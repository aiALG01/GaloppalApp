import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../state/slot_form_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_utils.dart';
import '../bottom_sheet_scaffold.dart';
import '../chip_option.dart';
import '../primary_button.dart';
import '../time_field.dart';

String _hm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// "Buchbare Stunde" creation sheet (trainer only). Modus / Dauer /
/// Wiederholung are collapsed by default (pre-filled from the trainer's
/// saved defaults) so the form stays short; the date, start time, seats and
/// facility are always visible.
class SlotFormSheet extends StatelessWidget {
  const SlotFormSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final form = app.form;
    // A range with no publishable time left is a hard block (nothing to
    // create). A single slot that collides with the calendar is only a
    // warning — the trainer can still choose "Trotzdem veröffentlichen".
    final singleConflict = form.isRange ? null : app.formSingleConflict;
    final rangeBlocked = form.isRange && app.formRangeFreeStartTimes.isEmpty;
    final blocked = rangeBlocked || singleConflict != null;

    final modeLabel =
        form.mode == SlotFormMode.range ? 'Zeitraum' : 'Einzelne Stunde';
    final repeatLabel = form.isRepeating
        ? '${form.repeat} · ${form.count}×'
        : 'Einmalig';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Buchbare Stunde',
          style: AppTextStyles.serif(size: 24, letterSpacing: -.2),
        ),
        const SizedBox(height: 5),
        Text(
          'Für deine Schüler sichtbar',
          style: AppTextStyles.sans(size: 12.5, color: AppColors.inkFaint(.55)),
        ),
        const SheetFieldLabel('Datum'),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: app.selectedDay,
              firstDate: dateOnly(DateTime.now()),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) app.selectDay(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: cardDecoration(shadowOpacity: .05),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  longDayLabel(app.selectedDay),
                  style: AppTextStyles.sans(size: 14, weight: FontWeight.w600),
                ),
                Icon(Icons.event, size: 16, color: AppColors.inkFaint(.35)),
              ],
            ),
          ),
        ),
        if (app.deviceBusyBlocks.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.blueFaint(.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BEREITS IN DEINEM KALENDER',
                  style: AppTextStyles.eyebrow(color: AppColors.blueText),
                ),
                const SizedBox(height: 6),
                for (final b in app.deviceBusyBlocks)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      b.allDay
                          ? 'ganztägig · ${b.title}'
                          : '${_hm(b.start)}–${_hm(b.end)} · ${b.title}',
                      style: AppTextStyles.sans(
                        size: 12.5,
                        color: AppColors.blueText,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],

        // ---- Modus (collapsible) ----
        _CollapsibleSection(
          label: 'Modus',
          value: modeLabel,
          child: Row(
            children: [
              ChipOption(
                label: 'Einzelne Stunde',
                selected: form.mode == SlotFormMode.single,
                onTap: () => app.setFormMode(SlotFormMode.single),
                selectedBg: AppColors.green,
                fillWidth: true,
              ),
              const SizedBox(width: 8),
              ChipOption(
                label: 'Zeitraum',
                selected: form.mode == SlotFormMode.range,
                onTap: () => app.setFormMode(SlotFormMode.range),
                selectedBg: AppColors.green,
                fillWidth: true,
              ),
            ],
          ),
        ),

        if (form.isRange) ...[
          const SheetFieldLabel('Zeitraum'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TimeField(
                  label: 'Von',
                  value: form.rangeStart,
                  onChanged: app.setFormRangeStart,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TimeField(
                  label: 'Bis',
                  value: form.rangeEnd,
                  onChanged: app.setFormRangeEnd,
                ),
              ),
            ],
          ),
        ] else ...[
          const SheetFieldLabel('Beginn'),
          const SizedBox(height: 10),
          TimeField(
            label: 'Startzeit',
            value: form.time,
            onChanged: app.setFormTime,
          ),
        ],

        // ---- Dauer (collapsible) ----
        _CollapsibleSection(
          label: 'Dauer',
          value: '${form.duration} Min',
          child: Row(
            children: [
              for (final d in kSlotDurations) ...[
                ChipOption(
                  label: '$d Min',
                  selected: form.duration == d,
                  onTap: () => app.setFormDuration(d),
                  selectedBg: AppColors.green,
                  fillWidth: true,
                ),
                if (d != kSlotDurations.last) const SizedBox(width: 8),
              ],
            ],
          ),
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
                onTap: app.capMinus,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${form.capacity}',
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
              _StepperButton(icon: Icons.add, filled: true, onTap: app.capPlus),
            ],
          ),
        ),

        const SizedBox(height: 16),
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
                      'Eigene Anlage',
                      style: AppTextStyles.sans(
                        size: 13.5,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      form.away
                          ? 'Andere Anlage angeben'
                          : (app.profile?.facility ?? '–'),
                      style: AppTextStyles.sans(
                        size: 11.5,
                        color: AppColors.inkFaint(.5),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                // Switch ON = eigene Anlage (the common case, so it's the
                // default). Turning it off reveals the away-facility field.
                value: !form.away,
                activeThumbColor: AppColors.green,
                onChanged: (_) => app.toggleFormAway(),
              ),
            ],
          ),
        ),
        if (form.away) ...[
          const SizedBox(height: 10),
          _AwayFacilityField(
            initialValue: form.awayFacility,
            onChanged: app.setFormAwayFacility,
          ),
        ],

        // ---- Wiederholung (collapsible) ----
        _CollapsibleSection(
          label: 'Wiederholung',
          value: repeatLabel,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  for (final r in kSlotRepeats) ...[
                    ChipOption(
                      label: r,
                      selected: form.repeat == r,
                      onTap: () => app.setFormRepeat(r),
                      fillWidth: true,
                    ),
                    if (r != kSlotRepeats.last) const SizedBox(width: 8),
                  ],
                ],
              ),
              if (form.isRepeating) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final c in kSlotCounts) ...[
                      ChipOption(
                        label: '$c×',
                        selected: form.count == c,
                        onTap: () => app.setFormCount(c),
                        selectedBg: AppColors.blue,
                        fillWidth: true,
                      ),
                      if (c != kSlotCounts.last) const SizedBox(width: 8),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: BoxDecoration(
            color: blocked
                ? const Color(0xFFB3261E).withValues(alpha: .08)
                : AppColors.green.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            app.formSummary,
            style: AppTextStyles.sans(
              size: 12.5,
              color: blocked ? const Color(0xFFB3261E) : AppColors.mintText,
              height: 1.5,
            ),
          ),
        ),
        if (app.deviceAllDayHints.isNotEmpty) ...[
          const SizedBox(height: 8),
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
                label: 'Veröffentlichen',
                loading: app.savingSlot,
                onPressed: app.savingSlot || rangeBlocked
                    ? null
                    : () async {
                        if (singleConflict != null) {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Terminüberschneidung'),
                              content: Text(
                                'Zu dieser Zeit hast du in deinem Kalender bereits '
                                '„${singleConflict.title}" '
                                '(${_hm(singleConflict.start)}–${_hm(singleConflict.end)}). '
                                'Stunde trotzdem veröffentlichen?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: const Text('Abbrechen'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: const Text('Trotzdem veröffentlichen'),
                                ),
                              ],
                            ),
                          );
                          if (ok != true) return;
                        }
                        await app.saveSlot(
                          ignoreCalendarConflict: singleConflict != null,
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

/// A labelled row that shows its current [value] and expands on tap to
/// reveal [child] (the picker). Collapsed by default to keep the form short.
class _CollapsibleSection extends StatefulWidget {
  const _CollapsibleSection({
    required this.label,
    required this.value,
    required this.child,
  });

  final String label;
  final String value;
  final Widget child;

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text(
                  widget.label.toUpperCase(),
                  style: AppTextStyles.eyebrow(color: AppColors.inkFaint(.42)),
                ),
                const Spacer(),
                Text(
                  widget.value,
                  style: AppTextStyles.sans(
                    size: 13,
                    weight: FontWeight.w600,
                    color: AppColors.inkFaint(.7),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: AppColors.inkFaint(.4),
                ),
              ],
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 10),
          widget.child,
        ],
      ],
    );
  }
}

/// Keeps its own [TextEditingController] so typing doesn't get clobbered by
/// the parent rebuilding on every [AppState] change.
class _AwayFacilityField extends StatefulWidget {
  const _AwayFacilityField({
    required this.initialValue,
    required this.onChanged,
  });

  final String initialValue;
  final ValueChanged<String> onChanged;

  @override
  State<_AwayFacilityField> createState() => _AwayFacilityFieldState();
}

class _AwayFacilityFieldState extends State<_AwayFacilityField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      style: AppTextStyles.sans(size: 13.5),
      decoration: InputDecoration(
        hintText: 'Name der Anlage',
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
