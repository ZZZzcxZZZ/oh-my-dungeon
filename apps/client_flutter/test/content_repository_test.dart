import 'dart:convert';

import 'package:dnd_table_client/src/core/database/app_database.dart';
import 'package:dnd_table_client/src/core/sync/sync_repository.dart';
import 'package:dnd_table_client/src/features/content/data/local/content_repository.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:dnd_table_client/src/features/content/domain/content_package_manifest.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_choice_resolver.dart';
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
    expect(await repository.search(const ContentQuery(text: '战士')), [
      fighterEntry,
    ]);
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

    expect(
      await repository.search(const ContentQuery(text: '火球术')),
      isNotEmpty,
    );
    expect(
      await repository.search(const ContentQuery(text: 'Fireball')),
      isNotEmpty,
    );
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

    expect(
      await repository.search(const ContentQuery(type: 'spell')),
      hasLength(1),
    );
    expect(
      await repository.search(const ContentQuery(type: 'class')),
      hasLength(1),
    );

    await repository.setFavorite('example:spell/fireball', true);
    expect(
      await repository.search(const ContentQuery(favoritesOnly: true)),
      hasLength(1),
    );
  });

  test('filters structured spell facets with AND across fields', () async {
    final spells = [
      ContentEntry.fromJson({
        'id': 'example:spell/fireball',
        'type': 'spell',
        'slug': 'fireball',
        'name': '火球术',
        'body': <Map<String, Object?>>[],
        'structured': {
          'level': 3,
          'school': '塑能',
          'classes': ['术士', '法师'],
        },
        'revision': 1,
      }),
      ContentEntry.fromJson({
        'id': 'example:spell/fly',
        'type': 'spell',
        'slug': 'fly',
        'name': '飞行术',
        'body': <Map<String, Object?>>[],
        'structured': {
          'level': 3,
          'school': '变化',
          'classes': ['术士', '魔契师', '法师'],
        },
        'revision': 1,
      }),
      ContentEntry.fromJson({
        'id': 'example:spell/fire-bolt',
        'type': 'spell',
        'slug': 'fire-bolt',
        'name': '火焰箭',
        'body': <Map<String, Object?>>[],
        'structured': {
          'level': 0,
          'school': '塑能',
          'classes': ['术士', '法师'],
        },
        'revision': 1,
      }),
    ];
    await repository.replacePackage(
      manifest: const ContentPackageManifest(
        formatVersion: 2,
        id: 'example',
        name: 'Example',
        version: '2.0.0',
        locale: 'zh-CN',
        system: 'dnd5e-2024',
        entryCount: 3,
      ),
      entries: spells,
      contentHash: 'hash-spell-facets',
    );

    final results = await repository.search(
      const ContentQuery(
        type: 'spell',
        facets: {
          'level': {'3'},
          'school': {'塑能'},
          'classes': {'法师'},
        },
      ),
    );

    expect(results.map((entry) => entry.id), ['example:spell/fireball']);
  });
  test('preserves subclass relations after a database round trip', () async {
    final classEntry = ContentEntry.fromJson({
      'id': 'example:class/warlock',
      'type': 'class',
      'slug': 'warlock',
      'name': 'Warlock',
      'body': <Map<String, Object?>>[],
      'rules': {
        'progression': [
          {
            'level': 3,
            'choices': [
              {
                'id': 'warlock-subclass',
                'label': 'Subclass',
                'optionType': 'subclass',
                'minimum': 1,
                'maximum': 1,
              },
            ],
          },
        ],
      },
      'revision': 1,
    });
    final subclassEntry = ContentEntry.fromJson({
      'id': 'example:subclass/fiend',
      'type': 'subclass',
      'slug': 'fiend',
      'name': 'Fiend',
      'body': <Map<String, Object?>>[],
      'relations': [
        {'type': 'subclassOf', 'targetId': classEntry.id},
      ],
      'revision': 1,
    });

    await repository.replacePackage(
      manifest: const ContentPackageManifest(
        formatVersion: 2,
        id: 'example',
        name: 'Example',
        version: '2.0.0',
        locale: 'en',
        system: 'dnd5e-2024',
        entryCount: 2,
      ),
      entries: [classEntry, subclassEntry],
      contentHash: 'hash-relations',
    );

    final persistedEntries = await repository.search(const ContentQuery());
    final byId = {for (final entry in persistedEntries) entry.id: entry};
    final choice =
        byId[classEntry.id]!.rules!.progression.single.choices.single;

    expect(byId[subclassEntry.id]!.relations, subclassEntry.relations);
    expect(
      RuleChoiceResolver(
        entries: byId,
      ).optionsFor(choice, sourceEntryId: classEntry.id),
      [byId[subclassEntry.id]],
    );
  });
  test('resolves outgoing and incoming links', () async {
    final entries = [
      ContentEntry.fromJson({
        'id': 'example:class/fighter',
        'type': 'class',
        'slug': 'fighter',
        'name': '战士',
        'body': [
          {
            'type': 'entryLink',
            'targetId': 'example:feature/action-surge',
            'text': '动作如潮',
          },
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

    final incoming = await repository.incomingLinks(
      'example:feature/action-surge',
    );
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
    expect(packages.first.contentHash, 'hash-1');
  });

  test('setting a favorite enqueues a vault operation', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = DriftContentRepository(database);
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
        formatVersion: 1,
        id: 'example',
        name: 'Example',
        version: '1.0.0',
        locale: 'zh-CN',
        system: 'dnd5e-2024',
        entryCount: 1,
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

  test(
    'coalesces local favorite edits using the pulled vault revision',
    () async {
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

      final pending = await DriftSyncRepository(
        database,
      ).pending(scope: 'vault');
      final favoriteOps = pending
          .where((operation) => operation.entityType == 'favorite')
          .toList();
      expect(favoriteOps, hasLength(1));
      expect(favoriteOps.single.baseRevision, 4);
      expect(jsonDecode(favoriteOps.single.payloadJson)['favorite'], isTrue);
      await database.close();
    },
  );

  test('package manifest operation excludes body and entries', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = DriftContentRepository(database);
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
      entries: [testFighterEntry()],
      contentHash: 'hash-abc',
    );
    final pending = await DriftSyncRepository(database).pending(scope: 'vault');
    expect(pending, hasLength(1));
    expect(pending.single.entityType, 'installedPackageManifest');
    final payload =
        jsonDecode(pending.single.payloadJson) as Map<String, Object?>;
    expect(payload.containsKey('entries'), isFalse);
    expect(payload.containsKey('body'), isFalse);
    expect(payload['id'], 'example');
    expect(payload['version'], '1.0.0');
    expect(payload['contentHash'], 'hash-abc');
    await database.close();
  });

  test(
    'updateEntry rewrites mutable fields without touching the key',
    () async {
      final entry = ContentEntry.fromJson({
        'id': 'example:spell/fireball',
        'type': 'spell',
        'slug': 'fireball',
        'name': '火球术',
        'summary': '爆炸性火焰',
        'body': <Map<String, Object?>>[],
        'tags': ['spell', 'fire'],
        'revision': 1,
      });
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
        entries: [entry],
        contentHash: 'hash-1',
      );

      final updated = ContentEntry.fromJson({
        'id': 'example:spell/fireball',
        'type': 'spell',
        'slug': 'fireball',
        'name': '火球术（家规）',
        'summary': '爆炸性火焰, DC 增益 +2',
        'body': <Map<String, Object?>>[],
        'tags': ['spell', 'fire', 'homebrew'],
        'revision': 2,
      });
      await repository.updateEntry(updated);

      final reloaded = await repository.getByKey('example:spell/fireball');
      expect(reloaded?.name, '火球术（家规）');
      expect(reloaded?.summary, '爆炸性火焰, DC 增益 +2');
      expect(reloaded?.tags, contains('homebrew'));
      expect(reloaded?.revision, 2);
      // 收藏和笔记应保留 (entryKey 未变).
      await repository.setFavorite('example:spell/fireball', true);
      await repository.saveNote('example:spell/fireball', '笔记');
      await repository.updateEntry(updated);
      expect(await repository.isFavorite('example:spell/fireball'), isTrue);
    },
  );

  test('updateEntry rejects entries that do not exist yet', () async {
    final ghost = ContentEntry.fromJson({
      'id': 'example:spell/fireball',
      'type': 'spell',
      'slug': 'fireball',
      'name': '火球术',
      'body': <Map<String, Object?>>[],
      'revision': 1,
    });
    expect(() => repository.updateEntry(ghost), throwsA(isA<StateError>()));
  });

  test('duplicateEntry clones an entry with a new id and name', () async {
    final entry = ContentEntry.fromJson({
      'id': 'example:spell/fireball',
      'type': 'spell',
      'slug': 'fireball',
      'name': '火球术',
      'summary': '爆炸性火焰',
      'body': <Map<String, Object?>>[],
      'revision': 1,
    });
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
      entries: [entry],
      contentHash: 'hash-1',
    );

    final duplicate = await repository.duplicateEntry(
      'example:spell/fireball',
      newName: '火球术（家规副本）',
    );
    expect(duplicate, isNotNull);
    expect(duplicate!.id, 'example:spell/fireball-copy');
    expect(duplicate.slug, 'fireball-copy');
    expect(duplicate.name, '火球术（家规副本）');
    expect(duplicate.type, 'spell');
    expect(duplicate.summary, '爆炸性火焰');

    // 副本可被搜索到 (同包 enabled).
    final results = await repository.search(const ContentQuery(text: '家规副本'));
    expect(results, hasLength(1));
    expect(results.single.id, 'example:spell/fireball-copy');

    // 原条目仍在.
    expect(await repository.getByKey('example:spell/fireball'), isNotNull);
  });

  test('duplicateEntry returns null when source entry is missing', () async {
    final duplicate = await repository.duplicateEntry(
      'example:spell/missing',
      newName: '幽灵',
    );
    expect(duplicate, isNull);
  });

  test(
    'duplicateEntry keeps executable rules local and out of Vault',
    () async {
      final entry = ContentEntry.fromJson({
        'id': 'example:classFeature/action-surge',
        'type': 'classFeature',
        'slug': 'action-surge',
        'name': '动作如潮',
        'body': <Map<String, Object?>>[],
        'rules': {
          'grants': [
            {
              'id': 'action-surge-resource',
              'kind': 'resource',
              'label': '动作如潮',
              'value': 1,
            },
          ],
        },
        'revision': 1,
      });
      await repository.replacePackage(
        manifest: const ContentPackageManifest(
          formatVersion: 2,
          id: 'example',
          name: 'Example',
          version: '1.0.0',
          locale: 'zh-CN',
          system: 'dnd5e-2024',
          entryCount: 1,
        ),
        entries: [entry],
        contentHash: 'hash-rules',
      );
      await database.delete(database.syncOutbox).go();

      final duplicate = await repository.duplicateEntry(
        entry.id,
        newName: '动作如潮（家规）',
      );

      expect(duplicate?.rules?.grants.single.kind.name, 'resource');
      expect(
        (await repository.getByKey(
          duplicate!.id,
        ))?.rules?.grants.single.kind.name,
        'resource',
      );
      expect(await database.select(database.syncOutbox).get(), isEmpty);
    },
  );

  test('updateEntry does not upload local package body to Vault', () async {
    final entry = ContentEntry.fromJson({
      'id': 'private:spell/fireball',
      'type': 'spell',
      'slug': 'fireball',
      'name': '火球术',
      'body': [
        {'type': 'paragraph', 'text': 'private rulebook text'},
      ],
      'revision': 1,
    });
    await repository.replacePackage(
      manifest: const ContentPackageManifest(
        formatVersion: 2,
        id: 'private',
        name: 'Private',
        version: '1.0.0',
        locale: 'zh-CN',
        system: 'dnd5e-2024',
        entryCount: 1,
      ),
      entries: [entry],
      contentHash: 'private-hash',
    );
    await database.delete(database.syncOutbox).go();

    await repository.updateEntry(
      ContentEntry.fromJson({...entry.toJson(), 'name': '火球术（批注）'}),
    );

    expect(await database.select(database.syncOutbox).get(), isEmpty);
  });
}
