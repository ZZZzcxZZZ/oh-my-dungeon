import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/auth/data/auth_api_client.dart';
import '../features/auth/data/auth_token_store.dart';
import '../features/campaigns/data/campaign_api_client.dart';
import '../features/client_mode/domain/client_mode.dart';
import '../features/rooms/data/room_api_client.dart';
import '../features/server_profiles/data/server_discovery_client.dart';
import '../features/server_profiles/data/server_profile_store.dart';
import '../features/server_profiles/presentation/server_profiles_page.dart';
import '../features/sessions/data/session_api_client.dart';

class DndTableApp extends StatefulWidget {
  const DndTableApp({
    this.serverProfileStore,
    this.authTokenStore,
    this.discoveryClient,
    this.roomClient,
    this.authClient,
    this.campaignClient,
    this.sessionClient,
    super.key,
  });

  final ServerProfileStore? serverProfileStore;
  final AuthTokenStore? authTokenStore;
  final ServerDiscoveryClient? discoveryClient;
  final RoomClient? roomClient;
  final AuthClient? authClient;
  final CampaignClient? campaignClient;
  final SessionClient? sessionClient;

  @override
  State<DndTableApp> createState() => _DndTableAppState();
}

class _DndTableAppState extends State<DndTableApp> {
  late final ClientModeController _modeController;
  late final Future<_AppDeps> _depsFuture;

  @override
  void initState() {
    super.initState();
    _modeController = ClientModeController();
    _depsFuture = _createDeps();
  }

  Future<_AppDeps> _createDeps() async {
    final injectedStore = widget.serverProfileStore;
    final injectedTokenStore = widget.authTokenStore;

    if (injectedStore != null && injectedTokenStore != null) {
      return _AppDeps(
        serverProfileStore: injectedStore,
        authTokenStore: injectedTokenStore,
        authClient: widget.authClient ?? AuthApiClient(),
        campaignClient: widget.campaignClient ?? CampaignApiClient(),
        sessionClient: widget.sessionClient ?? SessionApiClient(),
      );
    }

    final preferences = await SharedPreferences.getInstance();
    return _AppDeps(
      serverProfileStore:
          injectedStore ?? SharedPreferencesServerProfileStore(preferences),
      authTokenStore:
          injectedTokenStore ?? SharedPreferencesAuthTokenStore(preferences),
      authClient: widget.authClient ?? AuthApiClient(),
      campaignClient: widget.campaignClient ?? CampaignApiClient(),
      sessionClient: widget.sessionClient ?? SessionApiClient(),
    );
  }

  @override
  void dispose() {
    _modeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'D&D Table Tool',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
      ),
      home: FutureBuilder<_AppDeps>(
        future: _depsFuture,
        builder: (context, snapshot) {
          final deps = snapshot.data;
          if (deps == null) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          return ServerProfilesPage(
            store: deps.serverProfileStore,
            authTokenStore: deps.authTokenStore,
            discoveryClient: widget.discoveryClient ?? ServerDiscoveryClient(),
            roomClient: widget.roomClient ?? RoomApiClient(),
            authClient: deps.authClient,
            campaignClient: deps.campaignClient,
            sessionClient: deps.sessionClient,
            modeController: _modeController,
          );
        },
      ),
    );
  }
}

class _AppDeps {
  const _AppDeps({
    required this.serverProfileStore,
    required this.authTokenStore,
    required this.authClient,
    required this.campaignClient,
    required this.sessionClient,
  });

  final ServerProfileStore serverProfileStore;
  final AuthTokenStore authTokenStore;
  final AuthClient authClient;
  final CampaignClient campaignClient;
  final SessionClient sessionClient;
}
