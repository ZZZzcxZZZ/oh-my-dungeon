import 'package:dnd_table_client/src/features/content/data/export/dndpack_exporter.dart';
import 'package:dnd_table_client/src/features/content/data/import/content_package_importer.dart';
import 'package:dnd_table_client/src/features/content/data/local/content_repository.dart';
import 'package:dnd_table_client/src/features/content/data/local/local_homebrew_content_service.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:dnd_table_client/src/features/content/domain/content_package_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/content_test_support.dart';

void main() {
  test('导出 → 导入往返：条目与 rules 逐项不变，manifest 为 formatVersion 3', () async {
    final repository = MemoryContentRepository();
    final service = LocalHomebrewContentService(repository: repository);
    await service.create(
      type: 'class',
      name: '织星者',
      structured: const {
        'classRules': {
          'hitDie': 8,
          'savingThrowAbilities': ['int', 'wis'],
        },
      },
      rules: const {
        'progression': [
          {
            'levels': [1],
            'choices': [
              {
                'id': 'skills',
                'label': '选择两项技能熟练',
                'optionType': 'skill',
                'minimum': 2,
                'maximum': 2,
                'options': ['奥秘', '历史'],
              },
            ],
          },
        ],
      },
    );
    await service.create(
      type: 'spell',
      name: '星火',
      structured: const {'level': 0, 'school': '塑能'},
    );

    final export = await DndPackExporter(repository: repository).build(
      packageId: LocalHomebrewContentService.packageId,
    );

    expect(export.fileName, 'local-homebrew.dndpack');
    expect(export.report.valid, isTrue);

    // 用**另一个**仓库 + 真实导入器读回，确认产物可被真实链路接受。
    final target = MemoryContentRepository();
    final report = await ContentPackageImporter(
      target,
    ).previewDndPack(export.bytes);
    expect(
      report.errors.map((error) => '${error.path}: ${error.message}').toList(),
      isEmpty,
    );
    expect(report.valid, isTrue);
    expect(report.formatVersion, 3);
    expect(report.entryCount, 2);

    // `previewDndPack` 只校验不落库（它的契约就是"preview"）：先看报告里的解析结果，
    // 再用 `importReport` 真正写进目标仓库，两步都断言。
    expect((await target.search(const ContentQuery())), isEmpty);
    await ContentPackageImporter(target).importReport(report);
    final entries = await target.search(const ContentQuery());
    final byId = {for (final entry in entries) entry.id: entry};
    final classEntry = byId['local-homebrew:class/织星者'];
    expect(classEntry, isNotNull, reason: 'class 条目必须原样回来');
    expect(classEntry!.structured['classRules'], {
      'hitDie': 8,
      'savingThrowAbilities': ['int', 'wis'],
    });
    expect(classEntry.rules, isNotNull, reason: 'rules 必须随包导出');
    final choice = classEntry.rules!.progression.single.choices.single;
    expect(choice.id, 'skills');
    expect(choice.minimum, 2);
    expect(choice.options.map((option) => option.id), ['奥秘', '历史']);
    expect(byId.containsKey('local-homebrew:spell/星火'), isTrue);
  });

  test('导出前先自校验：坏包直接抛 DndPackExportException（带字段级报告）', () async {
    final repository = MemoryContentRepository();
    // 绕开服务层的 schema 校验，直接塞一个导入器不接受的条目（d7 不是合法骰面）。
    await repository.upsertPackageEntry(
      manifest: const ContentPackageManifest(
        formatVersion: 3,
        id: 'local-homebrew',
        name: '我的自制内容',
        version: '1.0.0',
        locale: 'zh-CN',
        system: 'dnd5e-2024',
        entryCount: 1,
      ),
      entry: ContentEntry.fromJson(<String, Object?>{
        'id': 'local-homebrew:class/broken',
        'type': 'class',
        'slug': 'broken',
        'name': '坏职业',
        'body': <Object?>[],
        'revision': 1,
        'structured': <String, Object?>{
          'classRules': <String, Object?>{'hitDie': 7},
        },
      }),
    );

    await expectLater(
      DndPackExporter(repository: repository).build(
        packageId: 'local-homebrew',
      ),
      throwsA(
        // 导入层的 code 写在本地化消息里（`ContentValidationError` 只有 path/message），
        // 这里断言消息即可确认是"生命骰非法"被拦住。
        isA<DndPackExportException>().having(
          (error) => error.report.errors.first.message,
          'message',
          contains('invalidHitDie'),
        ),
      ),
    );
  });

  test('包不存在 / 没有条目时明确报错，不产出一个空包', () async {
    final repository = MemoryContentRepository();
    await expectLater(
      DndPackExporter(repository: repository).build(packageId: 'nope'),
      throwsA(isA<StateError>()),
    );
  });
}
