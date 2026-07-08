import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/server_profile.dart';

abstract class ServerProfileStore {
  Future<List<ServerProfile>> listProfiles();
  Future<void> saveProfile(ServerProfile profile);
  Future<void> deleteProfile(String id);
  Future<String?> getDefaultProfileId();
  Future<void> setDefaultProfileId(String? id);
}

class InMemoryServerProfileStore implements ServerProfileStore {
  final List<ServerProfile> _profiles = [];
  String? _defaultProfileId;

  @override
  Future<List<ServerProfile>> listProfiles() async {
    return List.unmodifiable(_profiles);
  }

  @override
  Future<void> saveProfile(ServerProfile profile) async {
    _profiles.removeWhere((existing) => existing.id == profile.id);
    _profiles.add(profile);
  }

  @override
  Future<void> deleteProfile(String id) async {
    _profiles.removeWhere((existing) => existing.id == id);
    if (_defaultProfileId == id) {
      _defaultProfileId = null;
    }
  }

  @override
  Future<String?> getDefaultProfileId() async {
    return _defaultProfileId;
  }

  @override
  Future<void> setDefaultProfileId(String? id) async {
    _defaultProfileId = id;
  }
}

class SharedPreferencesServerProfileStore implements ServerProfileStore {
  SharedPreferencesServerProfileStore(this._preferences);

  static const _profilesKey = 'server_profiles.v1';
  static const _defaultProfileIdKey = 'server_profiles.default_id.v1';

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

    await _saveProfiles(nextProfiles);
  }

  @override
  Future<void> deleteProfile(String id) async {
    final profiles = await listProfiles();
    final nextProfiles = [
      for (final profile in profiles)
        if (profile.id != id) profile,
    ];

    await _saveProfiles(nextProfiles);
    if (await getDefaultProfileId() == id) {
      await setDefaultProfileId(null);
    }
  }

  @override
  Future<String?> getDefaultProfileId() async {
    return _preferences.getString(_defaultProfileIdKey);
  }

  @override
  Future<void> setDefaultProfileId(String? id) async {
    if (id == null) {
      await _preferences.remove(_defaultProfileIdKey);
      return;
    }

    await _preferences.setString(_defaultProfileIdKey, id);
  }

  Future<void> _saveProfiles(List<ServerProfile> profiles) async {
    await _preferences.setStringList(
      _profilesKey,
      profiles.map((profile) => jsonEncode(profile.toJson())).toList(),
    );
  }
}
