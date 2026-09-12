import 'dart:io';

import 'package:dnd_table_client/src/core/database/app_database.dart';
import 'package:dnd_table_client/src/features/characters/domain/structured_class_rules.dart';
import 'package:dnd_table_client/src/features/content/data/import/content_package_importer.dart';
import 'package:dnd_table_client/src/features/content/data/local/content_repository.dart';
import 'package:dnd_table_client/src/features/rules/domain/character_rule_definition.dart';
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
    'every included class exposes its related subclass choices',
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
      final classes = installed
          .where((entry) => entry.type == 'class')
          .toList(growable: false);

      // 静默空转是弱测试：一个 class 条目都装不进来，说明导入链本身坏了，
      // 必须在这里就红，而不是让下面的 for 循环一次都不执行。
      expect(classes, isNotEmpty, reason: '安装后的资料库里没有任何 class 条目');

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
      }
    },
    skip: packagePath.isEmpty ? 'No private package path was provided.' : false,
  );

  // 新契约下技能选择的唯一来源是 `classEntry.rules` 的 `choices`（含
  // `progression[].choices`）里 `optionType == "skill"` 的选择（`minimum` 是必选
  // 项数、内联 `options` 是候选值）。重提取包（formatVersion 3）已迁移到该形状，
  // 因此本用例不再 skip，直接校验真实私有包。
  test(
    'every included class exposes its skill choice through rules.choices',
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
      final classes = installed
          .where((entry) => entry.type == 'class')
          .toList(growable: false);

      // 同上一处：静默空转通过是弱测试，装不进 class 条目必须在这里红。
      expect(classes, isNotEmpty, reason: '安装后的资料库里没有任何 class 条目');

      for (final classEntry in classes) {
        final rules = classEntry.rules;
        final skillChoices = rules == null
            ? const <RuleChoiceDefinition>[]
            : <RuleChoiceDefinition>[
                ...rules.choices,
                for (final step in rules.progression) ...step.choices,
              ].where((choice) => choice.optionType == 'skill').toList(
                growable: false,
              );
        expect(
          skillChoices,
          isNotEmpty,
          reason: '${classEntry.name} is missing its skill choice',
        );
        for (final choice in skillChoices) {
          expect(
            choice.minimum,
            greaterThan(0),
            reason: '${classEntry.name} skill choice must require a pick',
          );
          expect(
            choice.options,
            isNotEmpty,
            reason: '${classEntry.name} should expose inline skill options',
          );
        }
      }
    },
    skip: packagePath.isEmpty ? 'No private package path was provided.' : false,
  );
}
