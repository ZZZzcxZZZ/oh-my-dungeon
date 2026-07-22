import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:dnd_table_client/src/features/content/presentation/widgets/content_class_feature_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('groups class features by level and fires tap callback',
      (tester) async {
    ContentEntry? opened;
    final fighter = ContentEntry.fromJson({
      'id': 'example:class/fighter',
      'type': 'class',
      'slug': 'fighter',
      'name': '战士',
      'body': <Map<String, Object?>>[],
      'revision': 1,
    });
    final fightingStyle = ContentEntry.fromJson({
      'id': 'example:classFeature/fighting-style',
      'type': 'classFeature',
      'slug': 'fighting-style',
      'name': '战斗风格',
      'body': <Map<String, Object?>>[],
      'revision': 1,
      'structured': {'class': 'fighter', 'level': 1},
    });
    final actionSurge = ContentEntry.fromJson({
      'id': 'example:classFeature/action-surge',
      'type': 'classFeature',
      'slug': 'action-surge',
      'name': '动作如潮',
      'body': <Map<String, Object?>>[],
      'revision': 1,
      'structured': {'class': 'fighter', 'level': 2},
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContentClassFeatureList(
            classEntry: fighter,
            featureEntries: [fightingStyle, actionSurge],
            onFeatureTap: (entry) => opened = entry,
          ),
        ),
      ),
    );

    expect(find.text('等级特性'), findsOneWidget);
    expect(find.text('等级 1'), findsOneWidget);
    expect(find.text('等级 2'), findsOneWidget);

    // 特性始终可见, 无需展开.
    await tester.tap(find.text('动作如潮'));

    expect(opened, actionSurge);
  });
}
