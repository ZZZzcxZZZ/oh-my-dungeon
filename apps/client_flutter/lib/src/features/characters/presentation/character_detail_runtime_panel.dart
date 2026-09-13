// character_detail_page.dart 的 part：运行期状态面板与状态网格。
part of 'character_detail_page.dart';

class _RuntimePanel extends StatefulWidget {
  const _RuntimePanel({
    required this.character,
    this.onUpdateRuntime,
    this.packagePriorities = const <String, int>{},
    this.ruleOverrides = RuleOverrideIndex.empty,
  });

  final CharacterSheet character;
  final CharacterRuntimeUpdate? onUpdateRuntime;

  /// 包 id → priority（决策 D2）：短休的契约魔法判定必须与建档 / 再派生同一份，
  /// 否则同一条覆盖在数值与行为两侧得到不同解释（L）。
  final Map<String, int> packagePriorities;

  /// 跨包职业规则声明索引（决策 D3）：短休判定必须看得见勘误包声明的
  /// `spellcasting.archetype`，否则"关闭该勘误来源"在行为路径上无效（L）。
  final RuleOverrideIndex ruleOverrides;

  @override
  State<_RuntimePanel> createState() => _RuntimePanelState();
}

class _RuntimePanelState extends State<_RuntimePanel> {
  final _conditionSearchController = TextEditingController();

  static const _commonConditions = [
    '失明',
    '魅惑',
    '耳聋',
    '恐慌',
    '擒抱',
    '失能',
    '隐形',
    '麻痹',
    '石化',
    '中毒',
    '倒地',
    '束缚',
    '震慑',
    '昏迷',
    '力竭 1',
    '力竭 2',
    '力竭 3',
    '力竭 4',
    '力竭 5',
    '力竭 6',
  ];

  late int _currentHp;
  late int _temporaryHp;
  late bool _inspiration;
  late List<String> _conditions;
  late int _deathSaveSuccesses;
  late int _deathSaveFailures;

  @override
  void initState() {
    super.initState();
    _syncFromCharacter();
  }

