import 'package:dnd_table_client/src/features/content/data/local/content_repository.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:dnd_table_client/src/features/content/presentation/content_detail_page.dart';
import 'package:dnd_table_client/src/features/content/presentation/content_library_controller.dart';
import 'package:dnd_table_client/src/features/content/presentation/content_library_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/content_test_support.dart';

ContentEntry _fighterClass() => ContentEntry.fromJson({
  'id': 'example:class/fighter',
  'type': 'class',
  'slug': 'fighter',
  'name': '战士',
  'body': <Map<String, Object?>>[],
  'revision': 1,
});

ContentEntry _championSubclass() => ContentEntry.fromJson({
  'id': 'example:subclass/champion',
  'type': 'subclass',
  'slug': 'champion',
  'name': '冠军',
  'body': <Map<String, Object?>>[],
  'revision': 1,
  'relations': [
    {'type': 'subclassOf', 'targetId': 'example:class/fighter'},
  ],
});

ContentEntry _secondWindFeature() => ContentEntry.fromJson({
  'id': 'example:classFeature/second-wind',
  'type': 'classFeature',
  'slug': 'second-wind',
  'name': '回气',
  'summary': '恢复生命值',
  'body': <Map<String, Object?>>[],
  'revision': 1,
  'structured': {'class': 'fighter', 'level': 1},
  'relations': [
    {'type': 'featureOf', 'targetId': 'example:class/fighter'},
  ],
});

ContentEntry _actionSurgeFeature() => ContentEntry.fromJson({
  'id': 'example:classFeature/action-surge',
  'type': 'classFeature',
  'slug': 'action-surge',
  'name': '动作如潮',
  'body': <Map<String, Object?>>[],
  'revision': 1,
  'structured': {'class': 'fighter', 'level': 2},
  'relations': [
    {'type': 'featureOf', 'targetId': 'example:class/fighter'},
  ],
});

/// 属于另一个职业的特性, 不应出现在战士详情里.
ContentEntry _arcaneRecoveryFeature() => ContentEntry.fromJson({
  'id': 'example:classFeature/arcane-recovery',
  'type': 'classFeature',
  'slug': 'arcane-recovery',
  'name': '奥术恢复',
  'body': <Map<String, Object?>>[],
  'revision': 1,
  'structured': {'class': 'wizard', 'level': 1},
  'relations': [
    {'type': 'featureOf', 'targetId': 'example:class/wizard'},
  ],
});

List<ContentEntry> _fighterPackage() => [
  _fighterClass(),
  _championSubclass(),
  _secondWindFeature(),
  _actionSurgeFeature(),
  _arcaneRecoveryFeature(),
];

