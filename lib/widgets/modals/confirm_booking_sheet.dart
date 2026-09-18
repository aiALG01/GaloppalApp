import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/lesson_slot.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_utils.dart';
import '../primary_button.dart';

String _hm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

class ConfirmBookingSheet extends StatelessWidget {
  const ConfirmBookingSheet({super.key, required this.slot});

  final LessonSlot slot;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    // Prefer the live slot from AppState so the "belegt" count stays current
    // if bookings change while this sheet is open.
    final slot = app.activeSlot ?? this.slot;
    final trainer = app.primaryTrainer;
    final conflict = app.conflictForSlot(slot);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Platz reservieren', style: AppTextStyles.serif(size: 24)),
        const SizedBox(height: 6),
        Text(
          '${longDayLabel(slot.date)} · ${slot.placeLabel(app.homeFacility)}',
          style: AppTextStyles.sans(size: 13, color: AppColors.inkFaint(.55)),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: cardDecoration(),
          child: Row(
            children: [
              const SizedBox(
                width: 44,
                height: 44,
                child: PlaceholderStripe(borderRadius: AppRadius.md),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trainer?.fullName ?? '',
                      style: AppTextStyles.sans(
                        size: 14.5,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${slot.durationMinutes} Min · ${slot.bookings.length} belegt',
                      style: AppTextStyles.sans(
                        size: 12,
                        color: AppColors.inkFaint(.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (conflict != null) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFB3261E).withValues(alpha: .08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Kollidiert mit „${conflict.title}“ in deinem Kalender (${_hm(conflict.start)}–${_hm(conflict.end)}).',
              style: AppTextStyles.sans(
                size: 12.5,
                color: const Color(0xFFB3261E),
                height: 1.4,
              ),
            ),
          ),
        ],
        if (app.deviceAllDayHints.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Hinweis: an dem Tag hast du einen ganztägigen Termin '
            '(${app.deviceAllDayHints.map((b) => b.title).join(', ')}).',
            style: AppTextStyles.sans(
              size: 11.5,
              color: AppColors.inkFaint(.55),
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: 'Zurück',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: PrimaryButton(
                label: 'Jetzt buchen',
                onPressed: conflict != null
                    ? null
                    : () async {
                        await app.confirmBookingActive();
                        if (context.mounted) Navigator.of(context).pop();
                      },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
