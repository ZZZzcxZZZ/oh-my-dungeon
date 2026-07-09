import 'package:flutter/material.dart';

import '../../auth/presentation/auth_controller.dart';
import '../../campaigns/presentation/campaign_controller.dart';
import '../domain/character.dart';
import 'character_controller.dart';

class CharactersTabPage extends StatefulWidget {
  const CharactersTabPage({
    required this.authController,
    required this.characterController,
    required this.campaignController,
    super.key,
  });

  final AuthController authController;
  final CharacterController characterController;
  final CampaignController campaignController;

  @override
  State<CharactersTabPage> createState() => _CharactersTabPageState();
}

class _CharactersTabPageState extends State<CharactersTabPage> {
  @override
  void initState() {
    super.initState();
    _maybeLoad();
  }

  void _maybeLoad() {
    if (widget.authController.isLoggedIn) {
      widget.characterController.loadCharacters();
      widget.campaignController.loadCampaigns();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.authController,
        widget.characterController,
        widget.campaignController,
      ]),
      builder: (context, _) {
        if (!widget.authController.isLoggedIn) {
          return _buildLoginPrompt(context);
        }

        return Scaffold(
          appBar: AppBar(title: const Text('角色')),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'create_character',
            onPressed: _showCreateDialog,
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
                Text(
                  '登录后管理角色',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
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
    if (characters.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '还没有角色\n点击右下角创建第一张角色卡',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: characters.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final character = characters[index];
        return _CharacterCard(
          character: character,
          onEdit: () => _showEditDialog(character),
          onBind: () => _showBindDialog(character),
          onHpDelta: (delta) => _adjustHp(character, delta),
        );
      },
    );
  }

  Future<void> _showCreateDialog() async {
    final nameController = TextEditingController();
    final classController = TextEditingController();
    final raceController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('新角色'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '名称'),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: classController,
                decoration: const InputDecoration(labelText: '职业'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: raceController,
                decoration: const InputDecoration(labelText: '种族'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop({
                'name': nameController.text.trim(),
                'classSummary': classController.text.trim(),
                'raceSummary': raceController.text.trim(),
              }),
              child: const Text('创建'),
            ),
          ],
        );
      },
    );

    if (result == null || result['name']!.isEmpty) return;

    final success = await widget.characterController.createCharacter(
      name: result['name']!,
      classSummary: emptyToNull(result['classSummary']),
      raceSummary: emptyToNull(result['raceSummary']),
    );

    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(success ? '角色已创建' : '创建失败')),
    );
  }

  Future<void> _showEditDialog(CharacterSheet character) async {
    final nameController = TextEditingController(text: character.name);
    final classController = TextEditingController(text: character.classSummary);
    final raceController = TextEditingController(text: character.raceSummary);
    final levelController = TextEditingController(text: '${character.level}');
    final hpController = TextEditingController(text: '${character.currentHp}');
    final maxHpController = TextEditingController(text: '${character.maxHp}');
    final acController = TextEditingController(text: '${character.armorClass}');
    final messenger = ScaffoldMessenger.of(context);

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('编辑角色'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '名称'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: levelController,
                        decoration: const InputDecoration(labelText: '等级'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: acController,
                        decoration: const InputDecoration(labelText: 'AC'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: hpController,
                        decoration: const InputDecoration(labelText: 'HP'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: maxHpController,
                        decoration: const InputDecoration(labelText: 'HP 上限'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: classController,
                  decoration: const InputDecoration(labelText: '职业'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: raceController,
                  decoration: const InputDecoration(labelText: '种族'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop({
                'name': nameController.text.trim(),
                'classSummary': classController.text.trim(),
                'raceSummary': raceController.text.trim(),
                'level': levelController.text.trim(),
                'currentHp': hpController.text.trim(),
                'maxHp': maxHpController.text.trim(),
                'armorClass': acController.text.trim(),
              }),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (result == null || result['name']!.isEmpty) return;

    final success = await widget.characterController.updateCharacter(
      characterId: character.id,
      name: result['name'],
      classSummary: emptyToNull(result['classSummary']),
      raceSummary: emptyToNull(result['raceSummary']),
      level: int.tryParse(result['level'] ?? ''),
      currentHp: int.tryParse(result['currentHp'] ?? ''),
      maxHp: int.tryParse(result['maxHp'] ?? ''),
      armorClass: int.tryParse(result['armorClass'] ?? ''),
    );

    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(success ? '角色已保存' : '保存失败')),
    );
  }

  Future<void> _showBindDialog(CharacterSheet character) async {
    if (widget.campaignController.campaigns.isEmpty) {
      await widget.campaignController.loadCampaigns();
    }
    if (!mounted) return;

    final campaigns = widget.campaignController.campaigns;
    if (campaigns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无可绑定战役')),
      );
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
    messenger.showSnackBar(
      SnackBar(content: Text(success ? '角色已绑定' : '绑定失败')),
    );
  }

  Future<void> _adjustHp(CharacterSheet character, int delta) async {
    final success = await widget.characterController.updateCharacter(
      characterId: character.id,
      currentHp: character.currentHp + delta,
    );
    if (!mounted || success) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('HP 调整失败')),
    );
  }
}

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({
    required this.character,
    required this.onEdit,
    required this.onBind,
    required this.onHpDelta,
  });

  final CharacterSheet character;
  final VoidCallback onEdit;
  final VoidCallback onBind;
  final ValueChanged<int> onHpDelta;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (character.raceSummary.isNotEmpty) character.raceSummary,
      if (character.classSummary.isNotEmpty) character.classSummary,
      'Lv.${character.level}',
    ].join(' / ');

    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person_outline)),
        title: Text(character.name),
        subtitle: Text(subtitle),
        trailing: Wrap(
          spacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Chip(label: Text('HP ${character.currentHp}/${character.maxHp}')),
            Chip(label: Text('AC ${character.armorClass}')),
            IconButton(
              tooltip: 'HP -1',
              onPressed: () => onHpDelta(-1),
              icon: const Icon(Icons.remove),
            ),
            IconButton(
              tooltip: 'HP +1',
              onPressed: () => onHpDelta(1),
              icon: const Icon(Icons.add),
            ),
            PopupMenuButton<_CharacterAction>(
              tooltip: '角色操作',
              onSelected: (action) {
                switch (action) {
                  case _CharacterAction.edit:
                    onEdit();
                  case _CharacterAction.bind:
                    onBind();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _CharacterAction.edit,
                  child: Text('编辑'),
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

enum _CharacterAction { edit, bind }

String? emptyToNull(String? value) {
  if (value == null || value.isEmpty) return null;
  return value;
}
