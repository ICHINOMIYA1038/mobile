import 'package:flutter/material.dart';

import '../../data/ng_tags.dart';

/// NG設定画面で使う、タグごとの表示/非表示トグルチップ。
/// selected=true は「表示する(NGにしていない)」を意味する。
class NgTagChip extends StatelessWidget {
  const NgTagChip({
    super.key,
    required this.tag,
    required this.selected,
    required this.onSelected,
  });

  final NgTag tag;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(tag.label),
      selected: selected,
      onSelected: onSelected,
    );
  }
}
