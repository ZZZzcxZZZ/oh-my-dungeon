import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../domain/ability_score_generator.dart';
import '../domain/character.dart';
import '../domain/character_edit_draft.dart';
import '../domain/dnd5e_rules.dart';
import '../domain/quick_build.dart';
import '../domain/rules_driven_character_builder.dart';
import '../domain/structured_class_rules.dart';
import '../../content/domain/content_entry.dart';
import '../../content/presentation/content_entry_preview_page.dart';
import '../../campaigns/presentation/widgets/avatar_picker.dart';
import '../../rules/domain/character_build.dart';
import '../../rules/domain/character_rule_definition.dart';
import '../../rules/domain/character_rules_engine.dart';
import '../../rules/domain/rule_choice_resolver.dart';
import 'widgets/character_builder_shell.dart';

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
  late final Map<String, TextEditingController> _abilityControllers;
  late final Map<String, TextEditingController> _currencyControllers;
  late final Map<String, bool> _saves;
  late final Map<String, bool> _skills;
  late _CreationFlow _flow;
  Map<String, Object?>? _appliedRulesData;
  final Map<String, Set<String>> _upgradeRuleChoices = {};
  bool _saving = false;

  // 头像选择状态（规范 §头像来源：本地角色头像离线保存在客户端）。
  Uint8List? _avatarBytes;
  String? _avatarMimeType;
  bool _pickingAvatar = false;
  String? _avatarPickError;

  String? get _currentAvatarUrl => widget.initialCharacter?.avatarUrl;

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
    if (!isEditing && _flow == _CreationFlow.quick) {
      return _QuickBuildPage(onSubmit: _submitQuickBuild);
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
                    decoration: const InputDecoration(
                      labelText: '名称',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('character-class-field'),
                          controller: _classController,
                          decoration: const InputDecoration(
                            labelText: '职业',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          key: const Key('character-race-field'),
                          controller: _raceController,
                          decoration: const InputDecoration(
                            labelText: '种族',
                            border: OutlineInputBorder(),
                          ),
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
                        decoration: InputDecoration(
                          labelText: entry.value,
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                ],
              ),
            ),
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
                      border: OutlineInputBorder(),
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
                            decoration: InputDecoration(
                              labelText: key,
                              border: const OutlineInputBorder(),
                            ),
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
                decoration: const InputDecoration(
                  labelText: '背景、个性、临时说明',
                  border: OutlineInputBorder(),
                ),
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
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      onChanged: onChanged,
    );
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
          entry.key: entry.value.toList(growable: false),
      },
    );
    final engine = CharacterRulesEngine(
      entries: {for (final entry in widget.contentEntries) entry.id: entry},
    );
    final previousLedger = engine.evaluate(previousBuild);
    final nextLedger = engine.evaluate(nextBuild);
    final previousKeys = {
      for (final grant in previousLedger.grants)
        '${grant.sourceEntryId}#${grant.id}',
    };
    final newGrants = nextLedger.grants
        .where(
          (grant) =>
              !previousKeys.contains('${grant.sourceEntryId}#${grant.id}'),
        )
        .toList(growable: false);
    final previousChoiceKeys = {
      for (final choice in previousLedger.activeChoices) choice.key,
    };
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
      pendingChoices: nextLedger.pendingChoices,
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
        if ((_upgradeRuleChoices[choice.key] ?? const <String>{}).isNotEmpty) {
          continue;
        }
        final recommended = resolver.recommendedFor(
          choice.definition,
          sourceEntryId: choice.sourceEntryId,
        );
        if (recommended.isEmpty) continue;
        _upgradeRuleChoices[choice.key] = recommended.toSet();
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
    final generated =
        RulesDrivenCharacterBuilder(
          entries: {for (final entry in widget.contentEntries) entry.id: entry},
        ).build(
          name: _nameController.text,
          build: preview.build,
          abilities: abilities,
          notes: _notesController.text,
        );
    setState(() {
      _maxHpController.text = '${generated.maxHp}';
      _acController.text = '${generated.armorClass}';
      _speedController.text = '${generated.speed}';
      _initiativeController.text = '${generated.initiativeBonus}';
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
                  icon: Icons.flash_on_outlined,
                  title: '快速创建',
                  subtitle: '用推荐默认值快速生成 1 级可玩角色。',
                  actionLabel: '快速创建',
                  onTap: () => setState(() => _flow = _CreationFlow.quick),
                ),
                const SizedBox(height: 12),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存角色失败：$e')),
        );
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
      final draft = hasStructuredRules
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
              ),
              abilities: quickDraft.abilities ?? Dnd5eRules.defaultAbilities,
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
                classEntryId: quickDraft.classEntryId,
                speciesEntryId: quickDraft.speciesEntryId,
                backgroundEntryId: quickDraft.backgroundEntryId,
                ruleChoices: quickDraft.ruleChoices,
                avatarUrl: quickDraft.avatarUrl ?? _effectiveAvatarUrl,
              ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建角色失败：$e')),
        );
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
      data: _appliedRulesData ?? widget.initialCharacter?.dataMap ?? const {},
    );
  }
}

class _CharacterUpgradePreview {
  const _CharacterUpgradePreview({
    required this.build,
    required this.newGrants,
    required this.ruleChoices,
    required this.pendingChoices,
    required this.missingEntryIds,
  });

  final CharacterBuild build;
  final List<ResolvedRuleGrant> newGrants;
  final List<ActiveRuleChoice> ruleChoices;
  final List<PendingRuleChoice> pendingChoices;
  final List<String> missingEntryIds;

  bool get canApply => pendingChoices.isEmpty && missingEntryIds.isEmpty;
}

class _CharacterUpgradeSection extends StatelessWidget {
  const _CharacterUpgradeSection({
    required this.preview,
    required this.applied,
    required this.onApply,
    required this.entries,
    required this.onChoiceChanged,
  });

  final _CharacterUpgradePreview preview;
  final bool applied;
  final VoidCallback? onApply;
  final List<ContentEntry> entries;
  final void Function(String key, Set<String> selected) onChoiceChanged;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: '升级队列',
      child: Card.filled(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.trending_up_outlined),
                title: Text('升级到 ${preview.build.level} 级'),
                subtitle: Text(
                  applied ? '等级规则已应用，保存角色后生效。' : '检查本级自动授予与必须完成的选择。',
                ),
              ),
              for (final grant in preview.newGrants)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.add_circle_outline),
                  title: Text('新增：${grant.label}'),
                  subtitle: Text(
                    grant.sourceLevel == null
                        ? grant.sourceEntryName
                        : '${grant.sourceEntryName} · 等级 ${grant.sourceLevel}',
                  ),
                ),
              for (final choice in preview.ruleChoices)
                _UpgradeRuleChoiceSection(
                  choice: choice,
                  entries: entries,
                  onChanged: (selected) =>
                      onChoiceChanged(choice.key, selected),
                ),
              for (final entryId in preview.missingEntryIds)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.link_off_outlined,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text('缺少资料：$entryId'),
                ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: applied ? null : onApply,
                icon: Icon(
                  applied ? Icons.check_circle_outline : Icons.auto_fix_high,
                ),
                label: Text(applied ? '等级规则已应用' : '应用等级规则'),
              ),
              if (!preview.canApply)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '请完成本级新增选择，或恢复缺失的资料条目。',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpgradeRuleChoiceSection extends StatelessWidget {
  const _UpgradeRuleChoiceSection({
    required this.choice,
    required this.entries,
    required this.onChanged,
  });

  final ActiveRuleChoice choice;
  final List<ContentEntry> entries;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final definition = choice.definition;
    final options = RuleChoiceResolver(
      entries: {for (final entry in entries) entry.id: entry},
    ).optionsFor(definition, sourceEntryId: choice.sourceEntryId);
    return Card.outlined(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    definition.label,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Icon(
                  choice.isValid
                      ? Icons.check_circle_outline
                      : Icons.pending_actions_outlined,
                  color: choice.isValid
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${choice.sourceEntryName} · 选择 ${definition.minimum}-${definition.maximum} 项',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            if (options.isEmpty)
              Text(
                '没有符合当前等级与资格的选项。',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in options)
                    FilterChip(
                      label: Text(option.name),
                      selected: choice.selected.contains(option.id),
                      onSelected: (selected) {
                        final next = choice.selected.toSet();
                        if (selected) {
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
                ],
              ),
          ],
        ),
      ),
    );
  }
}

