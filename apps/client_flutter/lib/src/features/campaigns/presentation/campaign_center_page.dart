import 'package:flutter/material.dart';

import '../domain/campaign.dart';
import '../domain/campaign_actor.dart';
import 'actors/campaign_actor_controller.dart';
import 'actors/campaign_actor_sheet_launcher.dart';
import 'campaign_controller.dart';
import 'campaign_detail_page.dart';
import 'center/campaign_archive_panel.dart';
import 'center/campaign_characters_panel.dart';
import 'center/campaign_overview_panel.dart';
import 'center/campaign_records_panel.dart';

/// The campaign's non-chat workspace. Chat stays fast and focused; durable
/// information lives here behind an adaptive Material 3 navigation shell —
/// `NavigationBar` on phones, `NavigationRail` on tablets/desktop.
///
/// Plan 3 task 2: the four panels (overview/team/archive/records) are
/// extracted into `center/` widgets so they can be reused and tested
/// independently. DM-only affordances follow server capabilities, never
/// optimistic client state.
class CampaignCenterPage extends StatefulWidget {
  const CampaignCenterPage({
    required this.campaign,
    required this.controller,
    this.actorController,
    super.key,
  });

  final Campaign campaign;
  final CampaignController controller;
  final CampaignActorController? actorController;

  @override
  State<CampaignCenterPage> createState() => _CampaignCenterPageState();
}

class _CampaignCenterPageState extends State<CampaignCenterPage> {
  /// Wide-screen breakpoint matching Material 3 expanded layout guidance.
  static const double _wideBreakpoint = 840;

