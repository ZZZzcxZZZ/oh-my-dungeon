import 'package:dnd_table_client/src/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('opens an empty schema at version four', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    expect(database.schemaVersion, 4);
    expect(await database.select(database.serverProfiles).get(), isEmpty);
    expect(await database.select(database.syncOutbox).get(), isEmpty);
    expect(await database.select(database.localContentPackages).get(), isEmpty);
    expect(await database.select(database.localContentEntries).get(), isEmpty);
    expect(await database.select(database.characters).get(), isEmpty);
    expect(await database.select(database.characterContentRefs).get(), isEmpty);
    expect(await database.select(database.campaignActorsCache).get(), isEmpty);
    expect(await database.select(database.campaignContentCache).get(), isEmpty);
    expect(await database.select(database.campaignSyncCursors).get(), isEmpty);
    expect(await database.select(database.characterSyncConflicts).get(), isEmpty);
    await database.close();
  });
}
