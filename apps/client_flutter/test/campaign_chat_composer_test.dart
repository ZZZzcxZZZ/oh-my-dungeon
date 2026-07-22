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
    // Plan 2026-07-23 Task 1.2: 现在显示「说」「做」文字标签 + 图标。
    expect(find.text('说'), findsOneWidget);
    expect(find.text('做'), findsOneWidget);
    expect(find.byType(ChatModePicker), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('groups mode and text inside one composer input surface', (
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
    final send = tester.getRect(find.byKey(const Key('campaign-chat-send')));

    expect(avatar.right, lessThan(surface.left));
    expect(surface.right, lessThan(send.left));
    expect(surface.contains(modeControl.center), isTrue);
    expect(surface.contains(input.center), isTrue);
    expect(input.width, greaterThanOrEqualTo(120));
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the previous two compact mode buttons', (tester) async {
    var mode = ChatMode.say;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Align(
              alignment: Alignment.bottomLeft,
              child: SizedBox(
                width: 96,
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

    expect(find.byKey(const Key('chat-mode-track')), findsNothing);
    // Plan 2026-07-23 Task 1.2: 引入滑动 thumb，现在存在。
    expect(find.byKey(const Key('chat-mode-thumb')), findsOneWidget);
    expect(
      tester
          .widget<ChatModeHalf>(find.byKey(const Key('chat-mode-say')))
          .selected,
      isTrue,
    );

    // Plan 2026-07-23 Task 1.2: 点击 act 按钮触发切换。
    await tester.tap(find.byKey(const Key('chat-mode-action')));
    await tester.pumpAndSettle();

    expect(mode, ChatMode.act);
    expect(
      tester
          .widget<ChatModeHalf>(find.byKey(const Key('chat-mode-action')))
          .selected,
      isTrue,
    );
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
