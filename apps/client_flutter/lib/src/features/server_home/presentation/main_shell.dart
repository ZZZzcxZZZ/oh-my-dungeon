import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/backup/drift_local_data_archive_service.dart';
import '../../../core/backup/local_backup_models.dart';
import '../../../core/backup/local_data_archive_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_repository.dart';
import '../../../core/sync/sync_status_controller.dart';
import '../../../features/app_preferences/presentation/app_preferences_controller.dart';
import '../../../features/auth/data/auth_api_client.dart';
import '../../../features/auth/data/auth_token_store.dart';
import '../../../features/auth/presentation/auth_controller.dart';
import '../../../features/campaigns/data/campaign_api_client.dart';
import '../../../features/campaigns/data/campaign_socket_service.dart';
import '../../../features/campaigns/data/local/campaign_cache_repository.dart';
import '../../../features/campaigns/data/socket_io_campaign_socket_service.dart';
import '../../../features/campaigns/data/sync/campaign_sync_api_client.dart';
import '../../../features/campaigns/data/sync/campaign_actor_backlink_service.dart';
import '../../../features/campaigns/data/sync/campaign_sync_service.dart';
import '../../../features/campaigns/presentation/actors/campaign_actor_controller.dart';
import '../../../features/campaigns/presentation/content/campaign_content_controller.dart';
import '../../../features/campaigns/presentation/campaign_controller.dart';
import '../../../features/campaigns/presentation/campaigns_tab_page.dart';
import '../../../features/characters/data/character_repository.dart';
import '../../../features/characters/data/local/character_sync_conflict_repository.dart';
import '../../../features/characters/data/local/drift_character_repository.dart';
import '../../../features/characters/presentation/character_conflict_banner_controller.dart';
import '../../../features/characters/presentation/character_controller.dart';
import '../../../features/characters/presentation/characters_tab_page.dart';
import '../../../features/client_mode/domain/client_mode.dart';
import '../../../features/content/data/import/content_package_importer.dart';
import '../../../features/content/data/import/bundled_content_installer.dart';
import '../../../features/content/data/campaign_aware_content_repository.dart';
import '../../../features/content/data/local/content_repository.dart';
import '../../../features/content/domain/content_file_picker.dart';
import '../../../features/content/presentation/content_library_controller.dart';
import '../../../features/content/presentation/content_library_page.dart';
import '../../../features/content/presentation/content_package_settings_page.dart';
import '../../../features/encounters/data/encounter_api_client.dart';
import '../../../features/encounters/presentation/encounter_controller.dart';
import '../../../core/dice/dice_roller.dart';
import '../../../features/server_profiles/domain/server_profile.dart';
import '../../../features/server_profiles/data/server_profile_store.dart';
import '../../../features/vault/data/drift_vault_change_applier.dart';
import '../../../features/vault/data/vault_api_client.dart';
import '../../../features/vault/domain/vault_models.dart';
import '../../../features/vault/presentation/vault_sync_controller.dart';
import '../domain/active_server_session.dart';
import 'home_dashboard_page.dart';
import 'content_bootstrap_gate.dart';
import 'settings_tab_page.dart';

/// Bottom-navigation shell shown after a server profile is selected.
///
/// The shell preserves tab state via [IndexedStack] so switching tabs does not
/// reload data.
class MainShell extends StatefulWidget {
  const MainShell({
    required this.session,
    required this.modeController,
    required this.authTokenStore,
    required this.authClient,
    required this.campaignClient,
    this.campaignSocketService,
    required this.appPreferencesController,
    this.database,
    this.diceRoller,
    this.serverProfileStore,
    this.serverProfilesPageBuilder,
    this.onSwitchToProfile,
    this.enableBackgroundSync = true,
    this.bundledContentLoader,
    super.key,
  });

