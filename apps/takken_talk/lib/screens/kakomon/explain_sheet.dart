import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/client.dart';
import '../../funnel.dart';
import '../../models/core.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/cap_notice.dart';
import '../../widgets/rich_text.dart';

/// 過去問演習の「AIに聞く」（サイトの ExplainPanel.svelte のスマホのシート）。いま解いている1問について AI に解説してもらう。
/// 下から高く開き、下へ払う・戻るで閉じれば同じ問題の同じ位置に戻る。答える前はヒントだけ（正解は言わない）。
Future<void> showExplainSheet(
  BuildContext context, {
  required String questionId,
  required String statement,
  required String where,
  Graded? graded,
  List<Term> glossary = const [],
}) {
  final state = AppScope.read(context);
  final thread = ExplainThread.of(questionId)..load(state.api);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Palette.paper,
    routeSettings: const RouteSettings(name: 'kakomon_explain'),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    clipBehavior: Clip.antiAlias,
    builder: (ctx) => Padding(
      // キーボードが出たらシートごと縮める（入力欄が隠れないように）
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.86,
        maxChildSize: 0.86,
        minChildSize: 0.4,
        snap: true,
        builder: (ctx, scroll) => _ExplainPanel(
          thread: thread,
          scroll: scroll,
          statement: statement,
          where: where,
          graded: graded,
          glossary: glossary,
          onTurn: state.applyTurn,
          api: state.api,
        ),
      ),
    ),
  );
}

class ExplainMsg {
  ExplainMsg(this.role, this.text);

  /// user / assistant
  final String role;
  String text;
  String? error;
}

/// 1問ぶんの会話。問題を行き来しても、シートを閉じても残す（アプリを開いているあいだ）。
/// 返答が流れている途中でシートを閉じても、ここで受け続けるので、開き直せば続きが見える。
class ExplainThread extends ChangeNotifier {
  ExplainThread._(this.questionId);
  static final _cache = <String, ExplainThread>{};
  static ExplainThread of(String questionId) => _cache.putIfAbsent(questionId, () => ExplainThread._(questionId));

  final String questionId;
  final List<ExplainMsg> msgs = [];
  bool loading = false;
  bool _loaded = false;
  bool busy = false;

  /// 1日の回数の上限などで送れないときのサーバーの文
  String? limit;

  /// 今日あと何回話せるか（done で届く。問題をまたいで共通なので static）
  static int? left;

  /// 最後に聞いたときの答え合わせ。答えてからまだ聞いていなければ、最初の頼み（なぜ…？）をもう一度出す
  Graded? askedWith;

