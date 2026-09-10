import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/presentation/avatar_image_provider.dart';
import '../../app_preferences/presentation/app_preferences_controller.dart';
import '../../campaigns/domain/campaign.dart';
import '../../campaigns/domain/campaign_character.dart';
import '../../campaigns/presentation/characters/campaign_character_controller.dart';
import '../../campaigns/presentation/characters/campaign_character_sheet_launcher.dart';
import '../../campaigns/presentation/campaign_controller.dart';
import '../../campaigns/presentation/center/campaign_characters_panel.dart';
import '../../client_mode/domain/client_mode.dart';
import '../../content/data/local/content_repository.dart';
import '../../content/domain/content_entry.dart';
import '../data/local/character_sync_conflict_repository.dart';
import '../data/character_markdown_codec.dart';
import '../data/character_repository.dart';
import '../domain/character.dart';
import '../domain/character_rule_projector.dart';
import '../domain/dnd5e_rules.dart';
import '../domain/monster_template_factory.dart';
import 'character_conflict_banner_controller.dart';
import 'character_conflict_resolution_page.dart';
import 'character_detail_page.dart';
import 'character_controller.dart';
import 'character_editor_page.dart';
import 'character_import_preview_sheet.dart';
import 'character_upgrade_page.dart';
import '../../../core/widgets/empty_state.dart';

class CharactersTabPage extends StatefulWidget {
  const CharactersTabPage({
    required this.controller,
    this.campaignController,
    this.contentRepository,
    this.localContentRepository,
    this.appPreferencesController,
    this.modeController,
    this.campaignCharacterController,
    this.conflictBannerController,
    this.onUseRemoteConflict,
    super.key,
  });

  final CharacterController controller;
  final CampaignController? campaignController;
  final ContentRepository? contentRepository;
  final ContentRepository? localContentRepository;
  final AppPreferencesController? appPreferencesController;
  final ClientModeController? modeController;
  final CampaignCharacterController? campaignCharacterController;

  /// 角色 vs Character 同步冲突 banner。仅在桌面/移动端有本地数据库时注入。
  final CharacterConflictBannerController? conflictBannerController;
  final Future<bool> Function(CharacterSyncConflict conflict)?
  onUseRemoteConflict;

  @override
  State<CharactersTabPage> createState() => _CharactersTabPageState();
}

class _CharactersTabPageState extends State<CharactersTabPage> {
  String? _expandedCampaignId;
  List<CharacterMarkdownExternalChange> _externalMarkdownChanges = const [];

