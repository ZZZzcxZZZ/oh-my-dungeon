import 'package:flutter/material.dart';

import '../../domain/campaign_character.dart';
import '../widgets/campaign_avatar.dart';

Future<CampaignCharacter?> showCampaignCharacterPickerSheet({
  required BuildContext context,
  required String title,
  required List<CampaignCharacter> characters,
}) {
  return showModalBottomSheet<CampaignCharacter>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) =>
        _CampaignCharacterPickerSheet(title: title, characters: characters),
  );
}

class _CampaignCharacterPickerSheet extends StatefulWidget {
  const _CampaignCharacterPickerSheet({
    required this.title,
    required this.characters,
  });

  final String title;
  final List<CampaignCharacter> characters;

  @override
  State<_CampaignCharacterPickerSheet> createState() =>
      _CampaignCharacterPickerSheetState();
}

class _CampaignCharacterPickerSheetState
    extends State<_CampaignCharacterPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final normalized = _query.trim().toLowerCase();
    final characters = widget.characters
        .where((character) {
          final name = _displayName(character).toLowerCase();
          final type = _typeLabel(character.characterType).toLowerCase();
          return normalized.isEmpty ||
              name.contains(normalized) ||
              type.contains(normalized);
        })
        .toList(growable: false);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              SearchBar(
                key: const Key('campaign-character-picker-search'),
                hintText: '搜索角色',
                leading: const Icon(Icons.search),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: characters.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('没有匹配的角色'),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: characters.length,
                        itemBuilder: (context, index) {
                          final character = characters[index];
                          final name = _displayName(character);
                          return ListTile(
                            key: Key('campaign-character-${character.id}'),
                            leading: CampaignAvatar(
                              initials: name,
                              imageUrl: character.sheet['avatarUrl'] as String?,
                              health: CampaignAvatar.healthFromHp(
                                character.sheet['currentHp'] as num?,
                                character.sheet['maxHp'] as num?,
                              ),
                              healthFraction: CampaignAvatar.fractionFromHp(
                                character.sheet['currentHp'] as num?,
                                character.sheet['maxHp'] as num?,
                              ),
                              size: 40,
                            ),
                            title: Text(name),
                            subtitle: Text(_typeLabel(character.characterType)),
                            onTap: () => Navigator.of(context).pop(character),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _displayName(CampaignCharacter character) {
    final name = character.sheet['name']?.toString().trim();
    return name == null || name.isEmpty ? '未命名角色' : name;
  }

  String _typeLabel(String type) => switch (type) {
    'player' => '玩家角色',
    'npc' => 'NPC',
    'monster' => '怪物',
    'companion' => '同伴',
    _ => '角色',
  };
}
