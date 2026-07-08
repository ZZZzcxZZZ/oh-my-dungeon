import 'package:flutter/material.dart';

import '../../../features/auth/data/auth_api_client.dart';
import '../../../features/auth/data/auth_token_store.dart';
import '../../../features/auth/presentation/auth_controller.dart';
import '../../../features/campaigns/data/campaign_api_client.dart';
import '../../../features/campaigns/presentation/campaign_controller.dart';
import '../../../features/campaigns/presentation/campaigns_tab_page.dart';
import '../../../features/client_mode/domain/client_mode.dart';
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
/// Three tabs: 战役 (Campaigns), 桌面 (Table), 设置 (Settings).
/// Each tab owns its own page widget; the shell preserves state via
/// [IndexedStack] so switching tabs does not reload data.
class MainShell extends StatefulWidget {
  const MainShell({
    required this.profile,
    required this.modeController,
    required this.roomClient,
    required this.authTokenStore,
    required this.authClient,
    required this.campaignClient,
    required this.sessionClient,
    super.key,
  });

  final ServerProfile profile;
  final ClientModeController modeController;
  final RoomClient roomClient;
  final AuthTokenStore authTokenStore;
  final AuthClient authClient;
  final CampaignClient campaignClient;
  final SessionClient sessionClient;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late final AuthController _authController;
  late final CampaignController _campaignController;
  late final SessionController _sessionController;
  late final SessionSocketService _socketService;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
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
    _sessionController = SessionController(
      apiBaseUrl: widget.profile.apiBaseUrl,
      authController: _authController,
      sessionClient: widget.sessionClient,
    );
    _socketService = SocketIoSessionSocketService();
  }

  @override
  void dispose() {
    _socketService.disconnect();
    _sessionController.dispose();
    _campaignController.dispose();
    _authController.dispose();
    super.dispose();
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
          ),
          TableTabPage(
            profile: widget.profile,
            authController: _authController,
            campaignController: _campaignController,
            sessionController: _sessionController,
            socketService: _socketService,
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
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.castle_outlined),
            selectedIcon: Icon(Icons.castle),
            label: '战役',
          ),
          NavigationDestination(
            icon: Icon(Icons.table_restaurant_outlined),
            selectedIcon: Icon(Icons.table_restaurant),
            label: '桌面',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
