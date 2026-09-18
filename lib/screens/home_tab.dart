import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/lesson_request.dart';
import '../models/lesson_slot.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/date_utils.dart';
import '../widgets/modals/modal_launchers.dart';
import '../widgets/primary_button.dart';
import '../widgets/slot_tile.dart';
import '../widgets/tab_scroll_view.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final name = (app.profile?.fullName ?? '').split(' ').first;
    final next = app.nextSlot;

    return TabScrollView(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fullDateHeader(DateTime.now()),
                    style: AppTextStyles.eyebrow(),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    greetingForHour(DateTime.now().hour, name),
                    style: AppTextStyles.serif(size: 31, letterSpacing: -.3),
                  ),
                ],
              ),
            ),
            _NotificationBell(app: app),
          ],
        ),
        if (app.deviceBusyBlocks.isNotEmpty) ...[
          const SizedBox(height: 16),
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
                  'PERSÖNLICHE TERMINE · ${longDayLabel(app.selectedDay)}',
                  style: AppTextStyles.eyebrow(color: AppColors.blueText),
                ),
                const SizedBox(height: 6),
                for (final b in app.deviceBusyBlocks)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      b.allDay
                          ? 'ganztägig · ${b.title}'
                          : '${b.start.hour.toString().padLeft(2, '0')}:${b.start.minute.toString().padLeft(2, '0')}'
                                '–${b.end.hour.toString().padLeft(2, '0')}:${b.end.minute.toString().padLeft(2, '0')} · ${b.title}',
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
        if (app.isTrainer) ...[
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Neue Stunde erstellen',
            color: AppColors.blue,
            onPressed: () => openSlotFormSheet(context, app),
          ),
        ],
        if (next != null) ...[
          const SizedBox(height: 20),
          _NextLessonCard(app: app, slot: next),
        ],
        if (app.isTrainer && app.pendingRequests.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Stundenanfragen', style: AppTextStyles.serif(size: 19)),
          const SizedBox(height: 13),
          Column(
            children: [
              for (final r in app.pendingRequests) ...[
                _RequestCard(app: app, request: r),
                const SizedBox(height: 11),
              ],
            ],
          ),
        ],
        const SizedBox(height: 26),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              app.isTrainer ? 'Heute' : 'Weitere Termine',
              style: AppTextStyles.serif(size: 19),
            ),
            TextButton(
              onPressed: () => app.goTab(2),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
              ),
              child: Text(
                app.isTrainer ? 'Kalender' : 'Buchen',
                style: AppTextStyles.sans(
                  size: 12,
                  weight: FontWeight.w600,
                  color: AppColors.green,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        if (app.homeListEmpty)
          EmptyStateCard(
            title: app.isTrainer ? 'Heute frei' : 'Keine weiteren Buchungen',
            text: app.isTrainer
                ? 'Für heute sind keine Einheiten geplant.'
                : 'Buche eine Stunde bei deinem Reitlehrer.',
          )
        else
          Column(
            children: [
              for (final s in app.homeList) ...[
                SlotTile(
                  slot: s,
                  homeFacility: app.homeFacility,
                  showDayLabel: true,
                  onTap: () => openSlotDetailSheet(context, app, s),
                ),
                const SizedBox(height: 11),
              ],
            ],
          ),
      ],
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => app.goTab(5),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: cardShadow(opacity: .07),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            const Icon(
              Icons.notifications_outlined,
              size: 20,
              color: AppColors.ink,
            ),
            if (app.hasUnread)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: AppColors.mint,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${app.unreadCount}',
                    style: AppTextStyles.sans(
                      size: 10.5,
                      weight: FontWeight.w700,
                      color: AppColors.mintTextStrong,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NextLessonCard extends StatelessWidget {
  const _NextLessonCard({required this.app, required this.slot});

  final AppState app;
  final LessonSlot slot;

  @override
  Widget build(BuildContext context) {
    final isTrainer = app.isTrainer;
    final people = isTrainer
        ? (slot.bookings.isEmpty
              ? 'Noch keine Anmeldung'
              : slot.bookings.map((b) => b.riderName).join(', '))
        : (app.primaryTrainer?.fullName ?? '');
    final peopleSub = isTrainer
        ? '${slot.bookings.length} von ${slot.capacity} Plätzen belegt'
        : 'Reitlehrer:in';
    final badge = isTrainer
        ? (slot.isFull ? 'Ausgebucht' : 'Plätze frei')
        : 'Bestätigt';
    final timeLabel = isTrainer
        ? '${slot.startTime}–${slot.endTime} Uhr'
        : '${weekdayShortLabel(slot.date)} ${slot.startTime}–${slot.endTime}';

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => openSlotDetailSheet(context, app, slot),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.green,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppColors.green.withValues(alpha: .35),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (isTrainer ? 'Nächste Einheit heute' : 'Nächste Stunde')
                  .toUpperCase(),
              style: AppTextStyles.sans(
                size: 10.5,
                weight: FontWeight.w600,
                letterSpacing: 1.4,
                color: Colors.white.withValues(alpha: .6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Reitstunde',
              style: AppTextStyles.serif(
                size: 27,
                color: Colors.white,
                letterSpacing: -.2,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: Colors.white.withValues(alpha: .85),
                ),
                const SizedBox(width: 6),
                Text(
                  timeLabel,
                  style: AppTextStyles.sans(
                    size: 13,
                    color: Colors.white.withValues(alpha: .85),
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.home_work_outlined,
                  size: 14,
                  color: Colors.white.withValues(alpha: .85),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    slot.placeLabel(app.homeFacility),
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.sans(
                      size: 13,
                      color: Colors.white.withValues(alpha: .85),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Container(
                height: 1,
                color: Colors.white.withValues(alpha: .18),
              ),
            ),
            Row(
              children: [
                const SizedBox(
                  width: 38,
                  height: 38,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        people,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.sans(
                          size: 14,
                          weight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        peopleSub,
                        style: AppTextStyles.sans(
                          size: 11.5,
                          color: Colors.white.withValues(alpha: .6),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.mint.withValues(alpha: .28),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    badge,
                    style: AppTextStyles.sans(
                      size: 10.5,
                      weight: FontWeight.w600,
                      color: const Color(0xFFEAF7EC),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.app, required this.request});

  final AppState app;
  final LessonRequest request;

  static String _hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  /// Checks the trainer's device/Google calendar for an overlap first and
  /// asks for confirmation before going ahead with the approval. A timed
  /// clash is a firm warning; an all-day entry is only a soft hint.
  Future<void> _accept(BuildContext context) async {
    final conflict = await app.calendarConflictFor(
      date: request.date,
      time: request.time,
      durationMinutes: request.durationMinutes,
    );
    final allDay = conflict == null
        ? await app.calendarAllDayTitlesFor(request.date)
        : const <String>[];
    if (!context.mounted) return;

    final body = conflict != null
        ? 'Zu dieser Zeit hast du in deinem Kalender bereits '
              '„${conflict.title}" (${_hm(conflict.start)}–${_hm(conflict.end)}). '
              'Anfrage trotzdem annehmen?'
        : allDay.isNotEmpty
        ? 'An dem Tag hast du einen ganztägigen Termin (${allDay.join(', ')}). '
              'Anfrage trotzdem annehmen?'
        : null;

    if (body != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            conflict != null ? 'Terminüberschneidung' : 'Terminhinweis',
          ),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Trotzdem annehmen'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await app.approveRequest(request);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.riderName ?? 'Schüler:in',
                      style: AppTextStyles.sans(
                        size: 14,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${longDayLabel(request.date)}, ${request.time}–${request.endTime} Uhr',
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
                  color: AppColors.blueFaint(.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Neu',
                  style: AppTextStyles.sans(
                    size: 10.5,
                    weight: FontWeight.w600,
                    color: AppColors.blueText,
                  ),
                ),
              ),
            ],
          ),
          if ((request.note ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '„${request.note}“',
              style: AppTextStyles.sans(
                size: 12,
                color: AppColors.inkFaint(.6),
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'Ablehnen',
                  onPressed: () => app.declineRequest(request),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryButton(
                  label: 'Annehmen',
                  onPressed: () => _accept(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
