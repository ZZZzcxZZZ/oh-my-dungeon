import 'package:dnd_table_client/src/features/content/domain/content_block.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:dnd_table_client/src/features/content/domain/content_package_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ContentBlock', () {
    test('parses a heading block', () {
      final block = ContentBlock.fromJson({
        'type': 'heading',
        'level': 2,
        'text': '职业特性',
      });
      expect(block, isA<HeadingBlock>());
      expect((block as HeadingBlock).level, 2);
      expect(block.text, '职业特性');
    });

    test('parses an entry link block', () {
      final block = ContentBlock.fromJson({
        'type': 'entryLink',
        'targetId': 'example:feature/action-surge',
        'text': '动作如潮',
      });
      expect(block, isA<EntryLinkBlock>());
      expect(
        (block as EntryLinkBlock).targetId,
        'example:feature/action-surge',
      );
      expect(block.text, '动作如潮');
    });

    test('parses a paragraph block', () {
      final block = ContentBlock.fromJson({
        'type': 'paragraph',
        'text': '战士是武器大师。',
      });
      expect(block, isA<ParagraphBlock>());
      expect((block as ParagraphBlock).text, '战士是武器大师。');
    });

    test('parses a list block', () {
      final block = ContentBlock.fromJson({
        'type': 'list',
        'ordered': true,
        'items': ['第一项', '第二项'],
      });
      expect(block, isA<ListBlock>());
      expect((block as ListBlock).ordered, isTrue);
      expect(block.items, ['第一项', '第二项']);
    });

    test('parses a table block', () {
      final block = ContentBlock.fromJson({
        'type': 'table',
        'headers': ['等级', '熟练加值'],
        'rows': [
          ['1', '+2'],
          ['5', '+3'],
        ],
      });
      expect(block, isA<TableBlock>());
      expect((block as TableBlock).headers, ['等级', '熟练加值']);
      expect(block.rows, hasLength(2));
    });

    test('parses a quote block', () {
      final block = ContentBlock.fromJson({'type': 'quote', 'text': '关键规则'});
      expect(block, isA<QuoteBlock>());
    });

    test('parses a callout block', () {
      final block = ContentBlock.fromJson({
        'type': 'callout',
        'variant': 'info',
        'text': '提示信息',
      });
      expect(block, isA<CalloutBlock>());
      expect((block as CalloutBlock).variant, 'info');
    });

    test('parses an image block', () {
      final block = ContentBlock.fromJson({
        'type': 'image',
        'asset': 'assets/fighter.png',
        'alt': '战士插画',
      });
      expect(block, isA<ImageBlock>());
      expect((block as ImageBlock).asset, 'assets/fighter.png');
    });

    test('parses a stat block', () {
      final block = ContentBlock.fromJson({
        'type': 'statBlock',
        'fields': {'AC': '18', 'HP': '143 (15d10 + 60)'},
      });
      expect(block, isA<StatBlockBlock>());
      expect((block as StatBlockBlock).fields['AC'], '18');
    });

    test('parses a dice expression block', () {
      final block = ContentBlock.fromJson({
        'type': 'diceExpression',
        'expression': '1d20+5',
        'label': '攻击',
      });
      expect(block, isA<DiceExpressionBlock>());
      expect((block as DiceExpressionBlock).expression, '1d20+5');
    });

    test('rejects html blocks', () {
      expect(
        () => ContentBlock.fromJson({
          'type': 'html',
          'html': '<script>x</script>',
        }),
        throwsFormatException,
      );
    });

    test('rejects unknown block types', () {
      expect(
        () => ContentBlock.fromJson({'type': 'unknown', 'text': 'x'}),
        throwsFormatException,
      );
    });
  });

  group('ContentEntry', () {
    test('parses a linked class feature without accepting html blocks', () {
      final entry = ContentEntry.fromJson({
        'id': 'example:class/fighter',
        'type': 'class',
        'slug': 'fighter',
        'name': '战士',
        'aliases': ['Fighter'],
        'summary': '武器大师',
        'body': [
          {'type': 'heading', 'level': 2, 'text': '职业特性'},
          {
            'type': 'entryLink',
            'targetId': 'example:feature/action-surge',
            'text': '动作如潮',
          },
        ],
        // 任务 10：职业规则只在 `classRules`，不再有顶层 `hitDie` 字符串副本；
        // 这里仍断言 `structured` 原样保留（换成新契约载荷）。
        'structured': {
          'classRules': {
            'hitDie': 10,
            'savingThrowAbilities': ['str', 'con'],
          },
        },
        'tags': ['class'],
        'source': {'label': '本地资料'},
        'revision': 1,
      });

      expect(entry.id, 'example:class/fighter');
      expect(entry.type, 'class');
      expect(entry.slug, 'fighter');
      expect(entry.name, '战士');
      expect(entry.aliases, ['Fighter']);
      expect(entry.summary, '武器大师');
      expect(entry.body, hasLength(2));
      expect(entry.body.last, isA<EntryLinkBlock>());
      expect(entry.structured['classRules'], {
        'hitDie': 10,
        'savingThrowAbilities': ['str', 'con'],
      });
      expect(entry.tags, ['class']);
      expect(entry.source.label, '本地资料');
      expect(entry.revision, 1);
    });

    test('uses empty collections for omitted optional fields', () {
      final entry = ContentEntry.fromJson({
        'id': 'example:spell/fireball',
        'type': 'spell',
        'slug': 'fireball',
        'name': '火球术',
        'body': <Map<String, Object?>>[],
        'revision': 1,
      });

      expect(entry.aliases, isEmpty);
      expect(entry.summary, isEmpty);
      expect(entry.structured, isEmpty);
      expect(entry.tags, isEmpty);
      expect(entry.source.label, isEmpty);
    });

    test('requires mandatory fields', () {
      expect(
        () => ContentEntry.fromJson({
          'type': 'spell',
          'slug': 'fireball',
          'name': '火球术',
          'body': <Map<String, Object?>>[],
          'revision': 1,
        }),
        throwsFormatException,
      );
    });

    test('round trips through toJson', () {
      final entry = ContentEntry.fromJson({
        'id': 'example:class/fighter',
        'type': 'class',
        'slug': 'fighter',
        'name': '战士',
        'body': [
          {'type': 'paragraph', 'text': '测试'},
        ],
        'revision': 1,
      });
      final json = entry.toJson();
      final restored = ContentEntry.fromJson(json);
      expect(restored.id, entry.id);
      expect(restored.name, entry.name);
      expect(restored.body, hasLength(1));
    });
  });

  group('ContentPackageManifest', () {
    test('parses a full manifest', () {
      final manifest = ContentPackageManifest.fromJson({
        'formatVersion': 1,
        'id': 'example',
        'name': 'Example',
        'version': '1.0.0',
        'locale': 'zh-CN',
        'system': 'dnd5e-2024',
        'entryCount': 42,
      });
      expect(manifest.formatVersion, 1);
      expect(manifest.id, 'example');
      expect(manifest.name, 'Example');
      expect(manifest.version, '1.0.0');
      expect(manifest.locale, 'zh-CN');
      expect(manifest.system, 'dnd5e-2024');
      expect(manifest.entryCount, 42);
      expect(manifest.priority, 0, reason: '旧 manifest 不写 priority → 缺省 0');
    });

    test('priority 往返：缺失 → 0，显式值读回，非整数抛 FormatException', () {
      final withPriority = ContentPackageManifest.fromJson({
        'formatVersion': 3,
        'id': 'errata',
        'name': 'Errata',
        'version': '1.0.0',
        'locale': 'zh-CN',
        'system': 'dnd5e-2024',
        'entryCount': 1,
        'priority': 40,
      });
      expect(withPriority.priority, 40);
      final restored = ContentPackageManifest.fromJson(withPriority.toJson());
      expect(restored.priority, 40, reason: 'toJson 始终写出 priority，往返自洽');
      expect(
        ContentPackageManifest.fromJson(
          ContentPackageManifest.fromJson({
            'formatVersion': 3,
            'id': 'legacy',
            'name': 'Legacy',
            'version': '1.0.0',
            'locale': 'zh-CN',
            'system': 'dnd5e-2024',
            'entryCount': 1,
          }).toJson(),
        ).priority,
        0,
      );
      // 类型错误不静默取默认值：写了 "40" 的包必须被发现，而不是悄悄排到档案之后。
      expect(
        () => ContentPackageManifest.fromJson({
          'formatVersion': 3,
          'id': 'bad',
          'name': 'Bad',
          'version': '1.0.0',
          'locale': 'zh-CN',
          'system': 'dnd5e-2024',
          'entryCount': 1,
          'priority': '40',
        }),
        throwsFormatException,
      );
    });

    test('rejects missing format version', () {
      expect(
        () => ContentPackageManifest.fromJson({
          'id': 'example',
          'name': 'Example',
          'version': '1.0.0',
          'locale': 'zh-CN',
          'system': 'dnd5e-2024',
          'entryCount': 1,
        }),
        throwsFormatException,
      );
    });
  });
}
