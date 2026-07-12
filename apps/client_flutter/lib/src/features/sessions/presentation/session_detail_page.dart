import 'dart:async';

import 'package:flutter/material.dart';

import '../../../features/app_preferences/presentation/app_preferences_controller.dart';
import '../../../features/auth/presentation/auth_controller.dart';
import '../../../features/characters/domain/character.dart';
import '../../../features/characters/domain/dnd5e_rules.dart';
import '../../../features/characters/presentation/character_controller.dart';
import '../../../features/characters/presentation/character_detail_page.dart';
import '../../../features/check_requests/domain/check_request.dart';
import '../../../features/check_requests/presentation/check_request_controller.dart';
import '../../../features/rooms/domain/dice_roller.dart' hide DiceRoll;
import '../../../features/server_profiles/domain/server_profile.dart';
import '../data/session_socket_service.dart';
import '../domain/session.dart';
import 'session_controller.dart';

/// Full-screen Session desktop: chat timeline + dice roll + members.
///
/// Connects to the realtime socket on entry and disconnects on exit. When no
/// socket service is provided, the page falls back to HTTP-only refresh.
class SessionDetailPage extends StatefulWidget {
  const SessionDetailPage({
    required this.profile,
    required this.authController,
    required this.sessionController,
    required this.checkRequestController,
    required this.characterController,
    required this.appPreferencesController,
    this.socketService,
    this.diceRoller,
    super.key,
  });

  final ServerProfile profile;
  final AuthController authController;
  final SessionController sessionController;
  final CheckRequestController checkRequestController;
  final CharacterController characterController;
  final AppPreferencesController appPreferencesController;
  final SessionSocketService? socketService;
  final DiceRoller? diceRoller;

  @override
  State<SessionDetailPage> createState() => _SessionDetailPageState();
}

class _SessionDetailPageState extends State<SessionDetailPage> {
  late final SessionSocketService _socket;
  StreamSubscription<ChatMessage>? _messageSub;
  StreamSubscription<DiceRoll>? _rollSub;
  StreamSubscription<Session>? _sessionSub;

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _requestedCheckLoad = false;

  @override
  void initState() {
    super.initState();
    _socket = widget.socketService ?? NoopSessionSocketService();
    _connectSocket();
    _messageSub = _socket.messageStream.listen((message) {
      widget.sessionController.onRemoteMessage(message);
    });
    _rollSub = _socket.rollStream.listen((roll) {
      widget.sessionController.onRemoteRoll(roll);
    });
    _sessionSub = _socket.sessionUpdatedStream.listen((session) {
      widget.sessionController.onRemoteSessionUpdate(session);
    });
  }

