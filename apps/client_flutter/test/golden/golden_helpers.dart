import 'package:dnd_table_client/src/app/theme/app_theme.dart';
import 'package:dnd_table_client/src/features/app_preferences/domain/app_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 加载应用真实字体（NotoSansSC + Roboto 别名），否则 golden 中的中文
/// 会渲染成 Ahem 方块。
Future<void> loadAppFonts() async {
  final data = await rootBundle.load('assets/fonts/NotoSansSC-Variable.ttf');
  for (final family in ['NotoSansSC', 'Roboto']) {
    final loader = FontLoader(family)..addFont(Future.value(data));
    await loader.load();
  }
}

/// 包一层应用主题的 golden 画布。
Widget themedApp(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(AppPreferences.defaults),
    home: Scaffold(body: Center(child: child)),
  );
}
