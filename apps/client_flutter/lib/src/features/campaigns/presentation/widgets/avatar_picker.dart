import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/presentation/avatar_image_provider.dart';

/// 头像选择与上传 UI（plan 2 任务5）。
///
/// 纯 UI 组件：图片选择和上传的实际平台/网络调用由宿主页面通过 [onPick] 和
/// [onUpload] 回调注入，便于测试。选图后宿主把字节回填到 [previewBytes]，
/// 预览就绪且未在上传中时上传按钮才可用。
class AvatarPicker extends StatelessWidget {
  const AvatarPicker({
    this.currentAvatarUrl,
    this.previewBytes,
    required this.onPick,
    this.onUpload,
    this.isUploading = false,
    this.error,
    super.key,
  });

  final String? currentAvatarUrl;
  final Uint8List? previewBytes;
  final VoidCallback onPick;
  final VoidCallback? onUpload;
  final bool isUploading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPreview = previewBytes != null;
    final hasCurrent = currentAvatarUrl != null && currentAvatarUrl!.isNotEmpty;
    final canUpload = hasPreview && !isUploading && onUpload != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: CircleAvatar(
            radius: 48,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            backgroundImage: hasPreview
                ? MemoryImage(previewBytes!)
                : avatarImageProvider(currentAvatarUrl),
            child: (!hasPreview && !hasCurrent)
                ? Icon(
                    Icons.person,
                    size: 48,
                    color: theme.colorScheme.onSurfaceVariant,
                  )
                : null,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: isUploading ? null : onPick,
              icon: const Icon(Icons.image_outlined),
              label: const Text('选择图片'),
            ),
            FilledButton.icon(
              onPressed: canUpload ? onUpload : null,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('上传'),
            ),
          ],
        ),
        if (isUploading) ...[
          const SizedBox(height: 12),
          const Center(child: CircularProgressIndicator()),
        ],
        if (error != null && error!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(error!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
        ],
      ],
    );
  }
}
