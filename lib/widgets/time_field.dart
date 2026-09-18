import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Tappable "HH:mm" value that opens an Apple-style spinning wheel to pick
/// a time in 5-minute steps.
class TimeField extends StatelessWidget {
  const TimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final parts = value.split(':');
        // Snap to a 5-minute grid so it lines up with the wheel's
        // `minuteInterval` (Cupertino asserts if the initial minute isn't a
        // multiple of the interval).
        final snappedMinute = (int.parse(parts[1]) / 5).round() * 5 % 60;
        var picked = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: snappedMinute,
        );
        await showModalBottomSheet<void>(
          context: context,
          backgroundColor: AppColors.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.sheet),
            ),
          ),
          builder: (sheetContext) => SafeArea(
            child: SizedBox(
              height: 260,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      CupertinoButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: Text(
                          'Fertig',
                          style: AppTextStyles.sans(
                            size: 15,
                            weight: FontWeight.w600,
                            color: AppColors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.time,
                      use24hFormat: true,
                      minuteInterval: 5,
                      initialDateTime: DateTime(
                        2024,
                        1,
                        1,
                        picked.hour,
                        picked.minute,
                      ),
                      onDateTimeChanged: (dt) =>
                          picked = TimeOfDay(hour: dt.hour, minute: dt.minute),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        onChanged(
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: cardDecoration(shadowOpacity: .05),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: AppTextStyles.eyebrow(color: AppColors.inkFaint(.42)),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  value,
                  style: AppTextStyles.sans(size: 16, weight: FontWeight.w600),
                ),
                Icon(Icons.schedule, size: 16, color: AppColors.inkFaint(.35)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
