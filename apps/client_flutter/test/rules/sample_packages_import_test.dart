import 'dart:convert';
import 'dart:io';

import 'package:dnd_table_client/src/core/database/app_database.dart';
import 'package:dnd_table_client/src/features/content/data/import/content_package_importer.dart';
import 'package:dnd_table_client/src/features/characters/domain/character_edit_draft.dart';
import 'package:dnd_table_client/src/features/characters/domain/rules_driven_character_builder.dart';
import 'package:dnd_table_client/src/features/content/data/local/content_repository.dart';
import 'package:dnd_table_client/src/features/rules/domain/character_build.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// `samples/*` 是**仓库内跟踪的**示例包，是第三方作者的抄写模板：它们必须能被
/// 真实导入器整包接受。一个导入即报错的示例包比没有更糟——作者会照着写出同样
/// 不被接受的包，然后以为是自己写错了。
///
/// 因此这里用真实的 [ContentPackageImporter.previewJson]（与用户导入走同一条
/// 校验链），断言 `errors` 为空、`valid` 为 true、`entryCount > 0`。
/// **不 skip**：样本目录或文件缺失就是仓库状态坏了，测试该红。
///
/// `flutter test` 的工作目录是包根 `apps/client_flutter`，样本在仓库根的
/// `samples/`，因此路径是 `../../samples`。
void main() {
  final samplesDir = Directory('../../samples');
  final packageDirs =
      (samplesDir.existsSync()
            ? samplesDir.listSync().whereType<Directory>().toList()
            : <Directory>[])
        ..sort((a, b) => a.path.compareTo(b.path));

  test('samples/ 下存在示例包（路径不对即红，不静默空转）', () {
    expect(
      samplesDir.existsSync(),
      isTrue,
      reason: '示例包目录缺失：${samplesDir.absolute.path}',
    );
    expect(
      packageDirs,
      isNotEmpty,
      reason: '${samplesDir.absolute.path} 下没有任何示例包目录',
    );
    for (final dir in packageDirs) {
      expect(
        File('${dir.path}/entries.json').existsSync(),
        isTrue,
        reason: '${dir.path} 缺少 entries.json',
      );
      expect(
        File('${dir.path}/manifest.json').existsSync(),
        isTrue,
        reason: '${dir.path} 缺少 manifest.json',
      );
    }
  });

  for (final dir in packageDirs) {
    final sampleName = dir.path.split(Platform.pathSeparator).last;

    test('示例包 samples/$sampleName 能被真实导入器整包导入', () async {
      final manifest =
          jsonDecode(File('${dir.path}/manifest.json').readAsStringSync())
              as Map<String, Object?>;
      final entries =
          jsonDecode(File('${dir.path}/entries.json').readAsStringSync())
              as List<Object?>;
      // 与 `previewDndpack` 组装真实 `.dndpack` 的方式一致：manifest 顶层字段
      // + `entries` 数组。
      final combined = Map<String, Object?>.from(manifest)
        ..['entries'] = entries;

      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final report = await ContentPackageImporter(
        DriftContentRepository(database),
      ).previewJson(jsonEncode(combined));

      expect(
        report.errors.map((error) => '${error.path}: ${error.message}').toList(),
        isEmpty,
        reason: 'samples/$sampleName 是给第三方作者抄的模板，必须可导入',
      );
      expect(report.valid, isTrue, reason: 'samples/$sampleName');
      expect(
        report.entryCount,
        greaterThan(0),
        reason: 'samples/$sampleName',
      );
      expect(
        report.entryCount,
        entries.length,
        reason: 'samples/$sampleName 的 manifest.entryCount 与实际条目数一致',
      );
    });
  }

  test('最小示例包的值选项：内联 grants 选中即生效（docs/README.md §9.2.6 的表格断言）', () {
    // §9.2.6 的表格声称"值选项的授予生效"（field-medic → hitPoints、pathfinder → speed）。
    // 文档里的示例包是被测试复用**同一份数据**的，这里就把那句话变成可执行的断言：
    // 导入 `samples/homebrew-partial-class` 后直接建角色，比较选中 / 不选中的派生结果。
    final dir = Directory('../../samples/homebrew-partial-class');
    final rawEntries =
        jsonDecode(File('${dir.path}/entries.json').readAsStringSync())
            as List<Object?>;
    final entries = <String, ContentEntry>{};
    for (final raw in rawEntries) {
      if (raw is! Map) continue;
      final entry = ContentEntry.fromJson(Map<String, Object?>.from(raw));
      entries[entry.id] = entry;
    }
    const classId = 'wayfinder:class/wayfinder';
    const focusKey = '$classId#wayfinder-focus';

    CharacterEditDraft buildWith(List<String>? picked) =>
        RulesDrivenCharacterBuilder(
      entries: entries,
        ).build(
      name: '引路者',
      build: CharacterBuild(
        level: 1,
        selections: const <String, String>{'class': classId},
        choices: <String, List<String>>{focusKey: ?picked},
      ),
      abilities: const <String, int>{
        'str': 10,
        'dex': 14,
        'con': 14,
        'int': 10,
        'wis': 14,
        'cha': 10,
      },
    );

    final baseline = buildWith(null);
    final pathfinder = buildWith(const <String>['pathfinder']);
    final medic = buildWith(const <String>['field-medic']);

    expect(pathfinder.speed, baseline.speed + 5, reason: 'pathfinder 的 speed grant');
    expect(medic.maxHp, baseline.maxHp + 2, reason: 'field-medic 的 hitPoints grant');
    expect(baseline.speed, 30);
    expect(medic.speed, baseline.speed, reason: '没选的选项不得生效');
  });
}
