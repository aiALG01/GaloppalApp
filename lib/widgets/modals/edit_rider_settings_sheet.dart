import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../bottom_sheet_scaffold.dart';
import '../chip_option.dart';
import '../primary_button.dart';

const List<String> kReminderHours = ['1', '2', '6', '24'];

/// Lets a rider edit their stable/reminder settings (shown read-only on the
/// profile tab otherwise).
class EditRiderSettingsSheet extends StatefulWidget {
  const EditRiderSettingsSheet({super.key});

  @override
  State<EditRiderSettingsSheet> createState() => _EditRiderSettingsSheetState();
}

class _EditRiderSettingsSheetState extends State<EditRiderSettingsSheet> {
  late final TextEditingController _stableName;
  late String _reminderHours;

  @override
  void initState() {
    super.initState();
    final p = context.read<AppState>().profile!;
    _stableName = TextEditingController(text: p.stableName ?? '');
    _reminderHours = kReminderHours.contains('${p.reminderHours}')
        ? '${p.reminderHours}'
        : kReminderHours.first;
  }

  @override
  void dispose() {
    _stableName.dispose();
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
          'Deine Angaben als Schüler:in',
          style: AppTextStyles.sans(size: 12.5, color: AppColors.inkFaint(.55)),
        ),
        const SheetFieldLabel('Stall'),
        const SizedBox(height: 10),
        TextField(
          controller: _stableName,
          textCapitalization: TextCapitalization.words,
          style: AppTextStyles.sans(size: 13.5),
          decoration: InputDecoration(
            hintText: 'Name deines Stalls',
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
        const SheetFieldLabel('Erinnerungen'),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final h in kReminderHours) ...[
              ChipOption(
                label: '$h Std',
                selected: _reminderHours == h,
                onTap: () => setState(() => _reminderHours = h),
                selectedBg: AppColors.mint,
                selectedFg: AppColors.mintTextStrong,
                fillWidth: true,
              ),
              if (h != kReminderHours.last) const SizedBox(width: 8),
            ],
          ],
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
                          stableName: _stableName.text.trim(),
                          reminderHours: int.parse(_reminderHours),
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