enum _CreationFlow { choose, quick, standard, fullSheet }

const _defaultClassOptions = ['战士', '法师', '游荡者', '牧师'];
const _defaultSpeciesOptions = ['人类', '精灵', '矮人', '半身人'];
const _defaultBackgroundOptions = ['士兵', '贤者', '罪犯', '侍祭'];

_CreationFlow _flowFromPreference(String value) {
  return switch (value) {
    'quick' => _CreationFlow.quick,
    'standard' => _CreationFlow.standard,
    'fullSheet' => _CreationFlow.fullSheet,
    _ => _CreationFlow.choose,
  };
}

class _CreationChoiceCard extends StatelessWidget {
  const _CreationChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(subtitle),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.tonal(onPressed: onTap, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class _QuickBuildPage extends StatefulWidget {
  const _QuickBuildPage({required this.onSubmit});

  final Future<void> Function(QuickBuildSelection draft) onSubmit;

  @override
  State<_QuickBuildPage> createState() => _QuickBuildPageState();
}

class _QuickBuildPageState extends State<_QuickBuildPage> {
  final _nameController = TextEditingController();
  String _className = '战士';
  String _species = '人类';
  String _background = '士兵';
  int _level = 1;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('快速创建角色')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SourceBanner(),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('quick-character-name-field'),
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '角色名',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                _ChoiceSection(
                  title: '职业',
                  selected: _className,
                  options: const ['战士', '法师', '游荡者', '牧师'],
                  onSelected: (value) => setState(() => _className = value),
                ),
                _ChoiceSection(
                  title: '物种',
                  selected: _species,
                  options: const ['人类', '精灵', '矮人', '半身人'],
                  onSelected: (value) => setState(() => _species = value),
                ),
                _ChoiceSection(
                  title: '背景',
                  selected: _background,
                  options: const ['士兵', '贤者', '罪犯', '侍祭'],
                  onSelected: (value) => setState(() => _background = value),
                ),
                Text('等级', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 1, label: Text('1')),
                    ButtonSegment(value: 3, label: Text('3')),
                    ButtonSegment(value: 5, label: Text('5')),
                  ],
                  selected: {_level},
                  onSelectionChanged: (selection) {
                    setState(() => _level = selection.single);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: () => widget.onSubmit(
              QuickBuildSelection(
                name: _nameController.text,
                className: _className,
                species: _species,
                background: _background,
                level: _level,
              ),
            ),
            icon: const Icon(Icons.check),
            label: const Text('创建角色'),
          ),
        ),
      ),
    );
  }
}

class _StandardBuildPage extends StatefulWidget {
  const _StandardBuildPage({
    required this.contentEntries,
    required this.onSubmit,
    required this.onContinueToFullSheet,
    this.onPickImage,
  });

  final List<ContentEntry> contentEntries;
  final Future<void> Function(QuickBuildSelection draft) onSubmit;
  final VoidCallback onContinueToFullSheet;
  final Future<({Uint8List bytes, String mimeType})?> Function()? onPickImage;

  @override
  State<_StandardBuildPage> createState() => _StandardBuildPageState();
}

class _StandardBuildPageState extends State<_StandardBuildPage> {
  static const _steps = ['职业', '背景', '物种', '属性', '熟练', '装备', '法术', '详情', '审核'];
  static const _stepIcons = [
    Icons.shield_outlined,
    Icons.history_edu_outlined,
    Icons.diversity_3_outlined,
    Icons.tune_outlined,
    Icons.workspace_premium_outlined,
    Icons.backpack_outlined,
    Icons.auto_fix_high_outlined,
    Icons.badge_outlined,
    Icons.fact_check_outlined,
  ];

  final _nameController = TextEditingController();
  int _currentStep = 0;
  late String _className;
  late String _species;
  late String _background;
  String? _classEntryId;
  String? _speciesEntryId;
  String? _backgroundEntryId;
  int _level = 1;
  final Set<String> _selectedSpellRefs = {};
  final Set<String> _selectedItemRefs = {};
  final Map<String, Set<String>> _ruleChoices = {};
  late Set<String> _selectedSkillProficiencies;
  late Map<String, int> _abilityScores;
  late Map<String, TextEditingController> _abilityControllers;
  AbilityScoreMethod _abilityMethod = AbilityScoreMethod.standardArray;

  // 头像选择状态（规范 §头像来源：本地角色头像离线保存在客户端）。
  Uint8List? _avatarBytes;
  String? _avatarMimeType;
  bool _pickingAvatar = false;
  String? _avatarPickError;

