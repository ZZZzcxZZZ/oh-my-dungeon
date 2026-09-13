// character_editor_page.dart 的 part：完整角色卡构建页及其状态。
part of 'character_editor_page.dart';

class _StandardBuildPage extends StatefulWidget {
  const _StandardBuildPage({
    required this.contentEntries,
    required this.onSubmit,
    required this.onContinueToFullSheet,
    this.packagePriorities = const <String, int>{},
    this.onPickImage,
  });

  final List<ContentEntry> contentEntries;
  final Future<void> Function(QuickBuildSelection draft) onSubmit;
  final VoidCallback onContinueToFullSheet;

  /// 包 id → priority（决策 D2）：向导内的 HP 预览 / 生命骰 / 法术配额必须与建档、
  /// 快速创建用**同一份**优先级，否则同一角色在向导与落库后数字不同（M）。
  final Map<String, int> packagePriorities;
  final Future<({Uint8List bytes, String mimeType})?> Function()? onPickImage;

  @override
  State<_StandardBuildPage> createState() => _StandardBuildPageState();
}

class _StandardBuildPageState extends State<_StandardBuildPage> {
  static const _steps = ['职业', '背景', '物种', '属性', '熟练', '装备', '法术', '故事', '审核'];

  /// 专用 UI 选择的「家步骤」。数值**只有**
  /// `RuleChoiceDefinition.dedicatedOptionSteps` 一处定义；这里只是取出来当常量
  /// 用，专用渲染器据此认领（不写 `builderStep == 4` 之类的第二套位置判断）。
  static final int _skillHomeStep =
      RuleChoiceDefinition.dedicatedOptionSteps[RuleChoiceDefinition
          .skillOptionType]!;
  static final int _spellHomeStep =
      RuleChoiceDefinition.dedicatedOptionSteps[RuleChoiceDefinition
          .spellOptionType]!;
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
  final _appearanceController = TextEditingController();
  final _personalityController = TextEditingController();
  final _idealsController = TextEditingController();
  final _bondsController = TextEditingController();
  final _flawsController = TextEditingController();
  final _backstoryController = TextEditingController();
  final _privateNotesController = TextEditingController();
  int _currentStep = 0;
  late String _className;
  late String _species;
  late String _background;
  String? _classEntryId;
  String? _speciesEntryId;
  String? _backgroundEntryId;
  int _level = 1;
  final Set<String> _selectedSpellRefs = {};
  final List<Map<String, Object?>> _customSpells = [];
  final Set<String> _selectedItemRefs = {};
  final Map<String, List<String>> _ruleChoices = {};

