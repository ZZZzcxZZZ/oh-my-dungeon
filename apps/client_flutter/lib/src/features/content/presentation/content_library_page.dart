import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_preferences/presentation/app_preferences_controller.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../campaigns/presentation/campaign_controller.dart';
import '../../client_mode/domain/client_mode.dart';
import '../domain/content.dart';
import 'content_controller.dart';
import 'widgets/content_class_feature_list.dart';

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
  String? _selectedTypeFilter = 'all';
  String? _selectedSpellSchool;
  int? _selectedSpellLevel;
  String? _selectedSpellClass;
  String? _selectedFeatCategory;
  bool _favoriteOnly = false;
  ContentItem? _wideSelectedItem;
  ContentItemDetail? _wideSelectedItemDetail;
  bool _isWideItemLoading = false;
  final Set<String> _enabledPackageIds = {};
  String? _bootstrappedForToken;

  /// 虚拟类型过滤器：把"武器/护甲/冒险装备"等细分类型映射到服务端 type + 客户端 category 过滤。
  static const _typeFilters = <_TypeFilterEntry>[
    _TypeFilterEntry(value: 'all', label: '全部'),
    _TypeFilterEntry(value: 'spell', label: '法术', serverType: 'spell'),
    _TypeFilterEntry(
      value: 'weapon',
      label: '武器',
      serverType: 'equipment',
      categoryMatch: _matchWeapon,
    ),
    _TypeFilterEntry(
      value: 'armor',
      label: '护甲',
      serverType: 'equipment',
      categoryMatch: _matchArmor,
    ),
    _TypeFilterEntry(value: 'gear', label: '冒险装备', serverType: 'item'),
    _TypeFilterEntry(value: 'species', label: '种族', serverType: 'species'),
    _TypeFilterEntry(value: 'class', label: '职业', serverType: 'class'),
    _TypeFilterEntry(
      value: 'background',
      label: '背景',
      serverType: 'background',
    ),
    _TypeFilterEntry(value: 'feat', label: '专长', serverType: 'feat'),
    _TypeFilterEntry(value: 'monster', label: '怪物', serverType: 'monster'),
    _TypeFilterEntry(value: 'condition', label: '状态', serverType: 'condition'),
  ];

  static bool _matchWeapon(Map structured) {
    final category = '${structured['category'] ?? ''}';
    return category.contains('武器');
  }

  static bool _matchArmor(Map structured) {
    final category = '${structured['category'] ?? ''}';
    return category.contains('甲') || category.contains('盾');
  }

  _TypeFilterEntry get _activeTypeFilter {
    return _typeFilters.firstWhere(
      (e) => e.value == _selectedTypeFilter,
      orElse: () => _typeFilters.first,
    );
  }

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
    await _loadItems();
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

  Future<void> _loadItems() async {
    _ensureCampaignSelection();
    final campaignId = _selectedCampaignId;
    final query = _searchController.text.trim().isEmpty
        ? null
        : _searchController.text.trim();
    final serverType = _activeTypeFilter.serverType;

    if (campaignId != null) {
      await widget.contentController.loadAvailableCampaignItems(
        campaignId: campaignId,
        type: serverType,
        query: query,
        favoriteOnly: _favoriteOnly,
      );
    } else {
      await widget.contentController.loadItems(type: serverType, query: query);
    }
  }

  Future<void> _showImportDialog() async {
    _ensureCampaignSelection();
    final campaignId = _selectedCampaignId;
    if (campaignId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先创建或加入一个战役')));
      return;
    }
    final controller = TextEditingController(
      text: const JsonImportExample().text,
    );
    final messenger = ScaffoldMessenger.of(context);

    final imported = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('导入战役资料包'),
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
                final ok = await widget.contentController.importCampaignJson(
                  campaignId: campaignId,
                  jsonText: controller.text,
                  dryRun: true,
                );
                messenger.showSnackBar(
                  SnackBar(content: Text(ok ? '校验通过' : '校验未通过')),
                );
              },
              child: const Text('校验'),
            ),
            FilledButton(
              onPressed: () async {
                final ok = await widget.contentController.importCampaignJson(
                  campaignId: campaignId,
                  jsonText: controller.text,
                );
                if (ok && context.mounted) Navigator.of(context).pop(true);
              },
              child: const Text('导入到当前战役'),
            ),
          ],
        );
      },
    );

    if (imported == true) {
      await _loadItems();
    }
  }

  Future<void> _showPrivateDraftDialog() async {
    _ensureCampaignSelection();
    final campaignId = _selectedCampaignId;
    if (campaignId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先选择要导入资料包的战役')));
      return;
    }
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
              final ok = await widget.contentController.importCampaignJson(
                campaignId: campaignId,
                jsonText: controller.text,
                dryRun: true,
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
              final ok = await widget.contentController.importCampaignJson(
                campaignId: campaignId,
                jsonText: controller.text,
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
      await _loadItems();
    }
  }

  Future<void> _showCreateItemDialog() async {
    _ensureCampaignSelection();
    final campaignId = _selectedCampaignId;
    if (campaignId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先创建或加入一个战役')));
      return;
    }
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
                    final ok = await widget.contentController
                        .importCampaignSingleItem(
                          campaignId: campaignId,
                          packageName: '自定义资料',
                          type: selectedType,
                          name: nameController.text,
                          description: descriptionController.text,
                          sourceLabel: sourceController.text,
                          structured: _buildStructuredFields(
                            type: selectedType,
                            spellLevelController: spellLevelController,
                            spellSchoolController: spellSchoolController,
                            spellCastingTimeController:
                                spellCastingTimeController,
                            spellRitual: spellRitual,
                            equipmentCategoryController:
                                equipmentCategoryController,
                            equipmentPriceController: equipmentPriceController,
                            equipmentWeightController:
                                equipmentWeightController,
                            speciesSizeController: speciesSizeController,
                            speciesAbilityController: speciesAbilityController,
                            classHitDieController: classHitDieController,
                            classPrimaryAbilityController:
                                classPrimaryAbilityController,
                            backgroundAbilityController:
                                backgroundAbilityController,
                            backgroundFeatController: backgroundFeatController,
                            featCategoryController: featCategoryController,
                            featPrerequisiteController:
                                featPrerequisiteController,
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
      await _loadItems();
    }
  }

  Future<void> _setPackageEnabled(String packageId, bool enabled) async {
    final campaignId = _selectedCampaignId;
    if (campaignId == null) return;
    await widget.contentController.setCampaignPackage(
      campaignId: campaignId,
      packageId: packageId,
      enabled: enabled,
    );
    await _loadItems();
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

  List<ContentItem> get _filteredItems {
    final hasCampaign = _selectedCampaignId != null;
    final items = hasCampaign
        ? widget.contentController.availableItems
        : widget.contentController.items;
    final filter = _activeTypeFilter;
    return items.where((item) {
      // 1. 虚拟类型过滤：服务端已粗过滤 type，客户端再按 category 精筛
      if (filter.categoryMatch != null) {
        final structured = item.structured;
        if (structured is! Map) return false;
        if (!filter.categoryMatch!(structured)) return false;
      }
      // 2. 法术细分：环阶 + 学派 + 职业
      if (item.type == 'spell') {
        final structured = item.structured;
        if (structured is Map) {
          if (_selectedSpellSchool != null) {
            final school = structured['school'];
            if (school == null ||
                '$school'.toLowerCase() !=
                    _selectedSpellSchool!.toLowerCase()) {
              return false;
            }
          }
          if (_selectedSpellLevel != null) {
            final level = structured['level'];
            if (level is! num || level.toInt() != _selectedSpellLevel) {
              return false;
            }
          }
          if (_selectedSpellClass != null) {
            final classes = structured['classes'];
            if (classes is! List ||
                !classes.any(
                  (c) =>
                      '$c'.toLowerCase() == _selectedSpellClass!.toLowerCase(),
                )) {
              return false;
            }
          }
        }
      }
      // 3. 专长细分：类别
      if (item.type == 'feat' && _selectedFeatCategory != null) {
        final structured = item.structured;
        if (structured is Map) {
          final category = '${structured['category'] ?? ''}';
          if (category != _selectedFeatCategory) return false;
        }
      }
      return true;
    }).toList();
  }

  List<String> get _availableSpellSchools {
    final hasCampaign = _selectedCampaignId != null;
    final items = hasCampaign
        ? widget.contentController.availableItems
        : widget.contentController.items;
    final schools = <String>{};
    for (final item in items) {
      if (item.type != 'spell') continue;
      final structured = item.structured;
      if (structured is Map) {
        final school = structured['school'];
        if (school != null) schools.add('$school');
      }
    }
    return schools.toList()..sort();
  }

  List<String> get _availableSpellClasses {
    final hasCampaign = _selectedCampaignId != null;
    final items = hasCampaign
        ? widget.contentController.availableItems
        : widget.contentController.items;
    final classes = <String>{};
    for (final item in items) {
      if (item.type != 'spell') continue;
      final structured = item.structured;
      if (structured is Map) {
        final value = structured['classes'];
        if (value is List) {
          for (final c in value) {
            final s = '$c';
            if (s.isNotEmpty) classes.add(s);
          }
        }
      }
    }
    return classes.toList()..sort();
  }

  List<String> get _availableFeatCategories {
    final hasCampaign = _selectedCampaignId != null;
    final items = hasCampaign
        ? widget.contentController.availableItems
        : widget.contentController.items;
    final categories = <String>{};
    for (final item in items) {
      if (item.type != 'feat') continue;
      final structured = item.structured;
      if (structured is Map) {
        final category = structured['category'];
        if (category != null && '$category'.isNotEmpty) {
          categories.add('$category');
        }
      }
    }
    return categories.toList()..sort();
  }

  Future<void> _showItemDetail(ContentItem item) async {
    final campaignId = _selectedCampaignId;
    final detail = campaignId == null
        ? null
        : await widget.contentController.loadCampaignItemDetail(
            campaignId: campaignId,
            itemId: item.id,
          );
    final displayedItem = detail?.item ?? item;
    var isFavorite = detail?.isFavorite ?? false;
    final links = detail?.outgoingLinks ?? const <ContentItemLink>[];
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        return AlertDialog(
          title: Text(displayedItem.name),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 顶部类型横幅：使用 M3 surfaceContainerHigh
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Chip(
                          avatar: Icon(_typeIcon(displayedItem.type), size: 16),
                          label: Text(_typeLabel(displayedItem.type)),
                          side: BorderSide.none,
                        ),
                        if (displayedItem.sourceLabel.isNotEmpty)
                          Chip(
                            avatar: const Icon(Icons.book_outlined, size: 16),
                            label: Text(displayedItem.sourceLabel),
                            side: BorderSide.none,
                          ),
                        ..._structuredChips(displayedItem),
                      ],
                    ),
                  ),
                  // 详细内容区：基本信息 + 描述
                  ..._structuredDetailRows(displayedItem),
                  if (displayedItem.type == 'class')
                    ContentClassFeatureList(
                      item: displayedItem,
                      links: links,
                      onLinkTap: (link) {
                        Navigator.of(context).pop();
                        _showItemDetail(link.target);
                      },
                    ),
                  if (links.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('关联条目', style: theme.textTheme.titleSmall),
                    for (final link in links)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(_typeIcon(link.target.type)),
                        title: Text(link.target.name),
                        subtitle: Text(
                          link.label.isEmpty ? link.relation : link.label,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).pop();
                          _showItemDetail(link.target);
                        },
                      ),
                  ],
                  if (displayedItem.description.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      '描述',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        displayedItem.description,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            if (campaignId != null)
              IconButton(
                tooltip: isFavorite ? '取消收藏' : '收藏',
                onPressed: () async {
                  await widget.contentController.setCampaignItemFavorite(
                    campaignId: campaignId,
                    itemId: displayedItem.id,
                    favorite: !isFavorite,
                  );
                  if (context.mounted) Navigator.of(context).pop();
                  await _showItemDetail(displayedItem);
                },
                icon: Icon(
                  isFavorite ? Icons.bookmark : Icons.bookmark_outline,
                ),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _selectWideItem(ContentItem item) async {
    setState(() {
      _wideSelectedItem = item;
      _wideSelectedItemDetail = null;
      _isWideItemLoading = true;
    });
    final campaignId = _selectedCampaignId;
    final detail = campaignId == null
        ? null
        : await widget.contentController.loadCampaignItemDetail(
            campaignId: campaignId,
            itemId: item.id,
          );
    if (!mounted || _wideSelectedItem?.id != item.id) return;
    setState(() {
      _wideSelectedItemDetail = detail;
      _isWideItemLoading = false;
    });
  }

  Future<void> _toggleWideItemFavorite() async {
    final campaignId = _selectedCampaignId;
    final detail = _wideSelectedItemDetail;
    if (campaignId == null || detail == null) return;
    await widget.contentController.setCampaignItemFavorite(
      campaignId: campaignId,
      itemId: detail.item.id,
      favorite: !detail.isFavorite,
    );
    await _selectWideItem(detail.item);
  }

  Widget _buildWideDetailPane() {
    final item = _wideSelectedItemDetail?.item ?? _wideSelectedItem;
    final detail = _wideSelectedItemDetail;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    if (item == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.menu_book_outlined,
                size: 48,
                color: colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text('选择一个条目', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('在此查看规则、关联条目与职业特性。', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      );
    }
    if (_isWideItemLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final links = detail?.outgoingLinks ?? const <ContentItemLink>[];
    return Material(
      color: colorScheme.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(item.name, style: theme.textTheme.headlineSmall),
                ),
                if (detail != null)
                  IconButton(
                    tooltip: detail.isFavorite ? '取消收藏' : '收藏',
                    onPressed: _toggleWideItemFavorite,
                    icon: Icon(
                      detail.isFavorite
                          ? Icons.bookmark
                          : Icons.bookmark_outline,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Chip(
                  avatar: Icon(_typeIcon(item.type), size: 16),
                  label: Text(_typeLabel(item.type)),
                ),
                if (item.sourceLabel.isNotEmpty)
                  Chip(
                    avatar: const Icon(Icons.book_outlined, size: 16),
                    label: Text(item.sourceLabel),
                  ),
                ..._structuredChips(item),
              ],
            ),
            ..._structuredDetailRows(item),
            if (item.type == 'class')
              ContentClassFeatureList(
                item: item,
                links: links,
                onLinkTap: (link) => _selectWideItem(link.target),
              ),
            if (links.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('关联条目', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final link in links)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_typeIcon(link.target.type)),
                  title: Text(link.target.name),
                  subtitle: Text(
                    link.label.isEmpty ? link.relation : link.label,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _selectWideItem(link.target),
                ),
            ],
            if (item.description.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('描述', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              SelectableText(
                item.description,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _structuredChips(ContentItem item) {
    final structured = item.structured;
    if (structured is! Map) return const [];
    final chips = <Widget>[];
    // 统一纯文字 chip（顶部已有类型+来源两个带图标 chip 作为标识）
    Widget chip(String text) => Chip(
      label: Text(text),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );

    if (item.type == 'spell') {
      final level = structured['level'];
      if (level is num) {
        chips.add(chip(level == 0 ? '戏法' : '$level环'));
      }
      final school = structured['school'];
      if (school != null) chips.add(chip('$school'));
      if (structured['ritual'] == true) chips.add(chip('仪式'));
    } else if (item.type == 'equipment') {
      final category = structured['category'];
      if (category != null) chips.add(chip('$category'));
      final damage = structured['damage'];
      if (damage != null) chips.add(chip('伤害 $damage'));
      final ac = structured['ac'];
      if (ac != null) chips.add(chip('AC $ac'));
      final price = structured['price'];
      if (price != null) chips.add(chip('$price'));
    } else if (item.type == 'item') {
      final category = structured['category'];
      if (category != null) chips.add(chip('$category'));
      final price = structured['price'];
      if (price != null) chips.add(chip('$price'));
    } else if (item.type == 'species') {
      final size = structured['size'];
      if (size != null) chips.add(chip('$size'));
      final speed = structured['speed'];
      if (speed != null) chips.add(chip('速度 $speed'));
      final creatureType = structured['creatureType'];
      if (creatureType != null) chips.add(chip('$creatureType'));
    } else if (item.type == 'class') {
      final hitDie = structured['hitDie'];
      if (hitDie != null) chips.add(chip('生命骰 $hitDie'));
      final primaryAbility = structured['primaryAbility'];
      if (primaryAbility != null) chips.add(chip('主属性 $primaryAbility'));
    } else if (item.type == 'feat') {
      final category = structured['category'];
      if (category != null) chips.add(chip('$category'));
      final prereq = structured['prerequisite'];
      if (prereq != null) chips.add(chip('先决 $prereq'));
    }
    return chips;
  }

  List<Widget> _structuredDetailRows(ContentItem item) {
    final structured = item.structured;
    if (structured is! Map) return const [];
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // 过滤掉已经在 chips 中展示过的字段，避免重复
    final skipKeys = <String>{};
    if (item.type == 'spell') {
      skipKeys.addAll(const {'level', 'school', 'ritual'});
    } else if (item.type == 'equipment') {
      skipKeys.addAll(const {'category', 'damage', 'ac', 'price'});
    } else if (item.type == 'item') {
      skipKeys.addAll(const {'category', 'price'});
    } else if (item.type == 'species') {
      skipKeys.addAll(const {'size', 'speed', 'creatureType'});
    } else if (item.type == 'class') {
      skipKeys.add('primaryAbility');
    } else if (item.type == 'feat') {
      skipKeys.addAll(const {'category', 'prerequisite'});
    }
    // 专长只显示描述，不显示基本信息
    if (item.type == 'feat') return const [];

    final entries = structured.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final visibleEntries = entries.where((e) {
      if (e.value == null) return false;
      if (skipKeys.contains(e.key)) return false;
      String display;
      if (e.value is List) {
        display = (e.value as List).join(', ');
      } else if (e.value is Map) {
        display = e.value.toString();
      } else {
        display = '${e.value}';
      }
      return display.isNotEmpty;
    }).toList();
    if (visibleEntries.isEmpty) return const [];

    return [
      const SizedBox(height: 16),
      Text(
        '基本信息',
        style: theme.textTheme.labelLarge?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          children: [
            for (final entry in visibleEntries) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 96,
                      child: Text(
                        _structuredFieldLabel(entry.key),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(child: _renderStructuredValue(entry.value)),
                  ],
                ),
              ),
              if (entry != visibleEntries.last)
                Divider(height: 1, color: colorScheme.outlineVariant),
            ],
          ],
        ),
      ),
    ];
  }

  Widget _renderStructuredValue(Object? value) {
    if (value is List) {
      return Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          for (final v in value)
            Chip(
              label: Text('$v'),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
        ],
      );
    }
    return SelectableText('$value');
  }

  String _structuredFieldLabel(String key) {
    return switch (key) {
      'level' => '环阶',
      'levelLabel' => '环阶',
      'school' => '学派',
      'castingTime' => '施法时间',
      'range' => '射程',
      'components' => '成分',
      'duration' => '持续时间',
      'ritual' => '仪式',
      'classes' => '职业列表',
      'category' => '类别',
      'price' => '价格',
      'weight' => '重量',
      'size' => '体型',
      'speed' => '速度',
      'creatureType' => '生物类型',
      'abilityScoreHint' => '属性加成',
      'traits' => '特性',
      'hitDie' => '生命骰',
      'primaryAbility' => '主属性',
      'savingThrows' => '豁免熟练',
      'spellcastingAbility' => '施法属性',
      'armorProficiency' => '护甲熟练',
      'weaponProficiency' => '武器熟练',
      'toolProficiency' => '工具熟练',
      'skills' => '技能熟练',
      'recommendedFeat' => '推荐专长',
      'prerequisite' => '先决条件',
      'page' => '页码',
      'zhName' => '中文名',
      'enName' => '英文名',
      'outlinePath' => '目录路径',
      'damage' => '伤害',
      'versatileDamage' => '双手伤害',
      'properties' => '属性',
      'mastery' => '精通',
      'armorType' => '护甲类型',
      'weaponType' => '武器类型',
      'ac' => 'AC',
      'acBonus' => 'AC 加成',
      'strengthRequirement' => '力量要求',
      'stealthDisadvantage' => '隐匿劣势',
      _ => key,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.authController.isLoggedIn) {
      return const _LoginPrompt();
    }

    final isDm = widget.modeController.mode == ClientMode.dungeonMaster;
    final campaigns = widget.campaignController.campaigns;
    final packages = widget.contentController.packages;
    final items = _filteredItems;
    final compact = widget.appPreferencesController.preferences.compactLists;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(isDm ? '内容库' : '资料库'),
        actions: [
          if (isDm)
            MenuAnchor(
              menuChildren: [
                MenuItemButton(
                  leadingIcon: const Icon(Icons.add_circle_outline),
                  onPressed: _showCreateItemDialog,
                  child: const Text('新增战役资料'),
                ),
                MenuItemButton(
                  leadingIcon: const Icon(Icons.upload_file_outlined),
                  onPressed: _showImportDialog,
                  child: const Text('导入战役资料包'),
                ),
                MenuItemButton(
                  leadingIcon: const Icon(Icons.lock_outline),
                  onPressed: _showPrivateDraftDialog,
                  child: const Text('导入私有草稿'),
                ),
              ],
              builder: (context, controller, child) => IconButton(
                tooltip: '资料库操作',
                onPressed: () =>
                    controller.isOpen ? controller.close() : controller.open(),
                icon: const Icon(Icons.more_vert),
              ),
            ),
          IconButton(
            tooltip: '刷新资料库',
            onPressed: _bootstrap,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1000;
          final detailPaneWidth = math.min(480.0, constraints.maxWidth * 0.42);
          return Row(
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          compact ? 12 : 16,
                          compact ? 12 : 16,
                          compact ? 12 : 16,
                          8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. 顶部搜索栏
                            SearchBar(
                              controller: _searchController,
                              hintText: '搜索名称、关键字…',
                              leading: const Icon(Icons.search),
                              trailing: [
                                IconButton(
                                  tooltip: '搜索',
                                  icon: const Icon(Icons.arrow_forward),
                                  onPressed: _loadItems,
                                ),
                              ],
                              onSubmitted: (_) => _loadItems(),
                            ),
                            const SizedBox(height: 12),
                            // 2. 类型选择
                            DropdownMenu<String?>(
                              key: ValueKey('type-filter-$_selectedTypeFilter'),
                              label: const Text('类型'),
                              initialSelection: _selectedTypeFilter,
                              expandedInsets: EdgeInsets.zero,
                              dropdownMenuEntries: [
                                for (final entry in _typeFilters)
                                  DropdownMenuEntry(
                                    value: entry.value,
                                    label: entry.label,
                                  ),
                              ],
                              onSelected: (value) async {
                                if (value == null) return;
                                setState(() {
                                  _selectedTypeFilter = value;
                                  // 切换类型时清空子筛选项
                                  _selectedSpellLevel = null;
                                  _selectedSpellSchool = null;
                                  _selectedSpellClass = null;
                                  _selectedFeatCategory = null;
                                });
                                await _loadItems();
                              },
                            ),
                            if (_selectedCampaignId != null) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: FilterChip(
                                  avatar: const Icon(
                                    Icons.bookmark_outline,
                                    size: 18,
                                  ),
                                  label: const Text('仅看收藏'),
                                  selected: _favoriteOnly,
                                  onSelected: (selected) async {
                                    setState(() => _favoriteOnly = selected);
                                    await _loadItems();
                                  },
                                ),
                              ),
                            ],
                            // 3. 子筛选（法术：环阶 + 学派 + 职业）
                            if (_selectedTypeFilter == 'spell') ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  SizedBox(
                                    width: 130,
                                    child: DropdownMenu<int?>(
                                      key: ValueKey(
                                        'spell-level-$_selectedSpellLevel',
                                      ),
                                      label: const Text('环阶'),
                                      initialSelection: _selectedSpellLevel,
                                      expandedInsets: EdgeInsets.zero,
                                      dropdownMenuEntries: const [
                                        DropdownMenuEntry(
                                          value: null,
                                          label: '全部',
                                        ),
                                        DropdownMenuEntry(
                                          value: 0,
                                          label: '戏法',
                                        ),
                                        DropdownMenuEntry(
                                          value: 1,
                                          label: '1 环',
                                        ),
                                        DropdownMenuEntry(
                                          value: 2,
                                          label: '2 环',
                                        ),
                                        DropdownMenuEntry(
                                          value: 3,
                                          label: '3 环',
                                        ),
                                        DropdownMenuEntry(
                                          value: 4,
                                          label: '4 环',
                                        ),
                                        DropdownMenuEntry(
                                          value: 5,
                                          label: '5 环',
                                        ),
                                        DropdownMenuEntry(
                                          value: 6,
                                          label: '6 环',
                                        ),
                                        DropdownMenuEntry(
                                          value: 7,
                                          label: '7 环',
                                        ),
                                        DropdownMenuEntry(
                                          value: 8,
                                          label: '8 环',
                                        ),
                                        DropdownMenuEntry(
                                          value: 9,
                                          label: '9 环',
                                        ),
                                      ],
                                      onSelected: (value) {
                                        setState(
                                          () => _selectedSpellLevel = value,
                                        );
                                      },
                                    ),
                                  ),
                                  SizedBox(
                                    width: 150,
                                    child: DropdownMenu<String?>(
                                      key: ValueKey(
                                        'spell-school-$_selectedSpellSchool',
                                      ),
                                      label: const Text('学派'),
                                      initialSelection: _selectedSpellSchool,
                                      expandedInsets: EdgeInsets.zero,
                                      dropdownMenuEntries: [
                                        const DropdownMenuEntry(
                                          value: null,
                                          label: '全部',
                                        ),
                                        for (final school
                                            in _availableSpellSchools)
                                          DropdownMenuEntry(
                                            value: school,
                                            label: school,
                                          ),
                                      ],
                                      onSelected: (value) {
                                        setState(
                                          () => _selectedSpellSchool = value,
                                        );
                                      },
                                    ),
                                  ),
                                  SizedBox(
                                    width: 150,
                                    child: DropdownMenu<String?>(
                                      key: ValueKey(
                                        'spell-class-$_selectedSpellClass',
                                      ),
                                      label: const Text('职业'),
                                      initialSelection: _selectedSpellClass,
                                      expandedInsets: EdgeInsets.zero,
                                      dropdownMenuEntries: [
                                        const DropdownMenuEntry(
                                          value: null,
                                          label: '全部',
                                        ),
                                        for (final cls
                                            in _availableSpellClasses)
                                          DropdownMenuEntry(
                                            value: cls,
                                            label: cls,
                                          ),
                                      ],
                                      onSelected: (value) {
                                        setState(
                                          () => _selectedSpellClass = value,
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            // 4. 子筛选（专长：类别）
                            if (_selectedTypeFilter == 'feat' &&
                                _availableFeatCategories.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              SizedBox(
                                width: 200,
                                child: DropdownMenu<String?>(
                                  key: ValueKey(
                                    'feat-category-$_selectedFeatCategory',
                                  ),
                                  label: const Text('类别'),
                                  initialSelection: _selectedFeatCategory,
                                  expandedInsets: EdgeInsets.zero,
                                  dropdownMenuEntries: [
                                    const DropdownMenuEntry(
                                      value: null,
                                      label: '全部',
                                    ),
                                    for (final category
                                        in _availableFeatCategories)
                                      DropdownMenuEntry(
                                        value: category,
                                        label: category,
                                      ),
                                  ],
                                  onSelected: (value) {
                                    setState(
                                      () => _selectedFeatCategory = value,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    // 5. DM 内容包管理（折叠在卡片里）
                    if (isDm && campaigns.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Card(
                            elevation: 0,
                            color: colorScheme.surfaceContainerLow,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.inventory_2_outlined,
                                        size: 20,
                                        color: colorScheme.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '内容包',
                                        style: theme.textTheme.titleMedium,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (packages.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: Text('还没有内容包，导入 JSON 后可为战役启用'),
                                    )
                                  else
                                    for (final contentPackage in packages)
                                      ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        leading: const Icon(
                                          Icons.inventory_2_outlined,
                                          size: 22,
                                        ),
                                        title: Text(contentPackage.name),
                                        subtitle: Text(
                                          '${contentPackage.version}'
                                          '${contentPackage.scope == "system" ? " · 内置" : ""}',
                                        ),
                                        trailing: _buildPackageToggle(
                                          contentPackage,
                                        ),
                                      ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    ],
                    // 6. 条目计数
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Text('条目', style: theme.textTheme.titleMedium),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${items.length}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSecondaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 8)),
                    // 7. 条目列表（卡片样式）
                    if (widget.contentController.isLoading)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      )
                    else if (items.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.menu_book_outlined,
                                  size: 48,
                                  color: colorScheme.outline,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '暂无内容',
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '尝试更换筛选或刷新资料库',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList.builder(
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return _buildItemCard(
                              item,
                              compact,
                              isWide: isWide,
                            );
                          },
                        ),
                      ),
                    // 错误信息
                    if (widget.contentController.importErrors.isNotEmpty ||
                        widget.contentController.error != null) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final error
                                  in widget.contentController.importErrors)
                                Text(
                                  error,
                                  style: TextStyle(color: colorScheme.error),
                                ),
                              if (widget.contentController.error != null)
                                Text(
                                  widget.contentController.error!,
                                  style: TextStyle(color: colorScheme.error),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ),
              ),
              if (isWide) ...[
                const VerticalDivider(width: 1),
                SizedBox(width: detailPaneWidth, child: _buildWideDetailPane()),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildItemCard(
    ContentItem item,
    bool compact, {
    required bool isWide,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => isWide ? _selectWideItem(item) : _showItemDetail(item),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: compact ? 8 : 12,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _typeIcon(item.type),
                  color: colorScheme.onSecondaryContainer,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: theme.textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _typeLabel(item.type),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _buildItemSubtitle(item),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPackageToggle(ContentPackage contentPackage) {
    if (contentPackage.scope == 'system') {
      return const Chip(
        label: Text('内置'),
        avatar: Icon(Icons.verified, size: 16),
      );
    }
    final campaignId = _selectedCampaignId;
    if (campaignId == null) {
      return const SizedBox.shrink();
    }
    final enabled = _enabledPackageIds.contains(contentPackage.id);
    return Wrap(
      spacing: 8,
      children: [
        IconButton(
          tooltip: '复制 JSON',
          onPressed: () => _copyPackageJson(contentPackage.id),
          icon: const Icon(Icons.copy_outlined),
        ),
        FilledButton.tonal(
          onPressed: enabled
              ? () => _setPackageEnabled(contentPackage.id, false)
              : () => _setPackageEnabled(contentPackage.id, true),
          child: Text(enabled ? '取消启用' : '启用'),
        ),
      ],
    );
  }

  Widget _buildItemSubtitle(ContentItem item) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final parts = <String>[];
    final structured = item.structured;
    if (structured is Map) {
      if (item.type == 'spell') {
        final level = structured['level'];
        if (level is num) {
          parts.add(level == 0 ? '戏法' : '$level环');
        }
        final school = structured['school'];
        if (school != null) parts.add('$school');
        final castingTime = structured['castingTime'];
        if (castingTime != null) parts.add('$castingTime');
      } else if (item.type == 'equipment' || item.type == 'item') {
        final category = structured['category'];
        if (category != null) parts.add('$category');
        final damage = structured['damage'];
        if (damage != null) parts.add('伤害 $damage');
        final ac = structured['ac'];
        if (ac != null) parts.add('AC $ac');
        final price = structured['price'];
        if (price != null) parts.add('$price');
      } else if (item.type == 'species') {
        final size = structured['size'];
        if (size != null) parts.add('$size');
        final speed = structured['speed'];
        if (speed != null) parts.add('速度 $speed');
      } else if (item.type == 'class') {
        final hitDie = structured['hitDie'];
        if (hitDie != null) parts.add('生命骰 $hitDie');
        final primaryAbility = structured['primaryAbility'];
        if (primaryAbility != null) parts.add('主属性 $primaryAbility');
      } else if (item.type == 'feat') {
        final category = structured['category'];
        if (category != null) parts.add('$category');
        final prerequisite = structured['prerequisite'];
        if (prerequisite != null && prerequisite.toString().isNotEmpty) {
          parts.add('先决 $prerequisite');
        }
      } else if (item.type == 'background') {
        final ability = structured['abilityScoreHint'];
        if (ability != null) parts.add('$ability');
      }
    }
    if (item.sourceLabel.isNotEmpty) parts.add(item.sourceLabel);
    return Text(
      parts.join(' · '),
      style: theme.textTheme.bodySmall?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _TypeFilterEntry {
  const _TypeFilterEntry({
    required this.value,
    required this.label,
    this.serverType,
    this.categoryMatch,
  });

  final String value;
  final String label;
  final String? serverType;
  final bool Function(Map structured)? categoryMatch;
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

IconData _typeIcon(String type) {
  return switch (type) {
    'spell' => Icons.auto_fix_high_outlined,
    'item' => Icons.inventory_2_outlined,
    'equipment' => Icons.shield_outlined,
    'species' => Icons.face_outlined,
    'class' => Icons.school_outlined,
    'background' => Icons.history_edu_outlined,
    'feat' => Icons.star_outline,
    'feature' => Icons.star_outline,
    'monster' => Icons.pets_outlined,
    'condition' => Icons.healing_outlined,
    _ => Icons.menu_book_outlined,
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
