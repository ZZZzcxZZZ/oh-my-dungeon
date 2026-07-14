import 'dart:typed_data';

import 'package:dnd_table_client/src/core/backup/local_backup_models.dart';
import 'package:dnd_table_client/src/core/backup/local_data_archive_service.dart';
import 'package:dnd_table_client/src/features/server_home/presentation/data_management_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory fake of [LocalDataArchiveService] for widget tests.
///
/// Records each method call so tests can assert on user interactions without
/// touching the filesystem or a real Drift database.
class MemoryLocalDataArchiveService implements LocalDataArchiveService {
  MemoryLocalDataArchiveService({this.validPreview = true});

  final bool validPreview;

  int exportCalls = 0;
  int previewCalls = 0;
  int restoreCalls = 0;
  int clearCacheCalls = 0;
  int rebuildIndexCalls = 0;

  ArchivePreview? lastPreview;

  @override
  Future<Uint8List> exportArchive() async {
    exportCalls++;
    return Uint8List.fromList([0x50, 0x4b, 0x03, 0x04]);
  }

  @override
  Future<ArchivePreview> previewArchive(Uint8List bytes) async {
    previewCalls++;
    if (!validPreview) {
      return ArchivePreview(
        valid: false,
        manifest: null,
        bytes: Uint8List(0),
        error: '无效存档',
      );
    }
    final manifest = LocalBackupManifest(
      formatVersion: 1,
      createdAt: '2026-07-14T00:00:00Z',
      clientVersion: '0.1.0',
      serverProfileCount: 1,
      packageCount: 1,
      entryCount: 1,
      assetCount: 1,
      characterCount: 1,
      totalSize: 42,
      sha256: 'abc',
    );
    final preview = ArchivePreview(
      valid: true,
      manifest: manifest,
      bytes: bytes,
    );
    lastPreview = preview;
    return preview;
  }

  @override
  Future<void> restoreArchive(ArchivePreview preview) async {
    restoreCalls++;
  }

  @override
  Future<void> clearCampaignCache() async {
    clearCacheCalls++;
  }

  @override
  Future<void> rebuildContentIndex() async {
    rebuildIndexCalls++;
  }
}

void main() {
  testWidgets(
    'opens data tools and requires confirmation before restore',
    (tester) async {
      final service = MemoryLocalDataArchiveService(validPreview: true);
      await tester.pumpWidget(MaterialApp(
        home: DataManagementPage(archiveService: service),
      ));

      // Tap "恢复备份" — must NOT restore immediately.
      await tester.tap(find.text('恢复备份'));
      await tester.pumpAndSettle();

      // The confirmation dialog must appear.
      expect(find.text('将替换此设备上的本地数据'), findsOneWidget);
      expect(service.restoreCalls, 0);

      // Confirm by tapping the affirmative action.
      await tester.tap(find.text('确认恢复'));
      await tester.pumpAndSettle();

      expect(service.restoreCalls, 1);
    },
  );

  testWidgets('export backup invokes the archive service', (tester) async {
    final service = MemoryLocalDataArchiveService(validPreview: true);
    await tester.pumpWidget(MaterialApp(
      home: DataManagementPage(archiveService: service),
    ));

    await tester.tap(find.text('导出备份'));
    await tester.pumpAndSettle();

    expect(service.exportCalls, 1);
  });

  testWidgets('clear campaign cache requires confirmation', (tester) async {
    final service = MemoryLocalDataArchiveService(validPreview: true);
    await tester.pumpWidget(MaterialApp(
      home: DataManagementPage(archiveService: service),
    ));

    await tester.tap(find.text('清理战役缓存'));
    await tester.pumpAndSettle();

    // The confirmation dialog must appear before clearing.
    expect(service.clearCacheCalls, 0);

    await tester.tap(find.text('确认清理'));
    await tester.pumpAndSettle();

    expect(service.clearCacheCalls, 1);
  });

  testWidgets('rebuild content index requires confirmation', (tester) async {
    final service = MemoryLocalDataArchiveService(validPreview: true);
    await tester.pumpWidget(MaterialApp(
      home: DataManagementPage(archiveService: service),
    ));

    await tester.tap(find.text('重建资料索引'));
    await tester.pumpAndSettle();

    expect(service.rebuildIndexCalls, 0);

    await tester.tap(find.text('确认重建'));
    await tester.pumpAndSettle();

    expect(service.rebuildIndexCalls, 1);
  });

  testWidgets(
    'restore shows preview details before confirmation',
    (tester) async {
      final service = MemoryLocalDataArchiveService(validPreview: true);
      await tester.pumpWidget(MaterialApp(
        home: DataManagementPage(archiveService: service),
      ));

      await tester.tap(find.text('恢复备份'));
      await tester.pumpAndSettle();

      // The dialog must surface preview details before the user confirms.
      expect(find.textContaining('角色'), findsWidgets);
      expect(find.textContaining('资料包'), findsWidgets);
    },
  );

  testWidgets('restore with invalid preview blocks confirmation',
      (tester) async {
    final service = MemoryLocalDataArchiveService(validPreview: false);
    await tester.pumpWidget(MaterialApp(
      home: DataManagementPage(archiveService: service),
    ));

    await tester.tap(find.text('恢复备份'));
    await tester.pumpAndSettle();

    // The error must be visible and the confirm button must be absent or
    // disabled — restore must not be callable.
    expect(find.textContaining('无效'), findsOneWidget);
    expect(service.restoreCalls, 0);
  });
}
