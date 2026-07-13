import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:meta/meta.dart';

import 'tables/core_tables.dart';

part 'app_database.g.dart';

/// 客户端本地数据库。本地数据是离线优先应用的事实来源，网络同步只把远端变化
/// 合并到本地表，UI 永远只读本地。
@DriftDatabase(tables: [
  ServerProfiles,
  SyncOutbox,
  SyncCursors,
  MigrationMarkers,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// 测试与内存数据库构造器。
  @visibleForTesting
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

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
