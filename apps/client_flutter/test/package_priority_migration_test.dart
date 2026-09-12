// test/package_priority_migration_test.dart
//
// S3 任务 6：包级 `priority` 与 Drift `schemaVersion` 13 → 14 迁移（决策 D2）。
//
// - 迁移链末尾追加 `local_content_packages.priority`（默认 0）；
// - 旧存档（v13）打开后包还在、enabled 不变、priority 取 0 ⇒ tier 仍是 100，
//   与引入 priority 之前"包声明固定 tier 100"逐项一致（行为不变）；
// - `DriftContentRepository.packagePriorities()` 是唯一只读投影。
import 'package:dnd_table_client/src/core/database/app_database.dart';
import 'package:dnd_table_client/src/features/content/data/local/content_repository.dart';
import 'package:dnd_table_client/src/features/content/domain/content_package_manifest.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('v13 → v14 给 local_content_packages 增加 priority，既有包取默认 0', () async {
    final sqlite = sqlite3.openInMemory();
    sqlite
      ..execute('''
        CREATE TABLE local_content_packages (
          id TEXT PRIMARY KEY NOT NULL,
          format_version INTEGER NOT NULL,
          name TEXT NOT NULL,
          version TEXT NOT NULL,
          locale TEXT NOT NULL,
          system TEXT NOT NULL,
          entry_count INTEGER NOT NULL,
          content_hash TEXT NOT NULL,
          enabled INTEGER NOT NULL DEFAULT 1,
          installed_at INTEGER NOT NULL
        )
      ''')
      ..execute(
        "INSERT INTO local_content_packages VALUES "
        "('phb-2024-v2', 3, 'PHB 2024', '2.0.0', 'zh-CN', 'dnd5e-2024', 1106, "
        "'hash', 1, 0)",
      )
      ..execute('PRAGMA user_version = 13');

    final database = AppDatabase.forTesting(NativeDatabase.opened(sqlite));
    final rows = await database.select(database.localContentPackages).get();

    // 向后兼容：老存档打开后包还在、enabled 不变、priority 取 0（= tier 100，
    // 与升级前"包声明固定 tier 100"完全一致，数值不变）。
    expect(database.schemaVersion, 14);
    expect(rows.single.id, 'phb-2024-v2');
    expect(rows.single.enabled, isTrue);
    expect(rows.single.entryCount, 1106);
    expect(rows.single.priority, 0);

    // 只读投影与落库值一致（老包缺省 0）。
    final repository = DriftContentRepository(database);
    expect(await repository.packagePriorities(), {'phb-2024-v2': 0});
    await database.close();
  });

  test('priority 可写入、读回，并经 packagePriorities() 投影', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    await database
        .into(database.localContentPackages)
        .insert(
          LocalContentPackagesCompanion.insert(
            id: 'errata',
            formatVersion: 3,
            name: '勘误',
            version: '1.0.0',
            locale: 'zh-CN',
            system: 'dnd5e-2024',
            entryCount: 1,
            contentHash: 'hash',
            priority: const Value(40),
            installedAt: DateTime(2026, 9, 12),
          ),
        );
    final row = await (database.select(
      database.localContentPackages,
    )..where((t) => t.id.equals('errata'))).getSingle();
    expect(row.priority, 40);
    expect(
      await DriftContentRepository(database).packagePriorities(),
      {'errata': 40},
    );
    await database.close();
  });

  test('replacePackage 落库 priority，_mapPackage 读回（含 0）', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = DriftContentRepository(database);
    await repository.replacePackage(
      manifest: const ContentPackageManifest(
        formatVersion: 3,
        id: 'high',
        name: 'High',
        version: '1.0.0',
        locale: 'zh-CN',
        system: 'dnd5e-2024',
        entryCount: 0,
        priority: 77,
      ),
      entries: const [],
      contentHash: 'hash',
    );
    final packages = await repository.watchPackages().first;
    expect(packages.single.priority, 77);
    expect(await repository.packagePriorities(), {'high': 77});
    await database.close();
  });
}
