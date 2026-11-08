import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// 観劇の写真。端末の中だけに保存し、サーバーには送らない
class LogPhotos {
  static const maxPerEntry = 10;

  static Future<Directory> _dir() async {
    final dir = Directory('${(await getApplicationSupportDirectory()).path}/log_photos');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<String> save(File source) async {
    final name = '${DateTime.now().microsecondsSinceEpoch}.jpg';
    await source.copy('${(await _dir()).path}/$name');
    return name;
  }

  static Future<File> file(String name) async => File('${(await _dir()).path}/$name');

  static Future<void> delete(String name) async {
    try {
      final f = await file(name);
      if (await f.exists()) await f.delete();
    } catch (_) {
      // 消せなくても記録の操作は止めない
    }
  }
}

class LogPhotoImage extends StatelessWidget {
  const LogPhotoImage({super.key, required this.name, required this.size});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) => FutureBuilder<File>(
    future: LogPhotos.file(name),
    builder: (context, snap) => snap.hasData
        // 小さく出すときは小さく読み込む。元の大きさのまま並べると、写真が多い人で端末のメモリが足りなくなる
        ? Image.file(snap.data!, width: size, height: size, fit: BoxFit.cover, cacheWidth: (size * MediaQuery.devicePixelRatioOf(context) * 2).round(), gaplessPlayback: true, errorBuilder: (_, _, _) => SizedBox(width: size, height: size))
        : SizedBox(width: size, height: size),
  );
}
