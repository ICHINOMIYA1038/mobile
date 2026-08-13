import 'package:flutter/material.dart';

import '../../data/units.dart';
import '../../logic/quiz_controller.dart';
import '../theme.dart';
import 'quiz_screen.dart';

/// 「ランダムに挑戦」「分野を選んで挑戦」共通の出題設定画面。
/// [byUnit]がtrueなら単元選択リストも表示する。
class QuizSetupScreen extends StatefulWidget {
  const QuizSetupScreen({super.key, required this.byUnit});

  final bool byUnit;

  @override
  State<QuizSetupScreen> createState() => _QuizSetupScreenState();
}

class _QuizSetupScreenState extends State<QuizSetupScreen> {
  // nullは「全問」を表す。
  static const _countOptions = <int?>[5, 10, 15, 20, null];

  int? _selectedCount = 10;
  late Set<String> _selectedUnits;

  @override
  void initState() {
    super.initState();
    // 「全部チェック済みから外していく」方が「未選択=全単元」より直感的なため、
    // 分野別モードでは最初は全単元を選択済みにしておく。
    _selectedUnits = widget.byUnit ? kAllUnits.toSet() : {};
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.byUnit ? '分野を選んで挑戦' : 'ランダムに挑戦')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (widget.byUnit) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('出題する単元', style: Theme.of(context).textTheme.titleLarge),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () =>
                            setState(() => _selectedUnits = kAllUnits.toSet()),
                        child: const Text('全選択'),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _selectedUnits = {}),
                        child: const Text('全解除'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: colors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    children: kAllUnits.asMap().entries.map((entry) {
                      final unit = entry.value;
                      final isLast = entry.key == kAllUnits.length - 1;
                      final selected = _selectedUnits.contains(unit);
                      return Column(
                        children: [
                          CheckboxListTile(
                            value: selected,
                            onChanged: (value) {
                              setState(() {
                                if (value ?? false) {
                                  _selectedUnits.add(unit);
                                } else {
                                  _selectedUnits.remove(unit);
                                }
                              });
                            },
                            title: Text(unit),
                            activeColor: labMint,
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                          if (!isLast)
                            Divider(
                              height: 1,
                              indent: 16,
                              endIndent: 16,
                              color: colors.textPrimary.withValues(alpha: 0.08),
                            ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
              if (_selectedUnits.isEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '少なくとも1つは選んでね',
                  style: TextStyle(color: Colors.red.shade400, fontSize: 12),
                ),
              ],
              const SizedBox(height: 28),
            ],
            Text('出題数', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _countOptions.map((count) {
                final selected = _selectedCount == count;
                return ChoiceChip(
                  label: Text(count == null ? '全問' : '$count問'),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedCount = count),
                  backgroundColor: colors.pageBackground,
                  selectedColor: nekoOrange.withValues(alpha: 0.25),
                  side: BorderSide(
                    color: selected
                        ? nekoOrange
                        : nekoOrange.withValues(alpha: 0.3),
                  ),
                  labelStyle: TextStyle(
                    color: selected ? nekoOrange : colors.textPrimary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: (widget.byUnit && _selectedUnits.isEmpty)
                  ? null
                  : () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => QuizScreen(
                            controller: QuizController(
                              questionCount: _selectedCount,
                              units: widget.byUnit ? _selectedUnits : null,
                            ),
                          ),
                        ),
                      );
                    },
              child: const Text('はじめる'),
            ),
          ],
        ),
      ),
    );
  }
}
