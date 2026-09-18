import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/modals/modal_launchers.dart';
import '../widgets/tab_scroll_view.dart';

class StudentsTab extends StatefulWidget {
  const StudentsTab({super.key});

  @override
  State<StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<StudentsTab> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final query = _search.text.trim().toLowerCase();
    final riders = query.isEmpty
        ? app.linkedRiders
        : app.linkedRiders
              .where((r) => r.fullName.toLowerCase().contains(query))
              .toList();

    return TabScrollView(
      children: [
        Text(
          'Schüler',
          style: AppTextStyles.serif(size: 31, letterSpacing: -.3),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
          decoration: cardDecoration(shadowOpacity: .05),
          child: Row(
            children: [
              Icon(Icons.search, size: 16, color: AppColors.inkFaint(.4)),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  style: AppTextStyles.sans(size: 13.5),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: 'Name suchen …',
                    hintStyle: AppTextStyles.sans(
                      size: 13.5,
                      color: AppColors.inkFaint(.4),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: cardDecoration(shadowOpacity: .06, radius: AppRadius.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Schüler einladen',
                style: AppTextStyles.sans(size: 14, weight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Schüler finden dich über diesen Link oder über die Suche '
                'nach deinem Namen in "Reitlehrer finden".',
                style: AppTextStyles.sans(
                  size: 12.5,
                  color: AppColors.inkFaint(.55),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: AppColors.inkFaint(.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        app.profile?.inviteLink ?? '',
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.sans(
                          size: 11.5,
                          color: AppColors.ink,
                        ).copyWith(fontFamily: 'monospace'),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Material(
                      color: AppColors.green,
                      borderRadius: BorderRadius.circular(9),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(9),
                        onTap: () {
                          final link = app.profile?.inviteLink ?? '';
                          Clipboard.setData(ClipboardData(text: link));
                          app.flash('Link kopiert');
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 8,
                          ),
                          child: Text(
                            'Kopieren',
                            style: AppTextStyles.sans(
                              size: 12,
                              weight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (riders.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              app.linkedRiders.isEmpty
                  ? 'Noch keine Schüler verknüpft.'
                  : 'Keine Treffer.',
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
              for (final r in riders) ...[
                InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  onTap: () => openStudentDetailSheet(context, app, r),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 13,
                    ),
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
                                r.fullName,
                                style: AppTextStyles.sans(
                                  size: 14.5,
                                  weight: FontWeight.w600,
                                ),
                              ),
                              if ((r.stableName ?? '').isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  r.stableName!,
                                  style: AppTextStyles.sans(
                                    size: 11.5,
                                    color: AppColors.inkFaint(.5),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 11),
              ],
            ],
          ),
      ],
    );
  }
}
