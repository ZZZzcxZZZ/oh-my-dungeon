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

  testWidgets('uses equal targets and equal 44px visible controls', (
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
    expect(
      tester.getSize(find.byKey(const Key('campaign-chat-send-target'))),
      const Size.square(48),
    );
    expect(
      tester.getSize(find.byKey(const Key('campaign-avatar-visual'))),
      const Size.square(44),
    );
    expect(
      tester.getSize(find.byKey(const Key('campaign-chat-send-visual'))),
      const Size.square(44),
    );
    expect(find.byType(ChatModePicker), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('embeds the single mode toggle inside the capsule input', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final text = TextEditingController();
    addTearDown(text.dispose);
    await tester.pumpWidget(
      _harness(controller: text, onSend: (_) async => true),
    );

    final avatar = tester.getRect(
      find.byKey(const Key('campaign-avatar-target')),
    );
    final surface = tester.getRect(
      find.byKey(const Key('campaign-composer-input-surface')),
    );
    final modeControl = tester.getRect(find.byType(ChatModePicker));
    final input = tester.getRect(find.byKey(const Key('campaign-chat-input')));
    final send = tester.getRect(
      find.byKey(const Key('campaign-chat-send-target')),
    );

    expect(avatar.right, lessThan(surface.left));
    expect(surface.right, lessThan(send.left));
    expect(surface.contains(modeControl.center), isTrue);
    expect(surface.contains(input.center), isTrue);
    expect(input.width, greaterThanOrEqualTo(120));
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses one circular mode button that toggles on tap', (
    tester,
  ) async {
    var mode = ChatMode.say;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Align(
              alignment: Alignment.bottomLeft,
              child: SizedBox(
                width: 40,
                child: ChatModePicker(
                  mode: mode,
                  enabled: true,
                  onChanged: (next) => setState(() => mode = next),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('chat-mode-toggle')), findsOneWidget);
    expect(find.byKey(const Key('chat-mode-thumb')), findsNothing);

    await tester.tap(find.byKey(const Key('chat-mode-toggle')));
    await tester.pumpAndSettle();

    expect(mode, ChatMode.act);
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

  for (final speakerMode in ['narrator', 'ooc']) {
    testWidgets('$speakerMode identity hides the say/action mode control', (
      tester,
    ) async {
      final text = TextEditingController();
      addTearDown(text.dispose);
      await tester.pumpWidget(
        _harness(
          controller: text,
          identity: CampaignComposerIdentity(
            displayName: speakerMode == 'narrator' ? '旁白 / DM' : '场外',
            speakerMode: speakerMode,
            characterId: null,
            avatarUrl: null,
            healthState: null,
            localCharacter: null,
            campaignCharacter: null,
            subtitle: '',
          ),
          onSend: (_) async => true,
        ),
      );

      expect(find.byType(ChatModePicker), findsNothing);
      expect(find.byKey(const Key('campaign-chat-input')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in const [Size(390, 844), Size(1280, 720)]) {
    testWidgets('handles long content at ${size.width}x${size.height}', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final text = TextEditingController(text: 'verylongunbrokenchatdraft' * 8);
      addTearDown(text.dispose);

      await tester.pumpWidget(
        _harness(
          controller: text,
          draftIdentityName: '一位拥有非常非常长名称的临时战役角色',
          onDiscardDraft: () {},
          onSend: (_) async => true,
        ),
      );

      expect(find.byKey(const Key('campaign-chat-input')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

Widget _harness({
  required TextEditingController controller,
  required Future<bool> Function(String content) onSend,
  CampaignComposerIdentity identity = const CampaignComposerIdentity(
    displayName: '阿莱娜',
    speakerMode: 'character',
    characterId: 'character-1',
    avatarUrl: null,
    healthState: 'healthy',
    localCharacter: null,
    campaignCharacter: null,
    subtitle: 'HP 8/10',
  ),
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
            identity: identity,
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
