import 'package:flutter/material.dart';

import '../domain/content_schema_registry.dart';
import '../domain/content_type_definition.dart';
import 'content_library_controller.dart';
import 'content_type_registry.dart';
import '../../../core/widgets/empty_state.dart';

class ContentHomePage extends StatelessWidget {
  const ContentHomePage({required this.controller, super.key});

  final ContentLibraryController controller;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List>(
      stream: controller.watchPackages(),
      builder: (context, snapshot) {
        final packages = snapshot.data ?? const [];
        if (packages.isEmpty) {
          return const _EmptyLibraryState();
        }
        return _CategoryGrid();
      },
    );
  }
}

class _EmptyLibraryState extends StatelessWidget {
  const _EmptyLibraryState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return EmptyState(
      icon: Icons.menu_book_outlined,
      iconSize: 56,
      title: '资料库还是空的',
      titleStyle: theme.textTheme.titleLarge,
      message: '前往「设置 → 资料包」导入资料包后即可离线查阅规则、法术与怪物。',
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final registry = ContentTypeRegistry.defaults();
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.4,
      children: [
        for (final type in ContentSchemaRegistry.defaults.librarySchemas.map(
          (schema) => schema.type,
        ))
          _CategoryCard(
            definition: registry.definitionFor(type),
            colorScheme: colorScheme,
            theme: theme,
          ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.definition,
    required this.colorScheme,
    required this.theme,
  });

  final ContentTypeDefinition definition;
  final ColorScheme colorScheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    // Static category overview card: no navigation target exists yet, so it
    // must not fake a tappable affordance (no InkWell/onTap).
    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(definition.icon, color: colorScheme.primary),
            const SizedBox(height: 4),
            Text(definition.label, style: theme.textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}
