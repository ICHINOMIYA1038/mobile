import 'dart:async';

import 'package:flutter/material.dart';

import 'data/favorites_repository.dart';
import 'data/prompt_generator.dart';
import 'models/etude_prompt.dart';
import 'theme/app_colors.dart';
import 'ui/widgets/ad_banner_slot.dart';

void main() => runApp(const EtudeApp());

class EtudeApp extends StatelessWidget {
  const EtudeApp({super.key});

  static ThemeData _themeFor(AppColors colors, Brightness brightness) {
    const seed = Color(0xFF7A3E65);
    return ThemeData(
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: brightness,
      ),
      scaffoldBackgroundColor: colors.background,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      extensions: [colors],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'エチュードメーカー',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: _themeFor(AppColors.light, Brightness.light),
      darkTheme: _themeFor(AppColors.dark, Brightness.dark),
      home: const TitleScreen(),
    );
  }
}

class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key});

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    final colors = context.colors;
    return Scaffold(
      body: CustomPaint(
        painter: _TitleBackgroundPainter(colors),
        child: Stack(
          children: [
            const Positioned(top: 82, right: 24, child: _HandmadeStar()),
            Positioned(
              top: 178,
              right: -24,
              child: Transform.rotate(
                angle: -.11,
                child: Container(
                  width: 112,
                  height: 32,
                  color: colors.decorativeAccent.withValues(alpha: .6),
                ),
              ),
            ),
            SafeArea(
              child: FadeTransition(
                opacity: fade,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.04),
                    end: Offset.zero,
                  ).animate(fade),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(26, 22, 26, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: _BrandMark(),
                        ),
                        const Spacer(flex: 2),
                        Transform.rotate(
                          angle: -.012,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 25),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              border: Border.all(color: colors.border),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(8),
                                topRight: Radius.circular(24),
                                bottomLeft: Radius.circular(22),
                                bottomRight: Radius.circular(10),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.shadow.withValues(alpha: .11),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'IMPROVISATION NOTE  /  01',
                                  style: TextStyle(
                                    color: colors.accent,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'エチュード\nメーカー',
                                  style: Theme.of(context)
                                      .textTheme
                                      .displaySmall
                                      ?.copyWith(
                                        color: colors.textPrimary,
                                        fontWeight: FontWeight.w800,
                                        height: 1.35,
                                        letterSpacing: -.8,
                                      ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '人数とジャンルを選ぶだけ。\n役・場所・秘密まで、即興のお題を一瞬で。',
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    height: 1.7,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        const _TitleFeatureRow(),
                        const Spacer(flex: 3),
                        _TitleStartButton(
                          onPressed: () =>
                              Navigator.of(context).pushReplacement(
                                PageRouteBuilder(
                                  transitionDuration: const Duration(
                                    milliseconds: 500,
                                  ),
                                  pageBuilder: (_, _, _) =>
                                      const GeneratorScreen(),
                                  transitionsBuilder:
                                      (_, animation, _, child) =>
                                          FadeTransition(
                                            opacity: animation,
                                            child: child,
                                          ),
                                ),
                              ),
                        ),
                        const SizedBox(height: 13),
                        Text(
                          '登録不要  /  すぐに使えます',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 11,
                            letterSpacing: .5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleBackgroundPainter extends CustomPainter {
  const _TitleBackgroundPainter(this.colors);

  final AppColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(colors.background, BlendMode.src);
    final dotPaint = Paint()..color = colors.dotPattern;
    for (double y = 16; y < size.height; y += 24) {
      for (double x = 16; x < size.width; x += 24) {
        canvas.drawCircle(Offset(x, y), .65, dotPaint);
      }
    }
    final line = Paint()
      ..color = colors.accentSoft.withValues(alpha: .35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(-20, size.height * .72)
      ..cubicTo(
        size.width * .18,
        size.height * .65,
        size.width * .24,
        size.height * .8,
        size.width * .44,
        size.height * .73,
      );
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _TitleBackgroundPainter oldDelegate) =>
      oldDelegate.colors != colors;
}

class _HandmadeStar extends StatelessWidget {
  const _HandmadeStar();

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: .12,
    child: Text(
      '✦',
      style: TextStyle(color: context.colors.accent, fontSize: 36),
    ),
  );
}

class _TitleStartButton extends StatelessWidget {
  const _TitleStartButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.ink,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(14),
        topRight: Radius.circular(25),
        bottomLeft: Radius.circular(24),
        bottomRight: Radius.circular(13),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'はじめる',
                  style: TextStyle(
                    color: colors.onInk,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 12),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.accentSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(7),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: colors.onAccent,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: colors.accentSoft,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(10),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(15),
              bottomRight: Radius.circular(9),
            ),
          ),
          child: Icon(Icons.theater_comedy_rounded, color: colors.onAccent),
        ),
        const SizedBox(width: 13),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ÉTUDE',
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
                fontSize: 17,
              ),
            ),
            Text(
              'PROMPT STUDIO',
              style: TextStyle(
                color: colors.textMuted,
                letterSpacing: 1.7,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TitleFeatureRow extends StatelessWidget {
  const _TitleFeatureRow();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(11),
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(19),
        ),
        border: Border.all(color: colors.border),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _TitleFeature(icon: Icons.groups_rounded, label: '2〜4人'),
          _TitleFeature(icon: Icons.shuffle_rounded, label: 'ランダム'),
          _TitleFeature(icon: Icons.bookmark_rounded, label: '保存'),
        ],
      ),
    );
  }
}

