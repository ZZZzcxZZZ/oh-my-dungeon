import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/app_preferences/data/app_preferences_store.dart';
import '../features/app_preferences/domain/app_preferences.dart';
import '../features/app_preferences/presentation/app_preferences_controller.dart';
import '../features/auth/data/auth_api_client.dart';
import '../features/auth/data/auth_token_store.dart';
import '../features/campaigns/data/campaign_api_client.dart';
import '../features/campaigns/data/campaign_socket_service.dart';
import '../features/characters/data/character_api_client.dart';
import '../features/check_requests/data/check_request_api_client.dart';
import '../features/client_mode/domain/client_mode.dart';
import '../features/content/data/content_api_client.dart';
import '../features/encounters/data/encounter_api_client.dart';
import '../features/rooms/data/room_api_client.dart';
import '../features/rooms/domain/dice_roller.dart';
import '../features/server_profiles/data/server_discovery_client.dart';
import '../features/server_profiles/data/server_profile_store.dart';
import '../features/server_profiles/domain/server_profile.dart';
import '../features/server_profiles/presentation/server_profiles_page.dart';
import '../features/sessions/data/session_api_client.dart';
import '../features/server_home/presentation/main_shell.dart';

class DndTableApp extends StatefulWidget {
  const DndTableApp({
    this.serverProfileStore,
    this.authTokenStore,
    this.discoveryClient,
    this.roomClient,
    this.authClient,
    this.campaignClient,
    this.campaignSocketService,
    this.characterClient,
    this.checkRequestClient,
    this.contentClient,
    this.encounterClient,
    this.sessionClient,
    this.modeController,
    this.appPreferencesController,
    this.diceRoller,
    super.key,
  });

  final ServerProfileStore? serverProfileStore;
  final AuthTokenStore? authTokenStore;
  final ServerDiscoveryClient? discoveryClient;
  final RoomClient? roomClient;
  final AuthClient? authClient;
  final CampaignClient? campaignClient;
  final CampaignSocketService? campaignSocketService;
  final CharacterClient? characterClient;
  final CheckRequestClient? checkRequestClient;
  final ContentClient? contentClient;
  final EncounterClient? encounterClient;
  final SessionClient? sessionClient;
  final ClientModeController? modeController;
  final AppPreferencesController? appPreferencesController;
  final DiceRoller? diceRoller;

  @override
  State<DndTableApp> createState() => _DndTableAppState();
}

class _DndTableAppState extends State<DndTableApp> {
  late final ClientModeController _modeController;
  late final bool _ownsModeController;
  AppPreferencesController? _ownedPreferencesController;
  late final Future<_AppDeps> _depsFuture;
  final _ActiveProfileNotifier _profileNotifier = _ActiveProfileNotifier();

  @override
  void initState() {
    super.initState();
    _modeController = widget.modeController ?? ClientModeController();
    _ownsModeController = widget.modeController == null;
    _depsFuture = _createDeps().then((deps) async {
      await _profileNotifier.initialize(deps.serverProfileStore);
      return deps;
    });
  }

  @override
  void dispose() {
    if (_ownsModeController) {
      _modeController.dispose();
    }
    _profileNotifier.dispose();
    _ownedPreferencesController?.dispose();
    super.dispose();
  }

