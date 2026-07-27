import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 結果画面の「秘密」欄は役を引いた本人だけに見せる内容で、共有機能で
/// 外部に漏れてはいけない。ソースを直接検査して、共有文を組み立てる
/// メソッドが prompt.secret を参照していないことを固定する。
void main() {
  test('共有機能が秘密（prompt.secret）を含めていない', () {
    final source = File('lib/main.dart').readAsStringSync();
    final shareMethodStart = source.indexOf('Future<void> _share(');
    expect(shareMethodStart, greaterThan(-1), reason: '_shareメソッドが見つかりません');

    final methodEnd = source.indexOf('\n}', shareMethodStart);
    final shareMethodBody = source.substring(shareMethodStart, methodEnd);

    expect(shareMethodBody.contains('prompt.secret'), isFalse);
  });
}
