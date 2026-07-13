import 'package:dnd_table_client/src/features/content/domain/content.dart';
import 'package:dnd_table_client/src/features/content/presentation/widgets/content_class_feature_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('groups class features by level and opens a linked feature', (
    tester,
  ) async {
    ContentItem? opened;
    const actionSurge = ContentItem(
      id: 'feature-action-surge',
      packageId: 'campaign-package',
      type: 'feature',
      slug: 'action-surge',
      name: 'Action Surge',
      description: 'Push beyond your normal limits.',
      structured: null,
      tags: null,
      sourceLabel: 'Campaign rules',
      schemaVersion: 1,
      createdAt: '2026-07-13T00:00:00.000Z',
      updatedAt: '2026-07-13T00:00:00.000Z',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContentClassFeatureList(
            item: const ContentItem(
              id: 'class-fighter',
              packageId: 'campaign-package',
              type: 'class',
              slug: 'fighter',
              name: 'Fighter',
              description: '',
              structured: {
                'levelFeatures': [
                  {'level': 1, 'name': 'Fighting Style'},
                  {'level': 2, 'name': 'Action Surge'},
                ],
              },
              tags: null,
              sourceLabel: 'Campaign rules',
              schemaVersion: 1,
              createdAt: '2026-07-13T00:00:00.000Z',
              updatedAt: '2026-07-13T00:00:00.000Z',
            ),
            links: const [
              ContentItemLink(
                relation: 'class-feature',
                label: 'Action Surge',
                target: actionSurge,
              ),
            ],
            onLinkTap: (link) => opened = link.target,
          ),
        ),
      ),
    );

    expect(find.text('等级特性'), findsOneWidget);
    expect(find.text('等级 1'), findsOneWidget);
    expect(find.text('等级 2'), findsOneWidget);

    await tester.tap(find.text('等级 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Action Surge'));

    expect(opened, actionSurge);
  });
}
