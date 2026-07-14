import 'package:flutter/material.dart';

import '../../../core/backup/local_data_archive_service.dart';
import '../../../core/sync/sync_status_controller.dart';
import '../../../core/sync/sync_status_tile.dart';
import '../../app_preferences/presentation/app_preferences_controller.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_page.dart';
import '../../client_mode/domain/client_mode.dart';
import '../../content/data/import/content_package_importer.dart';
import '../../content/data/local/content_repository.dart';
import '../../content/domain/content_file_picker.dart';
import '../../content/presentation/content_package_settings_page.dart';
import '../../server_profiles/data/server_profile_store.dart';
import '../../server_profiles/domain/server_profile.dart';
import '../../vault/presentation/vault_settings_section.dart';
import '../../vault/presentation/vault_sync_controller.dart';
import '../domain/active_server_session.dart';
import 'data_management_page.dart';

/// Top-level "设置" tab.
///
/// Shows server info, account state (login entry or logged-in user with
/// logout), and the Player/DM mode switch.
class SettingsTabPage extends StatefulWidget {
  const SettingsTabPage({
    required this.session,
    required this.modeController,
    required this.authController,
    required this.appPreferencesController,
    required this.syncStatusController,
    this.serverProfileStore,
    this.serverProfilesPageBuilder,
    this.onSwitchToProfile,
    this.contentRepository,
    this.contentImporter,
    this.contentFilePicker,
    this.vaultSyncActions,
    this.archiveService,
    super.key,
  });

  final ActiveServerSession session;
  final ClientModeController modeController;
  final AuthController authController;
  final AppPreferencesController appPreferencesController;
  final SyncStatusController syncStatusController;
  final ServerProfileStore? serverProfileStore;
  final WidgetBuilder? serverProfilesPageBuilder;
  final ValueChanged<ServerProfile>? onSwitchToProfile;
  final ContentRepository? contentRepository;
  final ContentPackageImporter? contentImporter;
  final ContentFilePicker? contentFilePicker;
  final VaultSyncActions? vaultSyncActions;
  final LocalDataArchiveService? archiveService;

  @override
  State<SettingsTabPage> createState() => _SettingsTabPageState();
}

