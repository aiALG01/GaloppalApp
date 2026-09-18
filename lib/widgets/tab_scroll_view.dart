import 'package:flutter/material.dart';

/// Shared scroll container for every tab body: consistent side padding and
/// enough bottom padding to clear the floating bottom nav bar.
class TabScrollView extends StatelessWidget {
  const TabScrollView({
    super.key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });

  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 120),
      child: Column(crossAxisAlignment: crossAxisAlignment, children: children),
    );
  }
}
