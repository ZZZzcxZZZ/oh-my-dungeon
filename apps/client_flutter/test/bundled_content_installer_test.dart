import 'package:dnd_table_client/src/features/content/data/import/bundled_content_installer.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/content_test_support.dart';

const _bundle = '''{
  "formatVersion": 2,
  "id": "test.bundle",
  "name": "Test bundle",
  "version": "1.0.0",
  "locale": "zh-CN",
  "system": "dnd5e-2024",
  "entryCount": 1,
  "entries": [{
    "id": "test.bundle:feat/example",
    "type": "feat",
    "slug": "example",
    "name": "Example feat",
    "body": [],
    "revision": 1
  }]
}''';

void main() {
  test('imports a valid bundled package only once per version', () async {
    final repository = MemoryContentRepository();
    final installer = BundledContentInstaller(
      repository: repository,
      loadBundle: () async => _bundle,
    );

    expect(await installer.installIfAvailable(), isTrue);
    expect(await repository.getByKey('test.bundle:feat/example'), isNotNull);
    expect(await installer.installIfAvailable(), isFalse);
  });
}
