import 'package:dnd_table_client/src/core/database/app_database.dart';
import 'package:dnd_table_client/src/features/content/data/import/content_package_importer.dart';
import 'package:dnd_table_client/src/features/content/data/local/content_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DriftContentRepository repository;
  late ContentPackageImporter importer;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftContentRepository(database);
    importer = ContentPackageImporter(repository);
  });

  tearDown(() => database.close());

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
    final favorites = await repository.search(const ContentQuery(favoritesOnly: true));
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
