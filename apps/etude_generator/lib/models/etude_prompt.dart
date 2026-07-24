import 'dart:convert';

class EtudePrompt {
  const EtudePrompt({
    required this.id,
    required this.players,
    required this.genre,
    required this.durationMinutes,
    required this.characters,
    required this.relationship,
    required this.place,
    required this.situation,
    required this.secret,
    required this.constraint,
    this.reflectionQuestions = const [],
  });

  final String id;
  final int players;
  final String genre;
  final int durationMinutes;
  final List<String> characters;
  final String relationship;
  final String place;
  final String situation;
  final String secret;
  final String constraint;
  final List<String> reflectionQuestions;

  String get title => '$placeで、$situation';

  Map<String, Object> toJson() => {
    'id': id,
    'players': players,
    'genre': genre,
    'durationMinutes': durationMinutes,
    'characters': characters,
    'relationship': relationship,
    'place': place,
    'situation': situation,
    'secret': secret,
    'constraint': constraint,
    'reflectionQuestions': reflectionQuestions,
  };

  factory EtudePrompt.fromJson(Map<String, dynamic> json) => EtudePrompt(
    id: json['id'] as String,
    players: json['players'] as int,
    genre: json['genre'] as String,
    durationMinutes: json['durationMinutes'] as int,
    characters: (json['characters'] as List).cast<String>(),
    relationship: json['relationship'] as String,
    place: json['place'] as String,
    situation: json['situation'] as String,
    secret: json['secret'] as String,
    constraint: json['constraint'] as String,
    reflectionQuestions:
        (json['reflectionQuestions'] as List?)?.cast<String>() ?? const [],
  );

  String encode() => jsonEncode(toJson());

  static EtudePrompt decode(String source) =>
      EtudePrompt.fromJson(jsonDecode(source) as Map<String, dynamic>);
}
