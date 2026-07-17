import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../app_preferences/presentation/app_preferences_controller.dart';
import '../../campaigns/presentation/actors/campaign_actor_controller.dart';
import '../../campaigns/presentation/actors/publish_character_sheet.dart';
import '../../campaigns/presentation/campaign_controller.dart';
import '../../client_mode/domain/client_mode.dart';
import '../../content/data/local/content_repository.dart';
import '../../content/domain/content_entry.dart';
import '../domain/character.dart';
import '../domain/character_rule_projector.dart';
import '../domain/dnd5e_rules.dart';
import 'character_detail_page.dart';
import 'character_controller.dart';
import 'character_editor_page.dart';
import 'character_upgrade_page.dart';

class CharactersTabPage extends StatefulWidget {
  const CharactersTabPage({
    required this.controller,
    this.campaignController,
    this.contentRepository,
    this.localContentRepository,
    this.onCampaignContentSelected,
    this.appPreferencesController,
    this.modeController,
    this.actorController,
    super.key,
  });

  final CharacterController controller;
  final CampaignController? campaignController;
  final ContentRepository? contentRepository;
  final ContentRepository? localContentRepository;
  final Future<void> Function(String campaignId)? onCampaignContentSelected;
  final AppPreferencesController? appPreferencesController;
  final ClientModeController? modeController;
  final CampaignActorController? actorController;

  @override
  State<CharactersTabPage> createState() => _CharactersTabPageState();
}

class _CharactersTabPageState extends State<CharactersTabPage> {
  @override
  void initState() {
    super.initState();
    widget.modeController?.addListener(_onModeChanged);
    widget.actorController?.addListener(_onActorChanged);
  }

