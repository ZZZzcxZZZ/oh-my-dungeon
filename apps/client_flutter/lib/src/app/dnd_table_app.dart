import 'package:flutter/material.dart';

import '../features/server_profiles/data/server_discovery_client.dart';
import '../features/server_profiles/data/server_profile_store.dart';
import '../features/server_profiles/presentation/server_profiles_page.dart';

class DndTableApp extends StatelessWidget {
  const DndTableApp({super.key});

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
      ),
    );
  }
}
