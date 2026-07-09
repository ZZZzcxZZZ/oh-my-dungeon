import 'dart:async';

import 'package:flutter/material.dart';

import '../../../features/auth/presentation/auth_controller.dart';
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
    this.socketService,
    super.key,
  });

  final ServerProfile profile;
  final AuthController authController;
  final SessionController sessionController;
  final SessionSocketService? socketService;

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
              Expanded(child: _buildTimeline(context)),
              _buildInputBar(context),
            ],
          ),
        );
      },
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
    final notationController = TextEditingController(text: '1d20');
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
    await widget.sessionController.createRoll(
      notation: notation,
      actorName: result['actorName'] ?? '玩家',
      visibility: isManager ? result['visibility'] : null,
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
    final isDm = message.isDmOnly;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Card(
          color: isDm
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
