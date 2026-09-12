import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../domain/ability_score_generator.dart';
import '../domain/character.dart';
import '../domain/character_edit_draft.dart';
import '../domain/class_rule_summary.dart';
import '../domain/declared_levels.dart';
import '../domain/dnd5e_rules.dart';
import '../domain/equipment_cost.dart';
import '../domain/quick_build.dart';
import '../domain/rules_driven_character_builder.dart';
import '../domain/spell_selection_policy.dart';
import '../domain/structured_class_rules.dart';
import '../../content/domain/content_entry.dart';
import '../../content/presentation/content_entry_preview_page.dart';
import '../../campaigns/presentation/widgets/avatar_picker.dart';
import '../../rules/domain/character_build.dart';
import '../../rules/domain/character_rule_definition.dart';
import '../../rules/domain/character_rules_engine.dart';
import '../../rules/domain/rule_choice_quota.dart';
import '../../rules/domain/rule_choice_resolver.dart';
import '../../rules/domain/rule_choice_semantics.dart';
import '../../rules/domain/rule_profile.dart';
import 'widgets/character_builder_shell.dart';
import 'widgets/declared_level_banner.dart';
import 'widgets/declared_level_track_shape.dart';
import 'widgets/rule_choice_section.dart';

part 'character_editor_creation_flow.dart';
part 'character_editor_builder_page.dart';
part 'character_editor_builder_chrome.dart';
part 'character_editor_details_summary.dart';
part 'character_editor_rule_choices.dart';
part 'character_editor_level_sections.dart';
part 'character_editor_spell_sections.dart';
part 'character_editor_shared_widgets.dart';
class CharacterEditorPage extends StatefulWidget {
  const CharacterEditorPage({
    required this.onSubmit,
    this.initialCharacter,
    this.defaultCreationMethod = 'choose',
    this.contentEntries = const [],
    this.onPickImage,
    super.key,
  });

  final CharacterSheet? initialCharacter;
  final String defaultCreationMethod;
  final List<ContentEntry> contentEntries;
  final Future<bool> Function(CharacterEditDraft draft) onSubmit;

  /// 选择头像图片的回调。返回 `(bytes, mimeType)` 或 `null`（用户取消）。
  /// 注入式以便测试时替换为内存 fake，不触发原生 file_picker。
  final Future<({Uint8List bytes, String mimeType})?> Function()? onPickImage;

  @override
  State<CharacterEditorPage> createState() => _CharacterEditorPageState();
}

