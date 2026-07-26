import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/question.dart';

class QuestionRepository {
  Future<List<Question>> loadAll() async {
    final raw = await rootBundle.loadString('assets/questions.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final list = json['questions'] as List;
    return list
        .map((e) => Question.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
