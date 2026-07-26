import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:etude_generator/data/favorites_repository.dart';
import 'package:etude_generator/models/etude_prompt.dart';

const _samplePrompt = EtudePrompt(
  id: 'p1',
  players: 2,
  genre: '日常',
  durationMinutes: 5,
  characters: ['役A', '役B'],
  relationship: '同僚',
  place: 'オフィス',
  situation: '残業中',
  secret: '秘密',
  constraint: '制約',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('壊れたお気に入り1件をスキップし、残りは読み込める', () async {
    SharedPreferences.setMockInitialValues({
      'favorite_prompts_v1': ['{不正なJSON', _samplePrompt.encode()],
    });

    final favorites = await FavoritesRepository().load();

    expect(favorites, hasLength(1));
    expect(favorites.single.id, 'p1');
  });

  test('保存したお気に入りをそのまま読み込める', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = FavoritesRepository();

    await repository.save([_samplePrompt]);
    final favorites = await repository.load();

    expect(favorites, hasLength(1));
    expect(favorites.single.place, 'オフィス');
  });
}
