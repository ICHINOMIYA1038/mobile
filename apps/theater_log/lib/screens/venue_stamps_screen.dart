import 'package:app_insights/app_insights.dart';
import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../catalog/achievements.dart';
import 'package:gikyoku_catalog/gikyoku_catalog.dart';
import '../catalog/venue_stamps.dart';
import '../catalog/seal_lines.dart';
import '../theme.dart';
import '../widgets/pon_stamp.dart';

/// スタンプ帳の先頭。都道府県の地図
class VenueStampSummary extends StatelessWidget {
  const VenueStampSummary({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final stamps = venueStamps(scope.catalog.venues, scope.log.entries);
    final done = stamps.values.fold(0, (a, b) => a + b.count);
    final prefs = stamps.values.where((p) => p.count > 0).length;
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(child: Text('劇場スタンプ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Palette.ink))),
              Text('$done / ${scope.catalog.venues.length}', key: const Key('venue-count'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Palette.ink)),
            ],
          ),
          Text('$prefs 都道府県に足あと。都道府県を押すと劇場の一覧', style: const TextStyle(fontSize: 12, color: Palette.inkSoft)),
          const SizedBox(height: 12),
          PrefectureMap(stamps: stamps, onTap: (p) => VenueListScreen.open(context, p)),
          const SizedBox(height: 6),
          const Text('各劇場とは関係のない、このアプリの楽しみ方です。', style: TextStyle(fontSize: 11, color: Palette.inkSoft)),
        ],
    );
  }
}

class PrefectureMap extends StatelessWidget {
  const PrefectureMap({super.key, required this.stamps, required this.onTap});
  final Map<String, PrefectureStamps> stamps;
  final ValueChanged<PrefectureStamps> onTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      const cols = 11, rows = 14;
      final size = c.maxWidth / cols;
      return SizedBox(
        height: size * rows,
        child: Stack(
          children: [
            for (final e in prefectureTiles.entries)
              Positioned(
                left: e.value.$1 * size,
                top: e.value.$2 * size,
                width: size,
                height: size,
                child: _Tile(name: e.key, stamps: stamps[e.key], onTap: onTap),
              ),
          ],
        ),
      );
    },
  );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.name, required this.stamps, required this.onTap});
  final String name;
  final PrefectureStamps? stamps;
  final ValueChanged<PrefectureStamps> onTap;

  @override
  Widget build(BuildContext context) {
    final s = stamps;
    final on = (s?.count ?? 0) > 0;
    final label = name == '北海道' ? '北海' : name.substring(0, name.length - 1);
    return Padding(
      padding: const EdgeInsets.all(1),
      child: Material(
        color: on ? Palette.vermilion : const Color(0xFFE8E8E2),
        borderRadius: BorderRadius.circular(2),
        child: InkWell(
          key: Key('pref-$name'),
          borderRadius: BorderRadius.circular(2),
          onTap: s == null ? null : () => onTap(s),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Text(
                  label,
                  style: TextStyle(fontSize: 10, fontWeight: on ? FontWeight.w700 : FontWeight.normal, color: on ? Colors.white : Palette.inkSoft),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class VenueListScreen extends StatelessWidget {
  const VenueListScreen({super.key, required this.stamps});
  final PrefectureStamps stamps;

  static Future<void> open(BuildContext context, PrefectureStamps s) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => VenueListScreen(stamps: s),
      settings: const RouteSettings(name: 'venue_list'),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final sorted = [...stamps.venues]..sort((a, b) => (stamps.visited.contains(a.name) ? 0 : 1) - (stamps.visited.contains(b.name) ? 0 : 1));
    return Scaffold(
      appBar: AppBar(title: Text('${stamps.prefecture} ${stamps.count} / ${stamps.total}')),
      body: ListView(
        children: [
          for (final v in sorted)
            ListTile(
              leading: Icon(stamps.visited.contains(v.name) ? Icons.verified : Icons.radio_button_unchecked, color: stamps.visited.contains(v.name) ? Palette.vermilion : Palette.line),
              title: Text(v.name, style: TextStyle(fontWeight: stamps.visited.contains(v.name) ? FontWeight.w700 : FontWeight.normal)),
            ),
        ],
      ),
    );
  }
}

/// 劇場を探して選ぶ。行ったことのある劇場を先に出す
class VenuePickerSheet extends StatefulWidget {
  const VenuePickerSheet({super.key});

  static Future<Venue?> open(BuildContext context) => showModalBottomSheet<Venue>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    routeSettings: const RouteSettings(name: 'venue_pick'),
    builder: (_) => const VenuePickerSheet(),
  );

  @override
  State<VenuePickerSheet> createState() => _VenuePickerSheetState();
}

class _VenuePickerSheetState extends State<VenuePickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final recent = scope.log.recent((e) => e.venue).toSet();
    final q = _q.trim().toLowerCase();
    final hits = scope.catalog.venues.where((v) => q.isEmpty ? recent.contains(v.name) : v.name.toLowerCase().contains(q) || v.prefecture.contains(q)).take(30).toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.6,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  key: const Key('venue-query'),
                  autofocus: true,
                  onChanged: (v) => setState(() => _q = v),
                  decoration: const InputDecoration(hintText: '劇場名か都道府県', prefixIcon: Icon(Icons.search), border: OutlineInputBorder(), isDense: true),
                ),
              ),
              Expanded(
                child: hits.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(q.isEmpty ? '劇場名を入れて探してください。' : '見つかりませんでした。一覧にない劇場は、記録の編集で自由に書けます。', style: const TextStyle(color: Palette.inkSoft, height: 1.6)),
                      )
                    : ListView(
                        children: [
                          for (final v in hits)
                            ListTile(
                              title: Text(v.name),
                              subtitle: Text(v.prefecture),
                              trailing: recent.contains(v.name) ? const Icon(Icons.verified, color: Palette.vermilion, size: 18) : null,
                              onTap: () => Navigator.of(context).pop(v),
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

/// 劇場スタンプが押された瞬間
class VenueStampedScreen extends StatefulWidget {
  const VenueStampedScreen({super.key, required this.venue, required this.isNew, this.earned = const []});
  final Venue venue;
  final bool isNew;
  final List<Achievement> earned;

  @override
  State<VenueStampedScreen> createState() => _VenueStampedScreenState();
}

class _VenueStampedScreenState extends State<VenueStampedScreen> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();

  @override
  void initState() {
    super.initState();
    AppInsights.logEvent('venue_stamp', parameters: {'is_new': widget.isNew ? 1 : 0});
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PonStamp(
            delay: const Duration(milliseconds: 180),
            child: PonSeal(size: 200, label: sealLines(widget.venue.name).join('\n'), sub: widget.venue.prefecture, fontSize: 21),
          ),
          const SizedBox(height: 28),
          FadeTransition(
            opacity: CurvedAnimation(parent: _c, curve: const Interval(0.45, 1)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.isNew ? '${widget.venue.prefecture}の新しい劇場！' : 'また来ました',
                  key: const Key('venue-stamp-message'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                for (final a in widget.earned)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'スタンプ獲得「${a.title}」',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFFE9A23B)),
                    ),
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('venue-stamp-close'),
                  style: FilledButton.styleFrom(backgroundColor: Palette.paper, foregroundColor: Palette.navy),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('閉じる'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
