// 任务 11：导入器接入规则诊断（`structured.classRules` / grant formula / 格式版本）。
//
// 契约：`formatVersion: 3` 是唯一被接受的版本；`classRules` 的 error 诊断阻断整包，
// warning 进 `report.warnings` 不阻断；命内置 slug 却未声明 `classRules` 一律拒绝，
// 杜绝"slug 写错就静默继承内置职业数值"；`hitPoints` / `ability` grant 的 `formula`
// 走 `MaxSpec` 同一套封闭语法，非法在导入期报 `invalidMaxSpec`。
import 'dart:convert';

import 'package:dnd_table_client/src/features/characters/domain/dnd5e_rules.dart';
import 'package:dnd_table_client/src/features/content/data/import/content_package_importer.dart';
import 'package:dnd_table_client/src/features/content/domain/content_import_report.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/content_test_support.dart';
import 'rule_profile_test_support.dart';

/// 构造一个单 class 条目的包文档；`structured` 缺省即"未声明 classRules"。
String packageJson({
  required Map<String, Object?> entry,
  num formatVersion = 3,
  String id = 'diag-pack',
  Object? globalAbilities,
  Object? globalSkills,
}) => jsonEncode({
  'formatVersion': formatVersion,
  'id': id,
  'name': 'Diag pack',
  'version': '1.0.0',
  'locale': 'zh-CN',
  'system': 'dnd5e-2024',
  'entryCount': 1,
  'abilities': ?globalAbilities,
  'skills': ?globalSkills,
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

    test('写了 classRules 却不是对象 → error，不当成"没有规则来源"放行', () async {
      final report = await importer.previewJson(
        packageJson(
          entry: classEntry(
            slug: 'homebrew-sage',
            structured: {'classRules': 'hitDie: 10'},
          ),
        ),
      );
      expect(report.valid, isFalse);
      final error = report.errors.singleWhere(
        (e) => e.path == r'$.entries[0].structured.classRules',
      );
      expect(error.message, contains('invalidTable'));
      expect(
        report.warnings.any((w) => w.message.contains('unresolvedClassRule')),
        isFalse,
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
      // §5.2：命中档案的条目**不再**收到 unresolvedClassRule——那会说"将只使用内置
      // 档案"，与同一条目的 error 自相矛盾。
      expect(report.warnings, isEmpty);
    });

    test('判定键与运行期同源：id 末段命中内置职业即受保护（slug 字段无豁免）', () async {
      // 运行期身份 = entry id 末段（`Dnd5eRules.resolveClassSlug` / `_slugFor`）；
      // 条目里的 `slug` 只是展示字段，写别的值不能让内置数值被静默继承。
      final report = await importer.previewJson(
        packageJson(
          entry: {
            ...classEntry(slug: 'custom-x'),
            'id': 'diag-pack:class/fighter',
          },
        ),
      );
      expect(report.valid, isFalse);
      final error = report.errors.singleWhere(
        (e) => e.message.contains('builtinSlugRequiresExplicitRules'),
      );
      expect(error.message, contains('fighter'));
      expect(report.warnings, isEmpty);
    });

    test('反向不误拦：id 末段是自制 slug 时，slug 字段写内置名也不阻断', () async {
      final report = await importer.previewJson(
        packageJson(
          entry: {
            ...classEntry(slug: 'fighter'),
            'id': 'diag-pack:class/custom-x',
          },
        ),
      );
      expect(report.valid, isTrue, reason: report.errors.toString());
      final warning = report.warnings.singleWhere(
        (w) => w.message.contains('unresolvedClassRule'),
      );
      expect(warning.path, r'$.entries[0].structured.classRules');
    });

    test('所有内置 slug 都受保护（判据来自档案，不写死名单）', () async {
      final slugs = Dnd5eRules.profile.classes.keys.toList()..sort();
      expect(slugs, isNotEmpty, reason: '档案没装配好，这条测试就没有意义');
      for (final slug in slugs) {
        final report = await importer.previewJson(
          packageJson(entry: classEntry(slug: slug)),
        );
        expect(
          report.valid,
          isFalse,
          reason: '内置职业 $slug 未声明 classRules 必须被拒绝',
        );
        final error = report.errors.singleWhere(
          (e) => e.message.contains('builtinSlugRequiresExplicitRules'),
        );
        expect(error.message, contains(slug));
      }
    });

    test('id 末段命中内置职业且声明了 classRules → 放行', () async {
      final report = await importer.previewJson(
        packageJson(
          entry: {
            ...classEntry(slug: 'custom-x'),
            'id': 'diag-pack:class/fighter',
            'structured': {
              'classRules': {'hitDie': 10},
            },
          },
        ),
      );
      expect(report.valid, isTrue);
      expect(report.errors, isEmpty);
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
              // `hitPoints` 是四种合法 formula 的载体；`ability` 只接受 `value`
              // （它自己的拒绝用例见下一条）。
              'grants': [
                {
                  'id': 'a',
                  'kind': 'hitPoints',
                  'label': 'A',
                  'formula': 'level',
                },
                {
                  'id': 'b',
                  'kind': 'hitPoints',
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
                      'kind': 'hitPoints',
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

    test('ability grant 的 formula 一律拒绝：没有精确逆，再派生会重复叠加', () async {
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
                  'id': 'b',
                  'kind': 'ability',
                  'label': 'B',
                  'target': 'cha',
                  'formula': 'ability:str',
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
      expect(error.message, contains('只接受 value'));
    });

    test('ability grant 自引用 formula（ability:<自身 target>）→ invalidMaxSpec', () async {
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
                      'id': 'asi-int',
                      'kind': 'ability',
                      'label': '属性提升：智力',
                      'target': 'int',
                      'formula': 'ability:int',
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
        (e) => e.path == r'$.entries[0].rules.progression[0].grants[0].formula',
      );
      expect(error.message, contains('不得自引用'));
    });

    test('hitPoints 同时写 value 与 formula → 导入期报 invalidMaxSpec', () async {
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
                  'id': 'hp',
                  'kind': 'hitPoints',
                  'label': '额外生命',
                  'value': 2,
                  'formula': 'level',
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
      expect(error.message, contains('二选一'));
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

  group('档案侧校验：原型与属性键', () {
    test('archetype 不在档案 progressions → unknownArchetype，路径精确到字段', () async {
      final report = await importer.previewJson(
        packageJson(
          entry: classEntry(
            slug: 'homebrew-sage',
            structured: {
              'classRules': {
                'hitDie': 10,
                'spellcasting': {
                  'mode': 'prepared',
                  'ability': 'cha',
                  'archetype': 'bogus',
                  'slots': {
                    '1': {'1': 2},
                  },
                  'prepared': {'1': 4},
                },
              },
            },
          ),
        ),
      );
      expect(report.valid, isFalse);
      final error = report.errors.singleWhere(
        (e) => e.message.contains('unknownArchetype'),
      );
      expect(
        error.path,
        r'$.entries[0].structured.classRules.spellcasting.archetype',
      );
      expect(error.message, contains('bogus'));
    });

    test('archetype 命中档案 progressions → 放行（full-caster 法术位可算）', () async {
      final report = await importer.previewJson(
        packageJson(
          entry: classEntry(
            slug: 'homebrew-sage',
            structured: {
              'classRules': {
                'hitDie': 10,
                'spellcasting': {
                  'mode': 'prepared',
                  'ability': 'cha',
                  'archetype': 'full-caster',
                  'prepared': {'1': 4},
                },
              },
            },
          ),
        ),
      );
      expect(report.valid, isTrue, reason: report.errors.toString());
    });

    test('kind: ability 的 target 不在档案 abilities → unknownAbility', () async {
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
                  'id': 'asi',
                  'kind': 'ability',
                  'label': '幸运提升',
                  'target': 'luck',
                  'value': 1,
                },
              ],
            },
          ),
        ),
      );
      expect(report.valid, isFalse);
      final error = report.errors.singleWhere(
        (e) => e.message.contains('unknownAbility'),
      );
      expect(error.path, r'$.entries[0].rules.grants[0].target');
      expect(error.message, contains('luck'));
    });

    test('kind: ability 的合法 target 放行（档案 abilities 内）', () async {
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
                  'id': 'asi',
                  'kind': 'ability',
                  'label': '属性提升：智力',
                  'target': 'int',
                  'value': 1,
                },
                {
                  'id': 'asi2',
                  'kind': 'ability',
                  'label': '属性提升：魅力',
                  'target': 'cha',
                  'value': 1,
                },
              ],
            },
          ),
        ),
      );
      // 合法 target 必须放行：判据是档案 abilities，不是"只要写了 target 就报错"。
      expect(report.valid, isTrue, reason: report.errors.toString());
      expect(
        report.errors.where((e) => e.message.contains('unknownAbility')),
        isEmpty,
      );
    });

    test('formula ability:xyz 的键不在档案 abilities → unknownAbility', () async {
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
                  'id': 'hp',
                  'kind': 'hitPoints',
                  'label': '额外生命',
                  'formula': 'ability:xyz',
                },
              ],
            },
          ),
        ),
      );
      expect(report.valid, isFalse);
      final error = report.errors.singleWhere(
        (e) => e.message.contains('unknownAbility'),
      );
      expect(error.path, r'$.entries[0].rules.grants[0].formula');
      expect(error.message, contains('ability:xyz'));
    });

    test('formula ability:con 的键在档案内 → 放行', () async {
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
                  'id': 'hp',
                  'kind': 'hitPoints',
                  'label': '额外生命',
                  'formula': 'ability:con',
                },
              ],
            },
          ),
        ),
      );
      expect(report.valid, isTrue, reason: report.errors.toString());
    });
  });

  group('§5.2 warning code', () {
    test('施法职业未声明 prepared → missingPreparedColumn', () async {
      final report = await importer.previewJson(
        packageJson(
          entry: classEntry(
            slug: 'homebrew-sage',
            structured: {
              'classRules': {
                'hitDie': 10,
                'spellcasting': {
                  'mode': 'prepared',
                  'ability': 'cha',
                  'archetype': 'full-caster',
                },
              },
            },
          ),
        ),
      );
      expect(report.valid, isTrue, reason: report.errors.toString());
      final warning = report.warnings.singleWhere(
        (w) => w.message.contains('missingPreparedColumn'),
      );
      expect(
        warning.path,
        r'$.entries[0].structured.classRules.spellcasting.prepared',
      );
    });

    test('非施法职业（mode: none）不会触发 missingPreparedColumn', () async {
      final report = await importer.previewJson(
        packageJson(
          entry: classEntry(
            slug: 'homebrew-sage',
            structured: {
              'classRules': {
                'hitDie': 10,
                'spellcasting': {'mode': 'none'},
              },
            },
          ),
        ),
      );
      expect(report.valid, isTrue, reason: report.errors.toString());
      expect(report.warnings, isEmpty);
    });

    test('施法职业既无自身 slots 也无提供法术位的原型 → missingCoreField', () async {
      final report = await importer.previewJson(
        packageJson(
          entry: classEntry(
            slug: 'homebrew-sage',
            structured: {
              'classRules': {
                'hitDie': 10,
                'spellcasting': {
                  'mode': 'prepared',
                  'ability': 'cha',
                  'prepared': {'1': 4},
                },
              },
            },
          ),
        ),
      );
      expect(report.valid, isTrue, reason: report.errors.toString());
      final warning = report.warnings.singleWhere(
        (w) => w.message.contains('missingCoreField'),
      );
      expect(warning.path, r'$.entries[0].structured.classRules.spellcasting');
    });

    test('施法职业挂了提供法术位的原型 → 不触发 missingCoreField', () async {
      final report = await importer.previewJson(
        packageJson(
          entry: classEntry(
            slug: 'homebrew-sage',
            structured: {
              'classRules': {
                'hitDie': 10,
                'spellcasting': {
                  'mode': 'prepared',
                  'ability': 'cha',
                  'archetype': 'half-caster',
                  'prepared': {'1': 4},
                },
              },
            },
          ),
        ),
      );
      expect(report.valid, isTrue, reason: report.errors.toString());
      expect(report.warnings, isEmpty);
    });

    test('资源表在 startsAtLevel 及以上出现 0 → zeroLevelResource', () async {
      final report = await importer.previewJson(
        packageJson(
          entry: classEntry(
            slug: 'homebrew-sage',
            structured: {
              'classRules': {
                'hitDie': 10,
                'resources': [
                  {
                    'id': 'focus',
                    'name': '专注',
                    'recovery': 'longRest',
                    'startsAtLevel': 2,
                    'maximum': {
                      'table': {'1': 0, '2': 3, '5': 0},
                    },
                  },
                ],
              },
            },
          ),
        ),
      );
      expect(report.valid, isTrue, reason: report.errors.toString());
      final warning = report.warnings.singleWhere(
        (w) => w.message.contains('zeroLevelResource'),
      );
      expect(
        warning.path,
        r'$.entries[0].structured.classRules.resources[0].maximum.table',
      );
      // startsAtLevel 之前的 0（1 级）不算；2 级及以上为 0 的档位才报。
      expect(warning.message, isNot(contains('1 级')));
      expect(warning.message, contains('5 级'));
    });

    test('表的范围整个落在 startsAtLevel 之前但沿用值为 0 → 也报 zeroLevelResource', () async {
      // `{"1": 0}` + startsAtLevel 3：表只声明 1 级（在 3 之前，循环看不到），
      // 但 §3.1 的"高于最后声明等级沿用最后声明值"让 3 级起上限恒为 0
      // （运行期 resourcesAt 会产出上限 0 的资源）。漏报这条 warning 等于
      // 让作者看不到"资源永远为 0"。
      final report = await importer.previewJson(
        packageJson(
          entry: classEntry(
            slug: 'homebrew-sage',
            structured: {
              'classRules': {
                'hitDie': 10,
                'resources': [
                  {
                    'id': 'focus',
                    'name': '专注',
                    'recovery': 'longRest',
                    'startsAtLevel': 3,
                    'maximum': {
                      'table': {'1': 0},
                    },
                  },
                ],
              },
            },
          ),
        ),
      );
      expect(report.valid, isTrue, reason: report.errors.toString());
      final warning = report.warnings.singleWhere(
        (w) => w.message.contains('zeroLevelResource'),
      );
      expect(warning.message, contains('3 级'));
    });

    test('表范围在 startsAtLevel 之前但沿用值为正 → 不触发', () async {
      final report = await importer.previewJson(
        packageJson(
          entry: classEntry(
            slug: 'homebrew-sage',
            structured: {
              'classRules': {
                'hitDie': 10,
                'resources': [
                  {
                    'id': 'focus',
                    'name': '专注',
                    'recovery': 'longRest',
                    'startsAtLevel': 3,
                    'maximum': {
                      'table': {'1': 2},
                    },
                  },
                ],
              },
            },
          ),
        ),
      );
      expect(report.valid, isTrue, reason: report.errors.toString());
      expect(report.warnings, isEmpty);
    });

    test('资源表全程为正 → 不触发 zeroLevelResource', () async {      final report = await importer.previewJson(
        packageJson(
          entry: classEntry(
            slug: 'homebrew-sage',
            structured: {
              'classRules': {
                'hitDie': 10,
                'resources': [
                  {
                    'id': 'focus',
                    'name': '专注',
                    'recovery': 'longRest',
                    'maximum': {
                      'table': {'1': 2, '5': 3},
                    },
                  },
                ],
              },
            },
          ),
        ),
      );
      expect(report.valid, isTrue, reason: report.errors.toString());
      expect(report.warnings, isEmpty);
    });

    test('常量 maximum: 0 不是"表" → 不触发 zeroLevelResource', () async {
      final report = await importer.previewJson(
        packageJson(
          entry: classEntry(
            slug: 'homebrew-sage',
            structured: {
              'classRules': {
                'hitDie': 10,
                'resources': [
                  {
                    'id': 'focus',
                    'name': '专注',
                    'recovery': 'longRest',
                    'maximum': 0,
                  },
                ],
              },
            },
          ),
        ),
      );
      expect(report.valid, isTrue, reason: report.errors.toString());
      expect(report.warnings, isEmpty);
    });

    test('包自带 abilities / skills 清单 → ignoredGlobalList（两条）', () async {
      final report = await importer.previewJson(
        packageJson(
          entry: classEntry(
            slug: 'homebrew-sage',
            structured: {
              'classRules': {'hitDie': 10},
            },
          ),
          globalAbilities: <String>['str', 'dex'],
          globalSkills: <Map<String, Object?>>[
            <String, Object?>{'name': '杂技', 'ability': 'dex'},
          ],
        ),
      );
      expect(report.valid, isTrue, reason: report.errors.toString());
      final codes = report.warnings
          .where((w) => w.message.contains('ignoredGlobalList'))
          .toList();
      expect(codes.length, 2);
      expect(
        codes.map((w) => w.path).toList(),
        <String>[r'$.abilities', r'$.skills'],
      );
    });

    test('包不带全局清单 → 没有 ignoredGlobalList', () async {
      final report = await importer.previewJson(
        packageJson(
          entry: classEntry(
            slug: 'homebrew-sage',
            structured: {
              'classRules': {'hitDie': 10},
            },
          ),
        ),
      );
      expect(report.valid, isTrue, reason: report.errors.toString());
      expect(report.warnings, isEmpty);
    });
  });

  group('整块缺 spellcasting 的施法职业（作者意图信号）', () {
    // `mode` 无从得知时，现有的 `mode != none` 分支一条都不报；补判只能靠作者意图：
    // 条目 `rules` 里有 `optionType == 'spell'` 的选择（`rules.choices` 或
    // `rules.progression[].choices`）。
    Map<String, Object?> spellChoice([String id = 'spells']) => {
      'id': id,
      'optionType': 'spell',
      'minimum': 1,
      'maximum': 1,
    };

    test('rules.choices 有法术选择却无 spellcasting → missingCoreField warning', () async {
      final report = await importer.previewJson(
        packageJson(
          entry: classEntry(
            slug: 'homebrew-sage',
            structured: {
              'classRules': {'hitDie': 10},
            },
            rules: {
              'choices': [spellChoice()],
            },
          ),
        ),
      );
      expect(report.valid, isTrue, reason: report.errors.toString());
      final warning = report.warnings.single;
      expect(warning.message, contains('missingCoreField'));
      expect(warning.path, r'$.entries[0].structured.classRules.spellcasting');
    });

    test('progression[].choices 的法术选择同样算意图；声明了 spellcasting 就不报', () async {
      final report = await importer.previewJson(
        packageJson(
          entry: classEntry(
            slug: 'homebrew-sage',
            structured: {
              'classRules': {
                'hitDie': 10,
                'spellcasting': {
                  'mode': 'prepared',
                  'ability': 'cha',
                  'archetype': 'half-caster',
                  'prepared': {'1': 4},
                },
              },
            },
            rules: {
              'progression': [
                {
                  'levels': [1],
                  'choices': [spellChoice()],
                },
              ],
            },
          ),
        ),
      );
      expect(report.valid, isTrue, reason: report.errors.toString());
      expect(report.warnings, isEmpty);
    });

    test('没有法术选择的普通职业不触发（意图信号是唯一判据）', () async {
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
                  'id': 'skills',
                  'optionType': 'skill',
                  'minimum': 2,
                  'maximum': 2,
                  // §5.1 invalidSkillCount：技能选择的候选必须由内联 options
                  // 给出且数量覆盖 minimum/maximum（判据在导入期）。
                  'options': <Object?>['洞悉', '医药', '说服'],
                },
              ],
            },
          ),
        ),
      );
      expect(report.valid, isTrue, reason: report.errors.toString());
      expect(report.warnings, isEmpty);
    });

    test('slug 命中内置职业且档案提供 spellcasting → 不误报', () async {
      // 反例防线：条目按字段**继承**档案（§3.6），部分声明 classRules 的内置职业
      // （这里只覆盖 hitDie）在运行期拿得到档案的 spellcasting；"条目没写"不是缺省。
      // 少了这层判据，一个只覆盖生命骰的 wizard 房规包就会被误报。
      final report = await importer.previewJson(
        packageJson(
          entry: classEntry(
            slug: 'wizard',
            structured: {
              'classRules': {'hitDie': 6},
            },
            rules: {
              'choices': [spellChoice()],
            },
          ),
        ),
      );
      expect(report.valid, isTrue, reason: report.errors.toString());
      expect(report.warnings, isEmpty);
    });
  });

  group('formatVersion 严格判据', () {
    test('3.5 不是 v3：不截断成 3 放行，报 unsupportedFormatVersion', () async {
      final report = await importer.previewJson(
        packageJson(
          formatVersion: 3.5,
          entry: classEntry(
            structured: {
              'classRules': {'hitDie': 10},
            },
          ),
        ),
      );
      expect(report.valid, isFalse);
      final error = report.errors.singleWhere(
        (e) => e.path == r'$.formatVersion',
      );
      expect(error.message, contains('3.5'));
      expect(error.message, contains('unsupportedFormatVersion'));
    });

    test('1 / 2 也带 unsupportedFormatVersion code', () async {
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
        final error = report.errors.singleWhere(
          (e) => e.path == r'$.formatVersion',
        );
        expect(error.message, contains('unsupportedFormatVersion'));
      }
    });

    test('缺省 / 非数字分支同样带 unsupportedFormatVersion code', () async {
      // 三条失败分支对作者是同一件事："这个版本不受支持，请重新生成"，
      // code 不该只在"数值不等于 3"那一条出现。
      String documentWith(Object? version, {required bool omit}) => jsonEncode({
        if (!omit) 'formatVersion': version,
        'id': 'diag-pack',
        'name': 'Diag pack',
        'version': '1.0.0',
        'locale': 'zh-CN',
        'system': 'dnd5e-2024',
        'entryCount': 1,
        'entries': [
          classEntry(
            structured: {
              'classRules': {'hitDie': 10},
            },
          ),
        ],
      });

      for (final (label, document) in <(String, String)>[
        ('缺省', documentWith(null, omit: true)),
        ('非数字', documentWith('3', omit: false)),
      ]) {
        final report = await importer.previewJson(document);
        expect(report.valid, isFalse, reason: '$label 必须被拒绝');
        final error = report.errors.singleWhere(
          (e) => e.path == r'$.formatVersion',
        );
        expect(error.message, contains('unsupportedFormatVersion'), reason: label);
        expect(error.message, contains('formatVersion 3'), reason: label);
      }
    });
  });

  group('装配错误不被降级', () {
    test('档案未装配时 previewJson 原样抛 StateError（不是 invalid entry）', () async {
      Dnd5eRules.resetForTests();
      try {
        await expectLater(
          importer.previewJson(packageJson(entry: classEntry(slug: 'fighter'))),
          throwsA(isA<StateError>()),
        );
      } finally {
        await Dnd5eRules.configure(await loadBuiltinProfileForTest());
      }
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

  // ── 阻塞项 1：`resources[].maximum.formula = "ability:<键>"` 的属性键 ──
  group('资源 maximum.formula 的属性键（§3.12、§5.1 unknownAbility）', () {
    Map<String, Object?> classRulesWithResource(String formula) => {
      'classRules': {
        'hitDie': 10,
        'resources': <Object?>[
          {
            'id': 'surge',
            'name': '星界涌动',
            'recovery': 'longRest',
            'maximum': {'formula': formula},
          },
        ],
      },
    };

    test('ability:wiz（三字母笔误）→ unknownAbility，path 到 maximum.formula', () async {
      final report = await importer.previewJson(
        packageJson(
          entry: classEntry(
            slug: 'homebrew-sage',
            structured: classRulesWithResource('ability:wiz'),
          ),
        ),
      );
      expect(report.valid, isFalse);
      final error = report.errors.singleWhere(
        (e) => e.message.contains('unknownAbility'),
      );
      expect(
        error.path,
        r'$.entries[0].structured.classRules.resources[0].maximum.formula',
      );
      expect(error.message, contains('ability:wiz'));
    });

    test('ability:wis 落在档案 abilities 内 → 放行', () async {
      final report = await importer.previewJson(
        packageJson(
          entry: classEntry(
            slug: 'homebrew-sage',
            structured: classRulesWithResource('ability:wis'),
          ),
        ),
      );
      expect(report.valid, isTrue, reason: report.errors.toString());
      expect(
        report.errors.where((e) => e.message.contains('unknownAbility')),
        isEmpty,
      );
    });
  });

  // ── 阻塞项 3：未知 grant kind 的 path 精确到 kind 字段 ──
  group('未知 grant kind：path 精确到 kind 字段（§5.1 unknownGrantKind）', () {
    Future<ContentImportReport> reportFor(Map<String, Object?> rules) =>
        importer.previewJson(
          packageJson(
            entry: classEntry(
              slug: 'homebrew-sage',
              structured: {
                'classRules': {'hitDie': 10},
              },
              rules: rules,
            ),
          ),
        );

    Map<String, Object?> grant(String kind) => {
      'id': 'res',
      'kind': kind,
      'label': '资源',
    };

    final cases = <String, (Map<String, Object?>, String)>{
      'rules.grants[k].kind': (
        {
          'grants': [grant('resource')],
        },
        r'$.entries[0].rules.grants[0].kind',
      ),
      'rules.progression[j].grants[k].kind': (
        {
          'progression': [
            {
              'levels': [1],
              'grants': [grant('conditionResistance')],
            },
          ],
        },
        r'$.entries[0].rules.progression[0].grants[0].kind',
      ),
      'rules.choices[c].options[o].grants[k].kind': (
        {
          'choices': [
            {
              'id': 'pick',
              'label': '选择',
              'optionType': 'feat',
              'minimum': 1,
              'maximum': 1,
              'options': [
                {
                  'id': 'vigor',
                  'label': '活力',
                  'grants': [grant('note')],
                },
              ],
            },
          ],
        },
        r'$.entries[0].rules.choices[0].options[0].grants[0].kind',
      ),
      'rules.progression[j].choices[c].options[o].grants[k].kind': (
        {
          'progression': [
            {
              'levels': [1],
              'choices': [
                {
                  'id': 'pick',
                  'label': '选择',
                  'optionType': 'feat',
                  'minimum': 1,
                  'maximum': 1,
                  'options': [
                    {
                      'id': 'vigor',
                      'label': '活力',
                      'grants': [grant('resource')],
                    },
                  ],
                },
              ],
            },
          ],
        },
        r'$.entries[0].rules.progression[0].choices[0].options[0].grants[0].kind',
      ),
    };

    cases.forEach((label, testCase) {
      final (rules, expectedPath) = testCase;
      test('$label → path 精确，且不降级成 invalid entry', () async {
        final report = await reportFor(rules);
        expect(report.valid, isFalse);
        expect(
          report.errors.map((e) => e.path),
          contains(expectedPath),
          reason: report.errors.toString(),
        );
        expect(
          report.errors
              .firstWhere((e) => e.path == expectedPath)
              .message,
          contains('unknownGrantKind'),
        );
        expect(
          report.errors.any((e) => e.message.contains('invalid entry')),
          isFalse,
          reason: report.errors.toString(),
        );
      });
    });

    test('kind: "resource" 的消息指向替代写法 classRules.resources', () async {
      final report = await reportFor({
        'grants': [grant('resource')],
      });
      expect(report.errors.single.message, contains('classRules.resources'));
    });

    test('合法 kind 仍然放行', () async {
      final report = await reportFor({
        'grants': [grant('feature')],
      });
      expect(report.valid, isTrue, reason: report.errors.toString());
    });
  });

  // ── 阻塞项 3 附带：progression 的形状也走精确 path ──
  group('progression 形状：path 精确到字段', () {
    Future<ContentImportReport> reportFor(Map<String, Object?> progression) =>
        importer.previewJson(
          packageJson(
            entry: classEntry(
              slug: 'homebrew-sage',
              structured: {
                'classRules': {'hitDie': 10},
              },
              rules: {
                'progression': [progression],
              },
            ),
          ),
        );

    test('旧的 level 键 → unknownField，path 到 progression[0].level', () async {
      final report = await reportFor({
        'level': 1,
        'grants': <Object?>[],
      });
      expect(report.valid, isFalse);
      expect(
        report.errors.map((e) => e.path),
        contains(r'$.entries[0].rules.progression[0].level'),
      );
      expect(
        report.errors.any((e) => e.message.contains('invalid entry')),
        isFalse,
        reason: report.errors.toString(),
      );
    });

    test('levels 越界 → invalidTable，path 到具体元素', () async {
      final report = await reportFor({'levels': [21]});
      expect(report.valid, isFalse);
      expect(
        report.errors.map((e) => e.path),
        contains(r'$.entries[0].rules.progression[0].levels[0]'),
      );
      expect(
        report.errors.any((e) => e.message.contains('invalid entry')),
        isFalse,
        reason: report.errors.toString(),
      );
    });
  });

  // ── 阻塞项 4：选择系统"声明了但用不了"的字段一律拒收（§3.10.3-7）──
  group('§3.10.3-7：选择系统字段声明了但用不了必须报 error', () {
    Future<ContentImportReport> reportFor(Map<String, Object?> extra) =>
        importer.previewJson(
          packageJson(
            entry: classEntry(
              slug: 'homebrew-sage',
              structured: {
                'classRules': {'hitDie': 10},
              },
              rules: {
                'choices': [
                  {
                    'id': 'pick',
                    'label': '选择',
                    'optionType': 'feat',
                    'minimum': 1,
                    'maximum': 1,
                    'optionTags': ['fighting-style'],
                    ...extra,
                  },
                ],
              },
            ),
          ),
        );

    test('repeatable → unsupportedChoiceField，path 到字段', () async {
      final report = await reportFor({'repeatable': true});
      expect(report.valid, isFalse);
      final error = report.errors.single;
      expect(error.path, r'$.entries[0].rules.choices[0].repeatable');
      expect(error.message, contains('unsupportedChoiceField'));
    });

    test('group / help → unsupportedChoiceField，各有自己的 path', () async {
      final report = await reportFor({'group': '1 级', 'help': '说明'});
      expect(report.valid, isFalse);
      expect(
        report.errors.map((e) => e.path),
        containsAll(<String>[
          r'$.entries[0].rules.choices[0].group',
          r'$.entries[0].rules.choices[0].help',
        ]),
      );
      expect(
        report.errors.every((e) => e.message.contains('unsupportedChoiceField')),
        isTrue,
      );
    });

    test('countsToward → invalidCountsToward，path 到字段', () async {
      final report = await reportFor({'countsToward': 'prepared'});
      expect(report.valid, isFalse);
      final error = report.errors.single;
      expect(error.path, r'$.entries[0].rules.choices[0].countsToward');
      expect(error.message, contains('invalidCountsToward'));
    });

    test('requires → invalidRequires，path 到字段', () async {
      final report = await reportFor({
        'requires': [
          {'ability': 'cha', 'minimum': 13},
        ],
      });
      expect(report.valid, isFalse);
      final error = report.errors.single;
      expect(error.path, r'$.entries[0].rules.choices[0].requires');
      expect(error.message, contains('invalidRequires'));
    });

    test('内联选项 grants → unsupportedChoiceField，path 到 grants', () async {
      final report = await reportFor({
        'options': <Object?>[
          {
            'id': 'poise',
            'label': '星界之势',
            'grants': <Object?>[
              {'id': 'g', 'kind': 'feature', 'label': '星界之势'},
            ],
          },
        ],
      });
      expect(report.valid, isFalse);
      final error = report.errors.singleWhere(
        (e) => e.message.contains('unsupportedChoiceField'),
      );
      expect(error.path, r'$.entries[0].rules.choices[0].options[0].grants');
    });

    test('都不带 → 放行（拒收只针对这批字段，不是拒绝整个选择模型）', () async {
      final report = await reportFor(const <String, Object?>{});
      expect(report.valid, isTrue, reason: report.errors.toString());
    });
  });

  // ── 阻塞项 5：§5.1 形状/参照 code 精确 path ──
  group('§5.1 形状/参照 code', () {
    Future<ContentImportReport> reportForChoice(Map<String, Object?> choice) =>
        importer.previewJson(
          packageJson(
            entry: classEntry(
              slug: 'homebrew-sage',
              structured: {
                'classRules': {'hitDie': 10},
              },
              rules: {
                'choices': [
                  {
                    'id': 'pick',
                    'label': '选择',
                    'minimum': 1,
                    'maximum': 1,
                    ...choice,
                  },
                ],
              },
            ),
          ),
        );

    test('unknownOptionType → path 到 optionType', () async {
      final report = await reportForChoice({
        'optionType': 'savingThrow',
        'optionTags': ['x'],
      });
      expect(report.valid, isFalse);
      final error = report.errors.singleWhere(
        (e) => e.message.contains('unknownOptionType'),
      );
      expect(error.path, r'$.entries[0].rules.choices[0].optionType');
      expect(error.message, contains('savingThrow'));
    });

    test('invalidChoiceRange（maximum < minimum）→ path 到 maximum', () async {
      final report = await reportForChoice({
        'optionType': 'feat',
        'optionTags': ['x'],
        'minimum': 2,
        'maximum': 1,
      });
      expect(report.valid, isFalse);
      final error = report.errors.singleWhere(
        (e) => e.message.contains('invalidChoiceRange'),
      );
      expect(error.path, r'$.entries[0].rules.choices[0].maximum');
    });

    test('duplicateOptionId：内联选项 id 重复 → path 到第二个选项', () async {
      final report = await reportForChoice({
        'optionType': 'feat',
        'options': <Object?>['决斗', '决斗'],
      });
      expect(report.valid, isFalse);
      final error = report.errors.singleWhere(
        (e) => e.message.contains('duplicateOptionId'),
      );
      expect(error.path, r'$.entries[0].rules.choices[0].options[1]');
    });

    test('duplicateOptionId：内联 id 与 optionEntryIds 冲突', () async {
      final report = await reportForChoice({
        'optionType': 'feat',
        'optionEntryIds': <Object?>['diag-pack:feat/a'],
        'options': <Object?>[
          {'id': 'diag-pack:feat/a', 'label': 'A'},
        ],
      });
      expect(report.valid, isFalse);
      final error = report.errors.singleWhere(
        (e) => e.message.contains('duplicateOptionId'),
      );
      expect(error.path, r'$.entries[0].rules.choices[0].options[0].id');
    });

    test('invalidValueOption：值类型带 optionEntryIds', () async {
      final report = await reportForChoice({
        'optionType': 'skill',
        'optionEntryIds': <Object?>['diag-pack:skill/stealth'],
        'options': <Object?>['隐匿'],
      });
      expect(report.valid, isFalse);
      final error = report.errors.singleWhere(
        (e) => e.message.contains('invalidValueOption'),
      );
      expect(error.path, r'$.entries[0].rules.choices[0].optionEntryIds');
    });

    test('invalidValueOption：值类型没有内联 options', () async {
      final report = await reportForChoice({'optionType': 'skill'});
      expect(report.valid, isFalse);
      expect(
        report.errors.map((e) => e.path),
        contains(r'$.entries[0].rules.choices[0].options'),
      );
    });

    test('unknownSkill → path 到具体选项', () async {
      final report = await reportForChoice({
        'optionType': 'skill',
        'options': <Object?>['特技'],
      });
      expect(report.valid, isFalse);
      final error = report.errors.singleWhere(
        (e) => e.message.contains('unknownSkill'),
      );
      expect(error.path, r'$.entries[0].rules.choices[0].options[0]');
      expect(error.message, contains('特技'));
    });

    test('invalidSkillCount：minimum 大于候选数 → path 到 minimum', () async {
      final report = await reportForChoice({
        'optionType': 'skill',
        'minimum': 3,
        'maximum': 3,
        'options': <Object?>['洞悉', '医药'],
      });
      expect(report.valid, isFalse);
      final error = report.errors.singleWhere(
        (e) => e.path == r'$.entries[0].rules.choices[0].minimum',
      );
      expect(error.message, contains('invalidSkillCount'));
    });

    test('invalidOptionRef：optionEntryIds 不存在 → error 带 code', () async {
      final report = await reportForChoice({
        'optionType': 'feat',
        'optionEntryIds': <Object?>['diag-pack:feat/missing'],
      });
      expect(report.valid, isFalse);
      final error = report.errors.singleWhere(
        (e) => e.path == r'$.entries[0].rules.choices[0].optionEntryIds[0]',
      );
      expect(error.message, contains('invalidOptionRef'));
      expect(error.message, contains('does not exist'));
    });
  });
}
