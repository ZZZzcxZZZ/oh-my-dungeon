import 'package:flutter/material.dart';

import '../../app_preferences/presentation/app_preferences_controller.dart';
import '../../campaigns/presentation/actors/campaign_actor_controller.dart';
import '../../campaigns/presentation/actors/campaign_actor_directory_page.dart';
import '../../campaigns/presentation/actors/publish_character_sheet.dart';
import '../../campaigns/presentation/campaign_controller.dart';
import '../../client_mode/domain/client_mode.dart';
import '../../content/presentation/content_controller.dart';
import '../domain/character.dart';
import '../domain/dnd5e_rules.dart';
import 'character_detail_page.dart';
import 'character_controller.dart';
import 'character_editor_page.dart';

class CharactersTabPage extends StatefulWidget {
  const CharactersTabPage({
    required this.controller,
    this.campaignController,
    this.contentController,
    this.appPreferencesController,
    this.modeController,
    this.actorController,
    super.key,
  });

  final CharacterController controller;
  final CampaignController? campaignController;
  final ContentController? contentController;
  final AppPreferencesController? appPreferencesController;
  final ClientModeController? modeController;
  final CampaignActorController? actorController;

  @override
  State<CharactersTabPage> createState() => _CharactersTabPageState();
}

class _CharactersTabPageState extends State<CharactersTabPage> {
  @override
  void initState() {
    super.initState();
    widget.modeController?.addListener(_onModeChanged);
    widget.actorController?.addListener(_onActorChanged);
  }