  final ActiveServerSession session;
  final ClientModeController modeController;
  final AuthTokenStore authTokenStore;
  final AuthClient authClient;
  final CampaignClient campaignClient;
  final CampaignSocketService? campaignSocketService;
  final AppPreferencesController appPreferencesController;
  final AppDatabase? database;
  final DiceRoller? diceRoller;
  final ServerProfileStore? serverProfileStore;
  final WidgetBuilder? serverProfilesPageBuilder;
  final ValueChanged<ServerProfile>? onSwitchToProfile;
  final bool enableBackgroundSync;
  final Future<String> Function()? bundledContentLoader;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late final AuthController _authController;
  late final CampaignController _campaignController;
  late final CharacterController _characterController;
  late final CharacterRepository _characterRepository;
  late final ContentRepository _localContentRepository;
  late final ContentRepository _contentRepository;
  late final CampaignCacheRepository _campaignCacheRepository;
  late final ContentPackageImporter _contentImporter;
  late final ContentLibraryController _libraryController;
  late final CampaignSocketService _campaignSocketService;
  late final CampaignActorController _actorController;
  late final CampaignContentController _campaignContentController;
  late final EncounterController _encounterController;
  CampaignActorBacklinkService? _backlinkService;
  CampaignSyncService? _campaignSyncService;
  CharacterConflictBannerController? _conflictBannerController;
  VaultSyncController? _vaultSyncController;
  late final LocalDataArchiveService _archiveService;
  final SyncStatusController _syncStatusController = SyncStatusController();
  final ContentFilePicker _contentFilePicker =
      const FilePickerContentFilePicker();
  int _currentIndex = 0;
  String? _activeCampaignId;
  String? _deviceId;
  late final Future<void> _contentBootstrap;

  @override
  void initState() {
    super.initState();
    widget.modeController.addListener(_onModeChanged);
    final profile = widget.session.profile;
    _authController = AuthController(
      tokenStore: widget.authTokenStore,
      authClient: widget.authClient,
      serverProfileId: profile?.id ?? '',
      apiBaseUrl: profile?.apiBaseUrl ?? '',
    )..initialize();
    _campaignSocketService =
        widget.campaignSocketService ?? SocketIoCampaignSocketService();
    // Spec §双向同步 切片 A: socket 收到 campaign:changed 信号时触发
    // actorController 增量拉取。闭包延迟引用 _actorController，它在下方
    // 才初始化，但闭包只在 connectCampaignChat 时调用，那时已就绪。
    _campaignController = CampaignController(
      apiBaseUrl: profile?.apiBaseUrl ?? '',
      authController: _authController,
      campaignClient: widget.campaignClient,
      campaignSocketService: _campaignSocketService,
      onCampaignChanged: () => _actorController.pullUntilCurrent(),
    );
    _characterRepository = widget.database != null
        ? DriftCharacterRepository(widget.database!)
        : EmptyCharacterRepository();
    _characterController = CharacterController(
      repository: _characterRepository,
    );
    _localContentRepository = widget.database != null
        ? DriftContentRepository(widget.database!)
        : EmptyContentRepository();
    _campaignCacheRepository = widget.database != null
        ? DriftCampaignCacheRepository(widget.database!)
        : EmptyCampaignCacheRepository();
    _contentRepository = CampaignAwareContentRepository(
      local: _localContentRepository,
      campaign: _campaignCacheRepository,
      activeCampaignId: () => _activeCampaignId,
    );
    _contentImporter = ContentPackageImporter(_localContentRepository);
    _libraryController = ContentLibraryController(
      repository: _contentRepository,
    );
    _contentBootstrap = _installBundledContent();
    // Spec §双向同步 切片 A: backlinkService 提前构造，供 _actorController
    // 发布成功回写本地角色，也供 _campaignSyncService 拉取循环复用。
    _backlinkService = widget.database != null
        ? CampaignActorBacklinkService(
            characterRepository: _characterRepository,
            database: widget.database!,
          )
        : null;
    // Spec §双向同步 切片 B: conflictBannerController 监听所有未解决冲突，
    // 角色列表页 banner + 冲突解决页共用。
    _conflictBannerController = widget.database != null
        ? CharacterConflictBannerController(
            repository: DriftCharacterSyncConflictRepository(widget.database!),
          )
        : null;
    _actorController = CampaignActorController(
      cacheRepository: _campaignCacheRepository,
      apiClient: HttpCampaignSyncApiClient(),
      apiBaseUrl: profile?.apiBaseUrl ?? '',
      accessToken: _authController.accessToken ?? '',
      currentUserId: _authController.user?.id ?? '',
      accessTokenProvider: () => _authController.accessToken ?? '',
      currentUserIdProvider: () => _authController.user?.id ?? '',
      onActorPublished: _backlinkService?.applyActorToCharacter,
    );
    _campaignContentController = CampaignContentController(
      cacheRepository: _campaignCacheRepository,
      apiClient: HttpCampaignSyncApiClient(),
      apiBaseUrl: profile?.apiBaseUrl ?? '',
      accessToken: _authController.accessToken ?? '',
      currentUserId: _authController.user?.id ?? '',
      accessTokenProvider: () => _authController.accessToken ?? '',
      currentUserIdProvider: () => _authController.user?.id ?? '',
    );
    // Spec §遭遇控场: 共享给战役中心的 DM 控场底部页, 让 DM 在战役进行中
    // 快速管理遭遇 HP / 推进回合.
    _encounterController = EncounterController(
      apiBaseUrl: profile?.apiBaseUrl ?? '',
      authController: _authController,
      encounterClient: EncounterApiClient(),
    );
    if (widget.database != null && widget.enableBackgroundSync) {
      _campaignSyncService = CampaignSyncService(
        cacheRepository: _campaignCacheRepository,
        apiClient: HttpCampaignSyncApiClient(),
        backlinkService: _backlinkService!,
      );
      _vaultSyncController = VaultSyncController(
        syncRepository: DriftSyncRepository(widget.database!),
        apiClient: HttpVaultApiClient(),
        changeApplier: DriftVaultChangeApplier(widget.database!),
      );
    }
    _archiveService = widget.database != null
        ? DriftLocalDataArchiveService(widget.database!)
        : _NullLocalDataArchiveService();
    _authController.addListener(_onAuthChanged);
    _initializeDeviceIdentity();
  }

