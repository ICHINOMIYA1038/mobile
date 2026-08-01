/// 色つきの絵文字を、インクで描いたようなセピア調に落とし込むための
/// 簡易セピア変換行列。羊皮紙の世界観とカラフルな絵文字がぶつかるのを防ぐ。
/// `ColorFiltered(colorFilter: ColorFilter.matrix(sepiaMatrix), child: ...)` で使う。
const sepiaMatrix = <double>[
  0.30, 0.55, 0.10, 0, 20,
  0.25, 0.48, 0.09, 0, 10,
  0.18, 0.35, 0.07, 0, -10,
  0, 0, 0, 1, 0,
];
