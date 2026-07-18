import 'dart:async';

import 'package:dnd_table_client/src/features/server_home/presentation/content_bootstrap_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('holds application content until bundled content is ready', (
    tester,
  ) async {
    final bootstrap = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        home: ContentBootstrapGate(
          future: bootstrap.future,
          builder: (_) => const Scaffold(body: Text('应用已就绪')),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('应用已就绪'), findsNothing);

    bootstrap.complete();
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('应用已就绪'), findsOneWidget);
  });
}
