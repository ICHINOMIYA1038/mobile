import 'package:shared_preferences/shared_preferences.dart';

import '../models/etude_prompt.dart';

class FavoritesRepository {
  static const _key = 'favorite_prompts_v1';

  Future<List<EtudePrompt>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs
            .getStringList(_key)
            ?.map(EtudePrompt.decode)
            .toList(growable: false) ??
        [];
  }

  Future<void> save(List<EtudePrompt> prompts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      prompts.map((prompt) => prompt.encode()).toList(),
    );
  }
}