class _TitleFeature extends StatelessWidget {
  const _TitleFeature({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon, color: context.colors.accentDeep, size: 21),
      const SizedBox(height: 5),
      Text(
        label,
        style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
      ),
    ],
  );
}

class GeneratorScreen extends StatefulWidget {
  const GeneratorScreen({super.key});

  @override
  State<GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends State<GeneratorScreen> {
  final _generator = PromptGenerator();
  final _favoritesRepository = FavoritesRepository();
  int _players = 2;
  String _genre = '日常';
  int _duration = 5;
  EtudePrompt? _prompt;
  List<EtudePrompt> _favorites = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final favorites = await _favoritesRepository.load();
    if (mounted) setState(() => _favorites = favorites);
  }

  void _generate() {
    setState(() {
      _prompt = _generator.generate(
        players: _players,
        genre: _genre,
        durationMinutes: _duration,
      );
    });
  }

  Future<void> _toggleFavorite(EtudePrompt prompt) async {
    final exists = _favorites.any((item) => item.id == prompt.id);
    setState(() {
      _favorites = exists
          ? _favorites.where((item) => item.id != prompt.id).toList()
          : [prompt, ..._favorites];
    });
    await _favoritesRepository.save(_favorites);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.colors.background,
        title: const Text(
          'ÉTUDE',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: 4,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'お気に入り',
            icon: Badge(
              isLabelVisible: _favorites.isNotEmpty,
              label: Text('${_favorites.length}'),
              child: const Icon(Icons.bookmark_rounded),
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => FavoritesScreen(
                  prompts: _favorites,
                  onRemove: _toggleFavorite,
                ),
              ),
            ),
          ),
        ],
      ),
      body: CustomPaint(
        painter: _NotebookBackgroundPainter(context.colors),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: [
              Text(
                '今日のエチュード',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 30,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 18),
              _SettingsCard(
                players: _players,
                genre: _genre,
                duration: _duration,
                onPlayersChanged: (value) => setState(() => _players = value),
                onGenreChanged: (value) => setState(() => _genre = value),
                onDurationChanged: (value) => setState(() => _duration = value),
              ),
              const SizedBox(height: 18),
              _GenerateButton(hasPrompt: _prompt != null, onPressed: _generate),
              const SizedBox(height: 24),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 360),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, .04),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: _prompt == null
                    ? const _EmptyPrompt()
                    : PromptCard(
                        key: ValueKey(_prompt!.id),
                        prompt: _prompt!,
                        isFavorite: _favorites.any(
                          (item) => item.id == _prompt!.id,
                        ),
                        onFavorite: () => _toggleFavorite(_prompt!),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotebookBackgroundPainter extends CustomPainter {
  const _NotebookBackgroundPainter(this.colors);

  final AppColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(colors.background, BlendMode.src);
    final dotPaint = Paint()..color = colors.dotPattern;
    for (double y = 18; y < size.height; y += 24) {
      for (double x = 18; x < size.width; x += 24) {
        canvas.drawCircle(Offset(x, y), .65, dotPaint);
      }
    }
    final doodle = Paint()
      ..color = colors.accentSoft.withValues(alpha: .22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(size.width + 8, 55), radius: 78),
      1.4,
      3.5,
      false,
      doodle,
    );
  }

  @override
  bool shouldRepaint(covariant _NotebookBackgroundPainter oldDelegate) =>
      oldDelegate.colors != colors;
}

