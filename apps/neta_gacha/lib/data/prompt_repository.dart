import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/prompt.dart';

/// 同梱お題はシチュエーションごとに別ファイル(assets/prompts/以下、シチュエーションIDと
/// 同じ名前のjson)に分けている。1ファイルに全シチュエーション分をまとめると、
/// コンテンツを増やすたびに無関係なシチュエーションの分まで毎回読み込むことになり
/// 無駄が大きいため。
class PromptRepository {
  Future<List<Prompt>> loadForSituation(String situationId) async {
    final raw = await rootBundle.loadString(
      'assets/prompts/$situationId.json',
    );
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final list = json['prompts'] as List;
    return list
        .map((e) => Prompt.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
