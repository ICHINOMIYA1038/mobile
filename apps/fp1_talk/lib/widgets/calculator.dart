import 'package:flutter/material.dart';

import '../theme.dart';

/// 本試験に持ち込める電卓と同じ、ふつうの電卓（押した順に計算する。× や ÷ を先にしない）。
/// 端数処理は自分でする練習のため、丸めない（表示は12桁まで。サイトの Calculator.svelte と同じ動き）。
/// 画面を閉じても値が残るよう、状態は画面の側が持つ（[CalculatorController]）。
class CalculatorController extends ChangeNotifier {
  String display = '0';

  /// 上の小さな行（「1,200 ×」「1,200 × 3 =」）
  String memo = '';
  double? _acc;
  String? _op;
  bool _fresh = true;

  static String fmt(double n) {
    if (!n.isFinite) return 'エラー';
    // 12桁で丸めて、浮動小数の誤差（0.1+0.2 など）を見せない
    final p = double.parse(n.toStringAsPrecision(12));
    final neg = p < 0;
    var s = p.abs().toString();
    if (s.contains('e')) return (neg ? '-' : '') + s;
    if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
    final parts = s.split('.');
    final i = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    return '${neg ? '-' : ''}$i${parts.length > 1 ? '.${parts[1]}' : ''}';
  }

  double get value => double.tryParse(display.replaceAll(',', '')) ?? 0;

  static double _apply(double a, double b, String o) => switch (o) {
        '+' => a + b,
        '−' => a - b,
        '×' => a * b,
        '÷' => a / b,
        _ => b,
      };

  void digit(String d) {
    if (display == 'エラー') display = '0';
    if (_fresh) {
      display = d == '.' ? '0.' : d;
      _fresh = false;
      notifyListeners();
      return;
    }
    if (d == '.' && display.contains('.')) return;
    final raw = display.replaceAll(',', '') + d;
    if (raw.replaceAll(RegExp(r'[-.]'), '').length > 12) return;
    if (raw.contains('.')) {
      final sp = raw.split('.');
      display = '${fmt(double.parse(sp[0]))}.${sp[1]}';
    } else {
      display = fmt(double.parse(raw));
    }
    notifyListeners();
  }

  void operator(String o) {
    final v = value;
    if (_acc != null && _op != null && !_fresh) {
      _acc = _apply(_acc!, v, _op!);
      display = fmt(_acc!);
    } else {
      _acc = v;
    }
    _op = o;
    memo = '${fmt(_acc!)} $o';
    _fresh = true;
    notifyListeners();
  }

  void equals() {
    if (_acc == null || _op == null) return;
    final v = value;
    memo = '${fmt(_acc!)} $_op ${fmt(v)} =';
    display = fmt(_apply(_acc!, v, _op!));
    _acc = null;
    _op = null;
    _fresh = true;
    notifyListeners();
  }

  void clear() {
    display = '0';
    _acc = null;
    _op = null;
    memo = '';
    _fresh = true;
    notifyListeners();
  }

  void back() {
    if (_fresh) return;
    final raw = display.replaceAll(',', '');
    final cut = raw.substring(0, raw.length - 1);
    if (cut.isEmpty || cut == '-') {
      display = '0';
    } else if (cut.endsWith('.')) {
      display = '${fmt(double.parse(cut.substring(0, cut.length - 1)))}.';
    } else {
      display = cut.contains('.') ? '${fmt(double.parse(cut.split('.')[0]))}.${cut.split('.')[1]}' : fmt(double.parse(cut));
    }
    notifyListeners();
  }

  void sign() {
    display = fmt(-value);
    notifyListeners();
  }

  /// キーの文字で押す（テストと画面のボタンの両方から）
  void press(String key) {
    switch (key) {
      case 'C':
        clear();
      case '±':
        sign();
      case '⌫':
        back();
      case '+' || '−' || '×' || '÷':
        operator(key);
      case '=':
        equals();
      case '00':
        digit('0');
        digit('0');
      default:
        digit(key);
    }
  }
}

/// 電卓の本体（表示とキー）。画面の下から出すパネルの中身
class CalculatorPad extends StatelessWidget {
  const CalculatorPad({super.key, required this.controller, this.onClose});
  final CalculatorController controller;
  final VoidCallback? onClose;

  static const _keys = [
    ['C', '±', '⌫', '÷'],
    ['7', '8', '9', '×'],
    ['4', '5', '6', '−'],
    ['1', '2', '3', '+'],
    ['0', '00', '.', '='],
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Icon(Icons.calculate_outlined, size: 18, color: Palette.inkSoft),
            const SizedBox(width: 6),
            const Expanded(child: Text('電卓（押した順に計算・丸めない）', style: TextStyle(fontSize: 12, color: Palette.inkSoft))),
            if (onClose != null)
              IconButton(onPressed: onClose, tooltip: '電卓を閉じる', icon: const Icon(Icons.close), constraints: const BoxConstraints(minWidth: 44, minHeight: 44)),
          ]),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
            decoration: BoxDecoration(color: Palette.fill, borderRadius: BorderRadius.circular(8), border: Border.all(color: Palette.line)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(controller.memo.isEmpty ? ' ' : controller.memo, style: const TextStyle(fontSize: 12, color: Palette.inkSoft)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    controller.display,
                    key: const Key('calc-display'),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Palette.ink, fontFeatures: [FontFeature.tabularFigures()]),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          for (final row in _keys)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                for (final (i, k) in row.indexed) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(child: _Key(k, onTap: () => controller.press(k))),
                ],
              ]),
            ),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key(this.label, {required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isOp = const ['÷', '×', '−', '+'].contains(label);
    final isEq = label == '=';
    final isFn = const ['C', '±', '⌫'].contains(label);
    final bg = isEq ? Palette.primary : isOp ? Palette.primarySoft : isFn ? Palette.fillStrong : Palette.paper;
    final fg = isEq ? Colors.white : isOp ? Palette.primaryStrong : Palette.ink;
    return Semantics(
      button: true,
      label: switch (label) { '⌫' => '1文字消す', '±' => '符号を変える', _ => label },
      excludeSemantics: true,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: Key('calc-$label'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Palette.line)),
            child: Text(label, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: fg)),
          ),
        ),
      ),
    );
  }
}
