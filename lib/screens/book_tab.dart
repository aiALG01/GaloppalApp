import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/lesson_request.dart';
import '../models/lesson_slot.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/date_utils.dart';
import '../widgets/modals/modal_launchers.dart';
import '../widgets/primary_button.dart';
import '../widgets/tab_scroll_view.dart';

String _hm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

class BookTab extends StatelessWidget {
  const BookTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final trainer = app.primaryTrainer;

    return TabScrollView(
      children: [
        Text(
          'Stunde buchen',
          style: AppTextStyles.serif(size: 31, letterSpacing: -.3),
        ),
        const SizedBox(height: 20),
        if (trainer == null)
          _NoTrainerCard(app: app)
        else ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
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
                        trainer.fullName,
                        style: AppTextStyles.sans(
                          size: 14.5,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        trainer.facility ?? '',
                        style: AppTextStyles.sans(
                          size: 11.5,
                          color: AppColors.inkFaint(.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.mintFaint(.22),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Verknüpft',
                    style: AppTextStyles.sans(
                      size: 10.5,
                      weight: FontWeight.w600,
                      color: AppColors.mintText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          () {
            final monday = app.selectedDay.subtract(
              Duration(days: app.selectedDay.weekday - 1),
            );
            final sunday = monday.add(const Duration(days: 6));
            final sameMonth = monday.month == sunday.month;
            final label = sameMonth
                ? '${monday.day}.–${sunday.day}. ${monthNamesDe[sunday.month - 1]}'
                : '${monday.day}. ${monthNamesDe[monday.month - 1]} – ${sunday.day}. ${monthNamesDe[sunday.month - 1]}';
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () => app.shiftSelectedWeek(-1),
                  child: const Icon(
                    Icons.chevron_left,
                    size: 20,
                    color: AppColors.blue,
                  ),
                ),
                Text(
                  label,
                  style: AppTextStyles.sans(
                    size: 12.5,
                    weight: FontWeight.w600,
                    color: AppColors.blueText,
                  ),
                ),
                InkWell(
                  onTap: () => app.shiftSelectedWeek(1),
                  child: const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AppColors.blue,
                  ),
                ),
              ],
            );
          }(),
          const SizedBox(height: 10),
          SizedBox(
            height: 66,
            child: Row(
              children: [
                for (final d in List.generate(
                  7,
                  (i) => app.selectedDay.add(
                    Duration(days: i - app.selectedDay.weekday + 1),
                  ),
                )) ...[
                  Expanded(
                    child: _DayChip(app: app, date: d),
                  ),
                  if (d.weekday != DateTime.sunday) const SizedBox(width: 7),
                ],
              ],
            ),
          ),

          if (app.lessonRequests.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Meine Anfragen', style: AppTextStyles.serif(size: 19)),
            const SizedBox(height: 13),
            Column(
              children: [
                for (final r in app.lessonRequests) ...[
                  _RequestTile(app: app, request: r),
                  const SizedBox(height: 11),
                ],
              ],
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'Freie Plätze · ${longDayLabel(app.selectedDay)}',
            style: AppTextStyles.serif(size: 19),
          ),
          if (app.deviceBusyBlocks.isNotEmpty) ...[
            const SizedBox(height: 10),
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
          const SizedBox(height: 13),
          if (app.freeSlotsForSelectedDay.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .5),
                border: Border.all(color: AppColors.inkFaint(.18)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'An diesem Tag sind alle Plätze belegt.',
                textAlign: TextAlign.center,
                style: AppTextStyles.sans(
                  size: 12.5,
                  color: AppColors.inkFaint(.5),
                ),
              ),
            )
          else
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.55,
              children: [
                for (final s in app.freeSlotsForSelectedDay)
                  _FreeSlotCard(app: app, slot: s),
              ],
            ),
          if (trainer.allowRequests) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
              decoration: BoxDecoration(
                color: AppColors.blueFaint(.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Passende Zeit nicht dabei?',
                          style: AppTextStyles.sans(
                            size: 13.5,
                            weight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Frag deinen Reitlehrer nach einem anderen Termin.',
                          style: AppTextStyles.sans(
                            size: 11.5,
                            color: AppColors.inkFaint(.5),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 130,
                    child: SecondaryButton(
                      label: 'Anfragen',
                      color: AppColors.blueText,
                      onPressed: () => openRequestLessonSheet(context, app),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _NoTrainerCard extends StatelessWidget {
  const _NoTrainerCard({required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: cardShadow(blur: 16),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.link, color: AppColors.green),
          ),
          const SizedBox(height: 14),
          Text('Noch kein Reitlehrer', style: AppTextStyles.serif(size: 21)),
          const SizedBox(height: 7),
          Text(
            'Finde deinen Reitlehrer über den Namen oder füge den Einladungslink ein.',
            textAlign: TextAlign.center,
            style: AppTextStyles.sans(
              size: 12.5,
              color: AppColors.inkFaint(.55),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            label: 'Reitlehrer finden',
            onPressed: () => openAddTrainerSheet(context, app),
          ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.app, required this.date});

  final AppState app;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final selected = isSameDate(date, app.selectedDay);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => app.selectDay(date),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? AppColors.blue : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected ? null : cardShadow(opacity: .05, blur: 6),
        ),
        child: Column(
          children: [
            Text(
              weekdayShortLabel(date),
              style: AppTextStyles.sans(
                size: 10,
                color: selected
                    ? Colors.white.withValues(alpha: .65)
                    : AppColors.inkFaint(.45),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${date.day}',
              style: AppTextStyles.sans(
                size: 15,
                weight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FreeSlotCard extends StatelessWidget {
  const _FreeSlotCard({required this.app, required this.slot});

  final AppState app;
  final LessonSlot slot;

  @override
  Widget build(BuildContext context) {
    final conflict = app.conflictForSlot(slot);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => openConfirmBookingSheet(context, app, slot),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border(
            left: BorderSide(
              color: conflict != null
                  ? const Color(0xFFB3261E)
                  : AppColors.mintText,
              width: 3,
            ),
          ),
          boxShadow: cardShadow(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                slot.startTime,
                style: AppTextStyles.sans(
                  size: 17,
                  weight: FontWeight.w700,
                  letterSpacing: -.1,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${slot.durationMinutes} Min',
              style: AppTextStyles.sans(
                size: 11.5,
                color: AppColors.inkFaint(.5),
              ),
            ),
            Text(
              slot.placeLabel(app.homeFacility),
              style: AppTextStyles.sans(
                size: 11.5,
                color: AppColors.inkFaint(.5),
              ),
            ),
            const SizedBox(height: 2),
            if (conflict != null)
              Text(
                'Kollidiert mit deinem Kalender',
                style: AppTextStyles.sans(
                  size: 11,
                  weight: FontWeight.w600,
                  color: const Color(0xFFB3261E),
                ),
              )
            else
              Text(
                '${slot.freeSeats} von ${slot.capacity} frei',
                style: AppTextStyles.sans(
                  size: 11,
                  weight: FontWeight.w600,
                  color: AppColors.mintText,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.app, required this.request});

  final AppState app;
  final LessonRequest request;

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final Color fg;
    late final String label;
    // An approved request whose resulting lesson the trainer has since
    // canceled must not keep showing as "Angenommen".
    final resultingSlot = request.resultingSlotId == null
        ? null
        : app.slotById(request.resultingSlotId!);
    final canceledAfterApproval =
        request.status == 'approved' && (resultingSlot?.isCanceled ?? false);
    switch (request.status) {
      case 'approved' when canceledAfterApproval:
        bg = AppColors.inkFaint(.08);
        fg = AppColors.inkFaint(.55);
        label = 'Abgesagt';
      case 'approved':
        bg = AppColors.mintFaint(.22);
        fg = AppColors.mintText;
        label = 'Angenommen';
      case 'declined':
        bg = AppColors.inkFaint(.08);
        fg = AppColors.inkFaint(.55);
        label = 'Abgelehnt';
      default:
        bg = AppColors.blueFaint(.18);
        fg = AppColors.blueText;
        label = 'Angefragt';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: cardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${longDayLabel(request.date)}, ${request.time} Uhr',
                  style: AppTextStyles.sans(
                    size: 13.5,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${request.durationMinutes} Min',
                  style: AppTextStyles.sans(
                    size: 11.5,
                    color: AppColors.inkFaint(.5),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: AppTextStyles.sans(
                size: 10.5,
                weight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
          if (request.isPending) ...[
            const SizedBox(width: 8),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => app.withdrawRequest(request),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: AppColors.inkFaint(.4),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
