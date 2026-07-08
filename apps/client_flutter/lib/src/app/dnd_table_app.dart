import 'package:flutter/material.dart';

import '../features/client_mode/domain/client_mode.dart';
import '../features/server_profiles/data/server_discovery_client.dart';
import '../features/server_profiles/data/server_profile_store.dart';
import '../features/server_profiles/presentation/server_profiles_page.dart';

class DndTableApp extends StatefulWidget {
  const DndTableApp({super.key});

  @override
  State<DndTableApp> createState() => _DndTableAppState();
}

class _DndTableAppState extends State<DndTableApp> {
  late final ClientModeController _modeController;

  @override
  void initState() {
    super.initState();
    _modeController = ClientModeController();
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
      home: ServerProfilesPage(
        store: InMemoryServerProfileStore(),
        discoveryClient: ServerDiscoveryClient(),
        modeController: _modeController,
      ),
    );
  }
}
