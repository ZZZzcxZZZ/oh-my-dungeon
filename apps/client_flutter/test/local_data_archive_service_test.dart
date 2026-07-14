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
  await db.into(db.serverProfiles).insert(
        ServerProfilesCompanion.insert(
          id: 'localhost',
          name: 'Local Server',
          baseUrl: 'http://localhost:3000',
          apiBaseUrl: 'http://localhost:3000/api',
          websocketUrl: 'http://localhost:3000',
        ),
      );

  await db.into(db.localContentPackages).insert(
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

  await db.into(db.localContentEntries).insert(
        LocalContentEntriesCompanion.insert(
          entryKey: 'example:spell/fireball',
          packageId: 'example',
          type: 'spell',
          slug: 'fireball',
          name: '火球术',
          revision: 1,
        ),
      );

  await db.into(db.localContentAssets).insert(
        LocalContentAssetsCompanion.insert(
          packageId: 'example',
          relativePath: 'images/fireball.png',
          bytes: Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]),
          mediaType: const Value('image/png'),
          contentHash: const Value('asset-hash'),
        ),
      );

  await db.into(db.contentLinks).insert(
        ContentLinksCompanion.insert(
          id: 'link-1',
          sourceId: 'example:spell/fireball',
          targetId: 'example:class/sorcerer',
        ),
      );

  await db.into(db.contentFavorites).insert(
        ContentFavoritesCompanion.insert(
          entryKey: 'example:spell/fireball',
          createdAt: DateTime.utc(2026, 7, 14),
        ),
      );

  await db.into(db.contentNotes).insert(
        ContentNotesCompanion.insert(
          entryKey: 'example:spell/fireball',
          markdown: 'Remember to use this carefully.',
          updatedAt: DateTime.utc(2026, 7, 14),
        ),
      );

  await db.into(db.contentReadHistory).insert(
        ContentReadHistoryCompanion.insert(
          entryKey: 'example:spell/fireball',
          readAt: DateTime.utc(2026, 7, 14),
        ),
      );

  await db.into(db.characters).insert(
        CharactersCompanion.insert(
          id: 'char-1',
          sheetJson:
              '{"id":"char-1","name":"Arannis","level":3,"currentHp":24,"maxHp":24,"armorClass":15}',
        ),
      );

  await db.into(db.characterContentRefs).insert(
        CharacterContentRefsCompanion.insert(
          characterId: 'char-1',
          slot: 'class',
          entryKey: 'example:class/fighter',
        ),
      );
}

void main() {
  group('DriftLocalDataArchiveService', () {
    test('exports local-owned data and restores it atomically without tokens',
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
      final assetFile =
          archive.findFile('assets/example/images/fireball.png');
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
      expect(
        await target.select(target.contentNotes).get(),
        hasLength(1),
      );

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

    test('rejects archive with mismatched sha256 and leaves target unchanged',
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
      final tamperedBytes =
          Uint8List.fromList(ZipEncoder().encode(archive));

      final preview = await targetService.previewArchive(tamperedBytes);
      expect(preview.valid, isFalse);

      // Target database must remain empty.
      expect(await target.select(target.characters).get(), isEmpty);

      await source.close();
      await target.close();
    });

    test('clearCampaignCache removes only campaign tables', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final service = DriftLocalDataArchiveService(db);
      await seedBackupFixture(db);

      // Insert a campaign cache entry.
      await db.into(db.campaignContentCache).insert(
            CampaignContentCacheCompanion.insert(
              id: 'entry-1',
              campaignId: 'camp-1',
              type: 'location',
              slug: 'moon-harbor',
              name: '月港',
              revision: 1,
              createdBy: 'dm',
              updatedBy: 'dm',
              createdAt: DateTime.utc(2026, 7, 14),
              updatedAt: DateTime.utc(2026, 7, 14),
            ),
          );
      await db.into(db.campaignSyncCursors).insert(
            CampaignSyncCursorsCompanion.insert(
              campaignId: 'camp-1',
              updatedAt: DateTime.utc(2026, 7, 14),
            ),
          );

      await service.clearCampaignCache();

      // Campaign cache should be empty.
      expect(await db.select(db.campaignContentCache).get(), isEmpty);
      expect(await db.select(db.campaignSyncCursors).get(), isEmpty);

      // Personal data should be untouched.
      expect(await db.select(db.characters).get(), hasLength(1));
      expect(await db.select(db.localContentEntries).get(), hasLength(1));

      await db.close();
    });

    test('manifest sha256 matches actual database.json content', () async {
      final source = AppDatabase.forTesting(NativeDatabase.memory());
      await seedBackupFixture(source);
      final service = DriftLocalDataArchiveService(source);

      final bytes = await service.exportArchive();
      final archive = ZipDecoder().decodeBytes(bytes);

      final manifestJson =
          jsonDecode(utf8.decode(
            archive.findFile('manifest.json')!.content as List<int>,
          )) as Map<String, Object?>;
      final dbContent = utf8.encode(
        utf8.decode(
          archive.findFile('database.json')!.content as List<int>,
        ),
      );
      final expectedHash = sha256.convert(dbContent).toString();

      expect(manifestJson['sha256'], expectedHash);

      await source.close();
    });
  });
}
