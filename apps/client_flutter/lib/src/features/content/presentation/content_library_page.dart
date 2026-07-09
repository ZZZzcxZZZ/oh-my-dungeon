import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth/presentation/auth_controller.dart';
import '../../campaigns/presentation/campaign_controller.dart';
import '../../client_mode/domain/client_mode.dart';
import 'content_controller.dart';

class ContentLibraryPage extends StatefulWidget {
  const ContentLibraryPage({
    required this.authController,
    required this.campaignController,
    required this.contentController,
    required this.modeController,
    super.key,
  });

  final AuthController authController;
  final CampaignController campaignController;
  final ContentController contentController;
  final ClientModeController modeController;

  @override
  State<ContentLibraryPage> createState() => _ContentLibraryPageState();
}

class _ContentLibraryPageState extends State<ContentLibraryPage> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCampaignId;
  String? _selectedType;

  @override
  void initState() {
    super.initState();
    widget.authController.addListener(_refresh);
    widget.campaignController.addListener(_refresh);
    widget.contentController.addListener(_refresh);
    widget.modeController.addListener(_refresh);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (!widget.authController.isLoggedIn) return;
    await widget.campaignController.loadCampaigns();
    await widget.contentController.loadPackages();
    _ensureCampaignSelection();
    await _loadAvailableItems();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _ensureCampaignSelection() {
    final campaigns = widget.campaignController.campaigns;
    if (_selectedCampaignId != null &&
        campaigns.any((campaign) => campaign.id == _selectedCampaignId)) {
      return;
    }
    _selectedCampaignId = campaigns.isEmpty ? null : campaigns.first.id;
  }

  Future<void> _loadAvailableItems() async {
    _ensureCampaignSelection();
    final campaignId = _selectedCampaignId;
    if (campaignId == null) return;

    await widget.contentController.loadAvailableCampaignItems(
      campaignId: campaignId,
      type: _selectedType,
      query: _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim(),
    );
  }

  Future<void> _showImportDialog() async {
    final controller = TextEditingController(
      text: const JsonImportExample().text,
    );
    final messenger = ScaffoldMessenger.of(context);

    final imported = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('导入内容包'),
          content: SizedBox(
            width: 560,
            child: TextField(
              controller: controller,
              minLines: 12,
              maxLines: 18,
              decoration: const InputDecoration(
                labelText: 'JSON 内容包',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                final ok = await widget.contentController.validateImportJson(
                  controller.text,
                );
                messenger.showSnackBar(
                  SnackBar(content: Text(ok ? '校验通过' : '校验未通过')),
                );
              },
              child: const Text('校验'),
            ),
            FilledButton(
              onPressed: () async {
                final ok = await widget.contentController.importJson(
                  controller.text,
                );
                if (ok && context.mounted) Navigator.of(context).pop(true);
              },
              child: const Text('导入'),
            ),
          ],
        );
      },
    );

    if (imported == true) {
      await _loadAvailableItems();
    }
  }

  Future<void> _enableSelectedPackage(String packageId) async {
    final campaignId = _selectedCampaignId;
    if (campaignId == null) return;
    await widget.contentController.setCampaignPackage(
      campaignId: campaignId,
      packageId: packageId,
      enabled: true,
    );
    await _loadAvailableItems();
  }

  Future<void> _copyPackageJson(String packageId) async {
    final messenger = ScaffoldMessenger.of(context);
    final json = await widget.contentController.exportPackageJson(packageId);
    if (!mounted) return;
    if (json == null) {
      messenger.showSnackBar(const SnackBar(content: Text('导出失败')));
      return;
    }
    await Clipboard.setData(ClipboardData(text: json));
    messenger.showSnackBar(const SnackBar(content: Text('内容包 JSON 已复制')));
  }

  @override
  void dispose() {
    widget.authController.removeListener(_refresh);
    widget.campaignController.removeListener(_refresh);
    widget.contentController.removeListener(_refresh);
    widget.modeController.removeListener(_refresh);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.authController.isLoggedIn) {
      return const _LoginPrompt();
    }

    final isDm = widget.modeController.mode == ClientMode.dungeonMaster;
    final campaigns = widget.campaignController.campaigns;
    final packages = widget.contentController.packages;
    final items = widget.contentController.availableItems;

    return Scaffold(
      appBar: AppBar(
        title: Text(isDm ? '内容库' : '资料库'),
        actions: [
          if (isDm)
            IconButton(
              tooltip: '导入内容包',
              onPressed: _showImportDialog,
              icon: const Icon(Icons.upload_file_outlined),
            ),
          IconButton(
            tooltip: '刷新资料库',
            onPressed: _bootstrap,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownMenu<String>(
            label: const Text('战役'),
            initialSelection: _selectedCampaignId,
            expandedInsets: EdgeInsets.zero,
            dropdownMenuEntries: [
              for (final campaign in campaigns)
                DropdownMenuEntry(value: campaign.id, label: campaign.name),
            ],
            onSelected: (value) async {
              _selectedCampaignId = value;
              await _loadAvailableItems();
            },
          ),
          const SizedBox(height: 12),
          SegmentedButton<String?>(
            segments: const [
              ButtonSegment(value: null, label: Text('全部')),
              ButtonSegment(value: 'spell', label: Text('法术')),
              ButtonSegment(value: 'item', label: Text('物品')),
              ButtonSegment(value: 'feat', label: Text('专长')),
              ButtonSegment(value: 'monster', label: Text('怪物')),
              ButtonSegment(value: 'condition', label: Text('状态')),
            ],
            selected: {_selectedType},
            onSelectionChanged: (selection) async {
              _selectedType = selection.single;
              await _loadAvailableItems();
            },
          ),
          const SizedBox(height: 12),
          SearchBar(
            controller: _searchController,
            hintText: '搜索资料',
            leading: const Icon(Icons.search),
            onSubmitted: (_) => _loadAvailableItems(),
          ),
          if (isDm) ...[
            const SizedBox(height: 20),
            Text('内容包', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (packages.isEmpty)
              const ListTile(
                leading: Icon(Icons.inventory_2_outlined),
                title: Text('还没有内容包'),
                subtitle: Text('导入 JSON 后可为战役启用'),
              )
            else
              for (final contentPackage in packages)
                ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: Text(contentPackage.name),
                  subtitle: Text(contentPackage.version),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      IconButton(
                        tooltip: '复制 JSON',
                        onPressed: () => _copyPackageJson(contentPackage.id),
                        icon: const Icon(Icons.copy_outlined),
                      ),
                      FilledButton.tonal(
                        onPressed: () =>
                            _enableSelectedPackage(contentPackage.id),
                        child: const Text('启用'),
                      ),
                    ],
                  ),
                ),
          ],
          const SizedBox(height: 20),
          Text('可用条目', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (widget.contentController.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (items.isEmpty)
            const ListTile(
              leading: Icon(Icons.menu_book_outlined),
              title: Text('暂无可用内容'),
              subtitle: Text('选择战役或让 DM 启用内容包'),
            )
          else
            for (final item in items)
              ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: Text(item.name),
                subtitle: Text(
                  '${_typeLabel(item.type)} · ${item.sourceLabel}',
                ),
              ),
          if (widget.contentController.importErrors.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final error in widget.contentController.importErrors)
              Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
          if (widget.contentController.error != null) ...[
            const SizedBox(height: 12),
            Text(
              widget.contentController.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}

class _LoginPrompt extends StatelessWidget {
  const _LoginPrompt();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text('登录后查看资料库', style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}

class JsonImportExample {
  const JsonImportExample();

  String get text {
    return '''{
  "name": "Basic Spells",
  "version": "1.0.0",
  "schemaVersion": 1,
  "locale": "zh-CN",
  "items": [
    {
      "type": "spell",
      "slug": "fire-bolt",
      "name": "Fire Bolt",
      "description": "A mote of fire.",
      "structured": { "level": 0 },
      "tags": ["cantrip"],
      "sourceLabel": "SRD"
    }
  ]
}''';
  }
}

String _typeLabel(String type) {
  return switch (type) {
    'spell' => '法术',
    'item' => '物品',
    'feat' => '专长',
    'feature' => '特性',
    'monster' => '怪物',
    'condition' => '状态',
    _ => type,
  };
}
