import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/database/app_database.dart';
import '../core/workspace/legacy_bootstrap_migrator.dart';
import '../core/workspace/legacy_workspace_migrator.dart';
import '../core/workspace/workspace_database_factory.dart';
import '../core/workspace/workspace_session_coordinator.dart';
import '../core/workspace/workspace_storage_manager.dart';
import 'theme/app_theme.dart';
import '../features/app_preferences/data/app_preferences_store.dart';
import '../features/app_preferences/domain/app_preferences.dart';
import '../features/app_preferences/presentation/app_preferences_controller.dart';
import '../features/auth/data/auth_api_client.dart';
import '../features/auth/data/auth_token_store.dart';
import '../features/auth/domain/auth_session.dart';
import '../features/campaigns/data/campaign_api_client.dart';
import '../features/campaigns/data/campaign_socket_service.dart';
import '../features/client_mode/data/client_mode_store.dart';
import '../features/client_mode/domain/client_mode.dart';
import '../core/dice/dice_roller.dart';
import '../features/server_home/domain/active_server_session.dart';
import '../features/server_profiles/data/drift_server_profile_store.dart';
import '../features/server_profiles/data/server_discovery_client.dart';
import '../features/server_profiles/data/bundled_default_server_seeder.dart';
import '../features/server_profiles/data/server_profile_migrator.dart';
import '../features/server_profiles/data/server_profile_store.dart';
import '../features/server_profiles/presentation/server_profiles_page.dart';
import '../features/server_home/presentation/main_shell.dart';
import 'app_identity.dart';

class OhMyDungeonApp extends StatefulWidget {
  const OhMyDungeonApp({
    this.database,
    this.serverProfileStore,
    this.authTokenStore,
    this.discoveryClient,
    this.authClient,
    this.campaignClient,
    this.campaignSocketService,
    this.modeController,
    this.appPreferencesController,
    this.diceRoller,
    this.enableBackgroundSync = true,
    this.bundledContentLoader,
    super.key,
  });

  final AppDatabase? database;
  final ServerProfileStore? serverProfileStore;
  final AuthTokenStore? authTokenStore;
  final ServerDiscoveryClient? discoveryClient;
  final AuthClient? authClient;
  final CampaignClient? campaignClient;
  final CampaignSocketService? campaignSocketService;
  final ClientModeController? modeController;
  final AppPreferencesController? appPreferencesController;
  final DiceRoller? diceRoller;
  final bool enableBackgroundSync;
  final Future<String> Function()? bundledContentLoader;

  @override
  State<OhMyDungeonApp> createState() => _OhMyDungeonAppState();
}

class _OhMyDungeonAppState extends State<OhMyDungeonApp> {
  late ClientModeController _modeController;
  late bool _ownsModeController;
  AppPreferencesController? _ownedPreferencesController;
  late final Future<_AppDeps> _depsFuture;
  final ActiveServerSession _session = ActiveServerSession();
  AppDatabase? _ownedBootstrapDatabase;
  AppDatabase? _ownedLegacyDatabase;
  WorkspaceStorageManager? _workspaceStorage;
  WorkspaceSessionCoordinator? _workspaceCoordinator;

  @override
  void initState() {
    super.initState();
    _modeController = widget.modeController ?? ClientModeController();
    _ownsModeController = widget.modeController == null;
    _depsFuture = _createDeps().then((deps) async {
      await _session.initialize(deps.serverProfileStore);
      return deps;
    });
  }

  @override
  void dispose() {
    if (_ownsModeController) {
      _modeController.dispose();
    }
    _session.dispose();
    _ownedPreferencesController?.dispose();
    unawaited(_workspaceStorage?.dispose() ?? Future<void>.value());
    unawaited(_ownedBootstrapDatabase?.close() ?? Future<void>.value());
    unawaited(_ownedLegacyDatabase?.close() ?? Future<void>.value());
    super.dispose();
  }

