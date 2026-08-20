import 'package:shared_preferences/shared_preferences.dart';

import '../models/prompt.dart';

class CustomPromptRepository {
  static const _key = 'custom_prompts_v1';

  Future<List<Prompt>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_key) ?? [];
    final prompts = <Prompt>[];
    for (final source in stored) {
      try {
        prompts.add(Prompt.decode(source));
      } catch (_) {
        // 破損したカスタムお題1件をスキップし、残りは読み込む。
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

  Future<void> add(Prompt prompt) async {
    final prompts = await load();
    prompts.add(prompt);
    await save(prompts);
  }

  Future<void> remove(String id) async {
    final prompts = await load();
    prompts.removeWhere((p) => p.id == id);
    await save(prompts);
  }
}
