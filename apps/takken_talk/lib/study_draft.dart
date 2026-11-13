import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class StudyDraft {
  StudyDraft({
    required this.userId,
    required this.session,
    Map<String, Map<String, dynamic>>? answers,
    this.persist = true,
  }) : answers = answers ?? {};

  /// false なら端末に残さない（「続きの3問」は、ホームの今日の3問の途中経過を上書きしない）
  final bool persist;

  final String userId;
  final Map<String, dynamic> session;
  final Map<String, Map<String, dynamic>> answers;
  String get day => session['day'] as String;
  String get kind => session['kind'] as String;
  List<Map<String, dynamic>> get questions => (session['questions'] as List)
      .map((q) => (q as Map).cast<String, dynamic>())
      .toList();
  bool get complete =>
      questions.isNotEmpty &&
      questions.every((q) => answers.containsKey(q['id']));
  int get correct => answers.values.where((a) => a['correct'] == true).length;
  static String _key(String userId) => 'study_draft_$userId';

  Future<void> save() async {
    if (!persist) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(userId),
      jsonEncode({'session': session, 'answers': answers}),
    );
  }

  static Future<StudyDraft> load(
    String userId,
    Map<String, dynamic> current,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final text = prefs.getString(_key(userId));
      if (text != null) {
        final data = jsonDecode(text) as Map<String, dynamic>;
        final session = (data['session'] as Map).cast<String, dynamic>();
        final qs = (session['questions'] as List).cast<Map>();
        final answers = (data['answers'] as Map).map(
          (k, v) => MapEntry(k as String, (v as Map).cast<String, dynamic>()),
        );
        final ids = qs.map((q) => q['id']).toSet();
        if (session['day'] == current['day'] &&
            qs.isNotEmpty &&
            qs.length <= 3 &&
            ids.length == qs.length &&
            answers.keys.every(ids.contains)) {
          return StudyDraft(userId: userId, session: session, answers: answers);
        }
      }
    } catch (_) {}
    return StudyDraft(userId: userId, session: current);
  }

  static Future<void> clear(String userId) async {
    await (await SharedPreferences.getInstance()).remove(_key(userId));
  }
}
