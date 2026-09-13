// character_detail_page.dart 的 part：法术面板与法术位行。
part of 'character_detail_page.dart';

class _SpellsPanel extends StatefulWidget {
  const _SpellsPanel({
    required this.character,
    required this.contentEntries,
    this.onUpdateRuntime,
    this.onSaveCharacter,
    this.packagePriorities = const <String, int>{},
    this.ruleOverrides = RuleOverrideIndex.empty,
    this.sources = const <String, RuleFieldSource>{},
    this.conflicts = const <RuleOverrideConflict>[],
    this.originLabels = const <String, String>{},
    this.entryOriginId,
    this.onDisableOverride,
    this.onResolveConflicts,
  });

  final CharacterSheet character;
  final List<ContentEntry> contentEntries;
  final CharacterRuntimeUpdate? onUpdateRuntime;
  final CharacterSaveCallback? onSaveCharacter;
  final Map<String, int> packagePriorities;

  /// 跨包职业规则声明索引（决策 D3）：回退解析必须看得见勘误包（L）。
  final RuleOverrideIndex ruleOverrides;

  /// 列级来源快照（`data.classRuleSources`，任务 9 消费）。
  final Map<String, RuleFieldSource> sources;
  final List<RuleOverrideConflict> conflicts;
  final Map<String, String> originLabels;

  /// 角色自身条目的 originId：来源是它时不显示关闭按钮（C）。
  final String? entryOriginId;
  final Future<void> Function(String originId)? onDisableOverride;
  final Future<void> Function(List<RuleOverrideConflict> conflicts)?
  onResolveConflicts;

  @override
  State<_SpellsPanel> createState() => _SpellsPanelState();
}

class _SpellsPanelState extends State<_SpellsPanel> {
  static const _quickEditService = CharacterQuickEditService();
  late Map<String, int> _slotsUsed;

  @override
  void initState() {
    super.initState();
    _syncFromCharacter();
  }