  String? get _avatarDataUrl {
    if (_avatarBytes != null && _avatarMimeType != null) {
      return 'data:$_avatarMimeType;base64,${base64Encode(_avatarBytes!)}';
    }
    return null;
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
    _className = _contentChoiceLabels('class', _defaultClassOptions).first;
    _species = _contentChoiceLabels('species', _defaultSpeciesOptions).first;
    _background = _contentChoiceLabels(
      'background',
      _defaultBackgroundOptions,
    ).first;
    _classEntryId = _entryIdFor('class', _className);
    _speciesEntryId = _entryIdFor('species', _species);
    _backgroundEntryId = _entryIdFor('background', _background);
    _selectedSkillProficiencies = _presetSkillsForBackground(_background);
    _abilityScores = _presetAbilitiesForClass(_className);
    _abilityControllers = {
      for (final entry in Dnd5eRules.abilityLabels.entries)
        entry.key: TextEditingController(text: '${_abilityScores[entry.key]}'),
    };
    _applyRecommendedRuleChoices();
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final controller in _abilityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summaryName = _nameController.text.trim().isEmpty
        ? '未命名角色'
        : _nameController.text.trim();
    final summary =
        '$summaryName / $_species / $_background / $_className / Lv.$_level';
    final review = _StandardBuildReview.from(
      name: _nameController.text,
      className: _className,
      species: _species,
      background: _background,
      abilityScores: _abilityScores,
    );
    final classOptions = _contentChoiceLabels('class', _defaultClassOptions);
    final speciesOptions = _contentChoiceLabels(
      'species',
      _defaultSpeciesOptions,
    );
    final backgroundOptions = _contentChoiceLabels(
      'background',
      _defaultBackgroundOptions,
    );
    final spellOptions = _contentChoiceLabels('spell', const []);
    final itemOptions = _contentChoiceLabelsForTypes(const [
      'equipment',
      'item',
    ], const []);
    final activeRuleChoices = _activeRuleChoices();
    final startingEquipment = _entryById(
      _classEntryId,
    )?.structured['startingEquipment'];
    final hasStructuredStartingEquipment =
        startingEquipment != null && '$startingEquipment'.trim().isNotEmpty;
    final visibleStepIndexes = <int>[
      0,
      1,
      2,
      3,
      4,
      if (itemOptions.isNotEmpty ||
          hasStructuredStartingEquipment ||
          activeRuleChoices.any((choice) => choice.builderStep == 5))
        5,
      if (spellOptions.isNotEmpty ||
          activeRuleChoices.any((choice) => choice.builderStep == 6))
        6,
      7,
      8,
    ];
    final visibleStep = visibleStepIndexes.indexOf(_currentStep);
    final ruleChoicesAreValid = activeRuleChoices.every((active) {
      final selected = _ruleChoices[active.key] ?? const <String>{};
      return selected.length >= active.definition.minimum &&
          selected.length <= active.definition.maximum;
    });
    final stepContent = _buildStepContent(
      context: context,
      classOptions: classOptions,
      speciesOptions: speciesOptions,
      backgroundOptions: backgroundOptions,
      spellOptions: spellOptions,
      itemOptions: itemOptions,
      activeRuleChoices: activeRuleChoices,
      review: review,
      summary: summary,
    );

    return CharacterBuilderShell(
      title: '标准创建角色',
      destinations: [
        for (final index in visibleStepIndexes)
          CharacterBuilderDestination(
            id: index,
            label: _steps[index],
            icon: _stepIcons[index],
          ),
      ],
      selectedIndex: visibleStep,
      onSelected: (index) => _selectStep(visibleStepIndexes[index]),
      editor: _BuilderStepEditor(
        step: _currentStep,
        stepLabel: _steps[_currentStep],
        stepDescription: _stepDescription(_steps[_currentStep]),
        nameController: _nameController,
        onNameChanged: (_) => setState(() {}),
        child: stepContent,
      ),
      summary: _BuilderSummaryPanel(
        summary: summary,
        review: review,
        level: _level,
        className: _className,
        abilities: _abilityScores,
        selectedSpells: _selectedSpellRefs.length,
        selectedItems: _selectedItemRefs.length,
        pendingChoices: activeRuleChoices.where((active) {
          final selected = _ruleChoices[active.key] ?? const <String>{};
          return selected.length < active.definition.minimum ||
              selected.length > active.definition.maximum;
        }).length,
      ),
      bottomBar: SafeArea(
        child: _BuilderFooter(
          currentStep: visibleStep,
          lastStep: visibleStepIndexes.length - 1,
          canCreate: review.isReady && ruleChoicesAreValid,
          onPrevious: visibleStep == 0
              ? null
              : () => _selectStep(visibleStepIndexes[visibleStep - 1]),
          onNext: visibleStep == visibleStepIndexes.length - 1
              ? null
              : () => _selectStep(visibleStepIndexes[visibleStep + 1]),
          onContinueToFullSheet: widget.onContinueToFullSheet,
          onCreate: () => widget.onSubmit(_selection()),
        ),
      ),
    );
  }

  void _selectStep(int step) {
    setState(() => _currentStep = step.clamp(0, _steps.length - 1));
  }

  QuickBuildSelection _selection() {
    return QuickBuildSelection(
      name: _nameController.text,
      className: _className,
      species: _species,
      background: _background,
      level: _level,
      spellRefs: _selectedSpellRefs.toList(),
      itemRefs: _selectedItemRefs.toList(),
      abilities: Map.unmodifiable(_abilityScores),
      skillProficiencies: _selectedSkillProficiencies.toList(),
      classEntryId: _classEntryId,
      speciesEntryId: _speciesEntryId,
      backgroundEntryId: _backgroundEntryId,
      ruleChoices: {
        for (final entry in _ruleChoices.entries)
          entry.key: entry.value.toList(growable: false),
      },
      avatarUrl: _avatarDataUrl,
    );
  }

