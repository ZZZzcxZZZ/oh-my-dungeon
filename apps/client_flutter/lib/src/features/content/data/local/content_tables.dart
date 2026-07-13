import 'package:drift/drift.dart';

/// 本地内容包元数据。每个包对应一次导入，enabled 控制是否参与搜索。
@DataClassName('LocalContentPackageRow')
class LocalContentPackages extends Table {
  TextColumn get id => text()();
  IntColumn get formatVersion => integer()();
  TextColumn get name => text()();
  TextColumn get version => text()();
  TextColumn get locale => text()();
  TextColumn get system => text()();
  IntColumn get entryCount => integer()();
  TextColumn get contentHash => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get installedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 本地内容条目。entryKey 等于 ContentEntry.id（如 example:class/fighter）。
@DataClassName('LocalContentEntryRow')
class LocalContentEntries extends Table {
  TextColumn get entryKey => text()();
  TextColumn get packageId => text()();
  TextColumn get type => text()();
  TextColumn get slug => text()();
  TextColumn get name => text()();
  TextColumn get aliasesJson => text().withDefault(const Constant('[]'))();
  TextColumn get summary => text().withDefault(const Constant(''))();
  TextColumn get bodyJson => text().withDefault(const Constant('[]'))();
  TextColumn get structuredJson => text().withDefault(const Constant('{}'))();
  TextColumn get tagsJson => text().withDefault(const Constant('[]'))();
  TextColumn get sourceLabel => text().withDefault(const Constant(''))();
  IntColumn get revision => integer()();

  @override
  Set<Column<Object>> get primaryKey => {entryKey};
}

/// 本地二进制资源（图片等）。按 packageId + relativePath 复合主键。
@DataClassName('LocalContentAssetRow')
class LocalContentAssets extends Table {
  TextColumn get packageId => text()();
  TextColumn get relativePath => text()();
  BlobColumn get bytes => blob()();
  TextColumn get mediaType => text().withDefault(const Constant(''))();
  TextColumn get contentHash => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {packageId, relativePath};
}

/// 条目之间的链接关系，从 EntryLinkBlock 提取。
@DataClassName('ContentLinkRow')
class ContentLinks extends Table {
  TextColumn get id => text()();
  TextColumn get sourceId => text()();
  TextColumn get targetId => text()();
  TextColumn get linkText => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 用户收藏的条目。
@DataClassName('ContentFavoriteRow')
class ContentFavorites extends Table {
  TextColumn get entryKey => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {entryKey};
}

/// 用户为条目编写的笔记。
@DataClassName('ContentNoteRow')
class ContentNotes extends Table {
  TextColumn get entryKey => text()();
  TextColumn get markdown => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {entryKey};
}

/// 条目阅读历史，用于"最近看过"列表。
@DataClassName('ContentReadHistoryRow')
class ContentReadHistory extends Table {
  TextColumn get entryKey => text()();
  DateTimeColumn get readAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {entryKey};
}
