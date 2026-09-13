// character_detail_page.dart 的 part：特性、参考资料与档案页签。
part of 'character_detail_page.dart';

class _FeaturesPanel extends StatelessWidget {
  const _FeaturesPanel({
    required this.character,
    required this.contentEntries,
    this.onSaveCharacter,
  });

  final CharacterSheet character;
  final List<ContentEntry> contentEntries;
  final CharacterSaveCallback? onSaveCharacter;
  static const _quickEditService = CharacterQuickEditService();

  @override
  Widget build(BuildContext context) {
    final overrides = CharacterManualOverrides.fromCharacter(character);
    final resolved = CharacterOverrideResolver.resolve(character);
    final allGrants = _objectMaps(
      character.dataMap['resolvedGrants'],
    ).where((grant) => grant['kind'] == 'feature').toList(growable: false);
    final visibleGrants = allGrants
        .where(
          (grant) => !overrides.hiddenGrantKeys.contains(
            CharacterOverrideResolver.grantKey(grant),
          ),
        )
        .toList(growable: false);
    final hiddenGrants = allGrants
        .where(
          (grant) => overrides.hiddenGrantKeys.contains(
            CharacterOverrideResolver.grantKey(grant),
          ),
        )
        .toList(growable: false);
    final grantedEntryIds = allGrants
        .map((grant) => grant['entryId'])
        .whereType<String>()
        .toSet();
    final selectedFeatureEntryIds = resolved.featureEntryIds
        .where(
          (entryId) =>
              !grantedEntryIds.contains(entryId) &&
              !overrides.addedFeatureEntryIds.contains(entryId),
        )
        .toList(growable: false);
    if (visibleGrants.isEmpty &&
        resolved.featureEntryIds.isEmpty &&
        resolved.customFeatures.isEmpty &&
        onSaveCharacter == null) {
      return const _EmptyPanel(title: '暂无已获得特性');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onSaveCharacter != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _addLibraryFeature(context),
                  icon: const Icon(Icons.add),
                  label: const Text('从资料库添加'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _addCustomFeature(context),
                  icon: const Icon(Icons.edit_note_outlined),
                  label: const Text('自定义特性'),
                ),
              ],
            ),
          ),
        if (visibleGrants.isNotEmpty)
          _Section(
            title: '自动获得的特性',
            icon: Icons.auto_awesome_outlined,
            child: Column(
              children: [
                for (final grant in visibleGrants)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.auto_awesome_outlined),
                    title: Text('${grant['label'] ?? grant['id'] ?? '职业特性'}'),
                    subtitle: Text(_grantSource(grant)),
                    onTap: grant['entryId'] is String
                        ? () => _openEntry(context, grant['entryId'] as String)
                        : null,
                    trailing: onSaveCharacter == null
                        ? null
                        : IconButton(
                            tooltip: '在角色卡中隐藏',
                            onPressed: () => _setGrantHidden(grant, true),
                            icon: const Icon(Icons.visibility_off_outlined),
                          ),
                  ),
              ],
            ),
          ),
        if (selectedFeatureEntryIds.isNotEmpty)
          _Section(
            title: '选择获得',
            icon: Icons.task_alt_outlined,
            child: Column(
              children: [
                for (final entryId in selectedFeatureEntryIds)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.check_circle_outline),
                    title: Text(_entryName(entryId)),
                    onTap: () => _openEntry(context, entryId),
                  ),
              ],
            ),
          ),
        if (overrides.addedFeatureEntryIds.isNotEmpty ||
            resolved.customFeatures.isNotEmpty)
          _Section(
            title: '手动添加',
            icon: Icons.menu_book_outlined,
            child: Column(
              children: [
                for (final entryId in overrides.addedFeatureEntryIds)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.link_outlined),
                    title: Text(_entryName(entryId)),
                    onTap: () => _openEntry(context, entryId),
                    trailing: onSaveCharacter == null
                        ? null
                        : IconButton(
                            tooltip: '删除',
                            onPressed: () => _removeAddedFeature(entryId),
                            icon: const Icon(Icons.delete_outline),
                          ),
                  ),
                for (final feature in resolved.customFeatures)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.edit_note_outlined),
                    title: Text('${feature['name'] ?? '自定义特性'}'),
                    subtitle: '${feature['description'] ?? ''}'.isEmpty
                        ? null
                        : Text('${feature['description']}'),
                    trailing: onSaveCharacter == null
                        ? null
                        : IconButton(
                            tooltip: '删除',
                            onPressed: () =>
                                _removeCustomFeature('${feature['id'] ?? ''}'),
                            icon: const Icon(Icons.delete_outline),
                          ),
                  ),
              ],
            ),
          ),
        if (hiddenGrants.isNotEmpty)
          _Section(
            title: '已隐藏',
            icon: Icons.visibility_off_outlined,
            child: Column(
              children: [
                for (final grant in hiddenGrants)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('${grant['label'] ?? grant['id'] ?? '职业特性'}'),
                    trailing: IconButton(
                      tooltip: '恢复显示',
                      onPressed: () => _setGrantHidden(grant, false),
                      icon: const Icon(Icons.visibility_outlined),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  String _entryName(String entryId) {
    for (final entry in contentEntries) {
      if (entry.id == entryId) return entry.name;
    }
    return entryId;
  }

  void _openEntry(BuildContext context, String entryId) {
    final entry = contentEntries
        .where((candidate) => candidate.id == entryId)
        .firstOrNull;
    if (entry == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前资料库中找不到这条特性')));
      return;
    }
    showContentEntryPreviewDialog(
      context,
      entry: entry,
      entries: contentEntries,
    );
  }

  Future<void> _addLibraryFeature(BuildContext context) async {
    final entry = await _pickContentEntry(
      context,
      title: '添加特性',
      entries: contentEntries
          .where(
            (entry) => const <String>{
              'classFeature',
              'feature',
              'feat',
            }.contains(entry.type),
          )
          .toList(growable: false),
    );
    if (entry == null) return;
    await onSaveCharacter?.call(
      _quickEditService.addFeature(character, entry.id),
    );
  }

  Future<void> _addCustomFeature(BuildContext context) async {
    final value = await _showNameDescriptionDialog(context, title: '自定义特性');
    if (value == null) return;
    await onSaveCharacter?.call(
      _quickEditService.addCustomFeature(
        character,
        name: value.$1,
        description: value.$2,
      ),
    );
  }

  Future<void> _setGrantHidden(Map<String, Object?> grant, bool hidden) async {
    await onSaveCharacter?.call(
      _quickEditService.setGrantHidden(
        character,
        CharacterOverrideResolver.grantKey(grant),
        hidden,
      ),
    );
  }

  Future<void> _removeAddedFeature(String entryId) async {
    await onSaveCharacter?.call(
      _quickEditService.removeAddedFeature(character, entryId),
    );
  }

  Future<void> _removeCustomFeature(String id) async {
    await onSaveCharacter?.call(
      _quickEditService.removeCustomFeature(character, id),
    );
  }

  String _grantSource(Map<String, Object?> grant) {
    final source =
        '${grant['sourceEntryName'] ?? grant['sourceEntryId'] ?? '未知来源'}';
    final level = grant['sourceLevel'];
    return level == null ? source : '$source · $level 级获得';
  }
}

class _CharacterReferencePanel extends StatelessWidget {
  const _CharacterReferencePanel({required this.character});

  final CharacterSheet character;

  @override
  Widget build(BuildContext context) {
    final characterProfile = character.characterMap;
    final sections = character.markdownSections;
    final challengeRating = '${characterProfile['challengeRating'] ?? ''}'
        .trim();
    final proficiencyBonus = characterProfile['proficiencyBonus'];
    final metadata = <String>[
      if (challengeRating.isNotEmpty) 'CR $challengeRating',
      if (proficiencyBonus != null) '熟练加值 +$proficiencyBonus',
      if ('${characterProfile['size'] ?? ''}'.trim().isNotEmpty)
        '${characterProfile['size']}',
      if ('${characterProfile['creatureType'] ?? ''}'.trim().isNotEmpty)
        '${characterProfile['creatureType']}',
      if ('${characterProfile['alignment'] ?? ''}'.trim().isNotEmpty)
        '${characterProfile['alignment']}',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('怪物资料', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final value in metadata) Chip(label: Text(value))],
        ),
        if ('${characterProfile['hitPointFormula'] ?? ''}'
            .trim()
            .isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            '生命骰 ${characterProfile['hitPointFormula']}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        if (character.description.isNotEmpty)
          _Section(
            title: '描述',
            icon: Icons.description_outlined,
            child: SelectableText(character.description),
          ),
        for (final entry in sections.entries)
          _Section(
            title: entry.key,
            icon: _characterSectionIcon(entry.key),
            child: SelectableText(
              '${entry.value}'.trim(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        if (sections.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text('暂无特质或动作说明；可从编辑角色补充。'),
          ),
      ],
    );
  }
}

IconData _characterSectionIcon(String title) {
  return switch (title) {
    '动作' || '附赠动作' || '反应' || '传奇动作' => Icons.bolt_outlined,
    '特质' => Icons.workspace_premium_outlined,
    '感官与语言' => Icons.visibility_outlined,
    _ => Icons.notes_outlined,
  };
}

class _ProfilePanel extends StatefulWidget {
  const _ProfilePanel({
    required this.character,
    this.onSaveCharacter,
    this.sources = const <String, RuleFieldSource>{},
    this.originLabels = const <String, String>{},
    this.entryOriginId,
    this.disabledOriginIds = const <String>{},
    this.resourceNames = const <String, String>{},
    this.recordedChoices = const <RecordedRuleChoice>[],
    this.onDisableOverride,
    this.onEnableOverride,
  });

  final CharacterSheet character;
  final CharacterSaveCallback? onSaveCharacter;

  /// 列级来源快照（`data.classRuleSources`，任务 9 的集中管理面）。
  final Map<String, RuleFieldSource> sources;
  final Map<String, String> originLabels;

  /// 角色自身条目的 originId（不是覆盖，C）与被关闭的来源（恢复入口，C）。
  final String? entryOriginId;
  final Set<String> disabledOriginIds;

  /// 资源 id → 资源展示名（K）。
  final Map<String, String> resourceNames;

  /// `data['choices']` 的读取结果（唯一读取方 `recordedRuleChoices`）。
  final List<RecordedRuleChoice> recordedChoices;

  final Future<void> Function(String originId)? onDisableOverride;
  final Future<void> Function(String originId)? onEnableOverride;

  @override
  State<_ProfilePanel> createState() => _ProfilePanelState();
}

class _ProfilePanelState extends State<_ProfilePanel> {
  static const _service = CharacterQuickEditService();
  final _controllers = <String, TextEditingController>{};
  Timer? _saveTimer;
  bool _saving = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _load(widget.character);
  }

  @override
  void didUpdateWidget(covariant _ProfilePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.character != widget.character && !_saving) {
      _load(widget.character);
    }
  }

  void _load(CharacterSheet character) {
    final profile = CharacterProfile.fromCharacter(character);
    final values = <String, String>{
      'alignment': profile.alignment,
      'appearance': profile.appearance,
      'personalityTraits': profile.personalityTraits,
      'ideals': profile.ideals,
      'bonds': profile.bonds,
      'flaws': profile.flaws,
      'backstory': profile.backstory,
      'languages': profile.languages.join('、'),
      'privateNotes': profile.privateNotes,
    };
    for (final entry in values.entries) {
      (_controllers[entry.key] ??= TextEditingController()).text = entry.value;
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onSaveCharacter != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '角色资料',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (_saving)
              const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (_saved)
              const Icon(Icons.cloud_done_outlined, size: 20),
          ],
        ),
        const SizedBox(height: 16),
        _profileField('alignment', '阵营', enabled: enabled),
        _profileField('appearance', '外貌', enabled: enabled, lines: 2),
        _profileField('personalityTraits', '个性特征', enabled: enabled, lines: 2),
        _profileField('ideals', '理想', enabled: enabled, lines: 2),
        _profileField('bonds', '牵绊', enabled: enabled, lines: 2),
        _profileField('flaws', '缺点', enabled: enabled, lines: 2),
        _profileField('languages', '语言', enabled: enabled),
        _profileField('backstory', '背景故事', enabled: enabled, lines: 6),
        _profileField('privateNotes', '私人笔记', enabled: enabled, lines: 5),
        const SizedBox(height: 8),
        // 规则来源的集中管理面：每一列取自哪里、可逐条关闭覆盖并恢复（任务 9）。
        RuleSourceListCard(
          sources: widget.sources,
          originLabels: widget.originLabels,
          entryOriginId: widget.entryOriginId,
          disabledOriginIds: widget.disabledOriginIds,
          resourceNames: widget.resourceNames,
          onDisableOverride: widget.onDisableOverride,
          onEnableOverride: widget.onEnableOverride,
        ),
        const SizedBox(height: 12),
        RuleChoiceListCard(choices: widget.recordedChoices),
        if (!enabled) const Text('当前角色为只读；从本地角色列表打开后可直接编辑。'),
      ],
    );
  }

  Widget _profileField(
    String key,
    String label, {
    required bool enabled,
    int lines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        key: Key('character-profile-$key'),
        controller: _controllers[key],
        enabled: enabled,
        minLines: lines,
        maxLines: lines,
        decoration: InputDecoration(
          labelText: label,
          alignLabelWithHint: lines > 1,
        ),
        onChanged: (_) => _scheduleSave(),
      ),
    );
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    if (_saved) setState(() => _saved = false);
    _saveTimer = Timer(const Duration(milliseconds: 600), _save);
  }

  Future<void> _save() async {
    final callback = widget.onSaveCharacter;
    if (callback == null || _saving) return;
    setState(() => _saving = true);
    final profile = CharacterProfile(
      alignment: _controllers['alignment']!.text.trim(),
      appearance: _controllers['appearance']!.text.trim(),
      personalityTraits: _controllers['personalityTraits']!.text.trim(),
      ideals: _controllers['ideals']!.text.trim(),
      bonds: _controllers['bonds']!.text.trim(),
      flaws: _controllers['flaws']!.text.trim(),
      backstory: _controllers['backstory']!.text.trim(),
      languages: _controllers['languages']!.text
          .split(RegExp(r'[,，、]'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      privateNotes: _controllers['privateNotes']!.text.trim(),
    );
    final success = await callback(
      _service.updateProfile(widget.character, profile),
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saved = success;
    });
  }
}
