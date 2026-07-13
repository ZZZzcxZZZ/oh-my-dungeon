import 'package:dnd_table_client/src/features/content/domain/content_block.dart';
import 'package:dnd_table_client/src/features/content/presentation/widgets/content_block_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders entry links as navigable material list tiles',
      (tester) async {
    String? opened;
    await tester.pumpWidget(MaterialApp(
      home: ContentBlockView(
        blocks: const [
          EntryLinkBlock(targetId: 'example:spell/fireball', text: '火球术'),
        ],
        onOpenEntry: (id) => opened = id,
      ),
    ));
    await tester.tap(find.text('火球术'));
    expect(opened, 'example:spell/fireball');
  });

  testWidgets(
      'renders heading, paragraph, list, table, quote, callout, image, statBlock, diceExpression',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SingleChildScrollView(
        child: ContentBlockView(
          blocks: [
            const HeadingBlock(level: 2, text: 'Heading'),
            const ParagraphBlock(text: 'Paragraph'),
            const ListBlock(items: ['a', 'b']),
            const TableBlock(headers: ['h'], rows: [
              ['c'],
            ]),
            const QuoteBlock(text: 'Quote'),
            const CalloutBlock(variant: 'info', text: 'Callout'),
            const ImageBlock(asset: 'assets/x.png', alt: 'alt'),
            const StatBlockBlock(fields: {'AC': '10'}),
            const DiceExpressionBlock(expression: '1d20', label: 'roll'),
          ],
        ),
      ),
    ));
    expect(find.text('Heading'), findsOneWidget);
    expect(find.text('Paragraph'), findsOneWidget);
    expect(find.text('a'), findsOneWidget);
    expect(find.text('c'), findsOneWidget);
    expect(find.text('Quote'), findsOneWidget);
    expect(find.text('Callout'), findsOneWidget);
    expect(find.text('alt'), findsOneWidget);
    expect(find.text('AC'), findsOneWidget);
    expect(find.text('1d20'), findsOneWidget);
  });
}
