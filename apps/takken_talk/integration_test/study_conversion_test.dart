import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:takken_talk/api/client.dart';
import 'package:takken_talk/funnel.dart';
import 'package:takken_talk/screens/home_screen.dart';
import 'package:takken_talk/state/app_state.dart';
import 'package:takken_talk/theme.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('初回3問から結果と学習プランの体験まで', (tester) async {
    SharedPreferences.setMockInitialValues({
      'ps_token': 'test_token',
      'ps_user_id': 'test_user',
    });
    Funnel.log = (_, {parameters}) async {};
    final home = <String, dynamic>{
      'examDate': '2027-10-17',
      'daysToExam': 340,
      'usedToday': 0,
      'capToday': 40,
      'tagline': 'AI の先生と話して学ぶ',
      'subjects': <Object>[],
      'chapters': <Object>[],
      'progress': {
        'seen': 0,
        'totalQuestions': 2820,
        'points': 399,
        'chapters': [
          {'chapterId': 'ch01', 'seen': 0, 'total': 10},
        ],
      },
      'study': {
        'day': '2026-11-11',
        'kind': 'starter',
        'questions': [
          for (var i = 0; i < 3; i++)
            {
              'id': 'test_q$i',
              'chapterId': 'ch01',
              'topic': '免許と宅建士',
              'statement': '説明の内容を確認する問題です。${i + 1}問目は正しいでしょうか。',
              'difficulty': 1,
              'lesson': {
                'title': '免許と宅建士の違い',
                'text':
                    'まずは、免許と宅建士の違いを整理してから、○×で確かめましょう。わからないところは、その場で AI に聞けます。',
              },
            },
        ],
      },
    };
    http.Response ok(Object body) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      200,
      headers: {'content-type': 'application/json'},
    );
    final answers = <String>[];
    final requests = <String>[];
    final fixtureErrors = <String>[];
    final api = ApiClient(
      baseUrl: 'http://test',
      client: MockClient((req) async {
        requests.add('${req.method} ${req.url.path}?${req.url.query}');
        try {
          switch (req.url.path) {
            case '/api/v1/takken/answer':
              final q = (jsonDecode(req.body) as Map)['questionId'] as String;
              answers.add(q);
              (home['progress'] as Map)['seen'] = answers.toSet().length;
              (((home['progress'] as Map)['chapters'] as List).first
                  as Map)['seen'] = answers
                  .toSet()
                  .length;
              return ok({
                'correct': q != 'test_q1',
                'explanation': '説明に戻って、違いを確認しましょう。',
                'reference': '',
              });
            case '/api/v1/takken/kakomon/ch01':
              expectSync(req.url.queryParameters['mode'], 'new');
              return ok({
                'items': [
                  for (var i = 3; i < 10; i++)
                    {
                      'question': {
                        'id': 'test_q$i',
                        'chapterId': 'ch01',
                        'topic': '免許と宅建士',
                        'statement': '追加で確認する問題です。${i + 1}問目は正しいでしょうか。',
                        'difficulty': 1,
                      },
                      'state': {'answered': false},
                    },
                ],
              });
            case '/api/v1/takken/pro/preview':
              expectSync(answers.toSet(), hasLength(10));
              return ok({
                'createdAt': DateTime.utc(
                  2026,
                  11,
                  10,
                  15,
                ).millisecondsSinceEpoch,
                'report': {
                  'answered': 10,
                  'accuracy': 0.9,
                  'subjects': [
                    {'label': '宅建業法', 'answered': 10, 'accuracy': 0.9},
                  ],
                },
                'plan': {
                  'ai': true,
                  'week': [
                    {
                      'tasks': [
                        {
                          'type': 'learn',
                          'text': '免許と宅建士の違いを先生と学ぶ',
                          'chapterId': 'ch01',
                          'pointId': 'test_point',
                        },
                        {
                          'type': 'kakomon',
                          'text': '免許と宅建士の問題を5問解く',
                          'chapterId': 'ch01',
                          'count': 5,
                        },
                      ],
                    },
                  ],
                },
              });
            case '/api/v1/takken/home':
              return ok(home);
            case '/api/v1/me':
              return ok(<String, Object>{});
            case '/api/v1/takken/review':
              return ok({'bookmarked': <Object>[]});
            case '/api/v1/takken/figure-bookmarks':
              return ok({'ids': <Object>[]});
            default:
              throw StateError('Unexpected test request: ${req.url.path}');
          }
        } catch (e) {
          fixtureErrors.add(e.toString());
          rethrow;
        }
      }),
    );
    await api.ensureUser();
    final state = AppState(api)..home = home;
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(theme: buildTheme(), home: const HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await binding.takeScreenshot('01_home');
    await tester.tap(find.text('まず3問やってみる'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('02_first_question');
    for (var i = 0; i < 3; i++) {
      await tester.ensureVisible(find.text('○ 正しい'));
      await tester.tap(find.text('○ 正しい'));
      await tester.pumpAndSettle();
      final next = find.text(i == 2 ? '今回の結果を見る' : '次の問題');
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
    }
    expect(answers, ['test_q0', 'test_q1', 'test_q2']);
    expect(find.text('3問、おつかれさまでした'), findsOneWidget);
    await binding.takeScreenshot('03_session_result');
    expect(find.textContaining('あと7問'), findsOneWidget);
    await tester.tap(find.text('まだ解いていない問題を解く'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('04_practice');
    expect(find.text('過去問 続きの問題'), findsOneWidget);
    for (var i = 3; i < 10; i++) {
      if (find.text('○ 正しい').evaluate().isEmpty) {
        await binding.takeScreenshot('practice_${i + 1}_missing');
        final texts = tester
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data)
            .whereType<String>()
            .take(20)
            .join(' / ');
        fail(
          '追加の${i + 1}問目を表示できませんでした。表示: $texts、通信: $requests、テスト用応答: $fixtureErrors',
        );
      }
      await tester.ensureVisible(find.text('○ 正しい'));
      await tester.tap(find.text('○ 正しい'));
      await tester.pumpAndSettle();
      if (i < 9) {
        await tester.tap(find.text('次の問題 ›'));
        await tester.pumpAndSettle();
      }
    }
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('あなたの学習プランを体験できます'), findsOneWidget);
    await binding.takeScreenshot('05_preview_ready');
    await tester.tap(find.text('1日分の学習プランを体験'));
    await tester.pumpAndSettle();
    expect(find.text('10問に取り組み、正答率は90%でした。'), findsOneWidget);
    await binding.takeScreenshot('06_plan_preview');
    expect(tester.takeException(), isNull);
  });
}