  @override
  void dispose() {
    widget.modeController.removeListener(_onModeChanged);
    _authController.removeListener(_onAuthChanged);
    _campaignSocketService.disconnect();
    _actorController.dispose();
    _campaignContentController.dispose();
    _encounterController.dispose();
    _libraryController.dispose();
    _characterController.dispose();
    _campaignController.dispose();
    _authController.dispose();
    _syncStatusController.dispose();
    _vaultSyncController?.dispose();
    _conflictBannerController?.dispose();
    super.dispose();
  }

  void _onModeChanged() {
    if (mounted) setState(() {});
  }

  void _onAuthChanged() {
    _configureVault();
  }

  Future<void> _initializeDeviceIdentity() async {
    final preferences = await SharedPreferences.getInstance();
    const key = 'dnd_table.device_id';
    final existing = preferences.getString(key);
    _deviceId =
        existing ??
        'device-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    if (existing == null) {
      await preferences.setString(key, _deviceId!);
    }
    _configureVault();
  }

  void _configureVault() {
    final controller = _vaultSyncController;
    final profile = widget.session.profile;
    final user = _authController.user;
    final token = _authController.accessToken;
    final deviceId = _deviceId;
    if (controller == null ||
        profile == null ||
        user == null ||
        token == null ||
        deviceId == null) {
      controller?.configure(null);
      return;
    }
    controller.configure(
      VaultSession(
        remoteUserId: user.id,
        deviceId: deviceId,
        baseUrl: profile.baseUrl,
        accessToken: token,
      ),
    );
    controller.refresh();
  }

  Future<void> _installBundledContent() async {
    if (widget.database == null) return;
    final installed = await BundledContentInstaller(
      repository: _localContentRepository,
      loadBundle: widget.bundledContentLoader,
    ).installIfAvailable();
    if (installed && mounted) {
      await _libraryController.refresh();
    }
  }

  Future<void> _activateCampaign(String campaignId) async {
    _activeCampaignId = campaignId;
    if (widget.enableBackgroundSync) {
      await Future.wait([
        _actorController.selectCampaign(campaignId),
        _campaignContentController.selectCampaign(campaignId),
      ]);
    }

    final profile = widget.session.profile;
    final token = _authController.accessToken;
    final user = _authController.user;
    final service = _campaignSyncService;
    if (widget.enableBackgroundSync &&
        profile != null &&
        token != null &&
        user != null &&
        service != null) {
      await service.pullUntilCurrent(
        apiBaseUrl: profile.apiBaseUrl,
        accessToken: token,
        deviceId: _deviceId ?? '',
        campaignId: campaignId,
        userId: user.id,
      );
    } else {
      await _actorController.pullUntilCurrent();
    }
    if (mounted) setState(() {});
  }

  void _openContentPackageSettings(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ContentPackageSettingsPage(
          repository: _contentRepository,
          importer: _contentImporter,
          filePicker: _contentFilePicker,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ContentBootstrapGate(
      future: _contentBootstrap,
      builder: _buildReadyShell,
    );
  }

  Widget _buildReadyShell(BuildContext context) {
    final pages = [
      HomeDashboardPage(
        session: widget.session,
        modeController: widget.modeController,
        authController: _authController,
        campaignController: _campaignController,
        characterController: _characterController,
        onNavigateToTab: (index) => setState(() => _currentIndex = index),
      ),
      CampaignsTabPage(
        session: widget.session,
        authController: _authController,
        campaignController: _campaignController,
        characterController: _characterController,
        contentRepository: _contentRepository,
        modeController: widget.modeController,
        appPreferencesController: widget.appPreferencesController,
        diceRoller: widget.diceRoller,
        onCampaignOpened: _activateCampaign,
        campaignContentController: _campaignContentController,
        actorController: _actorController,
        encounterController: _encounterController,
      ),
      CharactersTabPage(
        controller: _characterController,
        campaignController: _campaignController,
        contentRepository: _contentRepository,
        localContentRepository: _localContentRepository,
        onCampaignContentSelected: _activateCampaign,
        appPreferencesController: widget.appPreferencesController,
        modeController: widget.modeController,
        actorController: _actorController,
        conflictBannerController: _conflictBannerController,
      ),
      ContentLibraryPage(
        controller: _libraryController,
        onImportRequested: () => _openContentPackageSettings(context),
      ),
      SettingsTabPage(
        session: widget.session,
        modeController: widget.modeController,
        authController: _authController,
        appPreferencesController: widget.appPreferencesController,
        syncStatusController: _syncStatusController,
        serverProfileStore: widget.serverProfileStore,
        serverProfilesPageBuilder: widget.serverProfilesPageBuilder,
        onSwitchToProfile: widget.onSwitchToProfile,
        contentRepository: _contentRepository,
        contentImporter: _contentImporter,
        contentFilePicker: _contentFilePicker,
        vaultSyncActions: _vaultSyncController,
        archiveService: _archiveService,
      ),
    ];
    final body = IndexedStack(index: _currentIndex, children: pages);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 840) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (index) {
                    setState(() => _currentIndex = index);
                  },
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    const NavigationRailDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard),
                      label: Text('首页'),
                    ),
                    const NavigationRailDestination(
                      icon: Icon(Icons.castle_outlined),
                      selectedIcon: Icon(Icons.castle),
                      label: Text('战役'),
                    ),
                    const NavigationRailDestination(
                      icon: Icon(Icons.badge_outlined),
                      selectedIcon: Icon(Icons.badge),
                      label: Text('角色'),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.menu_book_outlined),
                      selectedIcon: const Icon(Icons.menu_book),
                      label: Text(_contentLabel),
                    ),
                    const NavigationRailDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings),
                      label: Text('设置'),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
          );
        }

        return Scaffold(
          body: body,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
            },
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: '首页',
              ),
              const NavigationDestination(
                icon: Icon(Icons.castle_outlined),
                selectedIcon: Icon(Icons.castle),
                label: '战役',
              ),
              const NavigationDestination(
                icon: Icon(Icons.badge_outlined),
                selectedIcon: Icon(Icons.badge),
                label: '角色',
              ),
              NavigationDestination(
                icon: const Icon(Icons.menu_book_outlined),
                selectedIcon: const Icon(Icons.menu_book),
                label: _contentLabel,
              ),
              const NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: '设置',
              ),
            ],
          ),
        );
      },
    );
  }

  String get _contentLabel {
    return widget.modeController.mode == ClientMode.dungeonMaster
        ? '内容库'
        : '资料库';
  }
}

/// Fallback archive service used when no [AppDatabase] is attached.
///
/// All operations throw [UnsupportedError] so callers surface a clear message
/// instead of silently producing an empty archive.
class _NullLocalDataArchiveService implements LocalDataArchiveService {
  @override
  Future<Uint8List> exportArchive() =>
      throw UnsupportedError('Local database unavailable');
  @override
  Future<ArchivePreview> previewArchive(Uint8List bytes) =>
      throw UnsupportedError('Local database unavailable');
  @override
  Future<void> restoreArchive(ArchivePreview preview) =>
      throw UnsupportedError('Local database unavailable');
  @override
  Future<void> clearCampaignCache() =>
      throw UnsupportedError('Local database unavailable');
  @override
  Future<void> rebuildContentIndex() =>
      throw UnsupportedError('Local database unavailable');
}
