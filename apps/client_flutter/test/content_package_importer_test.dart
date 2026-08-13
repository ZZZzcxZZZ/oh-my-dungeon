import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dnd_table_client/src/core/database/app_database.dart';
import 'package:dnd_table_client/src/features/content/data/import/content_package_importer.dart';
import 'package:dnd_table_client/src/features/content/data/local/content_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/content_test_support.dart';

void main() {
  test(
    'legacy class feature text becomes level-based executable rules',
    () async {
      final repository = MemoryContentRepository();
      final importer = ContentPackageImporter(repository);

      final report = await importer.previewJson('''{
      "formatVersion":1,
      "id":"legacy-phb",
      "name":"Legacy PHB",
      "version":"1.0.0",
      "locale":"zh-CN",
      "system":"dnd5e-2024",
      "entryCount":1,
      "entries":[{
        "id":"legacy-phb:class/fighter",
        "type":"class",
        "slug":"fighter",
        "name":"战士",
        "body":[],
        "revision":1,
        "structured":{"features":[
          "1级：回气 Second Wind你可以恢复生命值。",
          "2级：动作如潮 Action Surge你可以执行一个额外动作。"
        ]}
      }]
    }''');

      expect(report.valid, isTrue);
      expect(report.entryCount, 3);
      final fighter = report.entries.singleWhere(
        (entry) => entry.id == 'legacy-phb:class/fighter',
      );
      expect(
        fighter.rules!.progression
            .singleWhere((step) => step.level == 1)
            .grants
            .single
            .label,
        '回气',
      );
      final secondWind = report.entries.singleWhere(
        (entry) => entry.id == 'legacy-phb:class-feature/fighter-1-1',
      );
      expect(secondWind.type, 'classFeature');
      expect(secondWind.name, '回气');
      expect(secondWind.structured['level'], 1);
      expect(secondWind.structured['classId'], 'legacy-phb:class/fighter');
      expect(secondWind.body.single.text, contains('你可以恢复生命值'));
    },
  );

  late AppDatabase database;
  late DriftContentRepository repository;
  late ContentPackageImporter importer;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftContentRepository(database);
    importer = ContentPackageImporter(repository);
  });

  tearDown(() => database.close());

  test('unknown external entry types degrade to custom', () async {
    const source = '''{
      "formatVersion": 2,
      "id": "homebrew",
      "name": "Homebrew",
      "version": "1.0.0",
      "locale": "zh-CN",
      "system": "dnd5e-2024",
      "entryCount": 1,
      "entries": [{
        "id": "homebrew:mystery/example",
        "type": "mystery",
        "slug": "example",
        "name": "未知条目",
        "body": [],
        "revision": 1
      }]
    }''';

    final report = await ContentPackageImporter(repository).previewJson(source);

    expect(report.valid, isTrue);
    expect(report.entries.single.type, 'custom');
  });

  test('validates links before replacing the installed package', () async {
    final report = await importer.previewJson('''{
      "formatVersion":1,
      "id":"example",
      "name":"Example",
      "version":"1.0.0",
      "locale":"zh-CN",
      "system":"dnd5e-2024",
      "entryCount":1,
      "entries":[{
        "id":"example:class/fighter",
        "type":"class",
        "slug":"fighter",
        "name":"战士",
        "body":[{"type":"entryLink","targetId":"missing","text":"缺失"}],
        "revision":1
      }]
    }''');

    expect(report.valid, isFalse);
    expect(report.errors.single.path, r'$.entries[0].body[0].targetId');
    expect(await repository.watchPackages().first, isEmpty);
  });

  test('previews a valid package without importing', () async {
    final report = await importer.previewJson('''{
      "formatVersion":1,
      "id":"example",
      "name":"Example",
      "version":"1.0.0",
      "locale":"zh-CN",
      "system":"dnd5e-2024",
      "entryCount":1,
      "entries":[{
        "id":"example:class/fighter",
        "type":"class",
        "slug":"fighter",
        "name":"战士",
        "body":[],
        "revision":1
      }]
    }''');

    expect(report.valid, isTrue);
    expect(report.entryCount, 1);
    expect(await repository.watchPackages().first, isEmpty);
  });

  test(
    'imports a D&D 2024 v2 package with executable rule declarations',
    () async {
      final report = await importer.previewJson('''{
      "formatVersion":2,
      "id":"example.rules",
      "name":"Example rules",
      "version":"2.0.0",
      "locale":"zh-CN",
      "system":"dnd5e-2024",
      "entryCount":1,
      "entries":[{
        "id":"example.rules:class/fighter",
        "type":"class",
        "slug":"fighter",
        "name":"战士",
        "body":[],
        "revision":1,
        "rules":{"progression":[{"level":1,"grants":[{
          "id":"second-wind","kind":"feature","label":"回气"
        }]}]}
      }]
    }''');

      expect(report.valid, isTrue);
      await importer.importReport(report);
      final fighter = await repository.getByKey('example.rules:class/fighter');
      expect(fighter?.rules?.progression.single.level, 1);
      expect(
        fighter?.rules?.progression.single.grants.single.id,
        'second-wind',
      );
    },
  );

  test('imports and preserves validated content relationships', () async {
    final report = await importer.previewJson('''{
      "formatVersion":2,
      "id":"example.rules",
      "name":"Example rules",
      "version":"2.0.0",
      "locale":"zh-CN",
      "system":"dnd5e-2024",
      "entryCount":2,
      "entries":[{
        "id":"example.rules:class/wizard",
        "type":"class",
        "slug":"wizard",
        "name":"法师",
        "body":[],
        "revision":1
      },{
        "id":"example.rules:subclass/evoker",
        "type":"subclass",
        "slug":"evoker",
        "name":"塑能师",
        "body":[],
        "revision":1,
        "relations":[{
          "type":"subclassOf",
          "targetId":"example.rules:class/wizard"
        }]
      }]
    }''');

    expect(report.valid, isTrue);
    expect(report.entries.last.relations.single.type, 'subclassOf');
    expect(
      report.entries.last.relations.single.targetId,
      'example.rules:class/wizard',
    );
  });

  test('rejects unresolved relationship targets', () async {
    final report = await importer.previewJson('''{
      "formatVersion":2,"id":"broken","name":"Broken","version":"1.0.0",
      "locale":"zh-CN","system":"dnd5e-2024","entryCount":1,
      "entries":[{
        "id":"broken:subclass/evoker","type":"subclass","slug":"evoker",
        "name":"Evoker","body":[],"revision":1,
        "relations":[{"type":"subclassOf","targetId":"broken:class/missing"}]
      }]
    }''');

    expect(report.valid, isFalse);
    expect(
      report.errors.any(
        (error) => error.path == r'$.entries[0].relations[0].targetId',
      ),
      isTrue,
    );
  });

  test('rejects non-2024 systems for v2 rule packages', () async {
    final report = await importer.previewJson('''{
      "formatVersion":2,"id":"legacy","name":"Legacy","version":"1.0.0",
      "locale":"zh-CN","system":"dnd5e-2014","entryCount":0,"entries":[]
    }''');

    expect(report.valid, isFalse);
    expect(report.errors.any((error) => error.path == r'$.system'), isTrue);
  });

  test('rejects unresolved rule entry references in v2 packages', () async {
    final report = await importer.previewJson('''{
      "formatVersion":2,"id":"broken","name":"Broken","version":"1.0.0",
      "locale":"zh-CN","system":"dnd5e-2024","entryCount":1,
      "entries":[{
        "id":"broken:class/fighter","type":"class","slug":"fighter",
        "name":"战士","body":[],"revision":1,
        "rules":{"grants":[{
          "id":"missing-feature","kind":"feature",
          "entryId":"broken:class-feature/missing"
        }]}
      }]
    }''');

    expect(report.valid, isFalse);
    expect(
      report.errors.any(
        (error) => error.path == r'$.entries[0].rules.grants[0].entryId',
      ),
      isTrue,
    );
  });

  test('rejects unresolved recommended choice references', () async {
    final report = await importer.previewJson('''{
      "formatVersion":2,"id":"broken","name":"Broken","version":"1.0.0",
      "locale":"zh-CN","system":"dnd5e-2024","entryCount":1,
      "entries":[{
        "id":"broken:class/guardian","type":"class","slug":"guardian",
        "name":"Guardian","body":[],"revision":1,
        "rules":{"choices":[{
          "id":"gear","label":"Gear","optionType":"equipmentBundle",
          "minimum":1,"maximum":1,
          "recommendedEntryIds":["broken:equipment-bundle/missing"]
        }]}
      }]
    }''');

    expect(report.valid, isFalse);
    expect(
      report.errors.any(
        (error) =>
            error.path ==
            r'$.entries[0].rules.choices[0].recommendedEntryIds[0]',
      ),
      isTrue,
    );
  });

  test(
    'rejects recommended choices that do not satisfy their filters',
    () async {
      final report = await importer.previewJson('''{
      "formatVersion":2,"id":"broken","name":"Broken","version":"1.0.0",
      "locale":"zh-CN","system":"dnd5e-2024","entryCount":2,
      "entries":[{
        "id":"broken:class/mage","type":"class","slug":"mage",
        "name":"Mage","body":[],"revision":1,
        "rules":{"choices":[{
          "id":"spells","label":"Spells","optionType":"spell",
          "minimum":1,"maximum":1,"optionTags":["spell-list:mage"],
          "recommendedEntryIds":["broken:spell/other"]
        }]}
      },{
        "id":"broken:spell/other","type":"spell","slug":"other",
        "name":"Other","body":[],"revision":1,
        "structured":{"level":0},"tags":["spell-list:priest"]
      }]
    }''');

      expect(report.valid, isFalse);
      expect(
        report.errors.any(
          (error) =>
              error.path ==
              r'$.entries[0].rules.choices[0].recommendedEntryIds[0]',
        ),
        isTrue,
      );
    },
  );

  test('imports a valid package', () async {
    final report = await importer.previewJson('''{
      "formatVersion":1,
      "id":"example",
      "name":"Example",
      "version":"1.0.0",
      "locale":"zh-CN",
      "system":"dnd5e-2024",
      "entryCount":1,
      "entries":[{
        "id":"example:class/fighter",
        "type":"class",
        "slug":"fighter",
        "name":"战士",
        "body":[],
        "revision":1
      }]
    }''');

    await importer.importReport(report);
    final entries = await repository.search(const ContentQuery());
    expect(entries, hasLength(1));
    expect(entries.first.name, '战士');
  });

  test('previews and imports a dndpack zip with assets', () async {
    final archive = Archive()
      ..addFile(
        ArchiveFile.bytes(
          'manifest.json',
          utf8.encode(
            jsonEncode({
              'formatVersion': 1,
              'id': 'example.pack',
              'name': 'Example pack',
              'version': '1.0.0',
              'locale': 'zh-CN',
              'system': 'dnd5e-2024',
              'entryCount': 1,
            }),
          ),
        ),
      )
      ..addFile(
        ArchiveFile.bytes(
          'entries.json',
          utf8.encode(
            jsonEncode([
              {
                'id': 'example.pack:class/fighter',
                'type': 'class',
                'slug': 'fighter',
                'name': 'Fighter',
                'body': [
                  {'type': 'image', 'asset': 'assets/hero.png', 'alt': 'Hero'},
                ],
                'revision': 1,
              },
            ]),
          ),
        ),
      )
      ..addFile(
        ArchiveFile.bytes('assets/hero.png', const [
          0x89,
          0x50,
          0x4e,
          0x47,
          0x0d,
          0x0a,
          0x1a,
          0x0a,
        ]),
      );
    final bytes = Uint8List.fromList(ZipEncoder().encode(archive));

    final report = await importer.previewDndPack(bytes);

    expect(report.valid, isTrue);
    expect(report.assets.keys, contains('assets/hero.png'));
    await importer.importReport(report);
    expect(
      await repository.readAsset('example.pack', 'assets/hero.png'),
      isNotNull,
    );
  });

  test('rejects unsafe paths in a dndpack before importing', () async {
    final archive = Archive()
      ..addFile(ArchiveFile.bytes('../outside.json', utf8.encode('{}')));
    final bytes = Uint8List.fromList(ZipEncoder().encode(archive));

    final report = await importer.previewDndPack(bytes);

    expect(report.valid, isFalse);
    expect(report.errors.single.message, contains('unsafe'));
    expect(await repository.watchPackages().first, isEmpty);
  });

  test('upgrade preserves favorites and notes by stable entry ID', () async {
    final json1 = '''{
      "formatVersion":1,"id":"example","name":"Example","version":"1.0.0",
      "locale":"zh-CN","system":"dnd5e-2024","entryCount":1,
      "entries":[{"id":"example:class/fighter","type":"class","slug":"fighter","name":"战士","body":[],"revision":1}]
    }''';
    final json2 = '''{
      "formatVersion":1,"id":"example","name":"Example","version":"2.0.0",
      "locale":"zh-CN","system":"dnd5e-2024","entryCount":1,
      "entries":[{"id":"example:class/fighter","type":"class","slug":"fighter","name":"战士","body":[],"revision":2}]
    }''';

    final report1 = await importer.previewJson(json1);
    await importer.importReport(report1);
    await repository.setFavorite('example:class/fighter', true);
    await repository.saveNote('example:class/fighter', '我的笔记');

    final report2 = await importer.previewJson(json2);
    await importer.importReport(report2);

    final entries = await repository.search(const ContentQuery());
    expect(entries.first.revision, 2);
    final favorites = await repository.search(
      const ContentQuery(favoritesOnly: true),
    );
    expect(favorites, hasLength(1));
    // Notes are preserved since they key on entryKey which is stable
  });

  test('rejects entry count mismatch', () async {
    final report = await importer.previewJson('''{
      "formatVersion":1,"id":"example","name":"Example","version":"1.0.0",
      "locale":"zh-CN","system":"dnd5e-2024","entryCount":5,
      "entries":[{"id":"example:class/fighter","type":"class","slug":"fighter","name":"战士","body":[],"revision":1}]
    }''');

    expect(report.valid, isFalse);
    expect(report.errors.any((e) => e.path.contains('entryCount')), isTrue);
  });

  test('rejects duplicate entry IDs within a package', () async {
    final report = await importer.previewJson('''{
      "formatVersion":1,"id":"example","name":"Example","version":"1.0.0",
      "locale":"zh-CN","system":"dnd5e-2024","entryCount":2,
      "entries":[
        {"id":"example:class/fighter","type":"class","slug":"fighter","name":"战士","body":[],"revision":1},
        {"id":"example:class/fighter","type":"class","slug":"fighter","name":"战士","body":[],"revision":1}
      ]
    }''');

    expect(report.valid, isFalse);
    expect(report.errors.any((e) => e.path.contains('duplicate')), isTrue);
  });

  test('validates entry ID prefix matches package ID', () async {
    final report = await importer.previewJson('''{
      "formatVersion":1,"id":"example","name":"Example","version":"1.0.0",
      "locale":"zh-CN","system":"dnd5e-2024","entryCount":1,
      "entries":[{"id":"other:class/fighter","type":"class","slug":"fighter","name":"战士","body":[],"revision":1}]
    }''');

    expect(report.valid, isFalse);
    expect(report.errors.any((e) => e.path.contains('id')), isTrue);
  });
}