class _CharacterEditorPageState extends State<CharacterEditorPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _classController;
  late final TextEditingController _raceController;
  late final TextEditingController _levelController;
  late final TextEditingController _hpController;
  late final TextEditingController _maxHpController;
  late final TextEditingController _acController;
  late final TextEditingController _speedController;
  late final TextEditingController _initiativeController;
  late final TextEditingController _inventoryController;
  late final TextEditingController _notesController;
  late final TextEditingController _descriptionController;
  late final Map<String, TextEditingController> _characterControllers;
  late final Map<String, TextEditingController> _characterSectionControllers;
  late String _characterKind;
  late final Map<String, TextEditingController> _abilityControllers;
  late final Map<String, TextEditingController> _currencyControllers;
  late final Map<String, bool> _saves;
  late final Map<String, bool> _skills;
  late _CreationFlow _flow;
  Map<String, Object?>? _appliedRulesData;
  final Map<String, List<String>> _upgradeRuleChoices = {};
  bool _saving = false;

  // 头像选择状态（规范 §头像来源：本地角色头像离线保存在客户端）。
  Uint8List? _avatarBytes;
  String? _avatarMimeType;
  bool _pickingAvatar = false;
  String? _avatarPickError;

  String? get _currentAvatarUrl => widget.initialCharacter?.avatarUrl;
  bool get _editingCharacter =>
      widget.initialCharacter?.isNonPlayerCharacter == true;

  /// 把当前已选/已存在的头像序列化为可存入 CharacterEditDraft.avatarUrl
  /// 的字符串。新选图片编码为 data URL；未选则保留初始头像或 null。
  String? get _effectiveAvatarUrl {
    if (_avatarBytes != null && _avatarMimeType != null) {
      return 'data:$_avatarMimeType;base64,${base64Encode(_avatarBytes!)}';
    }
    return _currentAvatarUrl;
  }

  Future<void> _pickAvatarImage() async {
    final picker = widget.onPickImage;
    if (picker == null) return;
    setState(() {
      _pickingAvatar = true;
      _avatarPickError = null;
    });
    try {
      final result = await picker();
      if (!mounted) return;
      if (result == null) {
        setState(() => _pickingAvatar = false);
        return;
      }
      if (result.bytes.length > 2 * 1024 * 1024) {
        setState(() {
          _pickingAvatar = false;
          _avatarPickError = '头像图片不能超过 2 MB';
        });
        return;
      }
      setState(() {
        _avatarBytes = result.bytes;
        _avatarMimeType = result.mimeType;
        _pickingAvatar = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pickingAvatar = false;
        _avatarPickError = '选择图片失败';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    final character = widget.initialCharacter;
    _nameController = TextEditingController(text: character?.name ?? '');
    _classController = TextEditingController(
      text: character?.classSummary ?? '',
    );
    _raceController = TextEditingController(text: character?.raceSummary ?? '');
    _levelController = TextEditingController(text: '${character?.level ?? 1}');
    _hpController = TextEditingController(text: '${character?.currentHp ?? 0}');
    _maxHpController = TextEditingController(text: '${character?.maxHp ?? 0}');
    _acController = TextEditingController(
      text: '${character?.armorClass ?? 10}',
    );
    _speedController = TextEditingController(text: '${character?.speed ?? 30}');
    _initiativeController = TextEditingController(
      text: '${character?.initiativeBonus ?? 0}',
    );
    _inventoryController = TextEditingController(
      text: _inventoryToLines(character?.inventoryList ?? const []),
    );
    _notesController = TextEditingController(text: character?.notes ?? '');
    _descriptionController = TextEditingController(
      text: character?.description ?? '',
    );
    final characterProfile =
        character?.characterMap ?? const <String, Object?>{};
    _characterKind = character?.characterKind ?? 'player';
    _characterControllers = {
      for (final key in const [
        'templateRef',
        'size',
        'creatureType',
        'alignment',
        'challengeRating',
        'proficiencyBonus',
        'hitPointFormula',
      ])
        key: TextEditingController(text: '${characterProfile[key] ?? ''}'),
    };
    final markdownSections =
        character?.markdownSections ?? const <String, Object?>{};
    _characterSectionControllers = {
      for (final title in const ['感官与语言', '特质', '动作', '附赠动作', '反应', '传奇动作'])
        title: TextEditingController(text: '${markdownSections[title] ?? ''}'),
    };
    _abilityControllers = {
      for (final entry in Dnd5eRules.abilityLabels.entries)
        entry.key: TextEditingController(
          text:
              '${Dnd5eRules.abilityScore(character?.abilityMap ?? Dnd5eRules.defaultAbilities, entry.key)}',
        ),
    };
    _currencyControllers = {
      for (final key in ['cp', 'sp', 'ep', 'gp', 'pp'])
        key: TextEditingController(text: '${character?.currencyMap[key] ?? 0}'),
    };
    _saves = {
      for (final key in Dnd5eRules.abilityLabels.keys)
        key: character?.saveMap[key] == true,
    };
    _skills = {
      for (final skill in Dnd5eRules.skills)
        skill.name: character?.skillMap[skill.name] == true,
    };
    _flow = character == null
        ? _flowFromPreference(widget.defaultCreationMethod)
        : _CreationFlow.fullSheet;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _classController.dispose();
    _raceController.dispose();
    _levelController.dispose();
    _hpController.dispose();
    _maxHpController.dispose();
    _acController.dispose();
    _speedController.dispose();
    _initiativeController.dispose();
    _inventoryController.dispose();
    _notesController.dispose();
    _descriptionController.dispose();
    for (final controller in _characterControllers.values) {
      controller.dispose();
    }
    for (final controller in _characterSectionControllers.values) {
      controller.dispose();
    }
    for (final controller in _abilityControllers.values) {
      controller.dispose();
    }
    for (final controller in _currencyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialCharacter != null;
    if (!isEditing && _flow == _CreationFlow.choose) {
      return _buildCreationChoicePage(context);
    }
    if (!isEditing && _flow == _CreationFlow.standard) {
      return _StandardBuildPage(
        contentEntries: widget.contentEntries,
        onSubmit: _submitQuickBuild,
        onPickImage: widget.onPickImage,
        onContinueToFullSheet: () {
          setState(() => _flow = _CreationFlow.fullSheet);
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? '编辑角色' : '创建角色')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Section(
              title: '基础',
              child: Column(
                children: [
                  AvatarPicker(
                    key: const Key('character-avatar-picker'),
                    currentAvatarUrl: _currentAvatarUrl,
                    previewBytes: _avatarBytes,
                    isUploading: _pickingAvatar,
                    error: _avatarPickError,
                    onPick: _pickAvatarImage,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('character-name'),
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: '名称'),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('character-class-field'),
                          controller: _classController,
                          decoration: const InputDecoration(labelText: '职业'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          key: const Key('character-race-field'),
                          controller: _raceController,
                          decoration: const InputDecoration(labelText: '种族'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _numberField(
                          _levelController,
                          '等级',
                          key: const Key('character-level-field'),
                          onChanged: (_) => setState(() {
                            _appliedRulesData = null;
                            _upgradeRuleChoices.clear();
                            _applyRecommendedUpgradeChoices();
                          }),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _numberField(_speedController, '速度')),
                    ],
                  ),
                ],
              ),
            ),
            if (isEditing)
              if (_upgradePreview() case final preview?)
                _CharacterUpgradeSection(
                  preview: preview,
                  applied: _appliedRulesData != null,
                  onApply: preview.canApply ? _applyRulesUpgrade : null,
                  entries: widget.contentEntries,
                  onChoiceChanged: (key, selected) => setState(() {
                    _upgradeRuleChoices[key] = selected;
                    _appliedRulesData = null;
                    _applyRecommendedUpgradeChoices();
                  }),
                ),
            _Section(
              title: '能力值',
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final entry in Dnd5eRules.abilityLabels.entries)
                    SizedBox(
                      width: 120,
                      child: TextField(
                        key: Key('ability-${entry.key}-field'),
                        controller: _abilityControllers[entry.key],
                        decoration: InputDecoration(labelText: entry.value),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                ],
              ),
            ),
            if (_editingCharacter) _buildCharacterEditor(context),
            _Section(
              title: '战斗',
              child: Row(
                children: [
                  Expanded(child: _numberField(_hpController, 'HP')),
                  const SizedBox(width: 12),
                  Expanded(child: _numberField(_maxHpController, 'HP 上限')),
                  const SizedBox(width: 12),
                  Expanded(child: _numberField(_acController, 'AC')),
                  const SizedBox(width: 12),
                  Expanded(child: _numberField(_initiativeController, '先攻')),
                ],
              ),
            ),
            _Section(
              title: '豁免',
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final entry in Dnd5eRules.abilityLabels.entries)
                    FilterChip(
                      key: Key('save-${entry.key}-checkbox'),
                      label: Text(entry.value),
                      selected: _saves[entry.key] == true,
                      onSelected: (selected) {
                        setState(() => _saves[entry.key] = selected);
                      },
                    ),
                ],
              ),
            ),
            _Section(
              title: '技能',
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final skill in Dnd5eRules.skills)
                    FilterChip(
                      key: Key('skill-${skill.name}-checkbox'),
                      label: Text(skill.name),
                      selected: _skills[skill.name] == true,
                      onSelected: (selected) {
                        setState(() => _skills[skill.name] = selected);
                      },
                    ),
                ],
              ),
            ),
            _Section(
              title: '装备与货币',
              child: Column(
                children: [
                  TextField(
                    key: const Key('character-inventory-field'),
                    controller: _inventoryController,
                    decoration: const InputDecoration(
                      labelText: '装备，每行一个，例如：治疗药水 x2',
                    ),
                    minLines: 3,
                    maxLines: 5,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (final key in ['cp', 'sp', 'ep', 'gp', 'pp']) ...[
                        Expanded(
                          child: TextField(
                            key: Key('currency-$key-field'),
                            controller: _currencyControllers[key],
                            decoration: InputDecoration(labelText: key),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        if (key != 'pp') const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            _Section(
              title: '笔记',
              child: TextField(
                key: const Key('character-notes-field'),
                controller: _notesController,
                decoration: const InputDecoration(labelText: '背景、个性、临时说明'),
                minLines: 3,
                maxLines: 6,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('保存角色'),
          ),
        ),
      ),
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label, {
    Key? key,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      key: key,
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: TextInputType.number,
      onChanged: onChanged,
    );
  }

  Widget _buildCharacterEditor(BuildContext context) {
    return _Section(
      title: '怪物与 NPC 资料',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            key: const Key('character-kind-field'),
            initialValue: _characterKind,
            decoration: const InputDecoration(labelText: '类型'),
            items: const [
              DropdownMenuItem(value: 'monster', child: Text('怪物')),
              DropdownMenuItem(value: 'npc', child: Text('NPC')),
              DropdownMenuItem(value: 'companion', child: Text('同伴')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _characterKind = value);
            },
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final fieldWidth = constraints.maxWidth >= 680
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final field in const [
                    ('templateRef', '模板引用'),
                    ('size', '体型'),
                    ('creatureType', '生物类型'),
                    ('alignment', '阵营'),
                    ('challengeRating', '挑战等级 CR'),
                    ('proficiencyBonus', '熟练加值'),
                    ('hitPointFormula', '生命骰公式'),
                  ])
                    SizedBox(
                      width: fieldWidth,
                      child: TextField(
                        controller: _characterControllers[field.$1],
                        decoration: InputDecoration(labelText: field.$2),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('character-description-field'),
            controller: _descriptionController,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: '描述',
              hintText: '外观、习性、背景或主持人说明',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          Text('图鉴区块', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final entry in _characterSectionControllers.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                key: Key(
                  'character-section-${_characterSectionKey(entry.key)}',
                ),
                controller: entry.value,
                minLines: 3,
                maxLines: 8,
                decoration: InputDecoration(
                  labelText: entry.key,
                  hintText: '支持标题、列表和骰式等可读 Markdown',
                  alignLabelWithHint: true,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 升级预览用的职业规则解析（条目身份优先，§3.6）。选中条目不在内容仓库里
  /// （被删除等）时传 `entryId: null`，与 builder / 升级规划器**同一口径**：都退回
  /// [Dnd5eRules.resolveClassRules] 的"仅按展示名（classSummary）对齐档案"分支；
  /// 不再把原始 id 传进去（那会让预览与落库走两条解析路径）。不猜职业。
  ResolvedClassRules _resolveClassRules(String? entryId) {
    final entry = entryId == null ? null : _entryById(entryId);
    return Dnd5eRules.resolveClassRules(
      entryId: entry?.id,
      classSummary: entry?.name ?? '',
      structured: entry?.structured ?? const <String, Object?>{},
    );
  }

  ContentEntry? _entryById(String entryId) {
    for (final entry in widget.contentEntries) {
      if (entry.id == entryId) return entry;
    }
    return null;
  }

  _CharacterUpgradePreview? _upgradePreview() {
    final character = widget.initialCharacter;
    final buildJson = character?.dataMap['build'];
    if (character == null ||
        buildJson is! Map ||
        widget.contentEntries.isEmpty) {
      return null;
    }
    final targetLevel = _intValue(_levelController, character.level);
    if (targetLevel <= character.level || targetLevel > 20) return null;
    final previousBuild = CharacterBuild.fromJson(
      Map<String, Object?>.from(buildJson),
    );
    final nextBuild = CharacterBuild(
      level: targetLevel,
      selections: previousBuild.selections,
      choices: {
        ...previousBuild.choices,
        for (final entry in _upgradeRuleChoices.entries)
          entry.key: List<String>.unmodifiable(entry.value),
      },
      // `requires` 的能力门槛读**基础属性**（决策 D4），不是 `_abilityControllers`
      // 里的最终值：升级预览必须与引擎同口径，否则"门槛其实满足"的选择会被
      // 预览误判为不满足。
      abilities: previousBuild.abilities,
    );
    final engine = CharacterRulesEngine(
      entries: {for (final entry in widget.contentEntries) entry.id: entry},
    );
    // 池上限与引擎**同口径**（决策 D3）：数值只有 `RuleChoiceQuota.limitsFor`
    // 一处；否则预览会把其实超额的选择当成有效。
    final nextPoolLimits = RuleChoiceQuota.limitsFor(
      rules: _resolveClassRules(nextBuild.selections['class']),
      level: nextBuild.level,
    );
    final previousPoolLimits = RuleChoiceQuota.limitsFor(
      rules: _resolveClassRules(previousBuild.selections['class']),
      level: previousBuild.level,
    );
    final previousLedger = engine.evaluate(
      previousBuild,
      poolLimits: previousPoolLimits,
    );
    final nextLedger = engine.evaluate(nextBuild, poolLimits: nextPoolLimits);
    final previousKeys = {
      for (final grant in previousLedger.grants)
        ruleUnitKey(grant.sourceEntryId, grant.id, grant.sourceLevel),
    };
    final newGrants = nextLedger.grants
        .where(
          (grant) => !previousKeys.contains(
            ruleUnitKey(grant.sourceEntryId, grant.id, grant.sourceLevel),
          ),
        )
        .toList(growable: false);
    final previousChoiceKeys = {
      for (final choice in previousLedger.activeChoices) choice.key,
    };
    // 只有**本级新增**的选择才进入升级队列与 `pendingChoices`：上一级未完成的
    // 选择（技能在任务 7 之前的选中值不进 `build.choices`）不该堵塞升级；
    // 本级新增的选择必须由升级队列真的渲染出来（共享组件），否则就是
    // "看不见却阻塞"——`usesDedicatedOptionUi` 只决定渲染位置，不再免检。
    final upgradeChoices = nextLedger.activeChoices
        .where(
          (choice) =>
              !previousChoiceKeys.contains(choice.key) || !choice.isValid,
        )
        .toList(growable: false);
    return _CharacterUpgradePreview(
      build: nextBuild,
      newGrants: newGrants,
      ruleChoices: upgradeChoices,
      pendingChoices: nextLedger.pendingChoices
          .where((pending) => !previousChoiceKeys.contains(pending.key))
          .toList(growable: false),
      missingEntryIds: nextLedger.missingEntryIds,
    );
  }

  void _applyRecommendedUpgradeChoices() {
    final resolver = RuleChoiceResolver(
      entries: {for (final entry in widget.contentEntries) entry.id: entry},
    );
    var changed = true;
    while (changed) {
      changed = false;
      final preview = _upgradePreview();
      if (preview == null) return;
      for (final choice in preview.ruleChoices) {
        if ((_upgradeRuleChoices[choice.key] ?? const <String>[]).isNotEmpty) {
          continue;
        }
        final recommended = resolver.recommendedFor(
          choice.definition,
          sourceEntryId: choice.sourceEntryId,
        );
        if (recommended.isEmpty) continue;
        _upgradeRuleChoices[choice.key] = recommended.toList(growable: false);
        changed = true;
      }
    }
  }

  void _applyRulesUpgrade() {
    final preview = _upgradePreview();
    final character = widget.initialCharacter;
    if (preview == null || !preview.canApply || character == null) return;
    final abilities = {
      for (final entry in _abilityControllers.entries)
        entry.key: int.tryParse(entry.value.text.trim()) ?? 10,
    };
    final builder = RulesDrivenCharacterBuilder(
      entries: {for (final entry in widget.contentEntries) entry.id: entry},
    );
    // 再派生必须用**基础属性**：`_abilityControllers` 里是已含生效加值的最终值，
    // 直接回传会让同一份 `kind: ability` 授予再叠加一次（缺陷 4）。减加值的唯一
    // 实现在 builder；参照必须是**最近一次已应用**的 build（[`_appliedRulesData`]），
    // 因为应用后 controllers 已被写成**目标等级**的最终值。继续用存档里"升级前"
    // 的 `character.dataMap['build']` 会在第二次应用时减错区间的加值，每次多叠一份
    // `(旧等级, 目标等级]`；按钮在应用后禁用，这里仍是纵深防御（setState 之外
    // 的程序化调用）。
    final appliedData = _appliedRulesData ?? character.dataMap;
    final appliedBuildJson = appliedData['build'];
    final currentBuild = appliedBuildJson is Map
        ? CharacterBuild.fromJson(Map<String, Object?>.from(appliedBuildJson))
        : CharacterBuild(level: character.level);
    final generated = builder.build(
      name: _nameController.text,
      build: preview.build,
      abilities: builder.baseAbilitiesFrom(abilities, currentBuild),
      notes: _notesController.text,
    );
    setState(() {
      _maxHpController.text = '${generated.maxHp}';
      _acController.text = '${generated.armorClass}';
      _speedController.text = '${generated.speed}';
      _initiativeController.text = '${generated.initiativeBonus}';
      // 属性也写回"最终值"：否则下次再派生会用过期的属性当基础值（缺陷 4）。
      for (final entry in generated.abilities.entries) {
        _abilityControllers[entry.key]?.text = '${entry.value}';
      }
      _inventoryController.text = _inventoryToLines(
        _mergeInventory(
          _parseInventory(_inventoryController.text),
          generated.inventory,
        ),
      );
      _saves
        ..clear()
        ..addAll(generated.saves);
      _skills
        ..clear()
        ..addAll(generated.skills);
      _appliedRulesData = {
        ...character.dataMap,
        ...generated.data,
        if (character.runtimeMap.isNotEmpty)
          'runtime': Map<String, Object?>.from(character.runtimeMap),
      };
    });
  }

  Widget _buildCreationChoicePage(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('创建角色')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '选择创建方式',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '从 D&D 2024 的角色创建流程开始，之后仍可进入完整角色卡细调。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                _CreationChoiceCard(
                  icon: Icons.route_outlined,
                  title: '标准创建',
                  subtitle: '按来源、职业、起源、属性、装备和审核逐步完成。',
                  actionLabel: '标准创建',
                  onTap: () => setState(() => _flow = _CreationFlow.standard),
                ),
                const SizedBox(height: 12),
                _CreationChoiceCard(
                  icon: Icons.content_copy_outlined,
                  title: '导入或复制',
                  subtitle: '保留给 JSON 导入、复制已有角色和外部工具迁移。',
                  actionLabel: '稍后实现',
                  onTap: null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('角色名称不能为空')));
      return;
    }

    setState(() => _saving = true);
    try {
      final ok = await widget.onSubmit(_draft(name));
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).maybePop();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保存角色失败')));
      }
    } catch (e, stack) {
      // Spec §错误反馈: 表单提交过程中的任何异常都不能让 _saving 卡死,
      // 必须复位按钮状态并把真实错误打到 console 方便定位。
      debugPrint('character _submit failed: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存角色失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submitQuickBuild(QuickBuildSelection quickDraft) async {
    final name = quickDraft.name.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('角色名称不能为空')));
      return;
    }

    setState(() => _saving = true);
    try {
      final entries = {
        for (final entry in widget.contentEntries) entry.id: entry,
      };
      final selectedEntryIds = [
        quickDraft.classEntryId,
        quickDraft.speciesEntryId,
        quickDraft.backgroundEntryId,
      ].whereType<String>().toList(growable: false);
      final hasStructuredRules = selectedEntryIds.any(
        (entryId) => entries[entryId]?.rules != null,
      );
      // 同一份基础属性既进 `CharacterBuild.abilities`（`requires` 的门槛数据源，
      // 决策 D4），也作为派生的入参——两处必须是同一份，否则门槛与结算不同口径。
      final quickAbilities = quickDraft.abilities ?? Dnd5eRules.defaultAbilities;
      final baseDraft = hasStructuredRules
          ? RulesDrivenCharacterBuilder(entries: entries).build(
              name: name,
              build: CharacterBuild(
                level: quickDraft.level,
                selections: {
                  if (quickDraft.classEntryId != null)
                    'class': quickDraft.classEntryId!,
                  if (quickDraft.speciesEntryId != null)
                    'species': quickDraft.speciesEntryId!,
                  if (quickDraft.backgroundEntryId != null)
                    'background': quickDraft.backgroundEntryId!,
                },
                choices: quickDraft.ruleChoices,
                abilities: quickAbilities,
              ),
              abilities: quickAbilities,
              avatarUrl: quickDraft.avatarUrl ?? _effectiveAvatarUrl,
              extraSpellRefs: quickDraft.spellRefs,
              extraItemRefs: quickDraft.itemRefs,
              skillProficiencies:
                  quickDraft.skillProficiencies ?? const <String>[],
            )
          : QuickBuildService.build(
              QuickBuildSelection(
                name: quickDraft.name,
                className: quickDraft.className,
                species: quickDraft.species,
                background: quickDraft.background,
                level: quickDraft.level,
                spellRefs: quickDraft.spellRefs,
                itemRefs: quickDraft.itemRefs,
                abilities: quickDraft.abilities,
                skillProficiencies: quickDraft.skillProficiencies,
                classEntry: entries[quickDraft.classEntryId],
                classEntryId: quickDraft.classEntryId,
                speciesEntryId: quickDraft.speciesEntryId,
                backgroundEntryId: quickDraft.backgroundEntryId,
                ruleChoices: quickDraft.ruleChoices,
                avatarUrl: quickDraft.avatarUrl ?? _effectiveAvatarUrl,
                appearance: quickDraft.appearance,
                personalityTraits: quickDraft.personalityTraits,
                ideals: quickDraft.ideals,
                bonds: quickDraft.bonds,
                flaws: quickDraft.flaws,
                backstory: quickDraft.backstory,
                privateNotes: quickDraft.privateNotes,
                customSpells: quickDraft.customSpells,
              ),
            );
      final draft = baseDraft.copyWith(
        data: {
          ...baseDraft.data,
          'story': quickDraft.storyData,
          if (quickDraft.customSpells.isNotEmpty)
            'manualOverrides': quickDraft.manualOverridesData,
        },
      );
      final ok = await widget.onSubmit(draft);
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).maybePop();
      }
      // On failure, the caller (onSubmit) is responsible for showing the
      // specific error SnackBar — the editor does not have access to the
      // controller's error message.
    } catch (e, stack) {
      // Spec §错误反馈: RulesDrivenCharacterBuilder.build() 或 onSubmit
      // 抛出的任何异常都必须复位 _saving 并给用户可见反馈, 否则按钮会
      // 一直灰着且无任何提示 (用户报告"一直不能创建角色"的直接原因)。
      debugPrint('character _submitQuickBuild failed: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('创建角色失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  CharacterEditDraft _draft(String name) {
    final abilities = {
      for (final entry in _abilityControllers.entries)
        entry.key:
            int.tryParse(entry.value.text.trim()) ??
            Dnd5eRules.defaultAbilities[entry.key]!,
    };
    final baseData =
        _appliedRulesData ?? widget.initialCharacter?.dataMap ?? const {};
    final characterSections =
        <String, Object?>{
          ...widget.initialCharacter?.markdownSections ??
              const <String, Object?>{},
          for (final entry in _characterSectionControllers.entries)
            if (entry.value.text.trim().isNotEmpty)
              entry.key: entry.value.text.trim(),
        }..removeWhere((key, value) {
          return _characterSectionControllers.containsKey(key) &&
              '$value'.trim().isEmpty;
        });
    return CharacterEditDraft(
      name: name,
      level: _intValue(_levelController, 1),
      classSummary: _classController.text.trim(),
      raceSummary: _raceController.text.trim(),
      currentHp: _intValue(_hpController, 0),
      maxHp: _intValue(_maxHpController, 0),
      armorClass: _intValue(
        _acController,
        Dnd5eRules.baseArmorClass(abilities),
      ),
      speed: _intValue(_speedController, 30),
      initiativeBonus: _intValue(
        _initiativeController,
        Dnd5eRules.initiativeBonus(abilities),
      ),
      abilities: abilities,
      saves: Map.unmodifiable(_saves),
      skills: Map.unmodifiable(_skills),
      inventory: _parseInventory(_inventoryController.text),
      currency: {
        for (final entry in _currencyControllers.entries)
          entry.key: int.tryParse(entry.value.text.trim()) ?? 0,
      },
      notes: _notesController.text.trim(),
      avatarUrl: _effectiveAvatarUrl,
      data: {
        ...baseData,
        'description': _descriptionController.text.trim(),
        if (_editingCharacter)
          'character': {
            ...widget.initialCharacter!.characterMap,
            'kind': _characterKind,
            for (final entry in _characterControllers.entries)
              if (entry.value.text.trim().isNotEmpty)
                entry.key: entry.value.text.trim(),
          },
        if (_editingCharacter) 'markdownSections': characterSections,
      },
    );
  }
}