  Widget _buildStepContent({
    required BuildContext context,
    required List<String> classOptions,
    required List<String> speciesOptions,
    required List<String> backgroundOptions,
    required List<String> spellOptions,
    required List<String> itemOptions,
    required List<_ActiveRuleChoice> activeRuleChoices,
    required _StandardBuildReview review,
    required String summary,
  }) {
    final choicesForCurrentStep = activeRuleChoices.where((choice) {
      return choice.builderStep == _currentStep;
    });
    final ruleChoiceWidgets = [
      for (final active in choicesForCurrentStep)
        _RuleChoiceSection(
          choice: active,
          options: _choiceOptions(
            active.definition,
            sourceEntryId: active.sourceEntryId,
          ),
          allEntries: widget.contentEntries,
          selected: _ruleChoices[active.key] ?? const <String>{},
          onChanged: (next) => setState(() {
            _ruleChoices[active.key] = next;
            _applyRecommendedRuleChoices();
          }),
        ),
    ];
    final classSkillChoice = StructuredClassRules.skillChoice(
      _entryById(_classEntryId),
    );
    final fixedBackgroundSkills = classSkillChoice.count > 0
        ? _presetSkillsForBackground(_background)
        : const <String>{};
    return switch (_currentStep) {
      0 => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ChoiceSection(
            title: '选择职业',
            selected: _className,
            options: classOptions,
            sourceLabel: _hasContentChoices('class') ? '来自资料库' : null,
            onOpenOption: (name) => _openEntryByTypeAndName('class', name),
            onSelected: (value) => setState(() {
              _className = value;
              _classEntryId = _entryIdFor('class', value);
              _resetAbilityScoresForClass(value);
              _applyRecommendedRuleChoices();
            }),
          ),
          _StructuredRuleSummary(
            title: '职业规则摘要',
            entry: _entryById(_classEntryId),
            fields: const ['primaryAbility', 'hitDie'],
          ),
          _LevelProgressionSection(
            level: _level,
            className: _className,
            abilities: _abilityScores,
            onChanged: (value) => setState(() {
              _level = value;
              _applyRecommendedRuleChoices();
            }),
          ),
          ...ruleChoiceWidgets,
          _RuleGrantPreview(
            entries: _ruleEntriesForStep(0, activeRuleChoices),
            level: _level,
          ),
        ],
      ),
      1 => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ChoiceSection(
            title: '选择背景',
            selected: _background,
            options: backgroundOptions,
            sourceLabel: _hasContentChoices('background') ? '来自资料库' : null,
            onOpenOption: (name) => _openEntryByTypeAndName('background', name),
            onSelected: (value) => setState(() {
              _background = value;
              _backgroundEntryId = _entryIdFor('background', value);
              _selectedSkillProficiencies = _presetSkillsForBackground(value);
              _applyRecommendedRuleChoices();
            }),
          ),
          ...ruleChoiceWidgets,
          _RuleGrantPreview(
            entries: _ruleEntriesForStep(1, activeRuleChoices),
            level: _level,
          ),
        ],
      ),
      2 => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ChoiceSection(
            title: '选择物种',
            selected: _species,
            options: speciesOptions,
            sourceLabel: _hasContentChoices('species') ? '来自资料库' : null,
            onOpenOption: (name) => _openEntryByTypeAndName('species', name),
            onSelected: (value) => setState(() {
              _species = value;
              _speciesEntryId = _entryIdFor('species', value);
              _applyRecommendedRuleChoices();
            }),
          ),
          ...ruleChoiceWidgets,
          _RuleGrantPreview(
            entries: _ruleEntriesForStep(2, activeRuleChoices),
            level: _level,
          ),
        ],
      ),
      3 => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('设置属性', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          _AbilityScoreSection(
            method: _abilityMethod,
            scores: _abilityScores,
            controllers: _abilityControllers,
            onMethodChanged: _changeAbilityMethod,
            onApplyRecommended: () => setState(
              () => _setAbilityScores(_presetAbilitiesForClass(_className)),
            ),
            onRoll: _rollAbilityScores,
            onChanged: (ability, value) =>
                setState(() => _abilityScores[ability] = value),
          ),
        ],
      ),
      4 => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StructuredRuleSummary(
            title: '职业熟练摘要',
            entry: _entryById(_classEntryId),
            fields: const [
              'savingThrows',
              'skills',
              'weaponProficiency',
              'armorProficiency',
            ],
          ),
          ...ruleChoiceWidgets,
          _SkillProficiencySection(
            selected: _selectedSkillProficiencies,
            options: classSkillChoice.options,
            maximum: classSkillChoice.count > 0 ? classSkillChoice.count : null,
            fixed: fixedBackgroundSkills,
            onChanged: (next) =>
                setState(() => _selectedSkillProficiencies = next),
          ),
          _RuleGrantPreview(
            entries: _ruleEntriesForStep(4, activeRuleChoices),
            level: _level,
          ),
        ],
      ),
      5 => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StructuredRuleSummary(
            title: '职业初始装备',
            entry: _entryById(_classEntryId),
            fields: const ['startingEquipment'],
          ),
          ...ruleChoiceWidgets,
          if (ruleChoiceWidgets.isEmpty)
            _MultiChoiceSection(
              title: '选择装备',
              selected: _selectedItemRefs,
              options: itemOptions,
              sourceLabel:
                  _hasContentChoicesForTypes(const ['equipment', 'item'])
                  ? '来自资料库'
                  : null,
              emptyLabel: '资料库中暂无装备；规则方案仍会自动应用。',
              onOpenOption: (name) =>
                  _openEntryByTypesAndName(const ['equipment', 'item'], name),
              onChanged: (next) =>
                  setState(() => _replaceSet(_selectedItemRefs, next)),
              maximum: StructuredClassRules.startingEquipmentChoice(
                _entryById(_classEntryId),
              )?.maximum,
            ),
        ],
      ),
      6 => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...ruleChoiceWidgets,
          if (ruleChoiceWidgets.isEmpty)
            _MultiChoiceSection(
              title: '选择法术',
              selected: _selectedSpellRefs,
              options: spellOptions,
              sourceLabel: _hasContentChoices('spell') ? '来自资料库' : null,
              emptyLabel: '资料库中暂无法术；可先跳过。',
              onOpenOption: (name) => _openEntryByTypeAndName('spell', name),
              onChanged: (next) =>
                  setState(() => _replaceSet(_selectedSpellRefs, next)),
              maximum: StructuredClassRules.preparedSpellLimit(
                _entryById(_classEntryId),
                abilities: _abilityScores,
                level: _level,
              ),
            ),
        ],
      ),
      7 => _DetailsStep(
        name: _nameController.text,
        avatarBytes: _avatarBytes,
        isPickingAvatar: _pickingAvatar,
        avatarPickError: _avatarPickError,
        onPickAvatar: _pickAvatarImage,
      ),
      8 => _BuilderReviewStep(
        summary: summary,
        review: review,
        abilityMethodLabel: _abilityMethodLabel(_abilityMethod),
        pendingRuleChoices: activeRuleChoices
            .where((active) {
              final selected = _ruleChoices[active.key] ?? const <String>{};
              return selected.length < active.definition.minimum ||
                  selected.length > active.definition.maximum;
            })
            .toList(growable: false),
      ),
      _ => const SizedBox.shrink(),
    };
  }

  static String _stepDescription(String step) {
    return switch (step) {
      '职业' => '选择职业、等级和职业资源。',
      '背景' => '选择背景、技能与起源专长。',
      '物种' => '选择物种与物种特性。',
      '属性' => '标准数组、购点、掷骰或自定义。',
      '熟练' => '技能、工具、武器、防具与豁免。',
      '装备' => '职业装备、金币购买或自定义装备。',
      '法术' => '戏法、准备法术、法术位和专注。',
      '详情' => '名字、头像、阵营、外貌与背景。',
      '审核' => '检查缺失项、来源和手动覆盖。',
      _ => '',
    };
  }

  static String _abilityMethodLabel(AbilityScoreMethod method) {
    return switch (method) {
      AbilityScoreMethod.standardArray => '标准数组',
      AbilityScoreMethod.pointBuy => '27 点购点',
      AbilityScoreMethod.rolled => '随机',
    };
  }

  List<String> _contentChoiceLabels(String type, List<String> fallback) {
    return _contentChoiceLabelsForTypes([type], fallback);
  }

  List<String> _contentChoiceLabelsForTypes(
    List<String> types,
    List<String> fallback,
  ) {
    final labels = <String>{
      ...widget.contentEntries
          .where((entry) => types.contains(entry.type))
          .map((entry) => entry.name.trim())
          .where((name) => name.isNotEmpty),
    }.toList()..sort();
    return labels.isEmpty ? fallback : labels;
  }

  bool _hasContentChoices(String type) {
    return _hasContentChoicesForTypes([type]);
  }

  bool _hasContentChoicesForTypes(List<String> types) {
    return widget.contentEntries.any(
      (entry) => types.contains(entry.type) && entry.name.trim().isNotEmpty,
    );
  }

  ContentEntry? _entryById(String? entryId) {
    if (entryId == null) return null;
    return widget.contentEntries
        .where((entry) => entry.id == entryId)
        .firstOrNull;
  }

  String? _entryIdFor(String type, String name) {
    for (final entry in widget.contentEntries) {
      if (entry.type == type && entry.name.trim() == name.trim()) {
        return entry.id;
      }
    }
    return null;
  }

  List<_ActiveRuleChoice> _activeRuleChoices() {
    final queue = <({String entryId, int builderStep})>[
      if (_classEntryId != null) (entryId: _classEntryId!, builderStep: 0),
      if (_speciesEntryId != null) (entryId: _speciesEntryId!, builderStep: 2),
      if (_backgroundEntryId != null)
        (entryId: _backgroundEntryId!, builderStep: 1),
    ];
    final visited = <String>{};
    final result = <_ActiveRuleChoice>[];
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      if (!visited.add(current.entryId)) continue;
      final entryId = current.entryId;
      final entry = widget.contentEntries
          .where((candidate) => candidate.id == entryId)
          .firstOrNull;
      final rules = entry?.rules;
      if (entry == null || rules == null) continue;
      for (final definition in rules.choices) {
        final builderStep = _builderStepFor(
          definition.builderStep,
          current.builderStep,
        );
        result.add(
          _ActiveRuleChoice(
            key: '${entry.id}#${definition.id}',
            sourceEntryId: entry.id,
            sourceName: entry.name,
            builderStep: builderStep,
            definition: definition,
          ),
        );
      }
      for (final progression in rules.progression) {
        if (progression.level > _level) continue;
        for (final definition in progression.choices) {
          final builderStep = _builderStepFor(
            definition.builderStep,
            current.builderStep,
          );
          result.add(
            _ActiveRuleChoice(
              key: '${entry.id}#${definition.id}',
              sourceEntryId: entry.id,
              sourceName: entry.name,
              builderStep: builderStep,
              level: progression.level,
              definition: definition,
            ),
          );
        }
      }
      for (final active in result.where(
        (choice) => choice.sourceEntryId == entry.id,
      )) {
        final selected = _ruleChoices[active.key] ?? const <String>{};
        queue.addAll(
          selected.map(
            (selectedId) =>
                (entryId: selectedId, builderStep: active.builderStep),
          ),
        );
      }
    }
    return result;
  }

  void _openEntryByTypeAndName(String type, String name) {
    _openEntryByTypesAndName([type], name);
  }

  List<ContentEntry> _ruleEntriesForStep(
    int step,
    List<_ActiveRuleChoice> activeChoices,
  ) {
    final ids = <String>{
      if (step == 0 && _classEntryId != null) _classEntryId!,
      if (step == 2 && _speciesEntryId != null) _speciesEntryId!,
      if (step == 1 && _backgroundEntryId != null) _backgroundEntryId!,
      for (final choice in activeChoices.where(
        (candidate) => candidate.builderStep == step,
      ))
        ...?_ruleChoices[choice.key],
    };
    return widget.contentEntries
        .where((entry) => ids.contains(entry.id))
        .toList(growable: false);
  }

  void _openEntryByTypesAndName(List<String> types, String name) {
    final entry = widget.contentEntries
        .where(
          (candidate) =>
              types.contains(candidate.type) &&
              candidate.name.trim() == name.trim(),
        )
        .firstOrNull;
    if (entry == null) return;
    showContentEntryPreviewDialog(
      context,
      entry: entry,
      entries: widget.contentEntries,
    );
  }

  List<ContentEntry> _choiceOptions(
    RuleChoiceDefinition definition, {
    required String sourceEntryId,
  }) {
    return RuleChoiceResolver(
      entries: {for (final entry in widget.contentEntries) entry.id: entry},
    ).optionsFor(definition, sourceEntryId: sourceEntryId);
  }

  int _builderStepFor(String? declaredStep, int inheritedStep) {
    return switch (declaredStep) {
      'class' => 0,
      'origin' => inheritedStep,
      'abilities' => 3,
      'proficiencies' => 4,
      'equipment' => 5,
      'spells' => 6,
      'details' => 7,
      _ => inheritedStep,
    };
  }

  void _applyRecommendedRuleChoices() {
    final resolver = RuleChoiceResolver(
      entries: {for (final entry in widget.contentEntries) entry.id: entry},
    );
    var changed = true;
    while (changed) {
      changed = false;
      for (final active in _activeRuleChoices()) {
        if ((_ruleChoices[active.key] ?? const <String>{}).isNotEmpty) continue;
        final recommended = resolver.recommendedFor(
          active.definition,
          sourceEntryId: active.sourceEntryId,
        );
        if (recommended.isEmpty) continue;
        _ruleChoices[active.key] = recommended.toSet();
        changed = true;
      }
    }
  }

  void _replaceSet(Set<String> target, Set<String> next) {
    target
      ..clear()
      ..addAll(next);
  }

  void _changeAbilityMethod(AbilityScoreMethod method) {
    setState(() {
      _abilityMethod = method;
      if (method == AbilityScoreMethod.rolled) {
        _setAbilityScores(
          AbilityScoreGenerator.assignByPriority(
            scores: _abilityScores.values.toList(growable: false),
            priorities: _abilityPrioritiesForClass(_className),
          ),
        );
      } else {
        _setAbilityScores(_presetAbilitiesForClass(_className));
      }
    });
  }

  void _rollAbilityScores() {
    final random = Random.secure();
    final rolled = AbilityScoreGenerator.rollSix(nextInt: random.nextInt);
    setState(() {
      _abilityMethod = AbilityScoreMethod.rolled;
      _setAbilityScores(
        AbilityScoreGenerator.assignByPriority(
          scores: rolled,
          priorities: _abilityPrioritiesForClass(_className),
        ),
      );
    });
  }

  List<String> _abilityPrioritiesForClass(String className) {
    final preset = _presetAbilitiesForClass(className).entries.toList()
      ..sort((left, right) => right.value.compareTo(left.value));
    return preset.map((entry) => entry.key).toList(growable: false);
  }

  void _setAbilityScores(Map<String, int> scores) {
    _abilityScores = Map<String, int>.from(scores);
    for (final entry in _abilityScores.entries) {
      _abilityControllers[entry.key]?.text = '${entry.value}';
    }
  }

  Map<String, int> _presetAbilitiesForClass(String className) {
    final normalized = className.toLowerCase();
    if (normalized.contains('法师') || normalized.contains('wizard')) {
      return {'str': 8, 'dex': 13, 'con': 14, 'int': 15, 'wis': 12, 'cha': 10};
    }
    if (normalized.contains('游荡者') || normalized.contains('rogue')) {
      return {'str': 8, 'dex': 15, 'con': 14, 'int': 12, 'wis': 10, 'cha': 13};
    }
    if (normalized.contains('牧师') || normalized.contains('cleric')) {
      return {'str': 10, 'dex': 12, 'con': 14, 'int': 8, 'wis': 15, 'cha': 13};
    }
    return {'str': 15, 'dex': 14, 'con': 13, 'int': 10, 'wis': 12, 'cha': 8};
  }

  void _resetAbilityScoresForClass(String className) {
    final scores = _abilityMethod == AbilityScoreMethod.rolled
        ? AbilityScoreGenerator.assignByPriority(
            scores: _abilityScores.values.toList(growable: false),
            priorities: _abilityPrioritiesForClass(className),
          )
        : _presetAbilitiesForClass(className);
    _setAbilityScores(scores);
  }

  Set<String> _presetSkillsForBackground(String background) {
    final normalized = background.toLowerCase();
    if (normalized.contains('贤者') || normalized.contains('sage')) {
      return {'奥秘', '历史'};
    }
    if (normalized.contains('罪犯') || normalized.contains('criminal')) {
      return {'欺瞒', '隐匿'};
    }
    if (normalized.contains('侍僧') ||
        normalized.contains('侍祭') ||
        normalized.contains('acolyte')) {
      return {'洞悉', '宗教'};
    }
    return {'运动', '威吓'};
  }
}

