# リリースビルドの難読化・圧縮の設定。

# Flutter 本体。これが無いとリリースビルドで実行時エラーになる。
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google Mobile Ads（AdMob）。リフレクションで参照されるため削らせない。
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.** { *; }

# Play Billing（in_app_purchase）。課金が黙って壊れるのを防ぐ。
-keep class com.android.billingclient.** { *; }
-keep class com.android.vending.billing.** { *; }

# 警告の抑制（存在しない任意依存への参照）
-dontwarn io.flutter.embedding.**
