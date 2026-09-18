import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_notification.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/modals/edit_slot_sheet.dart';
import '../widgets/modals/modal_launchers.dart';
import '../widgets/tab_scroll_view.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return TabScrollView(
      children: [
        InkWell(
          onTap: () => app.goTab(1),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.chevron_left, size: 18, color: AppColors.green),
              Text(
                'Start',
                style: AppTextStyles.sans(
                  size: 12.5,
                  weight: FontWeight.w600,
                  color: AppColors.green,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Mitteilungen',
              style: AppTextStyles.serif(size: 31, letterSpacing: -.3),
            ),
            TextButton(
              onPressed: app.hasUnread ? app.markAllNotificationsRead : null,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
              ),
              child: Text(
                'Alle gelesen',
                style: AppTextStyles.sans(
                  size: 12,
                  weight: FontWeight.w600,
                  color: AppColors.green,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (app.notifications.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Text(
              'Noch keine Mitteilungen.',
              textAlign: TextAlign.center,
              style: AppTextStyles.sans(
                size: 12.5,
                color: AppColors.inkFaint(.5),
              ),
            ),
          )
        else
          Column(
            children: [
              for (final n in app.notifications) ...[
                _NotificationTile(app: app, n: n),
                const SizedBox(height: 11),
              ],
            ],
          ),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.app, required this.n});

  final AppState app;
  final AppNotification n;

  IconData get _icon {
    switch (n.kind) {
      case 'clock':
        return Icons.access_time;
      case 'cal':
        return Icons.calendar_month_outlined;
      default:
        return Icons.person_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(n.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFB3261E),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => app.deleteNotification(n),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: () async {
          await app.openNotification(n);
          final slot = n.slotId == null ? null : app.slotById(n.slotId!);
          if (slot == null || !context.mounted) return;
          // Trainers land straight in the lesson's edit sheet ("Bearbeitungs-
          // fenster"); riders — and any canceled lesson, which can't be
          // edited — get the read-only detail view.
          if (app.isTrainer && !slot.isCanceled) {
            app.openDetail(slot);
            await openEditSlotSheet(context, app);
            app.closeModal();
          } else {
            await openSlotDetailSheet(context, app, slot);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          decoration: cardDecoration(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(_icon, size: 17, color: AppColors.green),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            n.title,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.sans(
                              size: 14,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (!n.isRead) ...[
                          const SizedBox(width: 7),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: AppColors.mint,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      n.body,
                      style: AppTextStyles.sans(
                        size: 12.5,
                        color: AppColors.inkFaint(.55),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      n.relativeLabel(),
                      style: AppTextStyles.sans(
                        size: 11,
                        color: AppColors.inkFaint(.35),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
