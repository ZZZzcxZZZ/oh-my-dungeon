import 'package:flutter/material.dart';

import '../data/server_discovery_client.dart';
import '../data/server_profile_store.dart';
import '../domain/server_profile.dart';

class ServerProfilesPage extends StatefulWidget {
  const ServerProfilesPage({
    required this.store,
    required this.discoveryClient,
    super.key,
  });

  final ServerProfileStore store;
  final ServerDiscoveryClient discoveryClient;

  @override
  State<ServerProfilesPage> createState() => _ServerProfilesPageState();
}

class _ServerProfilesPageState extends State<ServerProfilesPage> {
  late Future<List<ServerProfile>> _profilesFuture;

  @override
  void initState() {
    super.initState();
    _profilesFuture = widget.store.listProfiles();
  }

  Future<void> _showAddServerDialog() async {
    final controller = TextEditingController(text: 'http://localhost:3000');
    final messenger = ScaffoldMessenger.of(context);

    final baseUrl = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('添加服务器'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: '服务器地址',
              hintText: 'https://example.com',
            ),
            keyboardType: TextInputType.url,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('测试并保存'),
            ),
          ],
        );
      },
    );

    if (baseUrl == null || baseUrl.trim().isEmpty) return;

    try {
      final metadata = await widget.discoveryClient.discover(baseUrl.trim());
      final profile = ServerProfile.fromMetadata(
        baseUrl: baseUrl.trim(),
        metadata: metadata,
      );
      await widget.store.saveProfile(profile);
      setState(() {
        _profilesFuture = widget.store.listProfiles();
      });
      messenger.showSnackBar(
        SnackBar(content: Text('已连接到 ${profile.name}')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('连接失败：$error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('D&D Table Tool'),
        actions: [
          IconButton(
            tooltip: '添加服务器',
            onPressed: _showAddServerDialog,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: FutureBuilder<List<ServerProfile>>(
        future: _profilesFuture,
        builder: (context, snapshot) {
          final profiles = snapshot.data ?? const <ServerProfile>[];
          if (profiles.isEmpty) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.dns_outlined,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '连接你的跑团服务器',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '添加自托管服务器后，就可以登录、切换 Player/DM 模式并进入战役。',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _showAddServerDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('添加服务器'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return ListView.separated(
            itemCount: profiles.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final profile = profiles[index];
              return ListTile(
                leading: const Icon(Icons.dns_outlined),
                title: Text(profile.name),
                subtitle: Text(profile.baseUrl),
                trailing: Text(profile.lastKnownVersion),
              );
            },
          );
        },
      ),
    );
  }
}
