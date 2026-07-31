import 'dart:async';

import 'package:dnd_table_client/src/features/app_preferences/data/app_preferences_store.dart';
import 'package:dnd_table_client/src/features/app_preferences/presentation/app_preferences_controller.dart';
import 'package:dnd_table_client/src/features/auth/data/auth_api_client.dart';
import 'package:dnd_table_client/src/features/auth/data/auth_token_store.dart';
import 'package:dnd_table_client/src/features/auth/domain/auth_session.dart';
import 'package:dnd_table_client/src/features/campaigns/data/campaign_api_client.dart';
import 'package:dnd_table_client/src/features/client_mode/domain/client_mode.dart';
import 'package:dnd_table_client/src/features/server_home/domain/active_server_session.dart';
import 'package:dnd_table_client/src/features/server_home/presentation/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('does not report logout while auth restoration is pending', (
    tester,
  ) async {
    final autoLogin = Completer<bool>();
    final tokenStore = _DelayedAuthTokenStore(autoLogin.future);
    final preferences = AppPreferencesController(
      store: InMemoryAppPreferencesStore(),
    );
    await preferences.initialize();
    final mode = ClientModeController();
    final session = ActiveServerSession();
    final reports = <AuthUser?>[];

    await tester.pumpWidget(
      MaterialApp(
        home: MainShell(
          session: session,
          modeController: mode,
          authTokenStore: tokenStore,
          authClient: AuthApiClient(),
          campaignClient: CampaignApiClient(),
          appPreferencesController: preferences,
          bundledContentLoader: () async => '{}',
          enableBackgroundSync: false,
          onAuthUserChanged: (user) async => reports.add(user),
        ),
      ),
    );
    await tester.pump();

    expect(reports, isEmpty);

    autoLogin.complete(false);
    await tester.pump();
    await tester.pump();

    expect(reports, [null]);

    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
    mode.dispose();
    preferences.dispose();
  });
}

class _DelayedAuthTokenStore implements AuthTokenStore {
  _DelayedAuthTokenStore(this.autoLogin);

  final Future<bool> autoLogin;

  @override
  Future<void> clearTokens(String serverProfileId) async {}

  @override
  Future<bool> getAutoLoginEnabled(String serverProfileId) => autoLogin;

  @override
  Future<StoredAuthTokens?> getTokens(String serverProfileId) async => null;

  @override
  Future<void> saveTokens(
    String serverProfileId,
    StoredAuthTokens tokens,
  ) async {}

  @override
  Future<void> setAutoLoginEnabled(
    String serverProfileId,
    bool enabled,
  ) async {}
}
