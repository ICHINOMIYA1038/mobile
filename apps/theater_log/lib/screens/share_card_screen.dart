import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:app_insights/app_insights.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gikyoku_catalog/gikyoku_catalog.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app_scope.dart';
import '../catalog/log_photos.dart';
import '../catalog/seal_lines.dart';
import '../catalog/theater_log.dart';
import '../theme.dart';
import '../widgets/pon_stamp.dart';
import '../widgets/ticket_stub.dart';

/// カードの形。SNS ごとに合う比率が違う
enum CardFormat {
  story('縦長', 9 / 16),
  portrait('4:5', 4 / 5),
  square('正方形', 1);

  const CardFormat(this.label, this.aspectRatio);
  final String label;
  final double aspectRatio;
}

/// SNS に載せる画像。感想と座席は人に見せたくないこともあるので、初めは入れない
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
  CardFormat _format = CardFormat.story;

  /// 背景の写真。記録の写真の名前か、このカードのためだけに選んだ写真
  late String? _photoName = widget.entry.photos.firstOrNull;
  File? _picked;
  bool _busy = false;

  Future<void> _pickPhoto() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2400, imageQuality: 90);
    if (x == null || !mounted) return;
    setState(() {
      _picked = File(x.path);
      _photoName = null;
    });
  }

  Future<void> _share(BuildContext buttonContext) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final box = buttonContext.findRenderObject() as RenderBox?;
      final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
      final boundary = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      // どの形でも横 1080px の画像にする
      final image = await boundary.toImage(pixelRatio: 1080 / boundary.size.width);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('${(await getTemporaryDirectory()).path}/gekipon_card.png');
      await file.writeAsBytes(data!.buffer.asUint8List(), flush: true);
      AppInsights.logEvent('log_card_share', parameters: {'with_note': _withNote ? 1 : 0, 'format': _format.name, 'photo': _photoName != null || _picked != null ? 1 : 0});
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'image/png')], sharePositionOrigin: origin));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final venue = AppScope.of(context).catalog.venues.where((v) => v.name == e.venue).firstOrNull;
    final maxCardWidth = MediaQuery.sizeOf(context).width - 40;
    // 縦長でも 1 画面に収まるように幅を詰める
    final cardWidth = math.min(maxCardWidth, (MediaQuery.sizeOf(context).height * 0.55) * _format.aspectRatio);
    return Scaffold(
      appBar: AppBar(title: const Text('シェアカード')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Center(
            child: SizedBox(
              width: cardWidth,
              child: RepaintBoundary(
                key: _key,
                child: LogShareCard(entry: e, format: _format, photoName: _photoName, photoFile: _picked, venue: venue, withNote: _withNote, withSeat: _withSeat),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final f in CardFormat.values)
                ChoiceChip(
                  key: Key('card-format-${f.name}'),
                  label: Text(f.label, style: TextStyle(color: _format == f ? Colors.white : Palette.ink)),
                  selected: _format == f,
                  onSelected: (_) => setState(() => _format = f),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 64,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _PhotoChoice(
                  key: const Key('card-photo-none'),
                  selected: _photoName == null && _picked == null,
                  onTap: () => setState(() {
                    _photoName = null;
                    _picked = null;
                  }),
                  child: Container(color: stubColorOf(e.id), alignment: Alignment.center, child: const Text('写真なし', style: TextStyle(fontSize: 10, color: Colors.white))),
                ),
                for (final name in e.photos)
                  _PhotoChoice(
                    selected: _photoName == name,
                    onTap: () => setState(() {
                      _photoName = name;
                      _picked = null;
                    }),
                    child: LogPhotoImage(name: name, size: 64),
                  ),
                if (_picked != null) _PhotoChoice(selected: true, onTap: () {}, child: Image.file(_picked!, fit: BoxFit.cover, width: 64, height: 64)),
                _PhotoChoice(
                  key: const Key('card-photo-pick'),
                  selected: false,
                  onTap: _pickPhoto,
                  child: const ColoredBox(color: Palette.card, child: Icon(Icons.add_photo_alternate_outlined, color: Palette.inkSoft)),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('カメラロールから選んだ写真は、このカードにだけ使います。記録には保存しません。', style: TextStyle(fontSize: 11, color: Palette.inkSoft)),
          ),
          const SizedBox(height: 4),
          if (e.note.isNotEmpty) SwitchListTile(key: const Key('card-note'), contentPadding: EdgeInsets.zero, title: const Text('感想を入れる'), value: _withNote, onChanged: (v) => setState(() => _withNote = v)),
          if (e.seat != null) SwitchListTile(key: const Key('card-seat'), contentPadding: EdgeInsets.zero, title: const Text('座席を入れる'), value: _withSeat, onChanged: (v) => setState(() => _withSeat = v)),
          const SizedBox(height: 12),
          Builder(
            builder: (c) => FilledButton.icon(
              key: const Key('card-share'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: _busy ? null : () => _share(c),
              icon: const Icon(Icons.ios_share),
              label: const Text('画像を共有', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoChoice extends StatelessWidget {
  const _PhotoChoice({super.key, required this.selected, required this.onTap, required this.child});
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: selected ? Palette.vermilion : Palette.line, width: selected ? 3 : 1)),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    ),
  );
}

/// 写真の上に半券を置き、朱のハンコを押した 1 枚。大きさは幅に合わせて決める
class LogShareCard extends StatelessWidget {
  const LogShareCard({super.key, required this.entry, this.format = CardFormat.story, this.photoName, this.photoFile, this.venue, this.withNote = false, this.withSeat = false});
  final TheaterLogEntry entry;
  final CardFormat format;
  final String? photoName;
  final File? photoFile;

  /// 劇場の一覧にある劇場なら、劇場のスタンプも押す
  final Venue? venue;
  final bool withNote;
  final bool withSeat;

  bool get _hasPhoto => photoName != null || photoFile != null;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: format.aspectRatio,
    child: LayoutBuilder(
      builder: (_, c) {
        final w = c.maxWidth;
        final color = stubColorOf(entry.id);
        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_hasPhoto) _Photo(name: photoName, file: photoFile) else _PlainBackground(color: color),
              // 文字が写真に負けないよう、下を暗くする
              if (_hasPhoto)
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0x00000000), Color(0xB3000000)], stops: [0, 0.45, 1]),
                  ),
                ),
              Positioned(
                left: w * 0.06,
                top: w * 0.06,
                child: Text('ゲキポン', style: TextStyle(fontFamily: displayFont, fontSize: w * 0.04, fontWeight: FontWeight.w800, color: Colors.white, shadows: const [Shadow(color: Colors.black45, blurRadius: 4)])),
              ),
              if (venue != null)
                Positioned(
                  right: w * 0.06,
                  top: w * 0.05,
                  child: Transform.rotate(
                    angle: 0.14,
                    child: _Lifted(child: PonSeal(key: const Key('card-venue-seal'), size: w * 0.27, label: sealLines(venue!.name).join('\n'), sub: venue!.prefecture, fontSize: w * 0.062)),
                  ),
                ),
              Positioned(
                left: w * 0.06,
                right: w * 0.06,
                bottom: w * 0.09,
                child: _CardStub(entry: entry, width: w * 0.88, color: color, withNote: withNote, withSeat: withSeat),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _Photo extends StatelessWidget {
  const _Photo({this.name, this.file});
  final String? name;
  final File? file;

  @override
  Widget build(BuildContext context) {
    if (file != null) return Image.file(file!, fit: BoxFit.cover, gaplessPlayback: true);
    return FutureBuilder<File>(
      future: LogPhotos.file(name!),
      builder: (_, snap) => snap.hasData ? Image.file(snap.data!, fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (_, _, _) => const ColoredBox(color: Palette.navy)) : const ColoredBox(color: Palette.navy),
    );
  }
}

/// 写真が無いときの背景。半券の色に、薄い朱の円を重ねる
class _PlainBackground extends StatelessWidget {
  const _PlainBackground({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: RadialGradient(center: const Alignment(0.6, -0.5), radius: 1.2, colors: [Color.lerp(color, Colors.white, 0.18)!, color, Color.lerp(color, Colors.black, 0.35)!]),
    ),
  );
}

/// カードの下に置く半券。右下に「観劇済」のハンコを押す
class _CardStub extends StatelessWidget {
  const _CardStub({required this.entry, required this.width, required this.color, required this.withNote, required this.withSeat});
  final TheaterLogEntry entry;
  final double width;
  final Color color;
  final bool withNote;
  final bool withSeat;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final d = e.watchedOn;
    final s = width / 100;
    final tear = s * 22;
    final place = [e.group, e.venue].whereType<String>().join('／');
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipPath(
          clipper: StubClipper(tearAt: tear, notch: s * 2.6),
          child: ColoredBox(
            color: Palette.card,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: tear,
                    color: color,
                    padding: EdgeInsets.symmetric(vertical: s * 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${d.year}', style: TextStyle(fontSize: s * 3, color: Colors.white70)),
                        Text('${d.month}.${d.day}', style: TextStyle(fontFamily: displayFont, fontSize: s * 5.6, fontWeight: FontWeight.w700, color: Colors.white)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(s * 4.5, s * 4, s * 26, s * 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: titleFont, fontSize: s * 5.4, height: 1.3, fontWeight: FontWeight.w800, color: Palette.ink)),
                          if (place.isNotEmpty) Padding(padding: EdgeInsets.only(top: s * 1), child: Text(place, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: s * 3.2, color: Palette.inkSoft))),
                          if (withSeat && e.seat != null) Text(e.seat!, key: const Key('card-seat-text'), style: TextStyle(fontSize: s * 3.2, color: Palette.inkSoft)),
                          if (e.rating != null) Padding(padding: EdgeInsets.only(top: s * 1), child: Text('★' * e.rating!, style: TextStyle(fontSize: s * 4, color: Palette.vermilion))),
                          if (withNote && e.note.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(top: s * 1.6),
                              child: Text(e.note, maxLines: 4, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: s * 3.3, height: 1.6, color: Palette.ink)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          right: s * 1,
          bottom: -s * 7,
          child: Transform.rotate(angle: -0.2, child: _Lifted(child: PonSeal(size: s * 24, label: '観劇済', sub: '${d.month}.${d.day}', fontSize: s * 5))),
        ),
      ],
    );
  }
}

/// 写真の色に溶けないよう、ハンコに白い縁と影をつける
class _Lifted extends StatelessWidget {
  const _Lifted({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      color: Palette.paper,
      boxShadow: [BoxShadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 3))],
    ),
    child: Padding(padding: const EdgeInsets.all(2), child: child),
  );
}