  @override
  void didUpdateWidget(covariant _RuntimePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.character != widget.character) {
      _syncFromCharacter();
    }
  }

  void _syncFromCharacter() {
    _currentHp = widget.character.currentHp;
    _temporaryHp = widget.character.temporaryHp;
    _inspiration = widget.character.inspiration;
    _conditions = [...widget.character.conditions];
    _deathSaveSuccesses = widget.character.deathSaveSuccesses;
    _deathSaveFailures = widget.character.deathSaveFailures;
  }

  @override
  void dispose() {
    _conditionSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editable = widget.onUpdateRuntime != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(
          title: '状态',
          icon: Icons.favorite_outline,
          child: _RuntimeStatusGrid(
            currentHp: _currentHp,
            maxHp: widget.character.maxHp,
            temporaryHp: _temporaryHp,
            inspiration: _inspiration,
            deathSaveSuccesses: _deathSaveSuccesses,
            deathSaveFailures: _deathSaveFailures,
            onAdjustHp: editable ? _showHpAdjustment : null,
            onTemporaryHpDecrease: !editable || _temporaryHp <= 0
                ? null
                : () => _setTemporaryHp(_temporaryHp - 1),
            onTemporaryHpIncrease: editable
                ? () => _setTemporaryHp(_temporaryHp + 1)
                : null,
            onToggleInspiration: editable
                ? () => _setInspiration(!_inspiration)
                : null,
            onDeathSaveSuccess: !editable || _deathSaveSuccesses >= 3
                ? null
                : () => _setDeathSaveSuccesses(_deathSaveSuccesses + 1),
            onDeathSaveFailure: !editable || _deathSaveFailures >= 3
                ? null
                : () => _setDeathSaveFailures(_deathSaveFailures + 1),
          ),
        ),
        if (editable)
          _Section(
            title: '休息',
            icon: Icons.hotel_outlined,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _takeShortRest,
                  icon: const Icon(Icons.bedtime_outlined),
                  label: const Text('短休'),
                ),
                FilledButton.icon(
                  onPressed: _takeLongRest,
                  icon: const Icon(Icons.night_shelter_outlined),
                  label: const Text('长休'),
                ),
                OutlinedButton.icon(
                  onPressed: _resetDeathSaves,
                  icon: const Icon(Icons.restart_alt_outlined),
                  label: const Text('重置死亡豁免'),
                ),
              ],
            ),
          ),
        _Section(
          title: '状态与效果',
          icon: Icons.warning_amber_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_conditions.isEmpty)
                    Text('暂无状态', style: Theme.of(context).textTheme.bodyMedium)
                  else
                    for (final condition in _conditions)
                      InputChip(
                        avatar: const Icon(Icons.flag_outlined, size: 18),
                        deleteIcon: const Icon(Icons.cancel),
                        label: Text(condition),
                        onDeleted: editable
                            ? () => _removeCondition(condition)
                            : null,
                      ),
                ],
              ),
              if (editable) ...[
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: TextField(
                    key: const Key('condition-search-field'),
                    controller: _conditionSearchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: '搜索或输入自定义状态',
                      prefixIcon: const Icon(Icons.search_outlined),
                      suffixIcon: _conditionSearchController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: '清空状态搜索',
                              onPressed: () {
                                setState(_conditionSearchController.clear);
                              },
                              icon: const Icon(Icons.close_outlined),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final condition in _filteredConditionOptions())
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 18),
                        label: Text(condition),
                        onPressed: () => _addCondition(condition),
                      ),
                    if (_canAddCustomCondition())
                      FilledButton.icon(
                        onPressed: _addCustomCondition,
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('添加自定义状态'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showHpAdjustment() async {
    final delta = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => const _HpAdjustmentSheet(),
    );
    if (delta == null) return;
    // 2024：伤害先扣临时生命值，溢出才扣当前生命值。
    final next = Dnd5eRules.applyHitPointDelta(
      current: _currentHp,
      maximum: widget.character.maxHp,
      temporary: _temporaryHp,
      delta: delta,
    );
    setState(() {
      _currentHp = next.current;
      _temporaryHp = next.temporary;
    });
    await widget.onUpdateRuntime?.call(
      currentHp: next.current,
      temporaryHp: next.temporary,
    );
  }

  Future<void> _setTemporaryHp(int value) async {
    setState(() => _temporaryHp = value);
    await widget.onUpdateRuntime?.call(temporaryHp: value);
  }

  Future<void> _setInspiration(bool value) async {
    setState(() => _inspiration = value);
    await widget.onUpdateRuntime?.call(inspiration: value);
  }

  Future<void> _addCondition(String condition) async {
    final normalized = condition.trim();
    if (normalized.isEmpty || _conditions.contains(normalized)) return;
    final next = [..._conditions, normalized];
    setState(() => _conditions = next);
    await widget.onUpdateRuntime?.call(conditions: next);
  }

  List<String> _filteredConditionOptions() {
    final query = _conditionSearchController.text.trim();
    final options = _commonConditions.where((condition) {
      if (_conditions.contains(condition)) return false;
      if (query.isEmpty) return true;
      return condition.contains(query);
    }).toList();
    return query.isEmpty ? options.take(12).toList() : options;
  }

  bool _canAddCustomCondition() {
    final query = _conditionSearchController.text.trim();
    if (query.isEmpty || _conditions.contains(query)) return false;
    return !_commonConditions.contains(query);
  }

  Future<void> _addCustomCondition() async {
    final condition = _conditionSearchController.text.trim();
    await _addCondition(condition);
    setState(_conditionSearchController.clear);
  }

  Future<void> _removeCondition(String condition) async {
    final next = _conditions.where((item) => item != condition).toList();
    setState(() => _conditions = next);
    await widget.onUpdateRuntime?.call(conditions: next);
  }

  Future<void> _setDeathSaveSuccesses(int value) async {
    final next = value.clamp(0, 3);
    setState(() => _deathSaveSuccesses = next);
    await widget.onUpdateRuntime?.call(deathSaveSuccesses: next);
  }

  Future<void> _setDeathSaveFailures(int value) async {
    final next = value.clamp(0, 3);
    setState(() => _deathSaveFailures = next);
    await widget.onUpdateRuntime?.call(deathSaveFailures: next);
  }

  Future<void> _resetDeathSaves() async {
    setState(() {
      _deathSaveSuccesses = 0;
      _deathSaveFailures = 0;
    });
    await widget.onUpdateRuntime?.call(
      deathSaveSuccesses: 0,
      deathSaveFailures: 0,
    );
  }

  Future<void> _takeShortRest() {
    // 邪术师契约魔法在短休恢复全部法术位；其他职业短休不回法术位。
    // 判定与取值共用**同一份**带用户覆盖的解析结果（L）：只解析一次，否则关闭了声明
    // `archetype: pact` 的来源后，短休仍按旧规则恢复全部法术位——同屏数值已按覆盖
    // 解析，行为没有。
    final rules = _resolveRulesWithOverrides(
      widget.character,
      widget.packagePriorities,
      overrides: widget.ruleOverrides,
    );
    final Map<String, int>? spellSlotsUsed = rules.usesPactMagic
        ? Dnd5eRules.spellSlotsAfterRest(
            rules: rules,
            used: widget.character.spellSlotsUsed,
            longRest: false,
          )
        : null;
    final next = Dnd5eRules.classResourcesAfterRest(
      resources: widget.character.classResources,
      used: widget.character.classResourcesUsed,
      longRest: false,
    );
    setState(() {
      _deathSaveSuccesses = 0;
      _deathSaveFailures = 0;
    });
    return widget.onUpdateRuntime?.call(
          deathSaveSuccesses: 0,
          deathSaveFailures: 0,
          classResourcesUsed: next,
          spellSlotsUsed: spellSlotsUsed,
        ) ??
        Future.value();
  }

  Future<void> _takeLongRest() async {
    final classResourcesUsed = Dnd5eRules.classResourcesAfterRest(
      resources: widget.character.classResources,
      used: widget.character.classResourcesUsed,
      longRest: true,
    );
    // 长休恢复全部法术位（规则：完成长休后所有已消耗法术位恢复）。
    const spellSlotsUsed = <String, int>{};
    setState(() {
      _currentHp = widget.character.maxHp;
      _temporaryHp = 0;
      _deathSaveSuccesses = 0;
      _deathSaveFailures = 0;
    });
    await widget.onUpdateRuntime?.call(
      currentHp: widget.character.maxHp,
      temporaryHp: 0,
      deathSaveSuccesses: 0,
      deathSaveFailures: 0,
      classResourcesUsed: classResourcesUsed,
      spellSlotsUsed: spellSlotsUsed,
    );
  }
}

