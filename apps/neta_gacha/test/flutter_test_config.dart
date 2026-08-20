import 'dart:async';

import 'package:neta_gacha/data/ad_service.dart';

// flutter test はこのファイルを自動的に読み込み、testExecutable でこのディレクトリの
// 全テストをラップする。AdMob/UMPの実チャンネル呼び出しを単体テスト環境で発火させない
// ようにするための共通設定はここに一箇所だけ書けばよい。
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AdService.disableForTests = true;
  await testMain();
}
