# Sound Shield — 部屋の防音診断（iOS専用）

内見のその場で部屋の防音性を診断し、音の侵入経路を可視化して、対策の効果を予測・検証するアプリ。

## 機能

| 機能 | 概要 | 主なコード |
| --- | --- | --- |
| 内見診断 | 中央/窓際/隣室側の計測 + 壁ノック + 手叩きの5ステップで防音スコア(0-100, A〜E)・弱点・壁の重さを判定。物件を保存して比較 | `lib/ui/screens/inspection_*`, `lib/logic/inspection_scorer.dart`, `ios/Runner/SoundMeter/ImpulseProbe.swift` |
| 音の侵入マップ(AR) | ARKit で端末位置を追跡しながらレベルを記録し、空間に色付き球で表示。面(窓/壁/ドア/床)ごとに集計 | `lib/ui/screens/ar_map_screen.dart`, `lib/logic/ar_map_analyzer.dart`, `ios/Runner/SoundMeter/ArNoiseMapView.swift` |
| 対策シミュレーター | 11対策 × 10オクターブバンドの減衰テーブルで予測ΔdB・費用を算出。効かない対策は効かないと表示 | `lib/logic/countermeasure_simulator.dart`, `lib/ui/screens/simulator_screen.dart` |
| 対策の効果検証 | 対策前後の計測で実測ΔdBを記録し、予測と比較 | `lib/ui/screens/before_after_screen.dart` |
| 騒音計 | リアルタイムdB、周波数帯別・時間推移、SoundAnalysis による音源推定 | `lib/ui/screens/meter_screen.dart`, `ios/Runner/SoundMeter/SoundMeterPlugin.swift` |
| PDF | 診断レポート・比較表を共有 | `lib/logic/inspection_pdf.dart` |

計測値はキャリブレーション未実施の相対値(同一端末での比較用)。無料・広告なし・課金なし。

## 開発

```sh
flutter analyze
flutter test
flutter build ios --no-codesign --simulator   # Swift も含めてコンパイル確認
./tool/screenshots.sh                          # ストア用スクショ(iPhone 16 Pro Max)
./tool/screenshots.sh "iPad Pro 13-inch (M4)" screenshots_ipad
```

ノック/手叩き解析の**アルゴリズムは実機なしで検証できる**:

```sh
cd tool/impulse_lab
swift run -c release impulse_lab synth        # 既知の RT60/周波数の合成音で推定誤差を確認
swift run -c release impulse_lab wav data/esc50   # 実録音(ESC-50 のノック/拍手)を解析
swift run -c release impulse_lab diag data/esc50  # エンベロープ診断
```

`data/esc50` は ESC-50 (CC BY, https://github.com/karolpiczak/ESC-50) の `door_wood_knock`(クラス30) と
`clapping`(22) を `meta/esc50.csv` で絞って `audio/` から取得したもの(リポジトリには含めない)。
ARマップは実機でしか動かない。判定閾値の調整ポイントは `docs/concept-v2.md` §8 参照。

## ドキュメント

- `docs/concept-v2.md` — コンセプト・市場調査・実装状況
- `docs/store-listing.md` — ストア掲載文
- `docs/app-store-submission.md` — 提出手順・審査メモ・提出状況
