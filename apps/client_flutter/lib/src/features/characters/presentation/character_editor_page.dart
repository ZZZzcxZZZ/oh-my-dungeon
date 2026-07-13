import 'package:flutter/material.dart';

import '../domain/character.dart';
import '../domain/character_edit_draft.dart';
import '../domain/dnd5e_rules.dart';
import '../domain/quick_build.dart';
import '../../content/domain/content.dart';

class CharacterEditorPage extends StatefulWidget {
  const CharacterEditorPage({
    required this.onSubmit,
    this.initialCharacter,
    this.defaultCreationMethod = 'choose',
    this.contentItems = const [],
    super.key,
  });

  final CharacterSheet? initialCharacter;
  final String defaultCreationMethod;
  final List<ContentItem> contentItems;
  final Future<bool> Function(CharacterEditDraft draft) onSubmit;

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
  bool _saving = false;

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
        contentItems: widget.contentItems,
        onSubmit: _submitQuickBuild,
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
                      Expanded(child: _numberField(_levelController, '等级')),
                      const SizedBox(width: 12),
                      Expanded(child: _numberField(_speedController, '速度')),
                    ],
                  ),
                ],
              ),
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

  Widget _numberField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
    );
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
    final ok = await widget.onSubmit(_draft(name));
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.of(context).maybePop();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存角色失败')));
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
    final draft = QuickBuildService.build(quickDraft);
    final ok = await widget.onSubmit(draft);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.of(context).maybePop();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('创建角色失败')));
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
      data: widget.initialCharacter?.dataMap ?? const {},
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
    required this.contentItems,
    required this.onSubmit,
    required this.onContinueToFullSheet,
  });

  final List<ContentItem> contentItems;
  final Future<void> Function(QuickBuildSelection draft) onSubmit;
  final VoidCallback onContinueToFullSheet;

  @override
  State<_StandardBuildPage> createState() => _StandardBuildPageState();
}

class _StandardBuildPageState extends State<_StandardBuildPage> {
  static const _steps = ['来源', '职业', '起源', '属性', '熟练', '装备', '法术', '详情', '审核'];

  final _nameController = TextEditingController();
  late String _className;
  late String _species;
  late String _background;
  int _level = 1;
  final Set<String> _selectedSpellRefs = {};
  final Set<String> _selectedItemRefs = {};
  late Set<String> _selectedSkillProficiencies;
  late Map<String, int> _abilityScores;
  late Map<String, TextEditingController> _abilityControllers;