  Future<_AppDeps> _createDeps() async {
    final injectedStore = widget.serverProfileStore;
    final injectedTokenStore = widget.authTokenStore;
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

    if (injectedStore != null && injectedTokenStore != null) {
      return _AppDeps(
        serverProfileStore: injectedStore,
        authTokenStore: injectedTokenStore,
        appPreferencesController: appPreferencesController,
        authClient: widget.authClient ?? AuthApiClient(),
        campaignClient: widget.campaignClient ?? CampaignApiClient(),
        characterClient: widget.characterClient ?? CharacterApiClient(),
        checkRequestClient:
            widget.checkRequestClient ?? CheckRequestApiClient(),
        contentClient: widget.contentClient ?? ContentApiClient(),
        encounterClient: widget.encounterClient ?? EncounterApiClient(),
        sessionClient: widget.sessionClient ?? SessionApiClient(),
      );
    }

    return _AppDeps(
      serverProfileStore:
          injectedStore ?? SharedPreferencesServerProfileStore(preferences!),
      authTokenStore:
          injectedTokenStore ?? SharedPreferencesAuthTokenStore(preferences!),
      appPreferencesController: appPreferencesController,
      authClient: widget.authClient ?? AuthApiClient(),
      campaignClient: widget.campaignClient ?? CampaignApiClient(),
      characterClient: widget.characterClient ?? CharacterApiClient(),
      checkRequestClient: widget.checkRequestClient ?? CheckRequestApiClient(),
      contentClient: widget.contentClient ?? ContentApiClient(),
      encounterClient: widget.encounterClient ?? EncounterApiClient(),
      sessionClient: widget.sessionClient ?? SessionApiClient(),
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
            _profileNotifier,
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

  /// 根据当前激活的服务器 profile 决定主界面：
  /// 有默认 profile → 直接进 MainShell（底部导航主页）；
  /// 无 → 进 ServerProfilesPage 引导页。
  Widget _buildHome(_AppDeps deps) {
    final profile = _profileNotifier.activeProfile;
    if (profile == null) {
      return ServerProfilesPage(
        store: deps.serverProfileStore,
        authTokenStore: deps.authTokenStore,
        discoveryClient:
            widget.discoveryClient ?? ServerDiscoveryClient(),
        roomClient: widget.roomClient ?? RoomApiClient(),
        authClient: deps.authClient,
        campaignClient: deps.campaignClient,
        campaignSocketService: widget.campaignSocketService,
        characterClient: deps.characterClient,
        checkRequestClient: deps.checkRequestClient,
        contentClient: deps.contentClient,
        encounterClient: deps.encounterClient,
        sessionClient: deps.sessionClient,
        modeController: _modeController,
        appPreferencesController: deps.appPreferencesController,
        diceRoller: widget.diceRoller,
        onProfileActivated: (activated) {
          _profileNotifier.activate(activated);
        },
      );
    }

    return MainShell(
      profile: profile,
      modeController: _modeController,
      roomClient: widget.roomClient ?? RoomApiClient(),
      authTokenStore: deps.authTokenStore,
      authClient: deps.authClient,
      campaignClient: deps.campaignClient,
      campaignSocketService: widget.campaignSocketService,
      characterClient: deps.characterClient,
      checkRequestClient: deps.checkRequestClient,
      contentClient: deps.contentClient,
      encounterClient: deps.encounterClient,
      sessionClient: deps.sessionClient,
      appPreferencesController: deps.appPreferencesController,
      diceRoller: widget.diceRoller,
      serverProfileStore: deps.serverProfileStore,
      onSwitchServer: () {
        // 退出当前服务器，回到引导页选择。
        _profileNotifier.deactivate();
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
    required this.serverProfileStore,
    required this.authTokenStore,
    required this.appPreferencesController,
    required this.authClient,
    required this.campaignClient,
    required this.characterClient,
    required this.checkRequestClient,
    required this.contentClient,
    required this.encounterClient,
    required this.sessionClient,
  });

  final ServerProfileStore serverProfileStore;
  final AuthTokenStore authTokenStore;
  final AppPreferencesController appPreferencesController;
  final AuthClient authClient;
  final CampaignClient campaignClient;
  final CharacterClient characterClient;
  final CheckRequestClient checkRequestClient;
  final ContentClient contentClient;
  final EncounterClient encounterClient;
  final SessionClient sessionClient;
}

/// 跟踪当前激活的服务器 profile。
///
/// 应用启动时从 [ServerProfileStore] 读取默认 profile；为 null 则显示引导页。
/// 用户在设置页切换服务器时调用 [activate]，退出时调用 [deactivate]，
/// 触发 [DndTableApp] 重建主界面。
class _ActiveProfileNotifier extends ChangeNotifier {
  ServerProfile? _activeProfile;

  ServerProfile? get activeProfile => _activeProfile;

  Future<void> initialize(ServerProfileStore store) async {
    final defaultId = await store.getDefaultProfileId();
    if (defaultId == null) return;
    final profiles = await store.listProfiles();
    _activeProfile = profiles.where((p) => p.id == defaultId).firstOrNull;
  }

  void activate(ServerProfile profile) {
    _activeProfile = profile;
    notifyListeners();
  }

  void deactivate() {
    _activeProfile = null;
    notifyListeners();
  }
}
