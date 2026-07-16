import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/import/content_package_importer.dart';
import '../data/local/content_repository.dart';
import '../domain/content_file_picker.dart';
import '../domain/content_import_report.dart';
import '../domain/content_package_manifest.dart';
import 'content_import_preview_dialog.dart';

class ContentPackageSettingsPage extends StatefulWidget {
  const ContentPackageSettingsPage({
    required this.repository,
    required this.importer,
    required this.filePicker,
    super.key,
  });

  final ContentRepository repository;
  final ContentPackageImporter importer;
  final ContentFilePicker filePicker;

  @override
  State<ContentPackageSettingsPage> createState() =>
      _ContentPackageSettingsPageState();
}

class _ContentPackageSettingsPageState
    extends State<ContentPackageSettingsPage> {
  List<ContentPackageManifest> _packages = const [];
  Map<String, bool> _enabled = {};
  StreamSubscription<List<ContentPackageManifest>>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.repository.watchPackages().listen(_onPackages);
  }

  Future<void> _onPackages(List<ContentPackageManifest> packages) async {
    final enabled = <String, bool>{};
    for (final p in packages) {
      enabled[p.id] = await widget.repository.isPackageEnabled(p.id);
    }
    if (!mounted) return;
    setState(() {
      _packages = packages;
      _enabled = enabled;
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _pickAndPreview() async {
    final file = await widget.filePicker.pick();
    if (file == null) return;
    ContentImportReport report;
    try {
      report = file.name.toLowerCase().endsWith('.dndpack')
          ? await widget.importer.previewDndPack(file.bytes)
          : await widget.importer.previewJson(utf8.decode(file.bytes));
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to read package: $error')),
      );
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => ContentImportPreviewDialog(
        report: report,
        onConfirm: () async {
          await widget.importer.importReport(report);
        },
      ),
    );
  }

  Future<void> _confirmDelete(ContentPackageManifest package) async {
    final impact = await widget.repository.deletionImpact(package.id);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除资料包'),
        content: Text(
          '将删除 ${impact.entryCount} 个条目，${impact.favoriteCount} 个收藏，${impact.noteCount} 条笔记',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              widget.repository.deletePackage(package.id);
              Navigator.of(context).pop();
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('资料包管理')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: _pickAndPreview,
              icon: const Icon(Icons.file_upload_outlined),
              label: const Text('从文件导入'),
            ),
            const SizedBox(height: 16),
            for (final package in _packages)
              Card(
                child: ListTile(
                  title: Text(package.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(package.version),
                      Text(
                        '${package.entryCount} 个条目 · ${package.locale} · ${package.system}',
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: _enabled[package.id] ?? false,
                        onChanged: (value) =>
                            widget.repository.setPackageEnabled(package.id, value),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmDelete(package),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
