import 'package:flutter/material.dart';

import '../domain/content_entry.dart';
import 'content_home_page.dart';
import 'content_library_controller.dart';
import 'content_type_registry.dart';

class _TypeFilter {
  const _TypeFilter({this.value, required this.label});

  final String? value;
  final String label;
}

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
const _typeFilters = <_TypeFilter>[
  _TypeFilter(value: null, label: '全部'),
  _TypeFilter(value: 'spell', label: '法术'),
  _TypeFilter(value: 'equipment', label: '装备'),
  _TypeFilter(value: 'item', label: '物品'),
  _TypeFilter(value: 'species', label: '种族'),
  _TypeFilter(value: 'class', label: '职业'),
  _TypeFilter(value: 'background', label: '背景'),
  _TypeFilter(value: 'feat', label: '专长'),
  _TypeFilter(value: 'monster', label: '怪物'),
  _TypeFilter(value: 'condition', label: '状态'),
  _TypeFilter(value: 'rule', label: '规则'),
];

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
  String? _selectedSpellLevel;
  String? _selectedSpellSchool;
  String? _selectedSpellClass;
  List<String> _spellSchools = const [];
  List<String> _spellClasses = const [];
  bool _favoritesOnly = false;

  @override
  void initState() {
    super.initState();
    _runSearch();
    _loadSpellFacetOptions();
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
      facets: <String, Set<String>>{
        if (_selectedType == 'spell' && _selectedSpellLevel != null)
          'level': {_selectedSpellLevel!},
        if (_selectedType == 'spell' && _selectedSpellSchool != null)
          'school': {_selectedSpellSchool!},
        if (_selectedType == 'spell' && _selectedSpellClass != null)
          'classes': {_selectedSpellClass!},
      },
    );
  }

  Future<void> _loadSpellFacetOptions() async {
    final options = await widget.controller.facetOptions(
      type: 'spell',
      fields: const ['school', 'classes'],
    );
    if (!mounted) return;
    setState(() {
      _spellSchools = options['school'] ?? const [];
      _spellClasses = options['classes'] ?? const [];
    });
  }

  void _clearSpellFilters() {
    _selectedSpellLevel = null;
    _selectedSpellSchool = null;
    _selectedSpellClass = null;
  }

  bool get _hasActiveFilter =>
      (_searchController.text.trim().isNotEmpty) ||
      _selectedType != null ||
      _favoritesOnly ||
      _selectedSpellLevel != null ||
      _selectedSpellSchool != null ||
      _selectedSpellClass != null;

  Widget _buildSpellFilters() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final width = compact
            ? constraints.maxWidth
            : (constraints.maxWidth - 16) / 3;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SizedBox(
              width: width,
              child: DropdownMenu<String?>(
                key: const Key('spell-level-filter'),
                initialSelection: _selectedSpellLevel,
                expandedInsets: EdgeInsets.zero,
                label: const Text('环位'),
                dropdownMenuEntries: [
                  const DropdownMenuEntry(value: null, label: '全部环位'),
                  for (final level in _spellLevelLabels.entries)
                    DropdownMenuEntry(value: level.key, label: level.value),
                ],
                onSelected: (value) {
                  setState(() => _selectedSpellLevel = value);
                  _runSearch();
                },
              ),
            ),
            SizedBox(
              width: width,
              child: DropdownMenu<String?>(
                key: const Key('spell-school-filter'),
                initialSelection: _selectedSpellSchool,
                expandedInsets: EdgeInsets.zero,
                label: const Text('学派'),
                dropdownMenuEntries: [
                  const DropdownMenuEntry(value: null, label: '全部学派'),
                  for (final school in _spellSchools)
                    DropdownMenuEntry(value: school, label: school),
                ],
                onSelected: (value) {
                  setState(() => _selectedSpellSchool = value);
                  _runSearch();
                },
              ),
            ),
            SizedBox(
              width: width,
              child: DropdownMenu<String?>(
                key: const Key('spell-class-filter'),
                initialSelection: _selectedSpellClass,
                expandedInsets: EdgeInsets.zero,
                label: const Text('职业'),
                dropdownMenuEntries: [
                  const DropdownMenuEntry(value: null, label: '全部职业'),
                  for (final characterClass in _spellClasses)
                    DropdownMenuEntry(
                      value: characterClass,
                      label: characterClass,
                    ),
                ],
                onSelected: (value) {
                  setState(() => _selectedSpellClass = value);
                  _runSearch();
                },
              ),
            ),
          ],
        );
      },
    );
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownMenu<String?>(
                        key: ValueKey('type-filter-$_selectedType'),
                        initialSelection: _selectedType,
                        expandedInsets: EdgeInsets.zero,
                        label: const Text('类型'),
                        dropdownMenuEntries: [
                          for (final filter in _typeFilters)
                            DropdownMenuEntry(
                              value: filter.value,
                              label: filter.label,
                            ),
                        ],
                        onSelected: (value) {
                          setState(() {
                            _selectedType = value;
                            if (value != 'spell') _clearSpellFilters();
                          });
                          if (value == 'spell') _loadSpellFacetOptions();
                          _runSearch();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      avatar: const Icon(Icons.favorite_border, size: 18),
                      label: const Text('收藏'),
                      selected: _favoritesOnly,
                      onSelected: (selected) {
                        setState(() => _favoritesOnly = selected);
                        _runSearch();
                      },
                    ),
                  ],
                ),
                if (_selectedType == 'spell') ...[
                  const SizedBox(height: 12),
                  _buildSpellFilters(),
                ],
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
                  return ContentHomePage(
                    controller: widget.controller,
                  );
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
