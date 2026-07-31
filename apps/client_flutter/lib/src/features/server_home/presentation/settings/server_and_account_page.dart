import 'package:flutter/material.dart';

import '../../../../core/sync/sync_status_controller.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../server_profiles/data/server_profile_store.dart';
import '../../../server_profiles/domain/server_profile.dart';
import '../../../vault/presentation/vault_sync_controller.dart';
import '../../domain/active_server_session.dart';
import 'server_and_account_section.dart';

class ServerAndAccountPage extends StatelessWidget {
  const ServerAndAccountPage({
    required this.session,
    required this.authController,
    required this.syncStatusController,
    this.serverProfileStore,
    this.serverProfilesPageBuilder,
    this.onSwitchToProfile,
    this.vaultSyncActions,
    super.key,
  });

  final ActiveServerSession session;
  final AuthController authController;
  final SyncStatusController syncStatusController;
  final ServerProfileStore? serverProfileStore;
  final WidgetBuilder? serverProfilesPageBuilder;
  final ValueChanged<ServerProfile>? onSwitchToProfile;
  final VaultSyncActions? vaultSyncActions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('服务器与账号')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: ServerAndAccountSection(
              session: session,
              authController: authController,
              syncStatusController: syncStatusController,
              serverProfileStore: serverProfileStore,
              serverProfilesPageBuilder: serverProfilesPageBuilder,
              onSwitchToProfile: onSwitchToProfile,
              vaultSyncActions: vaultSyncActions,
            ),
          ),
        ),
      ),
    );
  }
}
