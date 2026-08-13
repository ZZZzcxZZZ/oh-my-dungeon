import 'package:flutter/material.dart';

import '../../../../app/app_identity.dart';
import 'settings_section.dart';

/// 关于：产品名、版本号、简短说明。
class AboutSection extends StatelessWidget {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return SettingsSection(
      title: '关于',
      leading: Icon(Icons.info_outline, color: colorScheme.primary),
      children: [
        Card(
          child: Column(
            children: [
              ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/branding/ohmydungeon_icon.png',
                    width: 40,
                    height: 40,
                  ),
                ),
                title: const Text(AppIdentity.displayName),
                subtitle: const Text(AppIdentity.description),
              ),
              ListTile(
                leading: const Icon(Icons.tag),
                title: const Text('版本'),
                subtitle: const Text(AppIdentity.version),
                dense: true,
              ),
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('数据归属'),
                subtitle: const Text(
                  '本地角色、笔记和导入的资料包仅保存在此设备。'
                  '商业规则内容为用户私有导入，不会上传或分发。',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
