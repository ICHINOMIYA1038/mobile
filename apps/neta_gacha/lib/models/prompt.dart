import 'dart:convert';

/// お題1件。同梱コンテンツ・カスタムお題・お気に入りのいずれもこの型で表す。
class Prompt {
  const Prompt({
    required this.id,
    required this.situationId,
    required this.text,
    this.tags = const [],
    this.isCustom = false,
  });

  final String id;
  final String situationId;
  final String text;
  final List<String> tags;
  final bool isCustom;

  Map<String, Object?> toJson() => {
    'id': id,
    'situationId': situationId,
    'text': text,
    'tags': tags,
    'isCustom': isCustom,
  };

  factory Prompt.fromJson(Map<String, dynamic> json) {
    return Prompt(
      id: json['id'] as String,
      situationId: json['situationId'] as String,
      text: json['text'] as String,
      tags: (json['tags'] as List? ?? const []).cast<String>(),
      isCustom: json['isCustom'] as bool? ?? false,
    );
  }

  String encode() => jsonEncode(toJson());

  static Prompt decode(String source) =>
      Prompt.fromJson(jsonDecode(source) as Map<String, dynamic>);
}
