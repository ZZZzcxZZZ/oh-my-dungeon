import 'package:dnd_table_client/src/features/server_profiles/domain/server_metadata.dart';
import 'package:dnd_table_client/src/features/server_profiles/domain/server_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses well-known server metadata', () {
    final metadata = ServerMetadata.fromJson({
      'name': 'D&D Table Tool',
      'version': '0.1.0',
      'apiBaseUrl': 'http://localhost:3000/api',
      'websocketUrl': 'ws://localhost:3000/realtime',
      'registrationEnabled': true,
      'serverMode': 'self_hosted',
      'supportedSystems': ['dnd5e'],
      'apiVersion': '1',
      'features': ['campaignArchives', 'campaignActors', 'campaignChat'],
    });

    expect(metadata.name, 'D&D Table Tool');
    expect(metadata.registrationEnabled, isTrue);
    expect(metadata.supportedSystems, ['dnd5e']);
    expect(metadata.apiVersion, '1');
    expect(metadata.features, contains('campaignArchives'));
  });

  test('creates a server profile from discovered metadata', () {
    const metadata = ServerMetadata(
      name: 'Home Table',
      version: '0.1.0',
      apiBaseUrl: 'https://table.example.com/api',
      websocketUrl: 'wss://table.example.com/realtime',
      registrationEnabled: true,
      serverMode: 'self_hosted',
      supportedSystems: ['dnd5e'],
      apiVersion: '1',
      features: ['campaignArchives'],
    );

    final profile = ServerProfile.fromMetadata(
      baseUrl: 'https://table.example.com',
      metadata: metadata,
    );

    expect(profile.id, 'table.example.com');
    expect(profile.name, 'Home Table');
    expect(profile.websocketUrl, 'wss://table.example.com/realtime');
  });

  test('repairs legacy profiles that stored the server origin as the API URL', () {
    final profile = ServerProfile.fromJson({
      'id': '127.0.0.1',
      'name': 'Local preview',
      'baseUrl': 'http://127.0.0.1:5174',
      'apiBaseUrl': 'http://127.0.0.1:5174',
      'websocketUrl': 'ws://127.0.0.1:3000/realtime',
      'lastKnownVersion': '0.1.0',
    });

    expect(profile.apiBaseUrl, 'http://127.0.0.1:5174/api');
  });
}
