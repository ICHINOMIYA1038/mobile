/// 認識結果のデータモデル。ネイティブ(Core ML)側からこの形で返る。
/// ルビは「元画像の座標(比率)」で返り、元の写真の上に重ねて表示する。
library;

/// 1つの音符（ふりがな1個ぶん）。座標は元画像に対する比率(0.0〜1.0)。
class DoremiNote {
  /// ドレミ表記（例: "ド", "ファ♯"）。
  final String ruby;

  /// 元の音名（例: "F#5"）。移調や固定ド/移動ド切替のために保持。
  final String pitch;

  /// 元画像に対する x 位置（0.0〜1.0）。音符の水平位置。
  final double xFrac;

  /// 元画像に対する y 位置（0.0〜1.0）。その音符が属する五線の上端。ルビはこの少し上に置く。
  final double yFrac;

  /// 音価（例: "quarter", "eighth."）。
  final String duration;

  const DoremiNote({
    required this.ruby,
    required this.pitch,
    required this.xFrac,
    required this.yFrac,
    required this.duration,
  });

  factory DoremiNote.fromJson(Map<String, dynamic> j) => DoremiNote(
        ruby: (j['ruby'] as String?) ?? '',
        pitch: (j['pitch'] as String?) ?? '',
        xFrac: (j['x'] as num?)?.toDouble() ?? 0,
        yFrac: (j['yFrac'] as num?)?.toDouble() ?? 0,
        duration: (j['duration'] as String?) ?? '',
      );
}

/// 和音（同じ拍に重なる音の束）。単音は rubies が1個。
class PanelChord {
  /// 段画像に対する比率座標（最上部の音符ヘッド中心）。
  final double xFrac;
  final double yFrac;

  /// 属するスタッフ番号（1=上段）。ルビのレーン振り分けに使う。
  final int staff;

  /// 上の音から下の音の順のドレミ。
  final List<String> rubies;

  PanelChord(
      {required this.xFrac,
      required this.yFrac,
      this.staff = 1,
      required this.rubies});
}

/// 段画像内の五線1つぶんの座標（比率）。ルビをレーンに整列させるために使う。
class PanelStaff {
  final int staff;

  /// 五線の最上線・最下線の y（段画像高さに対する比率）。
  final double topFrac;
  final double bottomFrac;

  /// 五線の線間隔（段画像高さに対する比率）。
  final double interlineFrac;

  const PanelStaff(
      {required this.staff,
      required this.topFrac,
      required this.bottomFrac,
      required this.interlineFrac});
}

/// 認識した段(system)の画像＋その上に重ねる和音たち。
/// サーバーが .omr の音符ヘッド座標から正確な位置を返す。
class ScorePanel {
  /// 段画像（JPEGバイト列）。
  final List<int> imageBytes;
  final int width;
  final int height;

  /// 和音の列（位置は音符ヘッド中心）。
  final List<PanelChord> chords;

  /// 段内の五線たち（ルビのレーン配置用。空なら音符位置から推定する）。
  final List<PanelStaff> staves;

  /// 清書（ドレミ付きに組版し直したきれいな楽譜のPNG）。
  /// ルビを修正したら古くなるので null に戻す。
  List<int>? cleanBytes;
  int cleanWidth;
  int cleanHeight;

  /// 清書のリズム検証が通ったか。false の段は読み取りが不完全な可能性が
  /// あるため、清書表示に注意バッジを付けて原本確認を促す。
  bool cleanTrusted;

  ScorePanel({
    required this.imageBytes,
    required this.width,
    required this.height,
    required this.chords,
    this.staves = const [],
    this.cleanBytes,
    this.cleanWidth = 1,
    this.cleanHeight = 1,
    this.cleanTrusted = true,
  });

  double get aspect => height <= 0 ? 6 : width / height;

  bool get hasClean => cleanBytes != null && cleanBytes!.isNotEmpty;

  double get cleanAspect => cleanHeight <= 0 ? 6 : cleanWidth / cleanHeight;
}

/// 1枚の楽譜写真の認識結果。元画像の上にドレミを重ねて表示する。
class RecognizedScore {
  /// 元画像のローカルパス（この上にルビを重ねる）。
  final String sourceImagePath;

  /// 元画像のピクセル幅・高さ（アスペクト比の算出に使う）。
  final int imageWidth;
  final int imageHeight;

  final List<DoremiNote> notes;

  /// 段ごとの画像＋正確な音符位置（あれば、これを優先して表示）。
  final List<ScorePanel> panels;

  /// 認識にかかった時間（ミリ秒）。
  final int elapsedMs;

  /// 診断情報（段数・音符数など。原因切り分け用）。
  final String debug;

  /// ユーザーに見せる注意（例: 読み取れない五線があった）。
  final List<String> warnings;

  /// true=元写真の上にルビ重ね / false=きれいなドレミ列を生成表示（OpenAI等、位置が推定のとき）。
  final bool overlayOnImage;

  const RecognizedScore({
    required this.sourceImagePath,
    required this.imageWidth,
    required this.imageHeight,
    required this.notes,
    this.panels = const [],
    required this.elapsedMs,
    this.debug = '',
    this.warnings = const [],
    this.overlayOnImage = true,
  });

  factory RecognizedScore.fromJson(Map<String, dynamic> j) => RecognizedScore(
        sourceImagePath: (j['sourceImagePath'] as String?) ?? '',
        imageWidth: (j['imageWidth'] as num?)?.toInt() ?? 1,
        imageHeight: (j['imageHeight'] as num?)?.toInt() ?? 1,
        elapsedMs: (j['elapsedMs'] as num?)?.toInt() ?? 0,
        debug: (j['debug'] as String?) ?? '',
        overlayOnImage: (j['overlayOnImage'] as bool?) ?? true,
        notes: ((j['notes'] as List?) ?? const [])
            .map((e) => DoremiNote.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  int get noteCount => notes.length;

  double get aspect => imageHeight <= 0 ? 1 : imageWidth / imageHeight;

  /// ドレミを空白区切りで（コピー用）。
  String get doremiLine => notes.map((n) => n.ruby).join(' ');
}
