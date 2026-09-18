import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/lesson_slot.dart';
import '../../models/profile.dart';
import '../../models/student_note.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_utils.dart';
import '../bottom_sheet_scaffold.dart';
import '../primary_button.dart';

String _writtenOn(DateTime d) =>
    '${d.day}.${d.month}.${d.year} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Trainer-only view of one student: a running notes trail (general, or
/// tied to a specific lesson before/after it) and their lesson history.
class StudentDetailSheet extends StatefulWidget {
  const StudentDetailSheet({super.key, required this.rider});

  final Profile rider;

  @override
  State<StudentDetailSheet> createState() => _StudentDetailSheetState();
}

class _StudentDetailSheetState extends State<StudentDetailSheet> {
  final _note = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    context.read<AppState>().loadStudentNotes(widget.rider.id);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _addGeneralNote(AppState app) async {
    if (_note.text.trim().isEmpty) return;
    setState(() => _saving = true);
    await app.addStudentNote(riderId: widget.rider.id, body: _note.text);
    _note.clear();
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lessons = app.lessonsForRider(widget.rider.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.rider.fullName,
          style: AppTextStyles.serif(size: 24, letterSpacing: -.2),
        ),
        const SizedBox(height: 5),
        Text(
          widget.rider.stableName ?? '',
          style: AppTextStyles.sans(size: 12.5, color: AppColors.inkFaint(.55)),
        ),
        const SheetFieldLabel('Notiz hinzufügen'),
        const SizedBox(height: 10),
        TextField(
          controller: _note,
          maxLines: 3,
          style: AppTextStyles.sans(size: 13.5),
          decoration: InputDecoration(
            hintText: 'Allgemeine Notiz zu diesem Schüler …',
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
        const SizedBox(height: 10),
        PrimaryButton(
          label: 'Notiz speichern',
          loading: _saving,
          onPressed: () => _addGeneralNote(app),
        ),
        const SheetFieldLabel('Notizverlauf'),
        const SizedBox(height: 10),
        if (app.loadingStudentNotes)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (app.studentNotes.isEmpty)
          Text(
            'Noch keine Notizen.',
            style: AppTextStyles.sans(
              size: 12.5,
              color: AppColors.inkFaint(.5),
            ),
          )
        else
          Column(
            children: [
              for (final n in app.studentNotes) ...[
                _NoteTile(app: app, note: n, lessons: lessons),
                const SizedBox(height: 8),
              ],
            ],
          ),
        const SheetFieldLabel('Stunden'),
        const SizedBox(height: 10),
        if (lessons.isEmpty)
          Text(
            'Noch keine gemeinsamen Stunden.',
            style: AppTextStyles.sans(
              size: 12.5,
              color: AppColors.inkFaint(.5),
            ),
          )
        else
          Column(
            children: [
              for (final s in lessons) ...[
                _LessonRow(app: app, rider: widget.rider, slot: s),
                const SizedBox(height: 8),
              ],
            ],
          ),
        const SizedBox(height: 16),
        SecondaryButton(
          label: 'Schließen',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({
    required this.app,
    required this.note,
    required this.lessons,
  });

  final AppState app;
  final StudentNote note;
  final List<LessonSlot> lessons;

  @override
  Widget build(BuildContext context) {
    String badge;
    if (note.isGeneral) {
      badge = 'Allgemein';
    } else {
      final slot = lessons.where((s) => s.id == note.slotId).toList();
      final when = slot.isEmpty ? '' : ' · ${longDayLabel(slot.first.date)}';
      badge = '${note.phase == 'after' ? 'Nach' : 'Vor'}$when';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: cardDecoration(shadowOpacity: .05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: note.isGeneral
                      ? AppColors.mintFaint(.22)
                      : AppColors.blueFaint(.18),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  badge,
                  style: AppTextStyles.sans(
                    size: 10,
                    weight: FontWeight.w600,
                    color: note.isGeneral
                        ? AppColors.mintText
                        : AppColors.blueText,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _writtenOn(note.createdAt),
                style: AppTextStyles.sans(
                  size: 10.5,
                  color: AppColors.inkFaint(.4),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => app.deleteStudentNote(note),
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: AppColors.inkFaint(.35),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(note.body, style: AppTextStyles.sans(size: 13, height: 1.4)),
        ],
      ),
    );
  }
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({
    required this.app,
    required this.rider,
    required this.slot,
  });

  final AppState app;
  final Profile rider;
  final LessonSlot slot;

  Future<void> _composeNote(BuildContext context, String phase) async {
    final controller = TextEditingController();
    final body = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          phase == 'before' ? 'Notiz vor der Stunde' : 'Notiz nach der Stunde',
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Notiz …'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    if (body != null && body.trim().isNotEmpty) {
      await app.addStudentNote(
        riderId: rider.id,
        body: body,
        slotId: slot.id,
        phase: phase,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: cardDecoration(shadowOpacity: .05),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${longDayLabel(slot.date)}, ${slot.startTime} Uhr',
                  style: AppTextStyles.sans(size: 13, weight: FontWeight.w600),
                ),
                Text(
                  '${slot.durationMinutes} Min',
                  style: AppTextStyles.sans(
                    size: 11,
                    color: AppColors.inkFaint(.5),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _composeNote(context, 'before'),
            child: const Text('Vor'),
          ),
          TextButton(
            onPressed: () => _composeNote(context, 'after'),
            child: const Text('Nach'),
          ),
        ],
      ),
    );
  }
}
