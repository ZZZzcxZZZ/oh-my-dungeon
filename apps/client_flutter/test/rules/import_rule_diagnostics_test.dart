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
import 'package_json_test_support.dart';
import 'rule_profile_test_support.dart';

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

  group('priority（S3 决策 D2）', () {
    test('缺省 0（旧包行为不变），合法整数透传到 report', () async {
      final report = await importer.previewJson(
        packageJson(
          entry: classEntry(structured: {'classRules': {'hitDie': 8}}),
          priority: 30,
        ),
      );
      expect(report.valid, isTrue, reason: '${report.errors}');
      expect(report.priority, 30);

      final absent = await importer.previewJson(
        packageJson(
          entry: classEntry(structured: {'classRules': {'hitDie': 8}}),
        ),
      );
      expect(absent.valid, isTrue);
      expect(absent.priority, 0);
      // 0 也要显式接受（不是"没写"的特例）。
      final zero = await importer.previewJson(
        packageJson(
          entry: classEntry(structured: {'classRules': {'hitDie': 8}}),
          priority: 0,
        ),
      );
      expect(zero.valid, isTrue);
      expect(zero.priority, 0);
    });

    test('非整数 / 负数 / 越界 → invalidPriority，path 精确到顶层 priority 字段', () async {
      for (final bad in <Object?>['30', -1, 1.5, 1001]) {
        final report = await importer.previewJson(
          packageJson(
            entry: classEntry(structured: {'classRules': {'hitDie': 8}}),
            priority: bad,
          ),
        );
        expect(report.valid, isFalse, reason: '$bad');
        final error = report.errors.singleWhere(
          (e) => e.path == r'$.priority',
        );
        expect(error.message, contains('invalidPriority'), reason: '$bad');
        expect(report.priority, 0, reason: '非法值不落库，保持缺省 0');
      }
    });

    test('importReport 从 report 重建 manifest 时带上 priority', () async {
      final report = await importer.previewJson(
        packageJson(
          entry: classEntry(
            slug: 'homebrew-sage',
            structured: {'classRules': {'hitDie': 8}},
          ),
          priority: 40,
        ),
      );
      expect(report.valid, isTrue);
      await importer.importReport(report);
      final packages = await repository.watchPackages().first;
      expect(packages.single.priority, 40);
      expect(
        await repository.packagePriorities(),
        {'diag-pack': 40},
        reason: 'packagePriorities() 投影与落库值一致',
      );
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

    test('classRules.mode 非法值阻断整包，path 精确（invalidMergeMode）', () async {
      final report = await importer.previewJson(
        packageJson(
          entry: classEntry(
            structured: {
              'classRules': {'mode': 'merge', 'hitDie': 10},
            },
          ),
        ),
      );
      expect(report.valid, isFalse);
      final error = report.errors.singleWhere(
        (e) => e.message.contains('invalidMergeMode'),
      );
      expect(
        error.path,
        r'$.entries[0].structured.classRules.mode',
      );
      expect(error.message, contains('spellcasting.mode'));
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

    test('补丁资源缺 name / maximum 且档案没有同 id → incompleteResourcePatch', () async {
      final report = await importer.previewJson(
        packageJson(
          entry: classEntry(
            slug: 'fighter', // 命中内置 slug，必须显式 classRules
            structured: {
              'classRules': {
                'resources': [
                  {'id': 'unknown-resource', 'recovery': 'shortRest'},
                ],
              },
            },
          ),
          id: 'patch-pack',
        ),
      );
      expect(report.valid, isFalse);
      final error = report.errors.singleWhere(
        (e) => e.path == r'$.entries[0].structured.classRules.resources[0].id',
      );
      expect(error.message, contains('incompleteResourcePatch'));
      expect(error.message, contains('unknown-resource'));
    });

    test('补丁资源缺 name / maximum 但档案有同 id → 放行，不报 incompleteResourcePatch', () async {
      final report = await importer.previewJson(
        packageJson(
          entry: classEntry(
            slug: 'fighter',
            structured: {
              'classRules': {
                'resources': [
                  {'id': 'second_wind', 'maximum': 4},
                ],
              },
            },
          ),
          id: 'patch-pack',
        ),
      );
      expect(
        report.errors.any((e) => e.message.contains('incompleteResourcePatch')),
        isFalse,
        reason: '${report.errors}',
      );
    });
    test('replace 独占：档案的 spellcasting 不再算"可继承" → missingCoreField', () async {
      // 反例一：`{"mode":"replace","spellcasting":{"prepared":…}}` + slug wizard。
      // 旧实现拿**原始档案**判断可继承性，档案 wizard 有 spellcasting ⇒ 不报；
      // 运行期 replace 把档案截断，mode 缺省 none ⇒ prepared 静默消失。
      final report = await importer.previewJson(
        packageJson(
          entry: classEntry(
            slug: 'wizard',
            structured: {
              'classRules': {
                'mode': 'replace',
                'spellcasting': {
                  'prepared': {'1': 4},
                },
              },
            },
          ),
        ),
      );
      final warning = report.warnings.singleWhere(
        (w) => w.path == r'$.entries[0].structured.classRules.spellcasting',
      );
      expect(warning.message, contains('missingCoreField'));
      expect(warning.message, contains('mode'));
    });

    test('replace 独占：档案资源不再补齐 → incompleteResourcePatch', () async {
      // 反例二：`{"mode":"replace","resources":[{"id":"rage"}]}`。旧实现用档案的
      // rage 补齐 name / maximum 而放行；运行期 replace 下档案不参与，合并后
      // maximum 为 null ⇒ 整条资源被跳过。
      final report = await importer.previewJson(
        packageJson(
          entry: classEntry(
            slug: 'barbarian',
            structured: {
              'classRules': {
                'mode': 'replace',
                'resources': [
                  {'id': 'rage'},
                ],
              },
            },
          ),
        ),
      );
      expect(report.valid, isFalse);
      final error = report.errors.singleWhere(
        (e) =>
            e.path ==
            r'$.entries[0].structured.classRules.resources[0].id',
      );
      expect(error.message, contains('incompleteResourcePatch'));
      expect(error.message, contains('rage'));
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

    test('写了 spellcasting 却没写 mode 且档案无可继承 → missingCoreField', () async {
      // 唯一写出来的列（prepared）会被 parse 的缺省 `mode: none` 静默短路：
      // 原有两条分支都进不去（`mode != none` 为假、块非 null），必须补报。
      final report = await importer.previewJson(
        packageJson(
          entry: classEntry(
            slug: 'homebrew-sage',
            structured: {
              'classRules': {
                'hitDie': 10,
                'spellcasting': {
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
      expect(warning.message, contains('mode'));
    });

    test('写了 spellcasting 却没写 mode，但档案同 slug 提供施法 → 不误报', () async {
      // 档案已提供 `mode: prepared`：条目省略 mode 是"继续继承"，声明的 prepared
      // 列正常生效，不报缺失（§3.6 字段 / 列级继承）。
      final report = await importer.previewJson(
        packageJson(
          entry: classEntry(
            slug: 'wizard',
            structured: {
              'classRules': {
                'hitDie': 6,
                'spellcasting': {
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

  // ── 选择系统字段（§3.10）：放行 + 真正的取值/引用校验（§5.1）──
  group('选择系统字段（§3.10）：放行 + 真正的取值/引用校验', () {
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

    test('repeatable / group / help 放行', () async {
      final report = await reportFor({
        'repeatable': true,
        'group': '1 级',
        'help': '说明',
      });
      expect(report.valid, isTrue, reason: report.errors.toString());
    });

    test('内联选项的 grants 放行，且仍做 kind 校验', () async {
      final ok = await reportFor({
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
      expect(ok.valid, isTrue, reason: ok.errors.toString());

      final bad = await reportFor({
        'options': <Object?>[
          {
            'id': 'poise',
            'label': '星界之势',
            'grants': <Object?>[
              {'id': 'g', 'kind': 'resource', 'label': '旧写法'},
            ],
          },
        ],
      });
      expect(bad.valid, isFalse);
      expect(
        bad.errors.single.path,
        r'$.entries[0].rules.choices[0].options[0].grants[0].kind',
      );
      expect(bad.errors.single.message, contains('unknownGrantKind'));
    });

    test('countsToward：合法值放行，非法值报 invalidCountsToward', () async {
      expect((await reportFor({'countsToward': 'prepared'})).valid, isTrue);
      expect((await reportFor({'countsToward': 'spellbook'})).valid, isTrue);
      expect((await reportFor({'countsToward': 'known'})).valid, isTrue);
      expect(
        (await reportFor({'countsToward': 'cantrips'})).valid,
        isTrue,
        reason: '戏法池（决策 D8）：额度来自职业 cantrips 列',
      );
      expect((await reportFor({})).valid, isTrue, reason: '省略合法');

      final bad = await reportFor({'countsToward': 'rituals'});
      expect(bad.valid, isFalse);
      final error = bad.errors.single;
      expect(error.path, r'$.entries[0].rules.choices[0].countsToward');
      expect(error.message, contains('invalidCountsToward'));
    });

    test('requires：合法形态放行；引用不存在 / 能力非法 / minimum 非正报 invalidRequires', () async {
      expect(
        (await reportFor({
          'optionType': 'classFeature',
          'optionTags': ['x'],
          'requires': [
            {'ability': 'cha', 'minimum': 13},
          ],
        })).valid,
        isTrue,
      );

      for (final (bad, path) in <(Map<String, Object?>, String)>[
        (
          {
            'requires': [
              {'choice': 'missing-choice', 'option': 'x'},
            ],
          },
          r'$.entries[0].rules.choices[0].requires[0].choice',
        ),
        (
          {
            'requires': [
              {'ability': 'luck', 'minimum': 13},
            ],
          },
          r'$.entries[0].rules.choices[0].requires[0].ability',
        ),
        (
          {
            'requires': [
              {'ability': 'cha', 'minimum': 0},
            ],
          },
          r'$.entries[0].rules.choices[0].requires[0].minimum',
        ),
      ]) {
        final report = await reportFor(bad);
        expect(report.valid, isFalse, reason: '$bad');
        expect(
          report.errors.map((e) => e.path),
          contains(path),
          reason: '$bad → ${report.errors}',
        );
        expect(
          report.errors.firstWhere((e) => e.path == path).message,
          contains('invalidRequires'),
        );
      }
    });

    test('requires 形态白名单：缺 minimum / 跨形态 / 多余字段都报精确 path 的 invalidRequires', () async {
      // 正例：两种形态各自只带自己的字段。
      expect(
        (await reportFor({
          'optionType': 'classFeature',
          'optionTags': ['x'],
          'requires': [
            {'choice': 'pick'},
            {'ability': 'cha', 'minimum': 13},
          ],
        })).valid,
        isTrue,
      );

      // 三个反例（每一行是"原始输入 → 精确到字段的 path"）：
      for (final (bad, path) in <(Map<String, Object?>, String)>[
        // ability 形态缺 `minimum`：此前原始遍放过，解析层抛 FormatException，
        // 被降级成 `$.entries[0]` + `invalid entry`。
        (
          {
            'requires': [
              {'ability': 'cha'},
            ],
          },
          r'$.entries[0].rules.choices[0].requires[0].minimum',
        ),
        // choice 形态写了另一形态的 `minimum`：多余字段，此前同样静默通过。
        (
          {
            'requires': [
              {'choice': 'pick', 'minimum': 2},
            ],
          },
          r'$.entries[0].rules.choices[0].requires[0].minimum',
        ),
        // ability 形态写了另一形态的 `option`：多余字段。
        (
          {
            'requires': [
              {'ability': 'cha', 'minimum': 13, 'option': 'x'},
            ],
          },
          r'$.entries[0].rules.choices[0].requires[0].option',
        ),
      ]) {
        final report = await reportFor(bad);
        expect(report.valid, isFalse, reason: '$bad');
        final error = report.errors.single;
        expect(error.path, path, reason: '$bad → ${report.errors}');
        expect(error.message, contains('invalidRequires'));
        // 不得退化成"path 只到条目"的笼统误差（§5.1 path 精度）。
        expect(error.path, isNot(r'$.entries[0]'));
        expect(error.message, isNot(contains('invalid entry')));
      }
    });

    test('requires 的作用域取并集：祖先定义的合法 option 不被误拒（与运行期同源）', () async {
      // 同一条选择 id `pick` 同时出现在条目与其 `featureOf` 祖先上：运行期
      // `RuleChoiceSemantics.requiresSatisfied` 把作用域内所有同 choiceId 键的
      // 选中值取**并集**，所以祖先声明的 `ancestor-option` 是合法引用；导入期
      // 若只取**首个命中**（条目自己）就会误拒。
      Future<ContentImportReport> report(String option) => importer.previewJson(
        jsonEncode({
          'formatVersion': 3,
          'id': 'diag-pack',
          'name': 'Diag pack',
          'version': '1.0.0',
          'locale': 'zh-CN',
          'system': 'dnd5e-2024',
          'entryCount': 2,
          'entries': [
            {
              'id': 'diag-pack:classFeature/child',
              'type': 'classFeature',
              'slug': 'child',
              'name': 'Child',
              'body': <Object?>[],
              'revision': 1,
              'relations': [
                {'type': 'featureOf', 'targetId': 'diag-pack:class/ancestor'},
              ],
              'rules': {
                'choices': [
                  {
                    'id': 'pick',
                    'label': '选择',
                    'optionType': 'feat',
                    'optionTags': ['child-tag'],
                    'requires': [
                      {'choice': 'pick', 'option': option},
                    ],
                  },
                ],
              },
            },
            {
              'id': 'diag-pack:class/ancestor',
              'type': 'class',
              'slug': 'ancestor',
              'name': 'Ancestor',
              'body': <Object?>[],
              'revision': 1,
              'rules': {
                'choices': [
                  {
                    'id': 'pick',
                    'label': '选择',
                    'optionType': 'feat',
                    'options': [
                      {'id': 'ancestor-option', 'label': '祖先选项'},
                    ],
                  },
                ],
              },
            },
          ],
        }),
      );

      final union = await report('ancestor-option');
      expect(union.valid, isTrue, reason: union.errors.toString());
      expect(union.errors, isEmpty);

      // 反向对照：真正不在并集里的 option 仍然要报错（修成并集不等于放宽）。
      final missing = await report('missing-option');
      expect(missing.valid, isFalse);
      final error = missing.errors.single;
      expect(
        error.path,
        r'$.entries[0].rules.choices[0].requires[0].option',
      );
      expect(error.message, contains('invalidRequires'));
    });

    test('invalidAutoGrant：条目类型的字符串选项无法推断 grants', () async {
      final report = await reportFor({
        'optionType': 'classFeature',
        'optionTags': ['x'],
        'options': <Object?>['星界之势'],      });
      expect(report.valid, isFalse);
      final error = report.errors.singleWhere(
        (e) => e.message.contains('invalidAutoGrant'),
      );
      expect(error.path, r'$.entries[0].rules.choices[0].options[0]');
      expect(error.message, contains('星界之势'));
    });

    test('invalidAutoGrant 不适用于只记录选择的值类型与显式 grants 的对象选项', () async {
      // skill / ability / language / damageType / weaponMastery / value 的字符串元素
      for (final type in [
        'skill',
        'ability',
        'language',
        'damageType',
        'weaponMastery',
        'value',
      ]) {
        final report = await reportFor({
          'optionType': type,
          // 值类型选择的候选只允许内联 `options`（`invalidValueOption`），
          // 因此必须显式清掉夹具默认的条目标签。
          'optionTags': <Object?>[],
          'options': <Object?>[type == 'skill' ? '察觉' : 'cha'],
        });
        expect(report.valid, isTrue, reason: '$type → ${report.errors}');
      }
      // 条目类型的**对象**选项（显式给 id/label）不需要 grants
      final object = await reportFor({
        'optionType': 'classFeature',
        'optionTags': ['x'],
        'options': <Object?>[
          {'id': 'poise', 'label': '星界之势'},
        ],
      });
      expect(object.valid, isTrue, reason: object.errors.toString());
    });

    test('字符串简写的 ability 候选必须是档案属性键（unknownAbility）', () async {
      final report = await reportFor({
        'optionType': 'ability',
        'optionTags': <Object?>[],
        'options': <Object?>['luck'],
      });
      expect(report.valid, isFalse);
      final error = report.errors.single;
      expect(error.message, contains('unknownAbility'));
      expect(error.path, r'$.entries[0].rules.choices[0].options[0]');
      expect(error.message, contains('luck'));
    });

    test('invalidAutoGrant：值类型的 ability 选项 data.value 非正整数', () async {
      final report = await reportFor({
        'optionType': 'ability',
        'optionTags': <Object?>[],
        'options': <Object?>[
          {
            'id': 'str',
            'label': '力量',
            'data': {'value': 0},
          },
        ],
      });
      expect(report.valid, isFalse);
      final error = report.errors.single;
      expect(error.path, r'$.entries[0].rules.choices[0].options[0]');
      expect(error.message, contains('invalidAutoGrant'));
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

    test('unknownField：选择对象里的拼错字段名不再被静默忽略', () async {
      // `grup` 是 `group` 的拼错：解析层只读白名单键，会静默忽略它——§5.1 的
      // `unknownField` 承诺必须由导入期原始遍落实，path 精确到该键。
      final report = await reportForChoice({
        'optionType': 'feat',
        'optionTags': ['x'],
        'grup': '技能',
      });
      expect(report.valid, isFalse);
      final error = report.errors.single;
      expect(error.path, r'$.entries[0].rules.choices[0].grup');
      expect(error.message, contains('unknownField'));

      // 白名单内的字段全集一个都不误报。
      final ok = await reportForChoice({
        'optionType': 'feat',
        'optionTags': ['x'],
        'group': '技能',
        'help': '说明',
        'repeatable': true,
        'recommendedEntryIds': <Object?>[],
      });
      expect(
        ok.errors.any((e) => e.message.contains('unknownField')),
        isFalse,
        reason: ok.errors.toString(),
      );
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

    // 阻塞项 2：非数字的 `minimum` / `maximum` 曾在原始 JSON 校验里用
    // `as num?` 强转，畸形输入直接抛 `_TypeError`；该调用点在任何 `try` 之外，
    // UI 只接 `FormatException`，于是导入变成未捕获异常。必须降级为**精确 path**
    // 的诊断，绝不抛异常。
    for (final malformed in <Map<String, Object?>>[
      {'minimum': '2'},
      {'maximum': '2'},
      {'minimum': null},
      {'maximum': <String, Object?>{}},
    ]) {
      final field = malformed.keys.single;
      test('非数字 $field 不抛异常且 path 精确到该字段', () async {
        // 未捕获异常会让这一行直接让用例失败（不再需要 catch 兜底）。
        final report = await reportForChoice({
          'optionType': 'feat',
          'optionTags': ['x'],
          ...malformed,
        });
        expect(report.valid, isFalse, reason: 'malformed=$malformed');
        expect(
          report.errors.map((e) => e.path),
          contains(r'$.entries[0].rules.choices[0].' + field),
          reason: 'malformed=$malformed 的 error：${report.errors}',
        );
      });
    }

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
