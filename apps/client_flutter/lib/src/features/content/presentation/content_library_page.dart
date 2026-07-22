import 'package:flutter/material.dart';

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
  void _showDetailDialog(String entryKey) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 960,
            maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.9,
          ),
          child: _ContentReaderStack(
            initialEntryKey: entryKey,
            controller: widget.controller,
            onImportRequested: widget.onImportRequested,
            onClose: () => Navigator.of(dialogContext).pop(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: ContentSearchPage(
          controller: widget.controller,
          onSelect: (entry) => _showDetailDialog(entry.id),
          onImportRequested: widget.onImportRequested,
        ),
      ),
    );
  }
}

/// 浮层阅读器导航栈. 维护 entry key 列表, 顶部为当前显示的条目.
/// 点击关联条目压入栈, 返回时弹出栈, 整个 Dialog 复用同一个 PageStorage,
/// 使每个条目的滚动位置在出栈后可恢复.
class _ContentReaderStack extends StatefulWidget {
  const _ContentReaderStack({
    required this.initialEntryKey,
    required this.controller,
    required this.onImportRequested,
    required this.onClose,
  });

  final String initialEntryKey;
  final ContentLibraryController controller;
  final VoidCallback onImportRequested;
  final VoidCallback onClose;

  @override
  State<_ContentReaderStack> createState() => _ContentReaderStackState();
}

class _ContentReaderStackState extends State<_ContentReaderStack> {
  late final List<String> _stack;

  @override
  void initState() {
    super.initState();
    _stack = [widget.initialEntryKey];
  }

  void _push(String entryKey) {
    setState(() => _stack.add(entryKey));
  }

  void _pop() {
    if (_stack.length > 1) {
      setState(() => _stack.removeLast());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ContentDetailPage(
      entryKey: _stack.last,
      controller: widget.controller,
      onOpenEntry: _push,
      onImportRequested: widget.onImportRequested,
      onBack: _stack.length > 1 ? _pop : null,
      onClose: widget.onClose,
    );
  }
}
