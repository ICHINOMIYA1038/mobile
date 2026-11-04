import 'package:app_insights/app_insights.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../catalog/achievements.dart';
import '../catalog/models.dart';
import '../catalog/venue_stamps.dart';
import '../theme.dart';

/// スタンプ帳の先頭。都道府県の地図
class VenueStampSummary extends StatelessWidget {
  const VenueStampSummary({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final stamps = venueStamps(scope.catalog.venues, scope.log.entries);
    final done = stamps.values.fold(0, (a, b) => a + b.count);
    final prefs = stamps.values.where((p) => p.count > 0).length;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Palette.card, border: Border.all(color: Palette.line), borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('劇場スタンプ $done / ${scope.catalog.venues.length}', key: const Key('venue-count'), style: const TextStyle(fontFamily: titleFont, fontSize: 18, fontWeight: FontWeight.w700)),
          Text('$prefs 都道府県に足あと', style: const TextStyle(fontSize: 12, color: Palette.inkSoft)),
          const SizedBox(height: 10),
          PrefectureMap(stamps: stamps, onTap: (p) => VenueListScreen.open(context, p)),
          const SizedBox(height: 6),
          const Text('各劇場とは関係のない、このアプリの楽しみ方です。', style: TextStyle(fontSize: 11, color: Palette.inkSoft)),
        ],
      ),
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
        color: on ? Palette.vermilion : const Color(0xFFE9E2D2),
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          key: Key('pref-$name'),
          borderRadius: BorderRadius.circular(4),
          onTap: s == null ? null : () => onTap(s),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Text(label, style: TextStyle(fontSize: 10, fontWeight: on ? FontWeight.w700 : FontWeight.normal, color: on ? Colors.white : Palette.inkSoft)),
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
    MaterialPageRoute<void>(builder: (_) => VenueListScreen(stamps: s), settings: const RouteSettings(name: 'venue_list')),
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
                    ? Padding(padding: const EdgeInsets.all(20), child: Text(q.isEmpty ? '劇場名を入れて探してください。' : '見つかりませんでした。一覧にない劇場は、記録の編集で自由に書けます。', style: const TextStyle(color: Palette.inkSoft, height: 1.6)))
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
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..forward();

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
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
          ScaleTransition(
            scale: CurvedAnimation(parent: _c, curve: Curves.elasticOut),
            child: Transform.rotate(
              angle: -0.12,
              child: Container(
                width: 190,
                height: 190,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Palette.vermilion, width: 5)),
                child: Text(widget.venue.name, textAlign: TextAlign.center, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: titleFont, fontSize: 20, fontWeight: FontWeight.w800, height: 1.3, color: Palette.vermilion)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(widget.isNew ? '${widget.venue.prefecture}の新しい劇場！' : 'また来ました', key: const Key('venue-stamp-message'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
          for (final a in widget.earned)
            Padding(padding: const EdgeInsets.only(top: 8), child: Text('スタンプ獲得「${a.title}」', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFFE9A23B)))),
          const SizedBox(height: 24),
          FilledButton(key: const Key('venue-stamp-close'), style: FilledButton.styleFrom(backgroundColor: Palette.paper, foregroundColor: Palette.navy), onPressed: () => Navigator.of(context).pop(), child: const Text('閉じる')),
        ],
      ),
    ),
  );
}