  Future<_AppDeps> _createDeps() async {
    final injectedStore = widget.serverProfileStore;
    final injectedTokenStore = widget.authTokenStore;
    final injectedDatabase = widget.database;
    final useInMemoryPreferences =
        injectedStore != null &&
        injectedTokenStore != null &&
        widget.appPreferencesController == null;
    final needsSharedPreferences =
        !useInMemoryPreferences &&
        (injectedStore == null ||
            injectedTokenStore == null ||
            widget.appPreferencesController == null);
    final preferences = needsSharedPreferences
        ? await SharedPreferences.getInstance()
        : null;
    final appPreferencesController =
        widget.appPreferencesController ??
        AppPreferencesController(
          store: useInMemoryPreferences
              ? InMemoryAppPreferencesStore()
              : SharedPreferencesAppPreferencesStore(preferences!),
        );
    if (widget.appPreferencesController == null) {
      _ownedPreferencesController = appPreferencesController;
    }
    if (!appPreferencesController.initialized) {
      await appPreferencesController.initialize();
    }

    // When the caller did not inject a mode controller, upgrade the
    // placeholder to a persistent one backed by SharedPreferences so the
    // chosen DM/Player mode survives app restarts. Skip the upgrade in tests
    // that opt into the in-memory preference path (no SharedPreferences).
    if (widget.modeController == null && preferences != null) {
      final persistent = ClientModeController.withStore(
        store: SharedPreferencesClientModeStore(preferences),
      );
      await persistent.initialize();
      _modeController.dispose();
      _modeController = persistent;
    }

    final authClient = widget.authClient ?? AuthApiClient();
    final campaignClient = widget.campaignClient ?? CampaignApiClient();

    if (injectedStore != null && injectedTokenStore != null) {
      return _AppDeps(
        database: injectedDatabase,
        serverProfileStore: injectedStore,
        authTokenStore: injectedTokenStore,
        appPreferencesController: appPreferencesController,
        authClient: authClient,
        campaignClient: campaignClient,
      );
    }

    final AppDatabase database;
    final bool managedWorkspace;
    if (injectedDatabase != null) {
      database = injectedDatabase;
      managedWorkspace = false;
    } else {
      final bootstrap = _ownedBootstrapDatabase ??= AppDatabase.named(
        'bootstrap.db',
      );
      final legacy = _ownedLegacyDatabase ??= AppDatabase();
      final storage = _workspaceStorage ??= WorkspaceStorageManager(
        factory: const DriftWorkspaceDatabaseFactory(),
      );
      final coordinator = _workspaceCoordinator ??= WorkspaceSessionCoordinator(
        storage: storage,
      );
      await coordinator.initialize();
      await LegacyBootstrapMigrator(source: legacy, target: bootstrap).run();
      await LegacyWorkspaceMigrator(
        source: legacy,
        target: storage.database!,
      ).run();
      await legacy.close();
      if (identical(_ownedLegacyDatabase, legacy)) {
        _ownedLegacyDatabase = null;
      }
      database = storage.database!;
      managedWorkspace = true;
    }

    final ServerProfileStore serverProfileStore;
    if (injectedStore != null) {
      serverProfileStore = injectedStore;
    } else {
      final profileDatabase = managedWorkspace
          ? _ownedBootstrapDatabase!
          : database;
      serverProfileStore = DriftServerProfileStore(profileDatabase);
      final prefs = preferences ?? await SharedPreferences.getInstance();
      await ServerProfileMigrator(profileDatabase, prefs).run();
      // 全新安装首次启动自动加入内嵌默认服务器（仅当没有 profile 时）。
      await const BundledDefaultServerSeeder().seedIfEmpty(
        serverProfileStore,
        prefs,
      );
    }

    return _AppDeps(
      database: database,
      managedWorkspace: managedWorkspace,
      serverProfileStore: serverProfileStore,
      authTokenStore:
          injectedTokenStore ?? SharedPreferencesAuthTokenStore(preferences!),
      appPreferencesController: appPreferencesController,
      authClient: authClient,
      campaignClient: campaignClient,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AppDeps>(
      future: _depsFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildMaterialApp(
            preferences: AppPreferences.defaults,
            home: _StartupErrorPage(error: snapshot.error),
          );
        }

        final deps = snapshot.data;
        if (deps == null) {
          return _buildMaterialApp(
            preferences: AppPreferences.defaults,
            home: const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        return AnimatedBuilder(
          animation: Listenable.merge([
            deps.appPreferencesController,
            _session,
          ]),
          builder: (context, _) {
            return _buildMaterialApp(
              preferences: deps.appPreferencesController.preferences,
              home: _buildHome(deps),
            );
          },
        );
      },
    );
  }

  /// 离线优先：始终进入 MainShell，服务器会话可选。
  Widget _buildHome(_AppDeps deps) {
    final activeServerInstanceId = _session.profile?.instanceId;
    final database = deps.managedWorkspace
        ? _workspaceStorage!.database
        : deps.database;
    final workspaceGeneration = deps.managedWorkspace
        ? _workspaceStorage!.generation
        : 0;
    return MainShell(
      key: ValueKey('${_session.profile?.id}:$workspaceGeneration'),
      session: _session,
      modeController: _modeController,
      authTokenStore: deps.authTokenStore,
      authClient: deps.authClient,
      campaignClient: deps.campaignClient,
      campaignSocketService: widget.campaignSocketService,
      appPreferencesController: deps.appPreferencesController,
      database: database,
      workspaceStorageKey: deps.managedWorkspace
          ? _workspaceStorage!.identity?.storageKey
          : null,
      diceRoller: widget.diceRoller,
      enableBackgroundSync: widget.enableBackgroundSync,
      bundledContentLoader: widget.bundledContentLoader,
      serverProfileStore: deps.serverProfileStore,
      onAuthUserChanged: deps.managedWorkspace
          ? (user) => _onAuthUserChanged(
              sourceServerInstanceId: activeServerInstanceId,
              user: user,
            )
          : null,
      serverProfilesPageBuilder: (context) => ServerProfilesPage(
        store: deps.serverProfileStore,
        discoveryClient: widget.discoveryClient ?? ServerDiscoveryClient(),
        onProfileActivated: (activated) async {
          await deps.serverProfileStore.setDefaultProfileId(activated.id);
          await _changeWorkspace(() async {
            await _workspaceCoordinator?.loggedOut();
            _session.activate(activated);
          });
        },
      ),
      onSwitchToProfile: (profile) async {
        await deps.serverProfileStore.setDefaultProfileId(profile.id);
        await _changeWorkspace(() async {
          await _workspaceCoordinator?.loggedOut();
          _session.activate(profile);
        });
      },
    );
  }

  Future<void> _onAuthUserChanged({
    required String? sourceServerInstanceId,
    required AuthUser? user,
  }) async {
    final coordinator = _workspaceCoordinator;
    if (coordinator == null) return;
    final currentServerInstanceId = _session.profile?.instanceId;
    if (sourceServerInstanceId != currentServerInstanceId) return;
    await _changeWorkspace(() async {
      if (user == null || sourceServerInstanceId == null) {
        await coordinator.loggedOut();
      } else {
        await coordinator.authenticated(
          serverInstanceId: sourceServerInstanceId,
          userId: user.id,
        );
      }
    });
  }

  Future<void> _changeWorkspace(Future<void> Function() activate) async {
    await activate();
    if (!mounted) {
      await _workspaceStorage?.completeHandoff();
      return;
    }
    setState(() {});
    await WidgetsBinding.instance.endOfFrame;
    await _workspaceStorage?.completeHandoff();
  }

  Widget _buildMaterialApp({
    required AppPreferences preferences,
    required Widget home,
  }) {
    return MaterialApp(
      title: AppIdentity.productName,
      debugShowCheckedModeBanner: false,
      themeMode: preferences.themeMode,
      theme: AppTheme.light(preferences),
      darkTheme: AppTheme.dark(preferences),
      home: home,
    );
  }
}

/// Source-compatible alias for existing tests and integrations.
typedef DndTableApp = OhMyDungeonApp;

class _StartupErrorPage extends StatelessWidget {
  const _StartupErrorPage({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                  const SizedBox(height: 16),
                  Text(
                    '启动失败',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '本地预览数据可能已损坏。请清除 localhost:5173 的浏览器站点数据后刷新页面；也可以改用 http://127.0.0.1:5173 预览。',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$error',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppDeps {
  const _AppDeps({
    this.database,
    this.managedWorkspace = false,
    required this.serverProfileStore,
    required this.authTokenStore,
    required this.appPreferencesController,
    required this.authClient,
    required this.campaignClient,
  });

  final AppDatabase? database;
  final bool managedWorkspace;
  final ServerProfileStore serverProfileStore;
  final AuthTokenStore authTokenStore;
  final AppPreferencesController appPreferencesController;
  final AuthClient authClient;
  final CampaignClient campaignClient;
}
