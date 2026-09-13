import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:dnd_table_client/src/core/backup/drift_local_data_archive_service.dart';
import 'package:dnd_table_client/src/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

/// Seeds a database with personal data covering all exportable tables.
///
/// Writes: a server Profile (no token), a content package + entry + asset,
/// a character, favorites, notes, read history, and a content link.
Future<void> seedBackupFixture(AppDatabase db) async {
  await db
      .into(db.serverProfiles)
      .insert(
        ServerProfilesCompanion.insert(
          id: 'localhost',
          name: 'Local Server',
          baseUrl: 'http://localhost:3000',
          apiBaseUrl: 'http://localhost:3000/api',
          websocketUrl: 'http://localhost:3000',
        ),
      );

  await db
      .into(db.localContentPackages)
      .insert(
        LocalContentPackagesCompanion.insert(
          id: 'example',
          formatVersion: 1,
          name: 'Example Pack',
          version: '1.0.0',
          locale: 'zh-CN',
          system: 'dnd5e-2024',
          entryCount: 1,
          contentHash: 'abc123',
          installedAt: DateTime.utc(2026, 7, 14),
        ),
      );

  await db
      .into(db.localContentEntries)
      .insert(
        LocalContentEntriesCompanion.insert(
          entryKey: 'example:spell/fireball',
          packageId: 'example',
          type: 'spell',
          slug: 'fireball',
          name: '火球术',
          revision: 1,
        ),
      );

  await db
      .into(db.localContentAssets)
      .insert(
        LocalContentAssetsCompanion.insert(
          packageId: 'example',
          relativePath: 'images/fireball.png',
          bytes: Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]),
          mediaType: const Value('image/png'),
          contentHash: const Value('asset-hash'),
        ),
      );

  await db
      .into(db.contentLinks)
      .insert(
        ContentLinksCompanion.insert(
          id: 'link-1',
          sourceId: 'example:spell/fireball',
          targetId: 'example:class/sorcerer',
        ),
      );

  await db
      .into(db.contentFavorites)
      .insert(
        ContentFavoritesCompanion.insert(
          entryKey: 'example:spell/fireball',
          createdAt: DateTime.utc(2026, 7, 14),
        ),
      );

  await db
      .into(db.contentNotes)
      .insert(
        ContentNotesCompanion.insert(
          entryKey: 'example:spell/fireball',
          markdown: 'Remember to use this carefully.',
          updatedAt: DateTime.utc(2026, 7, 14),
        ),
      );

  await db
      .into(db.contentReadHistory)
      .insert(
        ContentReadHistoryCompanion.insert(
          entryKey: 'example:spell/fireball',
          readAt: DateTime.utc(2026, 7, 14),
        ),
      );

  await db
      .into(db.characters)
      .insert(
        CharactersCompanion.insert(
          id: 'char-1',
          sheetJson:
              '{"id":"char-1","name":"Arannis","level":3,"currentHp":24,"maxHp":24,"armorClass":15}',
        ),
      );

  await db
      .into(db.characterContentRefs)
      .insert(
        CharacterContentRefsCompanion.insert(
          characterId: 'char-1',
          slot: 'class',
          entryKey: 'example:class/fighter',
        ),
      );
}

/// Rewrites a v14 export into an **older on-disk shape** by mutating the given
/// tables' rows, then recomputes the manifest sha256 so the archive still
/// previews as valid.
Uint8List rewriteArchiveDatabase(
  Uint8List bytes,
  Map<String, void Function(Map<String, Object?> row)> mutate,
) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final databaseJson =
      jsonDecode(
            utf8.decode(
              archive.findFile('database.json')!.content as List<int>,
            ),
          )
          as Map<String, Object?>;
  final rewritten = <String, Object?>{...databaseJson};
  for (final entry in mutate.entries) {
    rewritten[entry.key] = <Map<String, Object?>>[
      for (final row in (databaseJson[entry.key] as List))
        _mutatedRow(row, entry.value),
    ];
  }
  final databaseBytes = Uint8List.fromList(utf8.encode(jsonEncode(rewritten)));

  final manifestJson =
      jsonDecode(
            utf8.decode(
              archive.findFile('manifest.json')!.content as List<int>,
            ),
          )
          as Map<String, Object?>;
  manifestJson['sha256'] = sha256.convert(databaseBytes).toString();

  final rebuilt = Archive();
  rebuilt.addFile(ArchiveFile.bytes('database.json', databaseBytes));
  rebuilt.addFile(
    ArchiveFile.bytes('manifest.json', utf8.encode(jsonEncode(manifestJson))),
  );
  for (final file in archive.files) {
    if (file.name == 'database.json' || file.name == 'manifest.json') continue;
    rebuilt.addFile(ArchiveFile.bytes(file.name, file.content as List<int>));
  }
  return Uint8List.fromList(ZipEncoder().encode(rebuilt));
}

