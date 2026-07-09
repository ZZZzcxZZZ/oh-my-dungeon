import 'package:flutter/material.dart';

import '../../../features/auth/data/auth_api_client.dart';
import '../../../features/auth/data/auth_token_store.dart';
import '../../../features/auth/presentation/auth_controller.dart';
import '../../../features/campaigns/data/campaign_api_client.dart';
import '../../../features/campaigns/presentation/campaign_controller.dart';
import '../../../features/campaigns/presentation/campaigns_tab_page.dart';
import '../../../features/characters/data/character_api_client.dart';
import '../../../features/characters/presentation/character_controller.dart';
import '../../../features/characters/presentation/characters_tab_page.dart';
import '../../../features/client_mode/domain/client_mode.dart';
import '../../../features/content/data/content_api_client.dart';
import '../../../features/content/presentation/content_controller.dart';
import '../../../features/content/presentation/content_library_page.dart';
import '../../../features/encounters/data/encounter_api_client.dart';
import '../../../features/encounters/presentation/encounter_controller.dart';
import '../../../features/rooms/data/room_api_client.dart';
import '../../../features/server_profiles/domain/server_profile.dart';
import '../../../features/sessions/data/session_api_client.dart';
import '../../../features/sessions/data/session_socket_service.dart';
import '../../../features/sessions/data/socket_io_session_socket_service.dart';
import '../../../features/sessions/presentation/session_controller.dart';
import 'settings_tab_page.dart';
import 'table_tab_page.dart';

/// Bottom-navigation shell shown after a server profile is selected.
///
/// The shell preserves tab state via [IndexedStack] so switching tabs does not
/// reload data.
class MainShell extends StatefulWidget {
  const MainShell({
    required this.profile,
    required this.modeController,
    required this.roomClient,
    required this.authTokenStore,
    required this.authClient,
    required this.campaignClient,
    required this.characterClient,
    required this.contentClient,
    required this.encounterClient,
    required this.sessionClient,
    super.key,
  });

  final ServerProfile profile;
  final ClientModeController modeController;
  final RoomClient roomClient;
  final AuthTokenStore authTokenStore;
  final AuthClient authClient;
  final CampaignClient campaignClient;
  final CharacterClient characterClient;
  final ContentClient contentClient;
  final EncounterClient encounterClient;
  final SessionClient sessionClient;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late final AuthController _authController;
  late final CampaignController _campaignController;
  late final CharacterController _characterController;
  late final ContentController _contentController;
  late final EncounterController _encounterController;
  late final SessionController _sessionController;
  late final SessionSocketService _socketService;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    widget.modeController.addListener(_onModeChanged);
    _authController = AuthController(
      tokenStore: widget.authTokenStore,
      authClient: widget.authClient,
      serverProfileId: widget.profile.id,
      apiBaseUrl: widget.profile.apiBaseUrl,
    )..initialize();
    _campaignController = CampaignController(
      apiBaseUrl: widget.profile.apiBaseUrl,
      authController: _authController,
      campaignClient: widget.campaignClient,
    );
    _characterController = CharacterController(
      apiBaseUrl: widget.profile.apiBaseUrl,
      authController: _authController,
      characterClient: widget.characterClient,
    );
    _contentController = ContentController(
      apiBaseUrl: widget.profile.apiBaseUrl,
      authController: _authController,
      contentClient: widget.contentClient,
    );
    _encounterController = EncounterController(
      apiBaseUrl: widget.profile.apiBaseUrl,
      authController: _authController,
      encounterClient: widget.encounterClient,
    );
    _sessionController = SessionController(
      apiBaseUrl: widget.profile.apiBaseUrl,
      authController: _authController,
      sessionClient: widget.sessionClient,
    );
    _socketService = SocketIoSessionSocketService();
  }

  @override
  void dispose() {
    widget.modeController.removeListener(_onModeChanged);
    _socketService.disconnect();
    _sessionController.dispose();
    _encounterController.dispose();
    _contentController.dispose();
    _characterController.dispose();
    _campaignController.dispose();
    _authController.dispose();
    super.dispose();
  }

  void _onModeChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          CampaignsTabPage(
            profile: widget.profile,
            authController: _authController,
            campaignController: _campaignController,
            characterController: _characterController,
          ),
          CharactersTabPage(
            authController: _authController,
            characterController: _characterController,
            campaignController: _campaignController,
          ),
          ContentLibraryPage(
            authController: _authController,
            campaignController: _campaignController,
            contentController: _contentController,
            modeController: widget.modeController,
          ),
          TableTabPage(
            profile: widget.profile,
            authController: _authController,
            campaignController: _campaignController,
            sessionController: _sessionController,
            encounterController: _encounterController,
            socketService: _socketService,
            modeController: widget.modeController,
          ),
          SettingsTabPage(
            profile: widget.profile,
            modeController: widget.modeController,
            authController: _authController,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: [
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
            label: widget.modeController.mode == ClientMode.dungeonMaster
                ? '内容库'
                : '资料库',
          ),
          const NavigationDestination(
            icon: Icon(Icons.table_restaurant_outlined),
            selectedIcon: Icon(Icons.table_restaurant),
            label: '桌面',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