class _GenerateButton extends StatelessWidget {
  const _GenerateButton({required this.hasPrompt, required this.onPressed});
  final bool hasPrompt;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.ink,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(15),
        topRight: Radius.circular(25),
        bottomLeft: Radius.circular(24),
        bottomRight: Radius.circular(14),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.casino_rounded, color: colors.onAccent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasPrompt ? 'もう一度' : 'お題をつくる',
                      style: TextStyle(
                        color: colors.onInk,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'TAP TO SHUFFLE',
                      style: TextStyle(
                        color: colors.onInk.withValues(alpha: .6),
                        fontSize: 9,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: colors.onInk),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.players,
    required this.genre,
    required this.duration,
    required this.onPlayersChanged,
    required this.onGenreChanged,
    required this.onDurationChanged,
  });

  final int players;
  final String genre;
  final int duration;
  final ValueChanged<int> onPlayersChanged;
  final ValueChanged<String> onGenreChanged;
  final ValueChanged<int> onDurationChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(26),
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(15),
        ),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: .09),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.accentSoft,
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox(width: 9, height: 9),
                ),
                const SizedBox(width: 9),
                const Text(
                  'HOW SHALL WE PLAY?',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const _OptionLabel(number: '01', label: '人数'),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in [2, 3, 4])
                  _PaperChoice(
                    label: '$value人',
                    selected: players == value,
                    onTap: () => onPlayersChanged(value),
                  ),
              ],
            ),
            const SizedBox(height: 19),
            const _OptionLabel(number: '02', label: 'ジャンル'),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in PromptGenerator.genres)
                  _PaperChoice(
                    label: value,
                    selected: genre == value,
                    onTap: () => onGenreChanged(value),
                  ),
              ],
            ),
            const SizedBox(height: 19),
            const _OptionLabel(number: '03', label: '時間'),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in PromptGenerator.durations)
                  _PaperChoice(
                    label: '$value分',
                    selected: duration == value,
                    onTap: () => onDurationChanged(value),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionLabel extends StatelessWidget {
  const _OptionLabel({required this.number, required this.label});
  final String number;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        number,
        style: TextStyle(
          color: context.colors.accent,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(width: 9),
      Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    ],
  );
}

class _PaperChoice extends StatelessWidget {
  const _PaperChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Semantics(
          button: true,
          selected: selected,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? colors.ink : colors.surfaceAlt,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(8),
                topRight: Radius.circular(selected ? 14 : 10),
                bottomLeft: Radius.circular(selected ? 13 : 10),
                bottomRight: const Radius.circular(8),
              ),
              border: Border.all(color: selected ? colors.ink : colors.border),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? colors.onInk : colors.textSecondary,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyPrompt extends StatelessWidget {
  const _EmptyPrompt();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: .4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Text('✦', style: TextStyle(color: colors.accent, fontSize: 28)),
          const SizedBox(height: 10),
          Text(
            'まだ白紙です。\n偶然から、最初の一言を。',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textSecondary, height: 1.65),
          ),
        ],
      ),
    );
  }
}

class PromptCard extends StatelessWidget {
  const PromptCard({
    super.key,
    required this.prompt,
    required this.isFavorite,
    required this.onFavorite,
  });

