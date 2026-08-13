import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:dnd_table_client/src/features/content/presentation/content_library_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/content_test_support.dart';

ContentEntry _monster(String slug, String type) => ContentEntry.fromJson({
  'id': 'legacy:monster/$slug',
  'type': 'monster',
  'slug': slug,
  'name': slug,
  'body': <Object?>[],
  'revision': 1,
  'structured': {'type': type},
});

void main() {
  test(
    'monster type facets expose only official broad creature types',
    () async {
      final controller = ContentLibraryController(
        repository: MemoryContentRepository(
          initialEntries: [
            _monster('undead-mage', '亡灵（法师）'),
            _monster('undead-swarm', '或小型亡灵'),
            _monster('chaotic-elemental', '元素,混乱中立'),
            _monster('titan', '天族或邪魔（泰坦）'),
          ],
        ),
      );

      final options = await controller.facetOptionsWithCounts(
        type: 'monster',
        fields: const ['type'],
      );

      expect(options['type']!.map((option) => option.value).toSet(), {
        'undead',
        'elemental',
        'celestial',
        'fiend',
      });
      expect(
        options['type']!.firstWhere((option) => option.value == 'undead').count,
        2,
      );
    },
  );

  test('broad monster type selection matches legacy subtype values', () async {
    final controller = ContentLibraryController(
      repository: MemoryContentRepository(
        initialEntries: [_monster('undead-mage', '亡灵（法师）')],
      ),
    );

    await controller.search(
      type: 'monster',
      facets: const {
        'type': {'undead'},
      },
    );

    expect(controller.results.map((entry) => entry.slug), ['undead-mage']);
  });
}
