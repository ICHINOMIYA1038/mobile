import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../config.dart';
import '../../models/core.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../rich_text.dart';
import 'kinds.dart';

/// 図解カード（サイトの FigureCard.svelte と同じ枠: 見出し → 本体 → ポイント → 「この図は…」）。
/// 本体はアプリで描く（kinds.dart）。描けない種類はサイトの `/fp1/embed/figure/<id>` を WebView で出す。
class FigureView extends StatelessWidget {
  const FigureView({super.key, required this.figure, this.favorite = true, this.feedback = true, this.shownOn = 'other'});
  final FigureData figure;

  /// 見出しの右に「☆ お気に入り」を出す
  final bool favorite;

  /// 下に「この図は わかりやすい／…」を出す
  final bool feedback;

  /// 意見に付ける出どころ（learn / library / other）
  final String shownOn;

  @override
  Widget build(BuildContext context) {
    final body = nativeFigureBody(figure);
    if (body == null) {
      // WebView の側が見出し・ポイントまで描くので、ここではお気に入りと意見の欄だけ足す
      return _Frame(
        figure: figure,
        favorite: favorite,
        feedback: feedback,
        shownOn: shownOn,
        showTitle: false,
        child: _EmbeddedFigure(figure.id),
      );
    }
    return _Frame(
      figure: figure,
      favorite: favorite,
      feedback: feedback,
      shownOn: shownOn,
      showTitle: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 14), child: body),
          if ((figure.note ?? '').isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Palette.line))),
              child: Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'ポイント  ', style: TextStyle(fontWeight: FontWeight.w700, color: Palette.warning)),
                  ...RichBody.spans(context, figure.note!, const [], const TextStyle(fontSize: 14, height: 1.7, color: Palette.ink)),
                ]),
                style: const TextStyle(fontSize: 14, height: 1.7, color: Palette.ink),
              ),
            ),
        ],
      ),
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.figure, required this.favorite, required this.feedback, required this.shownOn, required this.showTitle, required this.child});
  final FigureData figure;
  final bool favorite;
  final bool feedback;
  final String shownOn;
  final bool showTitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final fav = state.figureFavs.contains(figure.id);
    return Container(
      decoration: BoxDecoration(color: Palette.paper, border: Border.all(color: Palette.line), borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showTitle || favorite)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: showTitle ? Text(figure.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.5, color: Palette.ink)) : const SizedBox()),
                  if (favorite) _FavButton(on: fav, onTap: () => state.toggleFigureFav(figure.id, !fav)),
                ],
              ),
            ),
          child,
          if (feedback) _FigureFeedback(figureId: figure.id, shownOn: shownOn),
        ],
      ),
    );
  }
}

class _FavButton extends StatelessWidget {
  const _FavButton({required this.on, required this.onTap});
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        toggled: on,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            constraints: const BoxConstraints(minHeight: 32),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: on ? Palette.warningSoft : Palette.paper,
              border: Border.all(color: on ? Palette.warning : Palette.lineStrong),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(on ? '★ お気に入り' : '☆ お気に入り', style: TextStyle(fontSize: 13, color: on ? Palette.warning : Palette.inkSoft)),
          ),
        ),
      );
}

/// 「この図は わかりやすい／わかりにくい／間違いがある／こうしてほしい」（サイトの FigureFeedback.svelte）
class _FigureFeedback extends StatefulWidget {
  const _FigureFeedback({required this.figureId, required this.shownOn});
  final String figureId;
  final String shownOn;

  @override
  State<_FigureFeedback> createState() => _FigureFeedbackState();
}

class _FigureFeedbackState extends State<_FigureFeedback> {
  static const _ask = {
    'unclear': ('わかりにくい', 'どこが分かりにくいですか？（例: 矢印の意味、どこを見ればいいか）'),
    'wrong': ('間違いがある', 'どこが間違っていますか？（数字・条文など）'),
    'idea': ('こうしてほしい', 'こんな図・説明があると分かりやすい、など'),
  };
  bool _done = false;

  Future<void> _send(String rating, [String? note]) async {
    try {
      await AppScope.read(context).api.figureFeedback(figureId: widget.figureId, rating: rating, note: note, shownOn: widget.shownOn);
      if (mounted) setState(() => _done = true);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('送れませんでした')));
    }
  }

  Future<void> _askNote(String rating) async {
    final controller = TextEditingController();
    final note = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Palette.paper,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(ctx).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('この図は${_ask[rating]!.$1}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(controller: controller, autofocus: true, maxLines: 3, maxLength: 1000, decoration: InputDecoration(hintText: _ask[rating]!.$2, border: const OutlineInputBorder())),
              const SizedBox(height: 8),
              FilledButton(onPressed: () => Navigator.of(ctx).pop(controller.text.trim()), child: const Text('送る')),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
    if (note != null && note.isNotEmpty) await _send(rating, note);
  }

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 13, color: Palette.inkSoft, decoration: TextDecoration.underline);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 4),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Palette.line))),
      child: _done
          ? const Padding(padding: EdgeInsets.all(8), child: Text('ありがとうございます。図を直すのに使います。', style: TextStyle(fontSize: 13, color: Palette.success)))
          : Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text('この図は', style: TextStyle(fontSize: 13, color: Palette.inkFaint))),
                TextButton(onPressed: () => _send('clear'), child: const Text('わかりやすい', style: style)),
                for (final e in _ask.entries) TextButton(onPressed: () => _askNote(e.key), child: Text(e.value.$1, style: style)),
              ],
            ),
    );
  }
}

/// サイトの埋め込みページ。ページが FigureHeight で高さを知らせるので、その高さの枠にする
class _EmbeddedFigure extends StatefulWidget {
  const _EmbeddedFigure(this.id);
  final String id;

  @override
  State<_EmbeddedFigure> createState() => _EmbeddedFigureState();
}

class _EmbeddedFigureState extends State<_EmbeddedFigure> {
  late final WebViewController _controller;
  double _height = 240;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Palette.paper)
      ..addJavaScriptChannel('FigureHeight', onMessageReceived: (m) {
        final h = double.tryParse(m.message);
        if (h != null && h > 0 && mounted) {
          setState(() {
            _height = h;
            _loaded = true;
          });
        }
      })
      ..setNavigationDelegate(NavigationDelegate(
        // 図の中のリンクでよそへ行かない
        onNavigationRequest: (req) => req.url.contains('/embed/figure/') ? NavigationDecision.navigate : NavigationDecision.prevent,
      ))
      ..loadRequest(Uri.parse('${AppConfig.apiBase}/${AppConfig.exam}/embed/figure/${Uri.encodeComponent(widget.id)}'));
  }

  @override
  Widget build(BuildContext context) => AnimatedSize(
        duration: const Duration(milliseconds: 150),
        child: SizedBox(
          height: _height,
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (!_loaded) const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
        ),
      );
}
