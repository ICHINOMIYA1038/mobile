import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/ad_service.dart';
import '../data/custom_prompt_repository.dart';
import '../data/favorites_repository.dart';
import '../data/history_repository.dart';
import '../data/ng_settings_repository.dart';
import '../data/prompt_repository.dart';
import '../models/prompt.dart';

/// 1つのシチュエーションでの抽選ループを司る。
///
/// プール構築(同梱+カスタム、NGタグ・履歴でフィルタ) → 抽選 → 履歴記録 → お気に入り状態の
/// 追跡までを担当する。インタースティシャルの抽選回数カウンタはアプリセッション内で共有する
/// (シチュエーションを切り替えてもカウントは引き継がれる)ため、staticで保持する。
class RouletteController extends ChangeNotifier {
  RouletteController({
    required this.situationId,
    PromptRepository? promptRepository,
    CustomPromptRepository? customPromptRepository,
    FavoritesRepository? favoritesRepository,
    HistoryRepository? historyRepository,
    NgSettingsRepository? ngSettingsRepository,
    AdService? adService,
  }) : _promptRepository = promptRepository ?? PromptRepository(),
       _customPromptRepository =
           customPromptRepository ?? CustomPromptRepository(),
       _favoritesRepository = favoritesRepository ?? FavoritesRepository(),
       _historyRepository = historyRepository ?? HistoryRepository(),
       _ngSettingsRepository = ngSettingsRepository ?? NgSettingsRepository(),
       _adService = adService ?? AdService();

  final String situationId;
  final PromptRepository _promptRepository;
  final CustomPromptRepository _customPromptRepository;
  final FavoritesRepository _favoritesRepository;
  final HistoryRepository _historyRepository;
  final NgSettingsRepository _ngSettingsRepository;
  final AdService _adService;

  static const _interstitialInterval = 5;
  static int _drawsSinceInterstitial = 0;

  bool isLoading = true;
  Prompt? currentPrompt;
  bool currentIsFavorite = false;

  /// 抽選のたびに増える通し番号。同じお題が連続で出た場合でも演出用のKeyとして
  /// ユニークに使えるようにするためのもの(お題自体の識別には使わない)。
  int drawSequence = 0;

  List<Prompt> _pool = [];
  Set<String> _favoriteIds = {};

  Future<void> load() async {
    isLoading = true;
    notifyListeners();

    final bundled = await _promptRepository.loadForSituation(situationId);
    final custom = await _customPromptRepository.load();
    final disabledTags = await _ngSettingsRepository.loadDisabledTagIds();
    final favorites = await _favoritesRepository.load();
    _favoriteIds = favorites.map((f) => f.id).toSet();

    _pool = [...bundled, ...custom.where((p) => p.situationId == situationId)]
        .where((p) => p.tags.every((tag) => !disabledTags.contains(tag)))
        .toList();

    isLoading = false;
    notifyListeners();
  }

  /// お題を1件抽選する。プールが空(NG設定で全滅した等)ならfalseを返す。
  Future<bool> draw() async {
    if (_pool.isEmpty) return false;

    final recentIds = await _historyRepository.recentIdsFor(situationId);
    var candidates = _pool.where((p) => !recentIds.contains(p.id)).toList();
    // 直近除外で候補が尽きたら、除外なしの全プールから選ぶ(「候補なし」は返さない)。
    if (candidates.isEmpty) candidates = _pool;

    final picked = candidates[Random().nextInt(candidates.length)];
    currentPrompt = picked;
    currentIsFavorite = _favoriteIds.contains(picked.id);
    drawSequence++;
    await _historyRepository.recordShown(situationId, picked.id);
    notifyListeners();

    _drawsSinceInterstitial++;
    if (_drawsSinceInterstitial >= _interstitialInterval) {
      _drawsSinceInterstitial = 0;
      unawaited(_adService.showInterstitial());
    }
    return true;
  }

  Future<void> toggleFavorite() async {
    final prompt = currentPrompt;
    if (prompt == null) return;
    final isFavorite = await _favoritesRepository.toggle(prompt);
    currentIsFavorite = isFavorite;
    if (isFavorite) {
      _favoriteIds.add(prompt.id);
    } else {
      _favoriteIds.remove(prompt.id);
    }
    notifyListeners();
  }
}
