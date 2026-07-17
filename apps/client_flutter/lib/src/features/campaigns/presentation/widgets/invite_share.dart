import 'package:flutter/services.dart';

/// 邀请码分享文本格式化与系统分享入口。
///
/// 将战役邀请码格式化为可分享的中文文本，支持通过系统 share sheet
/// 或剪贴板分发。格式化逻辑为纯函数，便于测试；系统分享依赖
/// [Clipboard] 作为不依赖 share_plus 的最小实现，后续可替换为
/// share_plus 的 Share.share 而不影响调用方。

/// 格式化邀请码分享文本。
///
/// [code] 邀请码（必填）。
/// [campaignName] 战役名称（可选，提供时会在文本中点明）。
/// [serverUrl] 服务器地址（可选，帮助被邀请者配置客户端）。
String formatInviteShareText({
  required String code,
  String? campaignName,
  String? serverUrl,
}) {
  final buffer = StringBuffer();

  if (campaignName != null && campaignName.isNotEmpty) {
    buffer.writeln('邀请你加入 D&D 战役「$campaignName」！');
  } else {
    buffer.writeln('邀请你加入我的 D&D 战役！');
  }

  if (serverUrl != null && serverUrl.isNotEmpty) {
    buffer.writeln('服务器地址：$serverUrl');
  }
  buffer.writeln('邀请码：$code');
  buffer.write('在客户端「使用邀请码加入战役」输入即可加入。');

  return buffer.toString();
}

/// 复制分享文本到剪贴板。
///
/// 在不支持系统 share sheet 的环境（桌面 / Web）下作为兜底实现；
/// 移动端也可用于"仅复制"场景。
Future<void> copyInviteToClipboard({
  required String code,
  String? campaignName,
  String? serverUrl,
}) async {
  final text = formatInviteShareText(
    code: code,
    campaignName: campaignName,
    serverUrl: serverUrl,
  );
  await Clipboard.setData(ClipboardData(text: text));
}
