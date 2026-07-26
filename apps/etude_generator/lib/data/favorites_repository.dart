import 'package:shared_preferences/shared_preferences.dart';

import '../models/etude_prompt.dart';

class FavoritesRepository {
  static const _key = 'favorite_prompts_v1';

  Future<List<EtudePrompt>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_key) ?? [];
    final prompts = <EtudePrompt>[];
    for (final source in stored) {
      try {
        prompts.add(EtudePrompt.decode(source));
      } catch (_) {
        // 破損したお気に入り1件をスキップし、残りは読み込む。
      }
    }
    return prompts;
  }

  Future<void> save(List<EtudePrompt> prompts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      prompts.map((prompt) => prompt.encode()).toList(),
    );
  }
}
