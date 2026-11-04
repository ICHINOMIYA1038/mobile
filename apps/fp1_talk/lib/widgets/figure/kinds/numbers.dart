import 'package:flutter/material.dart';

import '../../../theme.dart';
import 'common.dart';

/// 数字。左に「何の」、右に大きな数字
class NumbersBody extends StatelessWidget {
  const NumbersBody(this.raw, {super.key});
  final Map<String, dynamic> raw;

  @override
  Widget build(BuildContext context) {
    final items = maps(raw['items']);
    return Ruled(
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 10, bottom: i == items.length - 1 ? 0 : 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: str(items[i]['label'])),
                      if (optStr(items[i]['note']) != null) TextSpan(text: '\n', style: subStyle, children: numSpans(items[i]['note'] as String)),
                    ]),
                    style: bodyStyle.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 16),
                // 長い数字（「5年以下の拘禁刑」など）は 11 文字ぶんで折り返す
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 19 * 11),
                  child: Text(
                    str(items[i]['value']),
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 19, height: 1.3, fontWeight: FontWeight.w700, color: Palette.columns[0]),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