class _BuilderStepEditor extends StatelessWidget {
  const _BuilderStepEditor({
    required this.step,
    required this.stepLabel,
    required this.stepDescription,
    required this.nameController,
    required this.onNameChanged,
    required this.child,
  });

  final int step;
  final String stepLabel;
  final String stepDescription;
  final TextEditingController nameController;
  final ValueChanged<String> onNameChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '步骤 ${step + 1} · $stepLabel',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                stepDescription,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                key: const Key('standard-character-name-field'),
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '角色名',
                  hintText: '可以稍后修改',
                  prefixIcon: Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(),
                ),
                onChanged: onNameChanged,
              ),
              const SizedBox(height: 20),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: KeyedSubtree(key: ValueKey(step), child: child),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BuilderFooter extends StatelessWidget {
  const _BuilderFooter({
    required this.currentStep,
    required this.lastStep,
    required this.canCreate,
    required this.onPrevious,
    required this.onNext,
    required this.onContinueToFullSheet,
    required this.onCreate,
  });

  final int currentStep;
  final int lastStep;
  final bool canCreate;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onContinueToFullSheet;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 720;
            final fullSheetButton = compact
                ? IconButton(
                    tooltip: '继续编辑完整角色卡',
                    onPressed: onContinueToFullSheet,
                    icon: const Icon(Icons.edit_note_outlined),
                  )
                : OutlinedButton.icon(
                    onPressed: onContinueToFullSheet,
                    icon: const Icon(Icons.edit_note_outlined),
                    label: const Text('继续编辑完整角色卡'),
                  );
            final previousButton = compact
                ? IconButton(
                    tooltip: '上一步',
                    onPressed: onPrevious,
                    icon: const Icon(Icons.arrow_back),
                  )
                : OutlinedButton.icon(
                    onPressed: onPrevious,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('上一步'),
                  );
            final primaryButton = currentStep == lastStep
                ? FilledButton.icon(
                    onPressed: canCreate ? onCreate : null,
                    icon: const Icon(Icons.check),
                    label: const Text('创建角色'),
                  )
                : FilledButton.icon(
                    onPressed: onNext,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('下一步'),
                  );
            return Row(
              children: [
                fullSheetButton,
                const Spacer(),
                previousButton,
                const SizedBox(width: 12),
                if (compact) Expanded(child: primaryButton) else primaryButton,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BuilderSummaryPanel extends StatelessWidget {
  const _BuilderSummaryPanel({
    required this.summary,
    required this.review,
    required this.level,
    required this.className,
    required this.abilities,
    required this.selectedSpells,
    required this.selectedItems,
    required this.pendingChoices,
  });

  final String summary;
  final _StandardBuildReview review;
  final int level;
  final String className;
  final Map<String, int> abilities;
  final int selectedSpells;
  final int selectedItems;
  final int pendingChoices;

  @override
  Widget build(BuildContext context) {
    final hp = Dnd5eRules.averageHitPoints(
      className: className,
      level: level,
      abilities: abilities,
    );
    final armorClass = Dnd5eRules.baseArmorClass(abilities);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('角色摘要', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(summary, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(label: 'HP', value: '$hp'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryMetric(label: 'AC', value: '$armorClass'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryMetric(
                  label: '熟练',
                  value: '+${Dnd5eRules.proficiencyBonus(level)}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('完成度', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: review.progress),
          const SizedBox(height: 6),
          Text('${review.completed}/${review.total} 已完成'),
          const SizedBox(height: 20),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.backpack_outlined),
            title: const Text('装备'),
            trailing: Text('$selectedItems'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.auto_fix_high_outlined),
            title: const Text('法术'),
            trailing: Text('$selectedSpells'),
          ),
          if (pendingChoices > 0)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.pending_actions_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
              title: const Text('待完成选择'),
              trailing: Text('$pendingChoices'),
            ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.titleMedium),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _DetailsStep extends StatelessWidget {
  const _DetailsStep({
    required this.name,
    required this.avatarBytes,
    required this.isPickingAvatar,
    required this.avatarPickError,
    required this.onPickAvatar,
  });

  final String name;
  final Uint8List? avatarBytes;
  final bool isPickingAvatar;
  final String? avatarPickError;
  final VoidCallback onPickAvatar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AvatarPicker(
          key: const Key('standard-character-avatar-picker'),
          previewBytes: avatarBytes,
          isUploading: isPickingAvatar,
          error: avatarPickError,
          onPick: onPickAvatar,
        ),
        const SizedBox(height: 12),
        Card.outlined(
          child: ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(name.trim().isEmpty ? '角色名尚未填写' : name.trim()),
            subtitle: const Text('角色名位于每个步骤顶部；头像、外貌和人物经历可在角色卡中继续完善。'),
          ),
        ),
      ],
    );
  }
}

class _StructuredRuleSummary extends StatelessWidget {
  const _StructuredRuleSummary({
    required this.title,
    required this.entry,
    required this.fields,
  });

  final String title;
  final ContentEntry? entry;
  final List<String> fields;

  @override
  Widget build(BuildContext context) {
    final items = <({String field, String value})>[];
    for (final field in fields) {
      final value = _formatValue(entry?.structured[field]);
      if (value.isNotEmpty) items.add((field: field, value: value));
    }
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card.filled(
        key: Key('structured-rule-summary-$title'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.rule_folder_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              for (final item in items)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_iconFor(item.field)),
                  title: Text(_labelFor(item.field)),
                  subtitle: Text(item.value),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatValue(Object? value) {
    if (value == null) return '';
    if (value is Iterable) return value.map((item) => '$item').join('、');
    return '$value'.trim();
  }

  static String _labelFor(String field) => switch (field) {
    'primaryAbility' => '主属性',
    'hitDie' => '生命骰',
    'savingThrows' => '豁免熟练',
    'skills' => '技能选择',
    'weaponProficiency' => '武器熟练',
    'armorProficiency' => '护甲熟练',
    'startingEquipment' => '初始装备',
    _ => field,
  };

  static IconData _iconFor(String field) => switch (field) {
    'primaryAbility' => Icons.hexagon_outlined,
    'hitDie' => Icons.favorite_outline,
    'savingThrows' => Icons.health_and_safety_outlined,
    'skills' => Icons.psychology_outlined,
    'weaponProficiency' => Icons.gavel_outlined,
    'armorProficiency' => Icons.shield_outlined,
    'startingEquipment' => Icons.inventory_2_outlined,
    _ => Icons.info_outline,
  };
}

class _RuleGrantPreview extends StatelessWidget {
  const _RuleGrantPreview({required this.entries, required this.level});

  final List<ContentEntry> entries;
  final int level;

  @override
  Widget build(BuildContext context) {
    final grants =
        <({ContentEntry entry, RuleGrantDefinition grant, int? level})>[];
    for (final entry in entries) {
      final rules = entry.rules;
      if (rules == null) continue;
      grants.addAll(
        rules.grants.map((grant) => (entry: entry, grant: grant, level: null)),
      );
      for (final progression in rules.progression) {
        if (progression.level > level) continue;
        grants.addAll(
          progression.grants.map(
            (grant) => (entry: entry, grant: grant, level: progression.level),
          ),
        );
      }
    }
    if (grants.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card.filled(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome_outlined),
                  const SizedBox(width: 8),
                  Text('自动获得', style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 8),
              for (final item in grants)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_grantIcon(item.grant.kind)),
                  title: Text(item.grant.label),
                  subtitle: Text(
                    item.level == null
                        ? item.entry.name
                        : '${item.entry.name} · 等级 ${item.level}',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _grantIcon(RuleGrantKind kind) {
    return switch (kind) {
      RuleGrantKind.feature => Icons.auto_awesome_outlined,
      RuleGrantKind.proficiency => Icons.workspace_premium_outlined,
      RuleGrantKind.spell => Icons.auto_fix_high_outlined,
      RuleGrantKind.equipment => Icons.inventory_2_outlined,
      RuleGrantKind.resource => Icons.battery_5_bar_outlined,
      RuleGrantKind.action => Icons.bolt_outlined,
      RuleGrantKind.conditionResistance => Icons.health_and_safety_outlined,
      RuleGrantKind.speed => Icons.directions_run_outlined,
      RuleGrantKind.armorClass => Icons.shield_outlined,
      RuleGrantKind.hitPoints => Icons.favorite_outline,
      RuleGrantKind.ability => Icons.hexagon_outlined,
      RuleGrantKind.note => Icons.notes_outlined,
    };
  }
}

class _BuilderReviewStep extends StatelessWidget {
  const _BuilderReviewStep({
    required this.summary,
    required this.review,
    required this.pendingRuleChoices,
    required this.abilityMethodLabel,
  });

  final String summary;
  final _StandardBuildReview review;
  final List<_ActiveRuleChoice> pendingRuleChoices;
  final String abilityMethodLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('审核角色', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                '完成度',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text('${review.completed}/${review.total} 已完成'),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: review.progress),
        const SizedBox(height: 12),
        Card.filled(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.fact_check_outlined),
                title: const Text('审核摘要'),
                subtitle: Text(summary),
              ),
              const Divider(height: 1),
              ListTile(
                dense: true,
                leading: const Icon(Icons.hexagon_outlined),
                title: const Text('属性生成来源'),
                trailing: Text(abilityMethodLabel),
              ),
              const Divider(height: 1),
              for (final check in review.checks)
                ListTile(
                  dense: true,
                  leading: Icon(
                    check.done
                        ? Icons.check_circle_outline
                        : Icons.radio_button_unchecked,
                  ),
                  title: Text(check.label),
                  trailing: Text(check.done ? '完成' : '待完成'),
                ),
            ],
          ),
        ),
        if (!review.isReady || pendingRuleChoices.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card.outlined(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '创建前仍需完成',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final missing in review.missing)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.error_outline),
                      title: Text(missing),
                    ),
                  for (final choice in pendingRuleChoices)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.pending_actions_outlined),
                      title: Text(choice.definition.label),
                    ),
                ],
              ),
            ),
          ),
        ] else ...[
          const SizedBox(height: 12),
          Card.outlined(
            child: const ListTile(
              leading: Icon(Icons.check_circle_outline),
              title: Text('创建前检查通过'),
              subtitle: Text('角色会保存所选资料条目的稳定引用与当前规则授予结果。'),
            ),
          ),
        ],
      ],
    );
  }
}

