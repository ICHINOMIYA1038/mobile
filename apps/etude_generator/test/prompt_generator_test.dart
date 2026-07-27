import 'dart:math';

import 'package:etude_generator/data/prompt_generator.dart';
import 'package:etude_generator/data/etude_themes.dart';
import 'package:etude_generator/models/etude_prompt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('テーマを1000本収録している', () {
    expect(PromptGenerator.themeCount, 1000);
    const expectedGenreCounts = {
      '日常': 200,
      'コメディ': 200,
      'シリアス': 200,
      'ミステリー': 200,
      'ファンタジー': 200,
    };
    for (final genre in PromptGenerator.genres) {
      expect(
        etudeThemes.where((theme) => theme.genre == genre),
        hasLength(expectedGenreCounts[genre]),
        reason: '$genreのテーマ数',
      );
    }
    for (final theme in etudeThemes) {
      expect(theme.place, isNotEmpty);
      expect(theme.situation, isNotEmpty);
      expect(theme.relationship, isNotEmpty);
      expect(theme.secret, isNotEmpty);
      expect(theme.constraint, isNotEmpty);
      expect(roleSets[theme.roleKey], hasLength(greaterThanOrEqualTo(4)));
      expect(theme.reflectionQuestions, hasLength(3));
    }
    final audited = etudeThemes.where((theme) => theme.audited).toList();
    expect(audited, hasLength(1000));
    for (final theme in audited) {
      expect(theme.roles, hasLength(4));
      expect(theme.roles.toSet(), hasLength(4));
      expect(theme.customReflectionQuestions, hasLength(3));
      expect(
        theme.customReflectionQuestions.every(
          (question) => question.trim().isNotEmpty,
        ),
        isTrue,
      );
      expect(theme.auditNotes, hasLength(4));
      expect(theme.auditNotes.every((note) => note.trim().isNotEmpty), isTrue);
      for (final role in theme.roles) {
        expect(role.split('\n').first.trim(), isNotEmpty);
        expect(role, contains('目的：'));
        expect(role, contains('秘密：'));
      }
    }
  });

  test('全テーマのplaceが重複していない', () {
    final places = etudeThemes.map((theme) => theme.place).toList();
    expect(places.toSet(), hasLength(places.length));
  });

  test('監査済みテーマは2人の中心役と専用振り返りを持つ', () {
    final theme = etudeThemes.singleWhere((item) => item.place == '閉店直前の喫茶店');

    expect(theme.audited, isTrue);
    expect(theme.roles.take(2).every((role) => role.contains('傘')), isTrue);
    expect(theme.roles[2], contains('貸出規則'));
    expect(theme.roles[3], contains('傘立て'));
    expect(theme.customReflectionQuestions.last, contains('謝罪の言葉を使わず'));
  });

  test('駅前の相乗りテーマは役と場所が一致する', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '終電後の駅前タクシー乗り場',
    );

    expect(theme.audited, isTrue);
    expect(theme.roles.take(2).every((role) => role.contains('社員')), isTrue);
    expect(theme.roles[2], contains('深夜帰宅補助'));
    expect(theme.roles[3], contains('タクシー運転手'));
    expect(theme.constraint, contains('最初の1分間'));
  });

  test('引っ越しテーマは人数が増えても全員が決定材料を持つ', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '同居を解消する前夜の空き部屋',
    );

    expect(theme.audited, isTrue);
    expect(theme.roles.take(2).every((role) => role.contains('同居人')), isTrue);
    expect(theme.roles[2], contains('宛名'));
    expect(theme.roles[3], contains('一週間預かれる'));
    expect(theme.constraint, contains('箱を開けたり動かしたりしない'));
  });

  test('教室の伝言テーマは伝言の出所が一つで役割が矛盾しない', () {
    final theme = etudeThemes.singleWhere((item) => item.place == '放課後の教室');

    expect(theme.audited, isTrue);
    expect(theme.roles.where((role) => role.contains('書いた本人')), hasLength(1));
    expect(theme.roles[2], contains('伝言を見つけた生徒'));
    expect(theme.roles[3], contains('隣の席の生徒'));
    expect(theme.constraint, '誰の名前も呼ばない');
  });

  test('会議室の弁当テーマは全役が異なる判断を提示する', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '午後の会議が始まる直前の会議室',
    );

    expect(theme.audited, isTrue);
    expect(theme.roles[0], contains('自分が受け取り'));
    expect(theme.roles[1], contains('後輩へ'));
    expect(theme.roles[2], contains('受取人を決め'));
    expect(theme.roles[3], contains('弁当を残し'));
    expect(theme.constraint, contains('相手が必要とする理由を一度尋ねる'));
  });

  test('病院の取り違えテーマは医療情報を公開せず本人確認できる', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '診察室前の待合スペース',
    );

    expect(theme.audited, isTrue);
    expect(theme.roles.take(2).every((role) => role.contains('患者')), isTrue);
    expect(theme.roles[2], contains('付き添い'));
    expect(theme.roles[3], contains('受付番号票'));
    expect(theme.constraint, contains('病名や受診理由を口にせず'));
    expect(theme.situation, contains('同じ名字'));
  });

  test('雨のバス停テーマは傘と全役の行動が関係修復につながる', () {
    final theme = etudeThemes.singleWhere((item) => item.place == '雨宿り中のバス停');

    expect(theme.audited, isTrue);
    expect(theme.roles.take(2).every((role) => role.contains('一緒に帰')), isTrue);
    expect(theme.roles[2], contains('迎えに来るよう連絡'));
    expect(theme.roles[3], contains('貸し傘'));
    expect(theme.constraint, contains('物の渡し方や立ち位置'));
    expect(theme.customReflectionQuestions.first, contains('傘'));
  });

  test('コインランドリーのテーマは衣装の所有者と混在原因が一貫する', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '早朝のコインランドリー',
    );

    expect(theme.audited, isTrue);
    expect(theme.roles[0], contains('約束の衣装'));
    expect(theme.roles[1], isNot(contains('衣装の本当の持ち主')));
    expect(theme.roles[2], contains('置き場所を取り違えた'));
    expect(theme.roles[3], contains('衣装を受け取り'));
    expect(theme.constraint, contains('色・形・用途'));
  });

  test('図書館テーマは追加役が対立を即時解決せず判断材料を変える', () {
    final theme = etudeThemes.singleWhere((item) => item.place == '閉館前の図書館');

    expect(theme.audited, isTrue);
    expect(theme.roles[0], contains('誕生日プレゼント'));
    expect(theme.roles[1], contains('翌日の読書会'));
    expect(theme.roles[2], contains('入力し忘れた'));
    expect(theme.roles[3], contains('読書会は延期'));
    expect(theme.roles[3], isNot(contains('同じ本を一冊')));
    expect(theme.constraint, contains('題名や著者名を言わず'));
  });

  test('パン屋テーマは数量と各役の解決材料が矛盾しない', () {
    final theme = etudeThemes.singleWhere((item) => item.place == '開店20分前のパン屋');

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('24個'), contains('14個')));
    expect(theme.roles[0], contains('店長のミス'));
    expect(theme.roles[1], contains('24個を14個'));
    expect(theme.roles[2], contains('別の商品'));
    expect(theme.roles[3], contains('必要数は20個'));
    expect(theme.constraint, contains('各自が解決案を一つ出す'));
  });

  test('公園の鍵テーマは持ち主の特定後も家族の選択が残る', () {
    final theme = etudeThemes.singleWhere((item) => item.place == '早朝の公園のベンチ');

    expect(theme.audited, isTrue);
    expect(theme.roles[0], contains('最も確実な返し方'));
    expect(theme.roles[1], allOf(contains('親'), contains('家の鍵')));
    expect(theme.roles[2], contains('個人情報を守りながら'));
    expect(theme.roles[2], contains('本人の許可なく伝えられない'));
    expect(theme.roles[3], contains('正式に預かる'));
    expect(theme.constraint, contains('全員ベンチから離れない'));
  });

  test('家族写真テーマは2人から4人まで中央の椅子に関わる', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '久しぶりに家族が集まった実家の居間',
    );

    expect(theme.audited, isTrue);
    expect(theme.roles[0], contains('弟・妹に中央'));
    expect(theme.roles[1], contains('兄・姉こそ中央'));
    expect(theme.roles[2], allOf(contains('実家を売り'), contains('中央')));
    expect(theme.roles[3], allOf(contains('撮影タイマー'), contains('居間')));
    expect(theme.constraint, contains('椅子や自分の立ち位置'));
    expect(theme.customReflectionQuestions.first, contains('中央の椅子'));
  });

  test('残業オフィスの差し入れテーマは匿名性と処分期限が両立する', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '消灯時刻が近い残業中のオフィス',
    );

    expect(theme.audited, isTrue);
    expect(theme.roles[0], contains('相手の案を自分の成果'));
    expect(theme.roles[1], contains('メモの筆跡'));
    expect(theme.roles[2], contains('送り主を言わないと約束'));
    expect(theme.roles[3], contains('アレルギー事故'));
    expect(theme.roles[3], isNot(contains('購入者がA')));
    expect(theme.constraint, contains('一度だけ具体的に認める'));
  });

  test('文化祭の案内板テーマは用途と安全条件が競合する', () {
    final theme = etudeThemes.singleWhere((item) => item.place == '文化祭前日の体育館');

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('矢印が逆向き'), contains('大型案内板')));
    expect(theme.roles[0], contains('背景幕を破って'));
    expect(theme.roles[1], contains('案内板の数が足りない'));
    expect(theme.roles[2], allOf(contains('古い会場図'), contains('耐水塗料')));
    expect(theme.roles[3], allOf(contains('避難口'), contains('許可できない')));
    expect(theme.constraint, contains('提案には必ず理由を一つ添える'));
  });

  test('コンビニテーマは未精算商品を規則内の選択肢だけで扱う', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '通勤客が増え始めた朝のコンビニ',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('会計中'), contains('取り消す')));
    expect(theme.roles[0], contains('引っ越し荷物'));
    expect(theme.roles[1], contains('未精算の商品は渡さず'));
    expect(theme.roles[2], contains('規則に沿って'));
    expect(theme.roles[3], contains('正規に代金を支払う'));
    expect(theme.constraint, contains('商品を置く・戻す・渡す動作'));
  });

  test('旅館の靴テーマは二足を見分ける手掛かりと手紙が矛盾しない', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '出発客が集まり始めた旅館の共同玄関',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('同じ型・同じサイズ'), contains('二足')));
    expect(theme.roles[0], contains('家族から借りた'));
    expect(theme.roles[1], contains('中敷き'));
    expect(theme.roles[2], contains('番号札'));
    expect(theme.roles[3], allOf(contains('宛名を書かず'), contains('Bの靴')));
    expect(theme.constraint, startsWith('靴を履かず'));
  });

  test('歯科医院テーマは個人的目的と診療優先度を分離する', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '診療終了が近い歯科医院の受付',
    );

    expect(theme.audited, isTrue);
    expect(theme.roles[0], allOf(contains('翌日の転居'), contains('鍵')));
    expect(theme.roles[1], allOf(contains('歯の痛み'), contains('必要な連絡以外')));
    expect(theme.roles[2], contains('推測で伝えることはできない'));
    expect(theme.roles[3], allOf(contains('受付で診断はせず'), contains('残り一枠')));
    expect(theme.constraint, contains('今の希望'));
    expect(theme.constraint, contains('境界'));
  });

  test('「お小遣い精算前のリビング」は家族内の小さな疑惑と仲裁を描く', () {
    final theme = etudeThemes.singleWhere(
      (item) =>
          item.place == '毎週日曜のお小遣い精算まで20分に迫った、手伝いポイント表が貼られた自宅リビングの壁掛けカレンダー前',
    );

    expect(theme.audited, isTrue);
    expect(theme.roles[0], contains('見慣れないシール'));
    expect(theme.roles[1], contains('皿洗いができず'));
    expect(theme.roles[2], contains('集計ルールが曖昧'));
    expect(theme.roles[3], contains('こっそり皿洗いをして'));
    expect(theme.constraint, contains('買い出しに出発する予定'));
  });

  test('ごみ置き場テーマは持ち主だけを責めず共同原因を扱う', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '収集車が去った後のマンションごみ置き場',
    );

    expect(theme.audited, isTrue);
    expect(theme.roles[0], contains('自分がごみ置き場へ動かした'));
    expect(theme.roles[1], contains('お知らせが一日ずれていた'));
    expect(theme.roles[2], allOf(contains('袋の持ち主'), contains('古い案内')));
    expect(theme.roles[3], contains('施錠区画が故障中'));
    expect(theme.constraint, allOf(contains('袋を開けず'), contains('決めつけず')));
  });

  test('空港テーマは二重手配と同姓同名を安全に確認する', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '国際線の空港到着ロビー',
    );

    expect(theme.audited, isTrue);
    expect(theme.roles[0], contains('ホームステイ'));
    expect(theme.roles[1], contains('企業研修'));
    expect(theme.roles[2], allOf(contains('旅客情報を公開せず'), contains('同姓同名')));
    expect(theme.roles[3], allOf(contains('二重手配'), contains('自分で決めたい')));
    expect(theme.constraint, allOf(contains('外見だけで決めつけず'), contains('各自')));
  });

  test('日常ジャンル200件の個別監査が完了している', () {
    final dailyThemes = etudeThemes.where((theme) => theme.genre == '日常');
    expect(dailyThemes, hasLength(200));
    expect(dailyThemes.every((theme) => theme.audited), isTrue);
  });

  test('高級レストランテーマは提供前のリハーサル内で指揮を争う', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '開店前の高級レストラン厨房',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, contains('盛り付けリハーサル'));
    expect(theme.roles[0], contains('高級店で働くのは今日が初めて'));
    expect(theme.roles[1], contains('正式な代理任命だと受け取った'));
    expect(theme.roles[2], allOf(contains('フードスタイリスト'), contains('誤解')));
    expect(theme.roles[3], allOf(contains('オーナー'), contains('事情をすべて知る')));
    expect(theme.constraint, allOf(contains('造語'), contains('即興で説明')));
  });

  test('静かな図書館テーマは新旧の合言葉と伝言制約が一致する', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '静かな読書時間中の図書館',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, contains('紫のカバが三冊目を借りた'));
    expect(theme.roles[0], allOf(contains('紫のカバ'), contains('助詞')));
    expect(theme.roles[1], contains('緑のキリンが二冊返した'));
    expect(theme.roles[2], contains('借りた」か「返した'));
    expect(theme.roles[3], contains('更新を伝え忘れた'));
    expect(theme.constraint, allOf(contains('各自一度だけ'), contains('ささやき声')));
  });

  test('オンライン説明会テーマは個別端末が必要なまま同室で連携する', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '取引先とのオンライン説明会5分前の小会議室',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('同じ企業用背景'), contains('個別端末')));
    expect(theme.roles[0], contains('全体進行'));
    expect(theme.roles[1], allOf(contains('個別録画'), contains('試作品')));
    expect(theme.roles[2], allOf(contains('逐次通訳'), contains('ミュート順')));
    expect(theme.roles[3], contains('予約システム移行'));
    expect(theme.constraint, contains('カメラ越しの呼びかけだけ'));
  });

  test('二つの披露宴テーマは関係を曖昧にする理由と照合手段がある', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '二つの披露宴が同時に始まる式場の受付前',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, contains('案内板が入れ替わり'));
    expect(theme.roles[0], allOf(contains('旧姓'), contains('会場案内の写真')));
    expect(theme.roles[1], allOf(contains('ゲーム内の呼び名'), contains('本名')));
    expect(theme.roles[2], contains('個人情報を大声で読み上げず'));
    expect(theme.roles[3], allOf(contains('受付番号'), contains('左右逆')));
    expect(theme.constraint, 'お祝いという言葉を使わない');
  });

  test('動かないエレベーターテーマは全員が階数を押さない理由を持つ', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '引っ越し作業中のマンションのエレベーター内',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('30秒'), contains('非常呼出ボタン')));
    expect(theme.secret, '誰も階数ボタンを押していない');
    expect(theme.roles[0], allOf(contains('8階'), contains('押してくれる')));
    expect(theme.roles[1], contains('すでに選択済み'));
    expect(theme.roles[2], allOf(contains('12階をお願いします'), contains('返事')));
    expect(theme.roles[3], contains('押し忘れ'));
    expect(theme.constraint, allOf(contains('別の故障原因'), contains('確かめる方法')));
  });

  test('社内職場テーマは弁当取り違えの勘違いコメディを扱う', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '本社ビル5階、社員食堂横の共用大型冷蔵庫前、昼休み開始8分前',
    );

    expect(theme.audited, isTrue);
    expect(theme.roles[0], contains('同じメーカーの弁当箱'));
    expect(theme.roles[1], contains('特製弁当'));
    expect(theme.roles[2], contains('三つの弁当箱'));
    expect(theme.roles[3], contains('人の弁当を勝手に処分'));
    expect(theme.constraint, contains('残り8分'));
  });

  test('健康診断テーマはコース別案内を同僚の記憶だけで決めない', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '会社の集団健康診断が始まる5分前の受付待合室',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('異なる検査コース'), contains('服薬')));
    expect(theme.secret, allOf(contains('最後まで読んでおらず'), contains('コースごと')));
    expect(theme.roles[0], contains('別のコースへ変更'));
    expect(theme.roles[1], allOf(contains('前年分'), contains('受付へ確認')));
    expect(theme.roles[2], contains('通知タイトルだけ'));
    expect(theme.roles[3], allOf(contains('コース番号'), contains('未開封')));
    expect(theme.constraint, contains('これは自分の記憶です'));
  });

  test('無人駅テーマは存在しない列車と最終バスの判断材料が分かれる', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '最終列車が出た後の山あいの無人駅ホーム',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('臨時快速'), contains('8分後')));
    expect(theme.secret, allOf(contains('携帯スピーカー'), contains('この駅には停車していない')));
    expect(theme.roles[0], allOf(contains('前年'), contains('日付部分')));
    expect(theme.roles[1], allOf(contains('南口'), contains('逆方向')));
    expect(theme.roles[2], allOf(contains('運行を終えて'), contains('ベンチの裏')));
    expect(theme.roles[3], contains('翌日ではなく今日'));
    expect(theme.constraint, contains('正確な地名か路線名'));
  });

  test('ペットショップテーマは通訳を観察可能な閉店確認へ置き換える', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == 'シャッターを半分下ろした閉店直後のペットショップ',
    );

    expect(theme.audited, isTrue);
    expect(theme.secret, allOf(contains('観察から作った即興'), contains('三項目')));
    expect(theme.roles[0], allOf(contains('展示スペースへ入れず'), contains('点検')));
    expect(theme.roles[1], allOf(contains('本当に言葉が分かるわけではなく'), contains('即興')));
    expect(theme.roles[2], allOf(contains('給水器'), contains('照明タイマー')));
    expect(theme.roles[3], allOf(contains('引継ぎ票'), contains('置き場所')));
    expect(theme.constraint, contains('根拠となる動きか音'));
  });

  test('家族裁判テーマはプリンの移し替えと移動を別々の証拠で追える', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '家族映画が始まる10分前の居間',
    );

    expect(theme.audited, isTrue);
    expect(theme.secret, allOf(contains('蓋付きマグ'), contains('ドアポケット')));
    expect(theme.roles[0], allOf(contains('空の容器'), contains('決めつけた')));
    expect(theme.roles[1], allOf(contains('ひび'), contains('中段')));
    expect(theme.roles[2], allOf(contains('ドアポケット'), contains('中身を確認していない')));
    expect(theme.roles[3], allOf(contains('写真'), contains('蓋付きマグ')));
    expect(theme.constraint, allOf(contains('見た事実'), contains('自分の推測')));
  });

  test('朝礼テーマは三つの締め言葉が発言済みでも未決定と分かる', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '全校朝礼の放送5分前の職員室',
    );

    expect(theme.audited, isTrue);
    expect(theme.secret, allOf(contains('三案'), contains('後で決める')));
    expect(theme.roles[0], allOf(contains('最初の案'), contains('二案目')));
    expect(theme.roles[1], allOf(contains('二番目の案'), contains('三番目')));
    expect(theme.roles[2], allOf(contains('三案すべて'), contains('後日決定')));
    expect(theme.roles[3], allOf(contains('決まったふりをせず'), contains('全部忘れ')));
    expect(theme.constraint, contains('どこで見たか・聞いたか'));
  });

  test('キャンプ場テーマはテント不足を認めて安全な宿泊方法を選べる', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == 'レンタル受付終了20分前のキャンプ場管理棟',
    );

    expect(theme.audited, isTrue);
    expect(
      theme.situation,
      allOf(contains('雨'), contains('共同ロッジ'), contains('中止')),
    );
    expect(theme.secret, contains('誰も宿泊用テントを持ってきていない'));
    expect(theme.roles[0], allOf(contains('サイト利用料'), contains('場所だけ')));
    expect(theme.roles[1], allOf(contains('寝袋'), contains('テント')));
    expect(theme.roles[2], allOf(contains('一度も開けておらず'), contains('日よけ用')));
    expect(theme.roles[3], allOf(contains('二人用'), contains('全員分')));
    expect(theme.constraint, contains('足りない物を一つ明確に認める'));
  });

  test('教育実習生の勘違いが引き起こす学校コメディを扱うテーマ', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '教育実習最終日、研究授業の開始12分前に用意された特別棟2階の実習生控室',
    );

    expect(theme.audited, isTrue);
    expect(theme.roles[0], contains('指導案を急遽刷り直した'));
    expect(theme.roles[1], contains('名前を書類に書き間違えた'));
    expect(theme.roles[2], contains('巡回時間を1つ勘違いしており'));
    expect(theme.roles[3], contains('隣のクラスへ間違えて配達'));
    expect(theme.constraint, contains('貸し借りした教材を元の教室へ'));
  });

  test('空港ポーチテーマは開けずに外側の証拠から届け先を決める', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '空港の手荷物検査場へ入る前の荷物整理台',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('12分'), contains('開けたり持ち去ったりせず')));
    expect(theme.secret, allOf(contains('空の見本'), contains('運搬カート')));
    expect(theme.roles[0], allOf(contains('管理ラベル'), contains('荷造り')));
    expect(theme.roles[1], allOf(contains('赤い引き手'), contains('ホテル')));
    expect(theme.roles[2], allOf(contains('見本コード'), contains('箱を閉め忘れ')));
    expect(theme.roles[3], allOf(contains('開けさせず'), contains('所定の窓口')));
    expect(theme.constraint, contains('外から確認できる印か記録'));
  });

  test('新商品会議テーマは隣室資料を性能の根拠にせず正式商品へ戻る', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '新商品サンプル到着15分前の企画会議室',
    );

    expect(theme.audited, isTrue);
    expect(theme.secret, allOf(contains('睡眠用クッション'), contains('折りたたみ傘')));
    expect(theme.roles[0], allOf(contains('雨の日を軽く'), contains('五案')));
    expect(theme.roles[1], allOf(contains('包まれる休息'), contains('ファイル名')));
    expect(theme.roles[2], allOf(contains('梅雨売場'), contains('幅8センチ')));
    expect(theme.roles[3], allOf(contains('商品コード'), contains('吸水ケース')));
    expect(theme.constraint, allOf(contains('平易な日本語'), contains('確定しない')));
  });

  test('美容院テーマは同じ表示名でも予約コードと施術内容で照合する', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '開店直後の美容院の待合席',
    );

    expect(theme.audited, isTrue);
    expect(theme.secret, allOf(contains('正規の同時予約'), contains('なりすましでもない')));
    expect(theme.roles[0], allOf(contains('A17'), contains('前髪カット')));
    expect(theme.roles[1], allOf(contains('B42'), contains('舞台用ヘアセット')));
    expect(theme.roles[2], allOf(contains('到着順'), contains('確認画面')));
    expect(theme.roles[3], allOf(contains('二席'), contains('予約コード')));
    expect(
      theme.constraint,
      allOf(contains('本名を聞いたり言ったりせず'), contains('施術内容')),
    );
  });

  test('防災訓練テーマは実通知を確認したら訓練演技を止める', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '町内会の防災訓練が始まった公民館前',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('試験放送'), contains('訓練ではありません')));
    expect(theme.secret, allOf(contains('裏面'), contains('この町内')));
    expect(theme.roles[0], allOf(contains('訓練中止'), contains('表面だけ')));
    expect(theme.roles[1], allOf(contains('発信元'), contains('一度消した')));
    expect(theme.roles[2], allOf(contains('川沿い区間'), contains('待機')));
    expect(theme.roles[3], allOf(contains('試験放送を止め'), contains('同じ時刻')));
    expect(theme.constraint, allOf(contains('未確認'), contains('演技を続けない')));
  });

  test('生放送テーマは新番組名を確認して旧ジングル前に訂正する', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '昼の生放送が始まって2分の地域ラジオ局ブース',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('まちの昼休み'), contains('まちのよりみち')));
    expect(theme.secret, allOf(contains('正式決定'), contains('旧題のまま')));
    expect(theme.roles[0], allOf(contains('旧題の印刷台本'), contains('短く訂正')));
    expect(theme.roles[1], allOf(contains('出演依頼'), contains('別コーナー名')));
    expect(theme.roles[2], allOf(contains('代替音'), contains('新題のファイルがなく')));
    expect(theme.roles[3], allOf(contains('正式な改題メール'), contains('確定連絡')));
    expect(theme.constraint, allOf(contains('ただいま確認中です'), contains('話を渡す')));
  });

  test('ホテルテーマは外見で招待作家を決めず通常予約と分けて照合する', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '文学イベント開催日のホテルフロント',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('G18'), contains('E24')));
    expect(theme.secret, allOf(contains('招待作家'), contains('イベント受付')));
    expect(theme.roles[0], allOf(contains('G18'), contains('新刊見本')));
    expect(theme.roles[1], allOf(contains('E24'), contains('内緒にしてください')));
    expect(theme.roles[2], allOf(contains('服装欄'), contains('次の行')));
    expect(theme.roles[3], allOf(contains('確認記録'), contains('カーディガン')));
    expect(theme.constraint, allOf(contains('外見や本名を根拠にせず'), contains('確認記録')));
  });

  test('卒業カードテーマは公開同意を確認し傘の手掛かりで宛先を絞る', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '卒業式後の読み上げ会が終わった教室',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('読み上げ可'), contains('青い傘')));
    expect(theme.secret, allOf(contains('白い糸'), contains('差出人と宛名')));
    expect(theme.roles[0], allOf(contains('文化祭の朝'), contains('顔をよく見ていない')));
    expect(theme.roles[1], allOf(contains('卒業式の練習日'), contains('日付')));
    expect(theme.roles[2], allOf(contains('読み上げ可'), contains('後ろ向き')));
    expect(theme.roles[3], allOf(contains('作者だと名乗り'), contains('返事を求める')));
    expect(theme.constraint, allOf(contains('根拠'), contains('間違いかもしれない理由')));
  });

  test('コメディジャンル200件の個別監査が完了している', () {
    final comedyThemes = etudeThemes.where((theme) => theme.genre == 'コメディ');

    expect(comedyThemes, hasLength(200));
    expect(comedyThemes.every((theme) => theme.audited), isTrue);
  });

  test('実家の家具テーマは共同保管一枠と売却時の誤解を分けて扱う', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '解体前夜、家具だけが残る実家の居間',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('30分後'), contains('食卓・本棚・足踏みミシン')));
    expect(theme.secret, allOf(contains('売却に同意'), contains('任せる')));
    expect(theme.roles[0], allOf(contains('修繕費'), contains('売りたくなかった')));
    expect(theme.roles[1], allOf(contains('食卓'), contains('費用や保管')));
    expect(theme.roles[2], allOf(contains('本棚'), contains('許可を得ないまま')));
    expect(theme.roles[3], allOf(contains('一つだけ'), contains('作業を止めていた')));
    expect(theme.constraint, allOf(contains('思い出'), contains('具体的な動作')));
  });

  test('閉校テーマは教師の進路と黒板写真の公開範囲を推測で決めない', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '閉校記録の撮影20分前、最後の授業を終えた教室',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('一枚だけ'), contains('個人名')));
    expect(theme.secret, allOf(contains('転任を断り'), contains('学習室')));
    expect(theme.roles[0], allOf(contains('問い'), contains('週一回')));
    expect(theme.roles[1], allOf(contains('学校名を下書き'), contains('確かめていない')));
    expect(theme.roles[2], allOf(contains('掲載同意'), contains('個人名')));
    expect(theme.roles[3], allOf(contains('再利用'), contains('まだ')));
    expect(theme.constraint, allOf(contains('未来形'), contains('下書きを一つ消す')));
  });

  test('病院面会テーマは本人の伝言と家族の希望を分けて順番を決める', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '面会時間終了後、病室前の夜間待機スペース',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('一人ずつ5分'), contains('意思を確認')));
    expect(theme.secret, allOf(contains('入るか帰るか'), contains('責めないで')));
    expect(theme.roles[0], allOf(contains('入る・待つ・帰る'), contains('後悔する')));
    expect(theme.roles[1], allOf(contains('音声伝言'), contains('本人の確認')));
    expect(theme.roles[2], allOf(contains('自分の不安'), contains('知らない')));
    expect(theme.roles[3], allOf(contains('病状を説明せず'), contains('指定されていない')));
    expect(theme.constraint, allOf(contains('沈黙を二度'), contains('自分の希望')));
  });

  test('退職日の引継ぎテーマは知識・権限・人員不足を分けて扱う', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '退職者のアカウント停止45分前のオフィス',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('承認権限'), contains('二人体制')));
    expect(theme.secret, allOf(contains('退職時の条件'), contains('合意')));
    expect(theme.roles[0], allOf(contains('共有文書'), contains('返却')));
    expect(theme.roles[1], allOf(contains('一人で対応できる'), contains('経験がない')));
    expect(theme.roles[2], allOf(contains('三か所空欄'), contains('検証')));
    expect(theme.roles[3], allOf(contains('一時停止'), contains('二人目')));
    expect(theme.constraint, contains('具体的な引継ぎ行動'));
  });

  test('乾物屋テーマは閉店と継業を巡る家族の決断を扱う', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '不動産業者の到着まで20分、三代続いた乾物屋の帳場',
    );

    expect(theme.audited, isTrue);
    expect(theme.roles[0], contains('緑内障が進行'));
    expect(theme.roles[1], contains('自分の逃げ場'));
    expect(theme.roles[2], contains('継ぎたいと祖母に申し出て'));
    expect(theme.roles[3], contains('よろけたりする様子'));
    expect(theme.constraint, contains('賃貸契約解除の書類'));
  });

  test('雪の駅テーマは手紙を受け取るかと読む時期を相手が選べる', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '雪で運転を止めた駅の待合室',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('代行バス'), contains('一年前')));
    expect(theme.secret, allOf(contains('謝罪でも告白でもなく'), contains('季節ごと')));
    expect(theme.roles[0], allOf(contains('断られても'), contains('一年間')));
    expect(theme.roles[1], allOf(contains('同意ではない'), contains('録音しては消し')));
    expect(theme.roles[2], allOf(contains('推測を撤回'), contains('今日きっと謝られる')));
    expect(theme.roles[3], allOf(contains('18分後'), contains('25分後')));
    expect(theme.constraint, allOf(contains('受け取るか'), contains('後で読むか')));
  });

  test('閉店後の店テーマは義務的支払い後の利益だけを三案へ配分する', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '最後のシャッターを下ろした家族経営のパン屋',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('税金'), contains('三回限定')));
    expect(theme.secret, allOf(contains('三回だけ'), contains('継承を迫る')));
    expect(theme.roles[0], allOf(contains('出店枠'), contains('三回で終える')));
    expect(theme.roles[1], allOf(contains('ウェブページ'), contains('常設店を継がない')));
    expect(theme.roles[2], allOf(contains('一回だけ'), contains('別の店')));
    expect(theme.roles[3], allOf(contains('確保済み'), contains('六か月')));
    expect(theme.constraint, allOf(contains('お金の額を言わず'), contains('伝票')));
  });

  test('海辺の駐車場テーマは二人が別の場所で待った事実と現在の希望を分ける', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '夕暮れの岬に残る新旧二つの海辺の駐車場',
    );

    expect(theme.audited, isTrue);
    expect(
      theme.situation,
      allOf(contains('上段'), contains('下段'), contains('今後')),
    );
    expect(theme.secret, allOf(contains('二人とも'), contains('拒絶')));
    expect(theme.roles[0], allOf(contains('給油レシート'), contains('月に一度')));
    expect(theme.roles[1], allOf(contains('写真'), contains('一週間')));
    expect(theme.roles[2], allOf(contains('案内ミス'), contains('判断を待ち')));
    expect(theme.roles[3], allOf(contains('移設図'), contains('会話から退き')));
    expect(
      theme.constraint,
      allOf(contains('今わかっていること'), contains('これから望むこと')),
    );
  });

  test('空の部室テーマは見学者を入部済みにせず解散か保留を選ぶ', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '備品返却日の夕方、作品だけが残る写真部の部室',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('解散届'), contains('7日間')));
    expect(theme.secret, allOf(contains('活動を見てから'), contains('署名していない')));
    expect(theme.roles[0], allOf(contains('役割分担'), contains('疲れ')));
    expect(theme.roles[1], allOf(contains('入部済み'), contains('思い込み')));
    expect(theme.roles[2], allOf(contains('約束しない'), contains('週二回')));
    expect(
      theme.roles[3],
      allOf(contains('作品は解散後も保存'), contains('自動では存続できない')),
    );
    expect(theme.constraint, allOf(contains('言い換えて'), contains('戻せないこと')));
  });

  test('転院延期テーマは本人の選択と家族への共有範囲を本人が決める', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '面会時間終了後、転院案内を広げた病院ロビー',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('設備トラブル'), contains('3日')));
    expect(theme.secret, allOf(contains('すでに説明'), contains('自分で選んで')));
    expect(theme.roles[0], allOf(contains('体調の詳細は共有せず'), contains('別施設')));
    expect(theme.roles[1], allOf(contains('同意なしに'), contains('休暇')));
    expect(theme.roles[2], allOf(contains('本人へ直接'), contains('前夜')));
    expect(theme.roles[3], allOf(contains('許可した範囲'), contains('水道設備')));
    expect(theme.constraint, allOf(contains('確認した事実'), contains('共有してよい範囲')));
  });

  test('火事後の喫茶店テーマはノートの所有確認と閲覧許可を分ける', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '火事の翌日、喫茶店の外に設けられた返却品仕分け所',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('捜査対象外'), contains('一頁だけ')));
    expect(theme.secret, allOf(contains('元従業員'), contains('月一回')));
    expect(theme.roles[0], allOf(contains('火事の前'), contains('解約通知')));
    expect(theme.roles[1], allOf(contains('青い糸'), contains('予約も')));
    expect(theme.roles[2], allOf(contains('証言'), contains('運営は約束できない')));
    expect(theme.roles[3], allOf(contains('私物'), contains('破れる可能性')));
    expect(theme.constraint, allOf(contains('残った物'), contains('返す・保存する・試す')));
  });

  test('最終便テーマは片方の取消後も搭乗と共同案の使用を別々に決める', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '搭乗終了12分前、海外演劇研修へ向かう最終便の搭乗口',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('個別に採用'), contains('共同')));
    expect(theme.secret, allOf(contains('保安検査'), contains('自分の予約だけ')));
    expect(theme.roles[0], allOf(contains('単独発表'), contains('後日精算')));
    expect(theme.roles[1], allOf(contains('今夜出発'), contains('言語支援')));
    expect(theme.roles[2], allOf(contains('採用は個別'), contains('採用保証がない')));
    expect(theme.roles[3], allOf(contains('制限区域'), contains('確定できず')));
    expect(theme.constraint, allOf(contains('自分の決定'), contains('相手への依頼')));
  });

  test('表彰式テーマは貢献の証拠と正式な訂正審査を分ける', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '受賞記録の公開30分前、地域調査表彰式後の控室',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('公開の一時停止'), contains('訂正')));
    expect(theme.secret, allOf(contains('代表連絡者'), contains('校正')));
    expect(theme.roles[0], allOf(contains('共同要請'), contains('確かめず')));
    expect(theme.roles[1], allOf(contains('署名済み報告書'), contains('送信記録')));
    expect(theme.roles[2], allOf(contains('その他の貢献者'), contains('共有しなかった')));
    expect(theme.roles[3], allOf(contains('翌営業日'), contains('保証できない')));
    expect(theme.constraint, allOf(contains('確認できる事実'), contains('求める対応')));
  });

  test('グループホーム退去テーマは家族の決断と本人の尊厳を描く', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '退去の返事期限まで40分、認知症対応型グループホームの共同キッチン',
    );

    expect(theme.audited, isTrue);
    expect(theme.roles[0], contains('退職届を出しており'));
    expect(theme.roles[1], contains('担当替えの内示'));
    expect(theme.roles[2], contains('経営不振に陥っており'));
    expect(theme.roles[3], contains('この土地を離れようとした'));
    expect(theme.constraint, contains('次の入居希望者の内覧'));
  });

  test('夜明けの公園テーマは未贈与の指輪を返却物として扱わない', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '始発バスの25分前、照明のある夜明け前の駅前公園',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('持ち主別'), contains('未贈与')));
    expect(theme.secret, allOf(contains('所有物ではなく'), contains('意図的')));
    expect(theme.roles[0], allOf(contains('許可'), contains('確かめたくて')));
    expect(theme.roles[1], allOf(contains('鍵と本'), contains('購入明細')));
    expect(theme.roles[2], allOf(contains('カメラ'), contains('封を開け直した')));
    expect(theme.roles[3], allOf(contains('それぞれ譲渡'), contains('代用品')));
    expect(theme.constraint, allOf(contains('一度も渡していない物'), contains('持ち帰る')));
  });

  test('停電マンションテーマは本人の選択と状況変化時の支援を分ける', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '非常灯だけが点く停電中のマンション8階廊下',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('避難命令はなく'), contains('90分')));
    expect(theme.secret, allOf(contains('灯り'), contains('緊急連絡先')));
    expect(theme.roles[0], allOf(contains('自分で決め'), contains('更新を忘れた')));
    expect(theme.roles[1], allOf(contains('無理に連れ出さず'), contains('全員避難')));
    expect(theme.roles[2], allOf(contains('火災・ガス漏れなし'), contains('確約できない')));
    expect(theme.roles[3], allOf(contains('訓練済み複数人'), contains('同意なく')));
    expect(theme.constraint, allOf(contains('具体的に頼みたいこと'), contains('触れる前')));
  });

  test('合格発表テーマは本人が結果の受取方法と直後の過ごし方を選ぶ', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '結果掲示直後、充電案内所がある大学校門',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('合格'), contains('不合格')));
    expect(theme.secret, allOf(contains('画面を保存'), contains('隠すつもりはない')));
    expect(theme.roles[0], allOf(contains('進路相談'), contains('三度')));
    expect(theme.roles[1], allOf(contains('喜ぶ時間'), contains('裏切り')));
    expect(theme.roles[2], allOf(contains('別々の相談枠'), contains('本人の許可なく')));
    expect(theme.roles[3], allOf(contains('一人で見られる席'), contains('確定結果')));
    expect(theme.constraint, allOf(contains('今聞く'), contains('今ほしい')));
  });

  test('廃線列車テーマは二人が異なる下車駅を選んでも移動が成立する', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '思い出の駅まで4分、廃線当日の最終定期列車',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('45分後'), contains('20時30分')));
    expect(theme.secret, allOf(contains('町を離れ'), contains('鍵も返却済み')));
    expect(theme.roles[0], allOf(contains('終点まで'), contains('送別会')));
    expect(theme.roles[1], allOf(contains('一人で途中下車'), contains('記念切符')));
    expect(theme.roles[2], allOf(contains('停車は2分'), contains('出発後')));
    expect(theme.roles[3], allOf(contains('公開範囲'), contains('録音機も停止')));
    expect(theme.constraint, allOf(contains('路線図'), contains('一度だけ望む連絡')));
  });

  test('社員食堂テーマは個人情報を持ち出さず記録IDで原本保全を求める', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '給与確定前夜、営業を終えた誰もいない社員食堂',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('14件'), contains('原本保全')));
    expect(theme.secret, allOf(contains('一括承認'), contains('確認せず')));
    expect(theme.roles[0], allOf(contains('断定しない'), contains('送信前')));
    expect(theme.roles[1], allOf(contains('提出中止を求めず'), contains('見出しだけ')));
    expect(theme.roles[2], allOf(contains('4人'), contains('残る10件')));
    expect(theme.roles[3], allOf(contains('受付番号'), contains('保証できない')));
    expect(theme.constraint, allOf(contains('まだ不明な意図'), contains('記録ID')));
  });

  test('手術前テーマは医療同意と家族が担える生活支援を分ける', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '手術室への移動25分前、連絡先確認票が残る個室',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('説明と同意'), contains('海外転勤')));
    expect(theme.secret, allOf(contains('2週間前'), contains('明日の航空券')));
    expect(theme.roles[0], allOf(contains('連絡先を変更'), contains('確認せず')));
    expect(theme.roles[1], allOf(contains('転勤を取り消す'), contains('住居')));
    expect(theme.roles[2], allOf(contains('3日間'), contains('引き受けられない')));
    expect(theme.roles[3], allOf(contains('情報共有範囲'), contains('確定しておらず')));
    expect(theme.constraint, allOf(contains('できないこと'), contains('患者本人')));
  });

  test('路面電車のエコバッグ取り違えテーマは思い込みと善意を扱う', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '夕方の路面電車、最後尾車両の荷物置き場前(次の停留所まで5分)',
    );

    expect(theme.audited, isTrue);
    expect(theme.roles[0], contains('覚え違えており'));
    expect(theme.roles[1], contains('隣のフックへかけ直していた'));
    expect(theme.roles[2], contains('断りなく荷物置き場のバッグ'));
    expect(theme.roles[3], contains('荷物置き場も写り込んだ写真'));
    expect(theme.constraint, contains('快速区間に入り'));
  });

  test('停電ホテルテーマは正規の客室変更と紙台帳の転記漏れで解ける', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '22時18分、非常灯で巡回中の停電したホテル4階',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('21時30分'), contains('変更票')));
    expect(theme.secret, allOf(contains('21時52分'), contains('22時03分')));
    expect(theme.roles[0], allOf(contains('412を空室'), contains('早めに印刷')));
    expect(theme.roles[1], allOf(contains('鍵袋'), contains('荷物の一部')));
    expect(theme.roles[2], allOf(contains('20時30分'), contains('紙の整備板')));
    expect(theme.roles[3], allOf(contains('本人確認'), contains('防火訓練用')));
    expect(theme.constraint, allOf(contains('予約上の部屋'), contains('宿泊者名')));
  });

  test('閉館後の美術館テーマは原画移動と改稿前の複製品で解ける', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '18時25分、閉館後の展示室を映す美術館警備卓',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('17時42分'), contains('複製品番号')));
    expect(theme.secret, allOf(contains('18時06分'), contains('1984年')));
    expect(theme.roles[0], allOf(contains('18時12分'), contains('旧版B')));
    expect(theme.roles[1], allOf(contains('撮影可能'), contains('1972年')));
    expect(theme.roles[2], allOf(contains('承認'), contains('末尾B')));
    expect(theme.roles[3], allOf(contains('作者自身'), contains('色分け')));
    expect(theme.constraint, allOf(contains('作品へ触れず'), contains('盗難')));
  });

  test('雨の山荘テーマは欠けた案内頁と旧台本から誤封入だと解ける', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '道路と電話が使える、十年ぶりの朗読会当日の雨の山荘',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('2/2頁'), contains('1/2頁')));
    expect(theme.secret, allOf(contains('任意参加'), contains('給紙ミス')));
    expect(theme.roles[0], allOf(contains('いったん止め'), contains('演じた役')));
    expect(theme.roles[1], allOf(contains('差出人'), contains('頁確認')));
    expect(theme.roles[2], allOf(contains('一字一句'), contains('演出上追加')));
    expect(theme.roles[3], allOf(contains('道路・電話'), contains('一枚だけ')));
    expect(theme.constraint, allOf(contains('正確に引用'), contains('退出')));
  });

  test('始発前の駅テーマは写真の撮影時刻と公開予定日を分けて解く', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '始発15分前、透明ポケット付きの忘れ物鞄を預かる駅事務室',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('未開封'), contains('制作票')));
    expect(theme.secret, allOf(contains('4時08分'), contains('公開予定日')));
    expect(theme.roles[0], allOf(contains('防犯記録'), contains('監視')));
    expect(theme.roles[1], allOf(contains('公開同意'), contains('空白')));
    expect(theme.roles[2], allOf(contains('連絡票'), contains('候補から外し')));
    expect(theme.roles[3], allOf(contains('別管理'), contains('仮予定')));
    expect(theme.constraint, allOf(contains('鞄を開けず'), contains('複写・公開しない')));
  });

  test('学校放送室テーマは削除原稿を読む合成音声の予約で解ける', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '18時12分、無人だった学校放送室の操作卓',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('録音一覧にない'), contains('18時20分')));
    expect(theme.secret, allOf(contains('自動復元'), contains('合成音声')));
    expect(theme.roles[0], allOf(contains('再実行を停止'), contains('二回')));
    expect(theme.roles[1], allOf(contains('17時35分'), contains('17時50分')));
    expect(theme.roles[2], allOf(contains('24時間'), contains('適用していなかった')));
    expect(theme.roles[3], allOf(contains('17時55分'), contains('氏名はなく')));
    expect(theme.constraint, allOf(contains('ヘッドホン'), contains('会話前')));
  });

  test('深夜コンビニテーマは販売停止品の瓶返却コードだと解ける', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '0時40分、三夜続けて同じ客が来た深夜のコンビニ',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('コード7710'), contains('空き瓶返却')));
    expect(theme.secret, allOf(contains('販売コードとしては停止'), contains('18か月ない')));
    expect(theme.roles[0], allOf(contains('瓶返却だけ'), contains('次の便')));
    expect(theme.roles[1], allOf(contains('取り寄せを迫らず'), contains('亡くなった家族')));
    expect(theme.roles[2], allOf(contains('負額'), contains('返却専用')));
    expect(theme.roles[3], allOf(contains('洗浄前'), contains('再製造')));
    expect(theme.constraint, allOf(contains('金額の正負'), contains('返却瓶')));
  });

  test('病院記録室テーマは実患者と訓練番号の接頭辞欠落で解ける', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '外来開始30分前、二冊の出力記録を隔離した病院記録室',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('20417'), contains('統合せず')));
    expect(theme.secret, allOf(contains('P-20417'), contains('ダミー枠')));
    expect(theme.roles[0], allOf(contains('配布保留'), contains('綴じよう')));
    expect(theme.roles[1], allOf(contains('接頭辞'), contains('警告')));
    expect(theme.roles[2], allOf(contains('紙テンプレート'), contains('混合していない')));
    expect(theme.roles[3], allOf(contains('研修票'), contains('手順を飛ばし')));
    expect(theme.constraint, allOf(contains('記録A・記録B'), contains('診療内容')));
  });

  test('無人オフィステーマは共有受信箱の隔離解除による遅延配送で解ける', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '19時10分、無人のオフィスにある端末廃棄前の確認室',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('19時06分'), contains('隔離番号')));
    expect(theme.secret, allOf(contains('11日前'), contains('予約送信ではなく')));
    expect(theme.roles[0], allOf(contains('本文を読まない'), contains('確認一覧')));
    expect(theme.roles[1], allOf(contains('配送ヘッダー'), contains('オフボーディング')));
    expect(theme.roles[2], allOf(contains('Q-271'), contains('自動解除')));
    expect(theme.roles[3], allOf(contains('自分の名義'), contains('隔離照会')));
    expect(
      theme.constraint,
      allOf(contains('本文と添付を開かず'), contains('返信・転送・削除せず')),
    );
  });

  test('団地屋上テーマは二回の設備点検を示す椅子の合図で解ける', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '閉鎖20分前、管理人立会いで入った古い団地の屋上共用部',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('青と白'), contains('椅子を固定')));
    expect(theme.secret, allOf(contains('19時55分'), contains('22時05分')));
    expect(theme.roles[0], allOf(contains('自室ベランダ'), contains('不安を広げ')));
    expect(theme.roles[1], allOf(contains('一次点検'), contains('7日間')));
    expect(theme.roles[2], allOf(contains('固定する規則'), contains('資材置場')));
    expect(theme.roles[3], allOf(contains('翌日用'), contains('省略していない')));
    expect(theme.constraint, allOf(contains('隠れて待たず'), contains('入退室記録')));
  });

  test('どんど焼きの書き初め混同テーマは会場合同化の伝達ミスを扱う', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '小正月のどんど焼き、点火の号令まで20分に迫った、地域の空き地に積まれた正月飾りの山の前',
    );

    expect(theme.audited, isTrue);
    expect(theme.roles[0], contains('のお知らせを読み飛ばしており'));
    expect(theme.roles[1], contains('合流場所や時間を個別に連絡'));
    expect(theme.roles[2], contains('区別せず同じ束を分けて'));
    expect(theme.roles[3], contains('過去にも似た混同が一度あり'));
    expect(theme.constraint, contains('立会いは16時までしかなく'));
  });

  test('霧の港テーマは過去名簿を使った訓練の誤通知で解ける', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '濃霧で入港停止中、5時18分の誤通知を受けた港の旅客待合室',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('4年前に亡くなった'), contains('通知ID')));
    expect(theme.secret, allOf(contains('5時00分'), contains('実通知フラグ')));
    expect(theme.roles[0], allOf(contains('SIM-54'), contains('三つの運航記録')));
    expect(theme.roles[1], allOf(contains('迎えを待つつもりはない'), contains('桟橋')));
    expect(theme.roles[2], allOf(contains('架空連絡先'), contains('5時18分')));
    expect(theme.roles[3], allOf(contains('非識別'), contains('訓練用フォルダ')));
    expect(theme.constraint, allOf(contains('故人が亡くなっている'), contains('探しに出ない')));
  });

  test('骨董店テーマは年代の違う原本ではなく同じ写字者による閲覧用写本で解ける', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '閉店後、店主立会いで入る除湿設備付き骨董店地下整理室',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('紙の透かし'), contains('1996年')));
    expect(theme.secret, allOf(contains('閲覧用写本'), contains('祖母')));
    expect(theme.roles[0], allOf(contains('96-C12'), contains('外れ札')));
    expect(theme.roles[1], allOf(contains('手習い帳'), contains('日付入り')));
    expect(theme.roles[2], allOf(contains('1994年製造'), contains('検査室')));
    expect(
      theme.roles[3],
      allOf(contains('原本C12とC78'), contains('経路はまだ分からない')),
    );
    expect(theme.constraint, allOf(contains('本文を声に出さず'), contains('偽造を断定しない')));
  });

  test('同窓会写真テーマは合成の作業版を逆順再生した現象として解ける', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '片付け終了20分前、同窓会後の母校の教室',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('元画像4枚'), contains('編集レイヤー')));
    expect(theme.secret, allOf(contains('10秒タイマー'), contains('逆向き')));
    expect(theme.roles[0], allOf(contains('20時31分'), contains('20時24分')));
    expect(theme.roles[1], allOf(contains('自分も'), contains('確認しなかった')));
    expect(theme.roles[2], allOf(contains('20時38分'), contains('通常の集合写真')));
    expect(theme.roles[3], allOf(contains('EDIT-01'), contains('新しい順')));
    expect(theme.constraint, allOf(contains('自分の記憶'), contains('同意前')));
  });

  test('地下駐車場テーマは車両の複製ではなく後付け解錠装置の二重登録で解ける', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '警備員が二台を移動禁止にした商業施設の地下駐車場',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('車台番号末尾'), contains('設定票')));
    expect(theme.secret, allOf(contains('4821と6194'), contains('始動認証')));
    expect(theme.roles[0], allOf(contains('リモコンFA'), contains('誤って')));
    expect(theme.roles[1], allOf(contains('18時12分'), contains('開ける前')));
    expect(theme.roles[2], allOf(contains('17時46分'), contains('同時に映る')));
    expect(theme.roles[3], allOf(contains('同時に設定モード'), contains('個別に見ていなかった')));
    expect(theme.constraint, allOf(contains('エンジンをかけず'), contains('末尾4桁')));
  });

  test('渓谷遊歩道分岐点テーマは道標の伝達ミスと思い込みを扱う', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '台風一過の朝、倒木処理の作業班が集まる渓谷遊歩道の分岐点、通行止め解除まで25分',
    );

    expect(theme.audited, isTrue);
    expect(theme.roles[0], contains('応急的な目印の付け替え'));
    expect(theme.roles[1], contains('崖側の枝道を塞ぐため'));
    expect(theme.roles[2], contains('見落として登山客を案内'));
    expect(theme.roles[3], contains('遠藤さんの息子'));
    expect(theme.constraint, contains('25分後までに'));
  });

  test('新聞社資料庫テーマは翌日の防犯訓練を使った当日印刷の模擬紙面で解ける', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '閉室25分前、入退室記録のある新聞社資料庫',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('TR-071'), contains('製本穴')));
    expect(theme.secret, allOf(contains('模擬号外'), contains('当て紙')));
    expect(theme.roles[0], allOf(contains('16時48分'), contains('ひな型')));
    expect(theme.roles[1], allOf(contains('14時12分'), contains('匿名化')));
    expect(theme.roles[2], allOf(contains('三枚'), contains('架空名')));
    expect(theme.roles[3], allOf(contains('製本穴のない'), contains('表紙裏')));
    expect(theme.constraint, allOf(contains('実際の印刷時刻'), contains('外部発信しない')));
  });

  test('閉鎖病棟テーマは転棟後も旧受信盤に残った携帯呼出ボタンの登録で解ける', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '閉鎖翌日、職員立会いで忘れ物を受け取る旧病棟面会室',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('WB-204'), contains('解除欄の空白')));
    expect(theme.secret, allOf(contains('旧受信盤'), contains('応答済み')));
    expect(theme.roles[0], allOf(contains('15時20分'), contains('まだ見せていなかった')));
    expect(theme.roles[1], allOf(contains('内線'), contains('別に確認')));
    expect(theme.roles[2], allOf(contains('40秒以内'), contains('自動解除')));
    expect(theme.roles[3], allOf(contains('旧側だけ解除'), contains('運用終了')));
    expect(theme.constraint, allOf(contains('診断名'), contains('無断で触れない')));
  });

  test('海辺の無人交番テーマは次回点検日を現在日にした168時間の端末ずれで解ける', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '遠隔通話端末と封印ロッカーがある海辺の無人交番前',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('L-3'), contains('168時間')));
    expect(theme.secret, allOf(contains('7月30日11時25分'), contains('電池交換')));
    expect(theme.roles[0], allOf(contains('末尾7316'), contains('尋ねなかった')));
    expect(theme.roles[1], allOf(contains('10時43分'), contains('次回点検8月6日')));
    expect(theme.roles[2], allOf(contains('三件'), contains('受取予約')));
    expect(theme.roles[3], allOf(contains('受付停止'), contains('通信試験')));
    expect(theme.constraint, allOf(contains('完全な製造番号'), contains('遠隔職員')));
  });

  test('閉店写真館テーマは旧レタッチ室で露光済みだった手詰めフィルムの再露光で解ける', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '鍵返却30分前、閉店した写真館の受付兼スタジオ',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('R12-04'), contains('コンタクトシート')));
    expect(theme.secret, allOf(contains('手詰めフィルム'), contains('封印確認')));
    expect(theme.roles[0], allOf(contains('ネガ'), contains('顔も身体も判別できず')));
    expect(theme.roles[1], allOf(contains('露光済み・未現像'), contains('最後の一本')));
    expect(theme.roles[2], allOf(contains('reserve'), contains('付箋')));
    expect(theme.roles[3], allOf(contains('サービス通路'), contains('撤去済みか')));
    expect(theme.constraint, allOf(contains('12年前の潜像'), contains('許可なく')));
  });

  test('消えかけた魔法テーマは全員の避難を先に確保してから記憶を伴う使用を選ぶ', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '満潮42分前、最後の封印灯が消えかけた王宮西水門の指令室',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('住民63人'), contains('避難命令')));
    expect(theme.secret, allOf(contains('自伝的記憶'), contains('満潮10分前')));
    expect(theme.roles[0], allOf(contains('自分で決めたい'), contains('事前同意ではなく')));
    expect(theme.roles[1], allOf(contains('72人'), contains('状況が変わった')));
    expect(theme.roles[2], allOf(contains('点呼済み'), contains('すべて補償')));
    expect(theme.roles[3], allOf(contains('過去二例'), contains('証拠はなく')));
    expect(theme.constraint, allOf(contains('避難開始を先に'), contains('最後まで撤回')));
  });

  test('時間停止駅テーマは旅行者本人が分針を戻した後にだけ1988年への帰還が始まる', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '発車鐘の直前で時間が止まった駅の大時計前',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('起点印'), contains('巻鍵')));
    expect(theme.secret, allOf(contains('1988年'), contains('手荷物預かり所')));
    expect(theme.roles[0], allOf(contains('自分で選んだ'), contains('自分で分針')));
    expect(theme.roles[1], allOf(contains('一度だけ'), contains('切符を破れば')));
    expect(theme.roles[2], allOf(contains('過去三件'), contains('保証できない')));
    expect(theme.roles[3], allOf(contains('同じ場所で再会'), contains('手を止めて')));
    expect(theme.constraint, allOf(contains('現在時刻を言わず'), contains('戻す前')));
  });

  test('竜の図書館テーマは本を動かさず一族から図書館へ管理責任だけを返す', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '年に一度の頁送りまで砂時計三杯、竜の眠りの間に続く図書館防音前室',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('百年契約'), contains('遠隔頁送りレバー')));
    expect(theme.secret, allOf(contains('十二枚'), contains('九百年前')));
    expect(theme.roles[0], allOf(contains('17年間'), contains('血の条件')));
    expect(theme.roles[1], allOf(contains('二人一組'), contains('一年延ばし')));
    expect(theme.roles[2], allOf(contains('七呼吸'), contains('再試験')));
    expect(theme.roles[3], allOf(contains('罰金記録'), contains('自動生成')));
    expect(theme.constraint, allOf(contains('物理的な場所'), contains('鎖に触れず')));
  });

  test('月一市場テーマは同じ出来事の記憶でも二人が独立して交換可否を選ぶ', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '閉場の第三鐘まで砂時計一杯、月に一度だけ開く市場の記憶査定所',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('八年前'), contains('一人だけ交換')));
    expect(theme.secret, allOf(contains('一人称'), contains('復元できない')));
    expect(theme.roles[0], allOf(contains('二か月後'), contains('権利を失う')));
    expect(theme.roles[1], allOf(contains('三週間'), contains('家族も安全')));
    expect(theme.roles[2], allOf(contains('共有記憶'), contains('仲介料')));
    expect(theme.roles[3], allOf(contains('無償で取り置ける'), contains('正式に訂正')));
    expect(theme.constraint, allOf(contains('欲しい物の名前'), contains('一人ずつ撤回')));
  });

  test('雲の裁判テーマは上流を救った効果と下流被害・確認不足を分けて審理する', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '評決再開20分前、雲の上の天候裁判所の証拠整理室',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('12雲量'), contains('種子倉三棟')));
    expect(theme.secret, allOf(contains('音声確認'), contains('追加分の5')));
    expect(theme.roles[0], allOf(contains('琥珀表示'), contains('一度に')));
    expect(theme.roles[1], allOf(contains('常時二人体制'), contains('40分')));
    expect(theme.roles[2], allOf(contains('4分の1'), contains('必要雲量')));
    expect(theme.roles[3], allOf(contains('種子18箱'), contains('具体数')));
    expect(theme.constraint, allOf(contains('善悪を断定せず'), contains('書き換えない')));
  });

  test('声を失う森テーマは一人が退出し一人が解除可能な番人見習いへ進む', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '案内鐘まで30分、声を失う森の西の分かれ道',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('出口まで20分'), contains('30日間')));
    expect(theme.secret, allOf(contains('守り輪'), contains('毎朝')));
    expect(theme.roles[0], allOf(contains('白標'), contains('二人分')));
    expect(theme.roles[1], allOf(contains('七日後'), contains('試用期間')));
    expect(theme.roles[2], allOf(contains('印刷板'), contains('途中退出')));
    expect(theme.roles[3], allOf(contains('食事と寝床'), contains('共有されていなかった')));
    expect(theme.constraint, allOf(contains('沈黙を同意'), contains('非常鈴')));
  });

  test('夢倉庫テーマは共同悪夢を確定予言にせず現実の冷却棚を先に閉鎖する', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '自動処分審査まで25分、夢を保管する倉庫の隔離閲覧室',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('N-404'), contains('亀裂2枚')));
    expect(theme.secret, allOf(contains('一つの分岐'), contains('30日隔離')));
    expect(theme.roles[0], allOf(contains('棚Cを直ちに閉鎖'), contains('一週間前')));
    expect(theme.roles[1], allOf(contains('別区画'), contains('まだ選んでいない')));
    expect(theme.roles[2], allOf(contains('一名欄'), contains('三日前')));
    expect(theme.roles[3], allOf(contains('5枚のうち2枚'), contains('緊急連絡')));
    expect(theme.constraint, allOf(contains('冒頭三像'), contains('棚Cへ入らない')));
  });

  test('沈む空中都市テーマは一人用の翼と整備カプセルで師弟二人が脱出する', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '嵐層へ入るまで35分、避難済みの空中都市中央設計工房',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('救助船へ8分'), contains('下降10分')));
    expect(theme.secret, allOf(contains('羽根がすべて消え'), contains('自動投棄')));
    expect(theme.roles[0], allOf(contains('緊急投棄口'), contains('40年分')));
    expect(theme.roles[1], allOf(contains('重要図面12枚'), contains('未完成案')));
    expect(theme.roles[2], allOf(contains('214人'), contains('共同札')));
    expect(theme.roles[3], allOf(contains('四基中三基'), contains('記録していなかった')));
    expect(theme.constraint, allOf(contains('受け入れられる経路'), contains('二人で乗らず')));
  });

  test('最後の夜の浜辺テーマは海の民の恒久選択と人間の一時訪問を分ける', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '日の出まで45分、一生に一度の陸上試行が終わる潮境浜の守り輪',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('何もしなければ海の姿'), contains('六時間用')));
    expect(theme.secret, allOf(contains('取り消せず'), contains('永住を意味しない')));
    expect(theme.roles[0], allOf(contains('半年見習い'), contains('友人がいなくても')));
    expect(theme.roles[1], allOf(contains('月に一度'), contains('家族と仕事')));
    expect(theme.roles[2], allOf(contains('無回答'), contains('権限がなく')));
    expect(theme.roles[3], allOf(contains('時間内の浮上'), contains('安全試験に落ちた')));
    expect(theme.constraint, allOf(contains('相手に求めないこと'), contains('所有者以外')));
  });

  test('記憶喫茶テーマは同じ公演の記憶でも脈印で客と店員の所有を分ける', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '閉店の記憶仕分けまで25分、記憶を売る喫茶店の封印席',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('24時間保留'), contains('K-17')));
    expect(theme.secret, allOf(contains('店員本人'), contains('A-09')));
    expect(theme.roles[0], allOf(contains('開演から終演まで'), contains('最後に礼')));
    expect(theme.roles[1], allOf(contains('30日隔離'), contains('最後の外出')));
    expect(theme.roles[2], allOf(contains('自動仕分けを停止'), contains('配膳後')));
    expect(theme.roles[3], allOf(contains('新しい同意'), contains('旧様式')));
    expect(theme.constraint, allOf(contains('所有者を決めつけず'), contains('所有者以外')));
  });

  test('名前預かり門テーマは旧い登録名を本人の真の名前と決めつけない', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '閉門まで30分、七日間の記録審理へ続く名前預かり門',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('私書札'), contains('待機宿')));
    expect(theme.secret, allOf(contains('現在用いる名前ではなく'), contains('復元される')));
    expect(theme.roles[0], allOf(contains('申立人'), contains('旧い登録名')));
    expect(theme.roles[1], allOf(contains('記録運搬人'), contains('記録漏えい')));
    expect(theme.roles[2], allOf(contains('緑灯'), contains('案内板を訂正')));
    expect(theme.roles[3], allOf(contains('記録訂正の権利'), contains('無効化')));
    expect(theme.constraint, allOf(contains('代読せず'), contains('本人以外')));
  });

  test('逆さ川テーマは一人が昨日の自分へ警告して帰還する案と現在の修復を比べる', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '逆潮の出航まで35分、昨日へ流れる川の保護された船着場',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('16時05分'), contains('12分後')));
    expect(theme.secret, allOf(contains('一人分'), contains('誰かが消えることはない')));
    expect(theme.roles[0], allOf(contains('16時00分'), contains('取水輪')));
    expect(theme.roles[1], allOf(contains('15時50分'), contains('点検札')));
    expect(theme.roles[2], allOf(contains('昨日の本人'), contains('今朝追記')));
    expect(theme.roles[3], allOf(contains('113枚'), contains('六週間')));
    expect(theme.constraint, allOf(contains('罪悪感だけで'), contains('二人目')));
  });

  test('星修理工房テーマは測定値で打上げを決め工房終了後の師弟の進路を分ける', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '星返し窓まで42分、最後の星を修理する工房の打上げ室',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('光度72以上'), contains('七日後')));
    expect(theme.secret, allOf(contains('職人が消えるわけではない'), contains('自己修復')));
    expect(theme.roles[0], allOf(contains('記録整理職'), contains('二週間前')));
    expect(theme.roles[1], allOf(contains('計器値'), contains('保守職')));
    expect(theme.roles[2], allOf(contains('沿岸船12隻'), contains('新暦')));
    expect(theme.roles[3], allOf(contains('翌月まで'), contains('旧住所')));
    expect(theme.constraint, allOf(contains('三つの異なる比喩'), contains('基準外')));
  });

  test('嘘の町テーマは放送時の未確認一人を根拠付きで訂正して西門を開ける', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '薬荷車の到着まで35分、巨大な文字が塞ぐ嘘の町の西門',
    );

    expect(theme.audited, isTrue);
    expect(
      theme.situation,
      allOf(contains('確認済みだったのは285人'), contains('18時12分')),
    );
    expect(theme.secret, allOf(contains('偽りと知る断定'), contains('五分')));
    expect(theme.roles[0], allOf(contains('18時00分'), contains('子どもたち')));
    expect(theme.roles[1], allOf(contains('286番'), contains('仮丸')));
    expect(theme.roles[2], allOf(contains('一時停止'), contains('あらゆる会話')));
    expect(theme.roles[3], allOf(contains('18時25分'), contains('12分残り')));
    expect(theme.constraint, allOf(contains('嘘みたいだが'), contains('善意を事実の代わり')));
  });

  test('死者の郵便局テーマは未来の自己便と待っていたきょうだいの未着便を分ける', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '最終仕分けまで30分、死者の手紙を扱う郵便局の返時窓口',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('R-41'), contains('30日保管')));
    expect(theme.secret, allOf(contains('18年分の加齢環'), contains('未来分岐')));
    expect(theme.roles[0], allOf(contains('仮仕分け票'), contains('取り消す')));
    expect(theme.roles[1], allOf(contains('今夜を最後'), contains('書面')));
    expect(theme.roles[2], allOf(contains('被災した預入台帳'), contains('三日前')));
    expect(theme.roles[3], allOf(contains('受取例が七件'), contains('教材訂正')));
    expect(
      theme.constraint,
      allOf(contains('差出人の名を読まず'), contains('R-41の代わり')),
    );
  });

  test('四季会議テーマは春の精霊の存続を多数決にせず修理案と比較する', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '年間案の本会議まで40分、四季を決める暦庁の予備会議室',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('余分な季節力24単位'), contains('五日間試験')));
    expect(theme.secret, allOf(contains('不可逆'), contains('四者全員')));
    expect(theme.roles[0], allOf(contains('8単位の修理'), contains('報告を遅らせた')));
    expect(theme.roles[1], allOf(contains('0日案を撤回'), contains('旧見積')));
    expect(theme.roles[2], allOf(contains('残り2'), contains('全備蓄')));
    expect(theme.roles[3], allOf(contains('40％'), contains('十日前')));
    expect(theme.constraint, allOf(contains('別の季節'), contains('単純多数')));
  });

  test('境界分けの儀式テーマは若木の発見と分配の合意形成を扱う', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '百年に一度の「境界分け」の儀式開始まで30分、東西の村境に立つ賽の実の大樹の下',
    );

    expect(theme.audited, isTrue);
    expect(theme.roles[0], contains('賽の実を東村のために'));
    expect(theme.roles[1], contains('西村側の蓄えが例年より'));
    expect(theme.roles[2], contains('自分から話すことが許されていない'));
    expect(theme.roles[3], contains('境界林への立ち入りを求める声'));
    expect(theme.constraint, contains('大樹を囲う結界が閉じて'));
  });

  test('王の寝室テーマは双方同意と自動帰還を備え誓文の仮説を夢で試す', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '入夢窓が閉じるまで30分、四夜休めない王の保護された寝室',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('八時間停止'), contains('最長12分')));
    expect(theme.secret, allOf(contains('立場が逆転'), contains('本心や治癒を証明しない')));
    expect(theme.roles[0], allOf(contains('合議会へ委任'), contains('文案')));
    expect(theme.roles[1], allOf(contains('現実の命令権'), contains('予備観察')));
    expect(theme.roles[2], allOf(contains('九分で予告'), contains('一日遅れた')));
    expect(theme.roles[3], allOf(contains('八時間だけ停止'), contains('百年前')));
    expect(theme.constraint, allOf(contains('「眠り」'), contains('診断として断定しない')));
  });

  test('世界端の灯台テーマは自動返信を避け一方向通知後に棚を補強する', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '返信窓まで40分、世界の端の亀裂棚に立つ遮光灯台',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('住民312人'), contains('九日分')));
    expect(theme.secret, allOf(contains('共鳴荷重18'), contains('耐荷重は22')));
    expect(theme.roles[0], allOf(contains('琥珀通知'), contains('一か月前')));
    expect(theme.roles[1], allOf(contains('内陸中継所'), contains('一度試そう')));
    expect(theme.roles[2], allOf(contains('現在10'), contains('書面だけ')));
    expect(theme.roles[3], allOf(contains('三回で返信要求'), contains('誤訳')));
    expect(theme.constraint, allOf(contains('遮光戸'), contains('試さない')));
  });

  test('願い忘れの泉テーマは両立しない将来と各自が飲む選択を分ける', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '泉が閉じるまで30分、長い旅の終点にある願い忘れの水場',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('二年間の単独調査'), contains('30日後')));
    expect(theme.secret, allOf(contains('そのままでは両立しない'), contains('他人の考えも変えず')));
    expect(theme.roles[0], allOf(contains('自分で開く'), contains('仮記入')));
    expect(theme.roles[1], allOf(contains('自分の進路'), contains('仮採用')));
    expect(theme.roles[2], allOf(contains('不可逆'), contains('古い案内板')));
    expect(theme.roles[3], allOf(contains('七日以内'), contains('相互通知欄')));
    expect(theme.constraint, allOf(contains('最後に各自一度'), contains('沈黙')));
  });

  test('地域写真展テーマは撮影と用途別の公開同意を分けて撤回できる', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '開場まで30分、地域写真展の受付裏にある作品交換台',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('オンライン公開停止'), contains('8分')));
    expect(theme.secret, allOf(contains('本人へ見せず'), contains('私的な一枚')));
    expect(theme.roles[0], allOf(contains('用途ごと'), contains('応募締切')));
    expect(theme.roles[1], allOf(contains('公開は撤回'), contains('表情は気に入っている')));
    expect(theme.roles[2], allOf(contains('違約金なし'), contains('追加確認')));
    expect(theme.roles[3], allOf(contains('内部確認紙'), contains('二枚')));
    expect(theme.constraint, allOf(contains('「せっかく」'), contains('沈黙')));
  });

  test('料理番組テーマは四つの封印ボウルを根拠で識別し味見しない', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '生放送まで20分、料理番組セット裏の封印ボウル置き場',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('D12'), contains('12分')));
    expect(theme.secret, allOf(contains('混入は起きていない'), contains('中身当て企画')));
    expect(theme.roles[0], allOf(contains('道具紹介'), contains('黄色い蓋')));
    expect(theme.roles[1], allOf(contains('専用器具'), contains('左右反転')));
    expect(theme.roles[2], allOf(contains('最大15分'), contains('四つの謎')));
    expect(theme.roles[3], allOf(contains('撮影用品庫'), contains('前日のもの')));
    expect(theme.constraint, allOf(contains('「これに違いない」'), contains('味見')));
  });

  test('閉館映画館テーマは建物の判断と映像資料の保存を分ける', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '管理鍵の封印まで45分、閉館した町の映画館の映写室',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('五日で速報'), contains('差額180万円')));
    expect(theme.secret, allOf(contains('拘束力のない'), contains('資料館へ移せ')));
    expect(theme.roles[0], allOf(contains('一か月の維持費'), contains('七日以内')));
    expect(theme.roles[1], allOf(contains('助成相談'), contains('来春')));
    expect(theme.roles[2], allOf(contains('解体日'), contains('館内設備一式')));
    expect(theme.roles[3], allOf(contains('フィルム86巻'), contains('六週間')));
    expect(theme.constraint, allOf(contains('「家族なら」'), contains('立入禁止')));
  });

  test('七夕祭りの短冊紛失テーマは思い込みと善意の行き違いを扱う', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '七夕まつり開始30分前、短冊を吊るす笹飾りが並ぶ児童館ホール',
    );

    expect(theme.audited, isTrue);
    expect(theme.roles[0], contains('他の短冊と混同している'));
    expect(theme.roles[1], contains('屋根側の笹に短冊をまとめて'));
    expect(theme.roles[2], contains('自分の判断で結び直していた'));
    expect(theme.roles[3], contains('笹の配置を入れ替えており'));
    expect(theme.constraint, contains('本人の許可なく読み上げ'));
  });

  test('誓約記録院テーマは加護と自立をめぐる対話的解決を扱う', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '刻限まで45分、誓約記録院の書き換え受付窓口',
    );

    expect(theme.audited, isTrue);
    expect(theme.roles[0], contains('守りの誓約'));
    expect(theme.roles[1], contains('ひそかに鍛錬'));
    expect(theme.roles[2], contains('円満に解消された記録'));
    expect(theme.roles[3], contains('戦乱から守るための一時しのぎ'));
    expect(theme.constraint, contains('次の申請機会は15年後'));
  });

  test('防音練習室テーマは有効な二重予約と設備要件を組み替える', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '利用開始まで25分、市民会館の防音練習室前',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('18時から20時'), contains('電子ピアノ')));
    expect(theme.secret, allOf(contains('どちらも有効'), contains('12分')));
    expect(theme.roles[0], allOf(contains('二場面'), contains('一週間前')));
    expect(theme.roles[1], allOf(contains('入退場'), contains('部屋番号')));
    expect(theme.roles[2], allOf(contains('A-184'), contains('紙台帳')));
    expect(theme.roles[3], allOf(contains('可動机'), contains('一階倉庫')));
    expect(theme.constraint, allOf(contains('本人に'), contains('終了時刻')));
  });

  test('効果音卓テーマは一列ずれた表示を安全に検証して笑いへ変える', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '公開収録まで18分、ラジオドラマの効果音卓',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('馬が走った'), contains('紙の対応表')));
    expect(theme.secret, allOf(contains('一列ずれている'), contains('6分')));
    expect(theme.roles[0], allOf(contains('Q12'), contains('二行即興')));
    expect(theme.roles[1], allOf(contains('F31'), contains('左右反対')));
    expect(theme.roles[2], allOf(contains('Q18'), contains('二日前')));
    expect(theme.roles[3], allOf(contains('再起動'), contains('最初のパッド')));
    expect(theme.constraint, allOf(contains('二人で確認'), contains('言い換わる')));
  });

  test('生垣テーマは隣人と親子の継承と和解を扱う', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '造園業者到着15分前、二軒の境界に沿って伸びる生垣の前',
    );

    expect(theme.audited, isTrue);
    expect(theme.roles[0], contains('縁まで切れてしまう気がして'));
    expect(theme.roles[1], contains('密かに不満を抱えていた'));
    expect(theme.roles[2], contains('伐採費用が当初の倍'));
    expect(theme.roles[3], contains('継ぐつもりがない'));
    expect(theme.constraint, contains('15分以内に'));
  });

  test('梅干し作りテーマは数の食い違いを善意の行動と伝え忘れで解く', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '土用干し三日目の昼、干し台の梅の実が減っていることに気づいた実家の縁側',
    );

    expect(theme.audited, isTrue);
    expect(theme.roles[0], contains('こっそり味見をして食べてしまい'));
    expect(theme.roles[1], contains('寝ぼけていて記憶に自信が持てず'));
    expect(theme.roles[2], contains('水滴の反射を虫と見間違えた'));
    expect(theme.roles[3], contains('友人の体調を案じて味見用に'));
    expect(theme.constraint, contains('夕立が来るとされる17時まで'));
  });

  test('香油商組合の献上品審査を巡る代用原料の発覚と対応を扱うテーマ', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '香油商組合の調香台、王宮献上品審査まで25分',
    );

    expect(theme.audited, isTrue);
    expect(theme.roles[0], contains('安価な代用香油で水増し'));
    expect(theme.roles[1], contains('会計係へこっそり相談'));
    expect(theme.roles[2], contains('組合の借金返済に流用'));
    expect(theme.roles[3], contains('別の組合の不正を見逃した'));
    expect(theme.constraint, contains('サンプル瓶は残り3本'));
  });

  test('飼育小屋テーマは当番表を巡る委員会内の対立を扱う', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '下校時刻15分前、夏休み前の小学校飼育小屋',
    );

    expect(theme.audited, isTrue);
    expect(theme.roles[0], contains('家族の帰省で1週間'));
    expect(theme.roles[1], contains('毛アレルギーが悪化'));
    expect(theme.roles[2], contains('うさぎを逃がしかけた'));
    expect(theme.roles[3], contains('うさぎを増やす計画'));
    expect(theme.constraint, contains('引き継ぎノート提出まで15分'));
  });

  test('王冠テーマは豪華さでなくコードと用途から第一場用を選ぶ', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '公開稽古まで20分、王冠が四つ並ぶ小道具調整台',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('C-04'), contains('装着確認票')));
    expect(theme.secret, allOf(contains('420グラム'), contains('発泡素材')));
    expect(theme.roles[0], allOf(contains('王冠なし'), contains('取材')));
    expect(theme.roles[1], allOf(contains('退場箱'), contains('一対一')));
    expect(theme.roles[2], allOf(contains('階段移動'), contains('登場場面順')));
    expect(theme.roles[3], allOf(contains('980グラム'), contains('注意')));
    expect(theme.constraint, allOf(contains('底面コード'), contains('実際にかぶらず')));
  });

  test('共同創作テーマは即興台詞と私的体験と表記の同意を分ける', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '企画応募まで60分、共同創作劇の台本確定室',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('12分'), contains('共同創作者表記')));
    expect(theme.secret, allOf(contains('48時間以内'), contains('上演されたくない')));
    expect(theme.roles[0], allOf(contains('七行'), contains('演出家だけ')));
    expect(theme.roles[1], allOf(contains('宣伝'), contains('創作を壊す')));
    expect(theme.roles[2], allOf(contains('共同表記版'), contains('語順')));
    expect(theme.roles[3], allOf(contains('未確定'), contains('応募枠')));
    expect(
      theme.constraint,
      allOf(contains('「みんなで作ったから」'), contains('最終決定期限')),
    );
  });

  test('レコード店テーマは伝達ミスによる誤解の解消を扱う', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '常連客への受け渡し30分前、老舗レコード店の試聴コーナー',
    );

    expect(theme.audited, isTrue);
    expect(theme.roles[0], contains('湿気対策のため保管棚'));
    expect(theme.roles[1], contains('色違い盤に変更してほしい'));
    expect(theme.roles[2], contains('返品コーナーだと思い込み'));
    expect(theme.roles[3], contains('同型番のケース'));
    expect(theme.constraint, contains('棚の記録と伝票'));
  });

  test('記憶夜船テーマは共同記憶の同意と代替経路を分ける', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '出航まで40分、島へ渡る記憶夜船の待合所',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('12時間'), contains('二時間')));
    expect(theme.secret, allOf(contains('思い出す入口'), contains('同意印')));
    expect(theme.roles[0], allOf(contains('歌唱技能'), contains('平気なふり')));
    expect(theme.roles[1], allOf(contains('絆の証明'), contains('先に書いて')));
    expect(theme.roles[2], allOf(contains('未署名'), contains('簡略')));
    expect(theme.roles[3], allOf(contains('90分'), contains('無償変更')));
    expect(theme.constraint, allOf(contains('沈黙'), contains('熱意不足')));
  });

  test('隣接練習室テーマは台詞と台の振動を測定値で分ける', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '利用終了まで35分、市民会館の隣接する二つの練習室',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('63デシベル'), contains('14デシベル')));
    expect(theme.secret, allOf(contains('49デシベル'), contains('45デシベル')));
    expect(theme.roles[0], allOf(contains('着席稽古'), contains('一週間前')));
    expect(theme.roles[1], allOf(contains('20時40分'), contains('一時間')));
    expect(theme.roles[2], allOf(contains('無料の10分延長'), contains('過去の利用記録')));
    expect(theme.roles[3], allOf(contains('全脚'), contains('先月')));
    expect(theme.constraint, allOf(contains('感覚だけ'), contains('廊下')));
  });

  test('献血ルームのピンバッジ取り違えから広がる行き違いを描くテーマ', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '駅前献血ルームの休憩コーナー、次の受付番号が呼ばれるまでの13分間',
    );

    expect(theme.audited, isTrue);
    expect(theme.roles[0], contains('注射が大の苦手'));
    expect(theme.roles[1], contains('50回目の献血を達成'));
    expect(theme.roles[2], contains('働き始めて三日目'));
    expect(theme.roles[3], contains('なぜ自分には記念品がないのか'));
    expect(theme.constraint, contains('13分間はこの休憩コーナーから動けない'));
  });

  test('免許返納ドライブテーマは家族の世代交代を扱う', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '運転免許返納の手続きまで50分、祖父が運転する最後のドライブ中の家族の乗用車内',
    );

    expect(theme.audited, isTrue);
    expect(theme.roles[0], contains('軽い接触事故'));
    expect(theme.roles[1], contains('内心ホッとしている'));
    expect(theme.roles[2], contains('物忘れが増えている'));
    expect(theme.roles[3], contains('祖父の運転で救われた'));
    expect(theme.constraint, contains('残り信号3つ'));
  });

  test('演出ノートテーマは別置された折り畳み図を32頁と特定する', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '展示公開まで40分、演劇資料館の演出ノート展示台',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('M-32A'), contains('挟込一枚')));
    expect(theme.secret, allOf(contains('頁は抜かれていない'), contains('裏面線')));
    expect(theme.roles[0], allOf(contains('寄贈時写真'), contains('取材者')));
    expect(theme.roles[1], allOf(contains('31頁と33頁'), contains('備考欄')));
    expect(theme.roles[2], allOf(contains('低角度写真'), contains('五年前')));
    expect(theme.roles[3], allOf(contains('作成時刻'), contains('連番撮影')));
    expect(theme.constraint, allOf(contains('物理的な枚数'), contains('開かず')));
  });

  test('名前鍵の宿テーマは予約名と本人が選ぶ鍵名を分ける', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '日付が変わるまで45分、名前を部屋鍵にする巡演宿の受付',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('囁き室'), contains('通常宿')));
    expect(theme.secret, allOf(contains('八時間'), contains('最初に本人が選ぶ名')));
    expect(theme.roles[0], allOf(contains('公開台帳'), contains('以前別の宿')));
    expect(theme.roles[1], allOf(contains('宿票の訂正'), contains('旅程表')));
    expect(theme.roles[2], allOf(contains('作動表示'), contains('例外許可')));
    expect(theme.roles[3], allOf(contains('代理設定不可'), contains('三か月前')));
    expect(theme.constraint, allOf(contains('出生名を尋ねたり'), contains('代理')));
  });

  test('共同住宅の退去テーマは既存損傷と清掃と棚補修を分ける', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '退去確認まで50分、荷物を出した共同住宅の台所',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('保証金6万円'), contains('2000円')));
    expect(theme.secret, allOf(contains('W-03'), contains('各2万3000円')));
    expect(theme.roles[0], allOf(contains('全額負担'), contains('相手の箱')));
    expect(theme.roles[1], allOf(contains('6000円ずつ'), contains('透明テープ')));
    expect(theme.roles[2], allOf(contains('返金明細'), contains('一桁')));
    expect(theme.roles[3], allOf(contains('強度試験'), contains('在庫')));
    expect(theme.constraint, allOf(contains('既存損傷'), contains('退去理由')));
  });

  test('駅の同型ケーステーマは逆の引換票を外装記録で訂正する', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '列車出発まで20分、同じ黒いケースが並ぶ駅の手荷物窓口',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('6.2キロ'), contains('橙色')));
    expect(theme.secret, allOf(contains('X-41'), contains('最大5分')));
    expect(theme.roles[0], allOf(contains('中空素材'), contains('自信満々')));
    expect(theme.roles[1], allOf(contains('予備電源二台'), contains('購入記録')));
    expect(theme.roles[2], allOf(contains('旧票を無効化'), contains('印刷ボタン')));
    expect(theme.roles[3], allOf(contains('時刻入り写真'), contains('プライバシー')));
    expect(theme.constraint, allOf(contains('開封'), contains('職業')));
  });

  test('同居解消後の犬テーマは六週間の移行計画と長期案を分ける', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '相談終了まで45分、動物病院の家族相談室',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('30日後'), contains('10泊')));
    expect(theme.secret, allOf(contains('週4日'), contains('試泊記録')));
    expect(theme.roles[0], allOf(contains('登録名義だけ'), contains('医療費')));
    expect(theme.roles[1], allOf(contains('面会'), contains('申請書')));
    expect(theme.roles[2], allOf(contains('判断項目'), contains('登録者だけ')));
    expect(theme.roles[3], allOf(contains('10泊連続'), contains('一週間前')));
    expect(theme.constraint, allOf(contains('本当に大事なら'), contains('永久')));
  });

  test('地域祭り会計テーマは電子決済と移した釣銭を一度ずつ数える', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '会計報告まで35分、地域祭り本部の施錠された精算室',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('8万6000円'), contains('F-10')));
    expect(theme.secret, allOf(contains('電子決済2万円'), contains('16時45分')));
    expect(theme.roles[0], allOf(contains('実測'), contains('緑色')));
    expect(theme.roles[1], allOf(contains('マイナス1万円'), contains('口頭連絡')));
    expect(theme.roles[2], allOf(contains('入金予定日'), contains('20分')));
    expect(theme.roles[3], allOf(contains('封印番号'), contains('同じ時刻')));
    expect(theme.constraint, allOf(contains('鞄'), contains('同じ1万円')));
  });

  test('天候時計テーマは雨量を変えず果樹園と公演の時刻を調整する', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '日没まで45分、町の雨雲を管理する天候時計室',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('12ミリ'), contains('21時30分')));
    expect(theme.secret, allOf(contains('一度変更'), contains('120人')));
    expect(theme.roles[0], allOf(contains('20時15分'), contains('五日前')));
    expect(theme.roles[1], allOf(contains('23時'), contains('昨日')));
    expect(theme.roles[2], allOf(contains('一度'), contains('四日前')));
    expect(theme.roles[3], allOf(contains('移動25分'), contains('仮押さえ')));
    expect(theme.constraint, allOf(contains('芸術か作物か'), contains('沈黙')));
  });

  test('旧劇団宛て荷物テーマは受領記録を戻し営業所受取へ変える', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '集荷窓口終了まで30分、共同稽古スタジオの受付',
    );

    expect(theme.audited, isTrue);
    expect(theme.situation, allOf(contains('P-72'), contains('営業所受取')));
    expect(theme.secret, allOf(contains('15分以内'), contains('20時')));
    expect(theme.roles[0], allOf(contains('注文番号'), contains('そのまま確定')));
    expect(theme.roles[1], allOf(contains('施錠棚'), contains('善意')));
    expect(theme.roles[2], allOf(contains('16時40分'), contains('表示更新')));
    expect(theme.roles[3], allOf(contains('封印番号'), contains('宛名不一致')));
    expect(theme.constraint, allOf(contains('通電'), contains('訂正番号')));
  });

  test('ラジオ紹介原稿テーマは承認本文と用途別の追記を分ける', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '生放送開始まで18分、地域ラジオ局の読み合わせブース',
    );

    expect(theme.audited, isTrue);
    expect(
      theme.situation,
      allOf(contains('45秒'), contains('V3'), contains('80字以内')),
    );
    expect(theme.secret, allOf(contains('78字'), contains('みずき・れん')));
    expect(theme.roles[0], allOf(contains('版番号V3'), contains('大げさに読んだ')));
    expect(theme.roles[1], allOf(contains('ポルタ'), contains('謙遜する予定')));
    expect(theme.roles[2], allOf(contains('試験表示'), contains('14時18分')));
    expect(theme.roles[3], allOf(contains('用途別'), contains('全国優勝級')));
    expect(theme.constraint, allOf(contains('腹話術を笑いの対象にしない'), contains('速口')));
  });

  test('獅子舞保存会の道具引き渡しと世代交代を描くシリアステーマ', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '引き取りトラック到着まで25分、後継者が途絶えた獅子舞保存会の道具蔵',
    );

    expect(theme.audited, isTrue);
    expect(theme.roles[0], contains('譲渡を言い出したのは自分'));
    expect(theme.roles[1], contains('獅子舞の型を独学で'));
    expect(theme.roles[2], contains('後継者が二人しかおらず'));
    expect(theme.roles[3], contains('補助金申請を試みた'));
    expect(theme.constraint, contains('トラックが到着するまで25分'));
  });

  test('きのこ狩りテーマは善意の勘違いによる混乱を扱う', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == 'きのこ狩りツアーの下山後、鑑定士到着まで15分の集荷小屋前',
    );

    expect(theme.audited, isTrue);
    expect(theme.roles[0], contains('タマゴタケが減っている気がして'));
    expect(theme.roles[1], contains('名前タグを外してしまった'));
    expect(theme.roles[2], contains('洗濯ばさみに変えていた'));
    expect(theme.roles[3], contains('夢中で採ったクリタケ'));
    expect(theme.constraint, contains('ラベルのないきのこ'));
  });

  test('種蒔きの儀式で誓いの言葉の書き換えを扱うテーマ', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '献納の鐘が鳴るまで25分、丘の上に建つ「種守りの塔」誓いの間',
    );

    expect(theme.audited, isTrue);
    expect(theme.roles[0], contains('分かち合う』に書き換えた'));
    expect(theme.roles[1], contains('言葉は時代に合わせて変えてよい'));
    expect(theme.roles[2], contains('二代前の飢饉の年に一度だけ書き換えられた'));
    expect(theme.roles[3], contains('婚姻同盟の話も進める'));
    expect(theme.constraint, contains('献納の鐘が鳴る前に確定させねば'));
  });

  test('還暦祝いの宴で家族の対立と和解を描くテーマ', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '祖父の還暦祝いの宴が始まる25分前、料亭の座敷',
    );

    expect(theme.audited, isTrue);
    expect(theme.roles[0], contains('サプライズで次男を会場に呼んだ'));
    expect(theme.roles[1], contains('家業を巡る言い争い'));
    expect(theme.roles[2], contains('予約と取り違えており'));
    expect(theme.roles[3], contains('借金をすでに全額返済'));
    expect(theme.constraint, contains('乾杯まで25分'));
  });

  test('宣伝写真テーマは個人用の中央指定と集合用G-1を分ける', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == 'スタジオ終了まで28分、二人芝居の宣伝写真撮影',
    );

    expect(theme.audited, isTrue);
    expect(
      theme.situation,
      allOf(contains('S-A'), contains('S-B'), contains('G-1')),
    );
    expect(theme.secret, allOf(contains('1200ピクセル'), contains('6000×4000')));
    expect(theme.roles[0], allOf(contains('左60センチ'), contains('六回')));
    expect(theme.roles[1], allOf(contains('右60センチ'), contains('競っている自覚')));
    expect(theme.roles[2], allOf(contains('solo'), contains('六往復')));
    expect(theme.roles[3], allOf(contains('完成見本'), contains('個人用')));
    expect(theme.constraint, allOf(contains('容姿'), contains('一人を切って')));
  });

  test('遺品パソコンのロック解除を巡る家族と継母の葛藤を扱うテーマ', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '遺品整理業者到着まで30分、亡き父のノートパソコンだけが残る書斎',
    );

    expect(theme.audited, isTrue);
    expect(theme.roles[0], contains('大げんかをしたことを今も後悔'));
    expect(theme.roles[1], contains('借金の申し出を断った'));
    expect(theme.roles[2], contains('パスワードを知っており'));
    expect(theme.roles[3], contains('パソコンを開けずに処分してしまい'));
    expect(theme.constraint, contains('専門業者への解錠依頼'));
  });

  test('青い傘の写真テーマは五本目をM-2に映るU-1の反射として解く', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '入稿まで35分、青い傘が五本写った宣伝写真の編集室',
    );

    expect(theme.audited, isTrue);
    expect(
      theme.situation,
      allOf(contains('C-17'), contains('U-1〜U-4'), contains('M-2')),
    );
    expect(theme.secret, allOf(contains('14時12分'), contains('22.5度')));
    expect(theme.roles[0], allOf(contains('K-1'), contains('K-2')));
    expect(theme.roles[1], allOf(contains('透明棚'), contains('三日月形')));
    expect(theme.roles[2], allOf(contains('反射経路'), contains('映込み')));
    expect(theme.roles[3], allOf(contains('RAW一枚'), contains('縦長トリミング')));
    expect(theme.constraint, allOf(contains('個人の鞄'), contains('固定済み')));
  });

  test('種蔵の契約は伝承の誤読を証拠と対話で正す過程を扱う', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '日の出の鐘まで40分、来年の契約を更新する村の共同種蔵',
    );

    expect(theme.audited, isTrue);
    expect(theme.roles[0], contains('手放したくないという私心'));
    expect(theme.roles[1], contains('父の代からの誤訳'));
    expect(theme.roles[2], contains('精霊との契約という物語'));
    expect(theme.roles[3], contains('神秘的に信じており'));
    expect(theme.constraint, contains('日の出の鐘が鳴るまでに'));
  });

  test('稽古映像テーマは誤公開を止め同意範囲と不明な範囲を分ける', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '次の稽古まで30分、誤公開された稽古映像の確認室',
    );

    expect(theme.audited, isTrue);
    expect(
      theme.situation,
      allOf(contains('R-24'), contains('18分間'), contains('23回')),
    );
    expect(theme.secret, allOf(contains('12人'), contains('画面録画')));
    expect(theme.roles[0], allOf(contains('14日間'), contains('完成版')));
    expect(theme.roles[1], allOf(contains('前回テンプレート'), contains('地球形')));
    expect(theme.roles[2], allOf(contains('削除へ変更可'), contains('空白')));
    expect(theme.roles[3], allOf(contains('10分'), contains('検出できない')));
    expect(theme.constraint, allOf(contains('完全に回収'), contains('端末')));
  });

  test('弁当二重仕込みテーマは家族の思いやりのすれ違いを描く', () {
    final theme = etudeThemes.singleWhere(
      (item) => item.place == '登校5分前、通学バッグに弁当が二つ入っていた三世代同居の玄関',
    );

    expect(theme.audited, isTrue);
    expect(theme.roles[0], contains('キャラ弁を仕込み'));
    expect(theme.roles[1], contains('孫の好物を詰めた弁当'));
    expect(theme.roles[2], contains('コンビニのサラダ'));
    expect(theme.roles[3], contains('再配達の宅配業者'));
    expect(theme.constraint, contains('宅配業者が呼び出しており'));
  });

  test('指定した人数・ジャンル・時間でお題を生成する', () {
    final prompt = PromptGenerator(
      random: Random(1),
    ).generate(players: 3, genre: 'ミステリー', durationMinutes: 10);

    expect(prompt.players, 3);
    expect(prompt.characters, hasLength(3));
    expect(prompt.genre, 'ミステリー');
    expect(prompt.durationMinutes, 10);
    expect(prompt.place, isNotEmpty);
    expect(prompt.situation, isNotEmpty);
    expect(prompt.secret, isNotEmpty);
    expect(prompt.constraint, isNotEmpty);
    expect(prompt.reflectionQuestions, hasLength(3));
    final selectedTheme = etudeThemes.singleWhere(
      (theme) => theme.place == prompt.place,
    );
    expect(prompt.reflectionQuestions, selectedTheme.reflectionQuestions);
  });

  test('保存用JSONを往復しても内容が変わらない', () {
    final original = PromptGenerator(
      random: Random(2),
    ).generate(players: 2, genre: 'コメディ', durationMinutes: 5);
    final restored = EtudePrompt.decode(original.encode());

    expect(restored.toJson(), original.toJson());
  });
}
