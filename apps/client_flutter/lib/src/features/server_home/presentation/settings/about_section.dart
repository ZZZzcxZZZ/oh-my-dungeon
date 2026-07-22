import 'package:flutter/material.dart';

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
                leading: const Icon(Icons.castle_outlined),
                title: const Text('D&D Table Tool'),
                subtitle: const Text('离线优先的跑团桌面工具'),
              ),
              ListTile(
                leading: const Icon(Icons.tag),
                title: const Text('版本'),
                subtitle: const Text('0.1.0'),
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