class _ActiveRuleChoice {
  const _ActiveRuleChoice({
    required this.key,
    required this.sourceEntryId,
    required this.sourceName,
    required this.builderStep,
    required this.definition,
    this.level,
  });

  final String key;
  final String sourceEntryId;
  final String sourceName;
  final int builderStep;
  final int? level;
  final RuleChoiceDefinition definition;
}

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
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
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
                            visualDensity: VisualDensity.compact,
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

class _StandardBuildReview {
  const _StandardBuildReview({required this.checks});

  factory _StandardBuildReview.from({
    required String name,
    required String className,
    required String species,
    required String background,
    required Map<String, int> abilityScores,
  }) {
    return _StandardBuildReview(
      checks: [
        const _BuildCheck(label: '来源', done: true),
        _BuildCheck(label: '职业', done: className.trim().isNotEmpty),
        _BuildCheck(
          label: '起源',
          done: species.trim().isNotEmpty && background.trim().isNotEmpty,
        ),
        _BuildCheck(label: '属性', done: _abilitiesAreValid(abilityScores)),
        _BuildCheck(label: '详情', done: name.trim().isNotEmpty),
      ],
    );
  }

  final List<_BuildCheck> checks;

  int get completed => checks.where((check) => check.done).length;
  int get total => checks.length;
  double get progress => completed / total;
  bool get isReady => completed == total;

