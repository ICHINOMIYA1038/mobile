import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/question.dart';

/// 問題データの読み込み。アプリに同梱しているため通信は発生せず、機内モードでも動く。
class QuestionRepository {
  List<Question>? _cache;

  Future<List<Question>> load() async {
    final cached = _cache;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString('assets/questions.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final questions = (decoded['questions'] as List<dynamic>)
        .map((e) => Question.fromJson(e as Map<String, dynamic>))
        .toList();

    _cache = questions;
    return questions;
  }
}
