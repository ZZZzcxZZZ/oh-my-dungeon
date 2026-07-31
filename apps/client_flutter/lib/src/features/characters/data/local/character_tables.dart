import 'package:drift/drift.dart';

/// 本地角色主表。sheetJson 保存完整角色卡序列化结果，离线优先且可跨设备同步。
@DataClassName('CharacterRow')
class Characters extends Table {
  TextColumn get id => text()();
  TextColumn get ownerLocalId => text().withDefault(const Constant('local'))();
  TextColumn get sheetJson => text()();

  /// Readable derivative regenerated from [sheetJson] on every write.
  ///
  /// Nullable only so backups created before schema v10 remain importable.
  TextColumn get markdownMirror => text().nullable()();
  BoolColumn get markdownDirty =>
      boolean().withDefault(const Constant(false))();
  IntColumn get revision => integer().withDefault(const Constant(1))();
  IntColumn get syncRevision => integer().nullable()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 角色引用的本地资料条目快照。删除资料包后角色仍可凭借 snapshot 使用。
///
/// 主键为 {characterId, entryKey}: 一个角色对同一个资料条目只能有一条
/// 引用, 但可以有多个 slot="feature" 的引用 (每个职业特性一条)。
/// 旧版本主键为 {characterId, slot}, 导致同 kind 的多个 grant (如多个
/// feature) 主键冲突 (SqliteException 1555)。schema v8 修正此约束。
@DataClassName('CharacterContentRefRow')
class CharacterContentRefs extends Table {
  TextColumn get characterId => text()();
  TextColumn get slot => text()();
  TextColumn get entryKey => text()();
  IntColumn get sourceRevision => integer().withDefault(const Constant(1))();
  TextColumn get snapshotJson => text().withDefault(const Constant('{}'))();

  @override
  Set<Column<Object>> get primaryKey => {characterId, entryKey};
}
