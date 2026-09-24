import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/doremi_engine.dart';
import '../services/score_store.dart';
import '../theme/app_theme.dart';
import 'capture_screen.dart';
import 'onboarding_screen.dart';
import 'result_screen.dart';

class HomeScreen extends StatefulWidget {
  final DoremiEngine engine;
  const HomeScreen({super.key, required this.engine});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<SavedScore> _recent = const [];

  @override
  void initState() {
    super.initState();
    _loadRecent();
    _maybeShowOnboarding();
  }

  Future<void> _maybeShowOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('onboarded_v1') ?? false) return;
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
        fullscreenDialog: true, builder: (_) => const OnboardingScreen()));
    await prefs.setBool('onboarded_v1', true);
  }

  Future<void> _loadRecent() async {
    final list = await ScoreStore.list();
    if (mounted) setState(() => _recent = list);
  }

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    // スクショや複数ページに対応するため、ギャラリーは複数選択できるようにする
    final List<XFile> files = source == ImageSource.gallery
        ? await picker.pickMultiImage(maxWidth: 3000, imageQuality: 95)
        : [
            if (await picker.pickImage(
                    source: source, maxWidth: 3000, imageQuality: 95)
                case final XFile f)
              f
          ];
    if (files.isEmpty || !context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ResultScreen(
          engine: widget.engine,
          imagePaths: files.map((f) => f.path).toList()),
    ));
    _loadRecent();
  }

  Future<void> _openSaved(SavedScore s) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ResultScreen(engine: widget.engine, savedId: s.id),
    ));
    _loadRecent();
  }

  Future<void> _deleteSaved(SavedScore s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('この楽譜を削除しますか？'),
        content: Text('「${s.title}」を端末から削除します。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('キャンセル')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('削除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await ScoreStore.delete(s.id);
      _loadRecent();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ドレミふりがな')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(Icons.music_note_rounded,
                  size: 72, color: AppColors.brand),
              const SizedBox(height: 14),
              const Text(
                '楽譜を撮るだけで\n音符にドレミのふりがな',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                    color: AppColors.ink),
              ),
              const SizedBox(height: 8),
              const Text(
                '譜読みが苦手でも、その場で読める。',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 14),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CaptureScreen(engine: widget.engine),
                  ));
                  _loadRecent();
                },
                icon: const Icon(Icons.photo_camera_rounded),
                label: const Text('楽譜を撮影する'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _pick(context, ImageSource.gallery),
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('写真から選ぶ'),
              ),
              const SizedBox(height: 20),
              if (_recent.isNotEmpty) ...[
                const Text('最近の楽譜',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.ink)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 116,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _recent.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (_, i) {
                      final s = _recent[i];
                      return Semantics(
                        button: true,
                        label: '${s.title}の楽譜を開く',
                        child: GestureDetector(
                          onTap: () => _openSaved(s),
                          onLongPress: () => _deleteSaved(s),
                          child: SizedBox(
                            width: 132,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Container(
                                    width: 132,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border:
                                          Border.all(color: AppColors.line),
                                      color: AppColors.surface,
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Image.file(
                                      File(s.thumbPath),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const Icon(
                                          Icons.music_note_rounded,
                                          color: AppColors.line),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(s.title,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.muted)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 4),
                const Text('長押しで削除できます',
                    style: TextStyle(color: AppColors.muted, fontSize: 11)),
              ] else
                const Text(
                  '対応: 童謡・ピアノなど五線譜の楽譜（手書きは苦手です）',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
