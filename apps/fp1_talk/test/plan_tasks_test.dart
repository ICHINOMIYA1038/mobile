import 'package:flutter_test/flutter_test.dart';
import 'package:fp1_talk/screens/pro/plan_tasks.dart';

/// 学習プランの7日の予定: 日付の書き方・タスクの行き先・済みの付け外し（先に画面を変え、失敗したら元に戻せること）
void main() {
  group('日付', () {
    test('「10/22（木）」', () {
      expect(dateLabel('2026-10-22'), '10/22（木）');
      expect(dateLabel('2026-10-25'), '10/25（日）');
      expect(dateLabel('2026-10-26'), '10/26（月）');
      expect(dateLabel('2027-01-01'), '1/1（金）');
    });
    test('読めなければそのまま', () => expect(dateLabel('1日目'), '1日目'));
  });

  group('タスクの行き先', () {
    test('先生と学ぶ: 論点の会話', () {
      final r = taskRoute({'type': 'learn', 'pointId': 'ch06-hendo-1', 'chapterId': 'ch06'});
      expect((r.go, r.chapterId, r.pointId), (TaskGo.learn, 'ch06', 'ch06-hendo-1'));
    });
    test('先生と学ぶ: 章が無ければ論点 id から', () {
      final r = taskRoute({'type': 'learn', 'pointId': 'ch05-saiken-3'});
      expect((r.go, r.chapterId), (TaskGo.learn, 'ch05'));
    });
    test('過去問: 論点つき・章だけ', () {
      final a = taskRoute({'type': 'kakomon', 'pointId': 'ch06-hendo-1', 'chapterId': 'ch06', 'count': 10});
      expect((a.go, a.chapterId, a.pointId), (TaskGo.kakomon, 'ch06', 'ch06-hendo-1'));
      final b = taskRoute({'type': 'kakomon', 'chapterId': 'ch07', 'count': 10});
      expect((b.go, b.chapterId, b.pointId), (TaskGo.kakomon, 'ch07', null));
      final c = taskRoute({'type': 'kakomon', 'pointId': 'ch09-x-2'});
      expect((c.go, c.chapterId), (TaskGo.kakomon, 'ch09'));
    });
    test('復習・模擬試験', () {
      expect(taskRoute({'type': 'review', 'count': 10}).go, TaskGo.review);
      expect(taskRoute({'type': 'mock'}).go, TaskGo.mock);
    });
    test('行き先が分からないものは押せない', () {
      expect(taskRoute({'type': 'kakomon'}).go, TaskGo.none);
      expect(taskRoute({'type': 'learn', 'pointId': 'odd'}).go, TaskGo.none);
      expect(taskRoute({'type': 'other'}).go, TaskGo.none);
    });
    test('過去問の見出しは「」の中', () {
      expect(kakomonTitle('第6章 物権と借地借家の「定期建物賃貸借」の過去問を10問'), '定期建物賃貸借');
      expect(kakomonTitle('第7章 都市計画法の過去問を30問'), isNull);
    });
  });

  group('済みの付け外し', () {
    Map<String, dynamic> plan() => {
      'createdAt': 1,
      'week': [
        {'date': '2026-10-21', 'doneCount': 1, 'tasks': [{'id': 'd0t0', 'done': true}, {'id': 'd0t1', 'done': false}]},
        {'date': '2026-10-22', 'doneCount': 0, 'tasks': [{'id': 'd1t1', 'done': false}]},
      ],
    };

    test('プランの1つを済みに（数え直す）', () {
      final p = plan();
      final q = checkedPlan(p, 'd0t1', true);
      final day = (q['week'] as List).first as Map;
      expect(day['doneCount'], 2);
      expect((day['tasks'] as List).last, {'id': 'd0t1', 'done': true, 'manual': true});
      // 元の形は変えない（失敗したらこれに戻す）
      expect(((p['week'] as List).first as Map)['doneCount'], 1);
      expect((((p['week'] as List).first as Map)['tasks'] as List).last, {'id': 'd0t1', 'done': false});
    });

    test('済みを外す', () {
      final q = checkedPlan(plan(), 'd0t0', false);
      expect(((q['week'] as List).first as Map)['doneCount'], 0);
    });

    test('ほかの日・知らない id は変えない', () {
      final q = checkedPlan(plan(), 'nope', true);
      expect(((q['week'] as List)[1] as Map)['doneCount'], 0);
      expect(((q['week'] as List)[0] as Map)['doneCount'], 1);
    });

    test('今日の予定（tasks がじかにある形）', () {
      final t = {'planAt': 1, 'doneCount': 0, 'tasks': [{'id': 'a', 'done': false}, {'id': 'b', 'done': false}]};
      final u = checkedToday(t, 'b', true);
      expect(u['doneCount'], 1);
      expect(t['doneCount'], 0);
      expect(((t['tasks'] as List)[1] as Map)['done'], false);
    });
  });
}
