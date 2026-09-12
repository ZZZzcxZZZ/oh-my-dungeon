// character_detail_page.dart 的 part：内容条目/名称描述/资源选择对话框。
part of 'character_detail_page.dart';

Future<ContentEntry?> _pickContentEntry(
  BuildContext context, {
  required String title,
  required List<ContentEntry> entries,
}) {
  var query = '';
  return showModalBottomSheet<ContentEntry>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) {
        final filtered = entries
            .where((entry) {
              if (query.isEmpty) return true;
              final normalized = query.toLowerCase();
              return entry.name.toLowerCase().contains(normalized) ||
                  entry.summary.toLowerCase().contains(normalized);
            })
            .toList(growable: false);
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.78,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SearchBar(
                    hintText: '搜索名称',
                    leading: const Icon(Icons.search),
                    onChanged: (value) => setSheetState(() => query = value),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filtered.isEmpty
                      ? const EmptyState(
                          icon: Icons.library_add_outlined,
                          title: '没有可添加的条目',
                        )
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final entry = filtered[index];
                            return ListTile(
                              title: Text(entry.name),
                              subtitle: entry.summary.isEmpty
                                  ? Text(entry.type)
                                  : Text(
                                      entry.summary,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                              onTap: () => Navigator.of(context).pop(entry),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

Future<(String, String)?> _showNameDescriptionDialog(
  BuildContext context, {
  required String title,
}) async {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final result = await showDialog<(String, String)>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: DialogSizes.form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: '名称'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(labelText: '说明（可选）'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final name = nameController.text.trim();
            if (name.isEmpty) return;
            Navigator.of(context).pop((name, descriptionController.text));
          },
          child: const Text('添加'),
        ),
      ],
    ),
  );
  nameController.dispose();
  descriptionController.dispose();
  return result;
}

Future<Dnd5eClassResource?> _showResourceDialog(
  BuildContext context, {
  Dnd5eClassResource? initial,
}) async {
  final nameController = TextEditingController(text: initial?.name ?? '');
  final maximumController = TextEditingController(
    text: '${initial?.maximum ?? 1}',
  );
  var recovery = initial?.recovery ?? 'longRest';
  final result = await showDialog<Dnd5eClassResource>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(initial == null ? '添加资源' : '编辑资源'),
        content: SizedBox(
          width: DialogSizes.form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('resource-name-field'),
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: '资源名称'),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('resource-maximum-field'),
                controller: maximumController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '最大次数'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const Key('resource-recovery-field'),
                initialValue: recovery,
                decoration: const InputDecoration(labelText: '恢复规则'),
                items: const [
                  DropdownMenuItem(value: 'shortRest', child: Text('短休恢复')),
                  DropdownMenuItem(
                    value: 'shortRestOne',
                    child: Text('短休恢复 1 次'),
                  ),
                  DropdownMenuItem(value: 'longRest', child: Text('长休恢复')),
                  DropdownMenuItem(value: 'none', child: Text('不自动恢复')),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => recovery = value);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              final maximum = int.tryParse(maximumController.text.trim()) ?? 0;
              if (name.isEmpty || maximum <= 0) return;
              final id =
                  initial?.id ??
                  'custom-resource-${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '')}';
              Navigator.of(context).pop(
                Dnd5eClassResource(
                  id: id.isEmpty
                      ? 'custom-resource-${DateTime.now().microsecondsSinceEpoch}'
                      : id,
                  name: name,
                  maximum: maximum,
                  recovery: recovery,
                ),
              );
            },
            child: Text(initial == null ? '添加' : '保存'),
          ),
        ],
      ),
    ),
  );
  nameController.dispose();
  maximumController.dispose();
  return result;
}
