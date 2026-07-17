import 'package:dnd_table_client/src/features/campaigns/presentation/widgets/invite_share.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatInviteShareText', () {
    test('包含邀请码', () {
      final text = formatInviteShareText(code: 'ABC123');
      expect(text, contains('ABC123'));
    });

    test('包含战役名（当提供时）', () {
      final text = formatInviteShareText(
        code: 'ABC123',
        campaignName: '失落矿坑',
      );
      expect(text, contains('失落矿坑'));
      expect(text, contains('ABC123'));
    });

    test('包含服务器地址（当提供时）', () {
      final text = formatInviteShareText(
        code: 'ABC123',
        campaignName: '失落矿坑',
        serverUrl: 'http://47.115.78.115',
      );
      expect(text, contains('http://47.115.78.115'));
      expect(text, contains('ABC123'));
    });

    test('无战役名时使用通用文案', () {
      final text = formatInviteShareText(code: 'XYZ789');
      expect(text, contains('XYZ789'));
      expect(text, contains('D&D'));
    });

    test('包含加入指引', () {
      final text = formatInviteShareText(code: 'ABC123');
      expect(text, contains('加入战役'));
    });
  });
}
