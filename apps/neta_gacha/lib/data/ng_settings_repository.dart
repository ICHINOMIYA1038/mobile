import 'package:shared_preferences/shared_preferences.dart';

/// ユーザーが非表示にしたNGタグID(kNgTagsのid)の集合を保存する。
class NgSettingsRepository {
  static const _key = 'ng_tags_v1';

  Future<Set<String>> loadDisabledTagIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? const []).toSet();
  }

  Future<void> toggleTag(String tagId) async {
    final prefs = await SharedPreferences.getInstance();
    final disabled = (prefs.getStringList(_key) ?? const []).toSet();
    if (!disabled.add(tagId)) {
      disabled.remove(tagId);
    }
    await prefs.setStringList(_key, disabled.toList());
  }
}