  @override
  void didUpdateWidget(covariant CharactersTabPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.modeController != widget.modeController) {
      oldWidget.modeController?.removeListener(_onModeChanged);
      widget.modeController?.addListener(_onModeChanged);
    }
    if (oldWidget.actorController != widget.actorController) {
      oldWidget.actorController?.removeListener(_onActorChanged);
      widget.actorController?.addListener(_onActorChanged);
    }
  }

  @override
  void dispose() {
    widget.modeController?.removeListener(_onModeChanged);
    widget.actorController?.removeListener(_onActorChanged);
    super.dispose();
  }

  void _onModeChanged() {
    if (mounted) setState(() {});
  }

  void _onActorChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.modeController?.mode ?? ClientMode.player;
    final isDm = mode == ClientMode.dungeonMaster;
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.controller,
        widget.campaignController,
        widget.contentController,
        widget.appPreferencesController,
      ]),
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('角色'),
            actions: [
              if (widget.modeController != null)
                _ModeSwitchToggle(
                  modeController: widget.modeController!,
                  isDm: isDm,
                ),
            ],
          ),
          floatingActionButton: isDm
              ? null
              : FloatingActionButton.extended(
                  heroTag: 'create_character',
                  onPressed: _openCreatePage,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('新角色'),
                ),
          body: isDm ? _buildDmBody(context) : _buildPlayerBody(context),
        );
      },
    );
  }

  Widget _buildPlayerBody(BuildContext context) {
    return KeyedSubtree(
      key: const Key('player-local-characters'),
      child: _buildCharacterList(context),
    );
  }

  Widget _buildDmBody(BuildContext context) {
    final actorController = widget.actorController;
    if (actorController == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('DM 模式不可用：未连接战役同步。'),
        ),
      );
    }
    final campaigns = (widget.campaignController?.campaigns ?? const [])
        .map((campaign) => CampaignOption(id: campaign.id, name: campaign.name))
        .toList(growable: false);
    return CampaignActorDirectoryPage(
      controller: actorController,
      campaigns: campaigns,
    );
  }

  Widget _buildCharacterList(BuildContext context) {
    if (widget.controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.controller.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            widget.controller.error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final characters = widget.controller.characters;
    final compact =
        widget.appPreferencesController?.preferences.compactLists ?? false;
    if (characters.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('还没有角色\n点击右下角创建第一张角色卡', textAlign: TextAlign.center),
        ),
      );
    }

    return ListView.separated(
      padding: compact
          ? const EdgeInsets.fromLTRB(12, 8, 12, 80)
          : const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: characters.length,
      separatorBuilder: (context, index) => SizedBox(height: compact ? 4 : 8),
      itemBuilder: (context, index) {
        final character = characters[index];
        return _CharacterCard(
          character: character,
          compact: compact,
          canPublish: widget.actorController != null,
          onOpen: () => _openDetailPage(character),
          onEdit: () => _openEditPage(character),
          onContentRefs: () => _showContentRefsDialog(character),
          onBind: () => _showBindDialog(character),
          onPublish: widget.actorController == null
              ? null
              : () => _showPublishSheet(character),
          onHpDelta: (delta) => _adjustHp(character, delta),
        );
      },
    );
  }

  Future<void> _openCreatePage() async {
    final messenger = ScaffoldMessenger.of(context);
    widget.controller.takeLastCreatedCharacter();
    final campaignId = await _selectCampaignContentSource();
    if (!mounted) return;
    if (campaignId != null && widget.contentController != null) {
      await widget.contentController!.loadAvailableCampaignItems(
        campaignId: campaignId,
      );
    } else if (widget.contentController != null) {
      await widget.contentController!.loadItems();
    }
    if (!mounted) return;
    final contentItems = campaignId == null
        ? (widget.contentController?.items ?? const [])
        : (widget.contentController?.availableItems ?? const []);
    final defaultCreationMethod =
        widget.appPreferencesController?.preferences.defaultCreationMethod ??
        'fullSheet';
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => CharacterEditorPage(
          defaultCreationMethod: defaultCreationMethod,
          contentItems: contentItems,
          onSubmit: (draft) async {
            final success = await widget.controller.createCharacter(draft);
            if (mounted) {
              messenger.showSnackBar(
                SnackBar(content: Text(success ? '角色已创建' : '创建失败')),
              );
            }
            return success;
          },
        ),
      ),
    );
  }

  Future<String?> _selectCampaignContentSource() async {
    final campaigns = widget.campaignController?.campaigns ?? const [];
    if (campaigns.isEmpty) return null;
    var selectedId = campaigns.first.id;
    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('选择创建资料'),
          content: DropdownMenu<String>(
            initialSelection: selectedId,
            label: const Text('战役资料库'),
            dropdownMenuEntries: [
              for (final campaign in campaigns)
                DropdownMenuEntry(value: campaign.id, label: campaign.name),
            ],
            onSelected: (value) {
              if (value != null) setDialogState(() => selectedId = value);
            },
          ),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop(''),
              icon: const Icon(Icons.public),
              label: const Text('使用通用资料'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(selectedId),
              child: const Text('继续'),
            ),
          ],
        ),
      ),
    ).then((value) => value?.isEmpty ?? true ? null : value);
  }

  Future<void> _openDetailPage(CharacterSheet character) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => CharacterDetailPage(
          character: character,
          initialTab:
              widget.appPreferencesController?.preferences.defaultCharacterTab ??
              'overview',
          onUpdateRuntime:
              ({
                int? currentHp,
                int? temporaryHp,
                bool? inspiration,
                List<String>? conditions,
                int? deathSaveSuccesses,
                int? deathSaveFailures,
                Map<String, int>? spellSlotsUsed,
                Map<String, int>? classResourcesUsed,
              }) async {
                if (currentHp != null) {
                  await widget.controller.updateCharacter(
                    character.copyWith(currentHp: currentHp),
                  );
                }
                if (temporaryHp != null ||
                    inspiration != null ||
                    conditions != null ||
                    deathSaveSuccesses != null ||
                    deathSaveFailures != null ||
                    spellSlotsUsed != null ||
                    classResourcesUsed != null) {
                  await widget.controller.updateRuntimeState(
                    characterId: character.id,
                    temporaryHp: temporaryHp,
                    inspiration: inspiration,
                    conditions: conditions,
                    deathSaveSuccesses: deathSaveSuccesses,
                    deathSaveFailures: deathSaveFailures,
                    spellSlotsUsed: spellSlotsUsed,
                    classResourcesUsed: classResourcesUsed,
                  );
                }
              },
          onUpdateInventory:
              ({
                List<Map<String, Object>>? inventory,
                Map<String, int>? currency,
              }) {
                return widget.controller.updateInventoryAndCurrency(
                  characterId: character.id,
                  inventory: inventory,
                  currency: currency,
                );
              },
          onEdit: () {
            Navigator.of(context).pop();
            _openEditPage(character);
          },
        ),
      ),
    );
  }

  Future<void> _openEditPage(CharacterSheet character) async {
    final messenger = ScaffoldMessenger.of(context);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => CharacterEditorPage(
          initialCharacter: character,
          onSubmit: (draft) async {
            final updated = character.copyWith(
              name: draft.name,
              level: draft.level,
              classSummary: emptyToNull(draft.classSummary) ?? character.classSummary,
              raceSummary: emptyToNull(draft.raceSummary) ?? character.raceSummary,
              currentHp: draft.currentHp,
              maxHp: draft.maxHp,
              armorClass: draft.armorClass,
              speed: draft.speed,
              initiativeBonus: draft.initiativeBonus,
              abilities: draft.abilities,
              saves: draft.saves,
              skills: draft.skills,
              inventory: draft.inventory,
              currency: draft.currency,
              notes: draft.notes,
              data: draft.data,
            );
            final success = await widget.controller.updateCharacter(updated);
            if (mounted) {
              messenger.showSnackBar(
                SnackBar(content: Text(success ? '角色已保存' : '保存失败')),
              );
            }
            return success;
          },
        ),
      ),
    );
  }

  Future<void> _showBindDialog(CharacterSheet character) async {
    if (widget.campaignController == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无可绑定战役')),
      );
      return;
    }
    if (widget.campaignController!.campaigns.isEmpty) {
      await widget.campaignController!.loadCampaigns();
    }
    if (!mounted) return;

    final campaigns = widget.campaignController!.campaigns;
    if (campaigns.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('暂无可绑定战役')));
      return;
    }

    String selectedId = campaigns.first.id;
    final messenger = ScaffoldMessenger.of(context);
    final campaignId = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('绑定战役'),
              content: DropdownButtonFormField<String>(
                initialValue: selectedId,
                decoration: const InputDecoration(
                  labelText: '战役',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final campaign in campaigns)
                    DropdownMenuItem(
                      value: campaign.id,
                      child: Text(campaign.name),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedId = value);
                  }
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(selectedId),
                  child: const Text('绑定'),
                ),
              ],
            );
          },
        );
      },
    );

    if (campaignId == null) return;
    // ignore: deprecated_member_use_from_same_package
    final success = await widget.controller.bindCharacterToCampaign(
      characterId: character.id,
      campaignId: campaignId,
    );
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(success ? '角色已绑定' : '绑定失败')));
  }

  Future<void> _showContentRefsDialog(CharacterSheet character) async {
    final refs = _contentRefsFromCharacter(character);
    final spellsController = TextEditingController(
      text: refs.spells.join(', '),
    );
    final itemsController = TextEditingController(text: refs.items.join(', '));
    final featuresController = TextEditingController(
      text: refs.features.join(', '),
    );
    final messenger = ScaffoldMessenger.of(context);

    final result = await showDialog<_ContentRefs>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('内容引用'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: spellsController,
                decoration: const InputDecoration(labelText: '法术 ID'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: itemsController,
                decoration: const InputDecoration(labelText: '装备/物品 ID'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: featuresController,
                decoration: const InputDecoration(labelText: '特性/专长 ID'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(
                _ContentRefs(
                  spells: _splitRefs(spellsController.text),
                  items: _splitRefs(itemsController.text),
                  features: _splitRefs(featuresController.text),
                ),
              ),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (result == null) return;

    final success = await widget.controller.updateContentRefs(
      characterId: character.id,
      spells: result.spells,
      items: result.items,
      features: result.features,
    );
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(success ? '内容引用已保存' : '保存失败')),
    );
  }

  Future<void> _showPublishSheet(CharacterSheet character) async {
    final actorController = widget.actorController;
    if (actorController == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => PublishCharacterSheet(
        controller: actorController,
        character: character,
      ),
    );
  }

  Future<void> _adjustHp(CharacterSheet character, int delta) async {
    final success = await widget.controller.updateCharacter(
      character.copyWith(currentHp: character.currentHp + delta),
    );
    if (!mounted || success) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('HP 调整失败')));
  }
}

