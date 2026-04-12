import 'package:flutter/material.dart';

/// Large “GOLF BITS” lockup (Lexend via theme).
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({
    super.key,
    this.size = BrandWordmarkSize.hero,
  });

  final BrandWordmarkSize size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final color = Theme.of(context).colorScheme.onSurface;

    final TextStyle base = switch (size) {
      BrandWordmarkSize.hero => theme.displaySmall!,
      BrandWordmarkSize.screen => theme.headlineMedium!,
      BrandWordmarkSize.compact => theme.titleLarge!,
    };

    return Text(
      'GOLF BITS',
      textAlign: TextAlign.center,
      style: base.copyWith(
        color: color,
        fontWeight: FontWeight.w900,
        fontStyle: FontStyle.italic,
        letterSpacing: 1.2,
      ),
    );
  }
}

enum BrandWordmarkSize { hero, screen, compact }
