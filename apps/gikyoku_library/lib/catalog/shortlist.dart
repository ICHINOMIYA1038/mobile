import 'package:app_insights/app_insights.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 候補リスト。端末の中だけに残す（ログインなし）
class Shortlist extends ChangeNotifier {
  static const _key = 'shortlist_ids';
  final List<int> _ids = [];

  List<int> get ids => List.unmodifiable(_ids);
  bool contains(int id) => _ids.contains(id);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _ids
      ..clear()
      ..addAll((prefs.getStringList(_key) ?? const []).map(int.tryParse).whereType<int>());
    notifyListeners();
  }

  Future<void> toggle(int id) async {
    final adding = !_ids.contains(id);
    adding ? _ids.insert(0, id) : _ids.remove(id);
    notifyListeners();
    AppInsights.logEvent(adding ? 'shortlist_add' : 'shortlist_remove', parameters: {'play_id': id});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _ids.map((e) => '$e').toList());
  }
}
