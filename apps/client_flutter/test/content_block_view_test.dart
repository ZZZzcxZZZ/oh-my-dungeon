import 'package:dnd_table_client/src/features/content/domain/content_block.dart';
import 'package:dnd_table_client/src/features/content/presentation/widgets/content_block_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('stat block wraps a long value at 320px without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ContentBlockView(
              blocks: [
                StatBlockBlock(
                  fields: {'速度': '步行 30 尺，飞行 120 尺（悬浮），游泳 60 尺，并且可以穿过狭窄空间'},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('dice expression wraps a long label at 320px without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ContentBlockView(
              blocks: [
                DiceExpressionBlock(
                  expression: '12d20+123',
                  label: '进行一次带有优势与额外加值的超长感知检定说明',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('renders entry links as navigable material list tiles', (
    tester,
  ) async {
    String? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: ContentBlockView(
          blocks: const [
            EntryLinkBlock(targetId: 'example:spell/fireball', text: '火球术'),
          ],
          onOpenEntry: (id) => opened = id,
        ),
      ),
    );
    await tester.tap(find.text('火球术'));
    expect(opened, 'example:spell/fireball');
  });

  testWidgets(
    'renders heading, paragraph, list, table, quote, callout, image, statBlock, diceExpression',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SingleChildScrollView(
            child: ContentBlockView(
              blocks: [
                const HeadingBlock(level: 2, text: 'Heading'),
                const ParagraphBlock(text: 'Paragraph'),
                const ListBlock(items: ['a', 'b']),
                const TableBlock(
                  headers: ['h'],
                  rows: [
                    ['c'],
                  ],
                ),
                const QuoteBlock(text: 'Quote'),
                const CalloutBlock(variant: 'info', text: 'Callout'),
                const ImageBlock(asset: 'assets/x.png', alt: 'alt'),
                const StatBlockBlock(fields: {'AC': '10'}),
                const DiceExpressionBlock(expression: '1d20', label: 'roll'),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Heading'), findsOneWidget);
      expect(find.text('Paragraph'), findsOneWidget);
      expect(find.text('a'), findsOneWidget);
      expect(find.text('c'), findsOneWidget);
      expect(find.text('Quote'), findsOneWidget);
      expect(find.text('Callout'), findsOneWidget);
      expect(find.text('alt'), findsOneWidget);
      expect(find.text('AC'), findsOneWidget);
      expect(find.text('1d20'), findsOneWidget);
    },
  );
}
