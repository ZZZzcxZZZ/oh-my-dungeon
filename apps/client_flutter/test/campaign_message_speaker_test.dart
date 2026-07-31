import 'package:dnd_table_client/src/features/campaigns/domain/campaign_message_speaker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('serializes every explicit campaign message speaker kind', () {
    expect(const CampaignMessageSpeaker.narrator().toJson(), {
      'kind': 'narrator',
    });
    expect(const CampaignMessageSpeaker.ooc().toJson(), {'kind': 'ooc'});
    expect(const CampaignMessageSpeaker.character('character-1').toJson(), {
      'kind': 'character',
      'characterId': 'character-1',
    });
    expect(
      const CampaignMessageSpeaker.temporary(
        displayName: '守门人',
        avatarUrl: 'avatar.png',
      ).toJson(),
      {'kind': 'temporary', 'displayName': '守门人', 'avatarUrl': 'avatar.png'},
    );
  });
}