  @override
  void initState() {
    super.initState();
    widget.modeController?.addListener(_onModeChanged);
    widget.campaignCharacterController?.addListener(_onCharacterChanged);
    widget.conflictBannerController?.addListener(_onBannerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkExternalMarkdownChanges();
    });
  }

  @override
  void didUpdateWidget(covariant CharactersTabPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.modeController != widget.modeController) {
      oldWidget.modeController?.removeListener(_onModeChanged);
      widget.modeController?.addListener(_onModeChanged);
    }
    if (oldWidget.campaignCharacterController !=
        widget.campaignCharacterController) {
      oldWidget.campaignCharacterController?.removeListener(
        _onCharacterChanged,
      );
      widget.campaignCharacterController?.addListener(_onCharacterChanged);
    }
    if (oldWidget.conflictBannerController != widget.conflictBannerController) {
      oldWidget.conflictBannerController?.removeListener(_onBannerChanged);
      widget.conflictBannerController?.addListener(_onBannerChanged);
    }
  }

  @override
  void dispose() {
    widget.modeController?.removeListener(_onModeChanged);
    widget.campaignCharacterController?.removeListener(_onCharacterChanged);
    widget.conflictBannerController?.removeListener(_onBannerChanged);
    super.dispose();
  }

  void _onModeChanged() {
    if (mounted) setState(() {});
  }

  void _onCharacterChanged() {
    if (mounted) setState(() {});
  }

  void _onBannerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.controller,
        widget.campaignController,
        widget.appPreferencesController,
        widget.conflictBannerController,
      ]),
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('角色'),
            actions: [
              IconButton(
                key: const Key('import-character-markdown'),
                tooltip: '导入角色卡',
                onPressed: _importMarkdown,
                icon: const Icon(Icons.file_upload_outlined),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            key: const Key('create_character'),
            heroTag: 'create_character',
            onPressed: _isDmMode ? _showDmCreateMenu : _openCreatePage,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('新角色'),
          ),
          body: _isDmMode
              ? _buildDmCharacterDirectory(context)
              : KeyedSubtree(
                  key: const Key('player-local-characters'),
                  child: Column(
                    children: [
                      if (_externalMarkdownChanges.isNotEmpty)
                        _buildExternalMarkdownBanner(context),
                      if (widget.conflictBannerController?.hasUnresolved ??
                          false)
                        _buildConflictBanner(context),
                      Expanded(child: _buildCharacterList(context)),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildExternalMarkdownBanner(BuildContext context) {
    final change = _externalMarkdownChanges.first;
    return MaterialBanner(
      key: const Key('external-character-markdown-banner'),
      leading: const Icon(Icons.difference_outlined),
      content: Text('“${change.existing.name}”的 Markdown 文件已在应用外修改'),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              _externalMarkdownChanges = _externalMarkdownChanges.sublist(1);
            });
          },
          child: const Text('忽略'),
        ),
        FilledButton.tonal(
          onPressed: () => _reviewExternalMarkdownChange(change),
          child: const Text('查看差异'),
        ),
      ],
    );
  }

  Future<void> _checkExternalMarkdownChanges() async {
    final changes = await widget.controller.detectExternalMarkdownChanges();
    if (!mounted || changes.isEmpty) return;
    setState(() => _externalMarkdownChanges = changes);
  }

  Future<void> _reviewExternalMarkdownChange(
    CharacterMarkdownExternalChange change,
  ) async {
    final action = await showModalBottomSheet<CharacterImportAction>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => CharacterImportPreviewSheet(
        imported: change.imported,
        existing: change.existing,
        onSelected: (value) => Navigator.pop(sheetContext, value),
      ),
    );
    if (action == null || !mounted) return;
    final character = switch (action) {
      CharacterImportAction.create => _asNewCharacter(change.imported),
      CharacterImportAction.replace => _replaceCharacter(
        change.existing,
        change.imported,
      ),
      CharacterImportAction.merge => _mergeCharacter(
        change.existing,
        change.imported,
      ),
    };
    final saved = await widget.controller.updateCharacter(character);
    if (!mounted || !saved) return;
    setState(() {
      _externalMarkdownChanges = _externalMarkdownChanges
          .where((item) => item != change)
          .toList(growable: false);
    });
  }

  Widget _buildDmCharacterDirectory(BuildContext context) {
    final campaignController = widget.campaignController;
    final characterController = widget.campaignCharacterController;
    final campaigns = campaignController?.campaigns ?? const <Campaign>[];

    return KeyedSubtree(
      key: const Key('dm-campaign-character-directory'),
      child: switch ((
        campaignController?.isLoading ?? false,
        campaignController?.error,
        campaigns.isEmpty,
        characterController,
      )) {
        (true, _, _, _) => const Center(child: CircularProgressIndicator()),
        (_, final String error, _, _) => _CharacterDirectoryMessage(
          icon: Icons.cloud_off_outlined,
          message: error,
        ),
        (_, _, true, _) => const _CharacterDirectoryMessage(
          icon: Icons.campaign_outlined,
          message: '还没有可管理的战役\n请先在战役页创建或加入战役',
        ),
        (_, _, _, null) => const _CharacterDirectoryMessage(
          icon: Icons.sync_problem_outlined,
          message: '战役角色服务尚未就绪',
        ),
        _ => RefreshIndicator(
          onRefresh: () async {
            await campaignController!.loadCampaigns();
            final campaignId = _expandedCampaignId;
            if (campaignId != null) {
              await _loadDmCampaign(campaignId);
            }
          },
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
            itemCount: campaigns.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final campaign = campaigns[index];
              final expanded = _expandedCampaignId == campaign.id;
              return Card.outlined(
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  key: Key('dm-campaign-group-${campaign.id}'),
                  initiallyExpanded: expanded,
                  maintainState: false,
                  leading: CircleAvatar(
                    child: Text(
                      campaign.name.trim().isEmpty
                          ? '?'
                          : campaign.name.characters.first.toUpperCase(),
                    ),
                  ),
                  title: Text(campaign.name),
                  subtitle: Text(
                    campaign.description.trim().isEmpty
                        ? campaign.system
                        : campaign.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onExpansionChanged: (value) {
                    if (!value) {
                      if (_expandedCampaignId == campaign.id) {
                        setState(() => _expandedCampaignId = null);
                      }
                      return;
                    }
                    setState(() => _expandedCampaignId = campaign.id);
                    _loadDmCampaign(campaign.id);
                  },
                  children: [
                    if (expanded)
                      _buildExpandedCampaignCharacters(
                        context,
                        campaign,
                        characterController!,
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      },
    );
  }

  Future<void> _loadDmCampaign(String campaignId) async {
    final campaignController = widget.campaignController;
    final characterController = widget.campaignCharacterController;
    if (campaignController == null || characterController == null) return;
    await Future.wait([
      campaignController.loadWorkspaceContext(campaignId),
      characterController.selectCampaign(campaignId),
    ]);
    await characterController.pullUntilCurrent();
  }

  Widget _buildExpandedCampaignCharacters(
    BuildContext context,
    Campaign campaign,
    CampaignCharacterController controller,
  ) {
    if (controller.selectedCampaignId != campaign.id || controller.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (controller.error != null) {
      return _CharacterDirectoryMessage(
        icon: Icons.sync_problem_outlined,
        message: controller.error!,
      );
    }

    final workspace = widget.campaignController?.workspaceContext;
    return CampaignCharactersPanel(
      key: Key('dm-campaign-characters-panel-${campaign.id}'),
      characters: controller.characters,
      isManager: workspace?.capabilities.canEditAnyCharacter ?? false,
      embedded: true,
      activeSpeakerCharacterId: workspace?.membership.activeSpeakerCharacterId,
      onOpenCharacter: _openCampaignCharacter,
      onArchiveCharacter: ({required CampaignCharacter character}) async {
        final success = await controller.archiveCharacter(character);
        return success ? null : (controller.error ?? '归档失败');
      },
      onRestoreCharacter: ({required CampaignCharacter character}) async {
        final success = await controller.restoreCharacter(character);
        return success ? null : (controller.error ?? '恢复失败');
      },
      onBatchArchive: ({required List<String> characterIds}) async {
        for (final characterId in characterIds) {
          final character = controller.characters
              .where((item) => item.id == characterId)
              .firstOrNull;
          if (character == null) continue;
          final success = await controller.archiveCharacter(character);
          if (!success) return controller.error ?? '归档失败';
        }
        return null;
      },
      onSetActiveSpeaker: ({required CampaignCharacter character}) async {
        final success =
            await widget.campaignController?.updateSpeaker(
              campaignId: campaign.id,
              speakerMode: 'character',
              characterId: character.id,
            ) ??
            false;
        return success
            ? null
            : (widget.campaignController?.workspaceContextError ?? '切换身份失败');
      },
      onSetVisibility:
          ({
            required CampaignCharacter character,
            required bool visibleToPlayers,
          }) async {
            final success = await controller.updateCharacter(
              character,
              character.sheet,
              visibleToPlayers: visibleToPlayers,
            );
            return success ? null : (controller.error ?? '更新可见性失败');
          },
    );
  }

  Future<void> _openCampaignCharacter(CampaignCharacter character) async {
    final controller = widget.campaignCharacterController;
    if (controller == null) return;
    final workspace = widget.campaignController?.workspaceContext;
    final canEditAnyCharacter =
        workspace?.campaign.id == character.campaignId &&
        (workspace?.capabilities.canEditAnyCharacter ?? false);
    await openCampaignCharacterSheet(
      context: context,
      controller: controller,
      character: character,
      canEditAnyCharacter: canEditAnyCharacter,
      contentRepository:
          widget.contentRepository ?? widget.localContentRepository,
    );
  }

  Widget _buildConflictBanner(BuildContext context) {
    final banner = widget.conflictBannerController!;
    final count = banner.unresolvedCount;
    final theme = Theme.of(context);
    return Material(
      key: const Key('character-conflict-banner'),
      color: theme.colorScheme.errorContainer,
      child: InkWell(
        onTap: _openConflictResolutionPage,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.sync_problem,
                color: theme.colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$count 个角色有未解决的同步冲突',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onErrorContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openConflictResolutionPage() async {
    final banner = widget.conflictBannerController;
    if (banner == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CharacterConflictResolutionPage(
          controller: banner,
          characterController: widget.controller,
          campaignCharacterController: widget.campaignCharacterController,
          onUseRemote: widget.onUseRemoteConflict,
        ),
      ),
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
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error),
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
          onOpen: () => _openDetailPage(character),
          onEdit: () => _openEditPage(character),
          onExport: () => _exportMarkdown(character),
          onDelete: () => _deleteCharacter(character),
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
  /// 2. 完整创建角色 (existing full character editor)
  /// DM 始终可以创建本地角色或从怪物模板建立完整角色卡；只有常驻
  /// 战役 NPC 需要已选中的战役。
  /// 一次性发言身份改用 speakerSnapshot 直接写入消息，不再创建 Character。
  bool get _isDmMode => widget.modeController?.mode == ClientMode.dungeonMaster;

  bool get _hasSelectedCampaign {
    final campaignId = widget.campaignCharacterController?.selectedCampaignId;
    return campaignId != null && campaignId.isNotEmpty;
  }

  Future<void> _showDmCreateMenu() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('创建角色'),
        children: [
          if (_hasSelectedCampaign)
            SimpleDialogOption(
              key: const Key('dm-create-quick-npc'),
              onPressed: () => Navigator.of(context).pop('quickNpc'),
              child: const ListTile(
                leading: Icon(Icons.smart_toy_outlined),
                title: Text('快速创建 NPC'),
                subtitle: Text('输入名称和 HP，创建当前战役的常驻 NPC'),
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
          SimpleDialogOption(
            key: const Key('dm-create-from-monster'),
            onPressed: () => Navigator.of(context).pop('monsterTemplate'),
            child: const ListTile(
              leading: Icon(Icons.menu_book_outlined),
              title: Text('从怪物资料创建'),
              subtitle: Text('搜索怪物模板，预填完整角色卡'),
            ),
          ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    switch (selected) {
      case 'quickNpc':
        await _showQuickNpcForm();
      case 'full':
        await _openCreatePage();
      case 'monsterTemplate':
        await _createFromMonsterTemplate();
    }
  }

  Future<void> _createFromMonsterTemplate() async {
    final repository =
        widget.localContentRepository ?? widget.contentRepository;
    if (repository == null) return;
    final monsters = await repository.search(
      const ContentQuery(type: 'monster'),
    );
    if (!mounted) return;
    if (monsters.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('资料库中没有怪物模板')));
      return;
    }
    final selected = await _pickMonsterTemplate(context, monsters);
    if (selected == null || !mounted) return;

    final initialDraft = MonsterTemplateFactory.fromEntry(selected);
    final preview = initialDraft.toLocalCharacter();
    final messenger = ScaffoldMessenger.of(context);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => CharacterEditorPage(
          initialCharacter: preview,
          contentEntries: monsters,
          onPickImage: _pickAvatarImage,
          onSubmit: (draft) async {
            final success = await widget.controller.createCharacter(draft);
            if (mounted) {
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? '已从 ${selected.name} 创建角色'
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

  Future<void> _showQuickNpcForm() async {
    final campaignCharacterController = widget.campaignCharacterController;
    if (campaignCharacterController == null) return;

    final nameController = TextEditingController();
    final hpController = TextEditingController();
    var characterType = 'npc';
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
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('NPC'),
                        selected: characterType == 'npc',
                        onSelected: (_) =>
                            setDialogState(() => characterType = 'npc'),
                      ),
                      ChoiceChip(
                        label: const Text('怪物'),
                        selected: characterType == 'monster',
                        onSelected: (_) =>
                            setDialogState(() => characterType = 'monster'),
                      ),
                      ChoiceChip(
                        label: const Text('同伴'),
                        selected: characterType == 'companion',
                        onSelected: (_) =>
                            setDialogState(() => characterType = 'companion'),
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
    final success = await campaignCharacterController.createDmCharacter(
      characterType: characterType,
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
          success ? '已创建常驻 NPC' : (campaignCharacterController.error ?? '创建失败'),
        ),
      ),
    );
  }

  Future<void> _openCreatePage() async {
    final messenger = ScaffoldMessenger.of(context);
    widget.controller.takeLastCreatedCharacter();
    final repository =
        widget.localContentRepository ?? widget.contentRepository;
    List<ContentEntry> contentEntries = const [];
    if (repository != null) {
      contentEntries = await repository.search(const ContentQuery());
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => CharacterEditorPage(
          defaultCreationMethod: 'standard',
          contentEntries: contentEntries,
          onPickImage: _pickAvatarImage,
          onSubmit: (draft) async {
            final success = await widget.controller.createCharacter(draft);
            if (mounted) {
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    success ? '角色已创建' : (widget.controller.error ?? '创建失败'),
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
                    success ? '角色已保存' : (widget.controller.error ?? '保存失败'),
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

  Future<void> _deleteCharacter(CharacterSheet character) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除角色？'),
        content: Text('“${character.name}”将从本地角色库中永久删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final success = await widget.controller.deleteCharacter(character.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? '角色已删除' : (widget.controller.error ?? '删除失败')),
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
    final success = await widget.controller.adjustHitPoints(
      characterId: character.id,
      delta: delta,
    );
    if (!mounted || success) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('HP 调整失败')));
  }

  Future<void> _importMarkdown() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['md', 'markdown'],
        withData: true,
      );
      final bytes = result?.files.singleOrNull?.bytes;
      if (bytes == null || bytes.isEmpty || !mounted) return;
      final imported = const CharacterMarkdownCodec().decode(
        utf8.decode(bytes),
      );
      final existing = widget.controller.characters
          .where((item) => item.id == imported.character.id)
          .firstOrNull;
      final action = await showModalBottomSheet<CharacterImportAction>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => CharacterImportPreviewSheet(
          imported: imported.character,
          existing: existing,
          onSelected: (value) => Navigator.pop(sheetContext, value),
        ),
      );
      if (action == null || !mounted) return;
      final character = switch (action) {
        CharacterImportAction.create => _asNewCharacter(imported.character),
        CharacterImportAction.replace => _replaceCharacter(
          existing!,
          imported.character,
        ),
        CharacterImportAction.merge => _mergeCharacter(
          existing!,
          imported.character,
        ),
      };
      final saved = await widget.controller.updateCharacter(character);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(saved ? '角色卡已导入' : '角色卡导入失败')));
    } on CharacterMarkdownFormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('无法导入角色卡：$error')));
    }
  }

  Future<void> _exportMarkdown(CharacterSheet character) async {
    final markdown = const CharacterMarkdownCodec().encode(character);
    await FilePicker.platform.saveFile(
      dialogTitle: '导出角色卡',
      fileName: '${_safeFilename(character.name)}.md',
      type: FileType.custom,
      allowedExtensions: const ['md'],
      bytes: Uint8List.fromList(utf8.encode(markdown)),
    );
  }
}

Future<ContentEntry?> _pickMonsterTemplate(
  BuildContext context,
  List<ContentEntry> monsters,
) {
  var query = '';
  return showModalBottomSheet<ContentEntry>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) {
        final normalized = query.trim().toLowerCase();
        final filtered = monsters
            .where((entry) {
              if (normalized.isEmpty) return true;
              return entry.name.toLowerCase().contains(normalized) ||
                  entry.aliases.any(
                    (alias) => alias.toLowerCase().contains(normalized),
                  ) ||
                  entry.summary.toLowerCase().contains(normalized);
            })
            .toList(growable: false);
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.82,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    '选择怪物模板',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SearchBar(
                    key: const Key('monster-template-search'),
                    hintText: '搜索名称、别名或类型',
                    leading: const Icon(Icons.search),
                    onChanged: (value) => setSheetState(() => query = value),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filtered.isEmpty
                      ? const EmptyState(icon: Icons.psychology_outlined, title: '没有匹配的怪物')
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final entry = filtered[index];
                            return ListTile(
                              key: Key('monster-template-${entry.id}'),
                              leading: const Icon(Icons.smart_toy_outlined),
                              title: Text(entry.name),
                              subtitle: Text(
                                entry.summary.isEmpty ? '怪物' : entry.summary,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: const Icon(Icons.chevron_right),
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

class _CharacterDirectoryMessage extends StatelessWidget {
  const _CharacterDirectoryMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return EmptyState(
      icon: icon,
      iconSize: 40,
      iconColor: theme.colorScheme.onSurfaceVariant,
      title: message,
      titleStyle: theme.textTheme.bodyLarge?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _CharacterCard extends StatefulWidget {
  const _CharacterCard({
    required this.character,
    required this.onOpen,
    required this.onEdit,
    required this.onExport,
    required this.onDelete,
    required this.onHpDelta,
    this.onUpgrade,
  });

  final CharacterSheet character;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onExport;
  final VoidCallback onDelete;
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
      if (!widget.character.isNonPlayerCharacter)
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
              key: Key('character-list-avatar-${widget.character.id}'),
              backgroundImage: avatarImageProvider(widget.character.avatarUrl),
              child:
                  widget.character.avatarUrl == null ||
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
                          const SizedBox(height: 8),
                          Text(
                            '状态',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
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
                                  case _CharacterAction.exportMarkdown:
                                    widget.onExport();
                                  case _CharacterAction.delete:
                                    widget.onDelete();
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: _CharacterAction.edit,
                                  child: Text('编辑'),
                                ),
                                const PopupMenuItem(
                                  value: _CharacterAction.exportMarkdown,
                                  child: Text('导出 Markdown'),
                                ),
                                PopupMenuItem(
                                  value: _CharacterAction.delete,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete_outline,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        '删除角色',
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Labels and values sit on a secondaryContainer tile, so they
            // must use the matching on-* role (E2).
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: colors.onSecondaryContainer),
            ),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: colors.onSecondaryContainer),
            ),
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

enum _CharacterAction { edit, exportMarkdown, delete }

String? emptyToNull(String? value) {
  if (value == null || value.isEmpty) return null;
  return value;
}

CharacterSheet _asNewCharacter(CharacterSheet imported) {
  final now = DateTime.now().toUtc().toIso8601String();
  return _copyImported(
    imported,
    id: 'imported-${DateTime.now().microsecondsSinceEpoch}',
    ownerUserId: 'local',
    createdAt: now,
    updatedAt: now,
  );
}

CharacterSheet _replaceCharacter(
  CharacterSheet existing,
  CharacterSheet imported,
) {
  return _copyImported(
    imported,
    id: existing.id,
    ownerUserId: existing.ownerUserId,
    createdAt: existing.createdAt,
    updatedAt: DateTime.now().toUtc().toIso8601String(),
  );
}

CharacterSheet _mergeCharacter(
  CharacterSheet existing,
  CharacterSheet imported,
) {
  return existing.copyWith(
    name: imported.name,
    avatarUrl: imported.avatarUrl,
    level: imported.level,
    classSummary: imported.classSummary,
    raceSummary: imported.raceSummary,
    currentHp: imported.currentHp,
    maxHp: imported.maxHp,
    armorClass: imported.armorClass,
    speed: imported.speed,
    initiativeBonus: imported.initiativeBonus,
    abilities: {...existing.abilityMap, ...imported.abilityMap},
    saves: {...existing.saveMap, ...imported.saveMap},
    skills: {...existing.skillMap, ...imported.skillMap},
    inventory: imported.inventory,
    currency: {...existing.currencyMap, ...imported.currencyMap},
    notes: imported.notes.isEmpty ? existing.notes : imported.notes,
    data: {...existing.dataMap, ...imported.dataMap},
  );
}

CharacterSheet _copyImported(
  CharacterSheet source, {
  required String id,
  required String ownerUserId,
  required String createdAt,
  required String updatedAt,
}) {
  return CharacterSheet(
    id: id,
    ownerUserId: ownerUserId,
    name: source.name,
    avatarUrl: source.avatarUrl,
    system: source.system,
    level: source.level,
    classSummary: source.classSummary,
    raceSummary: source.raceSummary,
    currentHp: source.currentHp,
    maxHp: source.maxHp,
    armorClass: source.armorClass,
    speed: source.speed,
    initiativeBonus: source.initiativeBonus,
    abilities: source.abilities,
    saves: source.saves,
    skills: source.skills,
    inventory: source.inventory,
    currency: source.currency,
    notes: source.notes,
    data: source.data,
    createdAt: createdAt,
    updatedAt: updatedAt,
    contentReferences: source.contentReferences,
  );
}

String _safeFilename(String value) {
  final safe = value.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
  return safe.isEmpty ? 'character' : safe;
}
