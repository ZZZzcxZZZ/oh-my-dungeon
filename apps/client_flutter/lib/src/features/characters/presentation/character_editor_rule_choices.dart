// character_editor_page.dart 的 part：非规则选择区（职业 / 背景 / 物种等单项与多项
// 选择）。规则选择（`rules.choices`）一律由共享组件
// `widgets/rule_choice_section.dart` 的 `RuleChoiceSection` 承担（唯一渲染器）。
part of 'character_editor_page.dart';

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
