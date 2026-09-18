import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/lesson_slot.dart';
import '../models/profile.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/maps_launcher.dart';
import '../widgets/modals/modal_launchers.dart';
import '../widgets/tab_scroll_view.dart';

class TrainersTab extends StatelessWidget {
  const TrainersTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return TabScrollView(
      children: [
        Text(
          'Reitlehrer',
          style: AppTextStyles.serif(size: 31, letterSpacing: -.3),
        ),
        const SizedBox(height: 6),
        Text(
          'Finde Reitlehrer über die Suche oder einen Einladungslink.',
          style: AppTextStyles.sans(
            size: 12.5,
            color: AppColors.inkFaint(.55),
            height: 1.55,
          ),
        ),
        const SizedBox(height: 18),
        for (final t in app.linkedTrainers) ...[
          _TrainerCard(
            app: app,
            trainer: t,
            primary: t.id == app.primaryTrainer?.id,
          ),
          const SizedBox(height: 14),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .55),
            border: Border.all(color: AppColors.inkFaint(.18)),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Text(
                'Weiteren Reitlehrer hinzufügen',
                style: AppTextStyles.sans(size: 14, weight: FontWeight.w600),
              ),
              const SizedBox(height: 5),
              Text(
                'Per Namenssuche finden oder Link/Code einfügen.',
                style: AppTextStyles.sans(
                  size: 12,
                  color: AppColors.inkFaint(.5),
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: () => openAddTrainerSheet(context, app),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: BorderSide(color: AppColors.inkFaint(.15)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: Text(
                  'Reitlehrer finden',
                  style: AppTextStyles.sans(
                    size: 13.5,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrainerCard extends StatelessWidget {
  const _TrainerCard({
    required this.app,
    required this.trainer,
    required this.primary,
  });

  final AppState app;
  final Profile trainer;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final List<LessonSlot> mySlots = primary
        ? app.myBookedSlotsForRider
        : const <LessonSlot>[];
    final openSlots = primary ? app.freeSlotsForSelectedDay.length : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(radius: AppRadius.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: PlaceholderStripe(borderRadius: AppRadius.lg),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trainer.fullName,
                      style: AppTextStyles.sans(
                        size: 15,
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
                    if ((trainer.address ?? '').isNotEmpty)
                      GestureDetector(
                        onTap: () => openAddressInMaps(trainer.address!),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.place_outlined,
                                size: 12,
                                color: AppColors.green,
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  trainer.address!,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.sans(
                                    size: 11,
                                    weight: FontWeight.w600,
                                    color: AppColors.green,
                                  ),
                                ),
                              ),
                            ],
                          ),
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
          if (primary) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Container(height: 1, color: AppColors.inkFaint(.07)),
            ),
            Row(
              children: [
                _Stat(value: '${mySlots.length}', label: 'Buchungen'),
                const SizedBox(width: 22),
                _Stat(value: '$openSlots', label: 'freie Plätze'),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => app.goTab(2),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Stunde buchen',
                  style: AppTextStyles.sans(
                    size: 14,
                    weight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: AppTextStyles.sans(size: 17, weight: FontWeight.w700),
        ),
        Text(
          label,
          style: AppTextStyles.sans(size: 11, color: AppColors.inkFaint(.5)),
        ),
      ],
    );
  }
}
