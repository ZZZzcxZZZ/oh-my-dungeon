import 'package:dnd_table_client/src/features/client_mode/domain/client_mode.dart';
import 'package:dnd_table_client/src/features/rooms/domain/dice_roller.dart';
import 'package:dnd_table_client/src/features/rooms/domain/room.dart';
import 'package:dnd_table_client/src/features/rooms/presentation/room_home_page.dart';
import 'package:dnd_table_client/src/features/server_profiles/domain/server_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const profile = ServerProfile(
    id: 'localhost',
    name: 'Local Table',
    baseUrl: 'http://localhost:3000',
    apiBaseUrl: 'http://localhost:3000/api',
    websocketUrl: 'ws://localhost:3000/ws',
    lastKnownVersion: '0.1.0',
  );
  const room = Room(id: 'room-1', name: 'Friday One Shot');

  testWidgets('rolls a d20 from the room detail page', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RoomHomePage(
          profile: profile,
          room: room,
          modeController: ClientModeController(),
          diceRoller: DiceRoller(nextInt: (_) => 19),
        ),
      ),
    );

    expect(find.text('暂无掷骰记录'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '掷 D20'));
    await tester.pump();

    expect(find.text('d20 = 20'), findsOneWidget);
  });
}
