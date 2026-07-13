import 'package:dnd_table_client/src/features/auth/data/auth_api_client.dart';
import 'package:dnd_table_client/src/features/auth/data/auth_token_store.dart';
import 'package:dnd_table_client/src/features/auth/domain/auth_session.dart';
import 'package:dnd_table_client/src/features/auth/presentation/auth_controller.dart';
import 'package:dnd_table_client/src/features/content/data/content_api_client.dart';
import 'package:dnd_table_client/src/features/content/domain/content.dart';
import 'package:dnd_table_client/src/features/content/presentation/content_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const apiBaseUrl = 'http://localhost:3000/api';

  Future<AuthController> buildLoggedInAuthController() async {
    final tokenStore = InMemoryAuthTokenStore();
    await tokenStore.saveTokens(
      'localhost',
      const StoredAuthTokens(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      ),
    );
    final controller = AuthController(
      tokenStore: tokenStore,
      authClient: _FakeAuthClient(),
      serverProfileId: 'localhost',
      apiBaseUrl: apiBaseUrl,
    );
    await controller.initialize();
    return controller;
  }

  test('dry-runs json import and exposes validation errors', () async {
    final authController = await buildLoggedInAuthController();
    final client = _FakeContentClient(
      importResult: const ImportContentPackageResult(
        valid: false,
        errors: ['Package name is required'],
        package: null,
      ),
    );
    final controller = ContentController(
      apiBaseUrl: apiBaseUrl,
      authController: authController,
      contentClient: client,
    );

    final ok = await controller.validateImportJson('{"items": []}');

    expect(ok, isFalse);
    expect(controller.importErrors, ['Package name is required']);
    expect(client.importCalls.single.dryRun, isTrue);

    controller.dispose();
    authController.dispose();
  });

  test('imports json and adds the package to local state', () async {
    final authController = await buildLoggedInAuthController();
    final client = _FakeContentClient(
      importResult: ImportContentPackageResult(
        valid: true,
        errors: const [],
        package: _package,
      ),
    );
    final controller = ContentController(
      apiBaseUrl: apiBaseUrl,
      authController: authController,
      contentClient: client,
    );

    final ok = await controller.importJson('{"name":"Basic","items":[]}');

    expect(ok, isTrue);
    expect(controller.packages, [_package]);
    expect(client.importCalls.single.dryRun, isFalse);

    controller.dispose();
    authController.dispose();
  });

  test('loads available campaign content', () async {
    final authController = await buildLoggedInAuthController();
    final client = _FakeContentClient(availableItems: [_item]);
    final controller = ContentController(
      apiBaseUrl: apiBaseUrl,
      authController: authController,
      contentClient: client,
    );

    await controller.loadAvailableCampaignItems(
      campaignId: 'camp-1',
      type: 'spell',
      query: 'fire',
    );

    expect(controller.availableItems, [_item]);
    expect(client.availableCalls.single, ('camp-1', 'spell', 'fire'));

    controller.dispose();
    authController.dispose();
  });

  test('loads global content items for character creation', () async {
    final authController = await buildLoggedInAuthController();
    final client = _FakeContentClient(items: [_item]);
    final controller = ContentController(
      apiBaseUrl: apiBaseUrl,
      authController: authController,
      contentClient: client,
    );

    await controller.loadItems(type: 'class', query: 'fighter');

    expect(controller.items, [_item]);
    expect(client.itemCalls.single, ('class', 'fighter'));

    controller.dispose();
    authController.dispose();
  });
}

const _item = ContentItem(
  id: 'item-1',
  packageId: 'pkg-1',
  type: 'spell',
  slug: 'fire-bolt',
  name: 'Fire Bolt',
  description: 'A mote of fire.',
  structured: {'level': 0},
  tags: ['cantrip'],
  sourceLabel: 'SRD',
  schemaVersion: 1,
  createdAt: '2026-07-09T00:00:00.000Z',
  updatedAt: '2026-07-09T00:00:00.000Z',
);

const _package = ContentPackage(
  id: 'pkg-1',
  scope: 'user',
  ownerUserId: 'user-1',
  campaignId: null,
  name: 'Basic Spells',
  version: '1.0.0',
  schemaVersion: 1,
  locale: 'zh-CN',
  status: 'active',
  createdBy: 'user-1',
  createdAt: '2026-07-09T00:00:00.000Z',
  updatedAt: '2026-07-09T00:00:00.000Z',
  items: [_item],
);

class _FakeAuthClient implements AuthClient {
  @override
  Future<AuthSession> login({
    required String apiBaseUrl,
    required String identifier,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> logout({
    required String apiBaseUrl,
    required String refreshToken,
  }) async {}

  @override
  Future<AuthUser> me({
    required String apiBaseUrl,
    required String accessToken,
  }) async {
    return const AuthUser(
      id: 'user-1',
      username: 'dm',
      email: 'dm@example.com',
    );
  }

  @override
  Future<String> refresh({
    required String apiBaseUrl,
    required String refreshToken,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<RegisterResult> register({
    required String apiBaseUrl,
    required String username,
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }
}

class _FakeContentClient implements ContentClient {
  @override
  Future<ContentItemDetail> getCampaignItem({required String apiBaseUrl, required String accessToken, required String campaignId, required String itemId}) async => ContentItemDetail(item: _item, isFavorite: false, outgoingLinks: const []);
  @override
  Future<ImportContentPackageResult> importCampaignPackage({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required Object package,
    bool dryRun = false,
  }) async => const ImportContentPackageResult(valid: true, errors: [], package: null);

  @override
  Future<void> setCampaignItemFavorite({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String itemId,
    required bool favorite,
  }) async {}
  _FakeContentClient({
    this.importResult = const ImportContentPackageResult(
      valid: true,
      errors: [],
      package: null,
    ),
    this.availableItems = const [],
    this.items = const [],
  });

  final ImportContentPackageResult importResult;
  final List<ContentItem> availableItems;
  final List<ContentItem> items;
  final List<({bool dryRun, Object package})> importCalls = [];
  final List<(String, String?, String?)> availableCalls = [];
  final List<(String?, String?)> itemCalls = [];

  @override
  Future<ImportContentPackageResult> importPackage({
    required String apiBaseUrl,
    required String accessToken,
    required Object package,
    bool dryRun = false,
  }) async {
    importCalls.add((dryRun: dryRun, package: package));
    return importResult;
  }

  @override
  Future<List<ContentItem>> listAvailableCampaignItems({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    String? type,
    String? query,
    bool favoriteOnly = false,
  }) async {
    availableCalls.add((campaignId, type, query));
    return availableItems;
  }

  @override
  Future<List<ContentPackage>> listPackages({
    required String apiBaseUrl,
    required String accessToken,
  }) async {
    return const [];
  }

  @override
  Future<Map<String, Object?>> exportPackage({
    required String apiBaseUrl,
    required String accessToken,
    required String packageId,
  }) async {
    return const {};
  }

  @override
  Future<List<ContentItem>> listItems({
    required String apiBaseUrl,
    required String accessToken,
    String? type,
    String? query,
    String? packageId,
  }) async {
    itemCalls.add((type, query));
    return items;
  }

  @override
  Future<void> setCampaignPackage({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String packageId,
    required bool enabled,
  }) async {}

  @override
  Future<void> disableCampaignItem({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String itemId,
    String? reason,
  }) async {}
}
