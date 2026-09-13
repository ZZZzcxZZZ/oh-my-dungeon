import 'dart:convert';

import 'package:dnd_table_client/src/features/content/data/import/content_package_importer.dart';
import 'package:dnd_table_client/src/features/content/data/local/content_repository.dart';
import 'package:dnd_table_client/src/features/content/domain/content_file_picker.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry_id.dart';
import 'package:dnd_table_client/src/features/content/presentation/content_package_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:dnd_table_client/src/features/content/data/local/local_homebrew_content_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/content_test_support.dart';

void main() {
  testWidgets('previews and imports a local package from settings', (
    tester,
  ) async {
    final bytes = utf8.encode(
      jsonEncode({
        'formatVersion': 3,
        'id': 'example',
        'name': 'Example',
        'version': '1.0.0',
        'locale': 'zh-CN',
        'system': 'dnd5e-2024',
        'entryCount': 1,
        'entries': [testFighterEntry().toJson()],
      }),
    );
    final picker = MemoryContentFilePicker(
      result: PickedContentFile(name: 'example.json', bytes: bytes),
    );
    final repository = MemoryContentRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: ContentPackageSettingsPage(
          repository: repository,
          importer: ContentPackageImporter(repository),
          filePicker: picker,
        ),
      ),
    );
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
    final report = await importer.previewJson(
      jsonEncode({
        'formatVersion': 3,
        'id': 'example',
        'name': 'Example',
        'version': '1.0.0',
        'locale': 'zh-CN',
        'system': 'dnd5e-2024',
        'entryCount': 1,
        'entries': [testFighterEntry().toJson()],
      }),
    );
    await importer.importReport(report);

    await tester.pumpWidget(
      MaterialApp(
        home: ContentPackageSettingsPage(
          repository: repository,
          importer: importer,
          filePicker: MemoryContentFilePicker(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Example'), findsOneWidget);
    expect(find.text('1.0.0'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
  });

  testWidgets('confirms deletion with impact summary', (tester) async {
    final repository = MemoryContentRepository();
    final importer = ContentPackageImporter(repository);
    final report = await importer.previewJson(
      jsonEncode({
        'formatVersion': 3,
        'id': 'example',
        'name': 'Example',
        'version': '1.0.0',
        'locale': 'zh-CN',
        'system': 'dnd5e-2024',
        'entryCount': 1,
        'entries': [testFighterEntry().toJson()],
      }),
    );
    await importer.importReport(report);

    await tester.pumpWidget(
      MaterialApp(
        home: ContentPackageSettingsPage(
          repository: repository,
          importer: importer,
          filePicker: MemoryContentFilePicker(),
        ),
      ),
    );
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
    final bytes = utf8.encode(
      jsonEncode({
        'formatVersion': 3,
        'id': 'example',
        'name': 'Example',
        'version': '1.0.0',
        'locale': 'zh-CN',
        'system': 'dnd5e-2024',
        'entryCount': 2,
        'entries': [testFighterEntry().toJson()],
      }),
    );
    final picker = MemoryContentFilePicker(
      result: PickedContentFile(name: 'example.json', bytes: bytes),
    );
    final repository = MemoryContentRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: ContentPackageSettingsPage(
          repository: repository,
          importer: ContentPackageImporter(repository),
          filePicker: picker,
        ),
      ),
    );
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
      final report = await importer.previewJson(
        jsonEncode({
          'formatVersion': 3,
          'id': packageId,
          'name': packageId,
          'version': '1.0.0',
          'locale': 'zh-CN',
          'system': 'dnd5e-2024',
          'entryCount': 1,
          'entries': [
            {...testFighterEntry().toJson(), 'id': '$packageId:class/fighter'},
          ],
        }),
      );
      await importer.importReport(report);
    }
    expect(await repository.watchPackages().first, hasLength(2));

    await tester.pumpWidget(
      MaterialApp(
        home: ContentPackageSettingsPage(
          repository: repository,
          importer: importer,
          filePicker: MemoryContentFilePicker(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // "清除所有本地资料包" 入口可见。
    expect(find.text('清除所有本地资料包'), findsOneWidget);
    // 新增的「我的自制内容」卡片会把入口推到视口外：先滚到可见再点。
    await tester.ensureVisible(find.text('清除所有本地资料包'));
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
    final report = await importer.previewJson(
      jsonEncode({
        'formatVersion': 3,
        'id': 'example',
        'name': 'Example',
        'version': '1.0.0',
        'locale': 'zh-CN',
        'system': 'dnd5e-2024',
        'entryCount': 1,
        'entries': [testFighterEntry().toJson()],
      }),
    );
    await importer.importReport(report);

    await tester.pumpWidget(
      MaterialApp(
        home: ContentPackageSettingsPage(
          repository: repository,
          importer: importer,
          filePicker: MemoryContentFilePicker(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('清除所有本地资料包'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();

    expect(await repository.watchPackages().first, hasLength(1));
  });

  // Spec §资料库 GUI 增强: 批量导入入口在资料包管理页可见,
  // 点击后通过 filePicker.pickMultiple 取多个文件并弹出确认向导.
  testWidgets(
    'batch import button opens wizard and imports multiple packages',
    (tester) async {
      final alphaBytes = utf8.encode(
        jsonEncode({
          'formatVersion': 3,
          'id': 'alpha',
          'name': 'Alpha',
          'version': '1.0.0',
          'locale': 'zh-CN',
          'system': 'dnd5e-2024',
          'entryCount': 1,
          'entries': [
            {...testFighterEntry().toJson(), 'id': 'alpha:class/fighter'},
          ],
        }),
      );
      final betaBytes = utf8.encode(
        jsonEncode({
          'formatVersion': 3,
          'id': 'beta',
          'name': 'Beta',
          'version': '1.0.0',
          'locale': 'zh-CN',
          'system': 'dnd5e-2024',
          'entryCount': 1,
          'entries': [
            {...testFighterEntry().toJson(), 'id': 'beta:class/fighter'},
          ],
        }),
      );
      final picker = MemoryContentFilePicker(
        multipleResult: [
          PickedContentFile(name: 'alpha.json', bytes: alphaBytes),
          PickedContentFile(name: 'beta.json', bytes: betaBytes),
        ],
      );
      final repository = MemoryContentRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: ContentPackageSettingsPage(
            repository: repository,
            importer: ContentPackageImporter(repository),
            filePicker: picker,
          ),
        ),
      );

      await tester.tap(find.text('批量导入'));
      await tester.pumpAndSettle();

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, '导入 2 个'));
      await tester.pumpAndSettle();

      final packages = await repository.watchPackages().first;
      expect(packages.map((p) => p.id), containsAll(['alpha', 'beta']));
    },
  );
  testWidgets('新建自制条目：类型/名称/structured/rules 落到 local-homebrew 包', (tester) async {
    final repository = MemoryContentRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: ContentPackageSettingsPage(
          repository: repository,
          importer: ContentPackageImporter(repository),
          filePicker: MemoryContentFilePicker(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('homebrew-entry-create-button')));
    await tester.pumpAndSettle();
    expect(find.text('新建自制条目'), findsOneWidget);

    // 类型下拉显式选 class：默认类型是第一个可创建类型（spell），它要求
    // level / school 这些必填字段，不属于本用例要验证的东西。
    await tester.tap(find.byKey(const Key('homebrew-entry-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('职业（class）').last);
    await tester.pumpAndSettle();

    // class 默认进可视化表单；这条用例验证的是 JSON 通道仍然可用（表单见
    // homebrew_class_rule_form_test.dart 与下面的覆盖用例）。
    await tester.tap(find.text('JSON'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('homebrew-entry-name')),
      '织星者',
    );
    await tester.enterText(
      find.byKey(const Key('homebrew-entry-structured')),
      '{"classRules": {"hitDie": 8}}',
    );
    await tester.enterText(
      find.byKey(const Key('homebrew-entry-rules')),
      '{"progression": [{"levels": [1], "grants": ['
      '{"id": "g1", "kind": "proficiency", "target": "skill:运动"}]}]}',
    );
    await tester.tap(find.byKey(const Key('homebrew-entry-save')));
    await tester.pumpAndSettle();

    // 对话框关闭 + 列表出现新条目。
    expect(find.text('新建自制条目'), findsNothing);
    final entries = await repository.search(
      const ContentQuery(packageId: LocalHomebrewContentService.packageId),
    );
    expect(entries, hasLength(1));
    expect(entries.single.name, '织星者');
    expect(entries.single.rules!.progression.single.grants.single.target, 'skill:运动');
    expect(find.byKey(const Key('homebrew-export-dndpack-button')), findsOneWidget);
  });

  testWidgets('基于现有条目创建覆盖：对齐键钉在来源条目上（S4）', (tester) async {
    final repository = MemoryContentRepository();
    final importer = ContentPackageImporter(repository);
    final report = await importer.previewJson(
      jsonEncode({
        'formatVersion': 3,
        'id': 'example',
        'name': 'Example',
        'version': '1.0.0',
        'locale': 'zh-CN',
        'system': 'dnd5e-2024',
        'entryCount': 3,
        'entries': [
          {
            'id': 'example:class/fighter',
            'type': 'class',
            'slug': 'fighter',
            'name': '战士',
            'body': <Object?>[],
            'revision': 1,
            'structured': {
              'classRules': {'hitDie': 10},
            },
            'rules': {
              'progression': [
                {
                  'levels': [1],
                  'grants': [
                    {
                      'id': 'g1',
                      'kind': 'feature',
                      // 指向**来源包内**的条目：预填进本地包就再也导不出去（S-1）。
                      'entryId': 'example:classFeature/second-wind',
                    },
                  ],
                },
              ],
            },
          },
          {
            'id': 'example:classFeature/second-wind',
            'type': 'classFeature',
            'slug': 'second-wind',
            'name': '回气',
            'body': <Object?>[],
            'revision': 1,
            'structured': {'class': 'fighter', 'level': 1},
          },
          {
            // 没有 classRules 的职业：不参与列级合并链，不作为覆盖来源。
            'id': 'example:class/no-rules',
            'type': 'class',
            'slug': 'no-rules',
            'name': '无规则职业',
            'body': <Object?>[],
            'revision': 1,
          },
        ],
      }),
    );
    expect(report.valid, isTrue, reason: '${report.errors}');
    await importer.importReport(report);

    await tester.pumpWidget(
      MaterialApp(
        home: ContentPackageSettingsPage(
          repository: repository,
          importer: importer,
          filePicker: MemoryContentFilePicker(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('homebrew-entry-create-override-button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('选择要覆盖的条目'), findsOneWidget);
    expect(
      find.byKey(const Key('homebrew-override-source-example:class/no-rules')),
      findsNothing,
      reason: '没有 classRules 的职业不参与合并链',
    );
    await tester.tap(
      find.byKey(const Key('homebrew-override-source-example:class/fighter')),
    );
    await tester.pumpAndSettle();

    // 覆盖模式：标题点明来源、对齐键提示在位、类型锁定、来源 classRules 预填。
    expect(find.text('创建覆盖：战士'), findsOneWidget);
    expect(find.byKey(const Key('homebrew-entry-override-hint')), findsOneWidget);
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const Key('homebrew-entry-type')),
          )
          .onChanged,
      isNull,
      reason: '覆盖必须与来源同类型',
    );
    expect(find.text('d10'), findsOneWidget, reason: '预填来源的 hitDie');

    // 但 **不预填来源的 rules**：来源 grants/choices 会引用来源包内的条目，
    // 带进本地包后这个包就再也导不出去（S-1）。
    final jsonSegment = find.descendant(
      of: find.byKey(const Key('homebrew-entry-editor-mode')),
      matching: find.text('JSON'),
    );
    await tester.ensureVisible(jsonSegment);
    await tester.pumpAndSettle();
    await tester.tap(jsonSegment);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('homebrew-entry-rules')))
          .controller!
          .text
          .trim(),
      '{}',
    );

    await tester.tap(find.byKey(const Key('homebrew-entry-save')));
    await tester.pumpAndSettle();

    final entries = await repository.search(
      const ContentQuery(packageId: LocalHomebrewContentService.packageId),
    );
    expect(entries, hasLength(1));
    expect(entries.single.id, 'local-homebrew:class/fighter');
    expect(
      contentEntryAlignmentKey(entries.single.id),
      contentEntryAlignmentKey('example:class/fighter'),
    );
    expect(
      entries.single.rules!.progression,
      isEmpty,
      reason: '覆盖不继承来源的 progression（跨包引用会让本包不可导出）',
    );
    // 已存在同键覆盖后，来源从候选里消失（再点只会提示没有可覆盖的条目）。
    await tester.tap(
      find.byKey(const Key('homebrew-entry-create-override-button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('选择要覆盖的条目'), findsNothing);
    expect(find.textContaining('没有可覆盖的职业条目'), findsOneWidget);
  });

  testWidgets('structured 不是合法 JSON → 就地报错、对话框不关、什么都没写', (tester) async {
    final repository = MemoryContentRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: ContentPackageSettingsPage(
          repository: repository,
          importer: ContentPackageImporter(repository),
          filePicker: MemoryContentFilePicker(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('homebrew-entry-create-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('homebrew-entry-name')), '坏的');
    await tester.enterText(
      find.byKey(const Key('homebrew-entry-structured')),
      '{not json',
    );
    await tester.tap(find.byKey(const Key('homebrew-entry-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('homebrew-entry-errors')), findsOneWidget);
    expect(find.textContaining('不是合法 JSON'), findsOneWidget);
    expect(find.text('新建自制条目'), findsOneWidget, reason: '出错不关对话框');
    expect(await repository.search(const ContentQuery()), isEmpty);
  });

  testWidgets('导出 .dndpack：产物能被真实导入器读回，文件名与条目数正确', (tester) async {
    final repository = MemoryContentRepository();
    final importer = ContentPackageImporter(repository);
    final service = LocalHomebrewContentService(repository: repository);
    await service.create(
      type: 'spell',
      name: '星火',
      structured: const {'level': 0, 'school': '塑能'},
    );

    String? exportedName;
    Uint8List? exportedBytes;
    await tester.pumpWidget(
      MaterialApp(
        home: ContentPackageSettingsPage(
          repository: repository,
          importer: importer,
          filePicker: MemoryContentFilePicker(),
          onExportDndPack: (fileName, bytes) async {
            exportedName = fileName;
            exportedBytes = bytes;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('homebrew-export-dndpack-button')));
    await tester.pumpAndSettle();

    expect(exportedName, 'local-homebrew.dndpack');
    expect(exportedBytes, isNotNull);
    final report = await ContentPackageImporter(
      MemoryContentRepository(),
    ).previewDndPack(exportedBytes!);
    expect(report.valid, isTrue, reason: '${report.errors}');
    expect(report.entryCount, 1);
    expect(find.textContaining('已导出'), findsOneWidget);
  });
}
