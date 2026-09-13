import 'package:dnd_table_client/src/features/content/data/campaign_aware_content_repository.dart';
import 'package:dnd_table_client/src/features/content/data/local/local_homebrew_content_service.dart';
import 'package:dnd_table_client/src/features/content/data/local/content_repository.dart';
import 'package:dnd_table_client/src/features/content/domain/content_block.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry_id.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/campaign_test_support.dart';
import 'support/content_test_support.dart';

void main() {
  test(
    'creates a searchable structured spell in the local homebrew package',
    () async {
      final repository = MemoryContentRepository();
      final service = LocalHomebrewContentService(repository: repository);

      final entry = await service.create(
        type: 'spell',
        name: '星火箭',
        summary: '一枚自制的奥术弹体。',
        description: '命中后造成力场伤害。',
        structured: const {'level': '1', 'school': '塑能', 'classes': '法师，术士'},
      );

      expect(entry.id, 'local-homebrew:spell/星火箭');
      expect(entry.structured['level'], 1);
      expect(entry.structured['classes'], ['法师', '术士']);
      final results = await repository.search(
        const ContentQuery(
          type: 'spell',
          facets: {
            'level': {'1'},
            'classes': {'法师'},
          },
        ),
      );
      expect(results.single.id, entry.id);
    },
  );

  test('uses a readable suffix when a generated id already exists', () async {
    final repository = MemoryContentRepository();
    final service = LocalHomebrewContentService(repository: repository);

    await service.create(type: 'custom', name: '秘密条目');
    final second = await service.create(type: 'custom', name: '秘密条目');

    expect(second.id, 'local-homebrew:custom/秘密条目-2');
  });

  test('updates in place and increments revision', () async {
    final repository = MemoryContentRepository();
    final service = LocalHomebrewContentService(repository: repository);
    final created = await service.create(
      type: 'item',
      name: '银钥匙',
      structured: const {'homebrewEffect': '微光'},
    );

    final updated = await service.update(
      existing: created,
      name: '银钥匙',
      summary: '现在会发光。',
      structured: const {'category': '奇物'},
    );

    expect(updated.id, created.id);
    expect(updated.revision, 2);
    expect(updated.structured['homebrewEffect'], '微光');
    expect((await repository.getByKey(created.id))?.summary, '现在会发光。');
  });

  test('rejects invalid structured data and deletes only the target', () async {
    final repository = MemoryContentRepository();
    final service = LocalHomebrewContentService(repository: repository);
    final kept = await service.create(type: 'item', name: '保留');
    final deleted = await service.create(type: 'item', name: '删除');

    expect(
      () => service.create(type: 'spell', name: '缺少环位'),
      throwsA(isA<LocalHomebrewValidationException>()),
    );
    await service.delete(deleted);

    expect(await repository.getByKey(deleted.id), isNull);
    expect(await repository.getByKey(kept.id), isNotNull);
  });
  test('包清单行必须是 formatVersion 3（导出/导入共用同一契约）', () {
    expect(LocalHomebrewContentService.packageManifest.formatVersion, 3);
  });

  test('rules 可写可清：create 落库、update 传 {} 清空、形状非法即报错', () async {
    final repository = MemoryContentRepository();
    final service = LocalHomebrewContentService(repository: repository);

    final entry = await service.create(
      type: 'class',
      name: '自制职业',
      structured: const {
        'classRules': {'hitDie': 10},
      },
      rules: const {
        'progression': [
          {
            'levels': [1],
            'grants': [
              {'id': 'g1', 'kind': 'proficiency', 'target': 'skill:运动'},
            ],
          },
        ],
      },
    );
    expect(entry.rules, isNotNull);
    expect(entry.rules!.progression.single.levels, [1]);
    expect(entry.rules!.progression.single.grants.single.target, 'skill:运动');

    // update 传 rules: {} = 清空（而不是"保留旧值"——作者要能删掉规则）。
    final cleared = await service.update(
      existing: entry,
      name: entry.name,
      structured: entry.structured,
      rules: const <String, Object?>{},
    );
    expect(cleared.rules!.progression, isEmpty);
    expect(cleared.rules!.choices, isEmpty);

    // 形状非法 → 明确报错，绝不静默丢弃 rules。
    await expectLater(
      service.create(
        type: 'class',
        name: '坏规则职业',
        rules: const {
          'progression': [
            {'levels': ['一'], 'grants': []},
          ],
        },
      ),
      throwsA(isA<LocalHomebrewValidationException>()),
    );
  });

  test('update 不会删掉描述框承载不了的块（标题 / 列表）', () async {
    final repository = MemoryContentRepository();
    final service = LocalHomebrewContentService(repository: repository);
    final created = await service.create(
      type: 'item',
      name: '银钥匙',
      description: '旧描述。',
      structured: const {'homebrewEffect': '微光'},
    );

    // 历史数据 / 导入器留下的富文本块：服务是唯一写入边界，但既有条目可能带
    // 标题、列表等描述框装不下的块，直接落库模拟这种输入。
    await repository.upsertPackageEntry(
      manifest: LocalHomebrewContentService.packageManifest,
      entry: ContentEntry(
        id: created.id,
        type: created.type,
        slug: created.slug,
        name: created.name,
        revision: created.revision,
        structured: created.structured,
        body: const [
          HeadingBlock(text: '银钥匙'),
          ParagraphBlock(text: '旧描述。'),
          ListBlock(items: ['微光', '轻便']),
        ],
      ),
    );
    final seeded = (await repository.getByKey(created.id))!;
    expect(seeded.body, hasLength(3));

    final updated = await service.update(
      existing: seeded,
      name: '银钥匙',
      description: '新描述。',
      structured: seeded.structured,
    );

    // 段落被这一个描述框替换（只剩一段），标题与列表原样保留且顺序不变。
    expect(updated.body, hasLength(3));
    expect(updated.body[0], isA<HeadingBlock>());
    expect(updated.body[1], isA<ParagraphBlock>());
    expect((updated.body[1] as ParagraphBlock).text, '新描述。');
    expect(updated.body[2], isA<ListBlock>());
    expect((updated.body[2] as ListBlock).items, ['微光', '轻便']);

    // 描述清空 = 删掉全部段落，非段落块仍然保留。
    final cleared = await service.update(
      existing: updated,
      name: updated.name,
      description: '   ',
      structured: updated.structured,
    );
    expect(cleared.body, hasLength(2));
    expect(cleared.body[0], isA<HeadingBlock>());
    expect(cleared.body[1], isA<ListBlock>());
  });

  test('create(overrideOf:) 把对齐键钉在来源条目上，不按名字生成 slug', () async {
    final repository = MemoryContentRepository();
    final service = LocalHomebrewContentService(repository: repository);
    const source = ContentEntry(
      id: 'builtin:class/fighter',
      type: 'class',
      slug: 'fighter',
      name: '战士',
      body: <ContentBlock>[],
      revision: 1,
      structured: <String, Object?>{
        'classRules': <String, Object?>{'hitDie': 10},
      },
    );

    final override = await service.create(
      type: 'class',
      name: '战士（自制）',
      structured: const {
        'classRules': {'hitDie': 12},
      },
      overrideOf: source,
    );

    // 名字是中文，若按 `_slugify(name)` 生成 slug 就永远对不上来源。
    expect(override.slug, 'fighter');
    expect(override.id, 'local-homebrew:class/fighter');
    expect(
      contentEntryAlignmentKey(override.id),
      contentEntryAlignmentKey(source.id),
    );
    expect(override.type, 'class', reason: '类型随来源，保证同一条合并链');

    // 同键再建一条 = 拒绝：两条自制覆盖抢同一列只能靠 originId 排序，作者无法预期。
    await expectLater(
      service.create(
        type: 'class',
        name: '又一条',
        structured: const {
          'classRules': {'hitDie': 8},
        },
        overrideOf: source,
      ),
      throwsA(isA<LocalHomebrewValidationException>()),
    );

    // 清空 classRules 的"覆盖"不参与合并链（RuleOverrideIndex 只收有 classRules 的
    // class 条目）：占了对齐键却什么都不覆盖比报错更糟，必须拦下。
    const wizard = ContentEntry(
      id: 'builtin:class/wizard',
      type: 'class',
      slug: 'wizard',
      name: '法师',
      body: <ContentBlock>[],
      revision: 1,
    );
    await expectLater(
      service.create(
        type: 'class',
        name: '空覆盖',
        structured: const {
          'classRules': <String, Object?>{},
        },
        overrideOf: wizard,
      ),
      throwsA(
        isA<LocalHomebrewValidationException>().having(
          (error) => error.errors.join('\n'),
          'errors',
          contains('classRules'),
        ),
      ),
    );

    // 来源 id 没有对齐键（空末段）→ 明确报错，而不是生成 `local-homebrew:class/`。
    await expectLater(
      service.create(
        type: 'class',
        name: '无键',
        overrideOf: const ContentEntry(
          id: '',
          type: 'class',
          slug: '',
          name: '',
          body: <ContentBlock>[],
          revision: 1,
        ),
      ),
      throwsA(isA<LocalHomebrewValidationException>()),
    );

    // 类型必须与来源一致：静默忽略调用方传的 type 会让"覆盖"落到另一条对齐键上。
    await expectLater(
      service.create(
        type: 'spell',
        name: '类型不符',
        structured: const {
          'classRules': {'hitDie': 8},
        },
        overrideOf: source,
      ),
      throwsA(isA<LocalHomebrewValidationException>()),
    );
  });

  test('组合仓库（生产装配）下重名加后缀、同键覆盖被拒，不静默覆盖', () async {
    final local = MemoryContentRepository();
    final aware = CampaignAwareContentRepository(
      local: local,
      campaign: MemoryCampaignCacheRepository(),
      activeCampaignId: () => null,
    );
    final service = LocalHomebrewContentService(repository: aware);

    // 重名：组合仓库的 `getByKey('local-homebrew:…')` 恒为 null（它只认带前缀的键），
    // 若还用 getByKey 判断占用，第二条会拿到同一个 id 直接覆盖第一条。
    final first = await service.create(type: 'custom', name: '同名');
    final second = await service.create(type: 'custom', name: '同名');
    expect(first.id, 'local-homebrew:custom/同名');
    expect(second.id, 'local-homebrew:custom/同名-2');
    expect(await aware.search(const ContentQuery()), hasLength(2));

    final classEntry = await service.create(
      type: 'class',
      name: '星骑士',
      structured: const {
        'classRules': {'hitDie': 12},
      },
    );
    expect(classEntry.id, 'local-homebrew:class/星骑士');

    // 覆盖：来源是从组合仓库读到的条目（id 带 `local:` 前缀），它的对齐键已被本包
    // 占着。旧实现用 `getByKey` 判重（组合仓库对无前缀键恒返回 null）会把这唯一一条
    // 静默覆盖；现在必须报错，而且原条目一个字段都不能变。
    final source = (await aware.search(
      const ContentQuery(type: 'class'),
    )).single;
    await expectLater(
      service.create(
        type: 'class',
        name: '星骑士覆盖',
        structured: const {
          'classRules': {'hitDie': 8},
        },
        overrideOf: source,
      ),
      throwsA(isA<LocalHomebrewValidationException>()),
    );
    final kept = (await aware.search(const ContentQuery(type: 'class'))).single;
    expect(
      (kept.structured['classRules']! as Map)['hitDie'],
      12,
      reason: '被拒的覆盖没有改掉已有条目',
    );

    // 停用"我的自制内容"包后占用检测仍然有效：`search` 会按 `packages.enabled`
    // 过滤（这时它什么都查不到），用它做判重就会退回"重名静默覆盖"。
    await local.setPackageEnabled(LocalHomebrewContentService.packageId, false);
    expect(await aware.search(const ContentQuery()), isEmpty);
    final third = await service.create(type: 'custom', name: '同名');
    expect(third.id, 'local-homebrew:custom/同名-3');
    for (final id in <String>[
      'local-homebrew:custom/同名',
      'local-homebrew:custom/同名-2',
      'local-homebrew:custom/同名-3',
    ]) {
      expect(await local.getByKey(id), isNotNull, reason: '$id 都应还在');
    }
  });
}
