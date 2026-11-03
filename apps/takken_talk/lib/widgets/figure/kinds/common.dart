import 'package:flutter/material.dart';

import '../../../theme.dart';

// 図の本体で共通に使う文字の大きさ・飾り・raw の読み方。
// 大きさはサイトのスマホの段（src/app.css の @media (max-width: 767px)）にそろえる: 本文 14 / 見出し 13 / 補足 12。

const double fsBody = 14;
const double fsLabel = 13;
const double fsSub = 12;

const bodyStyle = TextStyle(fontSize: fsBody, height: 1.6, color: Palette.ink);
const subStyle = TextStyle(fontSize: fsSub, height: 1.6, color: Palette.inkSoft, fontWeight: FontWeight.w400);

// ---- raw（手書きの JSON）を読む。欠けていても落ちないように ----

String str(Object? v) => v is String ? v : (v == null ? '' : '$v');
String? optStr(Object? v) {
  final s = v is String ? v : null;
  return (s == null || s.trim().isEmpty) ? null : s;
}

List<Map<String, dynamic>> maps(Object? v) => v is List ? v.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList() : const [];
List<String> strs(Object? v) => v is List ? v.map(str).toList() : const [];

// ---- 数字を太字に（サイトの src/lib/figureText.ts の splitNumbers と同じ式） ----

final _num = RegExp(
  r'((?:[0-9０-９]+(?:[,，.．][0-9０-９]+)*|[一二三四五六七八九十百千]+)(?:\s*(?:分の|/)\s*[0-9０-９一二三四五六七八九十]+)?\s*(?:万円|億円|円|万|%|％|割|倍|年|か月|ヶ月|カ月|月|週間|日|時間|人|㎡|平方メートル|ha|m|メートル|階|戸|区画|回)(?:以上|以下|超|未満|以内)?)',
);

/// 文の中の覚えるべき数字（金額・期間・割合など）だけ太字にした span の列
List<InlineSpan> numSpans(String s) {
  final out = <InlineSpan>[];
  var last = 0;
  for (final m in _num.allMatches(s)) {
    if (m.start > last) out.add(TextSpan(text: s.substring(last, m.start)));
    out.add(TextSpan(text: m.group(0), style: const TextStyle(fontWeight: FontWeight.w700, color: Palette.ink)));
    last = m.end;
  }
  if (last < s.length) out.add(TextSpan(text: s.substring(last)));
  return out;
}

/// 数字を太字にした文
class NumText extends StatelessWidget {
  const NumText(this.text, {super.key, this.style = bodyStyle, this.textAlign});
  final String text;
  final TextStyle style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => Text.rich(TextSpan(children: numSpans(text)), style: style, textAlign: textAlign);
}

// ---- できる／できない を ✓ / ✕ に（サイトの src/lib/figureValue.ts の cellTone と同じ判定） ----

const _yes = {
  'できる', '必要', '要る', '書く', 'あり', '有', '○', '可', '適用あり', '適用される', '必須', '認められる', '課税', '課税される', //
  'する', '該当', '該当する', '義務あり', '届出が必要', '許可が必要', '許可必要', '届出必要', 'あたる', '対象', '対象になる', '取り消せる', '有効', '対抗できる', '請求できる',
};
const _no = {
  'できない', '不要', '要らない', '書かない', 'なし', '無', '×', '不可', '適用なし', '適用されない', '認められない', '非課税', '課税されない', //
  'しない', '該当しない', '義務なし', '届出不要', '許可不要', 'あたらない', '対象外', '対象にならない', '取り消せない', '無効', '対抗できない', '請求できない',
};
final _head = RegExp(r'^([^（(、。,\s]+)(.*)$', dotAll: true);

/// 値のはじめが肯定・否定の言い切りなら、その向き（true = できる側）と残り（「（業者間は省略可）」など）
({bool? tone, String head, String rest}) cellTone(String value) {
  final v = value.trim();
  final m = _head.firstMatch(v);
  if (m != null && m.group(1)!.length <= 8) {
    final h = m.group(1)!;
    if (_yes.contains(h)) return (tone: true, head: h, rest: m.group(2)!.trim());
    if (_no.contains(h)) return (tone: false, head: h, rest: m.group(2)!.trim());
  }
  return (tone: null, head: v, rest: '');
}

/// 比べる表のセルの値: 言い切りは色つきの ✓/✕、残りは下の行に小さく。説明文は数字だけ太字
List<InlineSpan> valueSpans(String v) {
  final c = cellTone(v);
  if (c.tone == null) return numSpans(v);
  final color = c.tone! ? Palette.success : Palette.danger;
  return [
    TextSpan(text: '${c.tone! ? '✓' : '✕'} ${c.head}', style: TextStyle(fontWeight: FontWeight.w700, color: color)),
    if (c.rest.isNotEmpty) TextSpan(text: '\n', style: subStyle, children: numSpans(c.rest)),
  ];
}

/// 「どちらも」「すべて」の小さな札（文の頭に置く）
WidgetSpan allChip(String label) => WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(border: Border.all(color: Palette.lineStrong), borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: const TextStyle(fontSize: fsSub, height: 1.5, color: Palette.inkSoft, fontWeight: FontWeight.w400)),
      ),
    );

/// 横線で区切った縦の並び（最後の下には線を引かない）
class Ruled extends StatelessWidget {
  const Ruled({super.key, required this.children, this.color = Palette.line});
  final List<Widget> children;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++)
            i == children.length - 1 ? children[i] : DecoratedBox(decoration: BoxDecoration(border: Border(bottom: BorderSide(color: color))), child: children[i]),
        ],
      );
}
