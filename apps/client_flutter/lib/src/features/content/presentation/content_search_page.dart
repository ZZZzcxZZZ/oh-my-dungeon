import 'package:flutter/material.dart';

import '../../../core/widgets/app_search_bar.dart';
import '../domain/content_entry.dart';
import '../domain/content_schema_registry.dart';
import 'content_home_page.dart';
import 'content_library_controller.dart';
import 'content_type_registry.dart';

List<String?> get _typeFilters => <String?>[
  null,
  ...ContentSchemaRegistry.defaults.librarySchemas.map((schema) => schema.type),
];

List<ContentFieldSchema> _facetFieldsFor(String? type) => type == null
    ? const []
    : ContentSchemaRegistry.defaults.schemaFor(type).facetFields;

String contentFacetValueLabel(String type, String field, String value) {
  final fields = ContentSchemaRegistry.defaults.schemaFor(type).fields;
  for (final definition in fields) {
    if (definition.key == field) {
      return definition.valueLabels[value] ?? value;
    }
  }
  return value;
}

/// Task 2.2: facet section 标题旁的语义化图标, 参考 Material 3 规范.
/// Task 2.3: 补充 species/background/condition/rule 新增字段的图标.
IconData _facetFieldIcon(String field) {
  switch (field) {
    case 'level':
      return Icons.auto_awesome;
    case 'school':
      return Icons.category;
    case 'classes':
    case 'parentClass':
    case 'class':
      return Icons.shield;
    case 'hitDie':
      return Icons.favorite;
    case 'primaryAbility':
      return Icons.bolt;
    case 'category':
    case 'source':
      return Icons.category_outlined;
    case 'rarity':
      return Icons.star_outline;
    case 'prerequisite':
      return Icons.checklist;
    case 'challengeRating':
      return Icons.warning_amber;
    case 'type':
      return Icons.pets;
    case 'size':
      return Icons.height;
    case 'speed':
      return Icons.directions_run;
    case 'skillProficiencies':
      return Icons.school;
    case 'duration':
      return Icons.timer;
    default:
      return Icons.tag;
  }
}

class ContentSearchPage extends StatefulWidget {
  const ContentSearchPage({
    required this.controller,
    required this.onSelect,
    required this.onImportRequested,
    this.selectedEntryKey,
    super.key,
  });

  final ContentLibraryController controller;
  final ValueChanged<ContentEntry> onSelect;
  final VoidCallback onImportRequested;
  final String? selectedEntryKey;

  @override
  State<ContentSearchPage> createState() => _ContentSearchPageState();
}

