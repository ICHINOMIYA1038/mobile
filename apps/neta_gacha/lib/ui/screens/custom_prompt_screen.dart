import 'package:flutter/material.dart';

import '../../data/custom_prompt_repository.dart';
import '../../data/situations.dart';
import '../../models/prompt.dart';
import '../theme.dart';
import '../widgets/dashed_border.dart';
import '../widgets/dot_pattern_background.dart';

class CustomPromptScreen extends StatefulWidget {
  const CustomPromptScreen({super.key});

  @override
  State<CustomPromptScreen> createState() => _CustomPromptScreenState();
}

class _CustomPromptScreenState extends State<CustomPromptScreen> {
  final _repository = CustomPromptRepository();
  List<Prompt> _all = [];
  String _selectedSituationId = kSituations.first.id;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await _repository.load();
    if (!mounted) return;
    setState(() {
      _all = all;
      _loading = false;
    });
  }

  List<Prompt> get _filtered =>
      _all.where((p) => p.situationId == _selectedSituationId).toList();

  Future<void> _remove(Prompt prompt) async {
    await _repository.remove(prompt.id);
    if (!mounted) return;
    setState(() => _all.removeWhere((p) => p.id == prompt.id));
  }

  Future<void> _showAddDialog() async {
    final controller = TextEditingController();
    var situationId = _selectedSituationId;

    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('カスタムお題を追加'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    maxLines: 3,
                    decoration: const InputDecoration(hintText: 'お題の内容'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButton<String>(
                    value: situationId,
                    isExpanded: true,
                    items: kSituations
                        .map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => situationId = value);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('キャンセル'),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(controller.text.trim()),
                  child: const Text('追加'),
                ),
              ],
            );
          },
        );
      },
    );

    if (text == null || text.isEmpty) return;

    final prompt = Prompt(
      id: 'custom-${DateTime.now().millisecondsSinceEpoch}',
      situationId: situationId,
      text: text,
      isCustom: true,
    );
    await _repository.add(prompt);
    if (!mounted) return;
    setState(() {
      _all.add(prompt);
      _selectedSituationId = situationId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('カスタムお題')),
      body: DotPatternBackground(
        dotColor: colors.dotPattern,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  SizedBox(
                    height: 56,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: kSituations.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final situation = kSituations[index];
                        return ChoiceChip(
                          label: Text(situation.label),
                          selected: _selectedSituationId == situation.id,
                          onSelected: (_) => setState(
                            () => _selectedSituationId = situation.id,
                          ),
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: _filtered.isEmpty
                        ? Center(
                            child: Text(
                              'このシチュエーションのカスタムお題はまだありません',
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filtered.length,
                            itemBuilder: (context, index) {
                              final prompt = _filtered[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Dismissible(
                                  key: ValueKey(prompt.id),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.errorContainer,
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: const Icon(Icons.delete_rounded),
                                  ),
                                  onDismissed: (_) => _remove(prompt),
                                  child: DashedBorderContainer(
                                    color: colors.textMuted.withValues(
                                      alpha: 0.5,
                                    ),
                                    fillColor: colors.cardBackground,
                                    borderRadius: 18,
                                    padding: const EdgeInsets.all(16),
                                    child: Text(
                                      prompt.text,
                                      style: handwritingStyle(
                                        context,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
