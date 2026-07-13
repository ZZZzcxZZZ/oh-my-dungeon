import 'package:drift/drift.dart';

/// 本地角色主表。sheetJson 保存完整角色卡序列化结果，离线优先且可跨设备同步。
@DataClassName('CharacterRow')
class Characters extends Table {
  TextColumn get id => text()();
  TextColumn get ownerLocalId => text().withDefault(const Constant('local'))();
  TextColumn get sheetJson => text()();
  IntColumn get revision => integer().withDefault(const Constant(1))();
  IntColumn get syncRevision => integer().nullable()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 角色引用的本地资料条目快照。删除资料包后角色仍可凭借 snapshot 使用。
@DataClassName('CharacterContentRefRow')
class CharacterContentRefs extends Table {
  TextColumn get characterId => text()();
  TextColumn get slot => text()();
  TextColumn get entryKey => text()();
  IntColumn get sourceRevision => integer().withDefault(const Constant(1))();
  TextColumn get snapshotJson => text().withDefault(const Constant('{}'))();

  @override
  Set<Column<Object>> get primaryKey => {characterId, slot};
}
