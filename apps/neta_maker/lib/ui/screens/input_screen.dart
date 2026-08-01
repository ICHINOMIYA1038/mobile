import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/maker_result.dart';
import '../../theme/app_colors.dart';
import '../../theme/sepia_filter.dart';
import '../widgets/parchment_background.dart';
import 'result_screen.dart';

/// 名前入力画面。広告は一切置かない(コア体験を遮らないため)。
///
/// `TextField` はFlutter標準ウィジェットをそのまま使う。WebViewや独自実装の
/// 入力欄を使わないことで、既存アプリで頻発していた
/// 「日本語入力ができない」「flickキーボードしか使えない」
/// 「入力画面が邪魔でコピペできない」といった入力バグを構造的に避ける。
class InputScreen extends StatefulWidget {
  const InputScreen({super.key, required this.category});

  final MakerCategory category;

  @override
  State<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends State<InputScreen> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          category: widget.category,
          input: _controller.text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: colors.textPrimary,
      ),
      body: ParchmentBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.accentSurface,
                            border: Border.all(
                              color: colors.borderStrong,
                              width: 1.6,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: ColorFiltered(
                            colorFilter: const ColorFilter.matrix(sepiaMatrix),
                            child: Text(
                              widget.category.emoji,
                              style: const TextStyle(fontSize: 38),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -14,
                          right: -28,
                          child: Image.asset(
                            'assets/mascot/mascot_wave.png',
                            height: 56,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.category.title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.yujiSyuku(
                      fontSize: 26,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.category.description,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _controller,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    keyboardType: TextInputType.text,
                    maxLength: 20,
                    style: TextStyle(color: colors.textPrimary, fontSize: 20),
                    cursorColor: colors.accent,
                    decoration: InputDecoration(
                      labelText: '名前・ニックネーム',
                      labelStyle: TextStyle(color: colors.textSecondary),
                      filled: true,
                      fillColor: colors.surface,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: colors.accent, width: 2),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '名前を入力してね';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 24),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: colors.ink,
                      border: Border.all(color: colors.shadow, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: colors.shadow.withValues(alpha: 0.3),
                          blurRadius: 5,
                          offset: const Offset(2, 3),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: _submit,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            '―  診断する  ―',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.yujiSyuku(
                              fontSize: 18,
                              color: colors.onInk,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
