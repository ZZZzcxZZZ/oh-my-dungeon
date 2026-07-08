import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/server_profile.dart';

abstract class ServerProfileStore {
  Future<List<ServerProfile>> listProfiles();
  Future<void> saveProfile(ServerProfile profile);
}

class InMemoryServerProfileStore implements ServerProfileStore {
  final List<ServerProfile> _profiles = [];

  @override
  Future<List<ServerProfile>> listProfiles() async {
    return List.unmodifiable(_profiles);
  }

  @override
  Future<void> saveProfile(ServerProfile profile) async {
    _profiles.removeWhere((existing) => existing.id == profile.id);
    _profiles.add(profile);
  }
}

class SharedPreferencesServerProfileStore implements ServerProfileStore {
  SharedPreferencesServerProfileStore(this._preferences);

  static const _profilesKey = 'server_profiles.v1';

  final SharedPreferences _preferences;

  @override
  Future<List<ServerProfile>> listProfiles() async {
    final encodedProfiles = _preferences.getStringList(_profilesKey) ?? [];
    return encodedProfiles
        .map((encodedProfile) {
          final json = jsonDecode(encodedProfile) as Map<String, Object?>;
          return ServerProfile.fromJson(json);
        })
        .toList(growable: false);
  }

  @override
  Future<void> saveProfile(ServerProfile profile) async {
    final profiles = await listProfiles();
    final nextProfiles = [
      for (final existing in profiles)
        if (existing.id != profile.id) existing,
      profile,
    ];

    await _preferences.setStringList(
      _profilesKey,
      nextProfiles.map((profile) => jsonEncode(profile.toJson())).toList(),
    );
  }
}