  @override
  void initState() {
    super.initState();
    _className = _contentChoiceLabels('class', _defaultClassOptions).first;
    _species = _contentChoiceLabels('species', _defaultSpeciesOptions).first;
    _background = _contentChoiceLabels(
      'background',
      _defaultBackgroundOptions,
    ).first;
    _selectedSkillProficiencies = _presetSkillsForBackground(_background);
    _abilityScores = _presetAbilitiesForClass(_className);
    _abilityControllers = {
      for (final entry in Dnd5eRules.abilityLabels.entries)
        entry.key: TextEditingController(text: '${_abilityScores[entry.key]}'),
    };
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

    return Scaffold(
      appBar: AppBar(title: const Text('标准创建角色')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SourceBanner(),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('standard-character-name-field'),
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '角色名',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                _ChoiceSection(
                  title: '职业',
                  selected: _className,
                  options: classOptions,
                  sourceLabel: _hasContentChoices('class') ? '来自资料库' : null,
                  onSelected: (value) => setState(() {
                    _className = value;
                    _resetAbilityScoresForClass(value);
                  }),
                ),
                _LevelProgressionSection(
                  level: _level,
                  className: _className,
                  abilities: _abilityScores,
                  onChanged: (value) => setState(() => _level = value),
                ),
                _ChoiceSection(
                  title: '起源：物种',
                  selected: _species,
                  options: speciesOptions,
                  sourceLabel: _hasContentChoices('species') ? '来自资料库' : null,
                  onSelected: (value) => setState(() => _species = value),
                ),
                _ChoiceSection(
                  title: '起源：背景',
                  selected: _background,
                  options: backgroundOptions,
                  sourceLabel: _hasContentChoices('background')
                      ? '来自资料库'
                      : null,
                  onSelected: (value) => setState(() {
                    _background = value;
                    _selectedSkillProficiencies = _presetSkillsForBackground(
                      value,
                    );
                  }),
                ),
                _AbilityScoreSection(
                  scores: _abilityScores,
                  controllers: _abilityControllers,
                  onChanged: (ability, value) =>
                      setState(() => _abilityScores[ability] = value),
                ),
                _SkillProficiencySection(
                  selected: _selectedSkillProficiencies,
                  onChanged: (next) =>
                      setState(() => _selectedSkillProficiencies = next),
                ),
                _MultiChoiceSection(
                  title: '法术',
                  selected: _selectedSpellRefs,
                  options: spellOptions,
                  sourceLabel: _hasContentChoices('spell') ? '来自资料库' : null,
                  emptyLabel: '资料库中暂无法术；可先跳过，之后在角色卡里补充。',
                  onChanged: (next) =>
                      setState(() => _replaceSet(_selectedSpellRefs, next)),
                ),
                _MultiChoiceSection(
                  title: '装备',
                  selected: _selectedItemRefs,
                  options: itemOptions,
                  sourceLabel:
                      _hasContentChoicesForTypes(const ['equipment', 'item'])
                      ? '来自资料库'
                      : null,
                  emptyLabel: '资料库中暂无装备；会先使用职业默认装备。',
                  onChanged: (next) =>
                      setState(() => _replaceSet(_selectedItemRefs, next)),
                ),
                Card.filled(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '完成度',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            Text(
                              '${review.completed}/${review.total} 已完成',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(value: review.progress),
                        const SizedBox(height: 8),
                        Text(review.isReady ? '创建前检查通过' : '仍有项目需要完成'),
                        if (review.missing.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final item in review.missing)
                                InputChip(
                                  avatar: const Icon(Icons.error_outline),
                                  label: Text(item),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < _steps.length; i++)
                  Card.outlined(
                    child: ListTile(
                      leading: CircleAvatar(child: Text('${i + 1}')),
                      title: Text(_steps[i]),
                      subtitle: Text(_stepDescription(_steps[i])),
                      trailing: i <= 2
                          ? const Icon(Icons.check_circle_outline)
                          : const Icon(Icons.radio_button_unchecked),
                    ),
                  ),
                const SizedBox(height: 16),
                Card.filled(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.fact_check_outlined),
                        title: const Text('审核摘要'),
                        subtitle: Text(summary),
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
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onContinueToFullSheet,
                  icon: const Icon(Icons.edit_note_outlined),
                  label: const Text('继续编辑完整角色卡'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: review.isReady
                      ? () => widget.onSubmit(
                          QuickBuildSelection(
                            name: _nameController.text,
                            className: _className,
                            species: _species,
                            background: _background,
                            level: _level,
                            spellRefs: _selectedSpellRefs.toList(),
                            itemRefs: _selectedItemRefs.toList(),
                            abilities: Map.unmodifiable(_abilityScores),
                            skillProficiencies: _selectedSkillProficiencies
                                .toList(),
                          ),
                        )
                      : null,
                  icon: const Icon(Icons.check),
                  label: const Text('创建角色'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _stepDescription(String step) {
    return switch (step) {
      '来源' => '选择 D&D 2024、Legacy 或战役允许内容。',
      '职业' => '选择职业、等级和职业资源。',
      '起源' => '选择物种、背景、语言和 Origin Feat。',
      '属性' => '标准数组、购点、掷骰或自定义。',
      '熟练' => '技能、工具、武器、防具与豁免。',
      '装备' => '职业装备、金币购买或自定义装备。',
      '法术' => '戏法、准备法术、法术位和专注。',
      '详情' => '名字、头像、阵营、外貌与背景。',
      '审核' => '检查缺失项、来源和手动覆盖。',
      _ => '',
    };
  }

  List<String> _contentChoiceLabels(String type, List<String> fallback) {
    return _contentChoiceLabelsForTypes([type], fallback);
  }

  List<String> _contentChoiceLabelsForTypes(
    List<String> types,
    List<String> fallback,
  ) {
    final labels =
        widget.contentItems
            .where((item) => types.contains(item.type))
            .map((item) => item.name.trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return labels.isEmpty ? fallback : labels;
  }

  bool _hasContentChoices(String type) {
    return _hasContentChoicesForTypes([type]);
  }

  bool _hasContentChoicesForTypes(List<String> types) {
    return widget.contentItems.any(
      (item) => types.contains(item.type) && item.name.trim().isNotEmpty,
    );
  }

  void _replaceSet(Set<String> target, Set<String> next) {
    target
      ..clear()
      ..addAll(next);
  }

  Map<String, int> _presetAbilitiesForClass(String className) {
    final normalized = className.toLowerCase();
    if (normalized.contains('法师') || normalized.contains('wizard')) {
      return {'str': 8, 'dex': 14, 'con': 14, 'int': 16, 'wis': 12, 'cha': 10};
    }
    if (normalized.contains('游荡者') || normalized.contains('rogue')) {
      return {'str': 8, 'dex': 16, 'con': 14, 'int': 12, 'wis': 10, 'cha': 14};
    }
    if (normalized.contains('牧师') || normalized.contains('cleric')) {
      return {'str': 10, 'dex': 12, 'con': 14, 'int': 8, 'wis': 16, 'cha': 14};
    }
    return {'str': 16, 'dex': 14, 'con': 14, 'int': 10, 'wis': 12, 'cha': 8};
  }

  void _resetAbilityScoresForClass(String className) {
    _abilityScores = _presetAbilitiesForClass(className);
    for (final entry in _abilityScores.entries) {
      _abilityControllers[entry.key]?.text = '${entry.value}';
    }
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
  });

  final String title;
  final String selected;
  final List<String> options;
  final ValueChanged<String> onSelected;
  final String? sourceLabel;

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
                ChoiceChip(
                  label: Text(option),
                  selected: option == selected,
                  onSelected: (_) => onSelected(option),
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
    required this.scores,
    required this.controllers,
    required this.onChanged,
  });

  final Map<String, int> scores;
  final Map<String, TextEditingController> controllers;
  final void Function(String ability, int value) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isComplete = Dnd5eRules.abilityLabels.keys.every((ability) {
      final score = scores[ability];
      return score != null && score >= 3 && score <= 20;
    });

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
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              return GridView.count(
                crossAxisCount: compact ? 2 : 3,
                childAspectRatio: compact ? 2.7 : 3.2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final entry in Dnd5eRules.abilityLabels.entries)
                    TextField(
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

class _SkillProficiencySection extends StatelessWidget {
  const _SkillProficiencySection({
    required this.selected,
    required this.onChanged,
  });

  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                label: Text('熟练 ${selected.length} 项'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final skill in Dnd5eRules.skills)
                FilterChip(
                  key: Key('standard-skill-${skill.name}-chip'),
                  label: Text(
                    '${skill.name} · ${Dnd5eRules.abilityLabels[skill.ability]}',
                  ),
                  selected: selected.contains(skill.name),
                  onSelected: (isSelected) {
                    final next = {...selected};
                    if (isSelected) {
                      next.add(skill.name);
                    } else {
                      next.remove(skill.name);
                    }
                    onChanged(next);
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
  });

  final String title;
  final Set<String> selected;
  final List<String> options;
  final ValueChanged<Set<String>> onChanged;
  final String emptyLabel;
  final String? sourceLabel;

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
          if (options.isEmpty)
            Text(emptyLabel)
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in options)
                  FilterChip(
                    label: Text(option),
                    selected: selected.contains(option),
                    onSelected: (isSelected) {
                      final next = {...selected};
                      if (isSelected) {
                        next.add(option);
                      } else {
                        next.remove(option);
                      }
                      onChanged(next);
                    },
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
