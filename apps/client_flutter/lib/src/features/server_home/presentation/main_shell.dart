import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_status_controller.dart';
import '../../../features/app_preferences/presentation/app_preferences_controller.dart';
import '../../../features/auth/data/auth_api_client.dart';
import '../../../features/auth/data/auth_token_store.dart';
import '../../../features/auth/presentation/auth_controller.dart';
import '../../../features/campaigns/data/campaign_api_client.dart';
import '../../../features/campaigns/data/campaign_socket_service.dart';
import '../../../features/campaigns/data/socket_io_campaign_socket_service.dart';
import '../../../features/campaigns/presentation/campaign_controller.dart';
import '../../../features/campaigns/presentation/campaigns_tab_page.dart';
import '../../../features/characters/data/character_api_client.dart';
import '../../../features/characters/data/character_repository.dart';
import '../../../features/characters/data/local/drift_character_repository.dart';
import '../../../features/characters/presentation/character_controller.dart';
import '../../../features/characters/presentation/characters_tab_page.dart';
import '../../../features/check_requests/data/check_request_api_client.dart';
import '../../../features/client_mode/domain/client_mode.dart';
import '../../../features/content/data/content_api_client.dart';
import '../../../features/content/data/import/content_package_importer.dart';
import '../../../features/content/data/local/content_repository.dart';
import '../../../features/content/domain/content_file_picker.dart';
import '../../../features/content/presentation/content_controller.dart';
import '../../../features/content/presentation/content_library_controller.dart';
import '../../../features/content/presentation/content_library_page.dart';
import '../../../features/content/presentation/content_package_settings_page.dart';
import '../../../features/encounters/data/encounter_api_client.dart';
import '../../../features/rooms/data/room_api_client.dart';
import '../../../features/rooms/domain/dice_roller.dart';
import '../../../features/server_profiles/domain/server_profile.dart';
import '../../../features/server_profiles/data/server_profile_store.dart';
import '../../../features/sessions/data/session_api_client.dart';
import '../../../features/sessions/presentation/session_controller.dart';
import '../domain/active_server_session.dart';
import 'home_dashboard_page.dart';
import 'settings_tab_page.dart';

/// Bottom-navigation shell shown after a server profile is selected.
///
/// The shell preserves tab state via [IndexedStack] so switching tabs does not
/// reload data.
class MainShell extends StatefulWidget {
  const MainShell({
    required this.session,
    required this.modeController,
    required this.roomClient,
    required this.authTokenStore,
    required this.authClient,
    required this.campaignClient,
    this.campaignSocketService,
    required this.characterClient,
    required this.checkRequestClient,
    required this.contentClient,
    required this.encounterClient,
    required this.sessionClient,
    required this.appPreferencesController,
    this.database,
    this.diceRoller,
    this.serverProfileStore,
    this.serverProfilesPageBuilder,
    this.onSwitchToProfile,
    super.key,
  });

  final ActiveServerSession session;
  final ClientModeController modeController;
  final RoomClient roomClient;
  final AuthTokenStore authTokenStore;
  final AuthClient authClient;
  final CampaignClient campaignClient;
  final CampaignSocketService? campaignSocketService;
  final CharacterClient characterClient;
  final CheckRequestClient checkRequestClient;
  final ContentClient contentClient;
  final EncounterClient encounterClient;
  final SessionClient sessionClient;
  final AppPreferencesController appPreferencesController;
  final AppDatabase? database;
  final DiceRoller? diceRoller;
  final ServerProfileStore? serverProfileStore;
  final WidgetBuilder? serverProfilesPageBuilder;
  final ValueChanged<ServerProfile>? onSwitchToProfile;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late final AuthController _authController;
  late final CampaignController _campaignController;
  late final CharacterController _characterController;
  late final CharacterRepository _characterRepository;
  late final ContentController _contentController;
  late final ContentRepository _contentRepository;
  late final ContentPackageImporter _contentImporter;
  late final ContentLibraryController _libraryController;
  late final SessionController _sessionController;
  late final CampaignSocketService _campaignSocketService;
  final SyncStatusController _syncStatusController = SyncStatusController();
  final ContentFilePicker _contentFilePicker = const FilePickerContentFilePicker();
  int _currentIndex = 0;

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
    _campaignController = CampaignController(
      apiBaseUrl: profile?.apiBaseUrl ?? '',
      authController: _authController,
      campaignClient: widget.campaignClient,
      campaignSocketService: _campaignSocketService,
    );
    _characterRepository = widget.database != null
        ? DriftCharacterRepository(widget.database!)
        : EmptyCharacterRepository();
    _characterController = CharacterController(
      repository: _characterRepository,
    );
    _contentController = ContentController(
      apiBaseUrl: profile?.apiBaseUrl ?? '',
      authController: _authController,
      contentClient: widget.contentClient,
    );
    _contentRepository = widget.database != null
        ? DriftContentRepository(widget.database!)
        : EmptyContentRepository();
    _contentImporter = ContentPackageImporter(_contentRepository);
    _libraryController = ContentLibraryController(
      repository: _contentRepository,
    );
    _sessionController = SessionController(
      apiBaseUrl: profile?.apiBaseUrl ?? '',
      authController: _authController,
      sessionClient: widget.sessionClient,
    );
  }

  @override
  void dispose() {
    widget.modeController.removeListener(_onModeChanged);
    _campaignSocketService.disconnect();
    _sessionController.dispose();
    _libraryController.dispose();
    _contentController.dispose();
    _characterController.dispose();
    _campaignController.dispose();
    _authController.dispose();
    _syncStatusController.dispose();
    super.dispose();
  }

  void _onModeChanged() {
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
    final pages = [
      HomeDashboardPage(
        session: widget.session,
        modeController: widget.modeController,
        authController: _authController,
        campaignController: _campaignController,
        characterController: _characterController,
        sessionController: _sessionController,
        onNavigateToTab: (index) => setState(() => _currentIndex = index),
      ),
      CampaignsTabPage(
        session: widget.session,
        authController: _authController,
        campaignController: _campaignController,
        characterController: _characterController,
        contentController: _contentController,
        modeController: widget.modeController,
        appPreferencesController: widget.appPreferencesController,
        diceRoller: widget.diceRoller,
      ),
      CharactersTabPage(
        controller: _characterController,
        campaignController: _campaignController,
        contentController: _contentController,
        appPreferencesController: widget.appPreferencesController,
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
