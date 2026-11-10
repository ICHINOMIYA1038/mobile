import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:takken_talk/api/client.dart';
import 'package:takken_talk/funnel.dart';
import 'package:takken_talk/screens/pro/analysis_screen.dart';
import 'package:takken_talk/screens/study_next_step.dart';
import 'package:takken_talk/screens/study_screen.dart';
import 'package:takken_talk/state/app_state.dart';
import 'package:takken_talk/study_draft.dart';
import 'package:takken_talk/theme.dart';

http.Response ok(Object data) => http.Response.bytes(
  utf8.encode(jsonEncode(data)),
  200,
  headers: {'content-type': 'application/json'},
);

Map<String, dynamic> home(int seen) => {
  'pro': false,
  'study': <String, dynamic>{},
  'progress': {
    'seen': seen,
    'chapters': [
      {'chapterId': 'ch01', 'seen': seen.clamp(0, 3), 'total': 3},
      {'chapterId': 'ch02', 'seen': (seen - 3).clamp(0, 10), 'total': 10},
    ],
  },
};

Future<void> mount(WidgetTester tester, ApiClient api, {Widget? child}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await api.ensureUser();
  await tester.pumpWidget(
    AppScope(
      state: AppState(api),
      child: MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child:
                child ??
                const StudyNextStepCard(userId: 'test_user', chapterId: 'ch01'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final defaultLog = Funnel.log;
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'ps_token': 'test',
      'ps_user_id': 'test_user',
    });
    Funnel.log = (_, {parameters}) async {};
  });
  tearDown(() => Funnel.log = defaultLog);

  testWidgets('異なる3問の記録から、体験まであと7問と表示する', (tester) async {
    final api = ApiClient(
      baseUrl: 'http://test',
      client: MockClient((req) async {
        expect(req.url.path, '/api/v1/takken/home');
        return ok(home(3));
      }),
    );
    await mount(tester, api);
    expect(find.textContaining('異なる3問に答えました。あと7問'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      0.3,
    );
    expect(find.text('1日分の学習プランを体験'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('解き終えた章を避けて未回答を解き、戻ったら10問のプラン体験へ進む', (tester) async {
    var seen = 9;
    var homeCalls = 0;
    var previewCalls = 0;
    final api = ApiClient(
      baseUrl: 'http://test',
      client: MockClient((req) async {
        switch (req.url.path) {
          case '/api/v1/takken/home':
            homeCalls++;
            return ok(home(seen));
          case '/api/v1/takken/kakomon/ch02':
            expect(req.url.queryParameters['mode'], 'new');
            return ok({
              'items': [
                {
                  'question': {
                    'id': 'new_question',
                    'statement': 'まだ解いていない問題',
                    'difficulty': 1,
                  },
                  'state': {'answered': false},
                },
              ],
            });
          case '/api/v1/takken/answer':
            expect((jsonDecode(req.body) as Map)['questionId'], 'new_question');
            seen = 10;
            return ok({'correct': true, 'explanation': '確認できました。'});
          case '/api/v1/takken/pro/preview':
            expect(req.method, 'POST');
            previewCalls++;
            return ok({
              'createdAt': DateTime.utc(2026, 11, 11).millisecondsSinceEpoch,
              'report': {
                'answered': 10,
                'accuracy': 0.7,
                'subjects': <Object>[],
              },
              'plan': {'ai': false, 'week': <Object>[]},
            });
          default:
            fail('Unexpected test request: ${req.url.path}');
        }
      }),
    );
    await mount(tester, api);
    expect(find.textContaining('あと1問'), findsOneWidget);
    await tester.tap(find.text('まだ解いていない問題を解く'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('○ 正しい'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(homeCalls, 2);
    expect(find.text('あなたの学習プランを体験できます'), findsOneWidget);
    await tester.tap(find.text('1日分の学習プランを体験'));
    await tester.pumpAndSettle();
    expect(previewCalls, 1);
    expect(find.text('10問に取り組み、正答率は70%でした。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('通信できないときに解答数を推測せず、問題の続きは開ける', (tester) async {
    final api = ApiClient(
      baseUrl: 'http://test',
      client: MockClient((req) async {
        if (req.url.path == '/api/v1/takken/home') {
          return http.Response('{}', 503);
        }
        expect(req.url.path, '/api/v1/takken/kakomon/all');
        expect(req.url.queryParameters['mode'], 'new');
        return ok({'items': <Object>[]});
      }),
    );
    await mount(tester, api);
    expect(find.textContaining('記録を確認できませんでした'), findsOneWidget);
    expect(find.textContaining('あと7問'), findsNothing);
    await tester.tap(find.text('まだ解いていない問題を解く'));
    await tester.pumpAndSettle();
    expect(find.text('ここの問題は全部解きました。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('読み込み中に学習者を変えたら、前の人の記録を表示しない', (tester) async {
    final pending = Completer<http.Response>();
    final api = ApiClient(
      baseUrl: 'http://test',
      client: MockClient((_) => pending.future),
    );
    await mount(tester, api);
    await api.forgetUser();
    pending.complete(ok(home(99)));
    await tester.pumpAndSettle();
    expect(find.textContaining('99問'), findsNothing);
    expect(find.text('1日分の学習プランを体験'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('古いサーバーにはプラン体験の入口を出さない', (tester) async {
    final oldHome = home(10)..remove('study');
    final api = ApiClient(
      baseUrl: 'http://test',
      client: MockClient((_) async => ok(oldHome)),
    );
    await mount(tester, api);
    expect(find.text('あなたの学習プランを体験できます'), findsNothing);
  });

  testWidgets('結果から分析を見て戻ったときも、最新の解答数に更新する', (tester) async {
    var seen = 3;
    final api = ApiClient(
      baseUrl: 'http://test',
      client: MockClient((req) async {
        if (req.url.path == '/api/v1/takken/home') return ok(home(seen));
        expect(req.url.path, '/api/v1/takken/pro/analysis');
        seen = 10;
        return ok({
          'pro': false,
          'report': {
            'totals': {'answered': seen},
          },
          'preview': {
            'answered': seen,
            'minimum': 10,
            'eligible': true,
            'used': false,
          },
        });
      }),
    );
    await api.ensureUser();
    final draft = StudyDraft(
      userId: 'test_user',
      session: {
        'kind': 'starter',
        'day': '2026-11-11',
        'questions': [
          for (var i = 0; i < 3; i++)
            {
              'id': 'q$i',
              'chapterId': 'ch01',
              'statement': '確認$i',
              'topic': '確認',
            },
        ],
      },
    );
    for (var i = 0; i < 3; i++) {
      draft.answers['q$i'] = {'correct': true, 'answer': true};
    }
    await tester.pumpWidget(
      AppScope(
        state: AppState(api)..home = home(3),
        child: MaterialApp(
          theme: buildTheme(),
          home: StudyScreen(draft: draft),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('あと7問'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('解いた記録と学習プランを見る'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('解いた記録と学習プランを見る'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('あなたの学習プランを体験できます'), findsOneWidget);
    expect(find.textContaining('あと7問'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('分析から問題を解いて戻ると、残り問数と体験の入口が更新される', (tester) async {
    var seen = 9;
    var analysisCalls = 0;
    final api = ApiClient(
      baseUrl: 'http://test',
      client: MockClient((req) async {
        switch (req.url.path) {
          case '/api/v1/takken/pro/analysis':
            analysisCalls++;
            return ok({
              'pro': false,
              'report': {
                'totals': {'answered': seen},
              },
              'preview': {
                'answered': seen,
                'minimum': 10,
                'eligible': seen >= 10,
                'used': false,
              },
            });
          case '/api/v1/takken/kakomon/all':
            expect(req.url.queryParameters['mode'], 'new');
            return ok({
              'items': [
                {
                  'question': {
                    'id': 'new_question',
                    'statement': 'まだ解いていない問題',
                    'difficulty': 1,
                  },
                  'state': {'answered': false},
                },
              ],
            });
          case '/api/v1/takken/answer':
            seen = 10;
            return ok({'correct': true, 'explanation': '確認できました。'});
          default:
            fail('Unexpected test request: ${req.url.path}');
        }
      }),
    );
    await mount(
      tester,
      api,
      child: const SizedBox(height: 800, child: AnalysisScreen()),
    );
    expect(find.textContaining('あと1問'), findsOneWidget);
    await tester.tap(find.text('続けて問題を解く'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('○ 正しい'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(analysisCalls, 2);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, '1日分の学習プランを体験'),
          )
          .onPressed,
      isNotNull,
    );
    expect(find.textContaining('あと1問'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
