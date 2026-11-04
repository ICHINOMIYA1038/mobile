import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../catalog/models.dart';
import '../screens/play_screen.dart';
import '../theme.dart';

class PlayCard extends StatelessWidget {
  const PlayCard({super.key, required this.play});
  final Play play;

  @override
  Widget build(BuildContext context) {
    final shortlist = AppScope.of(context).shortlist;
    return Card(
      elevation: 0,
      color: Palette.card,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      shape: RoundedRectangleBorder(side: const BorderSide(color: Palette.line), borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => PlayScreen.open(context, play),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(play.title, style: const TextStyle(fontFamily: titleFont, fontSize: 17, fontWeight: FontWeight.w700, color: Palette.ink)),
                    const SizedBox(height: 2),
                    Text(play.author, style: const TextStyle(fontSize: 13, color: Palette.inkSoft)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 2,
                      children: [
                        _Fact(Icons.people_outline, play.castLabel),
                        _Fact(Icons.schedule, play.minutesLabel),
                        if (play.readUrl != null) const _Fact(Icons.menu_book_outlined, '読み先あり', color: Palette.vermilion),
                      ],
                    ),
                  ],
                ),
              ),
              ListenableBuilder(
                listenable: shortlist,
                builder: (context, _) {
                  final on = shortlist.contains(play.id);
                  return IconButton(
                    tooltip: on ? '気になるから外す' : '気になる',
                    icon: Icon(on ? Icons.bookmark : Icons.bookmark_border, color: on ? Palette.vermilion : Palette.inkSoft),
                    onPressed: () => shortlist.toggle(play.id),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.icon, this.text, {this.color = Palette.inkSoft});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: color),
      const SizedBox(width: 3),
      Flexible(child: Text(text, style: TextStyle(fontSize: 13, color: color))),
    ],
  );
}
