import 'package:flutter/material.dart';

/// Pre-round: players, course, events (placeholder).
class RoundSetupScreen extends StatelessWidget {
  const RoundSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set up round'),
      ),
      body: const Center(
        child: Text('Round setup — add UI here'),
      ),
    );
  }
}