  List<String> get missing {
    final result = <String>[];
    if (!checks.firstWhere((check) => check.label == '详情').done) {
      result.add('缺少角色名');
    }
    if (!checks.firstWhere((check) => check.label == '职业').done) {
      result.add('缺少职业');
    }
    if (!checks.firstWhere((check) => check.label == '起源').done) {
      result.add('缺少起源');
    }
    if (!checks.firstWhere((check) => check.label == '属性').done) {
      result.add('属性值需在 3-20');
    }
    return result;
  }

  static bool _abilitiesAreValid(Map<String, int> abilityScores) {
    return Dnd5eRules.abilityLabels.keys.every((ability) {
      final value = abilityScores[ability];
      return value != null && value >= 3 && value <= 20;
    });
  }
}

class _BuildCheck {
  const _BuildCheck({required this.label, required this.done});

  final String label;
  final bool done;
}

class _SourceBanner extends StatelessWidget {
  const _SourceBanner();

  @override
  Widget build(BuildContext context) {
    return Card.filled(
      child: const ListTile(
        leading: Icon(Icons.auto_stories_outlined),
        title: Text('D&D 2024'),
        subtitle: Text('使用物种、背景和 Origin Feat 的新版创建顺序。'),
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
                        visualDensity: VisualDensity.compact,
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

class _LevelProgressionSection extends StatelessWidget {
  const _LevelProgressionSection({
    required this.level,
    required this.className,
    required this.abilities,
    required this.onChanged,
  });

  final int level;
  final String className;
  final Map<String, int> abilities;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hp = Dnd5eRules.averageHitPoints(
      className: className,
      level: level,
      abilities: abilities,
    );
    final proficiency = Dnd5eRules.proficiencyBonus(level);
    final spellSlots = Dnd5eRules.spellSlotMaximums(
      classSummary: className,
      level: level,
    );
    final classResources = Dnd5eRules.classResources(
      classSummary: className,
      level: level,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card.outlined(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('等级', style: theme.textTheme.titleMedium),
                  ),
                  InputChip(
                    avatar: const Icon(Icons.trending_up_outlined),
                    label: Text('当前等级 $level'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton.filledTonal(
                    key: const Key('standard-level-decrement-button'),
                    tooltip: '降低等级',
                    onPressed: level <= 1 ? null : () => onChanged(level - 1),
                    icon: const Icon(Icons.remove),
                  ),
                  Expanded(
                    child: Slider(
                      value: level.toDouble(),
                      min: 1,
                      max: 20,
                      divisions: 19,
                      label: '$level',
                      onChanged: (value) => onChanged(value.round()),
                    ),
                  ),
                  IconButton.filledTonal(
                    key: const Key('standard-level-increment-button'),
                    tooltip: '提高等级',
                    onPressed: level >= 20 ? null : () => onChanged(level + 1),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('HP $hp')),
                  Chip(label: Text('熟练 +$proficiency')),
                  if (spellSlots.isNotEmpty)
                    Chip(label: Text('法术位 ${_formatSpellSlots(spellSlots)}')),
                  if (classResources.isNotEmpty)
                    Chip(
                      label: Text(
                        '职业资源 ${_formatClassResources(classResources)}',
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatSpellSlots(Map<String, int> slots) {
    final entries = slots.entries.toList()
      ..sort((a, b) => int.parse(a.key).compareTo(int.parse(b.key)));
    return entries
        .map(
          (entry) => '${Dnd5eRules.spellLevelLabel(entry.key)} ${entry.value}',
        )
        .join(' / ');
  }

  static String _formatClassResources(List<Dnd5eClassResource> resources) {
    return resources.map((item) => '${item.name} ${item.maximum}').join(' / ');
  }
}

class _AbilityScoreSection extends StatelessWidget {
  const _AbilityScoreSection({
    required this.method,
    required this.scores,
    required this.controllers,
    required this.onMethodChanged,
    required this.onApplyRecommended,
    required this.onRoll,
    required this.onChanged,
  });

  final AbilityScoreMethod method;
  final Map<String, int> scores;
  final Map<String, TextEditingController> controllers;
  final ValueChanged<AbilityScoreMethod> onMethodChanged;
  final VoidCallback onApplyRecommended;
  final VoidCallback onRoll;
  final void Function(String ability, int value) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isComplete = Dnd5eRules.abilityLabels.keys.every((ability) {
      final score = scores[ability];
      return score != null && score >= 3 && score <= 20;
    });
    final remaining = AbilityScoreGenerator.pointBuyRemaining(scores);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('属性', style: theme.textTheme.titleMedium)),
              InputChip(
                avatar: Icon(
                  isComplete ? Icons.check_circle_outline : Icons.error_outline,
                ),
                label: Text(isComplete ? '属性已完成' : '属性需调整'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SegmentedButton<AbilityScoreMethod>(
            segments: const [
              ButtonSegment(
                value: AbilityScoreMethod.standardArray,
                icon: Icon(Icons.view_array_outlined),
                label: Text('标准数组', key: Key('ability-method-standard')),
              ),
              ButtonSegment(
                value: AbilityScoreMethod.pointBuy,
                icon: Icon(Icons.calculate_outlined),
                label: Text('27 点购点', key: Key('ability-method-point-buy')),
              ),
              ButtonSegment(
                value: AbilityScoreMethod.rolled,
                icon: Icon(Icons.casino_outlined),
                label: Text('随机', key: Key('ability-method-rolled')),
              ),
            ],
            selected: {method},
            showSelectedIcon: false,
            onSelectionChanged: (selection) =>
                onMethodChanged(selection.single),
          ),
          const SizedBox(height: 12),
          if (method == AbilityScoreMethod.pointBuy)
            Row(
              children: [
                Icon(
                  remaining < 0 ? Icons.error_outline : Icons.toll_outlined,
                  color: remaining < 0 ? theme.colorScheme.error : null,
                ),
                const SizedBox(width: 8),
                Text(
                  '剩余 $remaining / ${AbilityScoreGenerator.pointBuyBudget} 点',
                  key: const Key('point-buy-remaining'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: remaining < 0 ? theme.colorScheme.error : null,
                  ),
                ),
              ],
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                key: Key(
                  method == AbilityScoreMethod.rolled
                      ? 'reroll-ability-scores'
                      : 'apply-recommended-ability-array',
                ),
                onPressed: method == AbilityScoreMethod.rolled
                    ? onRoll
                    : onApplyRecommended,
                icon: Icon(
                  method == AbilityScoreMethod.rolled
                      ? Icons.casino_outlined
                      : Icons.auto_fix_high_outlined,
                ),
                label: Text(
                  method == AbilityScoreMethod.rolled ? '重新掷骰' : '按职业推荐分配',
                ),
              ),
            ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              return GridView.count(
                crossAxisCount: compact ? 2 : 3,
                childAspectRatio: compact ? 1.7 : 2.2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final entry in Dnd5eRules.abilityLabels.entries)
                    method == AbilityScoreMethod.pointBuy
                        ? _PointBuyAbilityTile(
                            ability: entry.key,
                            label: entry.value,
                            scores: scores,
                            onChanged: (value) {
                              controllers[entry.key]?.text = '$value';
                              onChanged(entry.key, value);
                            },
                          )
                        : TextField(
                            key: Key('standard-ability-${entry.key}-field'),
                            controller: controllers[entry.key],
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: entry.value,
                              helperText:
                                  '调整值 ${Dnd5eRules.formatModifier(Dnd5eRules.abilityModifier(scores[entry.key] ?? 10))}',
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (value) =>
                                onChanged(entry.key, int.tryParse(value) ?? 0),
                          ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PointBuyAbilityTile extends StatelessWidget {
  const _PointBuyAbilityTile({
    required this.ability,
    required this.label,
    required this.scores,
    required this.onChanged,
  });

  final String ability;
  final String label;
  final Map<String, int> scores;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final score = scores[ability] ?? 8;
    final canIncrease = AbilityScoreGenerator.canSetPointBuyScore(
      scores,
      ability,
      score + 1,
    );
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.labelLarge),
                  Text(
                    '$score  ${Dnd5eRules.formatModifier(Dnd5eRules.abilityModifier(score))}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            IconButton(
              key: Key('point-buy-$ability-decrease'),
              tooltip: '降低$label',
              onPressed: score > 8 ? () => onChanged(score - 1) : null,
              icon: const Icon(Icons.remove),
            ),
            IconButton(
              key: Key('point-buy-$ability-increase'),
              tooltip: '提高$label',
              onPressed: canIncrease ? () => onChanged(score + 1) : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkillProficiencySection extends StatelessWidget {
  const _SkillProficiencySection({
    required this.selected,
    required this.onChanged,
    this.options = const <String>[],
    this.fixed = const <String>{},
    this.maximum,
  });

  final Set<String> selected;
  final List<String> options;
  final Set<String> fixed;
  final int? maximum;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final constrained = maximum != null && options.isNotEmpty;
    final optionNames = options.toSet();
    final chosen = selected
        .where((skill) => optionNames.contains(skill) && !fixed.contains(skill))
        .toSet();
    final displayedNames = constrained
        ? <String>{...fixed, ...optionNames}
        : Dnd5eRules.skills.map((skill) => skill.name).toSet();
    final displayedSkills = Dnd5eRules.skills
        .where((skill) => displayedNames.contains(skill.name))
        .toList(growable: false);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('熟练', style: theme.textTheme.titleMedium)),
              InputChip(
                avatar: const Icon(Icons.workspace_premium_outlined),
                label: Text(
                  constrained
                      ? '职业技能 ${chosen.length}/$maximum · 背景 ${fixed.length}'
                      : '熟练 ${selected.length} 项',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final skill in displayedSkills)
                Builder(
                  builder: (context) {
                    final isFixed = constrained && fixed.contains(skill.name);
                    final isSelected = selected.contains(skill.name);
                    final atLimit =
                        constrained && chosen.length >= (maximum ?? 0);
                    return FilterChip(
                      key: Key('standard-skill-${skill.name}-chip'),
                      avatar: isFixed
                          ? const Icon(Icons.lock_outline, size: 16)
                          : null,
                      label: Text(
                        '${skill.name} · ${Dnd5eRules.abilityLabels[skill.ability]}',
                      ),
                      selected: isSelected,
                      onSelected: isFixed || (!isSelected && atLimit)
                          ? null
                          : (nextSelected) {
                              final next = {...selected};
                              if (nextSelected) {
                                next.add(skill.name);
                              } else {
                                next.remove(skill.name);
                              }
                              onChanged(next);
                            },
                    );
                  },
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
                          visualDensity: VisualDensity.compact,
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

int _intValue(TextEditingController controller, int fallback) {
  return int.tryParse(controller.text.trim()) ?? fallback;
}

List<Map<String, Object>> _parseInventory(String text) {
  final result = <Map<String, Object>>[];
  for (final rawLine in text.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    final match = RegExp(r'^(.*?)\s*[xX×]\s*(\d+)$').firstMatch(line);
    if (match == null) {
      result.add({'name': line, 'quantity': 1});
    } else {
      result.add({
        'name': match.group(1)!.trim(),
        'quantity': int.parse(match.group(2)!),
      });
    }
  }
  return result;
}

String _inventoryToLines(List<Object?> inventory) {
  return inventory
      .map((item) {
        if (item is Map) {
          final name = item['name']?.toString() ?? '';
          final quantity = item['quantity'];
          if (quantity == null || quantity == 1) return name;
          return '$name x$quantity';
        }
        return '$item';
      })
      .join('\n');
}

List<Object?> _mergeInventory(List<Object?> current, List<Object?> generated) {
  final result = <Object?>[...current];
  final keys = {for (final item in current) _inventoryIdentity(item)}
    ..removeWhere((key) => key.isEmpty);
  for (final item in generated) {
    final key = _inventoryIdentity(item);
    if (key.isEmpty || !keys.add(key)) continue;
    result.add(item);
  }
  return result;
}

String _inventoryIdentity(Object? item) {
  if (item is Map) {
    final entryId = item['entryId']?.toString().trim();
    if (entryId != null && entryId.isNotEmpty) return 'id:$entryId';
    final name = item['name']?.toString().trim().toLowerCase() ?? '';
    return name.isEmpty ? '' : 'name:$name';
  }
  final name = '$item'.trim().toLowerCase();
  return name.isEmpty ? '' : 'name:$name';
}
