import 'package:dnd_table_client/src/features/campaigns/presentation/chat/campaign_chat_composer.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/chat/campaign_composer_identity.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/chat/chat_mode_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keeps the composer usable at 360px with keyboard insets', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final text = TextEditingController(text: '保留草稿');
    addTearDown(text.dispose);
    await tester.pumpWidget(
      _harness(
        controller: text,
        viewInsets: const EdgeInsets.only(bottom: 300),
        onSend: (_) async => false,
      ),
    );

    await tester.tap(find.byKey(const Key('campaign-chat-send')));
    await tester.pumpAndSettle();

    expect(text.text, '保留草稿');
    expect(find.byKey(const Key('campaign-chat-input')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses accessible compact controls and a 48px avatar target', (
    tester,
  ) async {
    final text = TextEditingController();
    addTearDown(text.dispose);
    await tester.pumpWidget(
      _harness(controller: text, onSend: (_) async => true),
    );

    expect(
      tester.getSize(find.byKey(const Key('campaign-avatar-target'))),
      const Size.square(48),
    );
    expect(find.bySemanticsLabel('说'), findsOneWidget);
    expect(find.bySemanticsLabel('做'), findsOneWidget);
    expect(find.text('说'), findsNothing);
    expect(find.text('做'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a dismissible temporary identity banner', (tester) async {
    final text = TextEditingController();
    var discarded = false;
    addTearDown(text.dispose);
    await tester.pumpWidget(
      _harness(
        controller: text,
        draftIdentityName: '临时守卫',
        onDiscardDraft: () => discarded = true,
        onSend: (_) async => true,
      ),
    );

    expect(find.text('临时身份：临时守卫'), findsOneWidget);
    await tester.tap(find.byKey(const Key('discard-draft-identity')));
    expect(discarded, isTrue);
  });
}

Widget _harness({
  required TextEditingController controller,
  required Future<bool> Function(String content) onSend,
  EdgeInsets viewInsets = EdgeInsets.zero,
  String? draftIdentityName,
  VoidCallback? onDiscardDraft,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(viewInsets: viewInsets),
      child: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: CampaignChatComposer(
            identity: const CampaignComposerIdentity(
              displayName: '阿莱娜',
              speakerMode: 'actor',
              actorId: 'actor-1',
              avatarUrl: null,
              healthState: 'healthy',
              localCharacter: null,
              campaignActor: null,
              subtitle: 'HP 8/10',
            ),
            mode: ChatMode.say,
            controller: controller,
            sending: false,
            onIdentityTap: () {},
            onModeChanged: (_) {},
            onSend: onSend,
            draftIdentityName: draftIdentityName,
            onDiscardDraft: onDiscardDraft,
          ),
        ),
      ),
    ),
  );
}
