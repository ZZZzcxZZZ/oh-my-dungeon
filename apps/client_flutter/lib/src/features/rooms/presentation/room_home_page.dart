import 'package:flutter/material.dart';

import '../../client_mode/domain/client_mode.dart';
import '../../server_profiles/domain/server_profile.dart';
import '../data/room_api_client.dart';
import '../domain/dice_roller.dart';
import '../domain/room.dart';
import '../domain/room_roll.dart';

class RoomHomePage extends StatefulWidget {
  RoomHomePage({
    required this.profile,
    required this.room,
    required this.modeController,
    RoomClient? roomClient,
    DiceRoller? diceRoller,
    super.key,
  }) : roomClient = roomClient ?? RoomApiClient(),
       diceRoller = diceRoller ?? DiceRoller();

  final ServerProfile profile;
  final Room room;
  final ClientModeController modeController;
  final RoomClient roomClient;
  final DiceRoller diceRoller;

  @override
  State<RoomHomePage> createState() => _RoomHomePageState();
}

class _RoomHomePageState extends State<RoomHomePage> {
  var _isLoadingRolls = true;
  var _isRolling = false;
  Object? _rollLoadError;
  List<RoomRoll> _rolls = [];

  @override
  void initState() {
    super.initState();
    _loadRolls();
  }

  Future<void> _loadRolls() async {
    try {
      final rolls = await widget.roomClient.listRolls(
        apiBaseUrl: widget.profile.apiBaseUrl,
        roomId: widget.room.id,
      );
      if (!mounted) return;
      setState(() {
        _rolls = rolls;
        _rollLoadError = null;
        _isLoadingRolls = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _rollLoadError = error;
        _isLoadingRolls = false;
      });
    }
  }

  Future<void> _rollD20() async {
    if (_isRolling) return;

    final messenger = ScaffoldMessenger.of(context);
    final diceRoll = widget.diceRoller.rollD20();
    setState(() {
      _isRolling = true;
    });

    try {
      final roll = await widget.roomClient.createRoll(
        apiBaseUrl: widget.profile.apiBaseUrl,
        roomId: widget.room.id,
        notation: diceRoll.notation,
        total: diceRoll.total,
        actorName: widget.modeController.mode.label,
        actorMode: widget.modeController.mode,
      );
      if (!mounted) return;
      setState(() {
        _rolls = [roll, ..._rolls];
        _isRolling = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isRolling = false;
      });
      messenger.showSnackBar(SnackBar(content: Text('掷骰失败：$error')));
    }
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
                  onPressed: _isRolling ? null : _rollD20,
                  icon: const Icon(Icons.casino_outlined),
                  label: const Text('掷 D20'),
                ),
              ),
              const SizedBox(height: 16),
              Text('掷骰记录', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (_isLoadingRolls)
                const LinearProgressIndicator()
              else if (_rollLoadError != null)
                Text('掷骰记录加载失败：$_rollLoadError')
              else if (_rolls.isEmpty)
                const Text('暂无掷骰记录')
              else
                for (final roll in _rolls) Text(_rollLabel(roll)),
            ],
          ),
        );
      },
    );
  }
}

String _rollLabel(RoomRoll roll) {
  final label = '${roll.notation} = ${roll.total}';
  return roll.actorName.isEmpty ? label : '${roll.actorName}: $label';
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
