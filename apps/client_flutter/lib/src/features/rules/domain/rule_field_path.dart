// 列级来源字段路径的**唯一**定义（契约 §3.7 + S3 决策 D5）。
//
// 解析器写来源、UI 读来源、角色数据持久化来源都必须走这里；任何地方都不得手拼
// `'spellcasting.prepared'` / `'resources.rage.maximum'`，也不得自己写中文标签。
// 列白名单同时是 `class_rule_set.dart` 的两个 `declares` 与列级合并的合法列集合。
abstract final class RuleFieldPath {
  static const hitDie = 'hitDie';
  static const savingThrowAbilities = 'savingThrowAbilities';

  static const spellcastingPrefix = 'spellcasting.';
  static const resourcePrefix = 'resources.';

  /// `spellcasting` 的列白名单（顺序与契约 §3.3 的字段表一致）。
  static const spellcastingColumns = <String>{
    'mode',
    'ability',
    'listTags',
    'archetype',
    'slots',
    'slotLevel',
    'prepared',
    'cantrips',
    'maximumSpellLevel',
  };

  /// 资源参与列级合并、且记录来源的列（`id` 是合键，`description` 无数值语义）。
  static const resourceColumns = <String>{
    'name',
    'maximum',
    'recovery',
    'startsAtLevel',
  };

  static String spellcasting(String column) => '$spellcastingPrefix$column';

  static String resource(String id, String column) => '$resourcePrefix$id.$column';

  /// `resources.<id>.<列>` 拆解；不是资源路径时返回 null。
  static ({String id, String column})? parseResource(String path) {
    if (!path.startsWith(resourcePrefix)) return null;
    final rest = path.substring(resourcePrefix.length);
    final split = rest.lastIndexOf('.');
    if (split <= 0) return null;
    return (id: rest.substring(0, split), column: rest.substring(split + 1));
  }

  /// 展示名（中文）的**唯一**实现。未知路径原样返回，便于暴露漏登记。
  /// [resourceName] 是资源的展示名（档案/条目里的 `name`）；缺省时退回资源 id。
  static String labelFor(String path, {String? resourceName}) {
    return switch (path) {
      hitDie => '生命骰',
      savingThrowAbilities => '豁免熟练',
      'spellcasting.mode' => '法术选择模型',
      'spellcasting.ability' => '施法属性',
      'spellcasting.listTags' => '法术列表',
      'spellcasting.archetype' => '法术位进阶',
      'spellcasting.slots' => '法术位',
      'spellcasting.slotLevel' => '契约法术位环阶',
      'spellcasting.prepared' => '准备法术上限',
      'spellcasting.cantrips' => '戏法上限',
      'spellcasting.maximumSpellLevel' => '最高法术环阶',
      _ => _resourceLabel(path, resourceName) ?? path,
    };
  }

  static String? _resourceLabel(String path, String? resourceName) {
    final parsed = parseResource(path);
    if (parsed == null) return null;
    final subject = resourceName ?? parsed.id;
    return switch (parsed.column) {
      'name' => '$subject · 名称',
      'maximum' => '$subject · 次数上限',
      'recovery' => '$subject · 恢复',
      'startsAtLevel' => '$subject · 起始等级',
      _ => null,
    };
  }
}
