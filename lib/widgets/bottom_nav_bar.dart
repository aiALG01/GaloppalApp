import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key, required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    // The background extends all the way to the physical bottom edge (past
    // the home-indicator inset) so there's no gap below the bar; only the
    // tappable row is padded up to clear the inset. Fully opaque — a
    // translucent/blurred bar let scrolled content show through underneath
    // it, which read as broken rather than intentional.
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      height: 88 + bottomInset,
      padding: EdgeInsets.only(left: 10, right: 10, bottom: bottomInset),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.inkFaint(.08))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NavItem(
            icon: Icons.cottage_outlined,
            label: 'Start',
            active: app.tab == 1,
            onTap: () => app.goTab(1),
          ),
          _NavItem(
            icon: Icons.calendar_month_outlined,
            label: app.isTrainer ? 'Kalender' : 'Buchen',
            active: app.tab == 2,
            onTap: () => app.goTab(2),
          ),
          _NavItem(
            icon: Icons.people_alt_outlined,
            label: app.isTrainer ? 'Schüler' : 'Reitlehrer',
            active: app.tab == 3,
            onTap: () => app.goTab(3),
          ),
          _NavItem(
            icon: Icons.person_outline,
            label: 'Profil',
            active: app.tab == 4,
            onTap: () => app.goTab(4),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.green : AppColors.inkFaint(.4);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              Icon(icon, size: 21, color: color),
              const SizedBox(height: 5),
              Text(
                label,
                style: AppTextStyles.sans(
                  size: 10.5,
                  weight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
