import 'dart:convert';

import 'package:dnd_table_client/src/core/database/app_database.dart';
import 'package:dnd_table_client/src/core/sync/sync_repository.dart';
import 'package:dnd_table_client/src/features/content/data/local/content_repository.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:dnd_table_client/src/features/content/domain/content_package_manifest.dart';
import 'package:dnd_table_client/src/features/vault/data/drift_vault_change_applier.dart';
import 'package:dnd_table_client/src/features/vault/domain/vault_models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/content_test_support.dart';

void main() {
  late AppDatabase database;
  late DriftContentRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftContentRepository(database);
  });

  tearDown(() => database.close());

  test('starts empty and searches enabled packages only', () async {
    final fighterEntry = ContentEntry.fromJson({
      'id': 'example:class/fighter',
      'type': 'class',
      'slug': 'fighter',
      'name': '战士',
      'body': <Map<String, Object?>>[],
      'revision': 1,
    });
    expect(await repository.search(const ContentQuery()), isEmpty);

    await repository.replacePackage(
      manifest: const ContentPackageManifest(
        formatVersion: 1,
        id: 'example',
        name: 'Example',
        version: '1.0.0',
        locale: 'zh-CN',
        system: 'dnd5e-2024',
        entryCount: 1,
      ),
      entries: [fighterEntry],
      contentHash: 'hash-1',
    );
    expect(await repository.search(const ContentQuery(text: '战士')), [fighterEntry]);
    await repository.setPackageEnabled('example', false);
    expect(await repository.search(const ContentQuery(text: '战士')), isEmpty);
  });

  test('searches by name, aliases, summary, and tags', () async {
    final entries = [
      ContentEntry.fromJson({
        'id': 'example:spell/fireball',
        'type': 'spell',
        'slug': 'fireball',
        'name': '火球术',
        'aliases': ['Fireball'],
        'summary': '爆炸性火焰',
        'body': <Map<String, Object?>>[],
        'tags': ['spell', 'fire'],
        'revision': 1,
      }),
    ];
    await repository.replacePackage(
      manifest: const ContentPackageManifest(
        formatVersion: 1,
        id: 'example',
        name: 'Example',
        version: '1.0.0',
        locale: 'zh-CN',
        system: 'dnd5e-2024',
        entryCount: 1,
      ),
      entries: entries,
      contentHash: 'hash-1',
    );

    expect(await repository.search(const ContentQuery(text: '火球术')), isNotEmpty);
    expect(await repository.search(const ContentQuery(text: 'Fireball')), isNotEmpty);
    expect(await repository.search(const ContentQuery(text: '爆炸')), isNotEmpty);
  });

  test('filters by type and favorite', () async {
    final entries = [
      ContentEntry.fromJson({
        'id': 'example:class/fighter',
        'type': 'class',
        'slug': 'fighter',
        'name': '战士',
        'body': <Map<String, Object?>>[],
        'revision': 1,
      }),
      ContentEntry.fromJson({
        'id': 'example:spell/fireball',
        'type': 'spell',
        'slug': 'fireball',
        'name': '火球术',
        'body': <Map<String, Object?>>[],
        'revision': 1,
      }),
    ];
    await repository.replacePackage(
      manifest: const ContentPackageManifest(
        formatVersion: 1,
        id: 'example',
        name: 'Example',
        version: '1.0.0',
        locale: 'zh-CN',
        system: 'dnd5e-2024',
        entryCount: 2,
      ),
      entries: entries,
      contentHash: 'hash-1',
    );

    expect(await repository.search(const ContentQuery(type: 'spell')), hasLength(1));
    expect(await repository.search(const ContentQuery(type: 'class')), hasLength(1));

    await repository.setFavorite('example:spell/fireball', true);
    expect(await repository.search(const ContentQuery(favoritesOnly: true)), hasLength(1));
  });

  test('resolves outgoing and incoming links', () async {
    final entries = [
      ContentEntry.fromJson({
        'id': 'example:class/fighter',
        'type': 'class',
        'slug': 'fighter',
        'name': '战士',
        'body': [
          {'type': 'entryLink', 'targetId': 'example:feature/action-surge', 'text': '动作如潮'}
        ],
        'revision': 1,
      }),
      ContentEntry.fromJson({
        'id': 'example:feature/action-surge',
        'type': 'classFeature',
        'slug': 'action-surge',
        'name': '动作如潮',
        'body': <Map<String, Object?>>[],
        'revision': 1,
      }),
    ];
    await repository.replacePackage(
      manifest: const ContentPackageManifest(
        formatVersion: 1,
        id: 'example',
        name: 'Example',
        version: '1.0.0',
        locale: 'zh-CN',
        system: 'dnd5e-2024',
        entryCount: 2,
      ),
      entries: entries,
      contentHash: 'hash-1',
    );

    final outgoing = await repository.outgoingLinks('example:class/fighter');
    expect(outgoing, hasLength(1));
    expect(outgoing.first.targetId, 'example:feature/action-surge');

    final incoming = await repository.incomingLinks('example:feature/action-surge');
    expect(incoming, hasLength(1));
    expect(incoming.first.sourceId, 'example:class/fighter');
  });

  test('deletes a package and reports impact', () async {
    await repository.replacePackage(
      manifest: const ContentPackageManifest(
        formatVersion: 1,
        id: 'example',
        name: 'Example',
        version: '1.0.0',
        locale: 'zh-CN',
        system: 'dnd5e-2024',
        entryCount: 1,
      ),
      entries: [
        ContentEntry.fromJson({
          'id': 'example:class/fighter',
          'type': 'class',
          'slug': 'fighter',
          'name': '战士',
          'body': <Map<String, Object?>>[],
          'revision': 1,
        }),
      ],
      contentHash: 'hash-1',
    );
    await repository.setFavorite('example:class/fighter', true);
    await repository.saveNote('example:class/fighter', '我的笔记');

    final impact = await repository.deletionImpact('example');
    expect(impact.entryCount, 1);
    expect(impact.favoriteCount, 1);
    expect(impact.noteCount, 1);

    await repository.deletePackage('example');
    expect(await repository.search(const ContentQuery()), isEmpty);
  });

  test('watches packages as a stream', () async {
    expect(await repository.watchPackages().first, isEmpty);
    await repository.replacePackage(
      manifest: const ContentPackageManifest(
        formatVersion: 1,
        id: 'example',
        name: 'Example',
        version: '1.0.0',
        locale: 'zh-CN',
        system: 'dnd5e-2024',
        entryCount: 0,
      ),
      entries: const [],
      contentHash: 'hash-1',
    );
    final packages = await repository.watchPackages().first;
    expect(packages, hasLength(1));
    expect(packages.first.id, 'example');
  });

  test('setting a favorite enqueues a vault operation', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = DriftContentRepository(database);
    await repository.replacePackage(
      manifest: const ContentPackageManifest(
        formatVersion: 1, id: 'example', name: 'Example', version: '1.0.0',
        locale: 'zh-CN', system: 'dnd5e-2024', entryCount: 1,
      ),
      entries: [testFighterEntry()],
      contentHash: 'hash-1',
    );
    await repository.setFavorite('example:class/fighter', true);
    final pending = await DriftSyncRepository(database).pending(scope: 'vault');
    final favoriteOp = pending.firstWhere((op) => op.entityType == 'favorite');
    expect(favoriteOp.entityId, 'example:class/fighter');
    await database.close();
  });

  test('saving a note enqueues a vault operation', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = DriftContentRepository(database);
    await repository.replacePackage(
      manifest: const ContentPackageManifest(
        formatVersion: 1, id: 'example', name: 'Example', version: '1.0.0',
        locale: 'zh-CN', system: 'dnd5e-2024', entryCount: 1,
      ),
      entries: [testFighterEntry()],
      contentHash: 'hash-1',
    );
    await repository.saveNote('example:class/fighter', 'My notes');
    final pending = await DriftSyncRepository(database).pending(scope: 'vault');
    final noteOp = pending.firstWhere((op) => op.entityType == 'note');
    expect(noteOp.entityId, 'example:class/fighter');
    await database.close();
  });

  test('coalesces local favorite edits using the pulled vault revision', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = DriftContentRepository(database);
    final applier = DriftVaultChangeApplier(database);
    await applier.applyAll([
      const VaultChange(
        cursor: '1',
        operation: 'upsert',
        entityType: 'favorite',
        entityId: 'example:class/fighter',
        revision: 4,
        payloadJson: '{"entryKey":"example:class/fighter","favorite":true}',
      ),
    ]);

    await repository.setFavorite('example:class/fighter', false);
    await repository.setFavorite('example:class/fighter', true);

    final pending = await DriftSyncRepository(database).pending(scope: 'vault');
    final favoriteOps = pending
        .where((operation) => operation.entityType == 'favorite')
        .toList();
    expect(favoriteOps, hasLength(1));
    expect(favoriteOps.single.baseRevision, 4);
    expect(jsonDecode(favoriteOps.single.payloadJson)['favorite'], isTrue);
    await database.close();
  });

  test('package manifest operation excludes body and entries', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = DriftContentRepository(database);
    await repository.replacePackage(
      manifest: const ContentPackageManifest(
        formatVersion: 1, id: 'example', name: 'Example', version: '1.0.0',
        locale: 'zh-CN', system: 'dnd5e-2024', entryCount: 1,
      ),
      entries: [testFighterEntry()],
      contentHash: 'hash-abc',
    );
    final pending = await DriftSyncRepository(database).pending(scope: 'vault');
    expect(pending, hasLength(1));
    expect(pending.single.entityType, 'installedPackageManifest');
    final payload = jsonDecode(pending.single.payloadJson) as Map<String, Object?>;
    expect(payload.containsKey('entries'), isFalse);
    expect(payload.containsKey('body'), isFalse);
    expect(payload['id'], 'example');
    expect(payload['version'], '1.0.0');
    expect(payload['contentHash'], 'hash-abc');
    await database.close();
  });
}
