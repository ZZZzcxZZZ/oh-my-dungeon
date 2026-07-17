import 'package:dnd_table_client/src/features/content/domain/content_import_report.dart';
import 'package:dnd_table_client/src/features/content/presentation/content_import_preview_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ContentImportReport _validReport({required int formatVersion}) {
  return ContentImportReport(
    valid: true,
    formatVersion: formatVersion,
    packageId: 'test-pkg',
    packageName: 'Test Package',
    version: '1.0.0',
    locale: 'zh-CN',
    system: 'dnd5e-2024',
    entryCount: 0,
    entries: const [],
    errors: const [],
    assets: const {},
    contentHash: 'fake-hash',
  );
}

void main() {
  group('ContentImportPreviewDialog legacy format banner', () {
    testWidgets(
      'shows legacy banner when formatVersion is 1',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ContentImportPreviewDialog(
              report: _validReport(formatVersion: 1),
              onConfirm: () async {},
            ),
          ),
        );
        await tester.pump();
        expect(find.byKey(const Key('legacy-format-banner')), findsOneWidget);
        expect(find.textContaining('旧版资料包格式'), findsOneWidget);
      },
    );

    testWidgets(
      'does not show legacy banner when formatVersion is 2',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ContentImportPreviewDialog(
              report: _validReport(formatVersion: 2),
              onConfirm: () async {},
            ),
          ),
        );
        await tester.pump();
        expect(find.byKey(const Key('legacy-format-banner')), findsNothing);
      },
    );

    testWidgets(
      'does not show legacy banner for invalid reports',
      (tester) async {
        final report = ContentImportReport(
          valid: false,
          formatVersion: 1,
          packageId: '',
          packageName: '',
          version: '',
          locale: '',
          system: '',
          entryCount: 0,
          entries: const [],
          errors: const [
            ContentValidationError(path: r'$', message: 'boom'),
          ],
          assets: const {},
          contentHash: 'fake-hash',
        );
        await tester.pumpWidget(
          MaterialApp(
            home: ContentImportPreviewDialog(
              report: report,
              onConfirm: () async {},
            ),
          ),
        );
        await tester.pump();
        expect(find.byKey(const Key('legacy-format-banner')), findsNothing);
      },
    );
  });
}
