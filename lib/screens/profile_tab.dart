import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/profile.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/modals/modal_launchers.dart';
import '../widgets/primary_button.dart';
import '../widgets/tab_scroll_view.dart';
import 'feature_requests_screen.dart';

Future<void> _pickAvatarSource(BuildContext context, AppState app) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadius.sheet),
      ),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(
              Icons.photo_library_outlined,
              color: AppColors.green,
            ),
            title: Text(
              'Aus Fotos wählen',
              style: AppTextStyles.sans(size: 14.5),
            ),
            onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(
              Icons.camera_alt_outlined,
              color: AppColors.green,
            ),
            title: Text(
              'Foto aufnehmen',
              style: AppTextStyles.sans(size: 14.5),
            ),
            onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (source != null) await app.pickAndUpdateAvatar(source);
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = app.profile;
    if (p == null) return const SizedBox.shrink();

    final settings = app.isTrainer
        ? [
            ('Standard-Trainingsort', p.facility ?? '–'),
            ('Standard-Dauer', '${p.defaultDurationMinutes} Min'),
            ('Standard-Plätze', '${p.defaultCapacity} Schüler'),
            (
              'Standard-Modus',
              p.defaultSlotMode == 'range' ? 'Zeitraum' : 'Einzelne Stunde',
            ),
            ('Standard-Wiederholung', p.defaultRepeat),
            ('Buchungsfrist', '${p.bookingLeadHours} Std vorher'),
            ('Stundenanfragen', p.allowRequests ? 'Erlaubt' : 'Aus'),
          ]
        : [
            ('Stall', p.stableName ?? '–'),
            ('Erinnerungen', '${p.reminderHours} Std vorher'),
            (
              'Reitlehrer',
              app.linkedTrainers.isEmpty
                  ? 'keiner'
                  : '${app.linkedTrainers.length} verknüpft',
            ),
          ];

    return TabScrollView(
      children: [
        Text(
          'Profil',
          style: AppTextStyles.serif(size: 31, letterSpacing: -.3),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: cardShadow(blur: 16),
          ),
          child: Column(
            children: [
              GestureDetector(
                onTap: () => _pickAvatarSource(context, app),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(39),
                      child: SizedBox(
                        width: 78,
                        height: 78,
                        child: (p.avatarUrl ?? '').isEmpty
                            ? const PlaceholderStripe(borderRadius: 39)
                            : Image.network(p.avatarUrl!, fit: BoxFit.cover),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: AppColors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.edit,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(p.fullName, style: AppTextStyles.serif(size: 21)),
              Text(
                app.isTrainer
                    ? 'Reitlehrer:in · ${p.facility ?? ''}'
                    : 'Schüler:in${(p.stableName ?? '').isEmpty ? '' : ' · ${p.stableName}'}',
                style: AppTextStyles.sans(
                  size: 12.5,
                  color: AppColors.inkFaint(.5),
                ),
              ),
              if ((p.bio ?? '').isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  p.bio!,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.sans(
                    size: 12.5,
                    color: AppColors.inkFaint(.6),
                    height: 1.55,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _RoleSwitchCard(app: app, profile: p),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Einstellungen',
              style: AppTextStyles.sans(
                size: 12.5,
                weight: FontWeight.w600,
                color: AppColors.inkFaint(.5),
              ),
            ),
            GestureDetector(
              onTap: () => app.isTrainer
                  ? openEditTrainerSettingsSheet(context, app)
                  : openEditRiderSettingsSheet(context, app),
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 14, color: AppColors.green),
                  const SizedBox(width: 4),
                  Text(
                    'Bearbeiten',
                    style: AppTextStyles.sans(
                      size: 12.5,
                      weight: FontWeight.w600,
                      color: AppColors.green,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: cardShadow(),
          ),
          child: Column(
            children: [
              for (var i = 0; i < settings.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                  decoration: BoxDecoration(
                    border: i == settings.length - 1
                        ? null
                        : Border(
                            bottom: BorderSide(color: AppColors.inkFaint(.06)),
                          ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(settings[i].$1, style: AppTextStyles.sans(size: 14)),
                      Text(
                        settings[i].$2,
                        style: AppTextStyles.sans(
                          size: 12.5,
                          color: AppColors.inkFaint(.42),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: cardShadow(),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gerätekalender',
                      style: AppTextStyles.sans(
                        size: 14,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      app.isTrainer
                          ? 'Deine Stunden im Kalender der App (Apple Kalender o. Ä.) anzeigen.'
                          : 'Deine gebuchten Stunden im Kalender der App (Apple Kalender o. Ä.) anzeigen.',
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
              if (app.calendarSyncBusy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              else
                Switch(
                  value: app.calendarSyncEnabled,
                  activeThumbColor: AppColors.green,
                  onChanged: (v) => app.setCalendarSyncEnabled(v),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SecondaryButton(
          label: 'Feature-Wünsche',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const FeatureRequestsScreen()),
          ),
        ),
        const SizedBox(height: 10),
        SecondaryButton(label: 'Abmelden', onPressed: app.logout),
      ],
    );
  }
}

/// Lets one account act as both trainer and rider ("beide Rollen
/// gleichzeitig"): a segmented switch once both are activated, or a single
/// button to activate the other role first.
class _RoleSwitchCard extends StatelessWidget {
  const _RoleSwitchCard({required this.app, required this.profile});

  final AppState app;
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    if (profile.hasDualRole) {
      return Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: cardShadow(),
        ),
        child: Row(
          children: [
            Expanded(
              child: _RoleSegment(
                label: 'Reitlehrer:in',
                selected: app.isTrainer,
                loading: app.switchingRole,
                onTap: () => app.switchActiveRole('trainer'),
              ),
            ),
            Expanded(
              child: _RoleSegment(
                label: 'Schüler:in',
                selected: !app.isTrainer,
                loading: app.switchingRole,
                onTap: () => app.switchActiveRole('rider'),
              ),
            ),
          ],
        ),
      );
    }

    final otherRole = app.isTrainer ? 'rider' : 'trainer';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: cardShadow(),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Auch als ${otherRole == 'trainer' ? 'Reitlehrer:in' : 'Schüler:in'} nutzen',
                  style: AppTextStyles.sans(size: 14, weight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ein Konto, zwei Rollen — du kannst jederzeit zwischen '
                  'ihnen wechseln.',
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
          app.switchingRole
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              : TextButton(
                  onPressed: () => app.switchActiveRole(otherRole),
                  child: Text(
                    'Aktivieren',
                    style: AppTextStyles.sans(
                      size: 13,
                      weight: FontWeight.w600,
                      color: AppColors.green,
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _RoleSegment extends StatelessWidget {
  const _RoleSegment({
    required this.label,
    required this.selected,
    required this.loading,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.green : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: loading ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTextStyles.sans(
              size: 13,
              weight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.inkFaint(.6),
            ),
          ),
        ),
      ),
    );
  }
}
