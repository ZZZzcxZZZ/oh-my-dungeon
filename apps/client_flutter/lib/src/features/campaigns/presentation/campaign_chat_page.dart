// ignore_for_file: deprecated_member_use_from_same_package

import 'package:flutter/material.dart';

import '../../characters/domain/character.dart';
import '../../characters/presentation/character_controller.dart';
import '../../characters/presentation/character_detail_page.dart';
import '../../content/domain/content.dart';
import '../../content/presentation/content_controller.dart';
import '../../rooms/domain/dice_roller.dart';
import '../domain/campaign.dart';
import 'campaign_controller.dart';

class CampaignChatPage extends StatefulWidget {
  const CampaignChatPage({
    required this.campaign,
    required this.character,
    required this.campaignController,
    required this.characterController,
    required this.contentController,
    required this.isDm,
    this.campaignActorId,
    this.diceRoller,
    super.key,
  });

  final Campaign campaign;
  final CharacterSheet? character;
  final CampaignController campaignController;
  final CharacterController characterController;
  final ContentController contentController;
  final bool isDm;
  final String? campaignActorId;
  final DiceRoller? diceRoller;

  @override
  State<CampaignChatPage> createState() => _CampaignChatPageState();
}

class _CampaignChatPageState extends State<CampaignChatPage> {
  final _controller = TextEditingController();
  _ChatMode _mode = _ChatMode.say;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.campaignController.loadMessages(widget.campaign.id);
      widget.campaignController.connectCampaignChat(widget.campaign.id);
      widget.characterController.loadCampaignCharacters(widget.campaign.id);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    widget.campaignController.disconnectCampaignChat();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.campaignController,
        widget.characterController,
      ]),
      builder: (context, _) {
        final messages = widget.campaignController.messages;
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.campaign.name),
                Text(
                  _t('campaignChatRoom'),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: _t('members'),
                onPressed: _showMembers,
                icon: const Icon(Icons.people_outline),
              ),
            ],
          ),
          body: Column(
            children: [
              _ChatIdentityBar(character: widget.character),
              if (widget.campaignController.messagesError != null)
                MaterialBanner(
                  content: Text(widget.campaignController.messagesError!),
                  actions: [
                    TextButton(
                      onPressed: () => widget.campaignController.loadMessages(
                        widget.campaign.id,
                      ),
                      child: Text(_t('retry')),
                    ),
                  ],
                ),
              Expanded(
                child: widget.campaignController.isMessagesLoading
                    ? const Center(child: CircularProgressIndicator())
                    : messages.isEmpty
                    ? Center(
                        child: Text(
                          _t('emptyChat'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          return _CampaignChatBubble(message: message);
                        },
                      ),
              ),
              _buildInputBar(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton.filledTonal(
                  tooltip: _t('moreTableTools'),
                  onPressed: _showMoreActions,
                  icon: const Icon(Icons.add),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ChatModePicker(
                    mode: _mode,
                    enabled: !_sending,
                    onChanged: (mode) {
                      setState(() => _mode = mode);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('campaign-chat-input'),
                    controller: _controller,
                    enabled: !_sending,
                    decoration: InputDecoration(
                      hintText: _mode == _ChatMode.say
                          ? _t('sayHint')
                          : _t('actHint'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: _sending ? null : (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const Key('campaign-chat-send'),
                  onPressed: _sending ? null : _send,
                  child: Text(_t('send')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _sending) return;

    setState(() => _sending = true);
    final sent = await widget.campaignController.sendMessage(
      campaignId: widget.campaign.id,
      kind: _mode == _ChatMode.act ? 'action' : 'say',
      content: content,
      campaignActorId: widget.campaignActorId,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (sent) {
      _controller.clear();
    }
  }

  Future<void> _showMoreActions() {
    return showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  leading: const Icon(Icons.casino_outlined),
                  title: Text(_t('rollDice')),
                  onTap: _showRollSheet,
                ),
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: Text(_t('characterSheet')),
                  onTap: _openCharacterSheet,
                ),
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text(_t('contentLibrary')),
                  onTap: _showContentLibrary,
                ),
                ListTile(
                  leading: const Icon(Icons.table_restaurant_outlined),
                  title: Text(_t('tableTools')),
                  subtitle: Text(_t('tableToolsHint')),
                  onTap: _showTableTools,
                ),
                if (widget.isDm)
                  ListTile(
                    leading: const Icon(Icons.shield_outlined),
                    title: Text(_t('dmControl')),
                    subtitle: Text(_t('dmControlHint')),
                    onTap: _showDmControl,
                  ),
                ListTile(
                  leading: const Icon(Icons.fact_check_outlined),
                  title: Text(_t('checkRequest')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showTableTools() {
    Navigator.of(context).pop();
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('tableTools'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(_t('tableToolsDescription')),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.fact_check_outlined),
                  title: Text(_t('checkRequest')),
                  subtitle: Text(_t('checkRequestHint')),
                ),
                ListTile(
                  leading: const Icon(Icons.history_edu_outlined),
                  title: Text(_t('tableLog')),
                  subtitle: Text(_t('tableLogHint')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDmControl() {
    Navigator.of(context).pop();
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('dmControl'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(_t('dmControlDescription')),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.shield_outlined),
                  title: Text(_t('encounterControl')),
                  subtitle: Text(_t('encounterControlHint')),
                ),
                ListTile(
                  leading: const Icon(Icons.group_outlined),
                  title: Text(_t('memberStatus')),
                  subtitle: Text(_t('memberStatusHint')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showRollSheet() {
    Navigator.of(context).pop();
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('quickRoll'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final notation in _quickDice)
                      FilledButton.tonalIcon(
                        onPressed: _sending
                            ? null
                            : () => _sendRollExpression(notation),
                        icon: const Icon(Icons.casino_outlined),
                        label: Text(notation),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _sendRollExpression(String notation) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final roll = (widget.diceRoller ?? DiceRoller()).rollExpression(notation);
      Navigator.of(context).pop();
      setState(() => _sending = true);
      final sent = await widget.campaignController.sendMessage(
        campaignId: widget.campaign.id,
        kind: 'roll',
        content: roll.label,
        campaignActorId: widget.campaignActorId,
      );
      if (!mounted) return;
      setState(() => _sending = false);
      if (!sent) {
        messenger.showSnackBar(SnackBar(content: Text(_t('sendFailed'))));
      }
    } on DiceRollException catch (error) {
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(content: Text('${_t('invalidDice')}$error')),
      );
    }
  }

  Future<void> _showContentLibrary() async {
    Navigator.of(context).pop();
    final searchController = TextEditingController();
    var selectedType = 'all';

    Future<void> loadItems() {
      final query = searchController.text.trim();
      return widget.contentController.loadAvailableCampaignItems(
        campaignId: widget.campaign.id,
        type: selectedType == 'all' ? null : selectedType,
        query: query.isEmpty ? null : query,
      );
    }

    await loadItems();
    if (!mounted) {
      searchController.dispose();
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> refreshItems() async {
              setSheetState(() {});
              await loadItems();
              if (context.mounted) setSheetState(() {});
            }

            return SafeArea(
              child: FractionallySizedBox(
                heightFactor: 0.78,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _t('campaignContentLibrary'),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            tooltip: MaterialLocalizations.of(
                              context,
                            ).closeButtonTooltip,
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          labelText: _t('searchContent'),
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            tooltip: _t('search'),
                            onPressed: refreshItems,
                            icon: const Icon(Icons.arrow_forward),
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => refreshItems(),
                      ),
                      const SizedBox(height: 12),
                      DropdownMenu<String>(
                        label: Text(_t('contentType')),
                        initialSelection: selectedType,
                        expandedInsets: EdgeInsets.zero,
                        dropdownMenuEntries: [
                          DropdownMenuEntry(value: 'all', label: _t('all')),
                          for (final type in _contentTypeFilters)
                            DropdownMenuEntry(
                              value: type,
                              label: _contentTypeLabel(type),
                            ),
                        ],
                        onSelected: (value) async {
                          if (value == null) return;
                          selectedType = value;
                          await refreshItems();
                        },
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: AnimatedBuilder(
                          animation: widget.contentController,
                          builder: (context, _) {
                            if (widget.contentController.isLoading) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (widget.contentController.error != null) {
                              return Center(
                                child: Text(widget.contentController.error!),
                              );
                            }

                            final items =
                                widget.contentController.availableItems;
                            if (items.isEmpty) {
                              return Center(child: Text(_t('emptyContent')));
                            }

                            return ListView.separated(
                              itemCount: items.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final item = items[index];
                                return ListTile(
                                  leading: const Icon(Icons.menu_book_outlined),
                                  title: Text(item.name),
                                  subtitle: Text(
                                    '${_contentTypeLabel(item.type)} · ${item.sourceLabel}',
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => _showContentItemDetail(item),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    searchController.dispose();
  }

  Future<void> _showContentItemDetail(ContentItem item) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Text(
                  '${_contentTypeLabel(item.type)} · ${item.sourceLabel}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 12),
                Text(item.description),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openCharacterSheet() {
    Navigator.of(context).pop();
    final character = widget.character;
    if (character == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_t('noBoundCharacter'))));
      return;
    }

    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => CharacterDetailPage(character: character),
      ),
    );
  }

  Future<void> _showMembers() {
    final bindings = widget.characterController.campaignCharacters;
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _t('campaignMembers'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                if (bindings.isEmpty)
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person_off)),
                    title: Text(_t('emptyMembers')),
                  )
                else
                  for (final binding in bindings)
                    _CampaignMemberTile(binding: binding),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CampaignMemberTile extends StatelessWidget {
  const _CampaignMemberTile({required this.binding});

  final CharacterCampaignBinding binding;

  @override
  Widget build(BuildContext context) {
    final character = binding.character;
    final name = character?.name ?? _t('unboundCharacter');
    final ancestryAndClass = _characterLine(character);
    final status = _statusLine(character);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _ChatAvatar(name: name, avatarUrl: character?.avatarUrl),
      title: Text(name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ancestryAndClass.isNotEmpty) Text(ancestryAndClass),
          if (status.isNotEmpty) Text(status),
          if (character != null && character.conditions.isNotEmpty)
            Text(character.conditions.join(', ')),
        ],
      ),
      trailing: Chip(label: Text(binding.visibility)),
    );
  }
}

class _ChatIdentityBar extends StatelessWidget {
  const _ChatIdentityBar({required this.character});

  final CharacterSheet? character;

  @override
  Widget build(BuildContext context) {
    final text = character == null
        ? _t('unboundCharacter')
        : '${character!.name} \u00B7 HP ${character!.currentHp}/${character!.maxHp} \u00B7 AC ${character!.armorClass}';
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            _ChatAvatar(
              name: character?.name ?? '?',
              avatarUrl: character?.avatarUrl,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

class _ChatModePicker extends StatelessWidget {
  const _ChatModePicker({
    required this.mode,
    required this.enabled,
    required this.onChanged,
  });

  final _ChatMode mode;
  final bool enabled;
  final ValueChanged<_ChatMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Row(
          children: [
            Expanded(
              child: _ChatModeHalf(
                key: const Key('chat-mode-say'),
                selected: mode == _ChatMode.say,
                enabled: enabled,
                icon: Icons.chat_bubble_outline,
                label: _t('say'),
                onTap: () => onChanged(_ChatMode.say),
              ),
            ),
            Expanded(
              child: _ChatModeHalf(
                key: const Key('chat-mode-action'),
                selected: mode == _ChatMode.act,
                enabled: enabled,
                icon: Icons.directions_run_outlined,
                label: _t('act'),
                onTap: () => onChanged(_ChatMode.act),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatModeHalf extends StatelessWidget {
  const _ChatModeHalf({
    super.key,
    required this.selected,
    required this.enabled,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final bool enabled;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = selected
        ? colorScheme.onSecondaryContainer
        : colorScheme.onSurfaceVariant;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? colorScheme.secondaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: foreground),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: foreground),
            ),
          ],
        ),
      ),
    );
  }
}

class _CampaignChatBubble extends StatelessWidget {
  const _CampaignChatBubble({required this.message});

  final CampaignChatMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.kind == 'roll') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Chip(
            avatar: const Icon(Icons.casino_outlined, size: 18),
            label: Text(message.content),
          ),
        ),
      );
    }

    if (message.kind == 'action') {
      return Padding(
        key: const Key('action-message'),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Text(
            message.content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    final displayName = message.displayName.trim().isEmpty
        ? _t('unknownSpeaker')
        : message.displayName;
    return Padding(
      key: const Key('say-message'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChatAvatar(name: displayName, avatarUrl: message.avatarUrl),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                Card(
                  margin: const EdgeInsets.only(top: 4),
                  color: colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(message.content),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatAvatar extends StatelessWidget {
  const _ChatAvatar({required this.name, required this.avatarUrl});

  final String name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();
    return CircleAvatar(
      backgroundImage: url == null || url.isEmpty ? null : NetworkImage(url),
      child: url == null || url.isEmpty ? Text(_avatarText(name)) : null,
    );
  }
}

enum _ChatMode { say, act }

const _quickDice = ['d20', 'd12', 'd10', 'd8', 'd6', 'd4', 'd100'];
const _contentTypeFilters = [
  'spell',
  'equipment',
  'item',
  'species',
  'class',
  'background',
  'feat',
  'condition',
  'monster',
];

String _avatarText(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '?';
  return trimmed.characters.first;
}

String _characterLine(CharacterSheet? character) {
  if (character == null) return '';
  return [
    character.classSummary.trim(),
    character.raceSummary.trim(),
  ].where((item) => item.isNotEmpty).join(' · ');
}

String _statusLine(CharacterSheet? character) {
  if (character == null) return '';
  final parts = [
    'HP ${character.currentHp}/${character.maxHp}',
    'AC ${character.armorClass}',
    if (character.conditions.isNotEmpty) character.conditions.join(', '),
  ];
  return parts.join(' · ');
}

String _contentTypeLabel(String type) => switch (type) {
  'background' => '\u80cc\u666f',
  'class' => '\u804c\u4e1a',
  'condition' => '\u72b6\u6001',
  'equipment' => '\u88c5\u5907',
  'feat' => '\u4e13\u957f',
  'item' => '\u7269\u54c1',
  'monster' => '\u602a\u7269',
  'species' => '\u79cd\u65cf',
  'spell' => '\u6cd5\u672f',
  _ => type,
};

String _t(String key) => switch (key) {
  'act' => '\u505a',
  'actHint' => '\u63cf\u8ff0\u52a8\u4f5c...',
  'all' => '\u5168\u90e8',
  'campaignChatRoom' => '\u6218\u5f79\u804a\u5929\u5ba4',
  'campaignContentLibrary' => '\u6218\u5f79\u8d44\u6599\u5e93',
  'campaignMembers' => '\u6218\u5f79\u6210\u5458',
  'characterSheet' => '\u89d2\u8272\u5361',
  'checkRequest' => '\u68c0\u5b9a\u8bf7\u6c42',
  'checkRequestHint' => '向玩家发起属性、技能或豁免检定',
  'contentLibrary' => '\u8d44\u6599\u5e93',
  'contentType' => '\u8d44\u6599\u7c7b\u578b',
  'dmControl' => 'DM 控场',
  'dmControlDescription' => '这里会继续整合遭遇、成员状态和隐藏信息。',
  'dmControlHint' => '遭遇、成员状态和 DM 私有工具',
  'emptyMembers' => '\u8fd8\u6ca1\u6709\u7ed1\u5b9a\u89d2\u8272',
  'emptyContent' => '\u6ca1\u6709\u627e\u5230\u53ef\u7528\u8d44\u6599',
  'emptyChat' =>
    '\u8fd8\u6ca1\u6709\u6d88\u606f\n\u4ece\u4e0b\u65b9\u5f00\u59cb\u8bf4\u8bdd\u6216\u505a\u52a8\u4f5c',
  'encounterControl' => '遭遇控场',
  'encounterControlHint' => '管理先攻、回合、敌人生命值和状态',
  'members' => '\u6210\u5458',
  'memberStatus' => '成员状态',
  'memberStatusHint' => '查看角色 HP、AC、状态和可见信息',
  'moreTableTools' => '\u66f4\u591a\u8dd1\u56e2\u529f\u80fd',
  'noBoundCharacter' =>
    '\u8bf7\u5148\u5728\u6218\u5f79\u4e2d\u7ed1\u5b9a\u89d2\u8272',
  'invalidDice' => '\u63b7\u9ab0\u8868\u8fbe\u5f0f\u65e0\u6548\uff1a',
  'quickRoll' => '\u5feb\u901f\u63b7\u9ab0',
  'retry' => '\u91cd\u8bd5',
  'rollDice' => '\u63b7\u9ab0',
  'say' => '\u8bf4',
  'sayHint' => '\u8bf4\u4e9b\u4ec0\u4e48...',
  'search' => '\u641c\u7d22',
  'searchContent' => '\u641c\u7d22\u8d44\u6599',
  'sendFailed' => '\u53d1\u9001\u5931\u8d25',
  'send' => '\u53d1\u9001',
  'tableLog' => '跑团日志',
  'tableLogHint' => '查看聊天、掷骰、状态变化和关键事件',
  'tableTools' => '桌面工具',
  'tableToolsDescription' => '桌面能力已经并入战役聊天室；常用操作从这里打开。',
  'tableToolsHint' => '检定、日志和战役现场工具',
  'unknownSpeaker' => '\u672a\u77e5\u53d1\u8a00\u8005',
  'unboundCharacter' => '\u672a\u7ed1\u5b9a\u89d2\u8272',
  _ => key,
};
