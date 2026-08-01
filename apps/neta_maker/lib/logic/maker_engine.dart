import '../data/generators/futatsuna_bank.dart';
import '../data/generators/nounai_bank.dart';
import '../data/generators/zensei_bank.dart';
import '../models/maker_result.dart';
import 'seeded_random.dart';

/// 各カテゴリ共通の生成エントリポイント。
///
/// 乱数の決定性(同じ入力なら同じ結果)は必ずここで作った[Random]経由でのみ
/// 得られる。各カテゴリの語彙バンク側は乱数の作り方を知らず、渡された
/// [Random]から選ぶだけにすることで、「診断ロジックに一貫性がない」問題を
/// 構造的に防ぐ。
MakerResult generateMakerResult({
  required MakerCategory category,
  required String input,
  int rerollNonce = 0,
}) {
  final normalized = input.trim();
  final random = seededRandomFor(
    category: category.name,
    input: normalized,
    rerollNonce: rerollNonce,
  );

  return switch (category) {
    MakerCategory.futatsuna => generateFutatsuna(normalized, random),
    MakerCategory.zensei => generateZensei(normalized, random),
    MakerCategory.nounai => generateNounai(normalized, random),
  };
}
