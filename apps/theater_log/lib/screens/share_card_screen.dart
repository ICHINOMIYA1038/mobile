import 'dart:io';
import 'dart:ui' as ui;

import 'package:app_insights/app_insights.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../catalog/log_photos.dart';
import '../catalog/theater_log.dart';
import '../theme.dart';

/// SNS に載せる画像。感想は人に見せたくないこともあるので、初めは入れない
class ShareCardScreen extends StatefulWidget {
  const ShareCardScreen({super.key, required this.entry});
  final TheaterLogEntry entry;

  static Future<void> open(BuildContext context, TheaterLogEntry entry) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => ShareCardScreen(entry: entry), settings: const RouteSettings(name: 'share_card')),
  );

  @override
  State<ShareCardScreen> createState() => _ShareCardScreenState();
}

class _ShareCardScreenState extends State<ShareCardScreen> {
  final _key = GlobalKey();
  bool _withNote = false;
  bool _withSeat = false;

  Future<void> _share(BuildContext buttonContext) async {
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    final boundary = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('${(await getTemporaryDirectory()).path}/gikyoku_log_card.png');
    await file.writeAsBytes(data!.buffer.asUint8List(), flush: true);
    AppInsights.logEvent('log_card_share', parameters: {'with_note': _withNote ? 1 : 0});
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'image/png')], sharePositionOrigin: origin));
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    return Scaffold(
      appBar: AppBar(title: const Text('シェアカード')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          RepaintBoundary(
            key: _key,
            child: LogShareCard(entry: e, withNote: _withNote, withSeat: _withSeat),
          ),
          if (e.note.isNotEmpty) SwitchListTile(key: const Key('card-note'), contentPadding: EdgeInsets.zero, title: const Text('感想を入れる'), value: _withNote, onChanged: (v) => setState(() => _withNote = v)),
          if (e.seat != null) SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('座席を入れる'), value: _withSeat, onChanged: (v) => setState(() => _withSeat = v)),
          const SizedBox(height: 12),
          Builder(
            builder: (c) => FilledButton.icon(key: const Key('card-share'), onPressed: () => _share(c), icon: const Icon(Icons.ios_share), label: const Text('画像を共有')),
          ),
        ],
      ),
    );
  }
}

class LogShareCard extends StatelessWidget {
  const LogShareCard({super.key, required this.entry, this.withNote = false, this.withSeat = false});
  final TheaterLogEntry entry;
  final bool withNote;
  final bool withSeat;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final d = e.watchedOn;
    final place = [e.group, e.venue].whereType<String>().join('／');
    return AspectRatio(
      aspectRatio: 4 / 5,
      child: Container(
        color: Palette.navy,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (e.photos.isNotEmpty) Expanded(flex: 5, child: LayoutBuilder(builder: (_, c) => FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: LogPhotoImage(name: e.photos.first, size: c.maxWidth)))),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${d.year}.${d.month}.${d.day}', style: const TextStyle(fontSize: 13, color: Palette.paper)),
                    const SizedBox(height: 6),
                    Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: titleFont, fontSize: 25, fontWeight: FontWeight.w700, height: 1.3, color: Palette.paper)),
                    if (place.isNotEmpty) ...[const SizedBox(height: 4), Text(place, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Palette.paper))],
                    if (withSeat && e.seat != null) Text(e.seat!, style: const TextStyle(fontSize: 13, color: Palette.paper)),
                    if (e.rating != null) ...[const SizedBox(height: 6), Text('★' * e.rating!, style: const TextStyle(fontSize: 16, color: Color(0xFFE9A23B)))],
                    if (withNote && e.note.isNotEmpty) ...[const SizedBox(height: 8), Flexible(child: Text(e.note, overflow: TextOverflow.fade, style: const TextStyle(fontSize: 13, height: 1.6, color: Palette.paper)))],
                    const Spacer(),
                    const Align(alignment: Alignment.bottomRight, child: Text('ゲキポン', style: TextStyle(fontFamily: titleFont, fontSize: 12, color: Palette.paper))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