  Future<void> load(ApiClient api) async {
    if (_loaded || loading) return;
    loading = true;
    notifyListeners();
    try {
      final j = await api.explainHistory(questionId);
      final got = ((j['messages'] as List?) ?? const [])
          .map((m) => (m as Map).cast<String, dynamic>())
          .where((m) => (m['text'] as String? ?? '').isNotEmpty)
          .map((m) => ExplainMsg(m['role'] == 'user' ? 'user' : 'assistant', m['text'] as String));
      if (msgs.isEmpty) msgs.addAll(got);
      _loaded = true;
    } catch (_) {
      // 読めなくても、新しく聞くことはできる。次に開いたときに読み直す
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// message が無ければ最初の頼み（答える前はヒント、答えたあとは「なぜ」）。
  /// 答えたあとは、毎回その○×を送る（サーバーが正解・不正解を踏まえて話す）
  Future<void> ask(ApiClient api, {String? message, Graded? graded, void Function(Map<String, dynamic>? turn)? onTurn}) async {
    if (busy) return;
    final text = message?.trim();
    busy = true;
    limit = null;
    askedWith = graded;
    // 最初の一言はサーバーが保存するもの（explain.ts の firstAsk）と同じにする
    final shown = (text != null && text.isNotEmpty)
        ? text
        : graded == null
            ? 'この問題のヒントをください。'
            : graded.correct
                ? 'なぜこの答えになるのか、解説してください。'
                : 'なぜ「${graded.rightAnswer ? '○' : '×'}」なのか、解説してください。';
    msgs.add(ExplainMsg('user', shown));
    final reply = ExplainMsg('assistant', '');
    msgs.add(reply);
    notifyListeners();
    try {
      await for (final e in api.explain(questionId: questionId, message: (text?.isNotEmpty ?? false) ? text : null, answer: graded?.answer)) {
        switch (e['type']) {
          case 'text':
            reply.text += e['delta'] as String? ?? '';
          case 'error':
            reply.error = e['message'] as String? ?? '解説を作れませんでした。';
          case 'done':
            final turn = (e['turn'] as Map?)?.cast<String, dynamic>();
            final cap = (turn?['capToday'] as num?)?.toInt() ?? 0;
            if (cap > 0) left = (cap - ((turn?['usedToday'] as num?)?.toInt() ?? 0)).clamp(0, cap);
            onTurn?.call(turn);
        }
        notifyListeners();
      }
      if (reply.error == null && reply.text.isNotEmpty) unawaited(Funnel.chatCompleted('explain'));
    } on ApiException catch (e) {
      if (e.isOverCap) {
        msgs.removeRange(msgs.length - 2, msgs.length);
        limit = e.message ?? '今日はもう話せません。';
        Funnel.capReached('explain', e.code);
        askedWith = null;
      } else {
        reply.error = e.message ?? '送れませんでした。もう一度試してください。';
      }
    } catch (_) {
      reply.error = '通信が切れました。もう一度送ってください。';
    } finally {
      busy = false;
      if (msgs.contains(reply) && reply.text.isEmpty && reply.error == null) reply.error = '解説を作れませんでした。もう一度押してみてください。';
      notifyListeners();
    }
  }

  /// Pro になったら、上限で止まっていた送信を戻す
  void clearLimit() {
    limit = null;
    notifyListeners();
  }

  /// 失敗した1往復を消して、同じ頼みをもう一度
  Future<void> retry(ApiClient api, {Graded? graded, void Function(Map<String, dynamic>? turn)? onTurn}) {
    final u = msgs[msgs.length - 2];
    msgs.removeRange(msgs.length - 2, msgs.length);
    final first = msgs.isEmpty && RegExp(r'^(この問題のヒントをください。|なぜ.+解説してください。)$').hasMatch(u.text);
    return ask(api, message: first ? null : u.text, graded: graded, onTurn: onTurn);
  }
}

class _ExplainPanel extends StatefulWidget {
  const _ExplainPanel({
    required this.thread,
    required this.scroll,
    required this.statement,
    required this.where,
    required this.graded,
    required this.glossary,
    required this.onTurn,
    required this.api,
  });
  final ExplainThread thread;
  final ScrollController scroll;
  final String statement;
  final String where;
  final Graded? graded;
  final List<Term> glossary;
  final void Function(Map<String, dynamic>? turn) onTurn;
  final ApiClient api;

  @override
  State<_ExplainPanel> createState() => _ExplainPanelState();
}

class _ExplainPanelState extends State<_ExplainPanel> {
  final _draft = TextEditingController();
  final _lastAsk = GlobalKey();
  bool _showQ = false;

  /// 答えが流れているあいだ、最後の質問を上端に留め続ける。自分でスクロールしたら止める
  bool _pin = false;
  bool _wasLoading = false;

  ExplainThread get _t => widget.thread;

  @override
  void initState() {
    super.initState();
    _t.addListener(_changed);
    _wasLoading = _t.loading;
    _toLastAsk();
  }

  @override
  void dispose() {
    _t.removeListener(_changed);
    _draft.dispose();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    // 履歴を読み終えたとき・答えが流れているあいだは、最後の質問を上端へ
    if (_pin || (_wasLoading && !_t.loading)) _toLastAsk();
    if (!_t.busy) _pin = false;
    _wasLoading = _t.loading;
  }

  /// 最後に送った質問を欄の上端に合わせる。答えはその下に流れてくるので、質問と答えの書き出しが必ず見える
  /// （答えに合わせて下へ送り続けると、長い答えでは自分の質問も答えの頭も上に流れてしまう）
  void _toLastAsk() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _lastAsk.currentContext;
      if (c == null || !c.mounted) return;
      Scrollable.ensureVisible(c, alignment: 0, alignmentPolicy: ScrollPositionAlignmentPolicy.explicit);
    });
  }

  Future<void> _ask([String? message]) {
    FocusScope.of(context).unfocus();
    _draft.clear();
    _pin = true;
    return _t.ask(widget.api, message: message, graded: widget.graded, onTurn: widget.onTurn);
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.graded;
    final t = _t;
    final msgs = t.msgs;
    final lastUser = msgs.lastIndexWhere((m) => m.role == 'user');
    final failed = msgs.isNotEmpty && msgs.last.error != null;
    // 答えたあとまだ「なぜ」を聞いていなければ、会話があっても最初の頼みを出す（ヒントだけ聞いてから答えたとき）
    final showCta = !t.loading && (msgs.isEmpty || (g != null && !identical(t.askedWith, g) && !t.busy && !failed));
    final quick = g != null ? const ['もっとかみくだいて', '具体例で説明して', 'ひっかけのポイントは？'] : const ['もう少しヒントを'];
    final ctaLabel = g == null ? 'ヒントをもらう' : (g.correct ? 'なぜこの答えになるの？' : 'なぜ「${g.rightAnswer ? '○' : '×'}」なの？');

    return Column(
      children: [
        // つまみと見出し。ここを下へ払っても閉じる
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(color: Palette.lineStrong, borderRadius: BorderRadius.circular(2)),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 6, 12, 10),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Palette.line))),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(header: true, child: const Text('AIに聞く', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Palette.ink))),
                    Text(widget.where, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Palette.inkFaint)),
                    // 答えの結果は AI の文に頼らず、ここでいつも見せる
                    if (g != null) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        _Badge(ok: g.correct, text: g.correct ? '正解' : '不正解'),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'あなたの答え ${g.answer ? '○' : '×'}${g.correct ? '' : '・正しくは ${g.rightAnswer ? '○' : '×'}'}',
                            style: const TextStyle(fontSize: 13, color: Palette.inkSoft),
                          ),
                        ),
                      ]),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                style: OutlinedButton.styleFrom(minimumSize: const Size(44, 44), padding: const EdgeInsets.symmetric(horizontal: 16), textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                child: const Text('問題に戻る'),
              ),
            ],
          ),
        ),
        Expanded(
          child: NotificationListener<UserScrollNotification>(
            onNotification: (_) {
              _pin = false;
              return false;
            },
            child: SingleChildScrollView(
              controller: widget.scroll,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 戻らなくても問題文を読み返せるように（押すと全文）
                  InkWell(
                    onTap: () => setState(() => _showQ = !_showQ),
                    child: Container(
                      color: Palette.desk,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      constraints: const BoxConstraints(minHeight: 44),
                      child: Semantics(
                        expanded: _showQ,
                        hint: _showQ ? '押すと短くする' : '押すと全文を出す',
                        child: Text(
                          widget.statement,
                          maxLines: _showQ ? null : 2,
                          overflow: _showQ ? null : TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, height: 1.6, color: Palette.inkSoft),
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (t.loading)
                          const Text('読み込んでいます…', style: TextStyle(fontSize: 14, color: Palette.inkFaint))
                        else if (msgs.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              g != null ? '答えの理由を AI がかみくだいて説明します。続けて質問もできます。' : '答える前は、正解を言わずにヒントだけ出します。',
                              style: const TextStyle(fontSize: 14, height: 1.7, color: Palette.inkSoft),
                            ),
                          ),
                        for (var i = 0; i < msgs.length; i++) ...[
                          if (msgs[i].role == 'user')
                            _Me(key: i == lastUser ? _lastAsk : null, text: msgs[i].text)
                          else
                            _Say(
                              msg: msgs[i],
                              glossary: widget.glossary,
                              onRetry: i == msgs.length - 1 && !t.busy ? () => t.retry(widget.api, graded: g, onTurn: widget.onTurn) : null,
                            ),
                          const SizedBox(height: 14),
                        ],
                        // 答える前は控えめに（○×で答えるのが先）。答えたあとは主役に
                        if (showCta)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: g != null
                                ? FilledButton(onPressed: t.busy ? null : () => _ask(), child: Text(ctaLabel))
                                : OutlinedButton(onPressed: t.busy ? null : () => _ask(), child: Text(ctaLabel)),
                          ),
                        if (t.limit != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: CapNotice(t.limit!, onPro: t.clearLimit),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        _compose(quick, showChips: msgs.isNotEmpty && !t.busy && t.limit == null && !failed && !showCta),
      ],
    );
  }

  Widget _compose(List<String> quick, {required bool showChips}) {
    final t = _t;
    final canSend = !t.busy && t.limit == null && _draft.text.trim().isNotEmpty;
    return Container(
      decoration: const BoxDecoration(color: Palette.paper, border: Border(top: BorderSide(color: Palette.line))),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showChips)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final s in quick)
                    Padding(
                      padding: const EdgeInsets.only(right: 8, bottom: 8),
                      child: ActionChip(
                        label: Text(s),
                        onPressed: () => _ask(s),
                        labelStyle: const TextStyle(fontSize: 13, color: Palette.primary),
                        backgroundColor: Palette.paper,
                        side: const BorderSide(color: Palette.lineStrong),
                        shape: const StadiumBorder(),
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                      ),
                    ),
                ]),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _draft,
                    enabled: t.limit == null,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 1000,
                    // 欄の外（解説・候補・送る）を押したらキーボードを閉じる
                    onTapOutside: (_) => FocusScope.of(context).unfocus(),
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 16, height: 1.5),
                    decoration: InputDecoration(
                      hintText: 'この問題について聞く',
                      counterText: '',
                      isDense: true,
                      filled: true,
                      fillColor: Palette.desk,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: Palette.line)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: Palette.line)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: canSend ? () => _ask(_draft.text) : null,
                  style: FilledButton.styleFrom(minimumSize: const Size(64, 46), padding: const EdgeInsets.symmetric(horizontal: 16)),
                  child: const Text('送る'),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                ExplainThread.left != null ? '今日あと ${ExplainThread.left} 回話せます（学ぶ画面と共通）' : '答え合わせとは別に、1日に話せる回数から1回減ります',
                style: const TextStyle(fontSize: 12, color: Palette.inkFaint),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 自分の質問（右寄せの吹き出し）
