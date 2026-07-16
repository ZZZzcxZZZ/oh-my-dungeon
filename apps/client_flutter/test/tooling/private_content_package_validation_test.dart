import 'dart:io';

import 'package:dnd_table_client/src/core/database/app_database.dart';
import 'package:dnd_table_client/src/features/content/data/import/content_package_importer.dart';
import 'package:dnd_table_client/src/features/content/data/local/content_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const packagePath = String.fromEnvironment('CONTENT_PACKAGE_PATH');

  test('the requested content package passes the real Flutter importer', () async {
    final file = File(packagePath);
    expect(
      await file.exists(),
      isTrue,
      reason: 'Content package not found: ${file.path}',
    );

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final report = await ContentPackageImporter(
      DriftContentRepository(database),
    ).previewJson(await file.readAsString());

    expect(
      report.errors.map((error) => '${error.path}: ${error.message}'),
      isEmpty,
    );
    expect(report.valid, isTrue);
    expect(report.entryCount, greaterThan(0));
  }, skip: packagePath.isEmpty ? 'No private package path was provided.' : false);
}
