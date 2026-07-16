import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// integration_test 側の takeScreenshot を受け取り、screenshots/ に PNG を書き出す。
/// 実行は tool/screenshots.sh から。
Future<void> main() async {
  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
      final directory = Directory('screenshots');
      if (!directory.existsSync()) directory.createSync(recursive: true);

      final file = File('${directory.path}/$name.png');
      file.writeAsBytesSync(bytes);
      stdout.writeln('  → ${file.path} (${(bytes.length / 1024).round()} KB)');
      return true;
    },
  );
}
