// character_detail_page.dart 的 part：职业资源区与 HP/资源调整表单。
part of 'character_detail_page.dart';

class _ResourcesPanel extends StatefulWidget {
  const _ResourcesPanel({
    required this.character,
    this.onUpdateRuntime,
    this.onSaveCharacter,
  });

  final CharacterSheet character;
  final CharacterRuntimeUpdate? onUpdateRuntime;
  final CharacterSaveCallback? onSaveCharacter;

  @override
  State<_ResourcesPanel> createState() => _ResourcesPanelState();
}

class _ResourcesPanelState extends State<_ResourcesPanel> {
  late Map<String, int> _classResourcesUsed;
  late List<Dnd5eClassResource> _resources;

  @override
  void initState() {
    super.initState();
    _syncFromCharacter();
  }

  @override
  void didUpdateWidget(covariant _ResourcesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.character != widget.character) _syncFromCharacter();
  }

  void _syncFromCharacter() {
    _resources = [...widget.character.classResources];
    _classResourcesUsed = {
      for (final resource in _resources)
        resource.id: (widget.character.classResourcesUsed[resource.id] ?? 0)
            .clamp(0, resource.maximum)
            .toInt(),
    };
  }

  @override
  Widget build(BuildContext context) {
    // §3.12：该等级不在职业声明范围内 → 没有资源时显式说"未声明"，不渲染成 0。
    // 三分支口径与法术位区完全一致，文案唯一实现在
    // [DeclaredLevels.rangeLevelLabel]：职业身份未声明 != 该职业没有资源。
    final declaredLevels = DeclaredLevels.fromCharacter(widget.character);
    final rangeLevelLabel = declaredLevels.rangeLevelLabel(
      isDeclared: DeclaredLevels.isDeclared(widget.character),
    );
    final levelUndeclared = declaredLevels.undeclares(widget.character.level);
    return _Section(
      title: '职业资源',
      icon: Icons.bolt_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_resources.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => _restoreResources(longRest: false),
                    icon: const Icon(Icons.bedtime_outlined),
                    label: const Text('恢复短休资源'),
                  ),
                  FilledButton.icon(
                    onPressed: () => _restoreResources(longRest: true),
                    icon: const Icon(Icons.night_shelter_outlined),
                    label: const Text('恢复长休资源'),
                  ),
                ],
              ),
            ),
          if (_resources.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: _emptyClassValueNotice(
                rangeLevelLabel: rangeLevelLabel,
                levelUndeclared: levelUndeclared,
                emptyLabel: '暂无可追踪资源',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                const gap = 12.0;
                final columns = constraints.maxWidth >= 900
                    ? 3
                    : constraints.maxWidth >= 600
                    ? 2
                    : 1;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final resource in _resources)
                      SizedBox(
                        width: width,
                        child: _ClassResourceLine(
                          resource: resource,
                          current:
                              resource.maximum -
                              (_classResourcesUsed[resource.id] ?? 0),
                          onSetCurrent: (value) =>
                              _setResourceCurrent(resource, value),
                          onEdit: widget.onSaveCharacter == null
                              ? null
                              : () => _editResource(resource),
                          onDelete: widget.onSaveCharacter == null
                              ? null
                              : () => _deleteResource(resource),
                        ),
                      ),
                  ],
                );
              },
            ),
          if (widget.onSaveCharacter != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: _addResource,
              icon: const Icon(Icons.add),
              label: const Text('添加资源'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _setResourceCurrent(
    Dnd5eClassResource resource,
    int current,
  ) async {
    final next = Map<String, int>.from(_classResourcesUsed);
    next[resource.id] = (resource.maximum - current)
        .clamp(0, resource.maximum)
        .toInt();
    setState(() => _classResourcesUsed = next);
    await widget.onUpdateRuntime?.call(classResourcesUsed: next);
  }

  Future<void> _restoreResources({required bool longRest}) async {
    final next = Dnd5eRules.classResourcesAfterRest(
      resources: _resources,
      used: _classResourcesUsed,
      longRest: longRest,
    );
    setState(() => _classResourcesUsed = next);
    await widget.onUpdateRuntime?.call(classResourcesUsed: next);
  }

  Future<void> _addResource() async {
    final resource = await _showResourceDialog(context);
    if (resource == null) return;
    await _saveResourceDefinitions([..._resources, resource]);
  }

  Future<void> _editResource(Dnd5eClassResource resource) async {
    final updated = await _showResourceDialog(context, initial: resource);
    if (updated == null) return;
    await _saveResourceDefinitions([
      for (final item in _resources)
        if (item.id == resource.id) updated else item,
    ]);
  }

  Future<void> _deleteResource(Dnd5eClassResource resource) async {
    await _saveResourceDefinitions(
      _resources
          .where((item) => item.id != resource.id)
          .toList(growable: false),
    );
  }

  Future<void> _saveResourceDefinitions(
    List<Dnd5eClassResource> resources,
  ) async {
    final used = Map<String, int>.from(_classResourcesUsed)
      ..removeWhere((id, _) => !resources.any((resource) => resource.id == id));
    for (final resource in resources) {
      used[resource.id] = (used[resource.id] ?? 0).clamp(0, resource.maximum);
    }
    final data = Map<String, Object?>.from(widget.character.dataMap)
      ..['classResources'] = [
        for (final resource in resources)
          <String, Object?>{
            'id': resource.id,
            'name': resource.name,
            'maximum': resource.maximum,
            'recovery': resource.recovery,
          },
      ];
    final saved = await widget.onSaveCharacter?.call(
      widget.character.copyWith(data: data),
    );
    if (saved != true || !mounted) return;
    setState(() {
      _resources = resources;
      _classResourcesUsed = used;
    });
    await widget.onUpdateRuntime?.call(classResourcesUsed: used);
  }
}

class _ClassResourceLine extends StatelessWidget {
  const _ClassResourceLine({
    required this.resource,
    required this.current,
    required this.onSetCurrent,
    this.onEdit,
    this.onDelete,
  });

  final Dnd5eClassResource resource;
  final int current;
  final ValueChanged<int> onSetCurrent;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bolt_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    resource.name,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (onEdit != null || onDelete != null)
                  PopupMenuButton<String>(
                    tooltip: '资源操作',
                    onSelected: (value) {
                      if (value == 'edit') onEdit?.call();
                      if (value == 'delete') onDelete?.call();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('编辑资源')),
                      PopupMenuItem(value: 'delete', child: Text('删除资源')),
                    ],
                  ),
              ],
            ),
            Text(
              '${resource.name} $current/${resource.maximum}',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(_resourceRecoveryLabel(resource.recovery)),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: resource.maximum == 0 ? 0 : current / resource.maximum,
            ),
            const SizedBox(height: 8),
            if (resource.maximum <= 8)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var index = 0; index < resource.maximum; index++)
                    IconButton.filledTonal(
                      key: Key('resource-pip-${resource.id}-$index'),
                      tooltip: '设置${resource.name}为${index + 1}',
                      onPressed: () =>
                          onSetCurrent(index < current ? index : index + 1),
                      icon: Icon(
                        index < current ? Icons.circle : Icons.circle_outlined,
                        size: 16,
                      ),
                    ),
                ],
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => _setNumericCurrent(context),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('设置当前值'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _setNumericCurrent(BuildContext context) async {
    final result = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _ResourceCurrentSheet(
        name: resource.name,
        current: current,
        maximum: resource.maximum,
      ),
    );
    if (result != null) onSetCurrent(result);
  }
}

