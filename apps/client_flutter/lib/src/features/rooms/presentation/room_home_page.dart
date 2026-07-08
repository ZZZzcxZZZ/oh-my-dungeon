import 'package:flutter/material.dart';

import '../../client_mode/domain/client_mode.dart';
import '../../server_profiles/domain/server_profile.dart';
import '../domain/dice_roller.dart';
import '../domain/room.dart';

class RoomHomePage extends StatefulWidget {
  RoomHomePage({
    required this.profile,
    required this.room,
    required this.modeController,
    DiceRoller? diceRoller,
    super.key,
  }) : diceRoller = diceRoller ?? DiceRoller();

  final ServerProfile profile;
  final Room room;
  final ClientModeController modeController;
  final DiceRoller diceRoller;

  @override
  State<RoomHomePage> createState() => _RoomHomePageState();
}

class _RoomHomePageState extends State<RoomHomePage> {
  final List<DiceRoll> _rolls = [];

  void _rollD20() {
    setState(() {
      _rolls.insert(0, widget.diceRoller.rollD20());
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.modeController,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: Text(widget.room.name)),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                widget.room.name,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(widget.profile.name),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  label: Text('当前模式：${widget.modeController.mode.label}'),
                ),
              ),
              const SizedBox(height: 32),
              Text('角色与跑团工具', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: const [
                  _ToolChip(icon: Icons.badge_outlined, label: '角色卡'),
                  _ToolChip(icon: Icons.casino_outlined, label: '掷骰'),
                  _ToolChip(icon: Icons.chat_bubble_outline, label: '房间消息'),
                  _ToolChip(icon: Icons.map_outlined, label: '场景'),
                ],
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: _rollD20,
                  icon: const Icon(Icons.casino_outlined),
                  label: const Text('掷 D20'),
                ),
              ),
              const SizedBox(height: 16),
              Text('掷骰记录', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (_rolls.isEmpty)
                const Text('暂无掷骰记录')
              else
                for (final roll in _rolls) Text(roll.label),
            ],
          ),
        );
      },
    );
  }
}

class _ToolChip extends StatelessWidget {
  const _ToolChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ActionChip(avatar: Icon(icon), label: Text(label), onPressed: () {});
  }
}