  @override
  void didUpdateWidget(covariant _SpellsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.character != widget.character) {
      _syncFromCharacter();
    }
  }

  void _syncFromCharacter() {
    final maximums = _slotMaximums();
    _slotsUsed = {
      for (final entry in maximums.entries)
        entry.key: (widget.character.spellSlotsUsed[entry.key] ?? 0)
            .clamp(0, entry.value)
            .toInt(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final ability = _spellcastingAbility();
    final slotMaximums = _slotMaximums();
    final resolved = CharacterOverrideResolver.resolve(widget.character);
    final spellRefs = resolved.spellEntryIds;
    final spellsByLevel = _spellsByLevel(spellRefs);
    // §3.12：该等级不在职业声明范围内 → 数值为空时显式说"未声明"，不渲染成 0。
    // 三分支（口径只在 [DeclaredLevels.rangeLevelLabel] 一处）：
    // 1. 职业身份未声明（`declared == false`）→ 范围级文案：**不知道**这个职业
    //    有什么，不能说成"暂无法术位"；
    // 2. 已声明但完全没有等级表（rogue / monk 这类 `max == null`）→ "暂无法术位"
    //    是关于该职业的真实陈述；
    // 3. 有等级声明但当前等级不在范围内 → 等级级 `UndeclaredLevelNotice`。
    final declaredLevels = DeclaredLevels.fromCharacter(widget.character);
    final classDeclared = DeclaredLevels.isDeclared(widget.character);
    final rangeLevelLabel = declaredLevels.rangeLevelLabel(
      isDeclared: classDeclared,
    );
    final levelUndeclared = declaredLevels.undeclares(widget.character.level);

    if (ability == null &&
        slotMaximums.isEmpty &&
        spellRefs.isEmpty &&
        resolved.customSpells.isEmpty &&
        widget.onSaveCharacter == null) {
      return const _EmptyPanel(title: '暂无法术引用');
    }

    final abilityLabel = ability == null
        ? '无'
        : Dnd5eRules.abilityLabels[ability] ?? ability;
    final saveDc = ability == null
        ? null
        : 8 +
              Dnd5eRules.proficiencyBonus(widget.character.level) +
              Dnd5eRules.abilityModifier(
                Dnd5eRules.abilityScore(widget.character.abilityMap, ability),
              );
    final spellAttack = saveDc == null ? null : saveDc - 8;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 冲突提示条置顶：同 tier 多来源抢同一列时用户必须看见并能选择（D6）。
        RuleOverrideConflictBanner(
          conflicts: widget.conflicts,
          originLabels: widget.originLabels,
          onResolve: widget.onResolveConflicts,
        ),
        _Section(
          title: '施法概览',
          icon: Icons.auto_fix_high_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('施法属性 $abilityLabel')),
                  if (saveDc != null) Chip(label: Text('法术豁免 DC $saveDc')),
                  if (spellAttack != null)
                    Chip(
                      label: Text(
                        '法术攻击 ${Dnd5eRules.formatModifier(spellAttack)}',
                      ),
                    ),
                ],
              ),
              _sourceChips(<String>[
                RuleFieldPath.spellcasting('mode'),
                RuleFieldPath.spellcasting('ability'),
              ]),
            ],
          ),
        ),
        _Section(
          title: '法术位',
          icon: Icons.hourglass_bottom_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (slotMaximums.isEmpty)
                _emptyClassValueNotice(
                  rangeLevelLabel: rangeLevelLabel,
                  levelUndeclared: levelUndeclared,
                  emptyLabel: '暂无法术位',
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              else
                for (final entry in _sortedSlotEntries(slotMaximums))
                  _SpellSlotLine(
                    level: entry.key,
                    used: _slotsUsed[entry.key] ?? 0,
                    maximum: entry.value,
                    onConsume: () => _adjustSlot(entry.key, 1),
                    onRecover: () => _adjustSlot(entry.key, -1),
                  ),
              _sourceChips(<String>[
                RuleFieldPath.spellcasting('slots'),
                RuleFieldPath.spellcasting('prepared'),
              ]),
            ],
          ),
        ),
        _Section(
          title: '已知与已准备法术',
          icon: Icons.menu_book_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.onSaveCharacter != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FilledButton.tonalIcon(
                    onPressed: _addSpell,
                    icon: const Icon(Icons.add),
                    label: const Text('添加法术'),
                  ),
                ),
              if (spellRefs.isEmpty && resolved.customSpells.isEmpty)
                Text('暂无法术', style: Theme.of(context).textTheme.bodyMedium)
              else
                for (final entry in spellsByLevel.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(
                      _spellLevelLabel(entry.key),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  for (final spell in entry.value)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.auto_fix_high_outlined),
                      title: Text(_entryName(spell)),
                      subtitle: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            resolved.effectivePreparedSpellEntryIds.contains(spell)
                                ? '已准备'
                                : '未准备',
                          ),
                          // 契约 §3.11 A3：显式法术选择的选中值由规则派生成
                          // `alwaysPreparedEntryIds`（"自动准备"，用户不能手动取消），
                          // 这里给出标记（secondaryContainer / onSecondaryContainer，
                          // 无新 token）。手动准备的存储是 preparedEntryIds；"已准备"
                          // 判定读两者的并集（`effectivePreparedSpellEntryIds`）。
                          if (resolved.alwaysPreparedSpellEntryIds.contains(spell))
                            Chip(
                              key: Key('always-prepared-$spell'),
                              label: const Text('始终准备'),
                              labelStyle: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSecondaryContainer,
                                  ),
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.secondaryContainer,
                              side: BorderSide.none,
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                        ],
                      ),
                      onTap: () => _openSpell(spell),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.onSaveCharacter != null)
                            IconButton(
                              tooltip:
                                  resolved.effectivePreparedSpellEntryIds.contains(spell)
                                  ? '取消准备${_entryName(spell)}'
                                  : '准备${_entryName(spell)}',
                              onPressed: () => _setPrepared(
                                spell,
                                !resolved.effectivePreparedSpellEntryIds.contains(spell),
                              ),
                              icon: Icon(
                                resolved.effectivePreparedSpellEntryIds.contains(spell)
                                    ? Icons.check_circle
                                    : Icons.check_circle_outline,
                              ),
                            ),
                          if (widget.onSaveCharacter != null)
                            IconButton(
                              tooltip: '移除${_entryName(spell)}',
                              onPressed: () => _removeSpell(spell),
                              icon: const Icon(Icons.delete_outline),
                            ),
                        ],
                      ),
                    ),
                ],
              if (resolved.customSpells.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Text(
                    '自定义法术',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                for (final spell in resolved.customSpells)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.auto_awesome_outlined),
                    title: Text(_customSpellName(spell)),
                    subtitle: Text(_customSpellSummary(spell)),
                    onTap: () => _openCustomSpell(spell),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// 法术位上限：先看角色创建 / 再派生时持久化的 `data.spellSlots`。
  ///
  /// 判据是**键是否存在**（H），不是"值是否非空"：键存在就是"已经派生过"——空表
  /// `{}` 的含义是"没有法术位"（例如关闭了声明 `spellcasting` 的来源），绝不回退
  /// 到 [_fallbackClassRules] 把被关闭来源的旧值读回来。只有老角色（这个键根本没
  /// 派生过）才回退解析规则档案。
  Map<String, int> _slotMaximums() {
    final derived = widget.character.dataMap['spellSlots'];
    if (derived is Map) {
      return {
        for (final entry in derived.entries)
          '${entry.key}': entry.value is num
              ? (entry.value as num).toInt()
              : int.tryParse('${entry.value}') ?? 0,
      };
    }
    if (!DeclaredLevels.isDeclared(widget.character)) return const {};
    return _fallbackClassRules().spellSlots(widget.character.level);
  }

  /// 施法属性：同样按**键是否存在**判断（H）。键存在且为 `null` = 规则侧
  /// **未声明**施法属性（关闭来源后的正常结果），不得再回退解析——那会把被关闭
  /// 来源的 `ability` 读回来，与同屏的"无"自相矛盾。
  String? _spellcastingAbility() {
    if (widget.character.dataMap.containsKey('spellcastingAbility')) {
      final derived = widget.character.dataMap['spellcastingAbility'];
      return derived is String && Dnd5eRules.abilityLabels.containsKey(derived)
          ? derived
          : null;
    }
    if (!DeclaredLevels.isDeclared(widget.character)) return null;
    return _fallbackClassRules().spellcastingAbility;
  }

  /// 老角色（没有持久化派生快照）的回退解析：与短休判定走**同一个共享实现**
  /// [_resolveRulesWithOverrides]（带覆盖 + 包优先级），不在这里再写第二份。
  ResolvedClassRules _fallbackClassRules() => _resolveRulesWithOverrides(
    widget.character,
    widget.packagePriorities,
    overrides: widget.ruleOverrides,
  );

  /// 只渲染**快照里真有来源**的列，避免每一列都显示"来源未知"的噪音。
  Widget _sourceChips(List<String> fields) {
    final known = <String>[
      for (final field in fields)
        if (widget.sources.containsKey(field)) field,
    ];
    if (known.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final field in known)
            RuleSourceChip(
              field: field,
              source: widget.sources[field],
              originLabels: widget.originLabels,
              entryOriginId: widget.entryOriginId,
              onDisableOverride: widget.onDisableOverride,
            ),
        ],
      ),
    );
  }

  Future<void> _adjustSlot(String level, int delta) async {
    final maximum = _slotMaximums()[level] ?? 0;
    final current = _slotsUsed[level] ?? 0;
    final next = Map<String, int>.from(_slotsUsed);
    next[level] = (current + delta).clamp(0, maximum).toInt();
    setState(() => _slotsUsed = next);
    await widget.onUpdateRuntime?.call(
      spellSlotsUsed: Map.unmodifiable(_slotsUsed),
    );
  }

  String _entryName(String entryId) {
    for (final entry in widget.contentEntries) {
      if (entry.id == entryId) return entry.name;
    }
    return entryId;
  }

  Map<int, List<String>> _spellsByLevel(List<String> spellRefs) {
    final result = <int, List<String>>{};
    for (final spell in spellRefs) {
      final entry = widget.contentEntries
          .where((candidate) => candidate.id == spell)
          .firstOrNull;
      final value = entry?.structured['level'];
      final level = value is num ? value.toInt() : int.tryParse('$value') ?? 99;
      (result[level] ??= []).add(spell);
    }
    return Map.fromEntries(
      result.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  String _spellLevelLabel(int level) {
    if (level == 0) return '戏法';
    if (level == 99) return '未分类法术';
    return Dnd5eRules.spellLevelLabel('$level');
  }

  void _openSpell(String entryId) {
    final entry = widget.contentEntries
        .where((candidate) => candidate.id == entryId)
        .firstOrNull;
    if (entry == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前资料库中找不到这条法术')));
      return;
    }
    showContentEntryPreviewDialog(
      context,
      entry: entry,
      entries: widget.contentEntries,
    );
  }

  String _customSpellName(Map<String, Object?> spell) {
    final name = spell['name']?.toString().trim() ?? '';
    return name.isEmpty ? '未命名法术' : name;
  }

  String _customSpellSummary(Map<String, Object?> spell) {
    final rawLevel = spell['level'];
    final level = rawLevel is num
        ? rawLevel.toInt()
        : int.tryParse('$rawLevel') ?? 99;
    final school = spell['school']?.toString().trim() ?? '';
    final parts = <String>[_spellLevelLabel(level)];
    if (school.isNotEmpty) parts.add(school);
    return parts.join(' · ');
  }

  Future<void> _openCustomSpell(Map<String, Object?> spell) {
    final description = spell['description']?.toString().trim() ?? '';
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_customSpellName(spell)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _customSpellSummary(spell),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 12),
            Text(description.isEmpty ? '暂无说明' : description),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _addSpell() async {
    final entry = await _pickContentEntry(
      context,
      title: '添加法术',
      entries: widget.contentEntries
          .where((entry) => entry.type == 'spell')
          .toList(growable: false),
    );
    if (entry == null) return;
    await widget.onSaveCharacter?.call(
      _quickEditService.addSpell(widget.character, entry.id),
    );
  }

  Future<void> _removeSpell(String entryId) async {
    await widget.onSaveCharacter?.call(
      _quickEditService.removeSpell(widget.character, entryId),
    );
  }

  Future<void> _setPrepared(String entryId, bool prepared) async {
    await widget.onSaveCharacter?.call(
      _quickEditService.setSpellPrepared(widget.character, entryId, prepared),
    );
  }
}

class _SpellSlotLine extends StatelessWidget {
  const _SpellSlotLine({
    required this.level,
    required this.used,
    required this.maximum,
    required this.onConsume,
    required this.onRecover,
  });

  final String level;
  final int used;
  final int maximum;
  final VoidCallback onConsume;
  final VoidCallback onRecover;

  @override
  Widget build(BuildContext context) {
    final label = Dnd5eRules.spellLevelLabel(level);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.auto_awesome_outlined),
      title: Text('$label $used/$maximum 已用'),
      subtitle: LinearProgressIndicator(
        value: maximum == 0 ? 0 : used / maximum,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '恢复$label法术位',
            onPressed: used <= 0 ? null : onRecover,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          IconButton(
            tooltip: '消耗$label法术位',
            onPressed: used >= maximum ? null : onConsume,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}

List<MapEntry<String, int>> _sortedSlotEntries(Map<String, int> slots) {
  final entries = slots.entries.toList();
  entries.sort((a, b) => int.parse(a.key).compareTo(int.parse(b.key)));
  return entries;
}
