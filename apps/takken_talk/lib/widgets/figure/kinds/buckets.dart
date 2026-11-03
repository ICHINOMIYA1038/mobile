import 'package:flutter/material.dart';

import '../../../theme.dart';
import 'common.dart';

/// 分ける。グループごとに色の下線つきの見出しと、罫線で区切った項目。2つのグループは広ければ横に並べる
class BucketsBody extends StatelessWidget {
  const BucketsBody(this.raw, {super.key});
  final Map<String, dynamic> raw;

  @override
  Widget build(BuildContext context) {
    final groups = maps(raw['groups']);
    final sections = [for (final g in groups) _group(g)];
    return LayoutBuilder(builder: (context, c) {
      // サイトは図の幅 480px 以上で2つを横に（本体の幅にすると 452）
      if (groups.length == 2 && c.maxWidth >= 452) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: sections[0]), const SizedBox(width: 14), Expanded(child: sections[1])]);
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (var i = 0; i < sections.length; i++) ...[if (i > 0) const SizedBox(height: 14), sections[i]]],
      );
    });
  }

  Widget _group(Map<String, dynamic> g) {
    final tone = switch (g['tone']) { 'yes' || 'no' || 'warn' => g['tone'] as String, _ => 'info' };
    final color = switch (tone) { 'yes' => Palette.success, 'no' => Palette.danger, 'warn' => Palette.warning, _ => Palette.lineStrong };
    final mark = switch (tone) { 'yes' => '✓ ', 'no' => '✕ ', _ => '' };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: color, width: 3))),
          child: Text('$mark${str(g['title'])}', style: TextStyle(fontSize: fsLabel, height: 1.5, fontWeight: FontWeight.w700, color: tone == 'info' ? Palette.ink : color)),
        ),
        Ruled(children: [for (final it in strs(g['items'])) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: NumText(it))]),
      ],
    );
  }
}
