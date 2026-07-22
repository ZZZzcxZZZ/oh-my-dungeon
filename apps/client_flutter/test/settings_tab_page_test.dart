import 'package:dnd_table_client/src/core/sync/sync_status_controller.dart';
import 'package:dnd_table_client/src/features/app_preferences/data/app_preferences_store.dart';
import 'package:dnd_table_client/src/features/app_preferences/presentation/app_preferences_controller.dart';
import 'package:dnd_table_client/src/features/auth/data/auth_api_client.dart';
import 'package:dnd_table_client/src/features/auth/data/auth_token_store.dart';
import 'package:dnd_table_client/src/features/auth/domain/auth_session.dart';
import 'package:dnd_table_client/src/features/auth/presentation/auth_controller.dart';
import 'package:dnd_table_client/src/features/client_mode/domain/client_mode.dart';
import 'package:dnd_table_client/src/features/server_home/domain/active_server_session.dart';
import 'package:dnd_table_client/src/features/server_home/presentation/settings_tab_page.dart';
import 'package:dnd_table_client/src/features/server_profiles/data/server_profile_store.dart';
import 'package:dnd_table_client/src/features/server_profiles/domain/server_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _profile = ServerProfile(
  id: 'localhost',
  name: 'Local Table',
  baseUrl: 'http://localhost:3000',
  apiBaseUrl: 'http://localhost:3000/api',
  websocketUrl: 'ws://localhost:3000/ws',
  lastKnownVersion: '0.1.0',
);

void main() {
  late AppPreferencesController preferencesController;
  late ClientModeController modeController;
  late AuthController authController;
  late SyncStatusController syncStatusController;
  late ActiveServerSession session;

  setUp(() async {
    preferencesController = AppPreferencesController(
      store: InMemoryAppPreferencesStore(),
    );
    await preferencesController.initialize();
    modeController = ClientModeController();
    final tokenStore = InMemoryAuthTokenStore();
    authController = AuthController(
      tokenStore: tokenStore,
      authClient: _StubAuthClient(),
      serverProfileId: _profile.id,
      apiBaseUrl: _profile.apiBaseUrl,
    );
    await authController.initialize();
    syncStatusController = SyncStatusController();
    session = ActiveServerSession()..activate(_profile);
  });

  tearDown(() {
    preferencesController.dispose();
    modeController.dispose();
    authController.dispose();
    syncStatusController.dispose();
    session.dispose();
  });

  Future<void> pumpSettings(
    WidgetTester tester, {
    ServerProfileStore? serverProfileStore,
    WidgetBuilder? serverProfilesPageBuilder,
    ValueChanged<ServerProfile>? onSwitchToProfile,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsTabPage(
          session: session,
          modeController: modeController,
          authController: authController,
          appPreferencesController: preferencesController,
          syncStatusController: syncStatusController,
          serverProfileStore: serverProfileStore,
          serverProfilesPageBuilder: serverProfilesPageBuilder,
          onSwitchToProfile: onSwitchToProfile,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders sections in the fixed IA order', (tester) async {
    await pumpSettings(tester);

    final labels = <String>[
      '外观与体验',
      '资料与存储',
      '服务器与账户',
      '角色模式',
      '关于',
    ];
    final indices = <int>[];
    for (final label in labels) {
      final found = find.text(label);
      expect(found, findsWidgets);
      final widget = tester.widget<Text>(found.first);
      final offset = tester.getTopLeft(found.first);
      // Record Y of each section header to compare ordering.
      indices.add(offset.dy.round());
      // Sanity check: the label is actually rendered.
      expect(widget.data, label);
    }
    for (var i = 1; i < indices.length; i++) {
      expect(
        indices[i],
        greaterThan(indices[i - 1]),
        reason: '${labels[i]} should appear below ${labels[i - 1]}',
      );
    }
  });

  testWidgets('does not render display-only settings', (tester) async {
    await pumpSettings(tester);

    // The old "默认规则集 / D&D 2024" tile was info-only with no behavior.
    expect(find.text('默认规则集'), findsNothing);
    expect(find.text('D&D 2024'), findsNothing);
    expect(find.text('显示 Legacy 内容'), findsNothing);
  });

  testWidgets('server/account/sync rows live only under 服务器与账户', (tester) async {
    await pumpSettings(tester);

    // "服务器" header is no longer a standalone section; the merged section
    // title is "服务器与账户".
    expect(find.text('服务器'), findsNothing);
    expect(find.text('账号'), findsNothing);
    expect(find.text('同步'), findsNothing);

    // But the merged section title is present exactly once.
    expect(find.text('服务器与账户'), findsOneWidget);

    // Server info card is present under the merged section.
    expect(find.text('Local Table'), findsOneWidget);
    expect(find.text('http://localhost:3000'), findsOneWidget);
  });

  testWidgets('caps content width at 760 dp on wide screens', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpSettings(tester);

    final scrollable = find.byType(SingleChildScrollView);
    expect(scrollable, findsOneWidget);

    final constrainedBox = tester.widget<ConstrainedBox>(
      find.ancestor(
        of: find.text('外观与体验'),
        matching: find.byType(ConstrainedBox),
      ).first,
    );
    final max = constrainedBox.constraints.maxWidth;
    expect(max, lessThanOrEqualTo(760));
  });

  testWidgets('seed color picker dialog previews and applies a custom color', (
    tester,
  ) async {
    await pumpSettings(tester);

    expect(preferencesController.preferences.seedColorValue, 0xff6750a4);

    await tester.tap(find.text('主题色'));
    await tester.pumpAndSettle();

    // Dialog shows preset swatches + a hex input.
    expect(find.text('预设色'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsWidgets); // selected preset check
    expect(find.text('自定义'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('seed-color-hex-input')), '0061A4');
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();

    // Cancel must not write the store.
    expect(find.byType(Dialog), findsNothing);
    expect(preferencesController.preferences.seedColorValue, 0xff6750a4);

    // Reopen and apply a preset color via Dialog.
    await tester.tap(find.text('主题色'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('seed-color-preset-0061a4')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '应用'));
    await tester.pumpAndSettle();

    expect(preferencesController.preferences.seedColorValue, 0xff0061a4);
  });

  testWidgets('no Card wraps a whole section and no Card nests another Card', (
    tester,
  ) async {
    await pumpSettings(tester);

    final sectionHeaders = find.byKey(const Key('settings-section-header'));
    expect(sectionHeaders, findsWidgets);

    // No section header should have a Card ancestor.
    for (final header in sectionHeaders.evaluate()) {
      final cardAncestor = find.ancestor(
        of: find.byElementPredicate((element) => element == header),
        matching: find.byType(Card),
      );
      expect(
        cardAncestor.evaluate(),
        isEmpty,
        reason: 'Section header is wrapped in a Card',
      );
    }

    // No Card should contain another Card.
    final cards = find.byType(Card);
    for (final cardElement in cards.evaluate()) {
      final cardFinder = find.byElementPredicate((element) => element == cardElement);
      final inner = find.descendant(
        of: cardFinder,
        matching: find.byType(Card),
      );
      expect(
        inner.evaluate(),
        isEmpty,
        reason: 'Card nests another Card',
      );
    }
  });

  testWidgets('shows the about section with product info', (tester) async {
    await pumpSettings(tester);

    expect(find.text('关于'), findsWidgets);
    expect(find.textContaining('D&D Table Tool'), findsWidgets);
    expect(find.textContaining('0.1.0'), findsWidgets);
  });
}

class _StubAuthClient implements AuthClient {
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
    throw UnimplementedError();
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