  @override
  void didUpdateWidget(covariant CharactersTabPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.modeController != widget.modeController) {
      oldWidget.modeController?.removeListener(_onModeChanged);
      widget.modeController?.addListener(_onModeChanged);
    }
    if (oldWidget.actorController != widget.actorController) {
      oldWidget.actorController?.removeListener(_onActorChanged);
      widget.actorController?.addListener(_onActorChanged);
    }
  }

  @override
  void dispose() {
    widget.modeController?.removeListener(_onModeChanged);
    widget.actorController?.removeListener(_onActorChanged);
    super.dispose();
  }

  void _onModeChanged() {
    if (mounted) setState(() {});
  }

  void _onActorChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.controller,
        widget.campaignController,
        widget.appPreferencesController,
      ]),
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('角色')),
          floatingActionButton: FloatingActionButton.extended(
            key: const Key('create_character'),
            heroTag: 'create_character',
            onPressed: _isDmModeWithCampaign ? _showDmCreateMenu : _openCreatePage,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('新角色'),
          ),
          body: KeyedSubtree(
            key: const Key('player-local-characters'),
            child: _buildCharacterList(context),
          ),
        );
      },
    );
  }

  Widget _buildCharacterList(BuildContext context) {
    if (widget.controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.controller.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            widget.controller.error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final characters = widget.controller.characters;
    if (characters.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('还没有角色\n点击右下角创建第一张角色卡', textAlign: TextAlign.center),
        ),
      );
    }

    final list = ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
      itemCount: characters.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final character = characters[index];
        return _CharacterCard(
          character: character,
          canPublish: widget.actorController != null,
          onOpen: () => _openDetailPage(character),
          onEdit: () => _openEditPage(character),
          onContentRefs: () => _showContentRefsDialog(character),
          onPublish: widget.actorController == null
              ? null
              : () => _showPublishSheet(character),
          onHpDelta: (delta) => _adjustHp(character, delta),
          onUpgrade: character.level >= 20
              ? null
              : () => _openUpgradePage(character),
        );
      },
    );
    return list;
  }

  /// Spec §DM 角色生命周期: DM 模式下角色栏 FAB 弹出菜单, 提供:
  /// 1. 快速创建 NPC (常驻, name + HP + type)
  /// 2. 快速创建一次性角色 (临时, name only)
  /// 3. 完整创建角色 (existing full character editor)
  /// 仅当 DM 模式且已选中战役时启用。
  bool get _isDmModeWithCampaign {
    final isDm = widget.modeController?.mode == ClientMode.dungeonMaster;
    final campaignId = widget.actorController?.selectedCampaignId;
    return isDm && campaignId != null && campaignId.isNotEmpty;
  }

  Future<void> _showDmCreateMenu() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('创建角色'),
        children: [
          SimpleDialogOption(
            key: const Key('dm-create-quick-npc'),
            onPressed: () => Navigator.of(context).pop('quickNpc'),
            child: const ListTile(
              leading: Icon(Icons.smart_toy_outlined),
              title: Text('快速创建 NPC'),
              subtitle: Text('输入名称和 HP，创建常驻 NPC/怪物/同伴'),
            ),
          ),
          SimpleDialogOption(
            key: const Key('dm-create-quick-temporary'),
            onPressed: () => Navigator.of(context).pop('quickTemporary'),
            child: const ListTile(
              leading: Icon(Icons.flash_on_outlined),
              title: Text('快速创建一次性角色'),
              subtitle: Text('只输入名称，创建临时角色'),
            ),
          ),
          SimpleDialogOption(
            key: const Key('dm-create-full'),
            onPressed: () => Navigator.of(context).pop('full'),
            child: const ListTile(
              leading: Icon(Icons.edit_note),
              title: Text('完整创建角色'),
              subtitle: Text('打开完整角色编辑器'),
            ),
          ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    switch (selected) {
      case 'quickNpc':
        await _showQuickNpcForm();
      case 'quickTemporary':
        await _showQuickTemporaryForm();
      case 'full':
        await _openCreatePage();
    }
  }

  Future<void> _showQuickNpcForm() async {
    final actorController = widget.actorController;
    if (actorController == null) return;

    final nameController = TextEditingController();
    final hpController = TextEditingController();
    var actorType = 'npc';
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('快速创建 NPC'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ChoiceChip(
                        label: const Text('NPC'),
                        selected: actorType == 'npc',
                        onSelected: (_) =>
                            setDialogState(() => actorType = 'npc'),
                      ),
                      ChoiceChip(
                        label: const Text('怪物'),
                        selected: actorType == 'monster',
                        onSelected: (_) =>
                            setDialogState(() => actorType = 'monster'),
                      ),
                      ChoiceChip(
                        label: const Text('同伴'),
                        selected: actorType == 'companion',
                        onSelected: (_) =>
                            setDialogState(() => actorType = 'companion'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('quick-npc-name'),
                    controller: nameController,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: '显示名称'),
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? '请输入名称' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    key: const Key('quick-npc-hp'),
                    controller: hpController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '初始最大 HP（可选）'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              key: const Key('quick-npc-confirm'),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop(true);
                }
              },
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) {
      nameController.dispose();
      hpController.dispose();
      return;
    }
    if (!mounted) {
      nameController.dispose();
      hpController.dispose();
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final maxHpText = hpController.text.trim();
    final maxHp = maxHpText.isEmpty ? null : int.tryParse(maxHpText);
    final success = await actorController.createDmActor(
      actorType: actorType,
      lifecycle: 'persistent',
      sheet: {
        'name': nameController.text.trim(),
        'maxHp': ?maxHp,
        'currentHp': ?maxHp,
      },
    );
    nameController.dispose();
    hpController.dispose();
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          success ? '已创建常驻 NPC' : (actorController.error ?? '创建失败'),
        ),
      ),
    );
  }

  Future<void> _showQuickTemporaryForm() async {
    final actorController = widget.actorController;
    if (actorController == null) return;

    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('快速创建一次性角色'),
        content: Form(
          key: formKey,
          child: TextFormField(
            key: const Key('quick-temporary-name'),
            controller: nameController,
            autofocus: true,
            decoration: const InputDecoration(labelText: '显示名称'),
            validator: (value) =>
                value == null || value.trim().isEmpty ? '请输入名称' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('quick-temporary-confirm'),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      nameController.dispose();
      return;
    }
    if (!mounted) {
      nameController.dispose();
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final success = await actorController.createTemporaryNpc(
      name: nameController.text.trim(),
    );
    nameController.dispose();
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          success ? '已创建临时角色' : (actorController.error ?? '创建失败'),
        ),
      ),
    );
  }

  Future<void> _openCreatePage() async {
    final messenger = ScaffoldMessenger.of(context);
    widget.controller.takeLastCreatedCharacter();
    final campaignId = await _selectCampaignContentSource();
    if (!mounted) return;
    final repository = campaignId == null
        ? (widget.localContentRepository ?? widget.contentRepository)
        : widget.contentRepository;
    List<ContentEntry> contentEntries = const [];
    if (repository != null) {
      if (campaignId != null) {
        await widget.onCampaignContentSelected?.call(campaignId);
      }
      if (!mounted) return;
      contentEntries = await repository.search(const ContentQuery());
    }
    if (!mounted) return;
    final defaultCreationMethod =
        widget.appPreferencesController?.preferences.defaultCreationMethod ??
        'fullSheet';
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => CharacterEditorPage(
          defaultCreationMethod: defaultCreationMethod,
          contentEntries: contentEntries,
          onPickImage: _pickAvatarImage,
          onSubmit: (draft) async {
            final success = await widget.controller.createCharacter(draft);
            if (mounted) {
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? '角色已创建'
                        : (widget.controller.error ?? '创建失败'),
                  ),
                ),
              );
            }
            return success;
          },
        ),
      ),
    );
  }

  Future<String?> _selectCampaignContentSource() async {
    final campaigns = widget.campaignController?.campaigns ?? const [];
    if (campaigns.isEmpty) return null;
    var selectedId = campaigns.first.id;
    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('选择创建资料'),
          content: DropdownMenu<String>(
            initialSelection: selectedId,
            label: const Text('战役资料库'),
            dropdownMenuEntries: [
              for (final campaign in campaigns)
                DropdownMenuEntry(value: campaign.id, label: campaign.name),
            ],
            onSelected: (value) {
              if (value != null) setDialogState(() => selectedId = value);
            },
          ),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop(''),
              icon: const Icon(Icons.public),
              label: const Text('使用通用资料'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(selectedId),
              child: const Text('继续'),
            ),
          ],
        ),
      ),
    ).then((value) => value?.isEmpty ?? true ? null : value);
  }

  Future<void> _openDetailPage(CharacterSheet character) async {
    final repository =
        widget.contentRepository ?? widget.localContentRepository;
    final contentEntries = repository == null
        ? const <ContentEntry>[]
        : await repository.search(const ContentQuery());
    if (!mounted) return;
    final projectedCharacter = CharacterRuleProjector(
      entries: {for (final entry in contentEntries) entry.id: entry},
    ).project(character);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => CharacterDetailPage(
          character: projectedCharacter,
          contentEntries: contentEntries,
          onSaveCharacter: widget.controller.updateCharacter,
          onUpgrade: projectedCharacter.level >= 20
              ? null
              : () => _openUpgradePage(projectedCharacter, contentEntries),
          initialTab:
              widget
                  .appPreferencesController
                  ?.preferences
                  .defaultCharacterTab ??
              'overview',
          onUpdateRuntime:
              ({
                int? currentHp,
                int? temporaryHp,
                bool? inspiration,
                List<String>? conditions,
                int? deathSaveSuccesses,
                int? deathSaveFailures,
                Map<String, int>? spellSlotsUsed,
                Map<String, int>? classResourcesUsed,
              }) async {
                if (currentHp != null) {
                  await widget.controller.updateCharacter(
                    character.copyWith(currentHp: currentHp),
                  );
                }
                if (temporaryHp != null ||
                    inspiration != null ||
                    conditions != null ||
                    deathSaveSuccesses != null ||
                    deathSaveFailures != null ||
                    spellSlotsUsed != null ||
                    classResourcesUsed != null) {
                  await widget.controller.updateRuntimeState(
                    characterId: character.id,
                    temporaryHp: temporaryHp,
                    inspiration: inspiration,
                    conditions: conditions,
                    deathSaveSuccesses: deathSaveSuccesses,
                    deathSaveFailures: deathSaveFailures,
                    spellSlotsUsed: spellSlotsUsed,
                    classResourcesUsed: classResourcesUsed,
                  );
                }
              },
          onUpdateInventory:
              ({
                List<Map<String, Object>>? inventory,
                Map<String, int>? currency,
              }) {
                return widget.controller.updateInventoryAndCurrency(
                  characterId: character.id,
                  inventory: inventory,
                  currency: currency,
                );
              },
          onEdit: () {
            Navigator.of(context).pop();
            _openEditPage(character);
          },
        ),
      ),
    );
  }

  Future<void> _openEditPage(CharacterSheet character) async {
    final messenger = ScaffoldMessenger.of(context);
    final repository =
        widget.contentRepository ?? widget.localContentRepository;
    final contentEntries = repository == null
        ? const <ContentEntry>[]
        : await repository.search(const ContentQuery());
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => CharacterEditorPage(
          initialCharacter: character,
          contentEntries: contentEntries,
          onPickImage: _pickAvatarImage,
          onSubmit: (draft) async {
            final updated = character.copyWith(
              name: draft.name,
              avatarUrl: draft.avatarUrl,
              level: draft.level,
              classSummary:
                  emptyToNull(draft.classSummary) ?? character.classSummary,
              raceSummary:
                  emptyToNull(draft.raceSummary) ?? character.raceSummary,
              currentHp: draft.currentHp,
              maxHp: draft.maxHp,
              armorClass: draft.armorClass,
              speed: draft.speed,
              initiativeBonus: draft.initiativeBonus,
              abilities: draft.abilities,
              saves: draft.saves,
              skills: draft.skills,
              inventory: draft.inventory,
              currency: draft.currency,
              notes: draft.notes,
              data: draft.data,
            );
            final success = await widget.controller.updateCharacter(updated);
            if (mounted) {
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? '角色已保存'
                        : (widget.controller.error ?? '保存失败'),
                  ),
                ),
              );
            }
            return success;
          },
        ),
      ),
    );
  }

  Future<CharacterSheet?> _openUpgradePage(
    CharacterSheet character, [
    List<ContentEntry>? loadedEntries,
  ]) async {
    final repository =
        widget.contentRepository ?? widget.localContentRepository;
    final contentEntries =
        loadedEntries ??
        (repository == null
            ? const <ContentEntry>[]
            : await repository.search(const ContentQuery()));
    if (!mounted) return null;
    return Navigator.of(context).push<CharacterSheet>(
      MaterialPageRoute<CharacterSheet>(
        builder: (context) => CharacterUpgradePage(
          character: character,
          contentEntries: contentEntries,
          onApply: widget.controller.updateCharacter,
        ),
      ),
    );
  }

  Future<void> _showContentRefsDialog(CharacterSheet character) async {
    final refs = _contentRefsFromCharacter(character);
    final spellsController = TextEditingController(
      text: refs.spells.join(', '),
    );
    final itemsController = TextEditingController(text: refs.items.join(', '));
    final featuresController = TextEditingController(
      text: refs.features.join(', '),
    );
    final messenger = ScaffoldMessenger.of(context);

    final result = await showDialog<_ContentRefs>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('内容引用'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: spellsController,
                decoration: const InputDecoration(labelText: '法术 ID'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: itemsController,
                decoration: const InputDecoration(labelText: '装备/物品 ID'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: featuresController,
                decoration: const InputDecoration(labelText: '特性/专长 ID'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(
                _ContentRefs(
                  spells: _splitRefs(spellsController.text),
                  items: _splitRefs(itemsController.text),
                  features: _splitRefs(featuresController.text),
                ),
              ),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (result == null) return;

    final success = await widget.controller.updateContentRefs(
      characterId: character.id,
      spells: result.spells,
      items: result.items,
      features: result.features,
    );
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(success ? '内容引用已保存' : '保存失败')),
    );
  }

  Future<void> _showPublishSheet(CharacterSheet character) async {
    final actorController = widget.actorController;
    if (actorController == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => PublishCharacterSheet(
        controller: actorController,
        character: character,
      ),
    );
  }

  Future<({Uint8List bytes, String mimeType})?> _pickAvatarImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
      withData: true,
    );
    final file = result?.files.singleOrNull;
    final bytes = file?.bytes;
    if (bytes == null || bytes.isEmpty) return null;
    final extension = (file?.extension ?? 'png').toLowerCase();
    final mimeType = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      _ => 'image/png',
    };
    return (bytes: bytes, mimeType: mimeType);
  }

  Future<void> _adjustHp(CharacterSheet character, int delta) async {
    final success = await widget.controller.updateCharacter(
      character.copyWith(currentHp: character.currentHp + delta),
    );
    if (!mounted || success) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('HP 调整失败')));
  }
}

