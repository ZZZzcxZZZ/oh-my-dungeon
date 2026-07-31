import 'package:dnd_table_client/src/features/campaigns/presentation/characters/campaign_character_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/campaign_test_support.dart';

void main() {
  testWidgets(
    'searches player and NPC characters and returns the selected row',
    (tester) async {
      String? selectedId;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () async {
                  final selected = await showCampaignCharacterPickerSheet(
                    context: context,
                    title: '选择角色',
                    characters: [
                      testCampaignCharacter(
                        id: 'player-1',
                        characterType: 'player',
                        sheet: const {'name': '阿兰尼斯'},
                      ),
                      testCampaignCharacter(
                        id: 'npc-1',
                        characterType: 'npc',
                        sheet: const {'name': '酒馆老板'},
                      ),
                    ],
                  );
                  selectedId = selected?.id;
                },
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('campaign-character-picker-search')),
        findsOne,
      );
      expect(find.text('阿兰尼斯'), findsOne);
      expect(find.text('酒馆老板'), findsOne);

      await tester.enterText(
        find.byKey(const Key('campaign-character-picker-search')),
        '老板',
      );
      await tester.pump();
      expect(find.text('阿兰尼斯'), findsNothing);
      expect(find.text('酒馆老板'), findsOne);

      await tester.tap(find.text('酒馆老板'));
      await tester.pumpAndSettle();
      expect(selectedId, 'npc-1');
    },
  );
}