class _HpAdjustmentSheet extends StatefulWidget {
  const _HpAdjustmentSheet();

  @override
  State<_HpAdjustmentSheet> createState() => _HpAdjustmentSheetState();
}

class _HpAdjustmentSheetState extends State<_HpAdjustmentSheet> {
  final _controller = TextEditingController(text: '1');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('调整生命值', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              key: const Key('hp-quick-value-field'),
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '数值',
                prefixIcon: Icon(Icons.monitor_heart_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(-_positiveValue),
                    icon: const Icon(Icons.heart_broken_outlined),
                    label: const Text('受到伤害'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => Navigator.of(context).pop(_positiveValue),
                    icon: const Icon(Icons.healing_outlined),
                    label: const Text('恢复 HP'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int get _positiveValue {
    final parsed = int.tryParse(_controller.text.trim());
    return parsed == null || parsed <= 0 ? 1 : parsed;
  }
}

class _ResourceCurrentSheet extends StatefulWidget {
  const _ResourceCurrentSheet({
    required this.name,
    required this.current,
    required this.maximum,
  });

  final String name;
  final int current;
  final int maximum;

  @override
  State<_ResourceCurrentSheet> createState() => _ResourceCurrentSheetState();
}

class _ResourceCurrentSheetState extends State<_ResourceCurrentSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: '${widget.current}',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '当前值（0-${widget.maximum}）',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                final value = int.tryParse(_controller.text.trim());
                Navigator.of(context).pop(
                  (value ?? widget.current).clamp(0, widget.maximum).toInt(),
                );
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }
}

String _resourceRecoveryLabel(String recovery) {
  return switch (recovery) {
    'shortRest' => '短休恢复',
    'shortRestOne' => '短休恢复 1 次',
    'none' => '不自动恢复',
    _ => '长休恢复',
  };
}