/// Removes the given non-null columns per table (the on-disk shape an older
/// client exported before those columns existed).
Uint8List stripLegacyColumnsForArchive(
  Uint8List bytes,
  Map<String, Set<String>> removals,
) => rewriteArchiveDatabase(bytes, <String, void Function(Map<String, Object?>)>{
  for (final entry in removals.entries)
    entry.key: (row) => row.removeWhere((key, _) => entry.value.contains(key)),
});

/// Rewrites a v14 export into the **v13 shape**: removes the
/// `local_content_packages.priority` key (the column was introduced in
/// schemaVersion 14). This is the on-disk shape a pre-v14 client exported.
Uint8List stripPackagePriorityForLegacyArchive(Uint8List bytes) =>
    stripLegacyColumnsForArchive(bytes, const <String, Set<String>>{
      'localContentPackages': {'priority'},
    });

Map<String, Object?> _mutatedRow(
  Object? row,
  void Function(Map<String, Object?> row) mutate,
) {
  final normalized = Map<String, Object?>.from(row as Map);
  mutate(normalized);
  return normalized;
}

/// Restores an archive whose named columns were stripped, then hands the target
/// database to [verify].
Future<void> expectLegacyColumnDefaults(
  Map<String, Set<String>> removals,
  Future<void> Function(AppDatabase target) verify,
) async {
  final source = AppDatabase.forTesting(NativeDatabase.memory());
  final target = AppDatabase.forTesting(NativeDatabase.memory());
  await seedBackupFixture(source);
  final legacyBytes = stripLegacyColumnsForArchive(
    await DriftLocalDataArchiveService(source).exportArchive(),
    removals,
  );
  final preview = await DriftLocalDataArchiveService(
    target,
  ).previewArchive(legacyBytes);
  expect(preview.valid, isTrue, reason: preview.error ?? '');
  await DriftLocalDataArchiveService(target).restoreArchive(preview);
  await verify(target);
  await source.close();
  await target.close();
}

