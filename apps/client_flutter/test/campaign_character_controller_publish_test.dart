import 'package:dnd_table_client/src/features/campaigns/presentation/characters/campaign_character_controller.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign_character.dart';
import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/campaign_test_support.dart';

void main() {
  late MemoryCampaignSyncApiClient apiClient;

  Future<CampaignCharacterController> buildController({
    Future<void> Function(CampaignCharacter character)? onCharacterPublished,
  }) async {
    apiClient = MemoryCampaignSyncApiClient();
    final controller = CampaignCharacterController(
      cacheRepository: MemoryCampaignCacheRepository(),
      apiClient: apiClient,
      apiBaseUrl: 'https://example.test/api',
      accessToken: 'access-token',
      currentUserId: 'user-1',
      onCharacterPublished: onCharacterPublished,
    );
    await controller.selectCampaign('campaign-1');
    return controller;
  }

  test(
    'a failed local backlink does not turn a successful publish into failure',
    () async {
      final controller = await buildController(
        onCharacterPublished: (_) async =>
            throw StateError('mirror unavailable'),
      );
      addTearDown(controller.dispose);

      final published = await controller.publishCharacter(
        CharacterSheet.local(id: 'local-1', name: '米拉', level: 1),
      );

      expect(published, isTrue);
      expect(controller.characters, hasLength(1));
      expect(controller.syncWarning, contains('本地角色卡同步失败'));
    },
  );

  test('unexpected publish failures expose their actual cause', () async {
    final controller = await buildController();
    addTearDown(controller.dispose);
    apiClient.nextPublishCharacterException = StateError('bad sheet value');

    final published = await controller.publishCharacter(
      CharacterSheet.local(id: 'local-1', name: '米拉', level: 1),
    );

    expect(published, isFalse);
    expect(controller.error, contains('bad sheet value'));
  });
}
