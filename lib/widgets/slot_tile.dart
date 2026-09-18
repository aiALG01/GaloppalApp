import 'package:flutter/material.dart';

import '../models/lesson_slot.dart';
import '../theme/app_theme.dart';
import '../utils/date_utils.dart';
import 'status_badge.dart';

/// List row for a lesson slot, used on Home, Calendar and (read-only) other
/// lists. [showDayLabel] renders the short weekday above the start time
/// (Home screen style); otherwise it renders start–end time (Calendar
/// style) with an optional "Serie" tag.
class SlotTile extends StatelessWidget {
  const SlotTile({
    super.key,
    required this.slot,
    required this.homeFacility,
    this.showDayLabel = false,
    this.onTap,
  });

  final LessonSlot slot;
  final String homeFacility;
  final bool showDayLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        decoration: cardDecoration(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: showDayLabel ? 64 : 68,
              padding: const EdgeInsets.only(right: 13),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: AppColors.inkFaint(.09)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: showDayLabel
                    ? [
                        Text(
                          weekdayShortLabel(slot.date),
                          style: AppTextStyles.sans(
                            size: 10.5,
                            color: AppColors.inkFaint(.42),
                            letterSpacing: .3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            slot.startTime,
                            style: AppTextStyles.sans(
                              size: 15,
                              weight: FontWeight.w700,
                              letterSpacing: -.1,
                            ),
                          ),
                        ),
                      ]
                    : [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            slot.startTime,
                            style: AppTextStyles.sans(
                              size: 15,
                              weight: FontWeight.w700,
                              letterSpacing: -.1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            slot.endTime,
                            style: AppTextStyles.sans(
                              size: 11.5,
                              color: AppColors.inkFaint(.42),
                            ),
                          ),
                        ),
                      ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${slot.startTime}–${slot.endTime} Uhr',
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.sans(
                            size: 14.5,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (!showDayLabel && slot.isSeries) ...[
                        const SizedBox(width: 7),
                        _SeriesTag(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(
                        Icons.home_work_outlined,
                        size: 12,
                        color: AppColors.inkFaint(.5),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          slot.placeLabel(homeFacility),
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.sans(
                            size: 11.5,
                            color: AppColors.inkFaint(.5),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.groups_outlined,
                        size: 12,
                        color: AppColors.inkFaint(.5),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${slot.bookings.length}/${slot.capacity}',
                        style: AppTextStyles.sans(
                          size: 11.5,
                          color: AppColors.inkFaint(.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusBadge(slot: slot),
          ],
        ),
      ),
    );
  }
}

class _SeriesTag extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.blueFaint(.16),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.repeat, size: 10, color: AppColors.blueText),
          const SizedBox(width: 4),
          Text(
            'Serie',
            style: AppTextStyles.sans(
              size: 10,
              weight: FontWeight.w600,
              color: AppColors.blueText,
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({super.key, required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .5),
        border: Border.all(color: AppColors.inkFaint(.18)),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.serif(size: 17),
          ),
          const SizedBox(height: 5),
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppTextStyles.sans(
              size: 12.5,
              color: AppColors.inkFaint(.5),
            ),
          ),
        ],
      ),
    );
  }
}
