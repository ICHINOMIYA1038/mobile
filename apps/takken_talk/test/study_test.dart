import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:takken_talk/api/client.dart';
import 'package:takken_talk/funnel.dart';
import 'package:takken_talk/screens/study_screen.dart';
import 'package:takken_talk/screens/pro/plan_preview_screen.dart';
import 'package:takken_talk/state/app_state.dart';
import 'package:takken_talk/study_draft.dart';
import 'package:takken_talk/theme.dart';

Map<String, dynamic> session({
  String day = '2026-11-11',
  String kind = 'starter',
}) => {
  'day': day,
  'kind': kind,
  'questions': [
    for (var i = 0; i < 3; i++)
      {
        'id': 'q$i',
        'chapterId': 'ch01',
        'topic': '確認',
        'statement': '問題$i',
        'difficulty': 1,
        'lesson': {'title': '免許を確認', 'text': '説明を読んでから答えましょう。'},
      },
  ],
};

http.Response ok(Object data) => http.Response.bytes(
  utf8.encode(jsonEncode(data)),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  late List<(String, Map<String, Object>?)> events;
  final defaultLog = Funnel.log;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'ps_token': 'test',
      'ps_user_id': 'u_test',
    });
    events = [];
    Funnel.log = (name, {parameters}) async {
      events.add((name, parameters));
    };
  });
  tearDown(() => Funnel.log = defaultLog);

  group('途中の3問', () {
    test('再起動とホームの問題の変化で、途中の問題を入れ替えない', () async {
      final d = StudyDraft(userId: 'u_test', session: session());
      d.answers['q0'] = {'answer': true, 'correct': true};
      await d.save();
      final changed = session(kind: 'daily');
      (changed['questions'] as List).removeAt(0);
      final saved = await StudyDraft.load('u_test', changed);
      expect(saved.questions, hasLength(3));
      expect(saved.kind, 'starter');
      expect(saved.answers['q0']?['correct'], true);
      expect(saved.complete, false);
    });

    test('翌日は新しい問題になり、ほかの学習者には引き継がない', () async {
      final d = StudyDraft(userId: 'u_test', session: session());
      d.answers['q0'] = {'answer': true, 'correct': true};
      await d.save();
      expect((await StudyDraft.load('other', session())).answers, isEmpty);
      expect(
        (await StudyDraft.load(
          'u_test',
          session(day: '2026-11-12', kind: 'daily'),
        )).answers,
        isEmpty,
      );
    });

    test('学習者を作り直すとき、端末の3問と継続計測の記録も消す', () async {
      await StudyDraft(userId: 'u_test', session: session()).save();
      await Funnel.studyStarted('u_test', 'starter', '2026-11-11');
      final api = ApiClient();
      await api.ensureUser();
      await api.forgetUser();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys().where((k) => k.startsWith('study_')), isEmpty);
    });
  });

  group('継続と完了の計測', () {
    test('初回開始と完了は1回、翌日の再訪は当日にだけ1回記録する', () async {
      await Funnel.studyStarted('u_test', 'starter', '2026-11-11');
      await Funnel.studyStarted('u_test', 'starter', '2026-11-11');
      await Funnel.visit('u_test', '2026-11-11');
      await Funnel.studyCompleted('u_test', 'starter', '2026-11-11', 2, 3);
      await Funnel.studyCompleted('u_test', 'starter', '2026-11-11', 2, 3);
      await Funnel.visit('u_test', '2026-11-12');
      await Funnel.visit('u_test', '2026-11-12');
      await Funnel.visit('u_test', '2026-11-13');
      expect(events.where((e) => e.$1 == 'study_first_started'), hasLength(1));
      expect(
        events.where((e) => e.$1 == 'study_first_completed'),
        hasLength(1),
      );
      expect(events.where((e) => e.$1 == 'study_return_d1'), hasLength(1));
    });

    test('既存の人の復習を、初回体験や翌日継続の人数に混ぜない', () async {
      await Funnel.studyStarted('u_test', 'daily', '2026-11-11');
      await Funnel.studyCompleted('u_test', 'daily', '2026-11-11', 3, 3);
      await Funnel.visit('u_test', '2026-11-12');
      expect(
        events.where(
          (e) => e.$1.startsWith('study_first') || e.$1 == 'study_return_d1',
        ),
        isEmpty,
      );
    });
  });

  testWidgets('説明のあと3問を解き、結果と翌日の復習を案内する', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requested = <String>[];
    final api = ApiClient(
      baseUrl: 'http://test',
      client: MockClient((req) async {
        if (req.url.path == '/api/v1/takken/home') {
          return ok({
            'pro': false,
            'study': session(),
            'progress': {'seen': 3},
          });
        }
        expect(req.url.path, '/api/v1/takken/answer');
        final body = jsonDecode(req.body) as Map;
        requested.add(body['questionId'] as String);
        return ok({
          'correct': false,
          'explanation': '説明を振り返りましょう。',
          'reference': '',
        });
      }),
    );
    await api.ensureUser();
    final draft = StudyDraft(userId: 'u_test', session: session());
    await tester.pumpWidget(
      AppScope(
        state: AppState(api)..home = {'study': session()},
        child: MaterialApp(
          theme: buildTheme(),
          home: StudyScreen(draft: draft),
        ),
      ),
    );
    expect(find.text('説明を読んでから答えましょう。'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.ensureVisible(find.text('○ 正しい'));
      await tester.tap(find.text('○ 正しい'));
      await tester.pumpAndSettle();
      final next = find.text(i == 2 ? '今回の結果を見る' : '次の問題');
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
    }
    expect(requested, ['q0', 'q1', 'q2']);
    expect(find.text('3問、おつかれさまでした'), findsOneWidget);
    expect(find.textContaining('明日は、今回まちがえた問題'), findsOneWidget);
    expect(find.textContaining('異なる3問に答えました。あと7問'), findsOneWidget);
    expect(tester.getBottomRight(find.text('まだ解いていない問題を解く')).dy, lessThan(844));
    expect(events.where((e) => e.$1 == 'study_first_completed'), hasLength(1));
    expect((await StudyDraft.load('u_test', session())).complete, true);
    expect(tester.takeException(), isNull);
  });

  testWidgets('プラン体験は実際の記録と次の行動を表示し、予測点を表示しない', (tester) async {
    final api = ApiClient(
      baseUrl: 'http://test',
      client: MockClient((req) async {
        expect(req.method, 'POST');
        expect(req.url.path, '/api/v1/takken/pro/preview');
        return ok({
          'createdAt': DateTime.utc(2026, 11, 10, 15).millisecondsSinceEpoch,
          'report': {'answered': 10, 'accuracy': 0.6, 'subjects': <Object>[]},
          'plan': {
            'ai': true,
            'week': [
              {
                'tasks': [
                  {
                    'type': 'kakomon',
                    'text': '免許の問題を復習する',
                    'chapterId': 'ch01',
                  },
                ],
              },
            ],
          },
        });
      }),
    );
    await api.ensureUser();
    await tester.pumpWidget(
      AppScope(
        state: AppState(api)..me = {'pro': false},
        child: MaterialApp(
          theme: buildTheme(),
          home: const PlanPreviewScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('10問に取り組み、正答率は60%でした。'), findsOneWidget);
    expect(find.text('免許の問題を復習する'), findsOneWidget);
    expect(find.textContaining('予測点'), findsNothing);
    expect(events.where((e) => e.$1 == 'pro_preview_viewed'), hasLength(1));
    expect(tester.takeException(), isNull);
  });
}
