import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_preferences/presentation/app_preferences_controller.dart';
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
    required this.appPreferencesController,
    super.key,
  });

  final AuthController authController;
  final CampaignController campaignController;
  final ContentController contentController;
  final ClientModeController modeController;
  final AppPreferencesController appPreferencesController;

  @override
  State<ContentLibraryPage> createState() => _ContentLibraryPageState();
}

class _ContentLibraryPageState extends State<ContentLibraryPage> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCampaignId;
  String? _selectedType;
  String? _bootstrappedForToken;

  @override
  void initState() {
    super.initState();
    widget.authController.addListener(_refresh);
    widget.campaignController.addListener(_refresh);
    widget.contentController.addListener(_refresh);
    widget.modeController.addListener(_refresh);
    widget.appPreferencesController.addListener(_refresh);
    _maybeBootstrap();
  }

  Future<void> _bootstrap() async {
    if (!widget.authController.isLoggedIn) return;
    await widget.campaignController.loadCampaigns();
    await widget.contentController.loadPackages();
    _ensureCampaignSelection();
    await _loadAvailableItems();
  }

  void _refresh() {
    _maybeBootstrap();
    if (mounted) setState(() {});
  }

  void _maybeBootstrap() {
    final token = widget.authController.accessToken;
    if (!widget.authController.isLoggedIn || token == null) {
      _bootstrappedForToken = null;
      return;
    }
    if (_bootstrappedForToken == token) return;
    _bootstrappedForToken = token;
    _bootstrap();
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

  Future<void> _showPrivateDraftDialog() async {
    final controller = TextEditingController();
    String? summary;
    String? localError;
    var busy = false;

    final imported = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> preview() async {
              String nextSummary;
              try {
                nextSummary = _privateDraftSummary(controller.text);
              } on FormatException catch (error) {
                setDialogState(() {
                  localError = error.message;
                  summary = null;
                });
                return;
              }

              setDialogState(() {
                busy = true;
                localError = null;
                summary = nextSummary;
              });
              final ok = await widget.contentController.validateImportJson(
                controller.text,
              );
              if (!context.mounted) return;
              setDialogState(() {
                busy = false;
                if (!ok) {
                  localError = widget.contentController.importErrors.join('\n');
                }
              });
            }

            Future<void> importDraft() async {
              setDialogState(() {
                busy = true;
                localError = null;
              });
              final ok = await widget.contentController.importJson(
                controller.text,
              );
              if (!context.mounted) return;
              setDialogState(() => busy = false);
              if (ok) Navigator.of(context).pop(true);
            }

            return AlertDialog(
              title: const Text('导入私有草稿'),
              content: SizedBox(
                width: 620,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '粘贴 private-imports 中的 *.content.private.json 草稿。私有草稿只会导入到你连接的服务器，不会提交到开源仓库。',
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('private-draft-json'),
                        controller: controller,
                        minLines: 10,
                        maxLines: 16,
                        decoration: const InputDecoration(
                          labelText: '私有草稿 JSON',
                          border: OutlineInputBorder(),
                        ),
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                      if (summary != null) ...[
                        const SizedBox(height: 12),
                        InputChip(
                          avatar: const Icon(Icons.lock_outline),
                          label: Text(summary!),
                        ),
                      ],
                      if (localError != null && localError!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          localError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: busy
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: busy ? null : preview,
                  child: const Text('预览'),
                ),
                FilledButton(
                  onPressed: busy ? null : importDraft,
                  child: const Text('导入到我的服务器'),
                ),
              ],
            );
          },
        );
      },
    );

    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    if (imported == true) {
      await _loadAvailableItems();
    }
  }

  Future<void> _showCreateItemDialog() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final sourceController = TextEditingController(text: 'Homebrew');
    final spellLevelController = TextEditingController();
    final spellSchoolController = TextEditingController();
    final spellCastingTimeController = TextEditingController();
    final equipmentCategoryController = TextEditingController();
    final equipmentPriceController = TextEditingController();
    final equipmentWeightController = TextEditingController();
    final speciesSizeController = TextEditingController();
    final speciesAbilityController = TextEditingController();
    final classHitDieController = TextEditingController();
    final classPrimaryAbilityController = TextEditingController();
    final backgroundAbilityController = TextEditingController();
    final backgroundFeatController = TextEditingController();
    final featCategoryController = TextEditingController();
    final featPrerequisiteController = TextEditingController();
    var selectedType = 'spell';
    var spellRitual = false;
    final messenger = ScaffoldMessenger.of(context);

    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('新增资料'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownMenu<String>(
                        label: const Text('类型'),
                        initialSelection: selectedType,
                        expandedInsets: EdgeInsets.zero,
                        dropdownMenuEntries: const [
                          DropdownMenuEntry(value: 'spell', label: '法术'),
                          DropdownMenuEntry(value: 'item', label: '物品'),
                          DropdownMenuEntry(value: 'equipment', label: '装备'),
                          DropdownMenuEntry(value: 'species', label: '种族'),
                          DropdownMenuEntry(value: 'class', label: '职业'),
                          DropdownMenuEntry(value: 'background', label: '背景'),
                          DropdownMenuEntry(value: 'feat', label: '专长'),
                        ],
                        onSelected: (value) {
                          if (value == null) return;
                          setDialogState(() => selectedType = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      _ContentTypeFields(
                        selectedType: selectedType,
                        spellLevelController: spellLevelController,
                        spellSchoolController: spellSchoolController,
                        spellCastingTimeController: spellCastingTimeController,
                        spellRitual: spellRitual,
                        onSpellRitualChanged: (value) =>
                            setDialogState(() => spellRitual = value),
                        equipmentCategoryController:
                            equipmentCategoryController,
                        equipmentPriceController: equipmentPriceController,
                        equipmentWeightController: equipmentWeightController,
                        speciesSizeController: speciesSizeController,
                        speciesAbilityController: speciesAbilityController,
                        classHitDieController: classHitDieController,
                        classPrimaryAbilityController:
                            classPrimaryAbilityController,
                        backgroundAbilityController:
                            backgroundAbilityController,
                        backgroundFeatController: backgroundFeatController,
                        featCategoryController: featCategoryController,
                        featPrerequisiteController: featPrerequisiteController,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('content-item-name'),
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: '名称',
                          border: OutlineInputBorder(),
                        ),
                        autofocus: true,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('content-item-description'),
                        controller: descriptionController,
                        decoration: const InputDecoration(
                          labelText: '说明',
                          border: OutlineInputBorder(),
                        ),
                        minLines: 3,
                        maxLines: 6,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('content-item-source'),
                        controller: sourceController,
                        decoration: const InputDecoration(
                          labelText: '来源',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('请填写名称')),
                      );
                      return;
                    }
                    final ok = await widget.contentController.importSingleItem(
                      packageName: '自定义资料',
                      type: selectedType,
                      name: nameController.text,
                      description: descriptionController.text,
                      sourceLabel: sourceController.text,
                      structured: _buildStructuredFields(
                        type: selectedType,
                        spellLevelController: spellLevelController,
                        spellSchoolController: spellSchoolController,
                        spellCastingTimeController: spellCastingTimeController,
                        spellRitual: spellRitual,
                        equipmentCategoryController:
                            equipmentCategoryController,
                        equipmentPriceController: equipmentPriceController,
                        equipmentWeightController: equipmentWeightController,
                        speciesSizeController: speciesSizeController,
                        speciesAbilityController: speciesAbilityController,
                        classHitDieController: classHitDieController,
                        classPrimaryAbilityController:
                            classPrimaryAbilityController,
                        backgroundAbilityController:
                            backgroundAbilityController,
                        backgroundFeatController: backgroundFeatController,
                        featCategoryController: featCategoryController,
                        featPrerequisiteController: featPrerequisiteController,
                      ),
                      tags: _buildTags(
                        type: selectedType,
                        spellRitual: spellRitual,
                        featCategoryController: featCategoryController,
                        equipmentCategoryController:
                            equipmentCategoryController,
                      ),
                    );
                    if (ok && context.mounted) {
                      Navigator.of(context).pop(true);
                    }
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );

    if (created == true) {
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
    widget.appPreferencesController.removeListener(_refresh);
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
    final compact = widget.appPreferencesController.preferences.compactLists;

    return Scaffold(
      appBar: AppBar(
        title: Text(isDm ? '内容库' : '资料库'),
        actions: [
          if (isDm)
            IconButton(
              tooltip: '新增资料',
              onPressed: _showCreateItemDialog,
              icon: const Icon(Icons.add_circle_outline),
            ),
          if (isDm)
            IconButton(
              tooltip: '导入内容包',
              onPressed: _showImportDialog,
              icon: const Icon(Icons.upload_file_outlined),
            ),
          if (isDm)
            IconButton(
              tooltip: '导入私有草稿',
              onPressed: _showPrivateDraftDialog,
              icon: const Icon(Icons.lock_outline),
            ),
          IconButton(
            tooltip: '刷新资料库',
            onPressed: _bootstrap,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(compact ? 12 : 16),
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
              ButtonSegment(value: 'equipment', label: Text('装备')),
              ButtonSegment(value: 'species', label: Text('种族')),
              ButtonSegment(value: 'class', label: Text('职业')),
              ButtonSegment(value: 'background', label: Text('背景')),
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
                  dense: compact,
                  visualDensity: compact
                      ? VisualDensity.compact
                      : VisualDensity.standard,
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
                dense: compact,
                visualDensity: compact
                    ? VisualDensity.compact
                    : VisualDensity.standard,
                leading: const Icon(Icons.menu_book_outlined),
                title: Text(item.name),
                subtitle: compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('紧凑资料列表'),
                          Text(
                            '${_typeLabel(item.type)} · ${item.sourceLabel}',
                          ),
                        ],
                      )
                    : Text('${_typeLabel(item.type)} · ${item.sourceLabel}'),
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

class _ContentTypeFields extends StatelessWidget {
  const _ContentTypeFields({
    required this.selectedType,
    required this.spellLevelController,
    required this.spellSchoolController,
    required this.spellCastingTimeController,
    required this.spellRitual,
    required this.onSpellRitualChanged,
    required this.equipmentCategoryController,
    required this.equipmentPriceController,
    required this.equipmentWeightController,
    required this.speciesSizeController,
    required this.speciesAbilityController,
    required this.classHitDieController,
    required this.classPrimaryAbilityController,
    required this.backgroundAbilityController,
    required this.backgroundFeatController,
    required this.featCategoryController,
    required this.featPrerequisiteController,
  });

  final String selectedType;
  final TextEditingController spellLevelController;
  final TextEditingController spellSchoolController;
  final TextEditingController spellCastingTimeController;
  final bool spellRitual;
  final ValueChanged<bool> onSpellRitualChanged;
  final TextEditingController equipmentCategoryController;
  final TextEditingController equipmentPriceController;
  final TextEditingController equipmentWeightController;
  final TextEditingController speciesSizeController;
  final TextEditingController speciesAbilityController;
  final TextEditingController classHitDieController;
  final TextEditingController classPrimaryAbilityController;
  final TextEditingController backgroundAbilityController;
  final TextEditingController backgroundFeatController;
  final TextEditingController featCategoryController;
  final TextEditingController featPrerequisiteController;

  @override
  Widget build(BuildContext context) {
    return switch (selectedType) {
      'spell' => _FormSection(
        title: '法术字段',
        children: [
          _SmallTextField(
            key: const Key('content-spell-level'),
            controller: spellLevelController,
            labelText: '环阶',
            keyboardType: TextInputType.number,
          ),
          _SmallTextField(
            key: const Key('content-spell-school'),
            controller: spellSchoolController,
            labelText: '学派',
          ),
          _SmallTextField(
            key: const Key('content-spell-casting-time'),
            controller: spellCastingTimeController,
            labelText: '施法时间',
          ),
          FilterChip(
            label: const Text('仪式'),
            selected: spellRitual,
            onSelected: onSpellRitualChanged,
          ),
        ],
      ),
      'equipment' || 'item' => _FormSection(
        title: '装备字段',
        children: [
          _SmallTextField(
            key: const Key('content-equipment-category'),
            controller: equipmentCategoryController,
            labelText: '分类',
          ),
          _SmallTextField(
            key: const Key('content-equipment-price'),
            controller: equipmentPriceController,
            labelText: '价格',
          ),
          _SmallTextField(
            key: const Key('content-equipment-weight'),
            controller: equipmentWeightController,
            labelText: '重量',
          ),
        ],
      ),
      'species' => _FormSection(
        title: '种族字段',
        children: [
          _SmallTextField(
            key: const Key('content-species-size'),
            controller: speciesSizeController,
            labelText: '体型',
          ),
          _SmallTextField(
            key: const Key('content-species-ability'),
            controller: speciesAbilityController,
            labelText: '属性提示',
          ),
        ],
      ),
      'class' => _FormSection(
        title: '职业字段',
        children: [
          _SmallTextField(
            key: const Key('content-class-hit-die'),
            controller: classHitDieController,
            labelText: '生命骰',
          ),
          _SmallTextField(
            key: const Key('content-class-primary-ability'),
            controller: classPrimaryAbilityController,
            labelText: '关键属性',
          ),
        ],
      ),
      'background' => _FormSection(
        title: '背景字段',
        children: [
          _SmallTextField(
            key: const Key('content-background-ability'),
            controller: backgroundAbilityController,
            labelText: '属性提示',
          ),
          _SmallTextField(
            key: const Key('content-background-feat'),
            controller: backgroundFeatController,
            labelText: '推荐专长',
          ),
        ],
      ),
      'feat' => _FormSection(
        title: '专长字段',
        children: [
          _SmallTextField(
            key: const Key('content-feat-category'),
            controller: featCategoryController,
            labelText: '类别',
          ),
          _SmallTextField(
            key: const Key('content-feat-prerequisite'),
            controller: featPrerequisiteController,
            labelText: '前提条件',
          ),
        ],
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: children),
        ],
      ),
    );
  }
}

class _SmallTextField extends StatelessWidget {
  const _SmallTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String labelText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 156,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: labelText,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
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
    'equipment' => '装备',
    'species' => '种族',
    'class' => '职业',
    'background' => '背景',
    'feat' => '专长',
    'feature' => '特性',
    'monster' => '怪物',
    'condition' => '状态',
    _ => type,
  };
}

String _privateDraftSummary(String jsonText) {
  final decoded = jsonDecode(jsonText);
  if (decoded is! Map) {
    throw const FormatException('私有草稿必须是一个 JSON 对象');
  }
  final items = decoded['items'];
  if (items is! List) {
    throw const FormatException('私有草稿缺少 items 数组');
  }

  final counts = <String, int>{};
  for (final item in items) {
    if (item is! Map) continue;
    final type = '${item['type'] ?? 'unknown'}';
    counts[type] = (counts[type] ?? 0) + 1;
  }

  final parts = counts.entries.toList()
    ..sort((left, right) => left.key.compareTo(right.key));
  if (parts.isEmpty) return '${items.length} 个条目';
  return '${items.length} 个条目 · ${parts.map((entry) => '${entry.key}: ${entry.value}').join(', ')}';
}

Map<String, Object?> _buildStructuredFields({
  required String type,
  required TextEditingController spellLevelController,
  required TextEditingController spellSchoolController,
  required TextEditingController spellCastingTimeController,
  required bool spellRitual,
  required TextEditingController equipmentCategoryController,
  required TextEditingController equipmentPriceController,
  required TextEditingController equipmentWeightController,
  required TextEditingController speciesSizeController,
  required TextEditingController speciesAbilityController,
  required TextEditingController classHitDieController,
  required TextEditingController classPrimaryAbilityController,
  required TextEditingController backgroundAbilityController,
  required TextEditingController backgroundFeatController,
  required TextEditingController featCategoryController,
  required TextEditingController featPrerequisiteController,
}) {
  final structured = <String, Object?>{};
  switch (type) {
    case 'spell':
      final level = int.tryParse(spellLevelController.text.trim());
      if (level != null) structured['level'] = level;
      _putText(structured, 'school', spellSchoolController);
      _putText(structured, 'castingTime', spellCastingTimeController);
      if (spellRitual) structured['ritual'] = true;
    case 'equipment':
    case 'item':
      _putText(structured, 'category', equipmentCategoryController);
      _putText(structured, 'price', equipmentPriceController);
      _putText(structured, 'weight', equipmentWeightController);
    case 'species':
      _putText(structured, 'size', speciesSizeController);
      _putText(structured, 'abilityScoreHint', speciesAbilityController);
    case 'class':
      _putText(structured, 'hitDie', classHitDieController);
      _putText(structured, 'primaryAbility', classPrimaryAbilityController);
    case 'background':
      _putText(structured, 'abilityScoreHint', backgroundAbilityController);
      _putText(structured, 'recommendedFeat', backgroundFeatController);
    case 'feat':
      _putText(structured, 'category', featCategoryController);
      _putText(structured, 'prerequisite', featPrerequisiteController);
  }
  return structured;
}

List<String> _buildTags({
  required String type,
  required bool spellRitual,
  required TextEditingController featCategoryController,
  required TextEditingController equipmentCategoryController,
}) {
  final tags = <String>[];
  if (type == 'spell' && spellRitual) tags.add('ritual');
  if (type == 'feat') _putTag(tags, featCategoryController.text);
  if (type == 'equipment' || type == 'item') {
    _putTag(tags, equipmentCategoryController.text);
  }
  return tags;
}

void _putText(
  Map<String, Object?> target,
  String key,
  TextEditingController controller,
) {
  final value = controller.text.trim();
  if (value.isNotEmpty) target[key] = value;
}

void _putTag(List<String> target, String value) {
  final tag = value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-');
  if (tag.isNotEmpty) target.add(tag);
}
