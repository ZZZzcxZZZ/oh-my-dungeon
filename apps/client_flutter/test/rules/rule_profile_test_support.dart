// 规则档案相关测试的共享辅助：从仓库路径读内置档案。
//
// 走生产同一条 `RuleProfileStore.loadBuiltin`，只把资产读取换成 `File`：
// `flutter test` 的工作目录是包根，而 `rootBundle` 需要 widget binding，
// 纯 Dart 测试里不可用。
import 'dart:convert';
import 'dart:io';

import 'package:dnd_table_client/src/features/rules/data/rule_profile_store.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_profile.dart';

/// 从仓库路径读取并解析内置档案。
Future<RuleProfile> loadBuiltinProfileForTest() => RuleProfileStore.loadBuiltin(
  readAsset: (path) async =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>,
);

/// S3 列级合并测试共用的最小内置档案（只含数值，字段形状与真实档案一致）。
///
/// wizard：施法职业（full-caster / int / 稀疏 slots，`prepared` / `cantrips` 为短数组）
/// barbarian：非施法职业 + 一条可列级覆盖的资源
Map<String, Object?> overrideArchive() => {
  'rulebookVersion': 1,
  'system': 'dnd5e-2024',
  'abilities': ['str', 'dex', 'con', 'int', 'wis', 'cha'],
  'skills': [
    {'name': '奥秘', 'ability': 'int'},
    {'name': '运动', 'ability': 'str'},
  ],
  'progressions': {
    'none': {'slots': <Object?>[]},
    'full-caster': {
      'minimumLevel': 1,
      'slots': [
        {'1': 2},
        {'1': 3},
        {'1': 4, '2': 2},
        {'1': 4, '2': 3},
        {'1': 4, '2': 3, '3': 2},
      ],
      'maximumSpellLevel': [1, 1, 2, 2, 3],
    },
  },
  'classes': {
    'wizard': {
      'hitDie': 6,
      'savingThrowAbilities': ['int', 'wis'],
      'spellcasting': {
        'mode': 'prepared',
        'ability': 'int',
        'archetype': 'full-caster',
        'slots': {'5': {'1': 4, '2': 3, '3': 2}},
        'prepared': [4, 5, 6, 7, 9],
        'cantrips': [3, 3, 3, 4, 4],
        'maximumSpellLevel': [1, 1, 2, 2, 3],
      },
      'resources': <Object?>[],
    },
    'barbarian': {
      'hitDie': 12,
      'savingThrowAbilities': ['str', 'con'],
      'spellcasting': {'mode': 'none'},
      'resources': [
        {
          'id': 'rage',
          'name': '狂暴',
          'startsAtLevel': 1,
          'recovery': 'shortRestOne',
          'maximum': {
            'table': {'1': 2, '3': 3, '6': 4},
          },
        },
      ],
    },
  },
};

