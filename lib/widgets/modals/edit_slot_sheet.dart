import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../state/slot_form_state.dart';
import '../../theme/app_theme.dart';
import '../bottom_sheet_scaffold.dart';
import '../chip_option.dart';
import '../primary_button.dart';

Future<void> openEditSlotSheet(BuildContext context, AppState app) async {
  await showAppBottomSheet(context, builder: (_) => const EditSlotSheet());
}

/// Edits an already-published slot's capacity/duration — e.g. to fit in
/// more riders after approving a request that only booked one seat. Doesn't
/// move the date/time (see "Anderen Termin vorschlagen" per rider in the
/// detail sheet for that).
class EditSlotSheet extends StatefulWidget {
  const EditSlotSheet({super.key});

  @override
  State<EditSlotSheet> createState() => _EditSlotSheetState();
}

class _EditSlotSheetState extends State<EditSlotSheet> {
  late int _capacity;
  late String _duration;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>().activeSlot!;
    _capacity = s.capacity;
    _duration = kSlotDurations.contains('${s.durationMinutes}')
        ? '${s.durationMinutes}'
        : kSlotDurations.first;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.activeSlot!;
    final minCapacity = s.bookings.length.clamp(1, 12);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Stunde bearbeiten',
          style: AppTextStyles.serif(size: 24, letterSpacing: -.2),
        ),
        const SizedBox(height: 5),
        Text(
          '${s.startTime}–${s.endTime} Uhr',
          style: AppTextStyles.sans(size: 12.5, color: AppColors.inkFaint(.55)),
        ),
        const SheetFieldLabel('Plätze'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: cardDecoration(shadowOpacity: .06),
          child: Row(
            children: [
              _StepperButton(
                icon: Icons.remove,
                filled: false,
                onTap: () => setState(
                  () => _capacity = (_capacity - 1).clamp(minCapacity, 12),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '$_capacity',
                      style: AppTextStyles.serif(
                        size: 22,
                        weight: FontWeight.w700,
                        letterSpacing: -.3,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Schüler pro Stunde',
                      style: AppTextStyles.sans(
                        size: 11,
                        color: AppColors.inkFaint(.5),
                      ),
                    ),
                  ],
                ),
              ),
              _StepperButton(
                icon: Icons.add,
                filled: true,
                onTap: () => setState(
                  () => _capacity = (_capacity + 1).clamp(minCapacity, 12),
                ),
              ),
            ],
          ),
        ),
        if (s.bookings.length > 1) ...[
          const SizedBox(height: 6),
          Text(
            'Mindestens ${s.bookings.length} — schon so viele angemeldet.',
            style: AppTextStyles.sans(size: 11, color: AppColors.inkFaint(.45)),
          ),
        ],
        const SheetFieldLabel('Dauer'),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final d in kSlotDurations) ...[
              ChipOption(
                label: '$d Min',
                selected: _duration == d,
                onTap: () => setState(() => _duration = d),
                selectedBg: AppColors.green,
                fillWidth: true,
              ),
              if (d != kSlotDurations.last) const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: 'Abbrechen',
                onPressed: app.savingSlot
                    ? null
                    : () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: PrimaryButton(
                label: 'Speichern',
                loading: app.savingSlot,
                onPressed: app.savingSlot
                    ? null
                    : () async {
                        await app.updateActiveSlot(
                          capacity: _capacity,
                          durationMinutes: int.parse(_duration),
                        );
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

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? AppColors.green : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: filled
            ? BorderSide.none
            : BorderSide(color: AppColors.inkFaint(.12)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(
            icon,
            size: 16,
            color: filled ? Colors.white : AppColors.ink,
          ),
        ),
      ),
    );
  }
}
