import 'package:dnd_table_client/src/features/server_profiles/domain/server_metadata.dart';
import 'package:dnd_table_client/src/features/server_profiles/domain/server_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses well-known server metadata', () {
    final metadata = ServerMetadata.fromJson({
      'instanceId': 'instance-1',
      'name': 'D&D Table Tool',
      'version': '0.1.0',
      'apiBaseUrl': 'http://localhost:3000/api',
      'websocketUrl': 'ws://localhost:3000/realtime',
      'registrationEnabled': true,
      'serverMode': 'self_hosted',
      'supportedSystems': ['dnd5e'],
      'apiVersion': '1',
      'features': ['campaignArchives', 'campaignCharacters', 'campaignChat'],
    });

    expect(metadata.instanceId, 'instance-1');
    expect(metadata.name, 'D&D Table Tool');
    expect(metadata.registrationEnabled, isTrue);
    expect(metadata.supportedSystems, ['dnd5e']);
    expect(metadata.apiVersion, '1');
    expect(metadata.features, contains('campaignArchives'));
  });

  test('creates a server profile from discovered metadata', () {
    const metadata = ServerMetadata(
      instanceId: 'instance-1',
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

    expect(profile.id, 'instance-1');
    expect(profile.serverName, 'Home Table');
    expect(profile.localAlias, isNull);
    expect(profile.displayName, 'Home Table');
    expect(profile.websocketUrl, 'wss://table.example.com/realtime');
  });

  test('keeps a local alias separate from the discovered server name', () {
    const metadata = ServerMetadata(
      instanceId: 'instance-1',
      name: 'Silver Sword',
      version: '0.1.0',
      apiBaseUrl: 'https://table.example.com/api',
      websocketUrl: 'wss://table.example.com/campaigns',
      registrationEnabled: true,
      serverMode: 'self_hosted',
      supportedSystems: ['dnd5e'],
    );

    final profile = ServerProfile.fromMetadata(
      baseUrl: 'https://table.example.com',
      metadata: metadata,
    ).copyWith(localAlias: '周五团');

    expect(profile.serverName, 'Silver Sword');
    expect(profile.localAlias, '周五团');
    expect(profile.displayName, '周五团');
  });

  test(
    'repairs legacy profiles that stored the server origin as the API URL',
    () {
      final profile = ServerProfile.fromJson({
        'id': '127.0.0.1',
        'name': 'Local preview',
        'baseUrl': 'http://127.0.0.1:5174',
        'apiBaseUrl': 'http://127.0.0.1:5174',
        'websocketUrl': 'ws://127.0.0.1:3000/realtime',
        'lastKnownVersion': '0.1.0',
      });

      expect(profile.apiBaseUrl, 'http://127.0.0.1:5174/api');
      expect(profile.serverName, 'Local preview');
      expect(profile.displayName, 'Local preview');
    },
  );
}
