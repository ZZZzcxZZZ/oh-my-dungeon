// P0-2.6：campaign 角色卡的规则解析必须拿到与本地建档**同一份**包 priority。
//
// 缺陷：`openCampaignCharacterSheet` 只加载了 `contentEntries`，不传
// `packagePriorities` → `CharacterDetailPage.packagePriorities` 落到默认 `const {}`
// → campaign 内的 `RuleOverrideIndex` 让所有声明的 tier 都落回 100，priority 40 的
// 勘误压不过自身条目（短休 `archetype: pact` 判定也随之与本地不一致）。
import 'package:dnd_table_client/src/features/campaigns/presentation/characters/campaign_character_controller.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/characters/campaign_character_sheet_launcher.dart';
import 'package:dnd_table_client/src/features/characters/domain/character_rule_overrides.dart';
import 'package:dnd_table_client/src/features/characters/domain/dnd5e_rules.dart';
import 'package:dnd_table_client/src/features/characters/domain/rule_override_index.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_detail_page.dart';
import 'package:dnd_table_client/src/features/content/data/campaign_aware_content_repository.dart';
import 'package:dnd_table_client/src/features/content/data/local/content_repository.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:dnd_table_client/src/features/content/domain/content_package_manifest.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_override_declaration.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/campaign_test_support.dart';
import 'support/content_test_support.dart';

const _errataPriority = 40;

ContentEntry _classEntry(String id) => ContentEntry.fromJson(<String, Object?>{
  'id': id,
  'type': 'class',
  'slug': 'wizard',
  'name': '勘误法师',
  'body': <Object?>[],
  'revision': 1,
  'structured': <String, Object?>{
    'classRules': <String, Object?>{
      'spellcasting': <String, Object?>{
        'mode': 'prepared',
        'prepared': <String, Object?>{'5': 9},
      },
    },
  },
});

/// 生产装配：条目 id 会被重写成 `local:<id>` / `campaign:<cid>:<id>`。
///
/// 用裸 `MemoryContentRepository` 会让 `packageIdOf(entryId)` 恰好等于原始包 id，
/// 从而**绕过**真实的前缀问题（C3 的旧版用例就是这么假绿的）。
Future<CampaignAwareContentRepository> _repositoryWithErrata() async {
  final repository = CampaignAwareContentRepository(
    local: MemoryContentRepository(),
    campaign: MemoryCampaignCacheRepository(),
    activeCampaignId: () => 'c1',
  );
  await (repository.local as MemoryContentRepository).upsertPackageEntry(
    manifest: const ContentPackageManifest(
      formatVersion: 3,
      id: 'errata',
      name: '勘误包',
      version: '1.0.0',
      locale: 'zh-CN',
      system: 'dnd5e-2024',
      entryCount: 1,
      priority: _errataPriority,
    ),
    entry: _classEntry('errata:class/wizard'),
  );
  return repository;
}

