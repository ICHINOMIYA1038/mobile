import 'package:shared_preferences/shared_preferences.dart';

import '../models/prompt.dart';

class FavoritesRepository {
  static const _key = 'favorite_prompts_v1';

  Future<List<Prompt>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_key) ?? [];
    final prompts = <Prompt>[];
    for (final source in stored) {
      try {
        prompts.add(Prompt.decode(source));
      } catch (_) {
        // 破損したお気に入り1件をスキップし、残りは読み込む。
      }
    }
    return prompts;
  }

  Future<void> save(List<Prompt> prompts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      prompts.map((prompt) => prompt.encode()).toList(),
    );
  }

  /// 保存済みなら外し、未保存なら追加する。追加後の状態(true=お気に入り中)を返す。
  Future<bool> toggle(Prompt prompt) async {
    final prompts = await load();
    final index = prompts.indexWhere((p) => p.id == prompt.id);
    if (index >= 0) {
      prompts.removeAt(index);
      await save(prompts);
      return false;
    }
    prompts.add(prompt);
    await save(prompts);
    return true;
  }
}
