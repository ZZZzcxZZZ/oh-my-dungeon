import 'package:flutter/material.dart';

import '../../app_preferences/presentation/app_preferences_controller.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../campaigns/presentation/campaign_controller.dart';
import '../../content/presentation/content_controller.dart';
import '../domain/character.dart';
import '../domain/dnd5e_rules.dart';
import 'character_detail_page.dart';
import 'character_controller.dart';
import 'character_editor_page.dart';

class CharactersTabPage extends StatefulWidget {
  const CharactersTabPage({
    required this.authController,
    required this.characterController,
    required this.campaignController,
    required this.contentController,
    required this.appPreferencesController,
    super.key,
  });

  final AuthController authController;
  final CharacterController characterController;
  final CampaignController campaignController;
  final ContentController contentController;
  final AppPreferencesController appPreferencesController;

  @override
  State<CharactersTabPage> createState() => _CharactersTabPageState();
}

class _CharactersTabPageState extends State<CharactersTabPage> {
  String? _loadedForToken;

  @override
  void initState() {
    super.initState();
    widget.authController.addListener(_onAuthChanged);
    _maybeLoad();
  }

  void _maybeLoad() {
    final token = widget.authController.accessToken;
    if (widget.authController.isLoggedIn &&
        token != null &&
        token != _loadedForToken) {
      _loadedForToken = token;
      widget.characterController.loadCharacters();
      widget.campaignController.loadCampaigns();
      widget.contentController.loadItems();
    }
  }

  void _onAuthChanged() {
    if (!widget.authController.isLoggedIn) {
      _loadedForToken = null;
      return;
    }
    _maybeLoad();
  }

  @override
  void dispose() {
    widget.authController.removeListener(_onAuthChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.authController,
        widget.characterController,
        widget.campaignController,
        widget.contentController,
        widget.appPreferencesController,
      ]),
      builder: (context, _) {
        if (!widget.authController.isLoggedIn) {
          return _buildLoginPrompt(context);
        }

        return Scaffold(
          appBar: AppBar(title: const Text('角色')),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'create_character',
            onPressed: _openCreatePage,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('新角色'),
          ),
          body: _buildCharacterList(context),
        );
      },
    );
  }

  Widget _buildLoginPrompt(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('角色')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.badge_outlined,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text('登录后管理角色', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                const Text(
                  '创建角色卡，之后可绑定到战役并用于跑团桌面。',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCharacterList(BuildContext context) {
    if (widget.characterController.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.characterController.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            widget.characterController.error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final characters = widget.characterController.characters;
    final compact = widget.appPreferencesController.preferences.compactLists;
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
          onOpen: () => _openDetailPage(character),
          onEdit: () => _openEditPage(character),
          onContentRefs: () => _showContentRefsDialog(character),
          onBind: () => _showBindDialog(character),
          onHpDelta: (delta) => _adjustHp(character, delta),
        );
      },
    );
  }

  Future<void> _openCreatePage() async {
    final messenger = ScaffoldMessenger.of(context);
    widget.characterController.takeLastCreatedCharacter();
    final campaignId = await _selectCampaignContentSource();
    if (!mounted) return;
    if (campaignId != null) {
      await widget.contentController.loadAvailableCampaignItems(
        campaignId: campaignId,
      );
    }
    if (!mounted) return;
    final contentItems = campaignId == null
        ? widget.contentController.items
        : widget.contentController.availableItems;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => CharacterEditorPage(
          defaultCreationMethod:
              widget.appPreferencesController.preferences.defaultCreationMethod,
          contentItems: contentItems,
          onSubmit: (draft) async {
            final success = await widget.characterController.createCharacter(
              name: draft.name,
              level: draft.level,
              classSummary: emptyToNull(draft.classSummary),
              raceSummary: emptyToNull(draft.raceSummary),
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
    if (!mounted) return;
    final createdCharacter = widget.characterController
        .takeLastCreatedCharacter();
    if (createdCharacter != null) {
      await _openDetailPage(createdCharacter);
    }
  }

  Future<String?> _selectCampaignContentSource() async {
    final campaigns = widget.campaignController.campaigns;
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
              widget.appPreferencesController.preferences.defaultCharacterTab,
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
                  await widget.characterController.updateCharacter(
                    characterId: character.id,
                    currentHp: currentHp,
                  );
                }
                if (temporaryHp != null ||
                    inspiration != null ||
                    conditions != null ||
                    deathSaveSuccesses != null ||
                    deathSaveFailures != null ||
                    spellSlotsUsed != null ||
                    classResourcesUsed != null) {
                  await widget.characterController.updateRuntimeState(
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
                return widget.characterController.updateInventoryAndCurrency(
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
            final success = await widget.characterController.updateCharacter(
              characterId: character.id,
              name: draft.name,
              level: draft.level,
              classSummary: emptyToNull(draft.classSummary),
              raceSummary: emptyToNull(draft.raceSummary),
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
    if (widget.campaignController.campaigns.isEmpty) {
      await widget.campaignController.loadCampaigns();
    }
    if (!mounted) return;

    final campaigns = widget.campaignController.campaigns;
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
    final success = await widget.characterController.bindCharacterToCampaign(
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

    final success = await widget.characterController.updateContentRefs(
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

  Future<void> _adjustHp(CharacterSheet character, int delta) async {
    final success = await widget.characterController.updateCharacter(
      characterId: character.id,
      currentHp: character.currentHp + delta,
    );
    if (!mounted || success) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('HP 调整失败')));
  }
}

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({
    required this.character,
    required this.compact,
    required this.onOpen,
    required this.onEdit,
    required this.onContentRefs,
    required this.onBind,
    required this.onHpDelta,
  });

  final CharacterSheet character;
  final bool compact;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onContentRefs;
  final VoidCallback onBind;
  final ValueChanged<int> onHpDelta;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (character.raceSummary.isNotEmpty) character.raceSummary,
      if (character.classSummary.isNotEmpty) character.classSummary,
      'Lv.${character.level}',
    ].join(' / ');

    return Card.outlined(
      child: ListTile(
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
