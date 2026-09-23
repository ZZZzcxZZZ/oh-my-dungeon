import 'package:dnd_table_client/src/features/content/data/campaign_aware_content_repository.dart';
import 'package:dnd_table_client/src/features/content/data/export/dndpack_exporter.dart';
import 'package:dnd_table_client/src/features/content/data/import/content_package_importer.dart';
import 'package:dnd_table_client/src/features/content/data/local/content_repository.dart';
import 'package:dnd_table_client/src/features/content/data/local/local_homebrew_content_service.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:dnd_table_client/src/features/content/domain/content_package_manifest.dart';
import 'package:dnd_table_client/src/features/characters/domain/rules_driven_character_builder.dart';
import 'package:dnd_table_client/src/features/rules/domain/character_build.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/campaign_test_support.dart';
import 'support/content_test_support.dart';

void main() {
  test('编辑职业规则后导出再导入，建卡只使用最终声明', () async {
    final source = MemoryContentRepository();
    final service = LocalHomebrewContentService(repository: source);
    final original = await service.create(
      type: 'class',
      name: '星骑士',
      structured: const {
        'classRules': {
          'hitDie': 10,
          'savingThrowAbilities': ['str', 'con'],
        },
      },
    );
    await service.update(
      existing: original,
      name: original.name,
      structured: const {
        'classRules': {'hitDie': 8},
      },
    );

    final export = await DndPackExporter(
      repository: source,
    ).build(packageId: LocalHomebrewContentService.packageId);
    final target = MemoryContentRepository();
    final importer = ContentPackageImporter(target);
    final report = await importer.previewDndPack(export.bytes);
    expect(report.valid, isTrue, reason: '${report.errors}');
    await importer.importReport(report);
    final imported = (await target.getByKey(original.id))!;
    expect(imported.structured['classRules'], {'hitDie': 8});

    final draft = RulesDrivenCharacterBuilder(entries: {imported.id: imported})
        .build(
          name: '莱娅',
          build: CharacterBuild(level: 1, selections: {'class': imported.id}),
          abilities: const {
            'str': 15,
            'dex': 13,
            'con': 14,
            'int': 10,
            'wis': 12,
            'cha': 8,
          },
        );
    expect(draft.data['hitDie'], 8);
    expect(draft.saves['str'], isFalse);
    expect(draft.saves['con'], isFalse);
  });

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

  test('生产装配（组合仓库）下导出可用：传输前缀被剥回包格式', () async {
    final local = MemoryContentRepository();
    // main_shell 注入设置页的正是这个组合仓库：读取时给本地条目 id、关系目标与
    // rules 引用加 `local:` 前缀。导出若不剥回去，真实导入器会直接判 error。
    final aware = CampaignAwareContentRepository(
      local: local,
      campaign: MemoryCampaignCacheRepository(),
      activeCampaignId: () => null,
    );
    Future<void> seed(Map<String, Object?> json) => local.upsertPackageEntry(
      manifest: LocalHomebrewContentService.packageManifest,
      entry: ContentEntry.fromJson(json),
    );
    await seed({
      'id': 'local-homebrew:classFeature/star',
      'type': 'classFeature',
      'slug': 'star',
      'name': '星辉',
      'body': <Object?>[],
      'revision': 1,
      'structured': <String, Object?>{'class': 'star-knight', 'level': 1},
    });
    await seed({
      'id': 'local-homebrew:class/star-knight',
      'type': 'class',
      'slug': 'star-knight',
      'name': '星骑士',
      'body': <Object?>[],
      'revision': 1,
      'structured': <String, Object?>{
        'classRules': <String, Object?>{'hitDie': 10},
      },
      'relations': <Object?>[
        {'type': 'related', 'targetId': 'local-homebrew:classFeature/star'},
      ],
      'rules': <String, Object?>{
        'progression': <Object?>[
          {
            'levels': [1],
            'grants': [
              {
                'id': 'g1',
                'kind': 'feature',
                'entryId': 'local-homebrew:classFeature/star',
              },
            ],
            'choices': [
              {
                'id': 'pick',
                'label': '挑一个特性',
                'optionType': 'classFeature',
                'minimum': 1,
                'maximum': 1,
                'optionEntryIds': ['local-homebrew:classFeature/star'],
                'recommendedEntryIds': ['local-homebrew:classFeature/star'],
              },
            ],
          },
        ],
      },
    });

    final export = await DndPackExporter(
      repository: aware,
      importer: ContentPackageImporter(local),
    ).build(packageId: LocalHomebrewContentService.packageId);

    final target = MemoryContentRepository();
    final importer = ContentPackageImporter(target);
    final report = await importer.previewDndPack(export.bytes);
    expect(report.valid, isTrue, reason: '${report.errors}');
    await importer.importReport(report);

    final entries = await target.search(const ContentQuery());
    expect(
      entries.map((entry) => entry.id).toList()..sort(),
      <String>[
        'local-homebrew:class/star-knight',
        'local-homebrew:classFeature/star',
      ],
    );
    final knight = entries.firstWhere((entry) => entry.type == 'class');
    expect(
      knight.relations.single.targetId,
      'local-homebrew:classFeature/star',
      reason: '关系目标也必须剥回包格式',
    );
    expect(
      knight.rules!.progression.single.grants.single.entryId,
      'local-homebrew:classFeature/star',
      reason: 'rules 里的条目引用同样不能被传输前缀带进包',
    );
    expect(
      knight.rules!.progression.single.choices.single.optionEntryIds,
      <String>['local-homebrew:classFeature/star'],
    );
    expect(
      knight.rules!.progression.single.choices.single.recommendedEntryIds,
      <String>['local-homebrew:classFeature/star'],
    );

    // 写方向（评审阻塞 B-1）：作者在设置页「编辑」保存后，本地库必须仍然存**规范 id**。
    // 组合仓库读取时给 relations / rules 引用加前缀，保存时若不剥回去，本地就会存下
    // `local:local-homebrew:…`；再读一次变两层前缀、导出只剥一层 → 该包从此导不出去。
    final service = LocalHomebrewContentService(repository: aware);
    final editing = (await aware.search(const ContentQuery(type: 'class'))).single;
    await service.update(
      existing: editing,
      name: '星骑士（改名）',
      structured: editing.structured,
    );
    final stored = (await local.getByKey('local-homebrew:class/star-knight'))!;
    expect(
      stored.relations.single.targetId,
      'local-homebrew:classFeature/star',
      reason: '本地库不能存带传输前缀的关系目标',
    );
    expect(
      stored.rules!.progression.single.grants.single.entryId,
      'local-homebrew:classFeature/star',
    );
    expect(
      stored.rules!.progression.single.choices.single.optionEntryIds,
      <String>['local-homebrew:classFeature/star'],
    );

    final reExport = await DndPackExporter(
      repository: aware,
      importer: ContentPackageImporter(local),
    ).build(packageId: LocalHomebrewContentService.packageId);
    final reReport = await ContentPackageImporter(
      MemoryContentRepository(),
    ).previewDndPack(reExport.bytes);
    expect(reReport.valid, isTrue, reason: '${reReport.errors}');
  });

  test('资源是"待补齐补丁"：缺 name/maximum 且档案无同 id 时报 incompleteResourcePatch', () async {
    final repository = MemoryContentRepository();
    Future<void> seed(Map<String, Object?> classRules) =>
        repository.upsertPackageEntry(
          manifest: LocalHomebrewContentService.packageManifest,
          entry: ContentEntry.fromJson({
            'id': 'local-homebrew:class/star-knight',
            'type': 'class',
            'slug': 'star-knight',
            'name': '星骑士',
            'body': <Object?>[],
            'revision': 1,
            'structured': <String, Object?>{'classRules': classRules},
          }),
        );

    // 表单"添加资源"的默认形状 = 只声明 id：形状层合法（`ClassRuleSet.parse` 无
    // error），但档案里没有同 id 资源可补齐，真实导出链会判 `incompleteResourcePatch`。
    // 这正是"新资源是待补齐补丁"的契约含义——不是可以一路存到导出才炸的合法终态。
    await seed({
      'hitDie': 10,
      'resources': [
        {'id': 'resource-1'},
      ],
    });
    await expectLater(
      DndPackExporter(repository: repository).build(
        packageId: LocalHomebrewContentService.packageId,
      ),
      throwsA(
        isA<DndPackExportException>().having(
          (error) => error.report.errors.first.message,
          'message',
          contains('incompleteResourcePatch'),
        ),
      ),
    );

    // 补齐 name + maximum 后即可导出（作者必须把补丁写完）。
    await seed({
      'hitDie': 10,
      'resources': [
        {'id': 'resource-1', 'name': '专注点', 'maximum': 3},
      ],
    });
    final export = await DndPackExporter(
      repository: repository,
    ).build(packageId: LocalHomebrewContentService.packageId);
    expect(export.report.valid, isTrue, reason: '${export.report.errors}');
  });
}
