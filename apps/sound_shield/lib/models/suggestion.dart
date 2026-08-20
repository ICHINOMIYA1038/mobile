/// 騒音を防ぐための対策1件分。
class Suggestion {
  const Suggestion({required this.title, required this.description});

  final String title;
  final String description;

  @override
  bool operator ==(Object other) =>
      other is Suggestion &&
      other.title == title &&
      other.description == description;

  @override
  int get hashCode => Object.hash(title, description);
}
