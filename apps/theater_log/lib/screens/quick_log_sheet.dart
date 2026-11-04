import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../catalog/achievements.dart';
import 'package:gikyoku_catalog/gikyoku_catalog.dart';
import '../catalog/theater_log.dart';
import '../theme.dart';
import '../widgets/ticket_stub.dart';
import 'log_edit_screen.dart';
import 'share_card_screen.dart';
import 'venue_stamps_screen.dart';

/// 3 秒で記録する。作品名と星だけ。細かいことはあとから
class QuickLogSheet extends StatefulWidget {
  const QuickLogSheet({super.key, this.play});
  final Play? play;

  static Future<void> open(BuildContext context, {Play? play}) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Palette.paper,
    routeSettings: const RouteSettings(name: 'quick_log'),
    builder: (_) => QuickLogSheet(play: play),
  );

  @override
  State<QuickLogSheet> createState() => _QuickLogSheetState();
}

class _QuickLogSheetState extends State<QuickLogSheet> {
  late final _title = TextEditingController(text: widget.play?.title);
  late Play? _play = widget.play;
  int? _rating;
  int _daysAgo = 0;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final scope = AppScope.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    final before = scope.log.entries;
    final today = DateUtils.dateOnly(DateTime.now());
    final entry = TheaterLogEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      watchedOn: today.subtract(Duration(days: _daysAgo)),
      playId: _play?.title == title ? _play?.id : null,
      author: _play?.title == title ? _play?.author : null,
      rating: _rating,
    );
    await scope.log.upsert(entry);
    HapticFeedback.mediumImpact();
    final earned = newlyEarned(before, scope.log.entries);
    navigator.pop();
    navigator.push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black87,
        settings: const RouteSettings(name: 'stub_stamped'),
        transitionDuration: const Duration(milliseconds: 150),
        pageBuilder: (_, _, _) => StubStampedScreen(entry: entry, earned: earned),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _title.text.trim().toLowerCase();
    final plays = AppScope.of(context).catalog.plays;
    final selected = _play?.title == _title.text.trim();
    final hits = q.isEmpty || selected ? const <Play>[] : plays.where((p) => p.title.toLowerCase().contains(q) || p.author.toLowerCase().contains(q)).take(4).toList();
    const days = ['今日', '昨日', 'おととい'];
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('何を観ましたか？', style: TextStyle(fontFamily: titleFont, fontSize: 22, fontWeight: FontWeight.w700, color: Palette.navy)),
            const SizedBox(height: 12),
            TextField(
              key: const Key('quick-title'),
              controller: _title,
              autofocus: widget.play == null,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(hintText: '作品名', filled: true, fillColor: Palette.card, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Palette.line))),
            ),
            for (final p in hits)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(p.title),
                subtitle: Text(p.author),
                onTap: () => setState(() {
                  _play = p;
                  _title.text = p.title;
                }),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    key: Key('quick-star-$i'),
                    tooltip: '$i',
                    iconSize: 34,
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() => _rating = _rating == i ? null : i);
                    },
                    icon: Icon((_rating ?? 0) >= i ? Icons.star : Icons.star_border, color: Palette.vermilion),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                for (var i = 0; i < days.length; i++)
                  ChoiceChip(
                    label: Text(days[i], style: TextStyle(color: _daysAgo == i ? Colors.white : Palette.ink)),
                    selected: _daysAgo == i,
                    onSelected: (_) => setState(() => _daysAgo = i),
                  ),
                ActionChip(
                  key: const Key('quick-more'),
                  label: const Text('くわしく書く'),
                  onPressed: () {
                    final navigator = Navigator.of(context);
                    final play = _play?.title == _title.text.trim() ? _play : null;
                    navigator.pop();
                    LogEditScreen.open(navigator.context, play: play);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('quick-save'),
                style: FilledButton.styleFrom(backgroundColor: Palette.vermilion, padding: const EdgeInsets.symmetric(vertical: 15)),
                onPressed: _title.text.trim().isEmpty ? null : _save,
                child: const Text('半券を切る', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 半券ができた瞬間。スタンプが押される
class StubStampedScreen extends StatefulWidget {
  const StubStampedScreen({super.key, required this.entry, required this.earned});
  final TheaterLogEntry entry;
  final List<Achievement> earned;

  @override
  State<StubStampedScreen> createState() => _StubStampedScreenState();
}

class _StubStampedScreenState extends State<StubStampedScreen> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  bool _hapticDone = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      if (!_hapticDone && _c.value > 0.72) {
        _hapticDone = true;
        HapticFeedback.heavyImpact();
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final log = AppScope.of(context).log;
    final year = widget.entry.watchedOn.year;
    final nth = log.countInYear(year);
    final stubIn = CurvedAnimation(parent: _c, curve: const Interval(0, 0.45, curve: Curves.easeOutBack));
    final stampIn = CurvedAnimation(parent: _c, curve: const Interval(0.5, 0.75, curve: Curves.easeIn));
    final restIn = CurvedAnimation(parent: _c, curve: const Interval(0.75, 1));
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeTransition(
                opacity: restIn,
                child: Text('$year年 $nth 本目', key: const Key('stamped-count'), style: const TextStyle(fontFamily: titleFont, fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
              const SizedBox(height: 20),
              SizedBox(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ScaleTransition(scale: stubIn, child: TicketStub(entry: widget.entry)),
                    Positioned(
                      right: 14,
                      bottom: -22,
                      child: AnimatedBuilder(
                        animation: stampIn,
                        builder: (_, child) => Opacity(
                          opacity: stampIn.value,
                          child: Transform.scale(scale: 2.4 - 1.4 * stampIn.value, child: Transform.rotate(angle: -0.22, child: child)),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(border: Border.all(color: Palette.vermilion, width: 3), borderRadius: BorderRadius.circular(6), color: const Color(0x22FFFFFF)),
                          child: const Text('観劇済', style: TextStyle(fontFamily: titleFont, fontSize: 22, fontWeight: FontWeight.w800, color: Palette.vermilion)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),
              FadeTransition(
                opacity: restIn,
                child: Column(
                  children: [
                    for (final a in widget.earned)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('スタンプ獲得「${a.title}」', key: Key('earned-${a.id}'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFE9A23B))),
                      ),
                    if (widget.entry.venue == null) ...[
                      FilledButton.icon(
                        key: const Key('stamped-venue'),
                        style: FilledButton.styleFrom(backgroundColor: Palette.vermilion),
                        onPressed: () async {
                          final venue = await VenuePickerSheet.open(context);
                          if (venue == null || !context.mounted) return;
                          final before = log.entries;
                          await log.upsert(widget.entry.copyWithVenue(venue.name));
                          if (!context.mounted) return;
                          final nav = Navigator.of(context);
                          nav.pop();
                          nav.push(
                            PageRouteBuilder<void>(
                              opaque: false,
                              barrierColor: Colors.black87,
                              settings: const RouteSettings(name: 'venue_stamped'),
                              pageBuilder: (_, _, _) => VenueStampedScreen(venue: venue, isNew: !before.any((e) => e.venue == venue.name), earned: newlyEarned(before, log.entries)),
                            ),
                          );
                        },
                        icon: const Icon(Icons.place),
                        label: const Text('劇場スタンプを押す'),
                      ),
                      const SizedBox(height: 4),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          key: const Key('stamped-note'),
                          onPressed: () {
                            final nav = Navigator.of(context);
                            nav.pop();
                            LogEditScreen.open(nav.context, entry: widget.entry);
                          },
                          child: const Text('感想を書く', style: TextStyle(color: Colors.white)),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            final nav = Navigator.of(context);
                            nav.pop();
                            ShareCardScreen.open(nav.context, widget.entry);
                          },
                          child: const Text('シェアする', style: TextStyle(color: Colors.white)),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          key: const Key('stamped-close'),
                          style: FilledButton.styleFrom(backgroundColor: Palette.paper, foregroundColor: Palette.navy),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('閉じる'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