  int _currentIndex = 0;
  String? _archiveKind;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadWorkspaceContext(widget.campaign.id);
      widget.controller.loadArchives(widget.campaign.id);
      // Spec §队伍: 邀请码列表在队伍面板就地展示, 需要拉取战役详情
      // (含 invites)。非 manager 调用会被服务端 403 忽略, 不影响普通玩家。
      widget.controller.loadCampaignDetail(widget.campaign.id);
    });
  }

  bool get _canManage =>
      widget.controller.workspaceContext?.capabilities.canManageCampaign ??
      false;

  List<CampaignActor> get _actors => widget.actorController?.actors ?? const [];

  List<CampaignMemberPreview> get _members =>
      widget.controller.workspaceContext?.members ??
      widget.campaign.memberPreview;

  /// Spec §完整管理: 当前发言身份 actorId, 从服务端 workspaceContext 读取,
  /// 用于在队伍面板高亮"使用中"的 actor。
  String? get _activeSpeakerActorId =>
      widget.controller.workspaceContext?.membership.activeSpeakerActorId;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.controller,
        if (widget.actorController != null) widget.actorController!,
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
    // Spec §档案: 新建条目 FAB 只在档案面板出现, 概览/队伍/记录面板不显示。
    if (!_canManage) return null;
    if (_currentIndex != 2) return null;
    return FloatingActionButton(
      key: const Key('campaign-create-archive-button'),
      tooltip: '新建条目',
      onPressed: _showCreateArchiveTypeMenu,
      child: const Icon(Icons.add),
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
        NavigationDestination(
          icon: Icon(Icons.history_outlined),
          selectedIcon: Icon(Icons.history),
          label: '记录',
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
            NavigationRailDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history),
              label: Text('记录'),
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
          actors: _actors,
          invites: _canManage ? widget.controller.invites : const [],
          campaignName: widget.campaign.name,
          serverUrl: widget.controller.apiBaseUrl,
          onCreateInvite: _canManage
              ? () => widget.controller.createInvite(
                  campaignId: widget.campaign.id,
                  maxUses: 1,
                )
              : null,
          onOpenActor: _openActorSheet,
          onOpenDmControl: _canManage ? _showDmControlSheet : null,
          // Spec §全局设置: 4 项低频操作整合到概览面板, DM 可见全部 4 项,
          // 普通玩家只见"离开战役"。
          onEditDetails: _canManage ? _openCampaignManagement : null,
          onTransferOwnership: _canManage ? _showNotImplemented : null,
          onArchiveCampaign: _canManage ? _showNotImplemented : null,
          onLeaveCampaign: _showNotImplemented,
        );
      case 1:
        return CampaignCharactersPanel(
          actors: _actors,
          isManager: _canManage,
          onOpenActor: _openActorSheet,
          activeSpeakerActorId: _activeSpeakerActorId,
          onCreateActor: _canManage && widget.actorController != null
              ? ({
                  required String actorType,
                  required String displayName,
                  required String lifecycle,
                  int? maxHp,
                }) async {
                  // AuthController.ensureValidAccessToken 会基于 JWT exp
                  // 主动预刷新；actor controller 的同步 accessTokenProvider
                  // 会读到刷新后的 token。
                  final token = await widget.controller.authController
                      .ensureValidAccessToken();
                  if (token == null) return '登录已过期，请重新登录';
                  final success = await widget.actorController!.createDmActor(
                    actorType: actorType,
                    lifecycle: lifecycle,
                    sheet: {
                      'name': displayName,
                      'maxHp': ?maxHp,
                      'currentHp': ?maxHp,
                    },
                  );
                  return success
                      ? null
                      : (widget.actorController!.error ?? '创建失败');
                }
              : null,
          onArchiveActor: _canManage && widget.actorController != null
              ? ({required CampaignActor actor}) async {
                  final token = await widget.controller.authController
                      .ensureValidAccessToken();
                  if (token == null) return '登录已过期，请重新登录';
                  final success = await widget.actorController!.archiveActor(
                    actor,
                  );
                  return success
                      ? null
                      : (widget.actorController!.error ?? '归档失败');
                }
              : null,
          onConvertToPersistent: _canManage && widget.actorController != null
              ? ({required CampaignActor actor}) async {
                  final token = await widget.controller.authController
                      .ensureValidAccessToken();
                  if (token == null) return '登录已过期，请重新登录';
                  final success = await widget.actorController!
                      .convertToPersistent(actor);
                  return success
                      ? null
                      : (widget.actorController!.error ?? '转为常驻失败');
                }
              : null,
          onBatchArchive: _canManage && widget.actorController != null
              ? ({required List<String> actorIds}) async {
                  final token = await widget.controller.authController
                      .ensureValidAccessToken();
                  if (token == null) return '登录已过期，请重新登录';
                  var lastError = '归档失败';
                  for (final id in actorIds) {
                    final actor = _actors
                        .where((candidate) => candidate.id == id)
                        .firstOrNull;
                    if (actor == null) continue;
                    final success = await widget.actorController!.archiveActor(
                      actor,
                    );
                    if (!success) {
                      lastError = widget.actorController!.error ?? lastError;
                    }
                  }
                  return lastError == '归档失败' && actorIds.isNotEmpty
                      ? null
                      : lastError;
                }
              : null,
          onSetActiveSpeaker: _canManage
              ? ({required CampaignActor actor}) async {
                  final success = await widget.controller.updateSpeaker(
                    campaignId: widget.campaign.id,
                    speakerMode: 'actor',
                    actorId: actor.id,
                  );
                  return success
                      ? null
                      : (widget.controller.workspaceContextError ?? '切换发言身份失败');
                }
              : null,
        );
      case 2:
        return CampaignArchivePanel(
          entries: widget.controller.archives,
          isLoading: widget.controller.isArchivesLoading,
          error: widget.controller.archivesError,
          canManage: _canManage,
          selectedKind: _archiveKind,
          onKindChanged: (kind) {
            setState(() => _archiveKind = kind);
            widget.controller.loadArchives(widget.campaign.id, kind: kind);
          },
          onRefresh: () => widget.controller.loadArchives(widget.campaign.id),
          onArchive: (entry) => widget.controller.archiveEntry(
            campaignId: widget.campaign.id,
            entryId: entry.id,
          ),
        );
      case 3:
        return CampaignRecordsPanel(
          messages: widget.controller.messages,
          onSearch: (query) => widget.controller.searchMessages(
            widget.campaign.id,
            query: query,
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  void _openActorSheet(CampaignActor actor) {
    final controller = widget.actorController;
    if (controller == null) return;
    openCampaignActorSheet(
      context: context,
      controller: controller,
      actor: actor,
      canEditAnyActor: _canManage,
    );
  }

  Future<void> _showCreateArchiveDialog({String initialKind = 'clue'}) async {
    var kind = initialKind;
    final title = TextEditingController();
    final summary = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final create = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建战役条目'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: kind,
                decoration: const InputDecoration(labelText: '类型'),
                items: const [
                  DropdownMenuItem(value: 'clue', child: Text('线索')),
                  DropdownMenuItem(value: 'location', child: Text('地点')),
                  DropdownMenuItem(value: 'document', child: Text('文档')),
                  DropdownMenuItem(value: 'file', child: Text('文件')),
                ],
                onChanged: (value) => kind = value ?? kind,
              ),
              TextFormField(
                controller: title,
                autofocus: true,
                decoration: const InputDecoration(labelText: '名称'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '请输入名称' : null,
              ),
              TextField(
                controller: summary,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: '说明（可选）'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
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
    if (create != true || !mounted) return;
    final entry = await widget.controller.createArchiveEntry(
      campaignId: widget.campaign.id,
      kind: kind,
      title: title.text,
      summary: summary.text,
    );
    title.dispose();
    summary.dispose();
    if (!mounted || entry != null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.controller.archivesError ?? '创建失败')),
    );
  }

  /// Spec §概览: DM 在概览面板看到控场摘要、群体检定和遭遇准备入口。
  /// 控场入口从聊天工具栏迁移到战役中心 → 概览, 与 spec 一致。
  Future<void> _showDmControlSheet() {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DM 控场', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text('这里会继续整合遭遇、成员状态和隐藏信息。'),
                const SizedBox(height: 12),
                const ListTile(
                  leading: Icon(Icons.shield_outlined),
                  title: Text('遭遇控场'),
                  subtitle: Text('管理先攻、回合、敌人生命值和状态'),
                ),
                const ListTile(
                  leading: Icon(Icons.group_outlined),
                  title: Text('成员状态'),
                  subtitle: Text('查看角色 HP、AC、状态和可见信息'),
                ),
              ],
            ),
          ),
        );
      },
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

  /// Spec §全局设置: 所有权转移、战役归档、离开战役三项暂未实现的服务端
  /// 操作，统一显示"开发中"提示，避免静默无反馈。
  void _showNotImplemented() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('该功能正在开发中')));
  }
}