class _CharacterCard extends StatefulWidget {
  const _CharacterCard({
    required this.character,
    required this.canPublish,
    required this.onOpen,
    required this.onEdit,
    required this.onContentRefs,
    required this.onHpDelta,
    this.onUpgrade,
    this.onPublish,
  });

  final CharacterSheet character;
  final bool canPublish;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onContentRefs;
  final VoidCallback? onPublish;
  final ValueChanged<int> onHpDelta;
  final VoidCallback? onUpgrade;

  @override
  State<_CharacterCard> createState() => _CharacterCardState();
}

class _CharacterCardState extends State<_CharacterCard> {
  bool _expanded = false;

  Future<void> _showHpAdjustmentDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _HpAdjustmentDialog(onAdjust: widget.onHpDelta),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (widget.character.raceSummary.isNotEmpty) widget.character.raceSummary,
      if (widget.character.classSummary.isNotEmpty)
        widget.character.classSummary,
      'Lv.${widget.character.level}',
    ].join(' / ');

    final perceptionBonus = Dnd5eRules.skillBonus(
      skillName: '察觉',
      abilities: widget.character.abilityMap,
      level: widget.character.level,
      proficient: widget.character.skillMap['察觉'] == true,
    );
    final primaryResource = widget.character.classResources.firstOrNull;

    return Card.outlined(
      key: Key('character-card-${widget.character.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            onTap: widget.onOpen,
            leading: CircleAvatar(
              backgroundImage: _avatarImage(widget.character.avatarUrl),
              child: widget.character.avatarUrl == null ||
                      widget.character.avatarUrl!.isEmpty
                  ? Text(widget.character.name.characters.first.toUpperCase())
                  : null,
            ),
            title: Text(widget.character.name),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(subtitle),
            ),
            trailing: IconButton(
              key: Key('character-expand-${widget.character.id}'),
              tooltip: _expanded ? '收起角色摘要' : '展开角色摘要',
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(
                _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(),
                        const SizedBox(height: 8),
                        LayoutBuilder(
                          builder: (context, constraints) => GridView.count(
                            crossAxisCount: constraints.maxWidth >= 520 ? 3 : 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 2.5,
                            children: [
                              _CharacterSummaryTile(
                                label: '生命值',
                                value:
                                    'HP ${widget.character.currentHp}/${widget.character.maxHp}',
                                progress: widget.character.maxHp <= 0
                                    ? 0
                                    : (widget.character.currentHp /
                                              widget.character.maxHp)
                                          .clamp(0, 1),
                              ),
                              _CharacterSummaryTile(
                                label: '护甲等级',
                                value: '${widget.character.armorClass}',
                              ),
                              _CharacterSummaryTile(
                                label: '先攻',
                                value: Dnd5eRules.formatModifier(
                                  widget.character.initiativeBonus,
                                ),
                              ),
                              _CharacterSummaryTile(
                                label: '被动察觉',
                                value: '${10 + perceptionBonus}',
                              ),
                              if (primaryResource != null)
                                _CharacterSummaryTile(
                                  label: primaryResource.name,
                                  value:
                                      '${widget.character.classResourcesUsed[primaryResource.id] ?? 0}/${primaryResource.maximum} 已用',
                                ),
                            ],
                          ),
                        ),
                        if (widget.character.conditions.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            '状态',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final condition
                                  in widget.character.conditions)
                                Chip(
                                  avatar: const Icon(
                                    Icons.warning_amber,
                                    size: 16,
                                  ),
                                  label: Text(condition),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            if (widget.onUpgrade != null)
                              FilledButton.tonalIcon(
                                onPressed: widget.onUpgrade,
                                icon: const Icon(Icons.upgrade),
                                label: const Text('升级'),
                              ),
                            OutlinedButton.icon(
                              onPressed: _showHpAdjustmentDialog,
                              icon: const Icon(Icons.favorite_outline),
                              label: const Text('调整 HP'),
                            ),
                            PopupMenuButton<_CharacterAction>(
                              tooltip: '更多角色操作',
                              onSelected: (action) {
                                switch (action) {
                                  case _CharacterAction.edit:
                                    widget.onEdit();
                                  case _CharacterAction.contentRefs:
                                    widget.onContentRefs();
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: _CharacterAction.edit,
                                  child: Text('编辑'),
                                ),
                                PopupMenuItem(
                                  value: _CharacterAction.contentRefs,
                                  child: Text('内容引用'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (widget.canPublish && widget.onPublish != null)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              key: Key(
                                'publish-character-${widget.character.id}',
                              ),
                              onPressed: widget.onPublish,
                              icon: const Icon(Icons.campaign_outlined),
                              label: const Text('发布到战役'),
                            ),
                          ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _HpAdjustmentDialog extends StatefulWidget {
  const _HpAdjustmentDialog({required this.onAdjust});

  final ValueChanged<int> onAdjust;

  @override
  State<_HpAdjustmentDialog> createState() => _HpAdjustmentDialogState();
}

class _HpAdjustmentDialogState extends State<_HpAdjustmentDialog> {
  final _amountController = TextEditingController(text: '1');

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _apply(int direction) {
    final amount = int.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) return;
    widget.onAdjust(direction * amount);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('调整 HP'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('character-card-hp-amount'),
            controller: _amountController,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '数值'),
          ),
          const SizedBox(height: 8),
          const Text('一次输入本次伤害或治疗量'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.tonalIcon(
          onPressed: () => _apply(-1),
          icon: const Icon(Icons.heart_broken_outlined),
          label: const Text('受到伤害'),
        ),
        FilledButton.icon(
          onPressed: () => _apply(1),
          icon: const Icon(Icons.healing_outlined),
          label: const Text('恢复'),
        ),
      ],
    );
  }
}

class _CharacterSummaryTile extends StatelessWidget {
  const _CharacterSummaryTile({
    required this.label,
    required this.value,
    this.progress,
  });

  final String label;
  final String value;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            Text(value, style: Theme.of(context).textTheme.titleSmall),
            if (progress != null) ...[
              const SizedBox(height: 4),
              LinearProgressIndicator(value: progress),
            ],
          ],
        ),
      ),
    );
  }
}

