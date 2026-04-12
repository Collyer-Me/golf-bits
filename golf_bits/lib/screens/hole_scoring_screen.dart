import 'package:flutter/material.dart';

/// In-round: current hole, award bits (placeholder).
class HoleScoringScreen extends StatelessWidget {
  const HoleScoringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hole 1'),
      ),
      body: const Center(
        child: Text('Hole scoring — add UI here'),
      ),
    );
  }
}
