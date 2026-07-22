import 'package:flutter/material.dart';

import '../domain/content_entry.dart';
import 'content_home_page.dart';
import 'content_library_controller.dart';
import 'content_type_registry.dart';

class _FacetField {
  const _FacetField({required this.key, required this.label});

  final String key;
  final String label;
}

const _typeFilters = <String?>[
  null,
  'spell',
  'equipment',
  'item',
  'species',
  'class',
  'subclass',
  'classFeature',
  'background',
  'feat',
  'equipmentBundle',
  'monster',
  'condition',
  'rule',
];

const _spellLevelLabels = <String, String>{
  '0': '戏法',
  '1': '1环',
  '2': '2环',
  '3': '3环',
  '4': '4环',
  '5': '5环',
  '6': '6环',
  '7': '7环',
  '8': '8环',
  '9': '9环',
};

List<_FacetField> _facetFieldsFor(String? type) {
  switch (type) {
    case 'spell':
      return const [
        _FacetField(key: 'level', label: '环位'),
        _FacetField(key: 'school', label: '学派'),
        _FacetField(key: 'classes', label: '可用职业'),
      ];
    case 'subclass':
      return const [_FacetField(key: 'parentClass', label: '所属职业')];
    case 'class':
      return const [
        _FacetField(key: 'hitDie', label: '生命骰'),
        _FacetField(key: 'primaryAbility', label: '主属性'),
      ];
    case 'classFeature':
      return const [
        _FacetField(key: 'class', label: '职业'),
        _FacetField(key: 'level', label: '等级'),
      ];
    case 'equipment':
      return const [_FacetField(key: 'category', label: '类别')];
    case 'item':
      return const [_FacetField(key: 'rarity', label: '稀有度')];
    case 'equipmentBundle':
      return const [_FacetField(key: 'source', label: '来源')];
    case 'feat':
      return const [
        _FacetField(key: 'category', label: '类别'),
        _FacetField(key: 'prerequisite', label: '先决条件'),
      ];
    case 'monster':
      return const [
        _FacetField(key: 'challengeRating', label: 'CR'),
        _FacetField(key: 'type', label: '类型'),
      ];
    default:
      return const [];
  }
}

String _facetValueLabel(String type, String field, String value) {
  if (type == 'spell' && field == 'level') {
    return _spellLevelLabels[value] ?? value;
  }
  return value;
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

  void _removeType() {
    setState(() {
      _selectedType = null;
      _facets = const {};
    });
    _runSearch();
  }

  void _toggleFavorites() {
    setState(() => _favoritesOnly = !_favoritesOnly);
    _runSearch();
  }

  void _removeFacet(String field, String value) {
    setState(() {
      final current = Set<String>.from(_facets[field] ?? const {});
      current.remove(value);
      if (current.isEmpty) {
        _facets = Map.of(_facets)..remove(field);
      } else {
        _facets = Map.of(_facets)..[field] = current;
      }
    });
    _runSearch();
  }

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
                SearchBar(
                  controller: _searchController,
                  hintText: '搜索名称、关键字…',
                  leading: const Icon(Icons.search),
                  onSubmitted: (_) => _runSearch(),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ActionChip(
                        key: const Key('content-filter-button'),
                        avatar: const Icon(Icons.tune, size: 18),
                        label: const Text('筛选'),
                        onPressed: _openFilterSheet,
                      ),
                      FilterChip(
                        label: const Text('收藏'),
                        selected: _favoritesOnly,
                        onSelected: (_) => _toggleFavorites(),
                      ),
                      if (_selectedType != null)
                        FilterChip(
                          label: Text(
                            registry.definitionFor(_selectedType!).label,
                          ),
                          onSelected: (_) => _removeType(),
                        ),
                      for (final fieldEntry in _facets.entries)
                        for (final value in fieldEntry.value)
                          FilterChip(
                            label: Text(
                              _selectedType == null
                                  ? value
                                  : _facetValueLabel(
                                      _selectedType!,
                                      fieldEntry.key,
                                      value,
                                    ),
                            ),
                            onSelected: (_) =>
                                _removeFacet(fieldEntry.key, value),
                          ),
                    ],
                  ),
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
  Map<String, List<String>> _facetOptions = const {};
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
      final options = await widget.controller.facetOptions(
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
    final registry = ContentTypeRegistry.defaults();
    final facetFields = _facetFieldsFor(_type);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
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
          const Divider(),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final type in _typeFilters)
                        FilterChip(
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
                        if ((_facetOptions[field.key] ?? const []).isNotEmpty)
                          _FacetSection(
                            title: field.label,
                            values: _facetOptions[field.key]!,
                            selectedValues: _facets[field.key] ?? const {},
                            valueLabel: (value) =>
                                _facetValueLabel(_type!, field.key, value),
                            onToggle: (value) => _toggleFacet(field.key, value),
                          ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
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
        ],
      ),
    );
  }
}

class _FacetSection extends StatelessWidget {
  const _FacetSection({
    required this.title,
    required this.values,
    required this.selectedValues,
    required this.valueLabel,
    required this.onToggle,
  });

  final String title;
  final List<String> values;
  final Set<String> selectedValues;
  final String Function(String) valueLabel;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final value in values)
                FilterChip(
                  label: Text(valueLabel(value)),
                  selected: selectedValues.contains(value),
                  onSelected: (_) => onToggle(value),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
