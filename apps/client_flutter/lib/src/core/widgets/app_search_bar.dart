import 'package:flutter/material.dart';

class AppSearchBar extends StatelessWidget {
  const AppSearchBar({
    required this.controller,
    required this.hintText,
    required this.onSubmitted,
    required this.onFilterPressed,
    this.activeFilterCount = 0,
    this.filterButtonKey = const Key('content-filter-button'),
    super.key,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onFilterPressed;
  final int activeFilterCount;
  final Key filterButtonKey;

  @override
  Widget build(BuildContext context) {
    final hasActiveFilters = activeFilterCount > 0;
    return SearchBar(
      controller: controller,
      hintText: hintText,
      leading: const Icon(Icons.search),
      onSubmitted: onSubmitted,
      trailing: [
        IconButton(
          key: filterButtonKey,
          tooltip: hasActiveFilters ? '筛选，已启用 $activeFilterCount 项' : '筛选',
          onPressed: onFilterPressed,
          icon: hasActiveFilters
              ? Badge(
                  label: Text('$activeFilterCount'),
                  child: const Icon(Icons.tune),
                )
              : const Icon(Icons.tune),
        ),
      ],
    );
  }
}
