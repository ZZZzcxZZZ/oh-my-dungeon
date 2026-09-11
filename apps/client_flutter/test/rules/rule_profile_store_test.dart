import 'dart:convert';
import 'dart:io';

import 'package:dnd_table_client/src/features/characters/domain/dnd5e_rules.dart';
import 'package:dnd_table_client/src/features/rules/data/rule_profile_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'rule_profile_test_support.dart';

/// 每次重新解码，避免用例之间通过可变 Map 互相污染。
Map<String, Object?> readArchive() =>
    jsonDecode(File('assets/rules/dnd5e-2024.rules.json').readAsStringSync())
        as Map<String, Object?>;

void main() {
  // 全局 `test/flutter_test_config.dart` 已经把内置档案装配进 `Dnd5eRules`。
  // 本文件要验证"未装配"和"重复装配"两条边界，所以每个用例都从干净状态开始，
  // 结束后恢复全局装配（同文件后续用例仍然拿得到 profile）。
  setUp(Dnd5eRules.resetForTests);
  tearDown(() async {
    Dnd5eRules.resetForTests();
    await Dnd5eRules.configure(await loadBuiltinProfileForTest());
  });

  test('内置档案可加载并装配到 Dnd5eRules（不走 rootBundle）', () async {
    final raw = readArchive();
    final profile = await RuleProfileStore.loadBuiltin(
      readAsset: (path) async {
        expect(path, RuleProfileStore.assetPath);
        return raw;
      },
    );
    await Dnd5eRules.configure(profile);
    expect(Dnd5eRules.profile.classRules('barbarian')!.hitDie, 12);
  });

  test('档案写法的法术位计数数组被展开成 {环阶: 数量}（含 pact 的环阶）', () async {
    final profile = await RuleProfileStore.loadBuiltin(
      readAsset: (path) async => readArchive(),
    );

    // 普通施法者：行内下标 + 1 就是环阶。
    expect(profile.progression('full-caster')!.slots!.at(3), {'1': 4, '2': 2});
    expect(profile.progression('half-caster')!.slots!.at(5), {'1': 4, '2': 2});
    expect(profile.progression('third-caster')!.slots!.at(3), {'1': 2});
    expect(profile.progression('third-caster')!.slots!.at(1), isEmpty);

    // pact：环阶来自同级的 `slotLevel`，不是行下标（§3.3）。
    // 与旧 `Dnd5eRules.pactSlotMaximums` 的返回值一致。
    expect(profile.progression('pact')!.slots!.at(1), {'1': 1});
    expect(profile.progression('pact')!.slots!.at(5), {'3': 2});
    expect(profile.progression('pact')!.slots!.at(11), {'5': 3});
    expect(profile.progression('pact')!.slots!.at(17), {'5': 4});

    // `none` 仍是"没有法术位表"，不是空表。
    expect(profile.progression('none')!.slots, isNull);
  });

  test('档案写法非法时原样交回解析器：fail-fast，不静默修正', () async {
    final raw = readArchive();
    final progressions = Map<String, Object?>.from(raw['progressions']! as Map);
    final pact = Map<String, Object?>.from(progressions['pact']! as Map);
    // pact 的行只允许一个计数；写两个属非法，不得被"只取第一个"之类的方式修好。
    pact['slots'] = [
      [1, 2],
    ];
    progressions['pact'] = pact;
    raw['progressions'] = progressions;

    await expectLater(
      RuleProfileStore.loadBuiltin(readAsset: (path) async => raw),
      throwsA(isA<StateError>()),
    );
  });

  test('档案非法时 loadBuiltin 抛 StateError，不返回空档案', () async {
    // 契约 §4.4：内置档案缺失或非法即 fail-fast，绝不伪造占位值兜底。
    await expectLater(
      RuleProfileStore.loadBuiltin(
        readAsset: (path) async => <String, Object?>{},
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains(RuleProfileStore.assetPath),
        ),
      ),
    );
  });

  test('未装配或已装配后再次 configure 都抛错', () async {
    expect(() => Dnd5eRules.profile, throwsStateError);
    final profile = await loadBuiltinProfileForTest();
    await Dnd5eRules.configure(profile);
    expect(Dnd5eRules.profile.classRules('barbarian')!.hitDie, 12);
    expect(() => Dnd5eRules.configure(profile), throwsStateError);
  });
}
