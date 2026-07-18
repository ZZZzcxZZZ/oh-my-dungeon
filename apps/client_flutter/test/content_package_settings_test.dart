import 'dart:convert';

import 'package:dnd_table_client/src/features/content/data/import/content_package_importer.dart';
import 'package:dnd_table_client/src/features/content/data/local/content_repository.dart';
import 'package:dnd_table_client/src/features/content/domain/content_file_picker.dart';
import 'package:dnd_table_client/src/features/content/presentation/content_package_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/content_test_support.dart';

void main() {
  testWidgets('previews and imports a local package from settings', (tester) async {
    final bytes = utf8.encode(jsonEncode({
      'formatVersion': 1,
      'id': 'example',
      'name': 'Example',
      'version': '1.0.0',
      'locale': 'zh-CN',
      'system': 'dnd5e-2024',
      'entryCount': 1,
      'entries': [testFighterEntry().toJson()],
    }));
    final picker = MemoryContentFilePicker(
      result: PickedContentFile(name: 'example.json', bytes: bytes),
    );
    final repository = MemoryContentRepository();
    await tester.pumpWidget(MaterialApp(
      home: ContentPackageSettingsPage(
        repository: repository,
        importer: ContentPackageImporter(repository),
        filePicker: picker,
      ),
    ));
    await tester.tap(find.text('从文件导入'));
    await tester.pumpAndSettle();
    expect(find.text('1 个条目'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '确认导入'));
    await tester.pumpAndSettle();
    expect(await repository.search(const ContentQuery()), hasLength(1));
  });

  testWidgets('shows installed packages with enable toggle', (tester) async {
    final repository = MemoryContentRepository();
    final importer = ContentPackageImporter(repository);
    // Pre-import a package so the list shows it
    final report = await importer.previewJson(jsonEncode({
      'formatVersion': 1,
      'id': 'example',
      'name': 'Example',
      'version': '1.0.0',
      'locale': 'zh-CN',
      'system': 'dnd5e-2024',
      'entryCount': 1,
      'entries': [testFighterEntry().toJson()],
    }));
    await importer.importReport(report);

    await tester.pumpWidget(MaterialApp(
      home: ContentPackageSettingsPage(
        repository: repository,
        importer: importer,
        filePicker: MemoryContentFilePicker(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Example'), findsOneWidget);
    expect(find.text('1.0.0'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
  });

  testWidgets('confirms deletion with impact summary', (tester) async {
    final repository = MemoryContentRepository();
    final importer = ContentPackageImporter(repository);
    final report = await importer.previewJson(jsonEncode({
      'formatVersion': 1,
      'id': 'example',
      'name': 'Example',
      'version': '1.0.0',
      'locale': 'zh-CN',
      'system': 'dnd5e-2024',
      'entryCount': 1,
      'entries': [testFighterEntry().toJson()],
    }));
    await importer.importReport(report);

    await tester.pumpWidget(MaterialApp(
      home: ContentPackageSettingsPage(
        repository: repository,
        importer: importer,
        filePicker: MemoryContentFilePicker(),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    // Delete confirmation dialog should show impact (1 entry)
    expect(find.textContaining('1'), findsWidgets);
    expect(find.widgetWithText(TextButton, '取消'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '删除'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();
    expect(await repository.search(const ContentQuery()), isEmpty);
  });

  testWidgets('rejects invalid package preview', (tester) async {
    final bytes = utf8.encode(jsonEncode({
      'formatVersion': 1,
      'id': 'example',
      'name': 'Example',
      'version': '1.0.0',
      'locale': 'zh-CN',
      'system': 'dnd5e-2024',
      'entryCount': 2,
      'entries': [testFighterEntry().toJson()],
    }));
    final picker = MemoryContentFilePicker(
      result: PickedContentFile(name: 'example.json', bytes: bytes),
    );
    final repository = MemoryContentRepository();
    await tester.pumpWidget(MaterialApp(
      home: ContentPackageSettingsPage(
        repository: repository,
        importer: ContentPackageImporter(repository),
        filePicker: picker,
      ),
    ));
    await tester.tap(find.text('从文件导入'));
    await tester.pumpAndSettle();
    expect(find.text('1 个条目'), findsNothing);
    expect(find.textContaining('entryCount'), findsWidgets);
    expect(await repository.search(const ContentQuery()), isEmpty);
  });

  // Spec §资料包: 提供"清除所有本地资料包"入口，让用户在旧版数据污染时
  // 一键重置；删除前必须二次确认并显示影响范围。
  testWidgets('clears all local packages after confirmation', (tester) async {
    final repository = MemoryContentRepository();
    final importer = ContentPackageImporter(repository);
    for (final packageId in ['alpha', 'beta']) {
      final report = await importer.previewJson(jsonEncode({
        'formatVersion': 1,
        'id': packageId,
        'name': packageId,
        'version': '1.0.0',
        'locale': 'zh-CN',
        'system': 'dnd5e-2024',
        'entryCount': 1,
        'entries': [
          {
            ...testFighterEntry().toJson(),
            'id': '$packageId:class/fighter',
          },
        ],
      }));
      await importer.importReport(report);
    }
    expect(await repository.watchPackages().first, hasLength(2));

    await tester.pumpWidget(MaterialApp(
      home: ContentPackageSettingsPage(
        repository: repository,
        importer: importer,
        filePicker: MemoryContentFilePicker(),
      ),
    ));
    await tester.pumpAndSettle();

    // "清除所有本地资料包" 入口可见。
    expect(find.text('清除所有本地资料包'), findsOneWidget);
    await tester.tap(find.text('清除所有本地资料包'));
    await tester.pumpAndSettle();

    // 二次确认对话框显示影响范围 (2 个资料包)。
    expect(find.textContaining('2'), findsWidgets);
    expect(find.widgetWithText(TextButton, '取消'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '清除'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '清除'));
    await tester.pumpAndSettle();

    expect(await repository.watchPackages().first, isEmpty);
    expect(await repository.search(const ContentQuery()), isEmpty);
  });

  testWidgets('cancel clear-all preserves installed packages', (tester) async {
    final repository = MemoryContentRepository();
    final importer = ContentPackageImporter(repository);
    final report = await importer.previewJson(jsonEncode({
      'formatVersion': 1,
      'id': 'example',
      'name': 'Example',
      'version': '1.0.0',
      'locale': 'zh-CN',
      'system': 'dnd5e-2024',
      'entryCount': 1,
      'entries': [testFighterEntry().toJson()],
    }));
    await importer.importReport(report);

    await tester.pumpWidget(MaterialApp(
      home: ContentPackageSettingsPage(
        repository: repository,
        importer: importer,
        filePicker: MemoryContentFilePicker(),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('清除所有本地资料包'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();

    expect(await repository.watchPackages().first, hasLength(1));
  });
}
