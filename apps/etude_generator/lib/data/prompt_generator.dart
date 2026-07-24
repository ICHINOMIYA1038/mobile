import 'dart:math';

import '../models/etude_prompt.dart';
import 'etude_themes.dart';

class PromptGenerator {
  PromptGenerator({Random? random}) : _random = random ?? Random();

  final Random _random;

  static const genres = ['日常', 'コメディ', 'シリアス', 'ミステリー', 'ファンタジー'];
  static const durations = [3, 5, 10, 15];
  static int get themeCount => etudeThemes.length;

  EtudePrompt generate({
    required int players,
    required String genre,
    required int durationMinutes,
  }) {
    final candidates = etudeThemes
        .where((theme) => theme.genre == genre)
        .toList(growable: false);
    if (candidates.isEmpty) {
      throw ArgumentError.value(genre, 'genre', '対応するテーマがありません');
    }

    final theme = candidates[_random.nextInt(candidates.length)];
    final List<String> roles;
    if (theme.audited) {
      roles = List<String>.from(theme.roles.take(players))..shuffle(_random);
    } else {
      final pool = List<String>.from(roleSets[theme.roleKey]!)
        ..shuffle(_random);
      roles = pool.take(players).toList();
      roles[0] = '${roles[0]}\n秘密：${theme.secret}';
    }
    return EtudePrompt(
      id: '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(9999)}',
      players: players,
      genre: genre,
      durationMinutes: durationMinutes,
      characters: roles.take(players).toList(),
      relationship: theme.relationship,
      place: theme.place,
      situation: theme.situation,
      secret: theme.secret,
      constraint: theme.constraint,
      reflectionQuestions: theme.reflectionQuestions,
    );
  }
}
