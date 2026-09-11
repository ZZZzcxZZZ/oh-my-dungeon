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
