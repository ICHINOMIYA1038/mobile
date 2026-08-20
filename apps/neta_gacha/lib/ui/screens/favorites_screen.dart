import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/favorites_repository.dart';
import '../../models/prompt.dart';
import '../theme.dart';
import '../widgets/dot_pattern_background.dart';
import '../widgets/prompt_card.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _repository = FavoritesRepository();
  List<Prompt> _favorites = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final favorites = await _repository.load();
    if (!mounted) return;
    setState(() {
      _favorites = favorites;
      _loading = false;
    });
  }

  Future<void> _remove(Prompt prompt) async {
    await _repository.toggle(prompt);
    if (!mounted) return;
    setState(() => _favorites.removeWhere((p) => p.id == prompt.id));
  }

  void _share(Prompt prompt) {
    SharePlus.instance.share(ShareParams(text: '${prompt.text}\n#配信ネタガチャ'));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('お気に入り')),
      body: DotPatternBackground(
        dotColor: colors.dotPattern,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _favorites.isEmpty
            ? Center(
                child: Text(
                  'まだお気に入りがありません',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _favorites.length,
                itemBuilder: (context, index) {
                  final prompt = _favorites[index];
                  return PromptCard(
                    prompt: prompt,
                    isFavorite: true,
                    tiltTurns: index.isEven ? -0.012 : 0.012,
                    onToggleFavorite: () => _remove(prompt),
                    onShare: () => _share(prompt),
                  );
                },
              ),
      ),
    );
  }
}