void main() {
  group('class content navigation', () {
    testWidgets('subclass and classFeature are independently searchable by type',
        (tester) async {
      final repository = MemoryContentRepository(
        initialEntries: _fighterPackage(),
      );
      final controller = ContentLibraryController(repository: repository);

      final subclasses = await repository.search(
        const ContentQuery(type: 'subclass'),
      );
      expect(subclasses.map((e) => e.id), ['example:subclass/champion']);

      final features = await repository.search(
        const ContentQuery(type: 'classFeature'),
      );
      expect(
        features.map((e) => e.id),
        containsAll([
          'example:classFeature/second-wind',
          'example:classFeature/action-surge',
          'example:classFeature/arcane-recovery',
        ]),
      );

      // controller 也能按类型检索.
      await controller.search(type: 'subclass');
      expect(controller.results.map((e) => e.id), ['example:subclass/champion']);
    });

    testWidgets('class detail shows only this class features grouped by level',
        (tester) async {
      final repository = MemoryContentRepository(
        initialEntries: _fighterPackage(),
      );
      final controller = ContentLibraryController(repository: repository);

      await tester.pumpWidget(
        MaterialApp(
          home: ContentDetailPage(
            entryKey: 'example:class/fighter',
            controller: controller,
            onOpenEntry: (_) {},
            onImportRequested: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('等级特性'), findsOneWidget);
      expect(find.text('等级 1'), findsOneWidget);
      expect(find.text('等级 2'), findsOneWidget);
      expect(find.text('回气'), findsOneWidget);
      expect(find.text('动作如潮'), findsOneWidget);
      // 属于法师的特性不应出现.
      expect(find.text('奥术恢复'), findsNothing);
    });

    testWidgets('class detail lists related subclasses', (tester) async {
      final repository = MemoryContentRepository(
        initialEntries: _fighterPackage(),
      );
      final controller = ContentLibraryController(repository: repository);

      await tester.pumpWidget(
        MaterialApp(
          home: ContentDetailPage(
            entryKey: 'example:class/fighter',
            controller: controller,
            onOpenEntry: (_) {},
            onImportRequested: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('子职业'), findsOneWidget);
      expect(find.text('冠军'), findsOneWidget);
    });

    testWidgets(
      'tapping a subclass opens the same reader and back restores the class',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);

        final repository = MemoryContentRepository(
          initialEntries: _fighterPackage(),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: ContentLibraryPage(
              controller: ContentLibraryController(repository: repository),
              onImportRequested: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('战士'));
        await tester.pumpAndSettle();

        // 战士详情打开, 子职业冠军可见 (在 Dialog 内).
        final dialogFinder = find.byType(Dialog);
        expect(
          find.descendant(
            of: dialogFinder,
            matching: find.text('等级特性'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: dialogFinder, matching: find.text('冠军')),
          findsOneWidget,
        );

        // 点子职业打开同一个 reader 栈.
        await tester.tap(
          find.descendant(
            of: dialogFinder,
            matching: find.text('冠军'),
          ),
        );
        await tester.pumpAndSettle();
        // 子职业 reader 不再显示战士的等级特性区.
        expect(
          find.descendant(
            of: dialogFinder,
            matching: find.text('等级特性'),
          ),
          findsNothing,
        );

        // 返回后战士详情恢复.
        await tester.tap(find.byTooltip('返回'));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: dialogFinder,
            matching: find.text('等级特性'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: dialogFinder, matching: find.text('回气')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'back restores the previous class scroll position',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);

        // 给战士添加大量特性, 使详情可滚动.
        final extraFeatures = <ContentEntry>[];
        for (var i = 3; i <= 12; i++) {
          extraFeatures.add(
            ContentEntry.fromJson({
              'id': 'example:classFeature/filler-$i',
              'type': 'classFeature',
              'slug': 'filler-$i',
              'name': '填充特性 $i',
              'body': <Map<String, Object?>>[],
              'revision': 1,
              'structured': {'class': 'fighter', 'level': i},
              'relations': [
                {'type': 'featureOf', 'targetId': 'example:class/fighter'},
              ],
            }),
          );
        }
        final repository = MemoryContentRepository(
          initialEntries: [..._fighterPackage(), ...extraFeatures],
        );
        await tester.pumpWidget(
          MaterialApp(
            home: ContentLibraryPage(
              controller: ContentLibraryController(repository: repository),
              onImportRequested: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('战士'));
        await tester.pumpAndSettle();

        final dialogScrollable = find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(Scrollable),
        );

        // 顶部特性初始可见.
        expect(
          find.descendant(
            of: find.byType(Dialog),
            matching: find.text('回气'),
          ),
          findsOneWidget,
        );

        // 滚动到底部, 让底部特性进入视口、顶部特性离开视口.
        final state = tester.state<ScrollableState>(dialogScrollable.first);
        state.position.jumpTo(state.position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(Dialog),
            matching: find.text('填充特性 12'),
          ),
          findsOneWidget,
        );

        // 点底部特性打开 reader 栈.
        await tester.tap(find.text('填充特性 12'));
        await tester.pumpAndSettle();

        // 返回后战士详情恢复, 底部特性仍在视口 (滚动位置保留).
        await tester.tap(find.byTooltip('返回'));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(Dialog),
            matching: find.text('填充特性 12'),
          ),
          findsOneWidget,
        );
      },
    );
  });
}