class _ContentSearchPageState extends State<ContentSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedType;
  Map<String, Set<String>> _facets = const <String, Set<String>>{};
  bool _favoritesOnly = false;

  @override
  void initState() {
    super.initState();
    _runSearch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _runSearch() {
    final text = _searchController.text.trim();
    widget.controller.search(
      text: text.isEmpty ? null : text,
      type: _selectedType,
      favoritesOnly: _favoritesOnly,
      facets: _facets,
    );
  }

  bool get _hasActiveFilter =>
      _selectedType != null ||
      _favoritesOnly ||
      _facets.values.any((set) => set.isNotEmpty);

  int get _activeFilterCount =>
      (_selectedType == null ? 0 : 1) +
      (_favoritesOnly ? 1 : 0) +
      _facets.values.fold<int>(0, (sum, values) => sum + values.length);

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<_FilterResult>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _FilterSheet(
        selectedType: _selectedType,
        facets: _facets,
        favoritesOnly: _favoritesOnly,
        controller: widget.controller,
      ),
    );
    if (result != null) {
      setState(() {
        _selectedType = result.type;
        _facets = result.facets;
        _favoritesOnly = result.favoritesOnly;
      });
      _runSearch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final registry = ContentTypeRegistry.defaults();
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSearchBar(
                  controller: _searchController,
                  hintText: '搜索名称、关键字…',
                  onSubmitted: (_) => _runSearch(),
                  onFilterPressed: _openFilterSheet,
                  activeFilterCount: _activeFilterCount,
                ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: widget.controller,
              builder: (context, _) {
                if (widget.controller.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (widget.controller.error != null) {
                  return Center(
                    child: Text(
                      widget.controller.error!,
                      style: TextStyle(color: colorScheme.error),
                    ),
                  );
                }
                final results = widget.controller.results;
                if (results.isEmpty) {
                  if (_hasActiveFilter) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 40,
                              color: colorScheme.outline,
                            ),
                            const SizedBox(height: 12),
                            Text('暂无内容', style: theme.textTheme.titleMedium),
                          ],
                        ),
                      ),
                    );
                  }
                  return ContentHomePage(controller: widget.controller);
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: results.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final entry = results[index];
                    final definition = registry.definitionFor(entry.type);
                    final isSelected = widget.selectedEntryKey == entry.id;
                    return ListTile(
                      leading: Icon(definition.icon),
                      title: Text(entry.name),
                      subtitle: entry.summary.isEmpty
                          ? null
                          : Text(
                              entry.summary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                      trailing: const Icon(Icons.chevron_right),
                      selected: isSelected,
                      onTap: () => widget.onSelect(entry),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterResult {
  const _FilterResult({
    this.type,
    required this.facets,
    this.favoritesOnly = false,
  });

  final String? type;
  final Map<String, Set<String>> facets;
  final bool favoritesOnly;
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.selectedType,
    required this.facets,
    required this.favoritesOnly,
    required this.controller,
  });

  final String? selectedType;
  final Map<String, Set<String>> facets;
  final bool favoritesOnly;
  final ContentLibraryController controller;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String? _type;
  late Map<String, Set<String>> _facets;
  late bool _favoritesOnly;
  Map<String, List<FacetOption>> _facetOptions = const {};
  bool _loadingFacets = false;

  @override
  void initState() {
    super.initState();
    _type = widget.selectedType;
    _facets = <String, Set<String>>{
      for (final entry in widget.facets.entries)
        entry.key: Set<String>.from(entry.value),
    };
    _favoritesOnly = widget.favoritesOnly;
    if (_type != null) {
      _loadFacetOptions(_type!);
    }
  }

  Future<void> _loadFacetOptions(String type) async {
    final fields = _facetFieldsFor(type);
    if (fields.isEmpty) {
      setState(() {
        _facetOptions = const {};
        _loadingFacets = false;
      });
      return;
    }
    setState(() => _loadingFacets = true);
    try {
      final options = await widget.controller.facetOptionsWithCounts(
        type: type,
        fields: fields.map((f) => f.key).toList(),
      );
      if (mounted) {
        setState(() {
          _facetOptions = options;
          _loadingFacets = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingFacets = false);
    }
  }

  void _selectType(String? type) {
    setState(() {
      _type = type;
      _facets = <String, Set<String>>{};
    });
    if (type != null) {
      _loadFacetOptions(type);
    } else {
      setState(() => _facetOptions = const {});
    }
  }

  void _toggleFacet(String field, String value) {
    setState(() {
      final current = Set<String>.from(_facets[field] ?? const {});
      if (current.contains(value)) {
        current.remove(value);
      } else {
        current.add(value);
      }
      if (current.isEmpty) {
        _facets.remove(field);
      } else {
        _facets[field] = current;
      }
    });
  }

  void _clearAll() {
    setState(() {
      _type = null;
      _facets = <String, Set<String>>{};
      _favoritesOnly = false;
      _facetOptions = const {};
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final registry = ContentTypeRegistry.defaults();
    final facetFields = _facetFieldsFor(_type);
    // Task 2.2: 容器改为 DraggableScrollableSheet, 小屏可拖拽调整高度;
    // 内容用 ListView (padding 经 SliverPadding 提供, 非 Padding widget),
    // 使 facet section 的 Padding 不被外层 Padding 包裹, 从而让
    // find.ancestor(of: 学派, matching: Padding) 只命中 section 自身.
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.25,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Center(
                  child: Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    Text('筛选', style: theme.textTheme.titleMedium),
                    const Spacer(),
                    TextButton(
                      key: const Key('content-filter-clear'),
                      onPressed: _clearAll,
                      child: const Text('清除'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                // Task 2.2: 用 SingleChildScrollView + Column 替代 ListView,
                // 确保所有 facet sections 都被构建 (非 lazy), 避免小屏下
                // SliverList 因 viewport 限制导致 school/classes section
                // 不挂载, 测试 find 失败. facet sections 数量少 (≤4),
                // 一次性构建无性能影响.
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 12,
                        children: [
                          for (final type in _typeFilters)
                            ChoiceChip(
                              label: Text(
                                type == null
                                    ? '全部'
                                    : registry.definitionFor(type).label,
                              ),
                              selected: _type == type,
                              onSelected: (_) => _selectType(type),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FilterChip(
                        avatar: const Icon(Icons.favorite_border, size: 18),
                        label: const Text('收藏'),
                        selected: _favoritesOnly,
                        onSelected: (selected) =>
                            setState(() => _favoritesOnly = selected),
                      ),
                      if (_type != null && facetFields.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        if (_loadingFacets)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else
                          for (final field in facetFields)
                            if ((_facetOptions[field.key] ?? const [])
                                .isNotEmpty)
                              _FacetSection(
                                title: field.label,
                                icon: _facetFieldIcon(field.key),
                                options: _facetOptions[field.key]!,
                                selectedValues: _facets[field.key] ?? const {},
                                valueLabel: (value) => contentFacetValueLabel(
                                  _type!,
                                  field.key,
                                  value,
                                ),
                                onToggle: (value) =>
                                    _toggleFacet(field.key, value),
                              ),
                      ],
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: FilledButton(
                    key: const Key('content-filter-apply'),
                    onPressed: () {
                      Navigator.of(context).pop(
                        _FilterResult(
                          type: _type,
                          facets: _facets,
                          favoritesOnly: _favoritesOnly,
                        ),
                      );
                    },
                    child: const Text('应用'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FacetSection extends StatelessWidget {
  const _FacetSection({
    required this.title,
    required this.icon,
    required this.options,
    required this.selectedValues,
    required this.valueLabel,
    required this.onToggle,
  });

  final String title;
  final IconData icon;
  final List<FacetOption> options;
  final Set<String> selectedValues;
  final String Function(String) valueLabel;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 12,
            children: [
              for (final option in options)
                FilterChip(
                  label: Text('${valueLabel(option.value)} (${option.count})'),
                  selected: selectedValues.contains(option.value),
                  onSelected: (_) => onToggle(option.value),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
