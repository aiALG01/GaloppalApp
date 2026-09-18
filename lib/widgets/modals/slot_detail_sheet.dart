import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/lesson_slot.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_utils.dart';
import '../primary_button.dart';
import 'edit_slot_sheet.dart';

class SlotDetailSheet extends StatelessWidget {
  const SlotDetailSheet({super.key, required this.slot});

  final LessonSlot slot;

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    String confirmLabel = 'Ja',
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _removeBooking(
    BuildContext context,
    AppState app,
    SlotBooking booking,
  ) async {
    final ok = await _confirm(
      context,
      title: 'Ausladen?',
      body:
          '${booking.riderName} wird aus dieser Stunde ausgetragen und benachrichtigt. Das kann nicht rückgängig gemacht werden.',
      confirmLabel: 'Ausladen',
    );
    if (ok) await app.removeBookingFromActiveSlot(booking);
  }

  Future<void> _cancelSlot(
    BuildContext context,
    AppState app,
    LessonSlot slot,
  ) async {
    // Slot belongs to a series → first ask whether to cancel just this
    // lesson or the whole (future) series.
    var wholeSeries = false;
    if (slot.isSeries) {
      final scope = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Serientermin absagen'),
          content: const Text(
            'Diese Stunde gehört zu einer Serie. Möchtest du nur diese Stunde '
            'absagen oder die ganze Serie (alle künftigen Termine)?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('cancel'),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('one'),
              child: const Text('Nur diese Stunde'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('series'),
              child: const Text('Ganze Serie'),
            ),
          ],
        ),
      );
      if (scope == null || scope == 'cancel' || !context.mounted) return;
      wholeSeries = scope == 'series';
    }

    if (slot.bookings.isEmpty && !wholeSeries) {
      await app.cancelActiveSlot();
      if (context.mounted) Navigator.of(context).pop();
      return;
    }

    final startsIn = slot.startDateTime.difference(DateTime.now());
    final shortNotice =
        startsIn < const Duration(hours: 24) && startsIn > Duration.zero;
    final reasonController = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(wholeSeries ? 'Serie absagen?' : 'Stunde absagen?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              wholeSeries
                  ? 'Alle künftigen Termine dieser Serie werden abgesagt. '
                        'Angemeldete Schüler werden benachrichtigt.'
                  : shortNotice
                  ? 'Diese Stunde beginnt in weniger als 24 Stunden und hat ${slot.bookings.length} '
                        '${slot.bookings.length == 1 ? "Anmeldung" : "Anmeldungen"}. Bist du sicher?'
                  : '${slot.bookings.length} ${slot.bookings.length == 1 ? "Schüler wird" : "Schüler werden"} benachrichtigt und gefragt, ob das für sie in Ordnung ist.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Grund (optional, wird den Schülern mitgeteilt)',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Absagen'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await app.cancelActiveSlot(
      reason: reasonController.text.trim().isEmpty
          ? null
          : reasonController.text.trim(),
      wholeSeries: wholeSeries,
    );
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _proposeAlternate(
    BuildContext context,
    AppState app,
    LessonSlot slot,
    SlotBooking booking,
  ) async {
    var date = slot.date;
    var time = slot.startTime;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Neuen Termin für ${booking.riderName} vorschlagen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(longDayLabel(date)),
                trailing: const Icon(Icons.event),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: date,
                    firstDate: dateOnly(DateTime.now()),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => date = dateOnly(picked));
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('$time Uhr'),
                trailing: const Icon(Icons.schedule),
                onTap: () async {
                  final parts = time.split(':');
                  final picked = await showTimePicker(
                    context: ctx,
                    initialTime: TimeOfDay(
                      hour: int.parse(parts[0]),
                      minute: int.parse(parts[1]),
                    ),
                  );
                  if (picked != null) {
                    setState(
                      () => time =
                          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
                    );
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Vorschlagen'),
            ),
          ],
        ),
      ),
    );
    if (result == true) {
      await app.proposeAlternateTimeFor(
        booking,
        date: date,
        time: time,
        durationMinutes: slot.durationMinutes,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    // Prefer the live slot from AppState (kept fresh by refreshSlots after
    // e.g. "ausladen") over the snapshot passed in when the sheet opened, so
    // the roster and "Belegung x/y" update immediately.
    final slot = app.activeSlot ?? this.slot;
    final statusLabel = slot.isCanceled
        ? 'Storniert'
        : (slot.isFull ? 'Ausgebucht' : 'Buchbar');
    final canManageRoster = app.isTrainer && !slot.isCanceled;

    SlotBooking? myBooking;
    if (!app.isTrainer) {
      final uid = app.profile?.id;
      for (final b in slot.bookings) {
        if (b.riderId == uid) myBooking = b;
      }
    }
    final leadHours = app.primaryTrainer?.bookingLeadHours ?? 0;
    final canWithdraw =
        myBooking != null &&
        DateTime.now().isBefore(
          slot.startDateTime.subtract(Duration(hours: leadHours)),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reitstunde', style: AppTextStyles.serif(size: 24)),
                  const SizedBox(height: 5),
                  Text(
                    '${longDayLabel(slot.date)} · ${slot.startTime}–${slot.endTime}',
                    style: AppTextStyles.sans(
                      size: 13,
                      color: AppColors.inkFaint(.55),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.blueFaint(.18),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                statusLabel,
                style: AppTextStyles.sans(
                  size: 10.5,
                  weight: FontWeight.w600,
                  color: AppColors.blueText,
                ),
              ),
            ),
          ],
        ),
        if (slot.isCanceled && (slot.cancelReason ?? '').isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'Grund: ${slot.cancelReason}',
            style: AppTextStyles.sans(
              size: 12.5,
              color: AppColors.inkFaint(.55),
            ),
          ),
        ],
        const SizedBox(height: 18),
        Container(
          decoration: cardDecoration(),
          child: Column(
            children: [
              _DetailRow(
                label: 'Ort',
                value: slot.placeLabel(app.homeFacility),
              ),
              _DetailRow(label: 'Dauer', value: '${slot.durationMinutes} Min'),
              _DetailRow(
                label: 'Belegung',
                value: '${slot.bookings.length}/${slot.capacity}',
              ),
              _DetailRow(
                label: 'Serie',
                value: slot.isSeries ? 'Wöchentlich' : 'Einmalig',
                last: slot.bookings.isEmpty,
              ),
              if (slot.bookings.isEmpty)
                const SizedBox.shrink()
              else
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Schüler',
                        style: AppTextStyles.sans(
                          size: 13,
                          color: AppColors.inkFaint(.5),
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (final b in slot.bookings) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                b.riderName,
                                style: AppTextStyles.sans(
                                  size: 13.5,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (canManageRoster) ...[
                              InkWell(
                                onTap: () =>
                                    _proposeAlternate(context, app, slot, b),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.event_repeat,
                                    size: 17,
                                    color: AppColors.blueText,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () => _removeBooking(context, app, b),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.person_remove_outlined,
                                    size: 17,
                                    color: const Color(0xFFB3261E),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (b != slot.bookings.last) const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: 'Schließen',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            if (app.isTrainer && !slot.isCanceled) ...[
              const SizedBox(width: 10),
              Expanded(
                child: SecondaryButton(
                  label: 'Bearbeiten',
                  color: AppColors.blueText,
                  onPressed: () => openEditSlotSheet(context, app),
                ),
              ),
            ],
          ],
        ),
        if (!slot.isCanceled && app.isTrainer) ...[
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () => _cancelSlot(context, app, slot),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.ink,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              minimumSize: const Size.fromHeight(0),
            ),
            child: Text(
              'Stunde absagen',
              style: AppTextStyles.sans(
                size: 14.5,
                weight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ] else if (!slot.isCanceled && myBooking != null) ...[
          const SizedBox(height: 10),
          if (canWithdraw)
            FilledButton(
              onPressed: () async {
                final ok = await _confirm(
                  context,
                  title: 'Buchung stornieren?',
                  body: 'Dein Reitlehrer wird benachrichtigt.',
                  confirmLabel: 'Stornieren',
                );
                if (ok) await app.withdrawOwnBooking(slot);
                if (ok && context.mounted) Navigator.of(context).pop();
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.ink,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                minimumSize: const Size.fromHeight(0),
              ),
              child: Text(
                'Buchung stornieren',
                style: AppTextStyles.sans(
                  size: 14.5,
                  weight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            )
          else
            Text(
              'Stornierung nicht mehr möglich (weniger als $leadHours Std vor Beginn).',
              textAlign: TextAlign.center,
              style: AppTextStyles.sans(
                size: 12,
                color: AppColors.inkFaint(.5),
              ),
            ),
        ] else if (app.isTrainer) ...[
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () async {
              await app.deleteSlotPermanently(slot);
              if (context.mounted) Navigator.of(context).pop();
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB3261E),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              minimumSize: const Size.fromHeight(0),
            ),
            child: Text(
              'Endgültig löschen',
              style: AppTextStyles.sans(
                size: 14.5,
                weight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.last = false,
  });

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: AppColors.inkFaint(.06))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.sans(size: 13, color: AppColors.inkFaint(.5)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTextStyles.sans(size: 13.5, weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
