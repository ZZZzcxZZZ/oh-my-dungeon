import 'package:flutter/material.dart';

import '../domain/content_entry.dart';
import 'content_detail_page.dart';
import 'content_library_controller.dart';
import 'content_search_page.dart';

class ContentLibraryPage extends StatefulWidget {
  const ContentLibraryPage({
    required this.controller,
    required this.onImportRequested,
    super.key,
  });

  final ContentLibraryController controller;
  final VoidCallback onImportRequested;

  @override
  State<ContentLibraryPage> createState() => _ContentLibraryPageState();
}

class _ContentLibraryPageState extends State<ContentLibraryPage> {
  String? _selectedEntryKey;

  void _selectEntryWide(ContentEntry entry) {
    setState(() => _selectedEntryKey = entry.id);
  }

  void _openEntryByKeyWide(String entryKey) {
    setState(() => _selectedEntryKey = entryKey);
  }

  void _pushDetailPage(String entryKey) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ContentDetailPage(
          entryKey: entryKey,
          controller: widget.controller,
          onOpenEntry: _pushDetailPage,
          onImportRequested: widget.onImportRequested,
        ),
      ),
    );
  }

  void _openEntryNarrow(ContentEntry entry) {
    _pushDetailPage(entry.id);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1000;
        if (isWide) {
          return Scaffold(
            body: Row(
              children: [
                SizedBox(
                  width: 380,
                  child: ContentSearchPage(
                    controller: widget.controller,
                    onSelect: _selectEntryWide,
                    onImportRequested: widget.onImportRequested,
                    selectedEntryKey: _selectedEntryKey,
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: ContentDetailPage(
                    key: ValueKey(_selectedEntryKey),
                    entryKey: _selectedEntryKey,
                    controller: widget.controller,
                    onOpenEntry: _openEntryByKeyWide,
                    onImportRequested: widget.onImportRequested,
                  ),
                ),
              ],
            ),
          );
        }
        return ContentSearchPage(
          controller: widget.controller,
          onSelect: _openEntryNarrow,
          onImportRequested: widget.onImportRequested,
        );
      },
    );
  }
}
