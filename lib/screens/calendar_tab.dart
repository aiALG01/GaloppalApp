import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/date_utils.dart';
import '../widgets/modals/modal_launchers.dart';
import '../widgets/slot_tile.dart';
import '../widgets/tab_scroll_view.dart';

String _hm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

class CalendarTab extends StatelessWidget {
  const CalendarTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final daySlots = app.daySlots;

    return TabScrollView(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    InkWell(
                      onTap: () => app.shiftCalendarMonth(-1),
                      child: const Icon(
                        Icons.chevron_left,
                        size: 18,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      monthYearLabel(app.calendarMonth).toUpperCase(),
                      style: AppTextStyles.eyebrow(),
                    ),
                    const SizedBox(width: 2),
                    InkWell(
                      onTap: () => app.shiftCalendarMonth(1),
                      child: const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Kalender',
                  style: AppTextStyles.serif(size: 31, letterSpacing: -.3),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${app.monthSlotCount} Einheiten',
                style: AppTextStyles.sans(
                  size: 11.5,
                  color: AppColors.inkFaint(.45),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: cardShadow(blur: 16),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  for (final w in weekdayShortDe)
                    Expanded(
                      child: Center(
                        child: Text(
                          w,
                          style: AppTextStyles.sans(
                            size: 10,
                            weight: FontWeight.w600,
                            color: AppColors.inkFaint(.35),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _MonthGrid(app: app),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              longDayLabel(app.selectedDay),
              style: AppTextStyles.serif(size: 19),
            ),
            Text(
              '${daySlots.length} Einheiten',
              style: AppTextStyles.sans(
                size: 11.5,
                color: AppColors.inkFaint(.45),
              ),
            ),
          ],
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
                  'PERSÖNLICHE TERMINE',
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
        if (daySlots.isEmpty)
          const EmptyStateCard(
            title: 'Noch keine Zeiten',
            text: 'Lege eine buchbare Stunde an, damit Schüler Plätze reservieren können.',
          )
        else
          Column(
            children: [
              for (final s in daySlots) ...[
                SlotTile(
                  slot: s,
                  homeFacility: app.homeFacility,
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

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    final month = app.calendarMonth;
    final leading = mondayIndex(firstOfMonth(month));
    final total = daysInMonth(month);
    final activeDays = app.monthActiveDays;
    final today = dateOnly(DateTime.now());

    final cells = <Widget>[];
    for (var i = 0; i < leading; i++) {
      cells.add(const SizedBox(height: 42));
    }
    for (var day = 1; day <= total; day++) {
      final date = DateTime(month.year, month.month, day);
      final selected = isSameDate(date, app.selectedDay);
      final isToday = isSameDate(date, today);
      final hasSlot = activeDays.contains(day);
      cells.add(
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => app.selectDay(date),
          child: Container(
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              // Today always shows blue — even when it's also the selected day.
              color: isToday
                  ? AppColors.blue
                  : (selected ? AppColors.ink : Colors.transparent),
              borderRadius: BorderRadius.circular(12),
              border: selected && isToday
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: AppTextStyles.sans(
                    size: 14,
                    weight: selected || isToday
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: selected || isToday ? Colors.white : AppColors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                SizedBox(
                  width: 4,
                  height: 4,
                  child: hasSlot
                      ? DecoratedBox(
                          decoration: BoxDecoration(
                            color: selected || isToday
                                ? AppColors.mint
                                : AppColors.green,
                            shape: BoxShape.circle,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      childAspectRatio: 1,
      children: cells,
    );
  }
}
