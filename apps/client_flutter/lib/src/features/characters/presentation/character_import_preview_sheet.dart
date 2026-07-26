import 'package:flutter/material.dart';

import '../domain/character.dart';
import '../domain/character_import_diff.dart';

enum CharacterImportAction { create, replace, merge }

class CharacterImportPreviewSheet extends StatelessWidget {
  const CharacterImportPreviewSheet({
    required this.imported,
    required this.existing,
    required this.onSelected,
    super.key,
  });

  final CharacterSheet imported;
  final CharacterSheet? existing;
  final ValueChanged<CharacterImportAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final diff = CharacterImportDiff.compare(existing, imported);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.preview_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '导入角色卡',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(imported.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: diff.changes.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final change = diff.changes[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(change.label),
                    subtitle: Text('${change.before}  →  ${change.after}'),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            if (existing == null)
              FilledButton.icon(
                onPressed: () => onSelected(CharacterImportAction.create),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('创建角色'),
              )
            else ...[
              FilledButton.icon(
                onPressed: () => onSelected(CharacterImportAction.merge),
                icon: const Icon(Icons.merge_type),
                label: const Text('合并到原角色'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => onSelected(CharacterImportAction.replace),
                icon: const Icon(Icons.sync),
                label: const Text('覆盖原角色'),
              ),
              TextButton.icon(
                onPressed: () => onSelected(CharacterImportAction.create),
                icon: const Icon(Icons.content_copy),
                label: const Text('另存为新角色'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
