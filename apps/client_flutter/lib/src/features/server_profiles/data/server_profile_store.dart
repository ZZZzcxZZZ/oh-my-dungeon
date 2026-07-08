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
