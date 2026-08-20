# アセットライブラリ・マニフェスト

`asset_library/` は、ゲームに実際使うかどうかに関わらず調達したフリー素材の**ソース置き場**。
実際にゲームに組み込む場合は必要な分だけ `web_game/static/` にコピーし、`web_game/MODEL_CREDITS.md` /
`web_game/AUDIO_CREDITS.md` に出典を追記する（手順は `docs/GAME_SPEC.md` 6.3節を参照）。

選定ポリシー: CC0（パブリックドメイン相当）を最優先。CC0以外を採用する場合は下表に必須クレジット文を明記すること。

## モデル

| パック | 配置場所 | 出典 | ライセンス | 用途メモ |
|---|---|---|---|---|
| Nature Kit | `models/nature-kit/glb/` | https://kenney.nl/assets/nature-kit | CC0 | 岩場テーマ用: `rock_*`, `stone_*`, `cliff_*` 多数。`cactus_*`（砂漠風）、`mushroom_*`、`log_*` も収録。329種のGLBモデル。テクスチャ埋め込み済み(外部テクスチャファイル不要)。 |
| Holiday Kit | `models/holiday-kit/glb/` | https://kenney.nl/assets/holiday-kit | CC0 | 雪原テーマ用: `tree-snow-a/b/c`, `snow-pile`, `snow-flat(-large)`, `rocks-large/medium/small`, `snowman`, `snowflake-a/b/c`。クリスマス色が強い小物(`present-*`, `candy-cane-*`, `gingerbread-*`, `wreath*`, `hanukkah-*`, `train-*`)は用途に応じて取捨選択。テクスチャは`glb/Textures/colormap.png`が必要(Mini Forestと同じ方式)。99種のGLBモデル。 |

## 音声

| パック | 配置場所 | 出典 | ライセンス | 用途メモ |
|---|---|---|---|---|
| Impact Sounds | `audio/impact-sounds/audio/` | https://kenney.nl/assets/impact-sounds | CC0 | 130種の衝撃音・足音(.ogg)。着地/ブーストパッドのSFX候補: `impactSoft_heavy_*`(着地の鈍い音)、`impactWood_*`、`footstep_snow_*`(雪原テーマの足音演出)、`footstep_grass_*`。 |

## 今後の調達候補（未取得）

- 追加テーマ用: 砂漠特化パック、洞窟/岩窟パック（Nature Kitの`cliff_*Cave*`系で当面代用可）
- UI/アイコン系パック（Kenneyの`category:UI`は現行サイト構成では見つからず。将来のストア/実績画面用に別途探索が必要）
- BGMバリエーション（テーマ別に曲を変える場合、OpenGameArt.org等で追加調達）

## 調達手順（再現用）

Kenneyサイトはクライアントサイドレンダリング(SPA)のため、素材ページの「Download」ボタンをクリック後に
表示される寄付モーダルの「Continue without donating...」をクリックすると実際のzip URLへのリクエストが
発生する仕組み。ブラウザで発生したリクエストURLを`curl`で(Refererヘッダー付きで)取得するのが確実:

```sh
curl -sS -o <name>.zip \
  -A "Mozilla/5.0 ..." \
  -e "https://kenney.nl/assets/<slug>" \
  "https://kenney.nl/media/pages/assets/<slug>/<hash>/kenney_<slug>.zip"
```

zip直リンクはブラウザでDownloadボタンをクリックして実際に発生したネットワークリクエストから都度取得する
(URLにハッシュが含まれ、パック更新のたびに変わるため固定できない)。
