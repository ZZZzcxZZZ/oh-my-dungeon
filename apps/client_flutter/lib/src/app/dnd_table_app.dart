import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/database/app_database.dart';
import '../features/app_preferences/data/app_preferences_store.dart';
import '../features/app_preferences/domain/app_preferences.dart';
import '../features/app_preferences/presentation/app_preferences_controller.dart';
import '../features/auth/data/auth_api_client.dart';
import '../features/auth/data/auth_token_store.dart';
import '../features/campaigns/data/campaign_api_client.dart';
import '../features/campaigns/data/campaign_socket_service.dart';
import '../features/client_mode/domain/client_mode.dart';
import '../core/dice/dice_roller.dart';
import '../features/server_home/domain/active_server_session.dart';
import '../features/server_profiles/data/drift_server_profile_store.dart';
import '../features/server_profiles/data/server_discovery_client.dart';
import '../features/server_profiles/data/server_profile_migrator.dart';
import '../features/server_profiles/data/server_profile_store.dart';
import '../features/server_profiles/presentation/server_profiles_page.dart';
import '../features/server_home/presentation/main_shell.dart';

class DndTableApp extends StatefulWidget {
  const DndTableApp({
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

  @override
  State<DndTableApp> createState() => _DndTableAppState();
}

class _DndTableAppState extends State<DndTableApp> {
  late final ClientModeController _modeController;
  late final bool _ownsModeController;
  AppPreferencesController? _ownedPreferencesController;
  late final Future<_AppDeps> _depsFuture;
  final ActiveServerSession _session = ActiveServerSession();
  AppDatabase? _ownedDatabase;

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
    _ownedDatabase?.close();
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
    if (injectedDatabase != null) {
      database = injectedDatabase;
    } else if (_ownedDatabase != null) {
      database = _ownedDatabase!;
    } else {
      _ownedDatabase = AppDatabase();
      database = _ownedDatabase!;
    }

    final ServerProfileStore serverProfileStore;
    if (injectedStore != null) {
      serverProfileStore = injectedStore;
    } else {
      serverProfileStore = DriftServerProfileStore(database);
      final prefs = preferences ?? await SharedPreferences.getInstance();
      await ServerProfileMigrator(database, prefs).run();
    }

    return _AppDeps(
      database: database,
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
    return MainShell(
      key: ValueKey(_session.profile?.id),
      session: _session,
      modeController: _modeController,
      authTokenStore: deps.authTokenStore,
      authClient: deps.authClient,
      campaignClient: deps.campaignClient,
      campaignSocketService: widget.campaignSocketService,
      appPreferencesController: deps.appPreferencesController,
      database: deps.database,
      diceRoller: widget.diceRoller,
      enableBackgroundSync: widget.enableBackgroundSync,
      serverProfileStore: deps.serverProfileStore,
      serverProfilesPageBuilder: (context) => ServerProfilesPage(
        store: deps.serverProfileStore,
        discoveryClient: widget.discoveryClient ?? ServerDiscoveryClient(),
        onProfileActivated: (activated) async {
          await deps.serverProfileStore.setDefaultProfileId(activated.id);
          _session.activate(activated);
        },
      ),
      onSwitchToProfile: (profile) async {
        await deps.serverProfileStore.setDefaultProfileId(profile.id);
        _session.activate(profile);
      },
    );
  }

  Widget _buildMaterialApp({
    required AppPreferences preferences,
    required Widget home,
  }) {
    final contrastLevel = preferences.highContrastTheme ? 0.5 : 0.0;
    final lightScheme = ColorScheme.fromSeed(
      seedColor: preferences.seedColor,
      contrastLevel: contrastLevel,
      dynamicSchemeVariant: _dynamicSchemeVariant(
        preferences.dynamicSchemeVariant,
      ),
    );
    final darkScheme = ColorScheme.fromSeed(
      seedColor: preferences.seedColor,
      brightness: Brightness.dark,
      contrastLevel: contrastLevel,
      dynamicSchemeVariant: _dynamicSchemeVariant(
        preferences.dynamicSchemeVariant,
      ),
    );
    return MaterialApp(
      title: 'D&D Table Tool',
      debugShowCheckedModeBanner: false,
      themeMode: preferences.themeMode,
      theme: ThemeData(useMaterial3: true, colorScheme: lightScheme),
      darkTheme: ThemeData(useMaterial3: true, colorScheme: darkScheme),
      home: home,
    );
  }

  DynamicSchemeVariant _dynamicSchemeVariant(String value) {
    return switch (value) {
      'fidelity' => DynamicSchemeVariant.fidelity,
      'expressive' => DynamicSchemeVariant.expressive,
      'vibrant' => DynamicSchemeVariant.vibrant,
      'neutral' => DynamicSchemeVariant.neutral,
      _ => DynamicSchemeVariant.tonalSpot,
    };
  }
}

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
    required this.serverProfileStore,
    required this.authTokenStore,
    required this.appPreferencesController,
    required this.authClient,
    required this.campaignClient,
  });

  final AppDatabase? database;
  final ServerProfileStore serverProfileStore;
  final AuthTokenStore authTokenStore;
  final AppPreferencesController appPreferencesController;
  final AuthClient authClient;
  final CampaignClient campaignClient;
}
