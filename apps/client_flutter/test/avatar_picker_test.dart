import 'dart:convert';
import 'dart:typed_data';

import 'package:dnd_table_client/src/features/campaigns/presentation/widgets/avatar_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// 1x1 透明 PNG，避免 MemoryImage 在测试里因无效数据抛异常。
final _pngBytes = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
  ),
);

void main() {
  testWidgets('shows pick button and triggers onPick', (tester) async {
    var picked = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AvatarPicker(onPick: () => picked++)),
      ),
    );

    await tester.tap(find.text('选择图片'));
    expect(picked, 1);
  });

  testWidgets('triggers onUpload when upload tapped', (tester) async {
    var uploaded = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AvatarPicker(
            previewBytes: _pngBytes,
            onPick: () {},
            onUpload: () => uploaded++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('上传'));
    expect(uploaded, 1);
  });

  testWidgets('upload button is disabled until a preview is picked', (
    tester,
  ) async {
    var uploaded = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AvatarPicker(onPick: () {}, onUpload: () => uploaded++),
        ),
      ),
    );

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(uploaded, 0);
  });

  testWidgets('shows progress indicator while uploading', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AvatarPicker(
            previewBytes: _pngBytes,
            onPick: () {},
            onUpload: () {},
            isUploading: true,
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows error text when error is provided', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AvatarPicker(onPick: () {}, error: '图片太大，请压缩后重试'),
        ),
      ),
    );

    expect(find.text('图片太大，请压缩后重试'), findsOneWidget);
  });
}
