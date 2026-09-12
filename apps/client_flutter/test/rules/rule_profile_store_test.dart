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

  test('生产资产路径：不注入读取器时 loadBuiltin 走 rootBundle 并成功', () async {
    // 其余用例都注入 `readAsset`（读仓库文件），于是把 `pubspec.yaml` 里的资产
    // 登记行删掉、或把资产挪走，整套测试仍然全绿——生产路径没有任何覆盖。
    // 这条用例**不注入**读取器，走 `rootBundle`（pubspec 登记的唯一消费者），
    // 因此登记失效就红。rootBundle 需要 widget binding，这里显式初始化。
    TestWidgetsFlutterBinding.ensureInitialized();
    final profile = await RuleProfileStore.loadBuiltin();
    expect(profile.abilities, hasLength(6));
    expect(profile.classRules('barbarian')!.hitDie, 12);
    expect(profile.classRules('wizard')!.spellcasting!.prepared!.at(1), 4);
  });

  test('档案声明了没有中文标签的属性键时 configure 抛错，且不留半配置状态', () async {
    // 属性键集合唯一权威是档案：档案放行了一个新属性键，界面就必须有它的中文名。
    // 缺标签不得静默丢弃（那会让"导入放行"的属性在运行期从界面消失）。
    final raw = readArchive();
    (raw['abilities']! as List).add('san');
    final profile = await RuleProfileStore.loadBuiltin(
      readAsset: (path) async => raw,
    );
    await expectLater(
      Dnd5eRules.configure(profile),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(contains('san'), contains('中文展示标签')),
        ),
      ),
    );
    // 抛错发生在装配之前：不得留下"半个档案"（profile 已装配但标签缺失）。
    expect(() => Dnd5eRules.profile, throwsStateError);
    expect(() => Dnd5eRules.abilityLabels, throwsStateError);
  });

  test('未装配或已装配后再次 configure 都抛错', () async {
    // 未装配时四个派生读取口都必须抛错，绝不返回空清单兜底（§4.4）。
    expect(() => Dnd5eRules.profile, throwsStateError);
    expect(() => Dnd5eRules.skills, throwsStateError);
    expect(() => Dnd5eRules.abilityLabels, throwsStateError);
    expect(() => Dnd5eRules.defaultAbilities, throwsStateError);
    final profile = await loadBuiltinProfileForTest();
    await Dnd5eRules.configure(profile);
    expect(Dnd5eRules.profile.classRules('barbarian')!.hitDie, 12);
    expect(Dnd5eRules.abilityLabels, isNotEmpty);
    expect(Dnd5eRules.defaultAbilities, isNotEmpty);
    expect(() => Dnd5eRules.configure(profile), throwsStateError);
  });
}
