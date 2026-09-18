import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A pill/segment button used throughout the slot-creation form and role
/// switchers. Matches the prototype's selected/unselected chip pairs.
class ChipOption extends StatelessWidget {
  const ChipOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedBg = AppColors.ink,
    this.selectedFg = Colors.white,
    this.fillWidth = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedBg;
  final Color selectedFg;
  final bool fillWidth;

  @override
  Widget build(BuildContext context) {
    final child = Material(
      color: selected ? selectedBg : Colors.white,
      borderRadius: BorderRadius.circular(11),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          alignment: Alignment.center,
          decoration: selected
              ? null
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: cardShadow(opacity: .06, blur: 6),
                ),
          child: Text(
            label,
            style: AppTextStyles.sans(
              size: 13,
              weight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? selectedFg : AppColors.ink,
            ),
          ),
        ),
      ),
    );
    return fillWidth ? Expanded(child: child) : child;
  }
}
