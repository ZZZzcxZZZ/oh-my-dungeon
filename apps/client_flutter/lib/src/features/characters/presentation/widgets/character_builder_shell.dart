import 'package:flutter/material.dart';

class CharacterBuilderDestination {
  const CharacterBuilderDestination({
    required this.id,
    required this.label,
    required this.icon,
  });

  final int id;
  final String label;
  final IconData icon;
}

class CharacterBuilderShell extends StatelessWidget {
  const CharacterBuilderShell({
    required this.title,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.editor,
    required this.summary,
    required this.bottomBar,
    super.key,
  });

  final String title;
  final List<CharacterBuilderDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget editor;
  final Widget summary;
  final Widget bottomBar;

  @override
  Widget build(BuildContext context) {
    assert(destinations.isNotEmpty);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 900) return _buildWide();
          return _buildCompact(context);
        },
      ),
      bottomNavigationBar: bottomBar,
    );
  }

  Widget _buildCompact(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          key: const Key('builder-mobile-step-selector'),
                          value: selectedIndex,
                          isExpanded: true,
                          icon: const Icon(Icons.expand_more),
                          items: [
                            for (
                              var index = 0;
                              index < destinations.length;
                              index++
                            )
                              DropdownMenuItem(
                                value: index,
                                child: Text(
                                  '${index + 1}. ${destinations[index].label}',
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) onSelected(value);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('${selectedIndex + 1}/${destinations.length}'),
                  ],
                ),
                LinearProgressIndicator(
                  value: (selectedIndex + 1) / destinations.length,
                ),
              ],
            ),
          ),
        ),
        Expanded(child: editor),
      ],
    );
  }

  Widget _buildWide() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NavigationRail(
          extended: true,
          scrollable: true,
          selectedIndex: selectedIndex,
          onDestinationSelected: onSelected,
          labelType: NavigationRailLabelType.none,
          destinations: [
            for (final destination in destinations)
              NavigationRailDestination(
                icon: Icon(
                  destination.icon,
                  key: Key('builder-step-${destination.id}'),
                ),
                selectedIcon: Icon(
                  destination.icon,
                  key: Key('builder-step-${destination.id}-selected'),
                ),
                label: Text(destination.label),
              ),
          ],
        ),
        const VerticalDivider(width: 1),
        Expanded(child: editor),
        const VerticalDivider(width: 1),
        SizedBox(width: 300, child: summary),
      ],
    );
  }
}
