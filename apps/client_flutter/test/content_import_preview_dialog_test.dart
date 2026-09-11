import 'package:dnd_table_client/src/features/content/domain/content_import_report.dart';
import 'package:dnd_table_client/src/features/content/presentation/content_import_preview_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ContentImportReport _report({
  bool valid = true,
  int formatVersion = 3,
  List<ContentValidationError> errors = const [],
  List<ContentValidationError> warnings = const [],
}) {
  return ContentImportReport(
    valid: valid,
    formatVersion: formatVersion,
    packageId: 'test-pkg',
    packageName: 'Test Package',
    version: '1.0.0',
    locale: 'zh-CN',
    system: 'dnd5e-2024',
    entryCount: 0,
    entries: const [],
    errors: errors,
    warnings: warnings,
    assets: const {},
    contentHash: 'fake-hash',
  );
}

Future<void> _pump(
  WidgetTester tester,
  ContentImportReport report,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ContentImportPreviewDialog(report: report, onConfirm: () async {}),
    ),
  );
  await tester.pump();
}

void main() {
  group('ContentImportPreviewDialog warnings', () {
    testWidgets('valid report with warnings shows the 提示 block', (tester) async {
      await _pump(
        tester,
        _report(
          warnings: const [
            ContentValidationError(
              path: r'$.entries[0].structured.classRules',
              message: '未声明 classRules（unresolvedClassRule）',
            ),
          ],
        ),
      );
      expect(find.byKey(const Key('import-preview-warnings')), findsOneWidget);
      expect(find.text('提示（不阻断导入）'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      expect(find.textContaining('unresolvedClassRule'), findsOneWidget);
      // warning 不阻断：确认导入按钮仍然可用。
      expect(find.widgetWithText(FilledButton, '确认导入'), findsOneWidget);
    });

    testWidgets('valid report without warnings hides the 提示 block', (
      tester,
    ) async {
      await _pump(tester, _report());
      expect(find.byKey(const Key('import-preview-warnings')), findsNothing);
      expect(find.text('提示（不阻断导入）'), findsNothing);
    });

    testWidgets('invalid report shows errors first, then warnings', (
      tester,
    ) async {
      await _pump(
        tester,
        _report(
          valid: false,
          errors: const [
            ContentValidationError(path: r'$.formatVersion', message: 'boom'),
          ],
          warnings: const [
            ContentValidationError(
              path: r'$.entries[0].structured.classRules.hitDie',
              message: '缺生命骰（missingCoreField）',
            ),
          ],
        ),
      );
      expect(find.byKey(const Key('import-preview-errors')), findsOneWidget);
      expect(find.byKey(const Key('import-preview-warnings')), findsOneWidget);
      expect(find.textContaining('boom'), findsOneWidget);
      expect(find.textContaining('missingCoreField'), findsOneWidget);
      expect(find.widgetWithText(TextButton, '关闭'), findsOneWidget);
    });

    testWidgets('legacy v1 banner is gone (v1 is rejected, never previewed)', (
      tester,
    ) async {
      await _pump(tester, _report(valid: false, formatVersion: 1));
      expect(find.byKey(const Key('legacy-format-banner')), findsNothing);
      expect(find.textContaining('旧版资料包格式'), findsNothing);
    });
  });
}