class _RuntimeStatusGrid extends StatelessWidget {
  const _RuntimeStatusGrid({
    required this.currentHp,
    required this.maxHp,
    required this.temporaryHp,
    required this.inspiration,
    required this.deathSaveSuccesses,
    required this.deathSaveFailures,
    required this.onAdjustHp,
    required this.onTemporaryHpDecrease,
    required this.onTemporaryHpIncrease,
    required this.onToggleInspiration,
    required this.onDeathSaveSuccess,
    required this.onDeathSaveFailure,
  });

  final int currentHp;
  final int maxHp;
  final int temporaryHp;
  final bool inspiration;
  final int deathSaveSuccesses;
  final int deathSaveFailures;
  final VoidCallback? onAdjustHp;
  final VoidCallback? onTemporaryHpDecrease;
  final VoidCallback? onTemporaryHpIncrease;
  final VoidCallback? onToggleInspiration;
  final VoidCallback? onDeathSaveSuccess;
  final VoidCallback? onDeathSaveFailure;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final columns = constraints.maxWidth >= 720
            ? 4
            : constraints.maxWidth >= 360
            ? 2
            : 1;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            SizedBox(
              width: width,
              height: 148,
              child: _RuntimeStatusTile(
                key: const Key('runtime-hp-panel'),
                icon: Icons.favorite_outline,
                title: '生命值',
                onTap: onAdjustHp,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '当前 HP $currentHp/$maxHp',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: maxHp <= 0 ? 0 : currentHp / maxHp,
                    ),
                    const Spacer(),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '点击调整',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: width,
              height: 148,
              child: _RuntimeStatusTile(
                key: const Key('runtime-temporary-hp-panel'),
                icon: Icons.shield_outlined,
                title: '临时生命值',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '临时 HP $temporaryHp',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          tooltip: '-1 临时 HP',
                          onPressed: onTemporaryHpDecrease,
                          icon: const Icon(Icons.remove),
                        ),
                        IconButton(
                          tooltip: '+1 临时 HP',
                          onPressed: onTemporaryHpIncrease,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: width,
              height: 148,
              child: _RuntimeStatusTile(
                key: const Key('runtime-inspiration-panel'),
                icon: Icons.auto_awesome_outlined,
                title: '激励',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(inspiration ? '当前可用' : '当前未获得'),
                    const Spacer(),
                    FilledButton.tonal(
                      onPressed: onToggleInspiration,
                      child: Text(inspiration ? '消耗激励' : '获得激励'),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: width,
              height: 148,
              child: _RuntimeStatusTile(
                key: const Key('runtime-death-saves-panel'),
                icon: Icons.monitor_heart_outlined,
                title: '死亡豁免',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('死亡豁免 $deathSaveSuccesses/$deathSaveFailures'),
                    const SizedBox(height: 4),
                    Text('成功 $deathSaveSuccesses · 失败 $deathSaveFailures'),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          tooltip: '死亡豁免成功 +1',
                          onPressed: onDeathSaveSuccess,
                          icon: const Icon(Icons.check_outlined),
                        ),
                        IconButton(
                          tooltip: '死亡豁免失败 +1',
                          onPressed: onDeathSaveFailure,
                          icon: const Icon(Icons.close_outlined),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RuntimeStatusTile extends StatelessWidget {
  const _RuntimeStatusTile({
    required this.icon,
    required this.title,
    required this.child,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(title, style: theme.textTheme.titleSmall),
                  ),
                  if (onTap != null) const Icon(Icons.edit_outlined, size: 17),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
