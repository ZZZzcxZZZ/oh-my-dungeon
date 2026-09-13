// 任务 11：导入报告与导入预览显示列级规则来源（契约 §3.7）。
//
// 报告新增 `classRuleSources`：每个 class 条目的列 → 来源。来源必须来自**生产解析
// 链** `RuleProfileResolver.resolveClassRules`，导入预览阶段的语义是"只看这个包 +
// 内置档案"（不接跨包索引——冲突是运行期概念）。预览以次级样式列出
// "条目 · 列展示名 ← 内置档案 / 包 id"，只提示、不阻断确认。
//
// 档案装配由 `test/flutter_test_config.dart` 全局完成（重复 configure 会被拒绝），
// 这里不再自己 setUpAll。
import 'package:dnd_table_client/src/features/content/data/import/content_package_importer.dart';
import 'package:dnd_table_client/src/features/content/presentation/content_import_preview_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'rules/package_json_test_support.dart';
import 'support/content_test_support.dart';

void main() {
  late MemoryContentRepository repository;
  late ContentPackageImporter importer;

  setUp(() {
    repository = MemoryContentRepository();
    importer = ContentPackageImporter(repository);
  });

  test('导入报告记录每个 class 条目的列级来源', () async {
    final report = await importer.previewJson(
      packageJson(
        id: 'patch-pack',
        entry: classEntry(
          packageId: 'patch-pack',
          slug: 'wizard',
          // 条目只覆盖 spellcasting.prepared，其余列来自内置档案
          classRules: {
            'spellcasting': {
              'prepared': {'5': 9},
            },
          },
        ),
      ),
    );
    expect(report.valid, isTrue, reason: '${report.errors}');

    final sources = report.classRuleSources['patch-pack:class/wizard']!;
    final byField = {
      for (final source in sources) source.field: source.originId,
    };
    expect(byField['spellcasting.prepared'], 'patch-pack:class/wizard');
    expect(byField['spellcasting.mode'], 'builtin:dnd5e-2024');
    expect(byField['spellcasting.ability'], 'builtin:dnd5e-2024');
    expect(byField['spellcasting.archetype'], 'builtin:dnd5e-2024');
    expect(byField['hitDie'], 'builtin:dnd5e-2024');
    // 内置 wizard 的 `slots` 由 `archetype: full-caster` 在**读取时**展开（§3.3），
    // 档案并没有声明 `slots` 这一列；§3.7 的来源只记"声明者"，因此这里照实为空
    // （不猜、也不把原型展开的结果记到内置档案名下）。同理 `spellcasting.slots`
    // 不在表里。
    expect(byField.containsKey('spellcasting.slots'), isFalse);
    // 条目自身声明的列按 tier = 100 + priority（缺省 0）记录。
    expect(
      sources.singleWhere((s) => s.field == 'spellcasting.prepared').tier,
      100,
    );
    // 来源列表按字段路径升序（结果可复现，UI 不抖动）。
    expect(
      [for (final source in sources) source.field],
      [for (final source in sources) source.field]..sort(),
    );
  });

  testWidgets('导入预览列出条目的来源摘要，不阻断确认', (tester) async {
    final report = await importer.previewJson(
      packageJson(
        id: 'patch-pack',
        entry: classEntry(
          packageId: 'patch-pack',
          slug: 'wizard',
          classRules: {
            'spellcasting': {
              'prepared': {'5': 9},
            },
          },
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ContentImportPreviewDialog(report: report, onConfirm: () async {}),
      ),
    );
    expect(find.byKey(const Key('import-preview-sources')), findsOneWidget);
    expect(find.textContaining('内置档案'), findsWidgets);
    expect(
      find.byKey(const Key('import-preview-sources-confirm')),
      findsOneWidget,
    );
  });
}
