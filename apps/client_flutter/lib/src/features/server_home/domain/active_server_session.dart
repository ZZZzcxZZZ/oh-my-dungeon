import 'package:flutter/foundation.dart';

import '../../server_profiles/data/server_profile_store.dart';
import '../../server_profiles/domain/server_profile.dart';

/// Tracks the currently active server profile.
///
/// The app always enters the local [MainShell]; this session is nullable so
/// offline-first features remain usable without a configured server. When the
/// user picks a server in settings, [activate] is called and listeners rebuild
/// server-dependent UI.
class ActiveServerSession extends ChangeNotifier {
  ServerProfile? _profile;
  ServerProfile? get profile => _profile;
  bool get isConfigured => _profile != null;

  Future<void> initialize(ServerProfileStore store) async {
    final defaultId = await store.getDefaultProfileId();
    if (defaultId == null) return;
    final profiles = await store.listProfiles();
    _profile = profiles.where((p) => p.id == defaultId).firstOrNull;
  }

  void activate(ServerProfile profile) {
    _profile = profile;
    notifyListeners();
  }

  void deactivate() {
    _profile = null;
    notifyListeners();
  }
}
