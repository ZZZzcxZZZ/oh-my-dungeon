import 'package:dnd_table_client/src/core/widgets/app_search_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('submits search text and invokes the filter action', (
    tester,
  ) async {
    final controller = TextEditingController(text: '火球术');
    addTearDown(controller.dispose);
    String? submitted;
    var filterPressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppSearchBar(
            controller: controller,
            hintText: '搜索名称、关键字…',
            onSubmitted: (value) => submitted = value,
            onFilterPressed: () => filterPressed = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(SearchBar));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.tap(find.byKey(const Key('content-filter-button')));

    expect(submitted, '火球术');
    expect(filterPressed, isTrue);
    expect(find.byType(Badge), findsNothing);
  });

  testWidgets('shows the active filter count inside the filter button', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppSearchBar(
            controller: controller,
            hintText: '搜索',
            activeFilterCount: 3,
            onSubmitted: (_) {},
            onFilterPressed: () {},
          ),
        ),
      ),
    );

    expect(find.text('3'), findsOneWidget);
    expect(find.byType(Badge), findsOneWidget);
    expect(find.byTooltip('筛选，已启用 3 项'), findsOneWidget);
  });
}
