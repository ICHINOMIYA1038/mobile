/// 宅建の重要用語を表すモデル。
class Term {
  const Term({
    required this.id,
    required this.name,
    required this.shortDescription,
    required this.detailedDescription,
    required this.category,
    this.aliases = const [],
  });

  final String id;
  final String name;
  final String shortDescription;
  final String detailedDescription;
  final String category;
  final List<String> aliases;
}
