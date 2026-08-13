import 'package:flutter/material.dart';

import '../../../../core/backup/local_data_archive_service.dart';
import '../../../content/data/import/content_package_importer.dart';
import '../../../content/data/local/content_repository.dart';
import '../../../content/domain/content_file_picker.dart';
import '../../../content/presentation/content_package_settings_page.dart';
import '../data_management_page.dart';
import 'settings_section.dart';

/// 资料与存储：本地资料包入口和数据备份/恢复入口。
class ContentAndStorageSection extends StatelessWidget {
  const ContentAndStorageSection({
    required this.contentRepository,
    required this.contentImporter,
    required this.contentFilePicker,
    required this.archiveService,
    super.key,
  });

  final ContentRepository? contentRepository;
  final ContentPackageImporter? contentImporter;
  final ContentFilePicker? contentFilePicker;
  final LocalDataArchiveService? archiveService;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return SettingsSection(
      title: '资料与存储',
      leading: Icon(Icons.inventory_2_outlined, color: colorScheme.primary),
      children: [
        if (contentRepository != null &&
            contentImporter != null &&
            contentFilePicker != null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('资料包'),
              subtitle: const Text('导入、启用或删除本地资料包'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openContentPackageSettings(context),
            ),
          ),
        if (archiveService != null) ...[
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('数据管理'),
              subtitle: const Text('导出或恢复本地角色与资料'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openDataManagementPage(context, archiveService!),
            ),
          ),
        ],
      ],
    );
  }

  void _openContentPackageSettings(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ContentPackageSettingsPage(
          repository: contentRepository!,
          importer: contentImporter!,
          filePicker: contentFilePicker!,
        ),
      ),
    );
  }

  void _openDataManagementPage(
    BuildContext context,
    LocalDataArchiveService service,
  ) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DataManagementPage(archiveService: service),
      ),
    );
  }
}