void main() {
  testWidgets('campaign 角色卡拿到包 priority，tier 与本地一致（P0-2.6）', (tester) async {
    // 生产装配（条目 id 会带前缀）。其余前置断言拆在下一个用例里：这样本用例的
    // tier 断言本身就是第一个失败点，变异"优先级表不带前缀键"能直接咬到它，
    // 而不是被前置断言抢先挡下。
    final repository = await _repositoryWithErrata();

    final controller = CampaignCharacterController(
      cacheRepository: MemoryCampaignCacheRepository(
        characters: [
          testCampaignCharacter(
            id: 'w1',
            campaignId: 'c1',
            sheet: <String, Object?>{
              'name': '勘误法师',
              'level': 5,
              'classSummary': '法师',
              'data': <String, Object?>{
                'classIdentity': <String, Object?>{
                  'entryId': 'base:class/wizard',
                  'slug': 'wizard',
                  'declared': true,
                },
              },
            },
          ),
        ],
      ),
      apiClient: MemoryCampaignSyncApiClient(),
      apiBaseUrl: 'http://localhost:3000/api',
      accessToken: 'tok',
      currentUserId: 'dm-1',
    );
    await controller.selectCampaign('c1');

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => openCampaignCharacterSheet(
                  context: context,
                  controller: controller,
                  character: controller.characters.single,
                  canEditAnyCharacter: true,
                  contentRepository: repository,
                ),
                child: const Text('打开角色卡'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开角色卡'));
    await tester.pumpAndSettle();

    final page = tester.widget<CharacterDetailPage>(
      find.byType(CharacterDetailPage),
    );
    expect(page.contentEntries, isNotEmpty);
    expect(
      page.packagePriorities,
      isNotEmpty,
      reason: 'campaign 路径必须把包 priority 一起加载并透传',
    );
    expect(page.packagePriorities['errata'], _errataPriority);

    // tier 计算与本地一致：索引 + entryPriority 用页面拿到的同一份输入。
    final resolved = Dnd5eRules.resolveClassRules(
      entryId: 'base:class/wizard',
      classSummary: '法师',
      overrides: RuleOverrideIndex.fromEntries(
        page.contentEntries,
        page.packagePriorities,
      ),
      entryPriority:
          page.packagePriorities[RuleOverrideDeclaration.packageIdOf(
            'base:class/wizard',
          )] ??
          0,
    );
    expect(
      resolved.sourceOf('spellcasting.prepared')!.tier,
      kEntryTier + _errataPriority,
      reason: 'priority 40 的勘误必须是 tier 140',
    );
    // 来源 originId 是**规范 id**（剥掉战役视图的 `local:` / `campaign:<cid>:` 传输
    // 前缀）：否则同一个角色在本地 / 战役两个入口打开时，来源标签、覆盖匹配
    // （disabled / pinned）都会分裂成两套 id（S3 已知限制，已修）。
    expect(
      resolved.sourceOf('spellcasting.prepared')!.originId,
      'errata:class/wizard',
    );
  });

  test('包优先级表的键与重写后的条目 id 同源（前缀归一化只有一处）', () async {
    final repository = await _repositoryWithErrata();

    final entries = await repository.search(const ContentQuery());
    expect(
      entries.map((entry) => entry.id),
      contains('local:errata:class/wizard'),
      reason: '生产装配下条目 id 带 local: 前缀',
    );

    final priorities = await repository.packagePriorities();
    // 三种键并存：原始包 id（本地仓库与既有调用点的口径）、本地前缀、当前战役前缀。
    expect(priorities['errata'], _errataPriority);
    expect(
      priorities['local:errata'],
      _errataPriority,
      reason: '规则层用 packageIdOf(local:errata:class/wizard) 查表，键必须同源',
    );
    expect(priorities['campaign:c1:errata'], _errataPriority);
    // 不产生二次前缀这种无意义键。
    expect(priorities.containsKey('local:local:errata'), isFalse);
    expect(priorities.containsKey('campaign:c1:local:errata'), isFalse);
  });

  test('覆盖选择跨视图一致：本地写的 id 在战役视图同样生效，反之亦然', () async {
    // 战役视图：条目 id 带 `local:` 前缀。
    final campaignRepository = await _repositoryWithErrata();
    final campaignEntries = await campaignRepository.search(const ContentQuery());
    final priorities = await campaignRepository.packagePriorities();
    expect(
      campaignEntries.map((entry) => entry.id),
      contains('local:errata:class/wizard'),
      reason: '前置：战役装配下条目 id 确实带前缀',
    );
    const rebasedClassEntry = 'local:base:class/wizard';

    ResolvedClassRules resolveWith(Set<String> disabled) =>
        Dnd5eRules.resolveClassRules(
          entryId: rebasedClassEntry,
          classSummary: '法师',
          overrides: RuleOverrideIndex.fromEntries(campaignEntries, priorities),
          entryPriority: priorities['base'] ?? 0,
          disabledOriginIds: disabled,
        );

    // 1) 不关闭 → 勘误生效，来源是规范 id。
    final errataApplies = resolveWith(const <String>{});
    expect(errataApplies.sourceOf('spellcasting.prepared')!.originId, 'errata:class/wizard');
    expect(errataApplies.sourceOf('spellcasting.prepared')!.tier, kEntryTier + _errataPriority);

    // 2) **本地视图写下的规范 id** 在战役视图同样生效（这正是旧行为的缺口）。
    final canonicalDisabled = CharacterRuleOverrides.fromData(<String, Object?>{
      'disabledOriginIds': <String>['errata:class/wizard'],
    });
    expect(canonicalDisabled.disabledOriginIds, <String>{'errata:class/wizard'});
    expect(
      resolveWith(canonicalDisabled.disabledOriginIds)
          .sourceOf('spellcasting.prepared')!
          .tier,
      isNot(kEntryTier + _errataPriority),
      reason: '关掉勘误来源后不得再按 tier 140 生效',
    );

    // 3) 老数据里带前缀的写法经 `fromData` 归一化后**同一结果**（向后兼容）。
    final legacyDisabled = CharacterRuleOverrides.fromData(<String, Object?>{
      'disabledOriginIds': <String>['local:errata:class/wizard'],
    });
    expect(legacyDisabled.disabledOriginIds, <String>{'errata:class/wizard'});
    expect(
      resolveWith(legacyDisabled.disabledOriginIds)
          .sourceOf('spellcasting.prepared')!
          .originId,
      resolveWith(canonicalDisabled.disabledOriginIds)
          .sourceOf('spellcasting.prepared')!
          .originId,
    );

    // 4) 角色自身条目的 tie-break 也跨视图成立：前缀形态的 entryId 仍被认作"自己的条目"
    //    （自身条目的 tier = 100 + entryPriority，这里 50 压过勘误的 priority 40）。
    final ownEntryWins = Dnd5eRules.resolveClassRules(
      entryId: rebasedClassEntry,
      classSummary: '法师',
      structured: const <String, Object?>{
        'classRules': <String, Object?>{
          'hitDie': 10,
          'spellcasting': <String, Object?>{
            'mode': 'prepared',
            'ability': 'int',
            'prepared': <String, int>{'5': 2},
          },
        },
      },
      overrides: RuleOverrideIndex.fromEntries(campaignEntries, priorities),
      entryPriority: 50,
    );
    expect(
      ownEntryWins.sourceOf('spellcasting.prepared')!.originId,
      'base:class/wizard',
      reason: '自身条目 originId 也是规范 id；entryPriority 压过勘误的 priority 40',
    );
    expect(
      ownEntryWins.sourceOf('spellcasting.prepared')!.tier,
      kEntryTier + 50,
    );
  });

  test('本地装配下同一份优先级表给出同一个 tier（前缀不改变结论）', () async {
    final local = MemoryContentRepository();
    await local.upsertPackageEntry(
      manifest: const ContentPackageManifest(
        formatVersion: 3,
        id: 'errata',
        name: '勘误包',
        version: '1.0.0',
        locale: 'zh-CN',
        system: 'dnd5e-2024',
        entryCount: 1,
        priority: _errataPriority,
      ),
      entry: _classEntry('errata:class/wizard'),
    );
    final resolved = Dnd5eRules.resolveClassRules(
      entryId: 'base:class/wizard',
      classSummary: '法师',
      overrides: RuleOverrideIndex.fromEntries(
        await local.search(const ContentQuery()),
        await local.packagePriorities(),
      ),
      entryPriority: 0,
    );
    expect(resolved.sourceOf('spellcasting.prepared')!.tier, kEntryTier + _errataPriority);
    expect(
      resolved.sourceOf('spellcasting.prepared')!.originId,
      'errata:class/wizard',
    );
  });
}
