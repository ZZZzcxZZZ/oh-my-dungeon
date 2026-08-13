import 'package:flutter/material.dart';

import '../../content/data/local/content_repository.dart';

import '../data/sync/campaign_sync_api_client.dart';
import '../domain/campaign.dart';
import '../domain/campaign_character.dart';
import 'characters/campaign_character_controller.dart';
import 'characters/campaign_character_sheet_launcher.dart';
import 'characters/dm_quick_ops_sheet.dart';
import 'campaign_controller.dart';
import 'campaign_detail_page.dart';
import 'campaign_event_dispatcher.dart';
import 'center/campaign_archive_editor_page.dart';
import 'center/campaign_archive_panel.dart';
import 'center/campaign_characters_panel.dart';
import 'center/campaign_overview_panel.dart';

/// The campaign's non-chat workspace. Chat stays fast and focused; durable
/// information lives here behind an adaptive Material 3 navigation shell —
/// `NavigationBar` on phones, `NavigationRail` on tablets/desktop.
///
/// Plan 2026-07-23 task 1: the center keeps only three top-level destinations
/// — 概览 / 角色 / 档案. Records search lives in the chat workspace, not here.
/// DM-only affordances follow server capabilities, never optimistic client
/// state. Overview sections use full-width layouts without nested `Card`
/// wrappers so the information hierarchy stays flat and scannable.
class CampaignCenterPage extends StatefulWidget {
  const CampaignCenterPage({
    required this.campaign,
    required this.controller,
    this.characterController,
    this.contentRepository,
    this.initialTab = 0,
    this.syncApiClient,
    super.key,
  });

  final Campaign campaign;
  final CampaignController controller;
  final CampaignCharacterController? characterController;
  final ContentRepository? contentRepository;
  /// 战役同步 API 客户端; 由上层注入共享实例, 未提供时页面自行创建.
  final CampaignSyncApiClient? syncApiClient;

  /// 初始选中的面板下标。0=概览 1=角色 2=档案。
  final int initialTab;

  @override
  State<CampaignCenterPage> createState() => _CampaignCenterPageState();
}

class _CampaignCenterPageState extends State<CampaignCenterPage> {
  /// Wide-screen breakpoint matching Material 3 expanded layout guidance.
  static const double _wideBreakpoint = 840;

