import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:meta/meta.dart';

import '../../features/content/data/local/content_tables.dart';
import 'tables/core_tables.dart';

part 'app_database.g.dart';

/// 客户端本地数据库。本地数据是离线优先应用的事实来源，网络同步只把远端变化
/// 合并到本地表，UI 永远只读本地。
@DriftDatabase(tables: [
  ServerProfiles,
  SyncOutbox,
  SyncCursors,
  MigrationMarkers,
  LocalContentPackages,
  LocalContentEntries,
  LocalContentAssets,
  ContentLinks,
  ContentFavorites,
  ContentNotes,
  ContentReadHistory,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// 测试与内存数据库构造器。
  @visibleForTesting
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(localContentPackages);
            await m.createTable(localContentEntries);
            await m.createTable(localContentAssets);
            await m.createTable(contentLinks);
            await m.createTable(contentFavorites);
            await m.createTable(contentNotes);
            await m.createTable(contentReadHistory);
          }
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'app.db',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.dart.js'),
      ),
    );
  }
}