void main() {
  group('DriftLocalDataArchiveService', () {
    test(
      'exports local-owned data and restores it atomically without tokens',
      () async {
        final source = AppDatabase.forTesting(NativeDatabase.memory());
        final target = AppDatabase.forTesting(NativeDatabase.memory());
        final sourceService = DriftLocalDataArchiveService(source);
        final targetService = DriftLocalDataArchiveService(target);
        await seedBackupFixture(source);

        final bytes = await sourceService.exportArchive();
        final preview = await targetService.previewArchive(bytes);

        expect(preview.valid, isTrue);
        expect(preview.characterCount, 1);
        expect(preview.packageCount, 1);

        // The archive must not contain auth tokens.
        final archive = ZipDecoder().decodeBytes(bytes);
        final databaseFile = archive.findFile('database.json')!;
        final databaseJson = utf8.decode(databaseFile.content as List<int>);
        expect(databaseJson, isNot(contains('access-token')));
        expect(databaseJson, isNot(contains('refresh-token')));

        // The archive must contain a manifest.
        final manifestFile = archive.findFile('manifest.json')!;
        final manifestJson =
            jsonDecode(utf8.decode(manifestFile.content as List<int>))
                as Map<String, Object?>;
        expect(manifestJson['formatVersion'], 1);
        expect(manifestJson['sha256'], isA<String>());

        // The archive must contain assets.
        final assetFile = archive.findFile(
          'assets/example/images/fireball.png',
        );
        expect(assetFile, isNotNull);

        await targetService.restoreArchive(preview);

        expect(await target.select(target.characters).get(), hasLength(1));
        expect(
          await target.select(target.localContentAssets).get(),
          isNotEmpty,
        );
        expect(
          await target.select(target.localContentEntries).get(),
          hasLength(1),
        );
        expect(
          await target.select(target.contentFavorites).get(),
          hasLength(1),
        );
        expect(await target.select(target.contentNotes).get(), hasLength(1));

        await source.close();
        await target.close();
      },
    );

    test('restores a v13 archive without priority keys, defaulting to 0', () async {
      final source = AppDatabase.forTesting(NativeDatabase.memory());
      final target = AppDatabase.forTesting(NativeDatabase.memory());
      final sourceService = DriftLocalDataArchiveService(source);
      final targetService = DriftLocalDataArchiveService(target);
      await seedBackupFixture(source);

      final legacyBytes = stripPackagePriorityForLegacyArchive(
        await sourceService.exportArchive(),
      );
      // The fixture really is the v13 shape: no `priority` key anywhere.
      final decoded = ZipDecoder().decodeBytes(legacyBytes);
      expect(
        utf8.decode(decoded.findFile('database.json')!.content as List<int>),
        isNot(contains('"priority"')),
      );

      final preview = await targetService.previewArchive(legacyBytes);
      expect(preview.valid, isTrue, reason: preview.error ?? '');

      // Before the fix this threw `TypeError: null is not a subtype of int`
      // inside the restore transaction and rolled the whole restore back.
      await targetService.restoreArchive(preview);

      final packages = await target.select(target.localContentPackages).get();
      expect(packages.single.id, 'example');
      // Old backups keep the "priority 0 ⇒ tier 100" behavior (D2).
      expect(packages.single.priority, 0);

      await source.close();
      await target.close();
    });

    // 0.2 阻塞项：同一条 `fromJson` 路径上还有三个"归档早于该列"的非空列，
    // 缺失时同样抛 `TypeError` 并回滚整个 restore。四列共用一处归一化。
    test('restores a v5 archive without entries.rulesJson, defaulting to {}', () async {
      await expectLegacyColumnDefaults(
        const <String, Set<String>>{
          'localContentEntries': {'rulesJson'},
        },
        (target) async {
          final entries = await target.select(target.localContentEntries).get();
          expect(entries.single.entryKey, 'example:spell/fireball');
          expect(entries.single.rulesJson, '{}');
          // 其它列不受影响。
          expect(entries.single.relationsJson, '[]');
        },
      );
    });

    test(
      'restores a v6 archive without entries.relationsJson, defaulting to []',
      () async {
        await expectLegacyColumnDefaults(
          const <String, Set<String>>{
            'localContentEntries': {'relationsJson'},
          },
          (target) async {
            final entries = await target
                .select(target.localContentEntries)
                .get();
            expect(entries.single.relationsJson, '[]');
            expect(entries.single.rulesJson, '{}');
          },
        );
      },
    );

    test(
      'restores a v10 archive without characters.markdownDirty, defaulting to false',
      () async {
        await expectLegacyColumnDefaults(
          const <String, Set<String>>{
            'characters': {'markdownDirty'},
          },
          (target) async {
            final characters = await target.select(target.characters).get();
            expect(characters.single.id, 'char-1');
            expect(characters.single.markdownDirty, isFalse);
          },
        );
      },
    );

    test(
      'restores an archive missing all four compat columns at once',
      () async {
        await expectLegacyColumnDefaults(
          const <String, Set<String>>{
            'localContentPackages': {'priority'},
            'localContentEntries': {'rulesJson', 'relationsJson'},
            'characters': {'markdownDirty'},
          },
          (target) async {
            expect(
              (await target.select(target.localContentPackages).get()).single
                  .priority,
              0,
            );
            final entry = (await target.select(
              target.localContentEntries,
            ).get()).single;
            expect(entry.rulesJson, '{}');
            expect(entry.relationsJson, '[]');
            expect(
              (await target.select(target.characters).get())
                  .single
                  .markdownDirty,
              isFalse,
            );
          },
        );
      },
    );

    test('treats an explicit null compat column as missing', () async {
      final source = AppDatabase.forTesting(NativeDatabase.memory());
      final target = AppDatabase.forTesting(NativeDatabase.memory());
      await seedBackupFixture(source);
      final legacyBytes = rewriteArchiveDatabase(
        await DriftLocalDataArchiveService(source).exportArchive(),
        <String, void Function(Map<String, Object?>)>{
          'localContentPackages': (row) => row['priority'] = null,
        },
      );
      final decoded = ZipDecoder().decodeBytes(legacyBytes);
      expect(
        utf8.decode(decoded.findFile('database.json')!.content as List<int>),
        contains('"priority":null'),
      );

      final preview = await DriftLocalDataArchiveService(
        target,
      ).previewArchive(legacyBytes);
      expect(preview.valid, isTrue, reason: preview.error ?? '');
      await DriftLocalDataArchiveService(target).restoreArchive(preview);
      expect(
        (await target.select(target.localContentPackages).get()).single.priority,
        0,
      );

      await source.close();
      await target.close();
    });

    test('rejects a non-object row with a table-naming error', () async {
      final source = AppDatabase.forTesting(NativeDatabase.memory());
      final target = AppDatabase.forTesting(NativeDatabase.memory());
      await seedBackupFixture(source);
      final sourceService = DriftLocalDataArchiveService(source);
      final targetService = DriftLocalDataArchiveService(target);

      // 把 characters 表整行换成字符串：归一化必须抛出带表名的错误，而不是把
      // 坏行降级成 `{}` 继续（那会掩盖归档损坏）。
      final bytes = await sourceService.exportArchive();
      final archive = ZipDecoder().decodeBytes(bytes);
      final databaseJson =
          jsonDecode(
                utf8.decode(
                  archive.findFile('database.json')!.content as List<int>,
                ),
              )
              as Map<String, Object?>;
      final rewritten = <String, Object?>{
        ...databaseJson,
        'characters': <Object?>['not-a-row'],
      };
      final databaseBytes = Uint8List.fromList(
        utf8.encode(jsonEncode(rewritten)),
      );
      final manifestJson =
          jsonDecode(
                utf8.decode(
                  archive.findFile('manifest.json')!.content as List<int>,
                ),
              )
              as Map<String, Object?>;
      manifestJson['sha256'] = sha256.convert(databaseBytes).toString();
      final rebuilt = Archive()
        ..addFile(ArchiveFile.bytes('database.json', databaseBytes))
        ..addFile(
          ArchiveFile.bytes(
            'manifest.json',
            utf8.encode(jsonEncode(manifestJson)),
          ),
        );
      final corrupted = Uint8List.fromList(ZipEncoder().encode(rebuilt));

      final preview = await targetService.previewArchive(corrupted);
      expect(preview.valid, isTrue, reason: preview.error ?? '');
      await expectLater(
        targetService.restoreArchive(preview),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('characters'),
          ),
        ),
      );
      // 整个 restore 事务回滚：目标库仍为空。
      expect(await target.select(target.characters).get(), isEmpty);

      await source.close();
      await target.close();
    });

    test('rejects corrupted archive preview', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final service = DriftLocalDataArchiveService(db);

      final corrupted = Uint8List.fromList([0x00, 0x01, 0x02, 0x03]);
      final preview = await service.previewArchive(corrupted);

      expect(preview.valid, isFalse);
      expect(preview.error, isNotNull);

      await db.close();
    });

    test(
      'rejects archive with mismatched sha256 and leaves target unchanged',
      () async {
        final source = AppDatabase.forTesting(NativeDatabase.memory());
        final target = AppDatabase.forTesting(NativeDatabase.memory());
        await seedBackupFixture(source);

        final sourceService = DriftLocalDataArchiveService(source);
        final targetService = DriftLocalDataArchiveService(target);

        final bytes = await sourceService.exportArchive();

        // Tamper with database.json without updating the manifest hash.
        final archive = ZipDecoder().decodeBytes(bytes);
        final dbFile = archive.findFile('database.json')!;
        final original = utf8.decode(dbFile.content as List<int>);
        final tampered = original.replaceAll('Arannis', 'EvilClone');
        archive.removeFile(dbFile);
        archive.addFile(
          ArchiveFile.bytes('database.json', utf8.encode(tampered)),
        );
        final tamperedBytes = Uint8List.fromList(ZipEncoder().encode(archive));

        final preview = await targetService.previewArchive(tamperedBytes);
        expect(preview.valid, isFalse);

        // Target database must remain empty.
        expect(await target.select(target.characters).get(), isEmpty);

        await source.close();
        await target.close();
      },
    );

    test('manifest sha256 matches actual database.json content', () async {
      final source = AppDatabase.forTesting(NativeDatabase.memory());
      await seedBackupFixture(source);
      final service = DriftLocalDataArchiveService(source);

      final bytes = await service.exportArchive();
      final archive = ZipDecoder().decodeBytes(bytes);

      final manifestJson =
          jsonDecode(
                utf8.decode(
                  archive.findFile('manifest.json')!.content as List<int>,
                ),
              )
              as Map<String, Object?>;
      final dbContent = utf8.encode(
        utf8.decode(archive.findFile('database.json')!.content as List<int>),
      );
      final expectedHash = sha256.convert(dbContent).toString();

      expect(manifestJson['sha256'], expectedHash);

      await source.close();
    });
  });
}
