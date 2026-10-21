import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// Firebase（計測・クラッシュの記録）の設定。**FP1 アプリはまだ Firebase に登録していないので null**。
///
/// 登録したら、このアプリのフォルダで `flutterfire configure`（Bundle ID jp.pairof.fp1.talk、iOS だけ）を実行する。
/// このファイルが生成し直され（currentPlatform が FirebaseOptions を返す形になる）、ios/Runner/GoogleService-Info.plist と
/// Crashlytics の記号のアップロードの手順（Xcode の Build Phases）も足される。宅建アプリの設定は流用しない。
/// null のあいだは main() が計測を始めないだけで、アプリはそのまま動く。
class DefaultFirebaseOptions {
  static FirebaseOptions? get currentPlatform => null;
}
