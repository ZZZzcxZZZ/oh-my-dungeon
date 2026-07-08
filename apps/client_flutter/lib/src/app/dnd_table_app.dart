import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/client_mode/domain/client_mode.dart';
import '../features/rooms/data/room_api_client.dart';
import '../features/server_profiles/data/server_discovery_client.dart';
import '../features/server_profiles/data/server_profile_store.dart';
import '../features/server_profiles/presentation/server_profiles_page.dart';

class DndTableApp extends StatefulWidget {
  const DndTableApp({
    this.serverProfileStore,
    this.discoveryClient,
    this.roomClient,
    super.key,
  });

  final ServerProfileStore? serverProfileStore;
  final ServerDiscoveryClient? discoveryClient;
  final RoomClient? roomClient;

  @override
  State<DndTableApp> createState() => _DndTableAppState();
}

class _DndTableAppState extends State<DndTableApp> {
  late final ClientModeController _modeController;
  late final Future<ServerProfileStore> _serverProfileStoreFuture;

  @override
  void initState() {
    super.initState();
    _modeController = ClientModeController();
    _serverProfileStoreFuture = _createServerProfileStore();
  }

  Future<ServerProfileStore> _createServerProfileStore() async {
    final injectedStore = widget.serverProfileStore;
    if (injectedStore != null) return injectedStore;

    final preferences = await SharedPreferences.getInstance();
    return SharedPreferencesServerProfileStore(preferences);
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
      home: FutureBuilder<ServerProfileStore>(
        future: _serverProfileStoreFuture,
        builder: (context, snapshot) {
          final store = snapshot.data;
          if (store == null) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          return ServerProfilesPage(
            store: store,
            discoveryClient: widget.discoveryClient ?? ServerDiscoveryClient(),
            roomClient: widget.roomClient ?? RoomApiClient(),
            modeController: _modeController,
          );
        },
      ),
    );
  }
}
