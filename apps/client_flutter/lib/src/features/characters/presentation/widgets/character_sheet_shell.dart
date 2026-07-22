import 'package:flutter/material.dart';

class CharacterSheetDestination {
  const CharacterSheetDestination({
    required this.id,
    required this.label,
    required this.icon,
    required this.child,
  });

  final String id;
  final String label;
  final IconData icon;
  final Widget child;
}

class CharacterSheetShell extends StatefulWidget {
  const CharacterSheetShell({
    required this.title,
    required this.header,
    required this.destinations,
    this.initialDestinationId = 'overview',
    this.actions = const [],
    super.key,
  });

  final String title;
  final Widget header;
  final List<CharacterSheetDestination> destinations;
  final String initialDestinationId;
  final List<Widget> actions;

  @override
  State<CharacterSheetShell> createState() => _CharacterSheetShellState();
}

class _CharacterSheetShellState extends State<CharacterSheetShell>
    with SingleTickerProviderStateMixin {
  late TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _createController();
    _controller.addListener(_handleSelectionChanged);
  }

  @override
  void didUpdateWidget(covariant CharacterSheetShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.destinations.length != widget.destinations.length) {
      final previousIndex = _controller.index;
      _controller.removeListener(_handleSelectionChanged);
      _controller.dispose();
      _controller = TabController(
        length: widget.destinations.length,
        initialIndex: previousIndex.clamp(0, widget.destinations.length - 1),
        vsync: this,
      )..addListener(_handleSelectionChanged);
      return;
    }
    if (oldWidget.initialDestinationId != widget.initialDestinationId) {
      _controller.index = _indexFor(widget.initialDestinationId);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleSelectionChanged);
    _controller.dispose();
    super.dispose();
  }

  TabController _createController() => TabController(
    length: widget.destinations.length,
    initialIndex: _indexFor(widget.initialDestinationId),
    vsync: this,
  );

  int _indexFor(String id) {
    final index = widget.destinations.indexWhere(
      (destination) => destination.id == id,
    );
    return index < 0 ? 0 : index;
  }

  void _handleSelectionChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    assert(widget.destinations.isNotEmpty);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), actions: widget.actions),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          widget.header,
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 900) return _buildWide();
                return _buildCompact();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompact() {
    return Column(
      children: [
        TabBar(
          controller: _controller,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            for (final destination in widget.destinations)
              Tab(
                key: Key('character-sheet-tab-${destination.id}'),
                text: destination.label,
              ),
          ],
        ),
        Expanded(child: _content()),
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
          minExtendedWidth: 200,
          selectedIndex: _controller.index,
          onDestinationSelected: _controller.animateTo,
          destinations: [
            for (final destination in widget.destinations)
              NavigationRailDestination(
                icon: Icon(
                  destination.icon,
                  key: Key(
                    'character-sheet-destination-${destination.id}',
                  ),
                ),
                selectedIcon: Icon(
                  destination.icon,
                  key: Key(
                    'character-sheet-destination-${destination.id}-selected',
                  ),
                ),
                label: Text(destination.label),
              ),
          ],
        ),
        const VerticalDivider(width: 1),
        Expanded(child: _content()),
      ],
    );
  }

  Widget _content() {
    return TabBarView(
      controller: _controller,
      children: [
        for (final destination in widget.destinations) destination.child,
      ],
    );
  }
}