  final EtudePrompt prompt;
  final bool isFavorite;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(24),
          bottomLeft: Radius.circular(25),
          bottomRight: Radius.circular(12),
        ),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: .12),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -7,
            left: 54,
            right: 54,
            child: Container(
              height: 18,
              decoration: BoxDecoration(
                color: colors.decorativeAccent.withValues(alpha: .68),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        prompt.title,
                        style: const TextStyle(
                          fontSize: 24,
                          height: 1.3,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.5,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: isFavorite ? 'お気に入りから削除' : 'お気に入りに追加',
                      onPressed: onFavorite,
                      style: IconButton.styleFrom(
                        backgroundColor: colors.surfaceAlt,
                      ),
                      icon: Icon(
                        isFavorite
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        color: colors.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${prompt.players}人・${prompt.genre}・${prompt.durationMinutes}分',
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .6,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Divider(color: colors.borderSoft, height: 1),
                ),
                _PromptRow(
                  icon: Icons.groups_rounded,
                  label: '関係',
                  value: prompt.relationship,
                ),
                _PromptRow(
                  icon: Icons.place_rounded,
                  label: '場所',
                  value: prompt.place,
                ),
                _PromptRow(
                  icon: Icons.bolt_rounded,
                  label: '状況',
                  value: prompt.situation,
                ),
                _PromptRow(
                  icon: Icons.person_rounded,
                  label: '役',
                  value: '${prompt.players}人分の役を、開始時に個別表示します',
                ),
                _PromptRow(
                  icon: Icons.lock_rounded,
                  label: '秘密',
                  value: '役を引いた本人だけに表示します',
                ),
                _PromptRow(
                  icon: Icons.rule_rounded,
                  label: '制約',
                  value: prompt.constraint,
                ),
                const SizedBox(height: 4),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RoleDrawScreen(prompt: prompt),
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.ink,
                    foregroundColor: colors.onInk,
                    minimumSize: const Size.fromHeight(56),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(21),
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(11),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text(
                    'このエチュードを実行する',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RoleDrawScreen extends StatefulWidget {
  const RoleDrawScreen({super.key, required this.prompt});
  final EtudePrompt prompt;

  @override
  State<RoleDrawScreen> createState() => _RoleDrawScreenState();
}

class _RoleDrawScreenState extends State<RoleDrawScreen> {
  List<String> get _roles => widget.prompt.characters;
  int _playerIndex = 0;
  bool _revealed = false;
  bool _ready = false;

  String get _playerName => '${_japaneseNumber(_playerIndex + 1)}人目';

  static String _japaneseNumber(int value) => switch (value) {
    1 => '一',
    2 => '二',
    3 => '三',
    4 => '四',
    _ => '$value',
  };

  void _advance() {
    if (!_revealed) {
      setState(() => _revealed = true);
      return;
    }
    if (_playerIndex == _roles.length - 1) {
      setState(() => _ready = true);
      return;
    }
    setState(() {
      _playerIndex++;
      _revealed = false;
    });
  }

  void _reviewRoles() {
    setState(() {
      _playerIndex = 0;
      _revealed = false;
      _ready = false;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: context.colors.background,
      title: const Text(
        '役を引く',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
    ),
    body: CustomPaint(
      painter: _NotebookBackgroundPainter(context.colors),
      child: SizedBox.expand(
        child: SafeArea(
          top: false,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _ready ? _buildReady() : _buildDraw(),
          ),
        ),
      ),
    ),
  );

  Widget _buildDraw() {
    final colors = context.colors;
    return CustomScrollView(
      key: ValueKey('$_playerIndex-$_revealed'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 30),
          sliver: SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${_playerIndex + 1} / ${_roles.length}',
                  style: TextStyle(
                    color: colors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _revealed ? 'あなたの役です' : '$_playerNameの方へ',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 29,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _revealed
                      ? '役を覚えたら、画面を伏せて次の人へ渡してください。'
                      : 'ほかの人に見えないように、画面を受け取ってください。',
                  style: TextStyle(color: colors.textSecondary, height: 1.55),
                ),
                const Spacer(),
                _RolePaper(
                  revealed: _revealed,
                  role: _roles[_playerIndex],
                  playerName: _playerName,
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _advance,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.ink,
                    foregroundColor: colors.onInk,
                    minimumSize: const Size.fromHeight(62),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: Icon(
                    _revealed
                        ? Icons.arrow_forward_rounded
                        : Icons.touch_app_rounded,
                  ),
                  label: Text(
                    !_revealed
                        ? '$_playerNameの役を引く'
                        : _playerIndex == _roles.length - 1
                        ? '配役完了'
                        : '次の人へ',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReady() {
    final colors = context.colors;
    return Padding(
      key: const ValueKey('ready'),
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 30),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '✦  READY',
              style: TextStyle(
                color: colors.accent,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '配役が決まりました。',
              style: TextStyle(
                fontSize: 29,
                fontWeight: FontWeight.w800,
                letterSpacing: -.8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'お互いの役は秘密のまま。\n最初の一言から、物語を始めましょう。',
              style: TextStyle(color: colors.textSecondary, height: 1.6),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.prompt.title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('関係　${widget.prompt.relationship}'),
                  const SizedBox(height: 7),
                  Text('制約　${widget.prompt.constraint}'),
                  const SizedBox(height: 7),
                  Text('時間　${widget.prompt.durationMinutes}分'),
                ],
              ),
            ),
            const SizedBox(height: 28),
            OutlinedButton.icon(
              onPressed: _reviewRoles,
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.textPrimary,
                minimumSize: const Size.fromHeight(56),
                side: BorderSide(color: colors.borderStrong),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(Icons.replay_rounded),
              label: const Text(
                '役をもう一度見返す',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => PerformanceScreen(prompt: widget.prompt),
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: colors.ink,
                foregroundColor: colors.onInk,
                minimumSize: const Size.fromHeight(62),
              ),
              icon: const Icon(Icons.theater_comedy_rounded),
              label: const Text(
                'エチュードを始める',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({super.key, required this.prompt});
  final EtudePrompt prompt;

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  Timer? _timer;
  late int _secondsLeft = widget.prompt.durationMinutes * 60;
  bool _running = true;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_running) return;
      if (_secondsLeft <= 1) {
        setState(() => _secondsLeft = 0);
        _finish();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _toggleTimer() => setState(() => _running = !_running);

  void _finish() {
    _timer?.cancel();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ReflectionScreen(prompt: widget.prompt),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _timeLabel {
    final minutes = _secondsLeft ~/ 60;
    final seconds = _secondsLeft % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: colors.background,
        title: const Text(
          '実演中',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        actions: [
          TextButton(onPressed: _finish, child: const Text('終了する')),
          const SizedBox(width: 8),
        ],
      ),
      body: CustomPaint(
        painter: _NotebookBackgroundPainter(colors),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 36),
            children: [
              Text(
                'NOW PLAYING  ●',
                style: TextStyle(
                  color: colors.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.7,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.prompt.title,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 25,
                  height: 1.3,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.6,
                ),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 28),
                decoration: BoxDecoration(
                  color: colors.ink,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(13),
                    topRight: Radius.circular(28),
                    bottomLeft: Radius.circular(26),
                    bottomRight: Radius.circular(12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.shadow.withValues(alpha: .145),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      _running ? '残り時間' : '一時停止中',
                      style: TextStyle(
                        color: colors.accentSoft,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _timeLabel,
                      style: TextStyle(
                        color: colors.onInk,
                        fontSize: 64,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _toggleTimer,
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.accentSoft,
                        foregroundColor: colors.onAccent,
                      ),
                      icon: Icon(
                        _running
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      label: Text(_running ? '一時停止' : '再開'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const AdBannerSlot(),
              const SizedBox(height: 16),
              const Text(
                '全員に見せてよい条件',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              _CommonConditionCard(
                icon: Icons.groups_rounded,
                label: '関係',
                value: widget.prompt.relationship,
              ),
              const SizedBox(height: 9),
              _CommonConditionCard(
                icon: Icons.place_rounded,
                label: '場所',
                value: widget.prompt.place,
              ),
              const SizedBox(height: 9),
              _CommonConditionCard(
                icon: Icons.bolt_rounded,
                label: '状況',
                value: widget.prompt.situation,
              ),
              const SizedBox(height: 9),
              _CommonConditionCard(
                icon: Icons.rule_rounded,
                label: '制約',
                value: widget.prompt.constraint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommonConditionCard extends StatelessWidget {
  const _CommonConditionCard({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.accentDeep, size: 20),
          const SizedBox(width: 12),
          SizedBox(
            width: 38,
            child: Text(
              label,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(height: 1.4))),
        ],
      ),
    );
  }
}

class ReflectionScreen extends StatelessWidget {
  const ReflectionScreen({super.key, required this.prompt});
  final EtudePrompt prompt;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: colors.background,
        title: const Text(
          '振り返り',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
      body: CustomPaint(
        painter: _NotebookBackgroundPainter(colors),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 30, 22, 36),
            children: [
              const Text(
                'おつかれさまでした。',
                style: TextStyle(
                  fontSize: 29,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '答え合わせではなく、起きた物語をみんなで眺めてみましょう。',
                style: TextStyle(color: colors.textSecondary, height: 1.6),
              ),
              const SizedBox(height: 26),
              Container(
                padding: const EdgeInsets.all(21),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(24),
                    bottomLeft: Radius.circular(22),
                    bottomRight: Radius.circular(11),
                  ),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TALK ABOUT IT',
                      style: TextStyle(
                        color: colors.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    for (final entry in _questions.indexed)
                      _ReflectionQuestion(
                        number: '${entry.$1 + 1}'.padLeft(2, '0'),
                        text: entry.$2,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const AdBannerSlot(),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => RoleDrawScreen(prompt: prompt),
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.ink,
                  foregroundColor: colors.onInk,
                  minimumSize: const Size.fromHeight(58),
                ),
                icon: const Icon(Icons.replay_rounded),
                label: const Text('同じお題でもう一度'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.textPrimary,
                  minimumSize: const Size.fromHeight(56),
                  side: BorderSide(color: colors.borderStrong),
                ),
                icon: const Icon(Icons.shuffle_rounded),
                label: const Text('新しいお題を作る'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> get _questions => prompt.reflectionQuestions.isNotEmpty
      ? prompt.reflectionQuestions
      : const ['いちばん意外だった展開は？', '相手の演技で印象に残った瞬間は？', 'もう一度なら、何を変えてみたい？'];
}

class _ReflectionQuestion extends StatelessWidget {
  const _ReflectionQuestion({required this.number, required this.text});
  final String number;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          number,
          style: TextStyle(
            color: context.colors.accent,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w700, height: 1.45),
          ),
        ),
      ],
    ),
  );
}

class _RolePaper extends StatelessWidget {
  const _RolePaper({
    required this.revealed,
    required this.role,
    required this.playerName,
  });
  final bool revealed;
  final String role;
  final String playerName;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      constraints: const BoxConstraints(minHeight: 220),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: revealed ? colors.surface : colors.ink,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(28),
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(12),
        ),
        border: Border.all(color: revealed ? colors.border : colors.ink),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: .125),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            revealed ? 'YOUR ROLE' : 'ROLE  /  $playerName',
            style: TextStyle(
              color: revealed ? colors.accent : colors.accentSoft,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 18),
          if (revealed)
            Text(
              role,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 24,
                height: 1.5,
                fontWeight: FontWeight.w800,
              ),
            )
          else
            Icon(Icons.question_mark_rounded, color: colors.onInk, size: 54),
        ],
      ),
    );
  }
}

class _PromptRow extends StatelessWidget {
  const _PromptRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colors.accentSurface,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: colors.accentDeep),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({
    super.key,
    required this.prompts,
    required this.onRemove,
  });
  final List<EtudePrompt> prompts;
  final Future<void> Function(EtudePrompt) onRemove;

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late final List<EtudePrompt> _prompts = List.from(widget.prompts);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: context.colors.background,
      title: const Text(
        'お気に入り',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
    ),
    body: CustomPaint(
      painter: _NotebookBackgroundPainter(context.colors),
      child: SizedBox.expand(
        child: _prompts.isEmpty
            ? const _EmptyFavorites()
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                itemCount: _prompts.length + 1,
                separatorBuilder: (_, index) =>
                    SizedBox(height: index == 0 ? 22 : 14),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    final colors = context.colors;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'とっておきの、お題。',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 28,
                            height: 1.25,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'また演じたい偶然を、ここに集めておけます。',
                          style: TextStyle(
                            color: colors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    );
                  }
                  final prompt = _prompts[index - 1];
                  return _FavoriteCard(
                    prompt: prompt,
                    index: index,
                    onDelete: () async {
                      setState(() => _prompts.remove(prompt));
                      await widget.onRemove(prompt);
                    },
                  );
                },
              ),
      ),
    ),
  );
}

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({
    required this.prompt,
    required this.index,
    required this.onDelete,
  });
  final EtudePrompt prompt;
  final int index;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(9),
          topRight: Radius.circular(21),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(11),
        ),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: .078),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 17, 12, 17),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.accentSurface,
                shape: BoxShape.circle,
              ),
              child: Text(
                index.toString().padLeft(2, '0'),
                style: TextStyle(
                  color: colors.accentDeep,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .5,
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prompt.title,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 17,
                      height: 1.35,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '${prompt.players}人・${prompt.genre}・${prompt.durationMinutes}分',
                    style: TextStyle(
                      color: colors.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .6,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    '${prompt.relationship}  /  ${prompt.place}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RoleDrawScreen(prompt: prompt),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.textPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      side: BorderSide(color: colors.borderStrong),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(14),
                          bottomLeft: Radius.circular(13),
                          bottomRight: Radius.circular(8),
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text(
                      'このお題を実行する',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '削除',
              onPressed: onDelete,
              style: IconButton.styleFrom(
                backgroundColor: colors.surfaceAlt,
                foregroundColor: colors.accentDeep,
              ),
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: .8),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(25),
              bottomLeft: Radius.circular(23),
              bottomRight: Radius.circular(10),
            ),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bookmark_border_rounded,
                color: colors.accent,
                size: 36,
              ),
              const SizedBox(height: 14),
              const Text(
                '保存したお題はありません',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 7),
              Text(
                '気に入った偶然を見つけたら、\nしおりを挟んでおきましょう。',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary, height: 1.55),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
