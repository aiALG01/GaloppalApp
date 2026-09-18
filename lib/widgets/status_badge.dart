import 'package:flutter/material.dart';

import '../models/lesson_slot.dart';
import '../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.slot});

  final LessonSlot slot;

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final Color fg;
    late final String label;
    if (slot.isCanceled) {
      bg = AppColors.blueFaint(.2);
      fg = AppColors.blueText;
      label = 'Storniert';
    } else if (slot.isFull) {
      bg = AppColors.green;
      fg = Colors.white;
      label = 'Ausgebucht';
    } else {
      bg = AppColors.mintFaint(.22);
      fg = AppColors.mintText;
      label = 'Buchbar';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppTextStyles.sans(
          size: 10.5,
          weight: FontWeight.w600,
          color: fg,
          letterSpacing: .4,
        ),
      ),
    );
  }
}
