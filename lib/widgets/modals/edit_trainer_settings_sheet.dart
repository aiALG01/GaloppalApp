import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../state/slot_form_state.dart';
import '../../theme/app_theme.dart';
import '../bottom_sheet_scaffold.dart';
import '../chip_option.dart';
import '../primary_button.dart';

const List<String> kBookingLeadHours = ['6', '12', '24', '48'];

/// Lets a trainer edit their default scheduling settings (shown read-only
/// on the profile tab otherwise).
class EditTrainerSettingsSheet extends StatefulWidget {
  const EditTrainerSettingsSheet({super.key});

  @override
  State<EditTrainerSettingsSheet> createState() =>
      _EditTrainerSettingsSheetState();
}

class _EditTrainerSettingsSheetState extends State<EditTrainerSettingsSheet> {
  late final TextEditingController _facility;
  late final TextEditingController _address;
  late String _duration;
  late SlotFormMode _mode;
  late String _repeat;
  late int _capacity;
  late String _leadHours;
  late bool _allowRequests;

  @override
  void initState() {
    super.initState();
    final p = context.read<AppState>().profile!;
    _facility = TextEditingController(text: p.facility ?? '');
    _address = TextEditingController(text: p.address ?? '');
    _duration = kSlotDurations.contains('${p.defaultDurationMinutes}')
        ? '${p.defaultDurationMinutes}'
        : kSlotDurations.first;
    _mode = slotModeFromString(p.defaultSlotMode);
    _repeat = kSlotRepeats.contains(p.defaultRepeat)
        ? p.defaultRepeat
        : kSlotRepeats.first;
    _capacity = p.defaultCapacity;
    _leadHours = kBookingLeadHours.contains('${p.bookingLeadHours}')
        ? '${p.bookingLeadHours}'
        : kBookingLeadHours.first;
    _allowRequests = p.allowRequests;
  }

  @override
  void dispose() {
    _facility.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Einstellungen',
          style: AppTextStyles.serif(size: 24, letterSpacing: -.2),
        ),
        const SizedBox(height: 5),
        Text(
          'Standardwerte für neue Stunden',
          style: AppTextStyles.sans(size: 12.5, color: AppColors.inkFaint(.55)),
        ),
        const SheetFieldLabel('Bezeichnung deines Standard-Trainingsorts'),
        const SizedBox(height: 10),
        TextField(
          controller: _facility,
          textCapitalization: TextCapitalization.words,
          style: AppTextStyles.sans(size: 13.5),
          decoration: InputDecoration(
            hintText: 'z. B. Reitanlage Sonnenhof',
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SheetFieldLabel('Adresse'),
        const SizedBox(height: 4),
        Text(
          'Damit Schüler deine Anlage direkt in Karten finden.',
          style: AppTextStyles.sans(size: 11, color: AppColors.inkFaint(.45)),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _address,
          textCapitalization: TextCapitalization.words,
          style: AppTextStyles.sans(size: 13.5),
          decoration: InputDecoration(
            hintText: 'Straße, PLZ, Ort',
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SheetFieldLabel('Standard-Dauer'),
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
        const SheetFieldLabel('Standard-Modus'),
        const SizedBox(height: 10),
        Row(
          children: [
            ChipOption(
              label: 'Einzelne Stunde',
              selected: _mode == SlotFormMode.single,
              onTap: () => setState(() => _mode = SlotFormMode.single),
              selectedBg: AppColors.green,
              fillWidth: true,
            ),
            const SizedBox(width: 8),
            ChipOption(
              label: 'Zeitraum',
              selected: _mode == SlotFormMode.range,
              onTap: () => setState(() => _mode = SlotFormMode.range),
              selectedBg: AppColors.green,
              fillWidth: true,
            ),
          ],
        ),
        const SheetFieldLabel('Standard-Wiederholung'),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final r in kSlotRepeats) ...[
              ChipOption(
                label: r,
                selected: _repeat == r,
                onTap: () => setState(() => _repeat = r),
                fillWidth: true,
              ),
              if (r != kSlotRepeats.last) const SizedBox(width: 8),
            ],
          ],
        ),
        const SheetFieldLabel('Standard-Plätze'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: cardDecoration(shadowOpacity: .06),
          child: Row(
            children: [
              _StepperButton(
                icon: Icons.remove,
                filled: false,
                onTap: () =>
                    setState(() => _capacity = (_capacity - 1).clamp(1, 12)),
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
                onTap: () =>
                    setState(() => _capacity = (_capacity + 1).clamp(1, 12)),
              ),
            ],
          ),
        ),
        const SheetFieldLabel('Buchungsfrist'),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final h in kBookingLeadHours) ...[
              ChipOption(
                label: '$h Std',
                selected: _leadHours == h,
                onTap: () => setState(() => _leadHours = h),
                selectedBg: AppColors.blue,
                fillWidth: true,
              ),
              if (h != kBookingLeadHours.last) const SizedBox(width: 8),
            ],
          ],
        ),
        const SheetFieldLabel('Stundenanfragen'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: cardDecoration(shadowOpacity: .06),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Anfragen erlauben',
                      style: AppTextStyles.sans(
                        size: 13.5,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Schüler können Termine außerhalb deiner veröffentlichten Stunden anfragen.',
                      style: AppTextStyles.sans(
                        size: 11.5,
                        color: AppColors.inkFaint(.5),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _allowRequests,
                activeThumbColor: AppColors.green,
                onChanged: (v) => setState(() => _allowRequests = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: 'Abbrechen',
                onPressed: app.savingProfile
                    ? null
                    : () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: PrimaryButton(
                label: 'Speichern',
                loading: app.savingProfile,
                onPressed: app.savingProfile
                    ? null
                    : () async {
                        await app.updateProfileFields(
                          facility: _facility.text.trim(),
                          address: _address.text.trim(),
                          defaultDurationMinutes: int.parse(_duration),
                          defaultCapacity: _capacity,
                          defaultSlotMode: slotModeToString(_mode),
                          defaultRepeat: _repeat,
                          bookingLeadHours: int.parse(_leadHours),
                          allowRequests: _allowRequests,
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