  Future<void> _connectSocket() async {
    final token = widget.authController.accessToken;
    final session = widget.sessionController.activeSession;
    if (token == null || session == null) return;
    try {
      await _socket.connect(
        serverOrigin: widget.profile.baseUrl,
        accessToken: token,
        sessionId: session.id,
      );
    } catch (_) {
      // Realtime is best-effort; the page still works via HTTP.
    }
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _rollSub?.cancel();
    _sessionSub?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _socket.disconnect();
    widget.sessionController.closeSession();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.authController,
        widget.sessionController,
        widget.checkRequestController,
        widget.characterController,
        widget.appPreferencesController,
      ]),
      builder: (context, _) {
        final session = widget.sessionController.activeSession;
        if (session == null) {
          if (widget.sessionController.isDetailLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return Scaffold(
            appBar: AppBar(title: const Text('场次')),
            body: Center(
              child: Text(
                widget.sessionController.detailError ?? '未找到场次',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          );
        }
        if (!_requestedCheckLoad) {
          _requestedCheckLoad = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.checkRequestController.loadCheckRequests(session.id);
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(session.name),
            actions: [
              _buildStatusChip(context, session),
              IconButton(
                icon: const Icon(Icons.people_outline),
                tooltip: '成员',
                onPressed: () => _showMembersSheet(context, session),
              ),
              if (widget.sessionController.isManager)
                _buildLifecycleAction(context, session),
            ],
          ),
          body: Column(
            children: [
              _buildCheckRequestStrip(context, session),
              Expanded(child: _buildTimeline(context)),
              _buildInputBar(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCheckRequestStrip(BuildContext context, Session session) {
    final controller = widget.checkRequestController;
    final requests = controller.requests;
    final isManager = widget.sessionController.isManager;
    if (!isManager && requests.isEmpty && !controller.isLoading) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.fact_check_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '检定请求',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (controller.isLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                if (isManager) ...[
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: () => _showCreateCheckRequestDialog(session.id),
                    icon: const Icon(Icons.add),
                    label: const Text('发起'),
                  ),
                ],
              ],
            ),
            if (controller.error != null) ...[
              const SizedBox(height: 6),
              Text(
                controller.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (requests.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 112,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: requests.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    return _CheckRequestCard(
                      request: requests[index],
                      isManager: isManager,
                      currentUserId: widget.authController.user?.id,
                      onRespond: _showRespondToCheckDialog,
                      onClose: controller.closeCheckRequest,
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, Session session) {
    final colorScheme = Theme.of(context).colorScheme;
    final (label, color) = switch (session.status) {
      'active' => ('进行中', colorScheme.primaryContainer),
      'scheduled' => ('待开始', colorScheme.surfaceContainerHighest),
      'ended' => ('已结束', colorScheme.secondaryContainer),
      _ => (session.status, colorScheme.surfaceContainerHighest),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Chip(
          label: Text(label),
          backgroundColor: color,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }

  Widget _buildLifecycleAction(BuildContext context, Session session) {
    if (session.isScheduled) {
      return IconButton(
        icon: const Icon(Icons.play_arrow),
        tooltip: '开始',
        onPressed: () => widget.sessionController.startSession(),
      );
    }
    if (session.isActive) {
      return IconButton(
        icon: const Icon(Icons.stop),
        tooltip: '结束',
        onPressed: () => widget.sessionController.endSession(),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildTimeline(BuildContext context) {
    final messages = widget.sessionController.messages;
    final rolls = widget.sessionController.rolls;
    final items = <_TimelineItem>[
      for (final m in messages) _MessageItem(m),
      for (final r in rolls) _RollItem(r),
    ]..sort((a, b) => a.sortKey.compareTo(b.sortKey));

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '还没有消息或掷骰记录\n在下方发送一条消息开始',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ),
      );
    }

    _scrollToBottom();

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item is _MessageItem) {
          return _MessageBubble(
            message: item.message,
            isMine: item.message.senderId == widget.authController.user?.id,
          );
        }
        return _RollCard(roll: (item as _RollItem).roll);
      },
    );
  }

  Widget _buildInputBar(BuildContext context) {
    final isSending = widget.sessionController.isSending;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.casino_outlined),
              tooltip: '掷骰',
              onPressed: isSending ? null : _showRollSheet,
            ),
            IconButton(
              icon: const Icon(Icons.badge_outlined),
              tooltip: '角色卡',
              onPressed: isSending ? null : _showCharacterSheetPicker,
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: '发送消息…',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                onSubmitted: isSending ? null : (_) => _sendMessage(),
                textInputAction: TextInputAction.send,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: isSending ? null : _sendMessage,
              icon: isSending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: const Text('发送'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text;
    if (content.trim().isEmpty) return;
    _messageController.clear();
    await widget.sessionController.sendMessage(content: content);
  }

  Future<void> _showRollSheet() async {
    final notationController = TextEditingController(
      text: widget.appPreferencesController.preferences.defaultDice,
    );
    String visibility = 'public';
    final isManager = widget.sessionController.isManager;
    final actorName = widget.authController.user?.username ?? '玩家';

    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('掷骰', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notationController,
                    decoration: const InputDecoration(
                      labelText: '表达式',
                      hintText: '如 2d6+3、1d20',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  if (isManager)
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'public', label: Text('公开')),
                        ButtonSegment(value: 'dm', label: Text('DM')),
                        ButtonSegment(value: 'blind', label: Text('暗骰')),
                      ],
                      selected: {visibility},
                      onSelectionChanged: (selection) {
                        setSheetState(() => visibility = selection.first);
                      },
                    ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop({
                      'notation': notationController.text.trim(),
                      'visibility': visibility,
                      'actorName': actorName,
                    }),
                    icon: const Icon(Icons.casino),
                    label: const Text('掷'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result == null) return;
    final notation = result['notation'];
    if (notation == null || notation.isEmpty) return;
    if (!mounted) return;
    if (widget.appPreferencesController.preferences.confirmBeforeRoll) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('确认掷骰'),
            content: Text('掷出 $notation？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('确认'),
              ),
            ],
          );
        },
      );
      if (confirmed != true) return;
    }
    if (!mounted) return;
    await widget.sessionController.createRoll(
      notation: notation,
      actorName: result['actorName'] ?? '玩家',
      visibility: isManager ? result['visibility'] : null,
    );
  }

  Future<void> _showCharacterSheetPicker() async {
    final selected = await showModalBottomSheet<CharacterSheet>(
      context: context,
      builder: (context) {
        final characters = widget.characterController.characters;
        if (characters.isEmpty) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.badge_outlined, size: 44),
                  const SizedBox(height: 12),
                  Text('暂无角色卡', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text(
                    '先到「角色」页创建角色，再回到场次里直接从角色卡掷骰。',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            itemCount: characters.length + 1,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                  child: Text(
                    '选择角色卡',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                );
              }
              final character = characters[index - 1];
              final subtitle = [
                if (character.raceSummary.isNotEmpty) character.raceSummary,
                if (character.classSummary.isNotEmpty) character.classSummary,
                'Lv.${character.level}',
              ].join(' / ');
              return ListTile(
                leading: CircleAvatar(
                  child: Text(character.name.characters.first),
                ),
                title: Text(character.name),
                subtitle: Text(subtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).pop(character),
              );
            },
          ),
        );
      },
    );

    if (!mounted || selected == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => CharacterDetailPage(
          character: selected,
          initialTab:
              widget.appPreferencesController.preferences.defaultCharacterTab,
          diceRoller: widget.diceRoller,
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
              }) {
                return _updateCharacterRuntime(
                  selected,
                  currentHp: currentHp,
                  temporaryHp: temporaryHp,
                  inspiration: inspiration,
                  conditions: conditions,
                  deathSaveSuccesses: deathSaveSuccesses,
                  deathSaveFailures: deathSaveFailures,
                  spellSlotsUsed: spellSlotsUsed,
                  classResourcesUsed: classResourcesUsed,
                );
              },
          onRoll: (event) {
            unawaited(_sendCharacterRoll(event));
          },
        ),
      ),
    );
  }

  Future<void> _updateCharacterRuntime(
    CharacterSheet selected, {
    int? currentHp,
    int? temporaryHp,
    bool? inspiration,
    List<String>? conditions,
    int? deathSaveSuccesses,
    int? deathSaveFailures,
    Map<String, int>? spellSlotsUsed,
    Map<String, int>? classResourcesUsed,
  }) async {
    final before = _currentCharacterSnapshot(selected);
    var success = true;

    if (currentHp != null) {
      success = await widget.characterController.updateCharacter(
        characterId: selected.id,
        currentHp: currentHp,
      );
    }

    final hasRuntimeUpdate =
        temporaryHp != null ||
        inspiration != null ||
        conditions != null ||
        deathSaveSuccesses != null ||
        deathSaveFailures != null ||
        spellSlotsUsed != null ||
        classResourcesUsed != null;
    if (hasRuntimeUpdate) {
      final runtimeSuccess = await widget.characterController
          .updateRuntimeState(
            characterId: selected.id,
            temporaryHp: temporaryHp,
            inspiration: inspiration,
            conditions: conditions,
            deathSaveSuccesses: deathSaveSuccesses,
            deathSaveFailures: deathSaveFailures,
            spellSlotsUsed: spellSlotsUsed,
            classResourcesUsed: classResourcesUsed,
          );
      success = success && runtimeSuccess;
    }

    if (!success ||
        !widget
            .appPreferencesController
            .preferences
            .logCharacterRuntimeChanges) {
      return;
    }

    final summaries = _characterRuntimeSummaries(
      before,
      currentHp: currentHp,
      temporaryHp: temporaryHp,
      inspiration: inspiration,
      conditions: conditions,
      deathSaveSuccesses: deathSaveSuccesses,
      deathSaveFailures: deathSaveFailures,
      spellSlotsUsed: spellSlotsUsed,
    );
    if (summaries.isEmpty) return;

    await widget.sessionController.sendMessage(
      content: summaries.join('\n'),
      kind: 'character_runtime',
    );
  }

  CharacterSheet _currentCharacterSnapshot(CharacterSheet fallback) {
    return widget.characterController.characters
            .where((character) => character.id == fallback.id)
            .firstOrNull ??
        fallback;
  }

  List<String> _characterRuntimeSummaries(
    CharacterSheet before, {
    int? currentHp,
    int? temporaryHp,
    bool? inspiration,
    List<String>? conditions,
    int? deathSaveSuccesses,
    int? deathSaveFailures,
    Map<String, int>? spellSlotsUsed,
  }) {
    final summaries = <String>[];
    final name = before.name;
    if (currentHp != null && currentHp != before.currentHp) {
      summaries.add(
        '$name 当前 HP ${before.currentHp}/${before.maxHp} -> '
        '$currentHp/${before.maxHp}',
      );
    }
    if (temporaryHp != null && temporaryHp != before.temporaryHp) {
      summaries.add('$name 临时 HP ${before.temporaryHp} -> $temporaryHp');
    }
    if (inspiration != null && inspiration != before.inspiration) {
      summaries.add(inspiration ? '$name 获得灵感' : '$name 消耗灵感');
    }
    if (conditions != null) {
      final beforeConditions = before.conditions.toSet();
      final afterConditions = conditions.toSet();
      final added = afterConditions.difference(beforeConditions).toList();
      final removed = beforeConditions.difference(afterConditions).toList();
      if (added.isNotEmpty) {
        summaries.add('$name 获得状态：${added.join('、')}');
      }
      if (removed.isNotEmpty) {
        summaries.add('$name 移除状态：${removed.join('、')}');
      }
    }
    final nextDeathSaveSuccesses = deathSaveSuccesses;
    final nextDeathSaveFailures = deathSaveFailures;
    if ((nextDeathSaveSuccesses != null &&
            nextDeathSaveSuccesses != before.deathSaveSuccesses) ||
        (nextDeathSaveFailures != null &&
            nextDeathSaveFailures != before.deathSaveFailures)) {
      summaries.add(
        '$name 死亡豁免 ${before.deathSaveSuccesses}/'
        '${before.deathSaveFailures} -> '
        '${nextDeathSaveSuccesses ?? before.deathSaveSuccesses}/'
        '${nextDeathSaveFailures ?? before.deathSaveFailures}',
      );
    }
    if (spellSlotsUsed != null) {
      final maximums = Dnd5eRules.spellSlotMaximums(
        classSummary: before.classSummary,
        level: before.level,
      );
      for (final entry in spellSlotsUsed.entries) {
        final beforeUsed = before.spellSlotsUsed[entry.key] ?? 0;
        if (entry.value == beforeUsed) continue;
        final label = Dnd5eRules.spellLevelLabel(entry.key);
        final maximum = maximums[entry.key];
        final suffix = maximum == null ? '' : '/$maximum';
        summaries.add(
          '$name $label法术位 $beforeUsed$suffix -> ${entry.value}$suffix',
        );
      }
    }
    return summaries;
  }

  Future<void> _sendCharacterRoll(CharacterRollEvent event) async {
    await widget.sessionController.sendMessage(
      content: event.summary,
      kind: 'roll',
    );
  }

  Future<void> _showCreateCheckRequestDialog(String sessionId) async {
    final labelController = TextEditingController(text: 'Perception');
    final dcController = TextEditingController(text: '15');
    String dcVisibility = 'public';

    final result = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('发起检定'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: labelController,
                    decoration: const InputDecoration(labelText: '名称'),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: dcController,
                    decoration: const InputDecoration(labelText: 'DC'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'public', label: Text('公开 DC')),
                      ButtonSegment(value: 'hidden', label: Text('隐藏 DC')),
                    ],
                    selected: {dcVisibility},
                    onSelectionChanged: (selection) {
                      setDialogState(() => dcVisibility = selection.single);
                    },
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
                    'label': labelController.text.trim(),
                    'dc': int.tryParse(dcController.text.trim()),
                    'dcVisibility': dcVisibility,
                  }),
                  child: const Text('发起'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;
    final label = result['label'] as String?;
    if (label == null || label.isEmpty) return;

    await widget.checkRequestController.createCheckRequest(
      sessionId: sessionId,
      label: label,
      checkType: 'skill',
      skill: label.toLowerCase(),
      dc: result['dc'] as int?,
      dcVisibility: result['dcVisibility'] as String?,
      targetMode: 'all',
    );
  }

  Future<void> _showRespondToCheckDialog(CheckRequest request) async {
    final modifierController = TextEditingController(text: '0');
    final actorName = widget.authController.user?.username ?? '玩家';

    final modifier = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('响应 ${request.label}'),
          content: TextField(
            controller: modifierController,
            decoration: const InputDecoration(labelText: '修正值'),
            keyboardType: TextInputType.number,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(
                context,
              ).pop(int.tryParse(modifierController.text.trim()) ?? 0),
              child: const Text('掷骰'),
            ),
          ],
        );
      },
    );

    if (modifier == null) return;
    await widget.checkRequestController.respondToCheckRequest(
      requestId: request.id,
      actorName: actorName,
      modifier: modifier,
    );
  }

  void _showMembersSheet(BuildContext context, Session session) {
    final members = session.members;
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('成员', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                if (members.isEmpty)
                  const Text('暂无成员')
                else
                  for (final member in members)
                    ListTile(
                      leading: Icon(
                        member.isManager
                            ? Icons.shield_outlined
                            : Icons.person_outline,
                      ),
                      title: Text(member.userId),
                      subtitle: Text('角色：${_roleLabel(member.role)}'),
                      dense: true,
                    ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _roleLabel(String role) {
    return switch (role) {
      'owner' => '主持人',
      'dm' => 'DM',
      'player' => '玩家',
      _ => role,
    };
  }
}

class _CheckRequestCard extends StatelessWidget {
  const _CheckRequestCard({
    required this.request,
    required this.isManager,
    required this.currentUserId,
    required this.onRespond,
    required this.onClose,
  });

  final CheckRequest request;
  final bool isManager;
  final String? currentUserId;
  final ValueChanged<CheckRequest> onRespond;
  final ValueChanged<String> onClose;

  @override
  Widget build(BuildContext context) {
    final myResponse = request.responses
        .where((response) => response.responderId == currentUserId)
        .firstOrNull;
    final isOpen = request.status == 'open';

    return SizedBox(
      width: 260,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      request.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Chip(
                    label: Text(isOpen ? '进行中' : '已关闭'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              Text(
                request.dc == null ? 'DC 隐藏' : 'DC ${request.dc}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              if (isManager)
                Row(
                  children: [
                    Expanded(child: Text('已提交 ${request.responses.length}')),
                    TextButton(
                      onPressed: isOpen ? () => onClose(request.id) : null,
                      child: const Text('关闭'),
                    ),
                  ],
                )
              else if (myResponse != null)
                Text('结果 ${myResponse.total} · ${myResponse.result}')
              else
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: isOpen ? () => onRespond(request) : null,
                    child: const Text('响应'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

sealed class _TimelineItem {
  const _TimelineItem(this.sortKey);
  final String sortKey;
}

class _MessageItem extends _TimelineItem {
  _MessageItem(this.message) : super(message.createdAt);
  final ChatMessage message;
}

class _RollItem extends _TimelineItem {
  _RollItem(this.roll) : super(roll.createdAt);
  final DiceRoll roll;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final ChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Text(
            message.content,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    if (message.isCharacterRuntime) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.82,
            ),
            child: Card.outlined(
              color: colorScheme.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.monitor_heart_outlined,
                      size: 18,
                      color: colorScheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '角色状态',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: colorScheme.onTertiaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            message.content,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: colorScheme.onTertiaryContainer,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final isDm = message.isDmOnly;
    final isRoll = message.isRoll;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Card(
          color: isRoll
              ? colorScheme.secondaryContainer
              : isDm
              ? colorScheme.tertiaryContainer
              : isMine
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isMine)
                  Text(
                    message.senderId,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (isDm)
                  Text(
                    'DM',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onTertiaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (isRoll) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.casino_outlined,
                        size: 16,
                        color: colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '角色卡掷骰',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                Text(message.content),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RollCard extends StatelessWidget {
  const _RollCard({required this.roll});

  final DiceRoll roll;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Card(
        color: roll.isDmOnly
            ? colorScheme.tertiaryContainer
            : colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.casino, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${roll.actorName} · ${roll.notation}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (roll.components.isNotEmpty)
                      Text(
                        roll.components
                            .map(
                              (c) => '${c.notation}: [${c.results.join(', ')}]',
                            )
                            .join('  '),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '${roll.total}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (roll.isDmOnly || roll.isBlind)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Chip(
                    label: Text(roll.isBlind ? '暗骰' : 'DM'),
                    labelStyle: Theme.of(context).textTheme.labelSmall,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
