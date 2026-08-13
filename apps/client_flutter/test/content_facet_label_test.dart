import 'package:dnd_table_client/src/features/content/presentation/content_search_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('monster facet labels expose broad localized creature types', () {
    expect(contentFacetValueLabel('monster', 'type', 'undead'), '亡灵');
    expect(contentFacetValueLabel('monster', 'type', 'humanoid'), '类人');
    expect(contentFacetValueLabel('monster', 'type', 'construct'), '构装');
  });
}
