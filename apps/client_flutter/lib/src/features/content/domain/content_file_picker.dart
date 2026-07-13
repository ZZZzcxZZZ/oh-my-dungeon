import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

abstract interface class ContentFilePicker {
  Future<PickedContentFile?> pick();
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
}
