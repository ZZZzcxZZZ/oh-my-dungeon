import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

abstract interface class ContentFilePicker {
  Future<PickedContentFile?> pick();

  /// Spec §资料库 GUI 增强: 批量导入确认向导. 一次选择多个
  /// `.json` / `.dndpack` 文件, 返回空列表表示用户取消.
  Future<List<PickedContentFile>> pickMultiple();
}

class PickedContentFile {
  const PickedContentFile({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
}

class FilePickerContentFilePicker implements ContentFilePicker {
  const FilePickerContentFilePicker();

  @override
  Future<PickedContentFile?> pick() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['json', 'dndpack'],
    );
    if (result == null) return null;
    final files = result.files;
    if (files.isEmpty) return null;
    final file = files.single;
    final bytes = file.bytes;
    if (bytes == null) return null;
    return PickedContentFile(name: file.name, bytes: bytes);
  }

  @override
  Future<List<PickedContentFile>> pickMultiple() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['json', 'dndpack'],
    );
    if (result == null) return const [];
    final picked = <PickedContentFile>[];
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null) continue;
      picked.add(PickedContentFile(name: file.name, bytes: bytes));
    }
    return picked;
  }
}
