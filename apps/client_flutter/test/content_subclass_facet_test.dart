import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:dnd_table_client/src/features/content/presentation/content_library_controller.dart';
import 'package:dnd_table_client/src/features/content/presentation/content_library_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/content_test_support.dart';

ContentEntry _class(String id, String name) => ContentEntry.fromJson({
  'id': id,
  'type': 'class',
  'slug': id.split('/').last,
  'name': name,
  'body': <Map<String, Object?>>[],
  'revision': 1,
});

ContentEntry _subclass(String id, String name, String parentClassId) =>
    ContentEntry.fromJson({
      'id': id,
      'type': 'subclass',
      'slug': id.split('/').last,
      'name': name,
      'body': <Map<String, Object?>>[],
      'revision': 1,
      // Spec §Wave 2 Task 2.1: 子职业仅通过 subclassOf 关系链接父职业,
      // structured.parentClass 不再被依赖 (资料包导入器从不写入该字段).
      'relations': [
        {'type': 'subclassOf', 'targetId': parentClassId},
      ],
    });

void main() {
  group('subclass parentClass facet (Task 2.1)', () {
    late ContentLibraryController controller;

    setUp(() {
      final repository = MemoryContentRepository(initialEntries: [
        _class('example:class/fighter', '战士'),
        _class('example:class/wizard', '法师'),
        _subclass('example:subclass/champion', '冠军', 'example:class/fighter'),
        _subclass('example:subclass/battle-master', '战斗大师', 'example:class/fighter'),
        _subclass('example:subclass/evoker', '塑能师', 'example:class/wizard'),
      ]);
      controller = ContentLibraryController(repository: repository);
    });

    tearDown(() => controller.dispose());

    test('facetOptions resolves parentClass names from subclassOf relations', () async {
      final options = await controller.facetOptions(
        type: 'subclass',
        fields: const ['parentClass'],
      );
      // 父职业名按 Unicode 序排列: 战 (U+6218) < 法 (U+6CD5) -> 战士, 法师.
      expect(options['parentClass'], ['战士', '法师']);
    });

    test('search filters subclasses by parentClass name', () async {
      await controller.search(
        type: 'subclass',
        facets: const {'parentClass': {'战士'}},
      );
      final names = controller.results.map((e) => e.name).toList()..sort();
      // 冠 (U+51A0) < 战 (U+6218) -> 冠军, 战斗大师.
      expect(names, ['冠军', '战斗大师']);
    });

    test('selecting wizard returns only wizard subclasses', () async {
      await controller.search(
        type: 'subclass',
        facets: const {'parentClass': {'法师'}},
      );
      expect(controller.results.map((e) => e.name), ['塑能师']);
    });

    test('subclass without subclassOf relation is excluded from parentClass facet',
        () async {
      final repository = MemoryContentRepository(initialEntries: [
        _class('example:class/fighter', '战士'),
        _subclass('example:subclass/champion', '冠军', 'example:class/fighter'),
        // 孤儿子职业, 无任何关系.
        ContentEntry.fromJson({
          'id': 'example:subclass/orphan',
          'type': 'subclass',
          'slug': 'orphan',
          'name': '孤儿',
          'body': <Map<String, Object?>>[],
          'revision': 1,
        }),
      ]);
      final localController = ContentLibraryController(repository: repository);
      addTearDown(localController.dispose);

      final options = await localController.facetOptions(
        type: 'subclass',
        fields: const ['parentClass'],
      );
      expect(options['parentClass'], ['战士']);
    });

    test('facetOptions ignores any stale structured.parentClass value', () async {
      // 即使旧数据残留 structured.parentClass, 也应只读 subclassOf 关系.
      final repository = MemoryContentRepository(initialEntries: [
        _class('example:class/fighter', '战士'),
        ContentEntry.fromJson({
          'id': 'example:subclass/champion',
          'type': 'subclass',
          'slug': 'champion',
          'name': '冠军',
          'body': <Map<String, Object?>>[],
          'revision': 1,
          'structured': {'parentClass': 'WRONG_STALE_VALUE'},
          'relations': [
            {'type': 'subclassOf', 'targetId': 'example:class/fighter'},
          ],
        }),
      ]);
      final localController = ContentLibraryController(repository: repository);
      addTearDown(localController.dispose);

      final options = await localController.facetOptions(
        type: 'subclass',
        fields: const ['parentClass'],
      );
      expect(options['parentClass'], ['战士']);
    });
  });

  group('subclass parentClass facet UI (Task 2.1)', () {
    testWidgets('filter sheet exposes parentClass facet options for subclass type',
        (tester) async {
      final repository = MemoryContentRepository(initialEntries: [
        _class('example:class/fighter', '战士'),
        _class('example:class/wizard', '法师'),
        _subclass('example:subclass/champion', '冠军', 'example:class/fighter'),
        _subclass('example:subclass/evoker', '塑能师', 'example:class/wizard'),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: ContentLibraryPage(
            controller: ContentLibraryController(repository: repository),
            onImportRequested: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('content-filter-button')));
      await tester.pumpAndSettle();

      // 选择子职业类型.
      await tester.tap(find.text('子职').last);
      await tester.pumpAndSettle();

      // 所属职业 facet 区块可见, 且列出父职业名 (而非裸 entryKey).
      // 注意: 主页背景 ListView 也展示了 "战士"/"法师" 职业条目,
      // 所以断言要限定在 BottomSheet 后代内.
      // Task 2.2: facet chip 标签带计数后缀 (如 "战士 (1)"), 改用 textContaining.
      final sheet = find.byType(BottomSheet);
      expect(find.descendant(of: sheet, matching: find.text('所属职业')),
          findsOneWidget);
      expect(find.descendant(of: sheet, matching: find.textContaining('战士')),
          findsOneWidget);
      expect(find.descendant(of: sheet, matching: find.textContaining('法师')),
          findsOneWidget);
    });

    testWidgets('selecting parentClass facet filters subclasses', (tester) async {
      final repository = MemoryContentRepository(initialEntries: [
        _class('example:class/fighter', '战士'),
        _class('example:class/wizard', '法师'),
        _subclass('example:subclass/champion', '冠军', 'example:class/fighter'),
        _subclass('example:subclass/evoker', '塑能师', 'example:class/wizard'),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: ContentLibraryPage(
            controller: ContentLibraryController(repository: repository),
            onImportRequested: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('content-filter-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('子职').last);
      await tester.pumpAndSettle();
      // 选择战士作为所属职业 (限定在 BottomSheet 后代内, 避免命中背景 ListView).
      // Task 2.2: facet chip 标签带计数后缀 (如 "战士 (1)"), 改用 textContaining;
      // DraggableScrollableSheet 内容可能超出可视区, 先 ensureVisible 再 tap.
      final sheet = find.byType(BottomSheet);
      final fighterText = find.descendant(
        of: sheet,
        matching: find.textContaining('战士'),
      );
      await tester.ensureVisible(fighterText);
      await tester.pumpAndSettle();
      await tester.tap(fighterText);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('content-filter-apply')));
      await tester.pumpAndSettle();

      // 只剩战士的子职业.
      expect(find.text('冠军'), findsOneWidget);
      expect(find.text('塑能师'), findsNothing);
    });
  });
}