  /// **背景预设**技能（`_presetSkillsForBackground`）。它只由背景决定，不是规则
  /// 选择：职业声明了 `optionType: "skill"` 时它是锁定的背景身份（`fixed`），
  /// 没有职业选择时（既有行为）它就是可编辑的技能集合本身。
  late Set<String> _backgroundSkillProficiencies;
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
    _backgroundSkillProficiencies = _backgroundSkillsFor(_backgroundEntryId);
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
    _appearanceController.dispose();
    _personalityController.dispose();
    _idealsController.dispose();
    _bondsController.dispose();
    _flawsController.dispose();
    _backstoryController.dispose();
    _privateNotesController.dispose();
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
    final spellSelectionRules = SpellSelectionPolicy.rulesFor(
      classEntry: _entryById(_classEntryId),
      characterLevel: _level,
    );
    final eligibleSpellEntries = SpellSelectionPolicy.eligibleSpells(
      entries: widget.contentEntries,
      rules: spellSelectionRules,
    );
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
          activeRuleChoices.any((choice) => choice.renderStep == 5))
        5,
      // 「法术」步骤必须对**任何**落在步骤 6 的选择可见：显式法术选择（家步骤
      // 由 `RuleChoiceDefinition.dedicatedOptionSteps` 定为 6，可能省略
      // `builderStep`）与通用条目选择（`builderStep: "spells"`）都算。否则选择区
      // 无处渲染却仍然阻塞创建。
      if (_hasContentChoices('spell') ||
          activeRuleChoices.any((choice) => choice.renderStep == 6))
        6,
      7,
      8,
    ];
    final visibleStep = visibleStepIndexes.indexOf(_currentStep);
    // 所有选择一律按普通选择校验：数量、以及 `requires` 前置（前置不满足 = 未完成，
    // 且由选择区显示原因，不静默跳过）。**没有免检名单**：`usesDedicatedOptionUi`
    // 只决定渲染位置（技能网格 / 法术池），选中值同样进 `_ruleChoices`。
    final ruleChoicesAreValid = activeRuleChoices.every(_ruleChoiceIsComplete);
    final stepContent = _buildStepContent(
      context: context,
      classOptions: classOptions,
      speciesOptions: speciesOptions,
      backgroundOptions: backgroundOptions,
      spellEntries: eligibleSpellEntries,
      spellSelectionRules: spellSelectionRules,
      itemOptions: itemOptions,
      startingEquipment: startingEquipment,
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
        // 同屏一个口径（M）：头部 HP 预览用向导页**唯一**的 `_resolveClassRules`
        // （带 structured.classRules 与包 priority），本组件不得自行解析。
        classRules: _resolveClassRules(_classEntryId),
        abilities: _abilityScores,
        selectedSpells: _selectedSpellRefs.length,
        selectedItems: _selectedItemRefs.length,
        pendingChoices: activeRuleChoices
            .where((active) => !_ruleChoiceIsComplete(active))
            .length,
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
      skillProficiencies: _backgroundSkillProficiencies.toList(growable: false),
      classEntry: _entryById(_classEntryId),
      classEntryId: _classEntryId,
      speciesEntryId: _speciesEntryId,
      backgroundEntryId: _backgroundEntryId,
      ruleChoices: {
        for (final entry in _ruleChoices.entries)
          entry.key: entry.value.toList(growable: false),
      },
      avatarUrl: _avatarDataUrl,
      appearance: _appearanceController.text,
      personalityTraits: _personalityController.text,
      ideals: _idealsController.text,
      bonds: _bondsController.text,
      flaws: _flawsController.text,
      backstory: _backstoryController.text,
      privateNotes: _privateNotesController.text,
      customSpells: List.unmodifiable(_customSpells),
    );
  }

  Widget _buildStepContent({
    required BuildContext context,
    required List<String> classOptions,
    required List<String> speciesOptions,
    required List<String> backgroundOptions,
    required List<ContentEntry> spellEntries,
    required SpellSelectionRules spellSelectionRules,
    required List<String> itemOptions,
    required Object? startingEquipment,
    required List<_ActiveRuleChoice> activeRuleChoices,
    required _StandardBuildReview review,
    required String summary,
  }) {
    // `skill` / `spell` 由专用渲染器承担，位置由 `optionType` 唯一决定
    // （`_ActiveRuleChoice.renderStep`，见 `RuleChoiceDefinition.dedicatedOptionSteps`），
    // 其余选择一律由共享组件渲染；判据的唯一实现点是
    // [RuleChoiceDefinition.usesDedicatedOptionUi]（**渲染**判据，不再是免检）。
    final choicesForCurrentStep = activeRuleChoices.where((choice) {
      return choice.renderStep == _currentStep &&
          !choice.definition.usesDedicatedOptionUi;
    });
    // `group` 相同的选择归一组（决策 D7）：组按首次声明顺序，无 group 的排最后。
    // 归组只有 `groupRuleChoiceSections` 一处实现；被排除在 `choicesForCurrentStep`
    // 之外的专用渲染器（技能网格 / 法术池）也在
    // [_skillProficiencySections] / [_spellChoicePoolSections] 里走**同一份**
    // 归组 + 标题组件，所以 `group` 在四种渲染路径上的呈现语义一致。
    final ruleChoiceGroups = groupRuleChoiceSections<_ActiveRuleChoice>(
      choicesForCurrentStep,
      groupOf: (active) => active.definition.group,
      buildChoice: (active) => RuleChoiceSection(
        definition: active.definition,
        candidates: _candidatesFor(active),
        selected: _ruleChoices[active.key] ?? const <String>[],
        sourceLabel: _choiceSourceLabel(active),
        blockedReason: _blockedReasonFor(active),
        requiresContext: _requiresContextFor(active),
        onOpenEntry: _openEntry,
        onChanged: (next) => setState(() {
          _ruleChoices[active.key] = next;
          _applyRecommendedRuleChoices();
        }),
      ),
    );
    final ruleChoiceWidgets = RuleChoiceGroupedSections(
      groups: ruleChoiceGroups,
    );
    // 显式法术选择的法术池（`usesDedicatedOptionUi` 的 `spell` 分支）。
    final spellChoicePools = _spellChoicePoolSections(activeRuleChoices);
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
            items: _classSummaryItems(_entryById(_classEntryId), const [
              'primaryAbility',
              'hitDie',
            ]),
          ),
          _LevelProgressionSection(
            level: _level,
            className: _className,
            classEntry: _entryById(_classEntryId),
            // 等级区生命骰与编辑器其它位置**同一口径**（M）。
            classRules: _resolveClassRules(_classEntryId),
            abilities: _abilityScores,
            onChanged: (value) => setState(() {
              _level = value;
              _applyRecommendedRuleChoices();
            }),
          ),
          ruleChoiceWidgets,
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
              _backgroundSkillProficiencies = _backgroundSkillsFor(
                _backgroundEntryId,
              );
              _applyRecommendedRuleChoices();
            }),
          ),
          ruleChoiceWidgets,
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
          ruleChoiceWidgets,
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
          // 决策 D7：`builderStep: "abilities"` 也必须有渲染位置，否则
          // `allowedBuilderSteps` 放行的选择会"看不见却阻塞创建"。
          ruleChoiceWidgets,
        ],
      ),
      4 => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StructuredRuleSummary(
            title: '职业熟练摘要',
            items: _classSummaryItems(_entryById(_classEntryId), const [
              'savingThrows',
              'skills',
              'weaponProficiency',
              'armorProficiency',
            ]),
          ),
          ruleChoiceWidgets,
          ..._skillProficiencySections(),
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
            items: _classSummaryItems(_entryById(_classEntryId), const [
              'startingEquipment',
            ]),
          ),
          ruleChoiceWidgets,
          if (ruleChoiceGroups.isEmpty) ...[
            _EquipmentBudgetSummary(
              startingEquipment: startingEquipment,
              selectedNames: _selectedItemRefs,
              entries: widget.contentEntries
                  .where(
                    (entry) =>
                        entry.type == 'equipment' || entry.type == 'item',
                  )
                  .toList(growable: false),
            ),
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
        ],
      ),
      6 => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ruleChoiceWidgets,
          // 显式法术选择（`optionType: "spell"`）由**法术池**承担（专用渲染器）；
          // 声明了显式法术选择时，法术步骤只由它们驱动（§3.10.3-3 声明与选择
          // 分离），不再同时显示"自由挑选"的全量列表。
          ...spellChoicePools,
          if (ruleChoiceGroups.isEmpty && spellChoicePools.isEmpty)
            _SpellChoiceSection(
              entries: spellEntries,
              selected: _selectedSpellRefs.toList(growable: false),
              onChanged: (next) =>
                  setState(() => _replaceSet(_selectedSpellRefs, next.toSet())),
              maximumCantrips: spellSelectionRules.maximumCantrips,
              maximumLeveledSpells: spellSelectionRules.maximumLeveledSpells,
              maximumSpellLevel: spellSelectionRules.maximumSpellLevel,
              automaticRulesConfigured: spellSelectionRules.configured,
              onOpenEntry: (entry) => _openEntry(entry),
            ),
          _CustomSpellSection(
            customSpells: _customSpells,
            onAddCustom: _addCustomSpell,
            onRemoveCustom: (index) =>
                setState(() => _customSpells.removeAt(index)),
          ),
        ],
      ),
      // 决策 D7：`builderStep: "details"` 也必须有渲染位置（示例包
      // `asi-or-feat` 就是这一类），否则选择区不可见却仍阻塞创建。
      7 => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ruleChoiceWidgets,
          _DetailsStep(
            name: _nameController.text,
            avatarBytes: _avatarBytes,
            isPickingAvatar: _pickingAvatar,
            avatarPickError: _avatarPickError,
            onPickAvatar: _pickAvatarImage,
            appearanceController: _appearanceController,
            personalityController: _personalityController,
            idealsController: _idealsController,
            bondsController: _bondsController,
            flawsController: _flawsController,
            backstoryController: _backstoryController,
            privateNotesController: _privateNotesController,
          ),
        ],
      ),
      8 => _BuilderReviewStep(
        summary: summary,
        review: review,
        abilityMethodLabel: _abilityMethodLabel(_abilityMethod),
        pendingRuleChoices: activeRuleChoices
            .where((active) => !_ruleChoiceIsComplete(active))
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
      '故事' => '头像、外貌、性格、牵绊与背景故事。',
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

  /// 向导内职业规则的**唯一**解析口径（M）：带包 priority（决策 D2）、条目自身的
  /// `structured.classRules` 与**跨包声明索引**（决策 D3），与
  /// `RulesDrivenCharacterBuilder`（向导落库路径）同源。本页的头部 HP 预览、
  /// 等级区生命骰、法术配额都必须走它，不得各自再调
  /// `Dnd5eRules.resolveClassRules`。
  ///
  /// 标准创建向导只在**新建**角色时出现（编辑老角色走完整表单），因此这里没有
  /// `data.ruleOverrides` 可带；`disabled` / `pinned` 为空是正确语义，不是遗漏。
  ResolvedClassRules _resolveClassRules(String? entryId) {
    final entry = _entryById(entryId);
    return Dnd5eRules.resolveClassRules(
      entryId: entry?.id,
      classSummary: entry?.name ?? _className,
      structured: entry?.structured ?? const <String, Object?>{},
      // 不带这份索引就看不见别的包对**同一 slug** 的勘误 / 补丁，预览会与
      // `RulesDrivenCharacterBuilder` 的落库结果不同（"向导显示 d8、落库变 d12"）。
      overrides: _ruleOverrides,
      entryPriority:
          widget.packagePriorities[RuleOverrideDeclaration.packageIdOf(
            entry?.id ?? '',
          )] ??
          0,
    );
  }

  /// 跨包职业规则声明索引（决策 D3）：**唯一的**构造点，按输入身份缓存——
  /// 每次 build 都重建会为每个条目重复 `ClassRuleSet.parse`。
  RuleOverrideIndex get _ruleOverrides {
    if (!identical(_ruleOverridesSource, widget.contentEntries) ||
        !identical(_ruleOverridesPriorities, widget.packagePriorities)) {
      _ruleOverridesSource = widget.contentEntries;
      _ruleOverridesPriorities = widget.packagePriorities;
      _ruleOverridesCache = RuleOverrideIndex.fromEntries(
        widget.contentEntries,
        widget.packagePriorities,
      );
    }
    return _ruleOverridesCache!;
  }

  List<ContentEntry>? _ruleOverridesSource;
  Map<String, int>? _ruleOverridesPriorities;
  RuleOverrideIndex? _ruleOverridesCache;

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
        final builderStep = ruleChoiceBuilderStep(
          definition.builderStep,
          inheritedStep: current.builderStep,
        );
        result.add(
          _ActiveRuleChoice(
            key: ruleUnitKey(entry.id, definition.id, null),
            sourceEntryId: entry.id,
            sourceName: entry.name,
            builderStep: builderStep,
            definition: definition,
          ),
        );
      }
      for (final progression in rules.progression) {
        // 一个步骤可覆盖多个等级（`levels`）：每个已达等级都是**独立**的生效单元
        // （§3.5 "同一批效果在多个等级重复生效"），选择也要每级各问一次；
        // 键必须带上等级，否则同一份选择会被折叠成一次、且与引擎判断不一致。
        final reachedLevels = progression.levels
            .where((level) => level <= _level)
            .toList(growable: false);
        for (final reachedLevel in reachedLevels) {
          for (final definition in progression.choices) {
            final builderStep = ruleChoiceBuilderStep(
              definition.builderStep,
              inheritedStep: current.builderStep,
            );
            result.add(
              _ActiveRuleChoice(
                key: ruleUnitKey(entry.id, definition.id, reachedLevel),
                sourceEntryId: entry.id,
                sourceName: entry.name,
                builderStep: builderStep,
                level: reachedLevel,
                definition: definition,
              ),
            );
          }
        }
      }
      for (final active in result.where(
        (choice) => choice.sourceEntryId == entry.id,
      )) {
        final selected = _ruleChoices[active.key] ?? const <String>[];
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

  void _openEntry(ContentEntry entry) {
    showContentEntryPreviewDialog(
      context,
      entry: entry,
      entries: widget.contentEntries,
    );
  }

  Future<void> _addCustomSpell() async {
    final result = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (dialogContext) => const _CustomSpellDialog(),
    );
    if (result != null && mounted) {
      setState(() => _customSpells.add(result));
    }
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
        (candidate) => candidate.renderStep == step,
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

  List<RuleChoiceCandidate> _candidatesFor(_ActiveRuleChoice active) {
    return RuleChoiceSemantics.candidatesFor(
      active.definition,
      entries: _entriesById,
      sourceEntryId: active.sourceEntryId,
    );
  }

  String _choiceSourceLabel(_ActiveRuleChoice active) {
    return active.level == null
        ? active.sourceName
        : '${active.sourceName} · 等级 ${active.level}';
  }

  Map<String, ContentEntry> get _entriesById => {
    for (final entry in widget.contentEntries) entry.id: entry,
  };

  RuleChoiceRequiresContext _requiresContextFor(_ActiveRuleChoice active) =>
      RuleChoiceRequiresContext(
        sourceEntryId: active.sourceEntryId,
        selectedByKey: _ruleChoices,
        abilities: _abilityScores,
        entries: _entriesById,
      );

  /// 选择级 `requires` 不满足时的原因文案；满足时为 `null`。判定与文案的唯一
  /// 实现点是 `ruleChoiceBlockedReason`（`RuleChoiceSemantics.requiresSatisfied`）。
  String? _blockedReasonFor(_ActiveRuleChoice active) => ruleChoiceBlockedReason(
    active.definition.requires,
    context: _requiresContextFor(active),
  );

  /// 一条选择是否**真的完成**：前置满足 + 数量在 `minimum`–`maximum` 之间。
  ///
  /// `ruleChoicesAreValid` / 摘要的 pending 计数 / 审核页清单共用它一处，
  /// 不得各自再写一套判断。
  bool _ruleChoiceIsComplete(_ActiveRuleChoice active) {
    final selected = _ruleChoices[active.key] ?? const <String>[];
    return _blockedReasonFor(active) == null &&
        selected.length >= active.definition.minimum &&
        selected.length <= active.definition.maximum;
  }

  void _applyRecommendedRuleChoices() {
    final resolver = RuleChoiceResolver(
      entries: {for (final entry in widget.contentEntries) entry.id: entry},
    );
    var changed = true;
    while (changed) {
      changed = false;
      for (final active in _activeRuleChoices()) {
        // `recommendedEntryIds` 只指向**条目**，而推荐值必须落在候选集里：
        // `recommendedFor` 已按候选过滤（技能选择没有条目候选时自然为空），
        // 因此不再需要"跳过专门 UI"的免检分支。
        if ((_ruleChoices[active.key] ?? const <String>[]).isNotEmpty) continue;
        final recommended = resolver.recommendedFor(
          active.definition,
          sourceEntryId: active.sourceEntryId,
        );
        if (recommended.isEmpty) continue;
        _ruleChoices[active.key] = recommended.toList(growable: false);
        changed = true;
      }
    }
  }

  /// 显式法术选择（`optionType: "spell"`）的法术池**专门渲染器**。
  ///
  /// 认领**只看 `optionType`**（[RuleChoiceDefinition.isSpellChoice]）与
  /// `renderStep`（= `dedicatedOptionStep`，家步骤由
  /// `RuleChoiceDefinition.dedicatedOptionSteps` 唯一决定：`spell` → 「法术」步骤
  /// 6），**不看声明里的 `builderStep`**（它只是提示）。
  ///
  /// 候选 = `RuleChoiceSemantics.candidatesFor`（枚举唯一实现点：`maximumOptionLevel`
  /// 与 `optionTags` 的过滤在 `RuleChoiceResolver.optionsFor`，与引擎
  /// `normalizeSelection` 同一份）**再经** `visibleRuleChoiceCandidates`（选项级
  /// `requires` 过滤的唯一实现点，与共享组件同源）：内联候选不再被丢弃，被隐藏
  /// 的已选值会列成"已选但未生效"。
  ///
  /// 上限 = `RuleChoiceQuota.effectiveMaximum`（`countsToward` 池的有效上限，
  /// 池数值只有 `RuleChoiceQuota.limitsFor` 一处来源）；上限为 0 时给出**可见原因**
  /// 而不是让 tile 可点却无反应（P2-12）。
  ///
  /// `group` 与三处选择面板**同一份**语义：[groupRuleChoiceSections] 归组、
  /// [RuleChoiceGroupedSections] 画标题（专用渲染器不再"只消费 help"）。
  List<Widget> _spellChoicePoolSections(
    List<_ActiveRuleChoice> activeRuleChoices,
  ) {
    final spellChoices = activeRuleChoices
        .where(
          (active) =>
              active.definition.isSpellChoice &&
              active.renderStep == _spellHomeStep,
        )
        .toList(growable: false);
    if (spellChoices.isEmpty) return const <Widget>[];
    final poolLimits = RuleChoiceQuota.limitsFor(
      // 校验路径也必须是**已解析**（带 disabled / pinned / 包 priority）的规则（M）：
      // 否则用户关闭某来源后，"还能选几个"仍按旧规则计算。
      rules: _resolveClassRules(_classEntryId),
      level: _level,
    );
    return [
      // `group` 的归组与标题**复用** [groupRuleChoiceSections] +
      // [RuleChoiceGroupedSections]（与三处选择面板同一份），专用渲染器不得另写
      // 分组循环或第二份标题样式——否则 `group` 在创建向导里"声明了却看不见"
      // （§3.10.3-7），两种渲染器与三处界面的呈现语义就分叉了。
      RuleChoiceGroupedSections(
        groups: groupRuleChoiceSections<_ActiveRuleChoice>(
          spellChoices,
          groupOf: (active) => active.definition.group,
          buildChoice: (active) {
            final selected = _ruleChoices[active.key] ?? const <String>[];
            final candidates = _candidatesFor(active);
            final visible = visibleRuleChoiceCandidates(
              candidates,
              _requiresContextFor(active),
            );
            final maximum = RuleChoiceQuota.effectiveMaximum(
              countsToward: active.definition.countsToward,
              maximum: active.definition.maximum,
              poolLimits: poolLimits,
              usedByOthers: _poolUsageByOthers(activeRuleChoices, active),
            );
            return _SpellChoiceSection(
              title: active.definition.label,
              hint: active.definition.help,
              blockedReason: _blockedReasonFor(active),
              // 池额度被同池选择占满（先声明先占）时也要有可见原因：否则候选 tile
              // 点得动却没反应（`_emit` 静默丢弃），用户看不到任何解释。
              capExhaustedReason: maximum == 0 && selected.isEmpty
                  ? '本选择的额度已被同一数量池中声明在前面的选择占满'
                        '（先声明先占）；请先取消同池的其它选择。'
                  : null,
              repeatable: active.definition.repeatable,
              entries: [
                for (final candidate in visible)
                  if (candidate.entry != null) candidate.entry!,
              ],
              inlineCandidates: [
                for (final candidate in visible)
                  if (candidate.entry == null) candidate,
              ],
              hiddenSelectedLabels: [
                for (final id in selected)
                  if (!visible.any((candidate) => candidate.id == id))
                    candidates
                            .where((candidate) => candidate.id == id)
                            .firstOrNull
                            ?.label ??
                        id,
              ],
              selected: selected,
              maximum: maximum,
              maximumSpellLevel: active.definition.maximumOptionLevel ?? 9,
              onChanged: (next) => setState(() {
                _ruleChoices[active.key] = next;
                _applyRecommendedRuleChoices();
              }),
              onOpenEntry: _openEntry,
            );
          },
        ),
      ),
    ];
  }

  /// 同一 `countsToward` 池里**其它**选择已占的数量（与引擎同一口径，决策 D8）。
  ///
  /// 引擎只累计"**声明在前**且 `requires` 已满足"的同池选择；界面必须用同一口径，
  /// 否则会把有效上限算小 → 出现"点得动却没反应、且没有原因"的 tile（P2-12）。
  /// 顺序按 `_activeRuleChoices()` 的声明顺序，只累计 [self] **之前**的选择。
  /// 最终判定仍以引擎为准（超额会进可见的 pending，不静默丢弃）。
  int _poolUsageByOthers(
    List<_ActiveRuleChoice> activeRuleChoices,
    _ActiveRuleChoice self,
  ) {
    final pool = self.definition.countsToward;
    if (pool == null) return 0;
    var used = 0;
    for (final active in activeRuleChoices) {
      if (active.key == self.key) break;
      if (active.definition.countsToward != pool) continue;
      if (_blockedReasonFor(active) != null) continue;
      used += (_ruleChoices[active.key] ?? const <String>[]).length;
    }
    return used;
  }

  /// 「熟练」步骤的专门渲染器（`optionType: "skill"` 的值类型选择）。
  ///
  /// 认领**只看 `optionType`**（[RuleChoiceDefinition.isSkillChoice]）与
  /// `renderStep`（家步骤由 `RuleChoiceDefinition.dedicatedOptionSteps` 唯一决定：
  /// `skill` → 「熟练」步骤 4），**不看声明里的 `builderStep`**（它只是提示）。
  /// 每条技能选择一组技能网格，候选与共享组件
  /// 同源（`RuleChoiceSemantics.candidatesFor` + 选项级 `requires` 过滤），选中值
  /// 写进 `_ruleChoices`。
  ///
  /// 三种"不能选"的原因都必须可见（不静默失败）：选择级 `requires` 不满足
  /// （[blockedReason]）、候选为空（[unavailableReason]）、已选值不在候选集里
  /// （未生效清单）。
  ///
  /// `group` 与三处选择面板**同一份**语义：[groupRuleChoiceSections] 归组、
  /// [RuleChoiceGroupedSections] 画标题（专用渲染器不再"只消费 help"）。
  ///
  /// 职业**没有**任何技能选择时保持既有行为：同一组件降级为"背景预设编辑"
  /// （全技能网格、写回 [_backgroundSkillProficiencies]）——这是历史 UX，不是
  /// 第二种"职业技能选择"实现（候选、交互、落库都由同一处承担）。
  List<Widget> _skillProficiencySections() {
    final skillChoices = _activeRuleChoices()
        .where(
          (active) =>
              active.definition.isSkillChoice &&
              active.renderStep == _skillHomeStep,
        )
        .toList(growable: false);
    if (skillChoices.isEmpty) {
      return [
        _SkillProficiencySection(
          selected: _backgroundSkillProficiencies.toList(growable: false),
          // 存在背景条目且它声明了技能熟练时，那两条是**背景的事实**（决策 D10）：
          // 传 `fixed` 让它们不可取消——旧实现允许点掉，但点掉也不会生效
          // （引擎仍按条目授予），是个静默 no-op 的控件。要改就改背景条目本身。
          fixed: _backgroundSkillProficiencies,
          onChanged: (next) =>
              setState(() => _backgroundSkillProficiencies = next.toSet()),
        ),
      ];
    }
    return [
      // 与法术池同理：`group` 的归组与标题复用共享组件，专用渲染器不再"只消费
      // help、丢掉 group"。
      RuleChoiceGroupedSections(
        groups: groupRuleChoiceSections<_ActiveRuleChoice>(
          skillChoices,
          groupOf: (active) => active.definition.group,
          buildChoice: (active) {
            final candidates = visibleRuleChoiceCandidates(
              _candidatesFor(active),
              _requiresContextFor(active),
            );
            final optionNames = {
              for (final candidate in candidates) candidate.label,
            };
            final selected = _ruleChoices[active.key] ?? const <String>[];
            return _SkillProficiencySection(
              title: active.definition.label,
              hint: active.definition.help,
              blockedReason: _blockedReasonFor(active),
              unavailableReason: candidates.isEmpty
                  ? '资料库中缺少 skill 选项：该选择既没有内联 options，也没有匹配的条目。'
                  : null,
              unavailableSelected: [
                for (final skill in selected)
                  if (!optionNames.contains(skill)) skill,
              ],
              selected: selected,
              options: [
                for (final candidate in candidates) candidate.label,
              ],
              minimum: active.definition.minimum,
              maximum: active.definition.maximum,
              repeatable: active.definition.repeatable,
              fixed: _backgroundSkillProficiencies,
              onChanged: (next) => setState(() {
                _ruleChoices[active.key] = next;
                _applyRecommendedRuleChoices();
              }),
            );
          },
        ),
      ),
    ];
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

  /// 推荐属性预设：**按条目身份 / 档案 slug 取键**
  /// （[QuickBuildService.editorAbilityPresetFor]），不再写死中文职业名。
  Map<String, int> _presetAbilitiesForClass(String className) =>
      QuickBuildService.editorAbilityPresetFor(
        classEntryId: _entryIdFor('class', className),
        className: className,
      );

  void _resetAbilityScoresForClass(String className) {
    final scores = _abilityMethod == AbilityScoreMethod.rolled
        ? AbilityScoreGenerator.assignByPriority(
            scores: _abilityScores.values.toList(growable: false),
            priorities: _abilityPrioritiesForClass(className),
          )
        : _presetAbilitiesForClass(className);
    _setAbilityScores(scores);
  }

  /// 背景技能来自**背景条目自己的 rules**（决策 D10，唯一读取口径在
  /// `backgroundSkillProficiencies`）。条目没声明就是"没有技能熟练"——
  /// 旧的"按背景中文名硬编码 + 未知背景发士兵技能"是猜测，已删除。
  Set<String> _backgroundSkillsFor(String? backgroundEntryId) =>
      backgroundSkillProficiencies(
        entries: widget.contentEntries,
        backgroundEntryId: backgroundEntryId,
      );
}