enum _CharacterAction { edit, contentRefs }

String? emptyToNull(String? value) {
  if (value == null || value.isEmpty) return null;
  return value;
}

class _ContentRefs {
  const _ContentRefs({
    required this.spells,
    required this.items,
    required this.features,
  });

  final List<String> spells;
  final List<String> items;
  final List<String> features;
}

_ContentRefs _contentRefsFromCharacter(CharacterSheet character) {
  final data = character.data;
  if (data is! Map) {
    return const _ContentRefs(spells: [], items: [], features: []);
  }
  final refs = data['contentRefs'];
  if (refs is! Map) {
    return const _ContentRefs(spells: [], items: [], features: []);
  }
  return _ContentRefs(
    spells: _stringList(refs['spells']),
    items: _stringList(refs['items']),
    features: _stringList(refs['features']),
  );
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value.whereType<String>().toList(growable: false);
}

List<String> _splitRefs(String value) {
  return value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

// Spec §头像来源: 支持本地角色头像（data URL）和战役角色头像（http(s) URL）。
ImageProvider<Object>? _avatarImage(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('data:image/')) {
    final separator = url.indexOf(',');
    if (separator < 0) return null;
    try {
      return MemoryImage(base64Decode(url.substring(separator + 1)));
    } on FormatException {
      return null;
    }
  }
  return NetworkImage(url);
}
