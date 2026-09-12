import 'dart:convert';

import 'package:dnd_table_client/src/features/content/data/import/content_package_importer.dart';
import 'package:dnd_table_client/src/features/content/data/local/content_repository.dart';
import 'package:dnd_table_client/src/features/content/domain/content_file_picker.dart';
import 'package:dnd_table_client/src/features/content/presentation/batch_import_wizard_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/content_test_support.dart';

void main() {
  late MemoryContentRepository repository;
  late ContentPackageImporter importer;

  setUp(() {
    repository = MemoryContentRepository();
    importer = ContentPackageImporter(repository);
  });

  PickedContentFile packageFile({
    required String id,
    required String name,
    int entryCount = 1,
  }) {
    final json = jsonEncode({
      'formatVersion': 3,
      'id': id,
      'name': name,
      'version': '1.0.0',
      'locale': 'zh-CN',
      'system': 'dnd5e-2024',
      'entryCount': entryCount,
      'entries': [
        {...testFighterEntry().toJson(), 'id': '$id:class/fighter'},
      ],
    });
    return PickedContentFile(name: '$id.json', bytes: utf8.encode(json));
  }

  /// 一个**有效但带 warning** 的包：自制职业声明了空的 classRules，
  /// 于是拿到 `missingCoreField`（缺 hitDie）提示，但不阻断导入。
  PickedContentFile warningFile({required String id, int zeroResources = 0}) {
    final json = jsonEncode({
      'formatVersion': 3,
      'id': id,
      'name': id,
      'version': '1.0.0',
      'locale': 'zh-CN',
      'system': 'dnd5e-2024',
      'entryCount': 1,
      'entries': [
        {
          ...testFighterEntry().toJson(),
          'id': '$id:class/homebrew-sage',
          'slug': 'homebrew-sage',
          'structured': {
            'classRules': <String, Object?>{
              // 每张"3 级起上限恒为 0"的表各自产出 1 条 zeroLevelResource。
              'resources': [
                for (var index = 0; index < zeroResources; index++)
                  {
                    'id': 'focus-$index',
                    'name': '专注 $index',
                    'recovery': 'longRest',
                    'startsAtLevel': 3,
                    'maximum': {
                      'table': {'1': 0},
                    },
                  },
              ],
            },
          },
        },
      ],
    });
    return PickedContentFile(name: '$id.json', bytes: utf8.encode(json));
  }

  PickedContentFile invalidFile({required String id}) {
    final json = jsonEncode({
      'formatVersion': 3,
      'id': id,
      'name': id,
      'version': '1.0.0',
      'locale': 'zh-CN',
      'system': 'dnd5e-2024',
      'entryCount': 99,
      'entries': [
        {...testFighterEntry().toJson(), 'id': '$id:class/fighter'},
      ],
    });
    return PickedContentFile(name: '$id.json', bytes: utf8.encode(json));
  }

  Future<void> pumpDialog(
    WidgetTester tester, {
    required List<PickedContentFile> files,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              // 模拟实际使用场景: 在 Scaffold 内通过 showDialog 弹出.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                showDialog<void>(
                  context: context,
                  builder: (_) =>
                      BatchImportWizardDialog(files: files, importer: importer),
                );
              });
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders preview for each picked file with checkbox', (
    tester,
  ) async {
    await pumpDialog(
      tester,
      files: [
        packageFile(id: 'alpha', name: 'Alpha Pack'),
        packageFile(id: 'beta', name: 'Beta Pack'),
      ],
    );

    expect(find.text('批量导入预览'), findsOneWidget);
    expect(find.text('Alpha Pack'), findsOneWidget);
    expect(find.text('Beta Pack'), findsOneWidget);
    // 默认全选有效项.
    expect(find.widgetWithText(FilledButton, '导入 2 个'), findsOneWidget);
  });

  testWidgets('imports all selected packages on confirm', (tester) async {
    await pumpDialog(
      tester,
      files: [
        packageFile(id: 'alpha', name: 'Alpha Pack'),
        packageFile(id: 'beta', name: 'Beta Pack'),
      ],
    );

    await tester.tap(find.widgetWithText(FilledButton, '导入 2 个'));
    await tester.pumpAndSettle();

    final packages = await repository.watchPackages().first;
    expect(packages.map((p) => p.id), containsAll(['alpha', 'beta']));
    expect(await repository.search(const ContentQuery()), hasLength(2));
  });

  testWidgets('marks invalid files as disabled with error hint', (
    tester,
  ) async {
    await pumpDialog(
      tester,
      files: [
        packageFile(id: 'alpha', name: 'Alpha Pack'),
        invalidFile(id: 'broken'),
      ],
    );

    // 无效文件展示错误标识.
    expect(find.textContaining('entryCount'), findsOneWidget);
    // 无效文件不可勾选, 因此有效导入按钮只显示 1 个.
    expect(find.widgetWithText(FilledButton, '导入 1 个'), findsOneWidget);
  });

  testWidgets('shows rule warnings for valid files instead of dropping them', (
    tester,
  ) async {
    await pumpDialog(
      tester,
      files: [
        packageFile(id: 'alpha', name: 'Alpha Pack'),
        warningFile(id: 'gamma'),
      ],
    );

    // 有效：依旧可以勾选导入。
    expect(find.widgetWithText(FilledButton, '导入 2 个'), findsOneWidget);
    // warning 不能像以前那样被静默丢掉。
    expect(find.text('提示（不阻断导入）'), findsOneWidget);
    expect(find.textContaining('missingCoreField'), findsOneWidget);
    // key 带索引：同一包的多条 warning 各有各的定位点（以前全一样）。
    expect(
      find.byKey(const Key('batch-import-warning-gamma-0')),
      findsOneWidget,
    );
  });

  testWidgets('超过 3 条 warning 时截断可见并显式说明还有多少条', (tester) async {
    await pumpDialog(
      tester,
      files: [
        packageFile(id: 'alpha', name: 'Alpha Pack'),
        // 4 条 zeroLevelResource + 1 条 missingCoreField = 5 条 warning。
        warningFile(id: 'gamma', zeroResources: 4),
      ],
    );

    // 前 3 条渲染出来，各自有独立 key。
    for (var index = 0; index < 3; index++) {
      expect(
        find.byKey(Key('batch-import-warning-gamma-$index')),
        findsOneWidget,
        reason: '第 $index 条 warning 必须可见且有独立 key',
      );
    }
    expect(
      find.byKey(const Key('batch-import-warning-gamma-3')),
      findsNothing,
    );
    // 截断**不静默**：显式说还有 2 条（共 5 条）。
    expect(find.textContaining('还有 2 条'), findsOneWidget);
    expect(find.textContaining('共 5 条'), findsOneWidget);
  });

  testWidgets('skips unchecked files when importing', (tester) async {
    await pumpDialog(
      tester,
      files: [
        packageFile(id: 'alpha', name: 'Alpha Pack'),
        packageFile(id: 'beta', name: 'Beta Pack'),
      ],
    );

    // 取消勾选第二个.
    await tester.tap(find.byKey(const Key('batch-import-checkbox-beta')));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, '导入 1 个'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '导入 1 个'));
    await tester.pumpAndSettle();

    final packages = await repository.watchPackages().first;
    expect(packages.map((p) => p.id), ['alpha']);
  });

  testWidgets('shows summary snackbar after batch import completes', (
    tester,
  ) async {
    await pumpDialog(
      tester,
      files: [
        packageFile(id: 'alpha', name: 'Alpha Pack'),
        packageFile(id: 'beta', name: 'Beta Pack'),
      ],
    );

    await tester.tap(find.widgetWithText(FilledButton, '导入 2 个'));
    await tester.pumpAndSettle();

    expect(find.textContaining('已导入 2 个资料包'), findsOneWidget);
  });

  testWidgets('select all and deselect all toggle buttons work', (
    tester,
  ) async {
    await pumpDialog(
      tester,
      files: [
        packageFile(id: 'alpha', name: 'Alpha Pack'),
        packageFile(id: 'beta', name: 'Beta Pack'),
      ],
    );

    // 默认全选, 取消全选.
    await tester.tap(find.text('取消全选'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, '导入 0 个'), findsOneWidget);

    // 重新全选.
    await tester.tap(find.text('全选'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, '导入 2 个'), findsOneWidget);
  });
}
