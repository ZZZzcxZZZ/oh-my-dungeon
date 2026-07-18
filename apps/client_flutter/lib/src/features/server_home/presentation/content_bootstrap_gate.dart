import 'package:flutter/material.dart';

class ContentBootstrapGate extends StatelessWidget {
  const ContentBootstrapGate({
    required this.future,
    required this.builder,
    super.key,
  });

  final Future<void> future;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return builder(context);
      },
    );
  }
}
