// character_editor_page.dart 的 part：规则选项、单项与多项选择区。
part of 'character_editor_page.dart';

class _RuleChoiceSection extends StatelessWidget {
  const _RuleChoiceSection({
    required this.choice,
    required this.options,
    required this.allEntries,
    required this.selected,
    required this.onChanged,
  });

  final _ActiveRuleChoice choice;
  final List<ContentEntry> options;
  final List<ContentEntry> allEntries;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final definition = choice.definition;
    final valid =
        selected.length >= definition.minimum &&
        selected.length <= definition.maximum;
    final sourceLabel = choice.level == null
        ? choice.sourceName
        : '${choice.sourceName} · 等级 ${choice.level}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card.outlined(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      definition.label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Icon(
                    valid ? Icons.check_circle : Icons.pending_outlined,
                    color: valid
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.error,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '$sourceLabel · 选择 ${definition.minimum}-${definition.maximum} 项',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              if (options.isEmpty)
                Text(
                  '资料库中缺少 ${definition.optionType} 选项。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final option in options)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FilterChip(
                            label: Text(option.name),
                            selected: selected.contains(option.id),
                            onSelected: (value) {
                              final next = Set<String>.from(selected);
                              if (value) {
                                if (definition.maximum == 1) next.clear();
                                if (next.length < definition.maximum) {
                                  next.add(option.id);
                                }
                              } else {
                                next.remove(option.id);
                              }
                              onChanged(next);
                            },
                          ),
                          IconButton(
                            key: Key('builder-open-entry-${option.id}'),
                            tooltip: '查看 ${option.name}',
                            onPressed: () => showContentEntryPreviewDialog(
                              context,
                              entry: option,
                              entries: allEntries,
                            ),
                            icon: const Icon(Icons.open_in_new, size: 18),
                          ),
                        ],
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceSection extends StatelessWidget {
  const _ChoiceSection({
    required this.title,
    required this.selected,
    required this.options,
    required this.onSelected,
    this.sourceLabel,
    this.onOpenOption,
  });

  final String title;
  final String selected;
  final List<String> options;
  final ValueChanged<String> onSelected;
  final String? sourceLabel;
  final ValueChanged<String>? onOpenOption;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (sourceLabel != null) ...[
            const SizedBox(height: 4),
            InputChip(
              avatar: const Icon(Icons.menu_book_outlined),
              label: Text(sourceLabel!),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ChoiceChip(
                      label: Text(option),
                      selected: option == selected,
                      onSelected: (_) => onSelected(option),
                    ),
                    if (onOpenOption != null)
                      IconButton(
                        tooltip: '查看 $option',
                        onPressed: () => onOpenOption!(option),
                        icon: const Icon(Icons.open_in_new, size: 18),
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MultiChoiceSection extends StatelessWidget {
  const _MultiChoiceSection({
    required this.title,
    required this.selected,
    required this.options,
    required this.onChanged,
    required this.emptyLabel,
    this.sourceLabel,
    this.onOpenOption,
    this.maximum,
  });

  final String title;
  final Set<String> selected;
  final List<String> options;
  final ValueChanged<Set<String>> onChanged;
  final String emptyLabel;
  final String? sourceLabel;
  final ValueChanged<String>? onOpenOption;

  /// 最多可选数量。已选数量达到该值后，未选项的 FilterChip 不可再选。
  /// null 表示不限制。已选项始终允许取消选择。
  final int? maximum;

  @override
  Widget build(BuildContext context) {
    final limit = maximum;
    final atLimit = limit != null && selected.length >= limit;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              if (limit != null) ...[
                const SizedBox(width: 8),
                Text(
                  '${selected.length} / $limit',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: atLimit
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          if (sourceLabel != null) ...[
            const SizedBox(height: 4),
            InputChip(
              avatar: const Icon(Icons.menu_book_outlined),
              label: Text(sourceLabel!),
            ),
          ],
          const SizedBox(height: 8),
          if (options.isEmpty)
            Text(emptyLabel)
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in options)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FilterChip(
                        label: Text(option),
                        selected: selected.contains(option),
                        onSelected: (isSelected) {
                          // 已达上限且试图新增：拒绝。允许取消已选项。
                          if (isSelected && atLimit) return;
                          final next = {...selected};
                          if (isSelected) {
                            next.add(option);
                          } else {
                            next.remove(option);
                          }
                          onChanged(next);
                        },
                      ),
                      if (onOpenOption != null)
                        IconButton(
                          tooltip: '查看 $option',
                          onPressed: () => onOpenOption!(option),
                          icon: const Icon(Icons.open_in_new, size: 18),
                        ),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