  late int _currentIndex;
  String? _archiveKind;
  List<String> _archiveSelectedTags = const [];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab.clamp(0, 2);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    await widget.controller.loadWorkspaceContext(widget.campaign.id);
    if (!mounted) return;
    await widget.controller.loadArchives(widget.campaign.id);
    if (!mounted || !_canManage) return;
    await widget.controller.loadCampaignDetail(widget.campaign.id);
  }

  bool get _canManage =>
      widget.controller.workspaceContext?.capabilities.canManageCampaign ??
      false;

  List<CampaignCharacter> get _characters =>
      widget.characterController?.characters ?? const [];

  List<CampaignMemberPreview> get _members =>
      widget.controller.workspaceContext?.members ??
      widget.campaign.memberPreview;

  /// Spec §完整管理: 当前发言身份 characterId, 从服务端 workspaceContext 读取,
  /// 用于在队伍面板高亮"使用中"的 character。
  String? get _activeSpeakerCharacterId =>
      widget.controller.workspaceContext?.membership.activeSpeakerCharacterId;

  /// Spec §档案: 当前用户 ID, 用于客户端判断"是否条目创建者"以决定编辑按钮
  /// 可见性。权限最终仍由服务端 capabilities 与 `createdBy` 校验, 这里只是
  /// 决定 UI 是否暴露编辑入口。
  String? get _currentUserId =>
      widget.controller.workspaceContext?.membership.userId;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.controller,
        if (widget.characterController != null) widget.characterController!,
      ]),
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= _wideBreakpoint;
          return Scaffold(
            appBar: AppBar(title: Text(widget.campaign.name)),
            floatingActionButton: _buildManageFab(),
            body: isWide
                ? _buildWideLayout(context)
                : _buildPanel(_currentIndex),
            bottomNavigationBar: isWide ? null : _buildBottomNavigation(),
          );
        },
      ),
    );
  }

  Widget? _buildManageFab() {
    // Every campaign member may create archive entries. Management
    // capabilities still gate editing other members' entries elsewhere.
    // Plan 2026-07-23 Task 1.4: 统一为 FAB.extended + 语义化图标，与角色
    // 新建按钮风格一致。
    if (_currentUserId == null) return null;
    if (_currentIndex != 2) return null;
    return FloatingActionButton.extended(
      key: const Key('campaign-create-archive-button'),
      heroTag: 'campaign-create-archive',
      onPressed: _showCreateArchiveTypeMenu,
      icon: const Icon(Icons.post_add),
      label: const Text('新条目'),
    );
  }

  /// Spec §档案: 新建条目按钮按类型区分。FAB 点击后先弹出类型选择菜单，
  /// 选好类型后再进入对应的创建表单（类型已预填）。
  Future<void> _showCreateArchiveTypeMenu() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('新建条目'),
        children: [
          SimpleDialogOption(
            key: const Key('archive-type-document'),
            onPressed: () => Navigator.of(context).pop('document'),
            child: const ListTile(
              leading: Icon(Icons.description_outlined),
              title: Text('新建资料'),
            ),
          ),
          SimpleDialogOption(
            key: const Key('archive-type-location'),
            onPressed: () => Navigator.of(context).pop('location'),
            child: const ListTile(
              leading: Icon(Icons.place_outlined),
              title: Text('新建地点'),
            ),
          ),
          SimpleDialogOption(
            key: const Key('archive-type-clue'),
            onPressed: () => Navigator.of(context).pop('clue'),
            child: const ListTile(
              leading: Icon(Icons.lightbulb_outline),
              title: Text('新建线索'),
            ),
          ),
          SimpleDialogOption(
            key: const Key('archive-type-file'),
            onPressed: () => Navigator.of(context).pop('file'),
            child: const ListTile(
              leading: Icon(Icons.attach_file_outlined),
              title: Text('新建文件'),
            ),
          ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    await _showCreateArchiveDialog(initialKind: selected);
  }

  Widget _buildBottomNavigation() {
    return NavigationBar(
      selectedIndex: _currentIndex,
      onDestinationSelected: (index) => setState(() => _currentIndex = index),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.info_outline),
          selectedIcon: Icon(Icons.info),
          label: '概览',
        ),
        NavigationDestination(
          icon: Icon(Icons.badge_outlined),
          selectedIcon: Icon(Icons.badge),
          label: '角色',
        ),
        NavigationDestination(
          icon: Icon(Icons.folder_outlined),
          selectedIcon: Icon(Icons.folder),
          label: '档案',
        ),
      ],
    );
  }

  Widget _buildWideLayout(BuildContext context) {
    return Row(
      children: [
        NavigationRail(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) =>
              setState(() => _currentIndex = index),
          extended: false,
          labelType: NavigationRailLabelType.all,
          destinations: const [
            NavigationRailDestination(
              icon: Icon(Icons.info_outline),
              selectedIcon: Icon(Icons.info),
              label: Text('概览'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.badge_outlined),
              selectedIcon: Icon(Icons.badge),
              label: Text('角色'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.folder_outlined),
              selectedIcon: Icon(Icons.folder),
              label: Text('档案'),
            ),
          ],
        ),
        const VerticalDivider(width: 1),
        Expanded(child: _buildPanel(_currentIndex)),
      ],
    );
  }

  Widget _buildPanel(int index) {
    switch (index) {
      case 0:
        return CampaignOverviewPanel(
          campaign: widget.campaign,
          canManage: _canManage,
          members: _members,
          characters: _characters,
          invites: _canManage ? widget.controller.invites : const [],
          campaignName: widget.campaign.name,
          serverUrl: widget.controller.apiBaseUrl,
          onCreateInvite: _canManage
              ? () => widget.controller.createInvite(
                  campaignId: widget.campaign.id,
                  maxUses: 1,
                )
              : null,
          onOpenCharacter: _openCharacterSheet,
          onOpenDmControl: _canManage ? _showDmControlSheet : null,
          onEditDetails: _canManage ? _openCampaignManagement : null,
        );
      case 1:
        return CampaignCharactersPanel(
          characters: _characters,
          isManager: _canManage,
          onOpenCharacter: _openCharacterSheet,
          activeSpeakerCharacterId: _activeSpeakerCharacterId,
          onCreateCharacter: _canManage && widget.characterController != null
              ? ({
                  required String characterType,
                  required String displayName,
                  required String lifecycle,
                  int? maxHp,
                }) async {
                  // AuthController.ensureValidAccessToken 会基于 JWT exp
                  // 主动预刷新；character controller 的同步 accessTokenProvider
                  // 会读到刷新后的 token。
                  final token = await widget.controller.authController
                      .ensureValidAccessToken();
                  if (token == null) return '登录已过期，请重新登录';
                  final success = await widget.characterController!
                      .createDmCharacter(
                        characterType: characterType,
                        lifecycle: lifecycle,
                        sheet: {
                          'name': displayName,
                          'maxHp': ?maxHp,
                          'currentHp': ?maxHp,
                        },
                      );
                  return success
                      ? null
                      : (widget.characterController!.error ?? '创建失败');
                }
              : null,
          onArchiveCharacter: _canManage && widget.characterController != null
              ? ({required CampaignCharacter character}) async {
                  final token = await widget.controller.authController
                      .ensureValidAccessToken();
                  if (token == null) return '登录已过期，请重新登录';
                  final success = await widget.characterController!
                      .archiveCharacter(character);
                  return success
                      ? null
                      : (widget.characterController!.error ?? '归档失败');
                }
              : null,
          onRestoreCharacter: _canManage && widget.characterController != null
              ? ({required CampaignCharacter character}) async {
                  final token = await widget.controller.authController
                      .ensureValidAccessToken();
                  if (token == null) return '登录已过期，请重新登录';
                  final success = await widget.characterController!
                      .restoreCharacter(character);
                  return success
                      ? null
                      : (widget.characterController!.error ?? '恢复失败');
                }
              : null,
          onBatchArchive: _canManage && widget.characterController != null
              ? ({required List<String> characterIds}) async {
                  final token = await widget.controller.authController
                      .ensureValidAccessToken();
                  if (token == null) return '登录已过期，请重新登录';
                  var lastError = '归档失败';
                  for (final id in characterIds) {
                    final character = _characters
                        .where((candidate) => candidate.id == id)
                        .firstOrNull;
                    if (character == null) continue;
                    final success = await widget.characterController!
                        .archiveCharacter(character);
                    if (!success) {
                      lastError =
                          widget.characterController!.error ?? lastError;
                    }
                  }
                  return lastError == '归档失败' && characterIds.isNotEmpty
                      ? null
                      : lastError;
                }
              : null,
          onSetActiveSpeaker: _canManage
              ? ({required CampaignCharacter character}) async {
                  final success = await widget.controller.updateSpeaker(
                    campaignId: widget.campaign.id,
                    speakerMode: 'character',
                    characterId: character.id,
                  );
                  return success
                      ? null
                      : (widget.controller.workspaceContextError ?? '切换发言身份失败');
                }
              : null,
          onSetVisibility: _canManage && widget.characterController != null
              ? ({
                  required CampaignCharacter character,
                  required bool visibleToPlayers,
                }) async {
                  final token = await widget.controller.authController
                      .ensureValidAccessToken();
                  if (token == null) return '登录已过期，请重新登录';
                  final success = await widget.characterController!
                      .updateCharacter(
                        character,
                        character.sheet,
                        visibleToPlayers: visibleToPlayers,
                      );
                  return success
                      ? null
                      : (widget.characterController!.error ?? '更新可见性失败');
                }
              : null,
        );
      case 2:
        return CampaignArchivePanel(
          entries: widget.controller.archives,
          isLoading: widget.controller.isArchivesLoading,
          error: widget.controller.archivesError,
          canManage: _canManage,
          currentUserId: _currentUserId,
          selectedKind: _archiveKind,
          onKindChanged: (kind) {
            setState(() => _archiveKind = kind);
            widget.controller.loadArchives(
              widget.campaign.id,
              kind: kind,
              tags: _archiveSelectedTags,
            );
          },
          selectedTags: _archiveSelectedTags,
          onTagsChanged: (tags) {
            setState(() => _archiveSelectedTags = tags);
            widget.controller.loadArchives(
              widget.campaign.id,
              kind: _archiveKind,
              tags: tags,
            );
          },
          onRefresh: () => widget.controller.loadArchives(
            widget.campaign.id,
            kind: _archiveKind,
            tags: _archiveSelectedTags,
          ),
          onArchive: (entry) => widget.controller.archiveEntry(
            campaignId: widget.campaign.id,
            entryId: entry.id,
          ),
          onUpdate: (entry, {bodyBlocks, summary, tags, title}) async {
            final updated = await widget.controller.updateArchiveEntry(
              campaignId: widget.campaign.id,
              entryId: entry.id,
              title: title,
              summary: summary,
              bodyBlocks: bodyBlocks,
              tags: tags,
            );
            if (updated != null) return true;
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(widget.controller.archivesError ?? '保存失败'),
                ),
              );
            }
            return false;
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }

  void _openCharacterSheet(CampaignCharacter character) {
    final controller = widget.characterController;
    if (controller == null) return;
    openCampaignCharacterSheet(
      context: context,
      controller: controller,
      character: character,
      canEditAnyCharacter: _canManage,
      contentRepository: widget.contentRepository,
    );
  }

  Future<void> _showCreateArchiveDialog({String initialKind = 'clue'}) async {
    // Plan 2026-07-23 task 4.4: 合并为单一 CampaignArchiveEditorPage。
    // 草稿由编辑器收集，调用方负责把 draft 转成服务端调用。
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CampaignArchiveEditorPage(
          initialKind: initialKind,
          existingEntries: widget.controller.archives,
          onSubmit: (draft) async {
            final linksPayload = draft.linkedEntryIds.isEmpty
                ? null
                : draft.linkedEntryIds
                      .map(
                        (id) => <String, Object?>{'kind': 'archive', 'id': id},
                      )
                      .toList(growable: false);
            final entry = await widget.controller.createArchiveEntry(
              campaignId: widget.campaign.id,
              kind: draft.kind,
              title: draft.title,
              summary: draft.summary,
              bodyBlocks: draft.bodyBlocks.isEmpty ? null : draft.bodyBlocks,
              tags: draft.tags.isEmpty ? null : draft.tags,
              links: linksPayload,
            );
            if (entry != null) {
              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('已保存到战役档案')));
              }
              return true;
            }
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(widget.controller.archivesError ?? '创建失败'),
                ),
              );
            }
            return false;
          },
        ),
      ),
    );
    if (created == true && mounted) {
      // 创建成功后刷新列表，确保新条目立刻可见。
      await widget.controller.loadArchives(widget.campaign.id);
    }
  }

  /// Spec §概览: DM 在概览面板看到控场摘要、群体检定和遭遇准备入口。
  /// 控场入口从聊天工具栏迁移到战役中心 → 概览, 与 spec 一致。
  Future<void> _showDmControlSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DM 控场', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text('常用主持操作集中在此处。'),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.bolt_outlined),
                  title: const Text('快捷操作'),
                  subtitle: const Text('批量扣血、给予装备、快速检定'),
                  enabled: widget.characterController != null,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _openDmQuickOps();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Task 3.4 — 打开 DM 快捷操作面板. 包含批量扣血、给予装备、快速检定
  /// 三个原子操作. dispatcher 用 CampaignController 的 apiBaseUrl 和
  /// accessTokenProvider 按需构造, 避免向上层传新依赖.
  Future<void> _openDmQuickOps() async {
    final characterController = widget.characterController;
    if (characterController == null) return;
    final dispatcher = CampaignEventDispatcher(
      apiClient: widget.syncApiClient ?? HttpCampaignSyncApiClient(),
      apiBaseUrlProvider: () => widget.controller.apiBaseUrl,
      accessTokenProvider: () => widget.controller.accessToken ?? '',
      onCharacterChanged: (characterSummary) async {
        // 服务端原子完成 HP/物品变更后, 触发 characterController 增量拉取,
        // 保证本地缓存与服务端一致.
        await characterController.pullUntilCurrent();
      },
    );
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: DmQuickOpsSheet(
          campaignId: widget.campaign.id,
          characterController: characterController,
          eventDispatcher: dispatcher,
          contentRepository: widget.contentRepository,
        ),
      ),
    );
  }

  /// Spec §全局设置: 打开战役详情编辑页（名称、封面、简介）。
  Future<void> _openCampaignManagement() {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CampaignDetailPage(
          controller: widget.controller,
          campaignId: widget.campaign.id,
        ),
      ),
    );
  }
}
