import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:dnd_table_client/src/features/content/presentation/content_detail_page.dart';
import 'package:dnd_table_client/src/features/content/presentation/content_library_controller.dart';
import 'package:dnd_table_client/src/features/content/presentation/content_library_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/content_test_support.dart';

Widget buildContentTestApp({required List<ContentEntry> entries}) {
  final repository = MemoryContentRepository(initialEntries: entries);
  return MaterialApp(
    home: ContentLibraryPage(
      controller: ContentLibraryController(repository: repository),
      onImportRequested: () {},
    ),
  );
}

void main() {
  testWidgets('shows an import action when the local library is empty', (tester) async {
    await tester.pumpWidget(buildContentTestApp(entries: const []));
    await tester.pumpAndSettle();
    expect(find.text('资料库还是空的'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '导入资料包'), findsOneWidget);
  });

  testWidgets('opens a narrow-screen entry on a full page', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(buildContentTestApp(entries: [testFighterEntry()]));
    await tester.pumpAndSettle();
    await tester.tap(find.text('战士'));
    await tester.pumpAndSettle();
    expect(find.byType(ContentDetailPage), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('shows wide-screen two-pane layout', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(buildContentTestApp(entries: [testFighterEntry()]));
    await tester.pumpAndSettle();
    expect(find.byType(ContentDetailPage), findsOneWidget);
  });

  testWidgets('filters favorites only when toggled', (tester) async {
    await tester.pumpWidget(buildContentTestApp(entries: [testFighterEntry()]));
    await tester.pumpAndSettle();
    expect(find.text('战士'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, '收藏'));
    await tester.pumpAndSettle();
    expect(find.text('战士'), findsNothing);
  });
}
