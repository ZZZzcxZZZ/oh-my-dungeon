// 「自动获得」预览（`_RuleGrantPreview`）的行派生：与引擎同源的多等级展开，
// 以及"每行一次"展示所需的重复消除。
import 'package:dnd_table_client/src/features/characters/presentation/character_editor_page.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ruleGrantPreviewRows', () {
    test('多等级步骤按每个已达等级各产一行，等级取各自生效等级', () {
      final entry = _entry(
        rules: const {
          'progression': [
            {
              'levels': [4, 8, 12, 16],
              'grants': [
                {
                  'id': 'asi',
                  'kind': 'ability',
                  'target': 'str',
                  'value': 1,
                  'label': '属性提升：力量 +1',
                },
              ],
            },
          ],
        },
      );

      // 16 级：四次独立生效，预览必须是 4 行（旧实现只取 reached.last → 1 行）。
      final rows = ruleGrantPreviewRows([entry], 16);
      expect(rows, hasLength(4));
      expect(rows.map((row) => row.sourceLevel), [4, 8, 12, 16]);
      expect(rows.map((row) => row.grant.label).toSet(), {'属性提升：力量 +1'});

      // 边界：7 级只达 4 级 → 1 行；3 级一个等级都没达 → 0 行。
      expect(ruleGrantPreviewRows([entry], 7), hasLength(1));
      expect(ruleGrantPreviewRows([entry], 7).single.sourceLevel, 4);
      expect(ruleGrantPreviewRows([entry], 3), isEmpty);
    });

    test('条目级 rules.grants 与等级无关，sourceLevel 为 null', () {
      final entry = _entry(
        rules: const {
          'grants': [
            {'id': 'ac', 'kind': 'armorClass', 'value': 1, 'label': '防御加值'},
          ],
        },
      );

      final rows = ruleGrantPreviewRows([entry], 1);
      expect(rows, hasLength(1));
      expect(rows.single.sourceLevel, isNull);
      expect(rows.single.entry.name, '晋升者');
    });

    test('kind: action 逐级展开只保留最早生效的一行', () {
      final entry = _entry(
        rules: const {
          'progression': [
            {
              'levels': [1, 2, 3],
              'grants': [
                {
                  'id': 'action-surge',
                  'kind': 'action',
                  'label': '动作如潮',
                },
                {
                  'id': 'asi-dex',
                  'kind': 'ability',
                  'target': 'dex',
                  'value': 1,
                  'label': '敏捷提升',
                },
              ],
            },
          ],
        },
      );

      final rows = ruleGrantPreviewRows([entry], 3);
      // 动作去重成 1 行；属性加值仍是 3 行（多等级语义在这里必须保留）。
      expect(
        rows.where((row) => row.grant.kind.name == 'action'),
        hasLength(1),
      );
      expect(rows.where((row) => row.grant.id == 'asi-dex'), hasLength(3));
      expect(
        rows.firstWhere((row) => row.grant.id == 'action-surge').sourceLevel,
        1,
      );
    });

    test('同一生效单元被两个条目步骤覆盖时不重复列出', () {
      final entry = _entry(
        rules: const {
          'progression': [
            {
              'levels': [3],
              'grants': [
                {'id': 'hp-up', 'kind': 'hitPoints', 'value': 1, 'label': '生命提升'},
              ],
            },
            {
              'levels': [3],
              'grants': [
                {'id': 'hp-up', 'kind': 'hitPoints', 'value': 1, 'label': '生命提升'},
              ],
            },
          ],
        },
      );

      expect(ruleGrantPreviewRows([entry], 3), hasLength(1));
    });
  });
}

ContentEntry _entry({required Map<String, Object?> rules}) =>
    ContentEntry.fromJson(<String, Object?>{
      'id': 'test:class/ascendant',
      'type': 'class',
      'slug': 'ascendant',
      'name': '晋升者',
      'body': <Object?>[],
      'revision': 1,
      'structured': <String, Object?>{},
      'rules': rules,
    });
