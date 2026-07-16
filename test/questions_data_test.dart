import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:takken_simple/models/question.dart';

/// 問題データそのものの検査。
/// 既存アプリで「誤字」「解説の誤り」「カテゴリ違い」が不満として挙がっている領域のため、
/// 機械的に検出できるものはここで落とす。問題を追加したら必ずこのテストを通すこと。
void main() {
  late List<Question> questions;

  setUpAll(() {
    final raw = File('assets/questions.json').readAsStringSync();
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    questions = (decoded['questions'] as List<dynamic>)
        .map((e) => Question.fromJson(e as Map<String, dynamic>))
        .toList();
  });

  test('問題が読み込める', () {
    expect(questions, isNotEmpty);
  });

  test('id が重複していない', () {
    final ids = questions.map((q) => q.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('category がすべて Category enum と一致する', () {
    for (final q in questions) {
      expect(
        Category.fromLabel(q.category),
        isNotNull,
        reason: '${q.id} の category "${q.category}" が Category enum にありません',
      );
    }
  });

  test('必須項目が空でない', () {
    for (final q in questions) {
      expect(q.statement.trim(), isNotEmpty, reason: '${q.id} の statement が空');
      expect(q.explanation.trim(), isNotEmpty, reason: '${q.id} の explanation が空');
      expect(q.reference.trim(), isNotEmpty, reason: '${q.id} の reference が空');
      expect(q.topic.trim(), isNotEmpty, reason: '${q.id} の topic が空');
    }
  });

  test('difficulty が 1〜3 に収まる', () {
    for (final q in questions) {
      expect(q.difficulty, inInclusiveRange(1, 3), reason: '${q.id} の difficulty が範囲外');
    }
  });

  test('statement が○×で答えられる長さに収まる', () {
    for (final q in questions) {
      expect(
        q.statement.length,
        lessThan(200),
        reason: '${q.id} の statement が長すぎます（一問一答として成立しません）',
      );
    }
  });

  test('解説は結論を書くだけの分量がある', () {
    for (final q in questions) {
      expect(
        q.explanation.length,
        greaterThan(20),
        reason: '${q.id} の explanation が短すぎます（理由と正しい結論を書くこと）',
      );
    }
  });

  test('○と×が極端に偏っていない', () {
    // ○ばかりだと「迷ったら○」で正解できてしまい、学習にならない。
    final trueCount = questions.where((q) => q.answer).length;
    final ratio = trueCount / questions.length;
    expect(ratio, inInclusiveRange(0.35, 0.65), reason: '正解の○×比が偏っています');
  });

  test('全科目に問題が存在する', () {
    for (final category in Category.values) {
      expect(
        questions.where((q) => q.category == category.label),
        isNotEmpty,
        reason: '${category.label} の問題がありません',
      );
    }
  });

  test('科目ごとの問題数が本試験の配点比率におおむね沿う', () {
    // データ側が偏っていると、scheduler が配点どおりに出そうとしても出せる問題が尽きる。
    for (final category in Category.values) {
      final actual =
          questions.where((q) => q.category == category.label).length / questions.length;
      expect(
        actual,
        closeTo(category.ratio, 0.06),
        reason: '${category.label} の問題数が配点比率から離れています',
      );
    }
  });

  test('同一 topic に問題が集中していない', () {
    final counts = <String, int>{};
    for (final q in questions) {
      counts.update(q.topic, (v) => v + 1, ifAbsent: () => 1);
    }
    for (final entry in counts.entries) {
      expect(
        entry.value,
        lessThanOrEqualTo(4),
        reason: 'topic "${entry.key}" に ${entry.value}問 が集中しています',
      );
    }
  });

  test('問題文が重複していない', () {
    final statements = questions.map((q) => q.statement).toList();
    expect(
      statements.toSet().length,
      statements.length,
      reason: '同じ問題文が複数の id に存在します',
    );
  });

  test('問題文に旧法令の表現が残っていない', () {
    // 競合アプリが「旧法令のまま」で叩かれている急所。問題文は現行法そのものなので一切許さない。
    // （解説は「旧法の瑕疵担保責任から改められた」のような対比が有用なため対象外）
    const stale = [
      '瑕疵担保責任',
      '錯誤無効',
      '錯誤により無効',
      '宅地造成等規制法',
      // 2025年6月1日の刑法改正で懲役・禁錮は拘禁刑に一本化された。
      '禁錮以上の刑',
      '懲役以上の刑',
      // 2025年4月1日施行の改正で四号建築物は廃止された。
      '四号建築物',
    ];
    for (final q in questions) {
      for (final word in stale) {
        expect(
          q.statement.contains(word),
          isFalse,
          reason: '${q.id} の問題文に旧法令の表現「$word」があります',
        );
      }
    }
  });

  test('廃止・改番された条文を根拠に挙げていない', () {
    // 2026年7月の法令監査で実際に見つかった型。根拠条文の誤りは解説の信頼を損なう。
    // 新しい改正を見つけたらここに足すこと。
    const staleReferences = {
      // 2025年4月1日施行の改正で6条1項は1〜3号に再編され、4号は存在しない。
      '建築基準法6条1項4号': '四号建築物は廃止。階数2以上/延べ200㎡超は6条1項2号',
      // 2024年7月1日施行の報酬告示改正で条建てが繰り下がった。現行の第九は別内容。
      '報酬告示第9': '広告料金のただし書は現行では第十一①',
    };
    for (final q in questions) {
      for (final entry in staleReferences.entries) {
        expect(
          q.reference.contains(entry.key),
          isFalse,
          reason: '${q.id} が廃止・改番された「${entry.key}」を引用しています。${entry.value}',
        );
      }
    }
  });

  test('毎年数値が変わる統計問題を含んでいない', () {
    // 問題データはアプリに同梱する固定データのため、統計を入れると翌年には誤りになる。
    final statistics = RegExp(r'(令和\d+年|20\d\d年)(度)?の.*(地価公示|住宅着工|取引件数|変動率)');
    for (final q in questions) {
      expect(
        statistics.hasMatch(q.statement),
        isFalse,
        reason: '${q.id} が統計問題の可能性があります',
      );
    }
  });

  test('期限切れの時限措置を現行制度として出題していない', () {
    // 税の特例には期限がある。問題データは同梱なので、期限が来ても自動では直らない。
    // 解説に書いた期限を過ぎたら、このテストが落ちて差し替えを促す。
    // 新しい期限付き特例を追加したらここに登録すること。詳細は docs/audit-2026-07.md。
    final deadlines = {
      // 住宅取得等資金贈与の非課税（措法70条の2）
      'zei-030': DateTime(2026, 12, 31),
      // 不動産取得税3%（地方税法附則11条の2第1項）
      'zei-001': DateTime(2027, 3, 31),
      // 宅地評価土地の課税標準1/2（同附則11条の5第1項）
      'zei-011': DateTime(2027, 3, 31),
      // 住宅用家屋の登録免許税の軽減（措法73条）
      'zei-018': DateTime(2027, 3, 31),
    };

    final now = DateTime.now();
    for (final entry in deadlines.entries) {
      final question = questions.firstWhere((q) => q.id == entry.key);
      expect(
        now.isAfter(entry.value),
        isFalse,
        reason: '${entry.key} が扱う特例は ${entry.value.year}年${entry.value.month}月${entry.value.day}日 に'
            '期限を迎えました。延長されたなら解説の年を更新し、廃止されたなら問題を差し替えてください。',
      );
      // 期限を解説に書いておくと、学習者もいつまでの制度か分かる。
      expect(
        question.explanation.contains('令和'),
        isTrue,
        reason: '${entry.key} は期限付きの特例なので、解説に適用期限を明記してください',
      );
    }
  });

  test('審査に出せる問題数がある', () {
    // App Store の Guideline 4.2（機能が最小限）対策。問題数はそのまま実用性の裏付けになる。
    expect(questions.length, greaterThanOrEqualTo(300));
  });
}
