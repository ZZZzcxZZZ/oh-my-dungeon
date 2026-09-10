import 'package:shared_preferences/shared_preferences.dart';

import '../domain/server_profile.dart';
import 'server_profile_store.dart';

/// 内嵌默认服务器：正式发布构建（`--dart-define=BUNDLED_DEFAULT_SERVER=true`）
/// 首次启动时自动加入内置服务器地址并设为默认，之后不再重复注入
/// （用户删除后可自行重新添加）。测试与开发构建默认关闭，保持
/// "无服务器离线优先"语义。
class BundledDefaultServerSeeder {
  const BundledDefaultServerSeeder({
    this.enabled = enabledByDefault,
    this.baseUrl = defaultBaseUrl,
    this.serverName = defaultServerName,
  });

  /// 构建期开关：仅正式发布构建置为 true。
  static const bool enabledByDefault = bool.fromEnvironment(
    'BUNDLED_DEFAULT_SERVER',
    defaultValue: false,
  );

  /// 构建期可覆盖的内嵌服务器地址。
  static const String defaultBaseUrl = String.fromEnvironment(
    'DEFAULT_SERVER_BASE_URL',
    defaultValue: 'http://47.122.123.77:3000',
  );

  static const String defaultServerName = 'OhMyDungeon 官方';
  static const _markerKey = 'server_profiles.bundled_seed.v1';
  static const _instanceId = 'bundled-ohmydungeon-official';

  final bool enabled;
  final String baseUrl;
  final String serverName;

  /// 仅当启用、从未 seed 过且当前没有任何 profile 时注入默认服务器。
  Future<void> seedIfEmpty(
    ServerProfileStore store,
    SharedPreferences preferences,
  ) async {
    if (!enabled) return;
    if (preferences.getBool(_markerKey) ?? false) return;
    final profiles = await store.listProfiles();
    if (profiles.isEmpty) {
      await store.saveProfile(
        ServerProfile(
          id: _instanceId,
          serverName: serverName,
          baseUrl: baseUrl,
          // 与服务端 /.well-known/dnd-tool-server 的 URL 约定一致
          // （server-info.service.ts）：apiBaseUrl = $base/api，
          // websocketUrl = ws(s)://host/campaigns。
          apiBaseUrl: '$baseUrl/api',
          websocketUrl: '${baseUrl.replaceFirst('http', 'ws')}/campaigns',
          lastKnownVersion: '0.1.0',
        ),
      );
      await store.setDefaultProfileId(_instanceId);
    }
    await preferences.setBool(_markerKey, true);
  }
}
