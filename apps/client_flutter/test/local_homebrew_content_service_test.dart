import 'package:dnd_table_client/src/features/content/data/local/local_homebrew_content_service.dart';
import 'package:dnd_table_client/src/features/content/data/local/content_repository.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
