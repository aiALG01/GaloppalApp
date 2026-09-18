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

/// Lets a rider propose a lesson time their trainer hasn't published —
/// only reachable when the trainer has turned requests on.
class RequestLessonSheet extends StatefulWidget {
  const RequestLessonSheet({super.key});

  @override
  State<RequestLessonSheet> createState() => _RequestLessonSheetState();
}

class _RequestLessonSheetState extends State<RequestLessonSheet> {
  late DateTime _date;
  String _time = '15:00';
  String _duration = '45';
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    _date = app.selectedDay.isBefore(dateOnly(DateTime.now()))
        ? dateOnly(DateTime.now())
        : app.selectedDay;
    _duration =
        kSlotDurations.contains('${app.primaryTrainer?.defaultDurationMinutes}')
        ? '${app.primaryTrainer!.defaultDurationMinutes}'
        : kSlotDurations.first;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: dateOnly(DateTime.now()),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = dateOnly(picked));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Stunde anfragen',
          style: AppTextStyles.serif(size: 24, letterSpacing: -.2),
        ),
        const SizedBox(height: 5),
        Text(
          '${app.primaryTrainer?.fullName ?? ''} entscheidet, ob der Termin passt.',
          style: AppTextStyles.sans(size: 12.5, color: AppColors.inkFaint(.55)),
        ),
        const SheetFieldLabel('Wunschtermin'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _pickDate(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: cardDecoration(shadowOpacity: .05),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'DATUM',
                        style: AppTextStyles.eyebrow(
                          color: AppColors.inkFaint(.42),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              longDayLabel(_date),
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.sans(
                                size: 14,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.event,
                            size: 16,
                            color: AppColors.inkFaint(.35),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TimeField(
                label: 'Uhrzeit',
                value: _time,
                onChanged: (v) => setState(() => _time = v),
              ),
            ),
          ],
        ),
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
        const SheetFieldLabel('Nachricht (optional)'),
        const SizedBox(height: 10),
        TextField(
          controller: _note,
          maxLines: 2,
          style: AppTextStyles.sans(size: 13.5),
          decoration: InputDecoration(
            hintText: 'z. B. Grund oder Wunsch',
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
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: 'Abbrechen',
                onPressed: app.savingRequest
                    ? null
                    : () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: PrimaryButton(
                label: 'Anfragen',
                loading: app.savingRequest,
                onPressed: app.savingRequest
                    ? null
                    : () async {
                        final ok = await app.submitLessonRequest(
                          date: _date,
                          time: _time,
                          durationMinutes: int.parse(_duration),
                          note: _note.text.trim().isEmpty
                              ? null
                              : _note.text.trim(),
                        );
                        if (ok && context.mounted) Navigator.of(context).pop();
                      },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
