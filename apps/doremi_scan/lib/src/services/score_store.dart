import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/score.dart';

/// 保存済み楽譜の一覧用メタ情報。
class SavedScore {
  final String id;
  final String title;
  final DateTime createdAt;
  final String thumbPath;
  const SavedScore(
      {required this.id,
      required this.title,
      required this.createdAt,
      required this.thumbPath});
}

/// 認識結果のローカル保存。
/// 同じ楽譜を毎回撮り直して20〜30秒待たなくて済むように、
/// 段画像・清書・ルビ（修正込み）をまるごと端末に残す。
class ScoreStore {
  static Future<Directory> _root() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/scores');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// 認識直後の自動保存。保存IDを返す。
  static Future<String> save(
      List<ScorePanel> panels, List<String> warnings) async {
    final root = await _root();
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final dir = Directory('${root.path}/$id')..createSync();
    await _writePanels(dir, panels, warnings, DateTime.now());
    return id;
  }

  /// 修正後の上書き保存（作成日時は維持）。
  static Future<void> update(String id, List<ScorePanel> panels) async {
    final root = await _root();
    final dir = Directory('${root.path}/$id');
    if (!dir.existsSync()) return;
    DateTime created = DateTime.now();
    try {
      final meta = jsonDecode(
              File('${dir.path}/meta.json').readAsStringSync())
          as Map<String, dynamic>;
      created = DateTime.fromMillisecondsSinceEpoch(meta['createdAt'] as int);
    } catch (_) {}
    // 警告は保存済みのものを引き継ぐ
    List<String> warnings = const [];
    try {
      final meta = jsonDecode(
              File('${dir.path}/meta.json').readAsStringSync())
          as Map<String, dynamic>;
      warnings = [for (final w in (meta['warnings'] as List?) ?? []) w as String];
    } catch (_) {}
    await _writePanels(dir, panels, warnings, created);
  }

  static Future<void> _writePanels(Directory dir, List<ScorePanel> panels,
      List<String> warnings, DateTime created) async {
    final metaPanels = <Map<String, dynamic>>[];
    for (var i = 0; i < panels.length; i++) {
      final p = panels[i];
      final imgFile = File('${dir.path}/panel_$i.jpg');
      imgFile.writeAsBytesSync(p.imageBytes);
      String? cleanName;
      if (p.hasClean) {
        cleanName = 'clean_$i.png';
        File('${dir.path}/$cleanName').writeAsBytesSync(p.cleanBytes!);
      }
      metaPanels.add({
        'image': 'panel_$i.jpg',
        'w': p.width,
        'h': p.height,
        'clean': cleanName,
        'cleanW': p.cleanWidth,
        'cleanH': p.cleanHeight,
        'cleanTrusted': p.cleanTrusted,
        'chords': [
          for (final c in p.chords)
            {'x': c.xFrac, 'y': c.yFrac, 'staff': c.staff, 'rubies': c.rubies}
        ],
        'staves': [
          for (final s in p.staves)
            {
              'staff': s.staff,
              'top': s.topFrac,
              'bottom': s.bottomFrac,
              'interline': s.interlineFrac
            }
        ],
      });
    }
    File('${dir.path}/meta.json').writeAsStringSync(jsonEncode({
      'createdAt': created.millisecondsSinceEpoch,
      'warnings': warnings,
      'panels': metaPanels,
    }));
  }

  /// 新しい順の一覧。
  static Future<List<SavedScore>> list() async {
    final root = await _root();
    final out = <SavedScore>[];
    for (final e in root.listSync().whereType<Directory>()) {
      final metaFile = File('${e.path}/meta.json');
      if (!metaFile.existsSync()) continue;
      try {
        final meta =
            jsonDecode(metaFile.readAsStringSync()) as Map<String, dynamic>;
        final created =
            DateTime.fromMillisecondsSinceEpoch(meta['createdAt'] as int);
        final panels = (meta['panels'] as List?) ?? const [];
        if (panels.isEmpty) continue;
        final first = Map<String, dynamic>.from(panels.first as Map);
        out.add(SavedScore(
          id: e.path.split(Platform.pathSeparator).last,
          title: '${created.month}月${created.day}日 '
              '${created.hour}:${created.minute.toString().padLeft(2, '0')}',
          createdAt: created,
          thumbPath: '${e.path}/${first['image']}',
        ));
      } catch (_) {}
    }
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  static Future<(List<ScorePanel>, List<String>)> load(String id) async {
    final root = await _root();
    final dir = Directory('${root.path}/$id');
    final meta = jsonDecode(File('${dir.path}/meta.json').readAsStringSync())
        as Map<String, dynamic>;
    final panels = <ScorePanel>[];
    for (final raw in (meta['panels'] as List?) ?? const []) {
      final p = Map<String, dynamic>.from(raw as Map);
      final cleanName = p['clean'] as String?;
      panels.add(ScorePanel(
        imageBytes: File('${dir.path}/${p['image']}').readAsBytesSync(),
        width: (p['w'] as num).toInt(),
        height: (p['h'] as num).toInt(),
        cleanBytes: cleanName == null
            ? null
            : File('${dir.path}/$cleanName').readAsBytesSync(),
        cleanWidth: (p['cleanW'] as num?)?.toInt() ?? 1,
        cleanHeight: (p['cleanH'] as num?)?.toInt() ?? 1,
        cleanTrusted: (p['cleanTrusted'] as bool?) ?? true,
        chords: [
          for (final c in (p['chords'] as List?) ?? const [])
            PanelChord(
              xFrac: ((c as Map)['x'] as num).toDouble(),
              yFrac: (c['y'] as num).toDouble(),
              staff: ((c['staff'] as num?) ?? 1).toInt(),
              rubies: [for (final r in (c['rubies'] as List)) r as String],
            ),
        ],
        staves: [
          for (final s in (p['staves'] as List?) ?? const [])
            PanelStaff(
              staff: (((s as Map)['staff'] as num?) ?? 1).toInt(),
              topFrac: ((s['top'] as num?) ?? 0).toDouble(),
              bottomFrac: ((s['bottom'] as num?) ?? 0).toDouble(),
              interlineFrac: ((s['interline'] as num?) ?? 0).toDouble(),
            ),
        ],
      ));
    }
    final warnings = [
      for (final w in (meta['warnings'] as List?) ?? const []) w as String
    ];
    return (panels, warnings);
  }

  static Future<void> delete(String id) async {
    final root = await _root();
    final dir = Directory('${root.path}/$id');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
}
