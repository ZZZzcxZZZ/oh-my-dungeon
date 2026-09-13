// P0-2.6：campaign 角色卡的规则解析必须拿到与本地建档**同一份**包 priority。
//
// 缺陷：`openCampaignCharacterSheet` 只加载了 `contentEntries`，不传
// `packagePriorities` → `CharacterDetailPage.packagePriorities` 落到默认 `const {}`
// → campaign 内的 `RuleOverrideIndex` 让所有声明的 tier 都落回 100，priority 40 的
// 勘误压不过自身条目（短休 `archetype: pact` 判定也随之与本地不一致）。
import 'package:dnd_table_client/src/features/campaigns/presentation/characters/campaign_character_controller.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/characters/campaign_character_sheet_launcher.dart';
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

void main() {
  testWidgets('campaign 角色卡拿到包 priority，tier 与本地一致（P0-2.6）', (tester) async {
    // 生产装配：UI 拿到的是 CampaignAwareContentRepository（条目 id 会被重写成
    // `local:<id>` / `campaign:<cid>:<id>`）。用裸 MemoryContentRepository 会让
    // `packageIdOf(entryId)` 恰好等于原始包 id，从而**绕过**真实的前缀问题
    // （C3 的旧版用例就是这么假绿的）。
    final repository = CampaignAwareContentRepository(
      local: MemoryContentRepository(),
      campaign: MemoryCampaignCacheRepository(),
      activeCampaignId: () => 'c1',
    );
    final local = repository.local as MemoryContentRepository;
    // 装一个 priority = 40 的勘误包（与本地 `packagePriorities()` 同源投影）。
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

    // 前置断言：仓库确实重写了 id，且优先级表覆盖重写后的键（否则下面的 tier 检查
    // 会因为"恰好没前缀"而失去意义）。
    final entries = await repository.search(const ContentQuery());
    expect(
      entries.map((entry) => entry.id),
      contains('local:errata:class/wizard'),
      reason: '生产装配下条目 id 带 local: 前缀',
    );
    final priorities = await repository.packagePriorities();
    expect(priorities['errata'], _errataPriority);
    expect(priorities['local:errata'], _errataPriority,
        reason: '包优先级表的键必须与重写后的条目 id 同源');
    expect(priorities['campaign:c1:errata'], _errataPriority);

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
    // 来源 originId 用的是**这份输入里的条目 id**：campaign 装配下带 `local:` 前缀
    // （与页面显示、`data.ruleOverrides` 的写入口径自洽）。不带前缀的等价性由下一个
    // 用例在本地装配下断言。
    expect(
      resolved.sourceOf('spellcasting.prepared')!.originId,
      'local:errata:class/wizard',
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
