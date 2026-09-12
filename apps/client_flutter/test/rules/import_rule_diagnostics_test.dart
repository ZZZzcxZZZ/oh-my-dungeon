// 任务 11：导入器接入规则诊断（`structured.classRules` / grant formula / 格式版本）。
//
// 契约：`formatVersion: 3` 是唯一被接受的版本；`classRules` 的 error 诊断阻断整包，
// warning 进 `report.warnings` 不阻断；命内置 slug 却未声明 `classRules` 一律拒绝，
// 杜绝"slug 写错就静默继承内置职业数值"；`hitPoints` / `ability` grant 的 `formula`
// 走 `MaxSpec` 同一套封闭语法，非法在导入期报 `invalidMaxSpec`。
import 'dart:convert';

import 'package:dnd_table_client/src/features/content/data/import/content_package_importer.dart';
import 'package:dnd_table_client/src/features/content/domain/content_import_report.dart';
import 'package:flutter_test/flutter_test.dart';


import '../support/content_test_support.dart';

/// 构造一个单 class 条目的包文档；`structured` 缺省即"未声明 classRules"。
String packageJson({
  required Map<String, Object?> entry,
  int formatVersion = 3,
  String id = 'diag-pack',
}) => jsonEncode({
  'formatVersion': formatVersion,
  'id': id,
  'name': 'Diag pack',
  'version': '1.0.0',
  'locale': 'zh-CN',
  'system': 'dnd5e-2024',
  'entryCount': 1,
  'entries': [entry],
});

Map<String, Object?> classEntry({
  String slug = 'homebrew-sage',
  Map<String, Object?>? structured,
  Map<String, Object?>? rules,
}) => {
  'id': 'diag-pack:class/$slug',
  'type': 'class',
  'slug': slug,
  'name': 'Diag class',
  'body': <Object?>[],
  'revision': 1,
  'structured': ?structured,
  'rules': ?rules,
};

