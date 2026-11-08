import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theater_log/widgets/community_widgets.dart';

void main() {
  testWidgets('初めて公開するときだけ、出る場所と出ないもの、利用規約とプライバシーポリシーへの同意を聞く', (tester) async {
    // 前の版（出る場所を書いていなかった）に同意した人にも、もう一度聞く
    SharedPreferences.setMockInitialValues({'community_rules_v1': true});
    final results = <bool>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (c) => TextButton(onPressed: () async => results.add(await CommunityRules.confirm(c)), child: const Text('公開'))),
      ),
    ));

    await tester.tap(find.text('公開'));
    await tester.pumpAndSettle();
    expect(find.textContaining('このアプリの「みんな」と作品のページ'), findsOneWidget);
    expect(find.textContaining('写真、座席、チケット代、観た日は出ません'), findsOneWidget);
    expect(find.textContaining('戯曲図書館'), findsNothing);
    expect(find.text('プライバシーポリシー'), findsOneWidget);
    await tester.tap(find.text('やめる'));
    await tester.pumpAndSettle();
    expect(results, [false]);

    await tester.tap(find.text('公開'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rules-agree')));
    await tester.pumpAndSettle();
    expect(results, [false, true]);
    expect((await SharedPreferences.getInstance()).getBool('community_rules_v2'), isTrue);

    // 同意したあとは聞かない
    await tester.tap(find.text('公開'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rules-agree')), findsNothing);
    expect(results, [false, true, true]);
  });
}
