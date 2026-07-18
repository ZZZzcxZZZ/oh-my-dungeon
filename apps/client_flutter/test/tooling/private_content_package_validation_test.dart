import 'dart:io';

import 'package:dnd_table_client/src/core/database/app_database.dart';
import 'package:dnd_table_client/src/features/characters/domain/structured_class_rules.dart';
import 'package:dnd_table_client/src/features/content/data/import/content_package_importer.dart';
import 'package:dnd_table_client/src/features/content/data/local/content_repository.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_choice_resolver.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const packagePath = String.fromEnvironment('CONTENT_PACKAGE_PATH');

  test(
    'the requested content package passes the real Flutter importer',
    () async {
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
    },
    skip: packagePath.isEmpty ? 'No private package path was provided.' : false,
  );

  test(
    'every class exposes its related subclass choices',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftContentRepository(database);
      final importer = ContentPackageImporter(repository);
      final report = await importer.previewJson(
        await File(packagePath).readAsString(),
      );
      expect(report.valid, isTrue);
      await importer.importReport(report);

      final installed = await repository.search(const ContentQuery());
      final entries = {for (final entry in installed) entry.id: entry};
      final resolver = RuleChoiceResolver(entries: entries);
      final classes = installed.where((entry) => entry.type == 'class');

      expect(classes, hasLength(12));
      for (final classEntry in classes) {
        final subclassChoices = classEntry.rules!.progression
            .expand((step) => step.choices)
            .where((choice) => choice.optionType == 'subclass');
        expect(
          subclassChoices,
          isNotEmpty,
          reason: '${classEntry.name} is missing its subclass choice',
        );
        expect(
          resolver.optionsFor(
            subclassChoices.first,
            sourceEntryId: classEntry.id,
          ),
          hasLength(4),
          reason: '${classEntry.name} should expose four related subclasses',
        );
        expect(
          StructuredClassRules.savingThrowAbilities(classEntry),
          hasLength(2),
          reason:
              '${classEntry.name} should expose two saving throw proficiencies',
        );
        final skillChoice = StructuredClassRules.skillChoice(classEntry);
        expect(
          skillChoice.count,
          greaterThan(0),
          reason: '${classEntry.name} should expose a skill choice count',
        );
        expect(
          skillChoice.options,
          isNotEmpty,
          reason: '${classEntry.name} should expose canonical skill options',
        );
      }
    },
    skip: packagePath.isEmpty ? 'No private package path was provided.' : false,
  );
}