void main() {
  late MemoryContentRepository repository;
  late ContentPackageImporter importer;

  setUp(() {
    repository = MemoryContentRepository();
    importer = ContentPackageImporter(repository);
  });

  group('formatVersion', () {
    test('只接受 3，1 与 2 整包拒绝且消息可操作', () async {
      for (final legacy in [1, 2]) {
        final report = await importer.previewJson(
          packageJson(
            formatVersion: legacy,
            entry: classEntry(
              structured: {
                'classRules': {'hitDie': 10},
              },
            ),
          ),
        );
        expect(report.valid, isFalse, reason: 'v$legacy 必须被拒绝');
        final versionError = report.errors.singleWhere(
          (error) => error.path == r'$.formatVersion',
        );
        expect(versionError.message, contains('3'));
        expect(versionError.message, contains('旧格式'));
        expect(versionError.message, contains('重新生成'));
      }
    });

    test('3 通过', () async {
      final report = await importer.previewJson(
        packageJson(
          entry: classEntry(
            structured: {
              'classRules': {'hitDie': 10},
            },
          ),
        ),
      );
      expect(report.valid, isTrue);
      expect(report.formatVersion, 3);
    });
  });

  group('structured.classRules 诊断分流', () {
    test('非法 classRules 阻断整包，路径精确到字段', () async {
      // hitDex 是未知键（想写 hitDie）。
      final report = await importer.previewJson(
        packageJson(
          entry: classEntry(
            structured: {
              'classRules': {'hitDex': 10},
            },
          ),
        ),
      );
      expect(report.valid, isFalse);
      expect(
        report.errors.single.path,
        r'$.entries[0].structured.classRules.hitDex',
      );
      expect(report.errors.single.message, contains('hitDie'));
      expect(report.errors.single.message, contains('unknownField'));
    });

    test('缺 hitDie 只给 warning（missingCoreField），不阻断', () async {
      final report = await importer.previewJson(
        packageJson(
          entry: classEntry(
            structured: {'classRules': <String, Object?>{}},
          ),
        ),
      );
      expect(report.valid, isTrue);
      expect(report.errors, isEmpty);
      expect(report.warnings.single.message, contains('missingCoreField'));
      expect(
        report.warnings.single.path,
        r'$.entries[0].structured.classRules.hitDie',
      );
    });

    test('warning 不阻断，error 与 warning 可同时出现', () async {
      final report = await importer.previewJson(
        packageJson(
          entry: classEntry(
            structured: {
              'classRules': {
                'hitDex': 10,
                'savingThrowAbilities': <Object?>['dex', 'luck'],
              },
            },
          ),
        ),
      );
      expect(report.valid, isFalse);
      // hitDex 是 error；缺少 hitDie 是 warning。
      expect(
        report.errors.any((e) => e.path.endsWith('classRules.hitDex')),
        isTrue,
      );
      expect(
        report.warnings.any(
          (w) => w.message.contains('missingCoreField') && w.path.endsWith('.hitDie'),
        ),
        isTrue,
      );
    });

    test('非 class 条目带 classRules 不参与校验', () async {
      final report = await importer.previewJson(
        packageJson(
          entry: {
            'id': 'diag-pack:feat/example',
            'type': 'feat',
            'slug': 'example',
            'name': 'Example',
            'body': <Object?>[],
            'revision': 1,
            'structured': {
              'classRules': {'hitDex': 10},
            },
          },
        ),
      );
      expect(report.valid, isTrue);
      expect(report.warnings, isEmpty);
    });
  });

  group('内置 slug 保护', () {
    test('slug 命中内置职业却未声明 classRules → 阻断', () async {
      final report = await importer.previewJson(
        packageJson(entry: classEntry(slug: 'fighter')),
      );
      expect(report.valid, isFalse);
      final error = report.errors.singleWhere(
        (e) => e.message.contains('builtinSlugRequiresExplicitRules'),
      );
      expect(error.path, r'$.entries[0].structured.classRules');
      expect(error.message, contains('fighter'));
      // 未声明 classRules 的普通自制职业只给 warning，见下一组用例。
      expect(report.warnings.single.message, contains('unresolvedClassRule'));
    });

    test('所有内置 slug 都受保护（判据来自档案，不写死名单）', () async {
      for (final slug in const [
        'barbarian',
        'bard',
        'cleric',
        'druid',
        'fighter',
        'monk',
        'paladin',
        'ranger',
        'rogue',
        'sorcerer',
        'warlock',
        'wizard',
      ]) {
        final report = await importer.previewJson(
          packageJson(entry: classEntry(slug: slug)),
        );
        expect(
          report.valid,
          isFalse,
          reason: '内置职业 $slug 未声明 classRules 必须被拒绝',
        );
        expect(
          report.errors.any(
            (e) => e.message.contains('builtinSlugRequiresExplicitRules'),
          ),
          isTrue,
          reason: '$slug 缺少 builtinSlugRequiresExplicitRules',
        );
      }
    });

    test('slug 命中内置职业且显式声明 classRules → 放行', () async {
      final report = await importer.previewJson(
        packageJson(
          entry: classEntry(
            slug: 'fighter',
            structured: {
              'classRules': {'hitDie': 10},
            },
          ),
        ),
      );
      expect(report.valid, isTrue);
    });

    test('自制 slug 未声明 classRules 只给 unresolvedClassRule warning', () async {
      final report = await importer.previewJson(
        packageJson(entry: classEntry(slug: 'homebrew-sage')),
      );
      expect(report.valid, isTrue);
      expect(report.errors, isEmpty);
      final warning = report.warnings.singleWhere(
        (w) => w.message.contains('unresolvedClassRule'),
      );
      expect(warning.path, r'$.entries[0].structured.classRules');
    });
  });

  group('grant formula 封闭语法', () {
    test('hitPoints grant 非法 formula 在导入期阻断（invalidMaxSpec）', () async {
      final report = await importer.previewJson(
        packageJson(
          entry: classEntry(
            slug: 'homebrew-sage',
            structured: {
              'classRules': {'hitDie': 10},
            },
            rules: {
              'grants': [
                {
                  'id': 'hp-bonus',
                  'kind': 'hitPoints',
                  'label': '额外生命',
                  'formula': 'con*2 + 3',
                },
              ],
            },
          ),
        ),
      );
      expect(report.valid, isFalse);
      final error = report.errors.singleWhere(
        (e) => e.message.contains('invalidMaxSpec'),
      );
      expect(error.path, r'$.entries[0].rules.grants[0].formula');
      expect(error.message, contains('con*2 + 3'));
    });

    test('ability grant 非法 formula 在导入期阻断', () async {
      final report = await importer.previewJson(
        packageJson(
          entry: classEntry(
            slug: 'homebrew-sage',
            structured: {
              'classRules': {'hitDie': 10},
            },
            rules: {
              'progression': [
                {
                  'levels': [3],
                  'grants': [
                    {
                      'id': 'asi',
                      'kind': 'ability',
                      'label': '属性提升',
                      'target': 'str',
                      'formula': '2d6',
                    },
                  ],
                },
              ],
            },
          ),
        ),
      );
      expect(report.valid, isFalse);
      final error = report.errors.singleWhere(
        (e) => e.message.contains('invalidMaxSpec'),
      );
      expect(error.path, r'$.entries[0].rules.progression[0].grants[0].formula');
    });

    test('hitPoints / ability 同时写 value 与 formula → 导入期报 invalidMaxSpec', () async {
      final report = await importer.previewJson(
        packageJson(
          entry: classEntry(
            slug: 'homebrew-sage',
            structured: {
              'classRules': {'hitDie': 10},
            },
            rules: {
              'progression': [
                {
                  'levels': [4],
                  'grants': [
                    {
                      'id': 'asi',
                      'kind': 'ability',
                      'label': '属性提升',
                      'target': 'int',
                      'value': 1,
                      'formula': 'level',
                    },
                  ],
                },
              ],
            },
          ),
        ),
      );
      expect(report.valid, isFalse);
      final error = report.errors.singleWhere(
        (e) => e.message.contains('invalidMaxSpec'),
      );
      expect(error.path, r'$.entries[0].rules.progression[0].grants[0].formula');
      expect(error.message, contains('二选一'));
    });

    test('合法 formula（level / ability:cha / 2*level / 7）放行', () async {
      final report = await importer.previewJson(
        packageJson(
          entry: classEntry(
            slug: 'homebrew-sage',
            structured: {
              'classRules': {'hitDie': 10},
            },
            rules: {
              'grants': [
                {
                  'id': 'a',
                  'kind': 'hitPoints',
                  'label': 'A',
                  'formula': 'level',
                },
                {
                  'id': 'b',
                  'kind': 'ability',
                  'label': 'B',
                  'formula': 'ability:cha',
                },
              ],
              'progression': [
                {
                  'levels': [5],
                  'grants': [
                    {
                      'id': 'c',
                      'kind': 'hitPoints',
                      'label': 'C',
                      'formula': '2*level',
                    },
                    {
                      'id': 'd',
                      'kind': 'ability',
                      'label': 'D',
                      'formula': '7',
                    },
                  ],
                },
              ],
            },
          ),
        ),
      );
      expect(report.valid, isTrue, reason: report.errors.toString());
    });

    test('其它 grant kind 的 formula 不受该封闭语法约束', () async {
      final report = await importer.previewJson(
        packageJson(
          entry: classEntry(
            slug: 'homebrew-sage',
            structured: {
              'classRules': {'hitDie': 10},
            },
            rules: {
              'grants': [
                {
                  'id': 'dmg',
                  'kind': 'feature',
                  'label': '特性',
                  'formula': '1d6+cha',
                },
              ],
            },
          ),
        ),
      );
      expect(report.valid, isTrue);
    });

    test('内联选项里的 hitPoints grant 同样校验 formula', () async {
      final report = await importer.previewJson(
        packageJson(
          entry: classEntry(
            slug: 'homebrew-sage',
            structured: {
              'classRules': {'hitDie': 10},
            },
            rules: {
              'choices': [
                {
                  'id': 'blessing',
                  'label': '祝福',
                  'optionType': 'feature',
                  'minimum': 1,
                  'maximum': 1,
                  'options': [
                    {
                      'id': 'vigor',
                      'label': '活力',
                      'grants': [
                        {
                          'id': 'vigor-hp',
                          'kind': 'hitPoints',
                          'label': '额外生命',
                          'formula': 'nope',
                        },
                      ],
                    },
                  ],
                },
              ],
            },
          ),
        ),
      );
      expect(report.valid, isFalse);
      final error = report.errors.singleWhere(
        (e) => e.message.contains('invalidMaxSpec'),
      );
      expect(
        error.path,
        r'$.entries[0].rules.choices[0].options[0].grants[0].formula',
      );
    });
  });

  group('报告与预览贯通', () {
    test('previewDndPack 也把 warning 带进报告', () async {
      final report = await importer.previewDndPack(
        dndPackBytes(
          manifest: {
            'formatVersion': 3,
            'id': 'diag-pack',
            'name': 'Diag pack',
            'version': '1.0.0',
            'locale': 'zh-CN',
            'system': 'dnd5e-2024',
            'entryCount': 1,
          },
          entries: [classEntry(slug: 'homebrew-sage')],
        ),
      );
      expect(report.valid, isTrue);
      expect(report.warnings.single.message, contains('unresolvedClassRule'));
    });

    test('默认 warnings 为空列表', () {
      const report = ContentImportReport(
        valid: true,
        formatVersion: 3,
        packageId: 'p',
        packageName: 'P',
        version: '1',
        locale: 'zh-CN',
        system: 'dnd5e-2024',
        entryCount: 0,
        entries: [],
        errors: [],
        assets: {},
        contentHash: 'h',
      );
      expect(report.warnings, isEmpty);
    });
  });
}
