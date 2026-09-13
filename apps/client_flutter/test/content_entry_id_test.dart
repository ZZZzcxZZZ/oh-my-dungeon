import 'package:dnd_table_client/src/features/content/domain/content_entry_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonicalContentEntryId：剥传输前缀，其它一律原样', () {
    // 本地前缀
    expect(canonicalContentEntryId('local:x'), 'x');
    expect(
      canonicalContentEntryId('local:errata:class/wizard'),
      'errata:class/wizard',
    );
    // 战役前缀：只剥到第二个冒号（包 id 允许含 `:`）
    expect(
      canonicalContentEntryId('campaign:c1:errata:class/wizard'),
      'errata:class/wizard',
    );
    expect(canonicalContentEntryId('campaign:c1:base'), 'base');
    // 已经是规范 id / 占位符 / 空串：原样
    expect(canonicalContentEntryId('errata:class/wizard'), 'errata:class/wizard');
    expect(canonicalContentEntryId('<entry>'), '<entry>');
    expect(canonicalContentEntryId(''), '');
    // 边界：只有前缀、或前缀后不是 `<cid>:` 形态时不乱剥
    expect(canonicalContentEntryId('local:'), '');
    expect(canonicalContentEntryId('campaign:'), 'campaign:');
    expect(canonicalContentEntryId('campaign::x'), 'campaign::x');
    // 前后空白先裁掉
    expect(canonicalContentEntryId('  local:x  '), 'x');
  });
}
