import 'package:flutter/material.dart';

import '../../../theme.dart';
import 'common.dart';

/// しくみ。見出しと字下げだけの目次のような形（いちばん上は罫線で区切り、下の段は左の線で字下げ）
class NestBody extends StatelessWidget {
  const NestBody(this.raw, {super.key});
  final Map<String, dynamic> raw;

  @override
  Widget build(BuildContext context) {
    final nodes = maps(raw['nodes']);
    return Ruled(
      children: [
        for (var i = 0; i < nodes.length; i++)
          Padding(padding: EdgeInsets.only(top: i == 0 ? 0 : 8, bottom: i == nodes.length - 1 ? 0 : 8), child: _node(nodes[i], 0)),
      ],
    );
  }

  Widget _node(Map<String, dynamic> n, int depth) {
    final children = maps(n['children']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NumText(str(n['title']), style: bodyStyle.copyWith(fontWeight: FontWeight.w700, fontSize: depth == 0 ? fsBody : fsLabel)),
        if (optStr(n['note']) != null) NumText(n['note'] as String, style: subStyle),
        if (children.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(4, 6, 0, 0),
            padding: const EdgeInsets.only(left: 12),
            decoration: const BoxDecoration(border: Border(left: BorderSide(color: Palette.lineStrong, width: 2))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [for (var i = 0; i < children.length; i++) Padding(padding: EdgeInsets.only(top: i == 0 ? 0 : 4), child: _node(children[i], depth + 1))],
            ),
          ),
      ],
    );
  }
}
