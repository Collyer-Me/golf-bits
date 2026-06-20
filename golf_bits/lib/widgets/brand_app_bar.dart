import 'package:flutter/material.dart';

import 'brand_wordmark.dart';

/// The single app bar used across every screen: the Bits Dots Junk wordmark,
/// centered, with an automatic back button on pushed routes and optional
/// trailing actions. Screen titles live in the body — never here — so the
/// header stays identical everywhere.
class BrandAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BrandAppBar({super.key, this.actions, this.leading, this.markOnly = false});

  /// Trailing actions (e.g. a settings menu or refresh). Kept minimal.
  final List<Widget>? actions;

  /// Optional custom leading (e.g. a step-aware back button). When null, the
  /// standard back button is shown automatically on pushed routes.
  final Widget? leading;

  /// Show just the mark instead of the full wordmark.
  final bool markOnly;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      centerTitle: true,
      title: BrandWordmark(size: BrandWordmarkSize.compact, markOnly: markOnly),
      leading: leading,
      actions: actions,
    );
  }
}