class _Me extends StatelessWidget {
  const _Me({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: Palette.primarySoft, borderRadius: BorderRadius.circular(14)),
          child: Text(text, style: const TextStyle(fontSize: 15, height: 1.6, color: Palette.ink)),
        ),
      );
}

/// AI の返答。段落ごとに RichBody（太字・マーカー・用語）
class _Say extends StatelessWidget {
  const _Say({required this.msg, required this.glossary, this.onRetry});
  final ExplainMsg msg;
  final List<Term> glossary;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final paras = msg.text.trim().isEmpty ? const <String>[] : msg.text.trim().split(RegExp(r'\n{2,}'));
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final p in paras)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: RichBody(p, glossary: glossary, style: const TextStyle(fontSize: 16, height: 1.75, color: Palette.ink)),
            ),
          if (paras.isEmpty && msg.error == null) const Text('AI が考えています…', style: TextStyle(fontSize: 14, color: Palette.inkFaint)),
          if (msg.error != null)
            Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(msg.error!, style: const TextStyle(fontSize: 14, color: Palette.danger)),
              if (onRetry != null)
                TextButton(onPressed: onRetry, style: TextButton.styleFrom(minimumSize: const Size(44, 44)), child: const Text('もう一度')),
            ]),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.ok, required this.text});
  final bool ok;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        decoration: BoxDecoration(color: ok ? Palette.successSoft : Palette.dangerSoft, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ok ? Palette.success : Palette.danger)),
      );
}
