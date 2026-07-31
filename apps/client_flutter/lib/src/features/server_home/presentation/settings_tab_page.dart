import 'package:flutter/material.dart';

import '../../../core/backup/local_data_archive_service.dart';
import '../../../core/sync/sync_status_controller.dart';
import '../../app_preferences/presentation/app_preferences_controller.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../client_mode/domain/client_mode.dart';
import '../../content/data/import/content_package_importer.dart';
import '../../content/data/local/content_repository.dart';
import '../../content/domain/content_file_picker.dart';
import '../../server_profiles/data/server_profile_store.dart';
import '../../server_profiles/domain/server_profile.dart';
import '../../vault/presentation/vault_sync_controller.dart';
import '../domain/active_server_session.dart';
import 'settings/about_section.dart';
import 'settings/appearance_section.dart';
import 'settings/content_and_storage_section.dart';
import 'settings/gameplay_settings_section.dart';
import 'settings/role_mode_section.dart';
import 'settings/server_and_account_section.dart';
import 'settings/server_and_account_page.dart';

/// Top-level settings tab. The section order is deliberate and stable.
class SettingsTabPage extends StatelessWidget {
  const SettingsTabPage({
    required this.session,
    required this.modeController,
    required this.authController,
    required this.appPreferencesController,
    required this.syncStatusController,
    this.serverProfileStore,
    this.serverProfilesPageBuilder,
    this.onSwitchToProfile,
    this.contentRepository,
    this.contentImporter,
    this.contentFilePicker,
    this.vaultSyncActions,
    this.archiveService,
    super.key,
  });

  final ActiveServerSession session;
  final ClientModeController modeController;
  final AuthController authController;
  final AppPreferencesController appPreferencesController;
  final SyncStatusController syncStatusController;
  final ServerProfileStore? serverProfileStore;
  final WidgetBuilder? serverProfilesPageBuilder;
  final ValueChanged<ServerProfile>? onSwitchToProfile;
  final ContentRepository? contentRepository;
  final ContentPackageImporter? contentImporter;
  final ContentFilePicker? contentFilePicker;
  final VaultSyncActions? vaultSyncActions;
  final LocalDataArchiveService? archiveService;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        modeController,
        authController,
        session,
        syncStatusController,
        appPreferencesController,
      ]),
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('设置')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ServerAndAccountSection(
                    session: session,
                    authController: authController,
                    syncStatusController: syncStatusController,
                    compact: true,
                    onOpenDetails: () => _openServerAndAccount(context),
                  ),
                  const SizedBox(height: 24),
                  RoleModeSection(modeController: modeController),
                  const SizedBox(height: 24),
                  AppearanceSection(controller: appPreferencesController),
                  const SizedBox(height: 24),
                  GameplaySettingsSection(controller: appPreferencesController),
                  const SizedBox(height: 24),
                  ContentAndStorageSection(
                    contentRepository: contentRepository,
                    contentImporter: contentImporter,
                    contentFilePicker: contentFilePicker,
                    archiveService: archiveService,
                  ),
                  const SizedBox(height: 24),
                  const AboutSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openServerAndAccount(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => ServerAndAccountPage(
          session: session,
          authController: authController,
          syncStatusController: syncStatusController,
          serverProfileStore: serverProfileStore,
          serverProfilesPageBuilder: serverProfilesPageBuilder,
          onSwitchToProfile: onSwitchToProfile,
          vaultSyncActions: vaultSyncActions,
        ),
      ),
    );
  }
}
