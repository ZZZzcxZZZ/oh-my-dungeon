import 'package:dnd_table_client/src/features/content/domain/content_block.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:dnd_table_client/src/features/content/presentation/widgets/content_entry_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldShowMetadataView', () {
    test('false when body already has a statBlock (avoids duplicate metadata)', () {
      final entry = ContentEntry(
        id: 'pkg:spell:fire-bolt',
        type: 'spell',
        slug: 'fire-bolt',
        name: '火焰箭',
        structured: const {'level': 0, 'school': '塑能'},
        body: const [
          StatBlockBlock(fields: {'环阶': '戏法', '学派': '塑能'}),
          ParagraphBlock(text: '描述正文。'),
        ],
        revision: 1,
      );

      expect(shouldShowMetadataView(entry), isFalse);
    });

    test('true when structured present but body has no statBlock', () {
      final entry = ContentEntry(
        id: 'pkg:rule:custom',
        type: 'rule',
        slug: 'custom',
        name: '自定义规则',
        structured: const {'source': 'DM'},
        body: const [ParagraphBlock(text: '正文。')],
        revision: 1,
      );

      expect(shouldShowMetadataView(entry), isTrue);
    });

    test('false when structured is empty', () {
      final entry = ContentEntry(
        id: 'pkg:note:blank',
        type: 'custom',
        slug: 'blank',
        name: '空白',
        body: const [ParagraphBlock(text: '正文。')],
        revision: 1,
      );

      expect(shouldShowMetadataView(entry), isFalse);
    });
  });
}