/// Player <-> DM 模式切换按钮。Player 模式下显示“DM 视图”，反之亦然。
class _ModeSwitchToggle extends StatelessWidget {
  const _ModeSwitchToggle({required this.modeController, required this.isDm});

  final ClientModeController modeController;
  final bool isDm;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: Key(isDm ? 'mode-switch-player' : 'mode-switch-dm'),
      tooltip: isDm ? '切换为玩家视图' : '切换为 DM 视图',
      icon: Icon(isDm ? Icons.person_outline : Icons.castle_outlined),
      onPressed: () => modeController.setMode(
        isDm ? ClientMode.player : ClientMode.dungeonMaster,
      ),
    );
  }
}

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({
    required this.character,
    required this.compact,
    required this.canPublish,
    required this.onOpen,
    required this.onEdit,
    required this.onContentRefs,
    required this.onBind,
    required this.onHpDelta,
    this.onPublish,
  });

  final CharacterSheet character;
  final bool compact;
  final bool canPublish;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onContentRefs;
  final VoidCallback onBind;
  final VoidCallback? onPublish;
  final ValueChanged<int> onHpDelta;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (character.raceSummary.isNotEmpty) character.raceSummary,
      if (character.classSummary.isNotEmpty) character.classSummary,
      'Lv.${character.level}',
    ].join(' / ');

    return Card.outlined(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            onTap: onOpen,
            dense: compact,
            visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
            leading: CircleAvatar(
              child: Text(character.name.characters.first.toUpperCase()),
            ),
            title: Text(character.name),
            subtitle: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('紧凑角色列表'),
                      Text(subtitle),
                      Text(
                        'HP ${character.currentHp}/${character.maxHp} · AC ${character.armorClass} · 先攻 ${Dnd5eRules.formatModifier(character.initiativeBonus)}',
                      ),
                    ],
                  )
                : Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(subtitle),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            Chip(
                              label: Text(
                                'HP ${character.currentHp}/${character.maxHp}',
                              ),
                            ),
                            Chip(label: Text('AC ${character.armorClass}')),
                            Chip(
                              label: Text(
                                '先攻 ${Dnd5eRules.formatModifier(character.initiativeBonus)}',
                              ),
                            ),
                            Chip(
                              label: Text(
                                '熟练 +${Dnd5eRules.proficiencyBonus(character.level)}',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
            trailing: Wrap(
              spacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton(
                  tooltip: 'HP -1',
                  onPressed: () => onHpDelta(-1),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                IconButton(
                  tooltip: 'HP +1',
                  onPressed: () => onHpDelta(1),
                  icon: const Icon(Icons.add_circle_outline),
                ),
                PopupMenuButton<_CharacterAction>(
                  tooltip: '角色操作',
                  onSelected: (action) {
                    switch (action) {
                      case _CharacterAction.edit:
                        onEdit();
                      case _CharacterAction.contentRefs:
                        onContentRefs();
                      case _CharacterAction.bind:
                        onBind();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: _CharacterAction.edit, child: Text('编辑')),
                    PopupMenuItem(
                      value: _CharacterAction.contentRefs,
                      child: Text('内容引用'),
                    ),
                    PopupMenuItem(
                      value: _CharacterAction.bind,
                      child: Text('绑定战役'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (canPublish && onPublish != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: Key('publish-character-${character.id}'),
                  onPressed: onPublish,
                  icon: const Icon(Icons.campaign_outlined),
                  label: const Text('发布到战役'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum _CharacterAction { edit, contentRefs, bind }

String? emptyToNull(String? value) {
  if (value == null || value.isEmpty) return null;
  return value;
}

class _ContentRefs {
  const _ContentRefs({
    required this.spells,
    required this.items,
    required this.features,
  });

  final List<String> spells;
  final List<String> items;
  final List<String> features;
}

_ContentRefs _contentRefsFromCharacter(CharacterSheet character) {
  final data = character.data;
  if (data is! Map) {
    return const _ContentRefs(spells: [], items: [], features: []);
  }
  final refs = data['contentRefs'];
  if (refs is! Map) {
    return const _ContentRefs(spells: [], items: [], features: []);
  }
  return _ContentRefs(
    spells: _stringList(refs['spells']),
    items: _stringList(refs['items']),
    features: _stringList(refs['features']),
  );
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value.whereType<String>().toList(growable: false);
}

List<String> _splitRefs(String value) {
  return value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}