class _SettingsTabPageState extends State<SettingsTabPage> {
  List<ServerProfile> _allProfiles = const [];

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final store = widget.serverProfileStore;
    if (store == null) return;
    final profiles = await store.listProfiles();
    if (!mounted) return;
    setState(() {
      _allProfiles = profiles;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.modeController,
        widget.authController,
        widget.session,
        widget.syncStatusController,
      ]),
      builder: (context, _) {
        return AnimatedBuilder(
          animation: widget.appPreferencesController,
          builder: (context, _) {
            return Scaffold(
              appBar: AppBar(title: const Text('设置')),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildServerSection(context),
                    const SizedBox(height: 24),
                    _buildSyncSection(context),
                    const SizedBox(height: 24),
                    _buildContentSection(context),
                    const SizedBox(height: 24),
                    _buildVaultSection(context),
                    const SizedBox(height: 24),
                    _buildAccountSection(context),
                    const SizedBox(height: 24),
                    _buildModeSection(context),
                    const SizedBox(height: 24),
                    _buildAppearanceSection(context),
                    const SizedBox(height: 24),
                    _buildRulesSection(context),
                    const SizedBox(height: 24),
                    _buildCharacterSheetSection(context),
                    const SizedBox(height: 24),
                    _buildGameplaySection(context),
                    const SizedBox(height: 24),
                    _buildDataSection(context),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildServerSection(BuildContext context) {
    final store = widget.serverProfileStore;
    final profile = widget.session.profile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('服务器', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              if (profile == null) ...[
                ListTile(
                  leading: const Icon(Icons.cloud_off),
                  title: const Text('尚未连接服务器'),
                  subtitle: const Text('离线模式下本地资料、角色和笔记仍可用'),
                ),
                if (widget.serverProfilesPageBuilder != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.tonalIcon(
                        onPressed: () => _openServerProfilesPage(context),
                        icon: const Icon(Icons.add),
                        label: const Text('管理服务器'),
                      ),
                    ),
                  ),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.dns_outlined),
                  title: Text(profile.name),
                  subtitle: Text(profile.baseUrl),
                ),
                ListTile(
                  leading: const Icon(Icons.tag),
                  title: Text('版本 ${profile.lastKnownVersion}'),
                  dense: true,
                ),
                if (store != null && _allProfiles.length > 1) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '切换服务器',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                  ),
                  for (final p in _allProfiles)
                    ListTile(
                      leading: Icon(
                        p.id == profile.id
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                      ),
                      title: Text(p.name),
                      subtitle: Text(p.baseUrl),
                      enabled: p.id != profile.id,
                      onTap: () => widget.onSwitchToProfile?.call(p),
                    ),
                ],
                if (widget.serverProfilesPageBuilder != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _openServerProfilesPage(context),
                        icon: const Icon(Icons.settings_outlined),
                        label: const Text('管理服务器'),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _openServerProfilesPage(BuildContext context) {
    final builder = widget.serverProfilesPageBuilder;
    if (builder == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: builder),
    );
  }

  Widget _buildSyncSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('同步', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: SyncStatusTile(
            controller: widget.syncStatusController,
            isLoggedIn: widget.authController.isLoggedIn,
          ),
        ),
      ],
    );
  }

  Widget _buildContentSection(BuildContext context) {
    final repository = widget.contentRepository;
    final importer = widget.contentImporter;
    final filePicker = widget.contentFilePicker;
    if (repository == null || importer == null || filePicker == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('资料包', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: const Text('资料包'),
            subtitle: const Text('导入、启用或删除本地资料包'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openContentPackageSettings(
              context,
              repository: repository,
              importer: importer,
              filePicker: filePicker,
            ),
          ),
        ),
      ],
    );
  }

  void _openContentPackageSettings(
    BuildContext context, {
    required ContentRepository repository,
    required ContentPackageImporter importer,
    required ContentFilePicker filePicker,
  }) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ContentPackageSettingsPage(
          repository: repository,
          importer: importer,
          filePicker: filePicker,
        ),
      ),
    );
  }

  Widget _buildVaultSection(BuildContext context) {
    final actions = widget.vaultSyncActions;
    if (actions == null) return const SizedBox.shrink();
    return VaultSettingsSection(actions: actions);
  }

  Widget _buildAccountSection(BuildContext context) {
    if (widget.authController.isLoading) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('账号'),
          SizedBox(height: 8),
          Card(child: ListTile(leading: CircularProgressIndicator())),
        ],
      );
    }

    if (!widget.authController.isLoggedIn) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('账号', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('未登录'),
              subtitle: const Text('登录后可管理战役与跑团'),
              trailing: FilledButton(
                onPressed: () => _openAuthPage(context),
                child: const Text('登录'),
              ),
            ),
          ),
        ],
      );
    }

    final user = widget.authController.user!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('账号', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.person),
                title: Text(user.username),
                subtitle: Text(user.email),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.tonalIcon(
                  onPressed: () => widget.authController.logout(),
                  icon: const Icon(Icons.logout),
                  label: const Text('退出登录'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModeSection(BuildContext context) {
    final mode = widget.modeController.mode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('客户端模式', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<ClientMode>(
                  segments: const [
                    ButtonSegment(
                      value: ClientMode.player,
                      icon: Icon(Icons.person_outline),
                      label: Text('Player'),
                    ),
                    ButtonSegment(
                      value: ClientMode.dungeonMaster,
                      icon: Icon(Icons.shield_outlined),
                      label: Text('DM'),
                    ),
                  ],
                  selected: {mode},
                  onSelectionChanged: (selection) =>
                      widget.modeController.setMode(selection.single),
                ),
                const SizedBox(height: 12),
                Text('当前模式：${mode.label}'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppearanceSection(BuildContext context) {
    final preferences = widget.appPreferencesController.preferences;
    final colors = {
      'Material 紫': const Color(0xff6750a4),
      'Material 蓝': const Color(0xff0061a4),
      'Material 绿': const Color(0xff386a20),
      'Material 青': const Color(0xff006a60),
      'Material 橙': const Color(0xff8f4c00),
      '中性色': const Color(0xff5f5e62),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('外观', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card.outlined(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_outlined),
                      label: Text('系统'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_outlined),
                      label: Text('浅色'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_outlined),
                      label: Text('深色'),
                    ),
                  ],
                  selected: {preferences.themeMode},
                  onSelectionChanged: (selection) {
                    widget.appPreferencesController.setThemeMode(selection.single);
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: preferences.dynamicSchemeVariant,
                  decoration: const InputDecoration(
                    labelText: '主题风格',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.palette_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'tonalSpot',
                      child: Text('标准 Material'),
                    ),
                    DropdownMenuItem(value: 'fidelity', child: Text('忠实取色')),
                    DropdownMenuItem(value: 'expressive', child: Text('表现力')),
                    DropdownMenuItem(value: 'vibrant', child: Text('鲜明')),
                    DropdownMenuItem(value: 'neutral', child: Text('中性')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      widget.appPreferencesController.setDynamicSchemeVariant(value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Material 3 主题色',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  '使用 seed color 生成 Material 3 tonal palette，颜色角色由 ColorScheme 统一分配。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final entry in colors.entries)
                      ChoiceChip(
                        label: Text(entry.key),
                        selected:
                            preferences.seedColorValue ==
                            entry.value.toARGB32(),
                        avatar: CircleAvatar(backgroundColor: entry.value),
                        onSelected: (_) {
                          widget.appPreferencesController.setSeedColor(entry.value);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.contrast_outlined),
                  title: const Text('高对比 Material 3'),
                  subtitle: const Text('提高前景与容器色差，适合长时间跑团和投屏。'),
                  value: preferences.highContrastTheme,
                  onChanged: widget.appPreferencesController.setHighContrastTheme,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRulesSection(BuildContext context) {
    final preferences = widget.appPreferencesController.preferences;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('规则与角色创建', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card.outlined(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.auto_stories_outlined),
                title: const Text('默认规则集'),
                subtitle: const Text('决定新角色创建时优先使用的规则来源'),
                trailing: DropdownButton<String>(
                  value: preferences.ruleset,
                  items: const [
                    DropdownMenuItem(value: 'dnd2024', child: Text('D&D 2024')),
                    DropdownMenuItem(value: 'dnd2014', child: Text('D&D 2014')),
                    DropdownMenuItem(value: 'mixed', child: Text('混合')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      widget.appPreferencesController.setRuleset(value);
                    }
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.route_outlined),
                title: const Text('默认创建方式'),
                subtitle: const Text('新建角色时默认推荐的创建路径'),
                trailing: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'quick', label: Text('快速')),
                    ButtonSegment(value: 'standard', label: Text('标准')),
                  ],
                  selected: {preferences.defaultCreationMethod},
                  onSelectionChanged: (selection) {
                    widget.appPreferencesController.setDefaultCreationMethod(
                      selection.single,
                    );
                  },
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.history_edu_outlined),
                title: const Text('显示 Legacy 内容'),
                subtitle: const Text('允许在资料库和角色创建中显示旧版内容提示'),
                value: preferences.showLegacyContent,
                onChanged: widget.appPreferencesController.setShowLegacyContent,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCharacterSheetSection(BuildContext context) {
    final preferences = widget.appPreferencesController.preferences;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('角色卡', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card.outlined(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.tab_outlined),
                title: const Text('默认角色卡标签'),
                subtitle: const Text('打开角色详情时优先关注的页面'),
                trailing: DropdownButton<String>(
                  value: preferences.defaultCharacterTab,
                  items: const [
                    DropdownMenuItem(value: 'overview', child: Text('总览')),
                    DropdownMenuItem(value: 'actions', child: Text('动作')),
                    DropdownMenuItem(value: 'spells', child: Text('法术')),
                    DropdownMenuItem(value: 'equipment', child: Text('装备')),
                    DropdownMenuItem(value: 'status', child: Text('状态')),
                    DropdownMenuItem(value: 'features', child: Text('特性')),
                    DropdownMenuItem(value: 'details', child: Text('详情')),
                    DropdownMenuItem(value: 'notes', child: Text('笔记')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      widget.appPreferencesController.setDefaultCharacterTab(value);
                    }
                  },
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.account_tree_outlined),
                title: const Text('显示字段来源'),
                subtitle: const Text('显示属性、熟练、特性来自职业、起源或手动覆盖'),
                value: preferences.showCharacterSources,
                onChanged: widget.appPreferencesController.setShowCharacterSources,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.inventory_2_outlined),
                title: const Text('显示负重'),
                subtitle: const Text('在装备页显示重量和负重相关信息'),
                value: preferences.showEncumbrance,
                onChanged: widget.appPreferencesController.setShowEncumbrance,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGameplaySection(BuildContext context) {
    final preferences = widget.appPreferencesController.preferences;
    final diceController = TextEditingController(text: preferences.defaultDice);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('跑团偏好', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card.outlined(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.casino_outlined),
                title: const Text('默认骰子'),
                subtitle: TextField(
                  controller: diceController,
                  decoration: const InputDecoration(
                    hintText: '1d20',
                    isDense: true,
                  ),
                  onSubmitted: widget.appPreferencesController.setDefaultDice,
                ),
                trailing: FilledButton.tonal(
                  onPressed: () {
                    widget.appPreferencesController.setDefaultDice(
                      diceController.text,
                    );
                  },
                  child: const Text('保存'),
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.view_agenda_outlined),
                title: const Text('列表密度'),
                subtitle: const Text('在角色、资料和战役列表中优先显示更多内容'),
                value: preferences.compactLists,
                onChanged: widget.appPreferencesController.setCompactLists,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.fact_check_outlined),
                title: const Text('掷骰确认'),
                subtitle: const Text('掷出默认骰子前先确认，避免误触'),
                value: preferences.confirmBeforeRoll,
                onChanged: widget.appPreferencesController.setConfirmBeforeRoll,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.receipt_long_outlined),
                title: const Text('角色状态写入日志'),
                subtitle: const Text('在线跑团时把 HP、休息和状态变化记录到当前场次日志'),
                value: preferences.logCharacterRuntimeChanges,
                onChanged:
                    widget.appPreferencesController.setLogCharacterRuntimeChanges,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openAuthPage(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => AuthPage(authController: widget.authController),
      ),
    );
  }

  Widget _buildDataSection(BuildContext context) {
    final service = widget.archiveService;
    if (service == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('数据', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('数据管理'),
            subtitle: const Text('备份、恢复、清理战役缓存或重建资料索引'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openDataManagementPage(context, service),
          ),
        ),
      ],
    );
  }

  void _openDataManagementPage(
    BuildContext context,
    LocalDataArchiveService service,
  ) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DataManagementPage(archiveService: service),
      ),
    );
  }
}
