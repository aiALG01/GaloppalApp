import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/modals/modal_launchers.dart';
import '../widgets/toast_overlay.dart';
import 'book_tab.dart';
import 'calendar_tab.dart';
import 'home_tab.dart';
import 'notifications_screen.dart';
import 'profile_tab.dart';
import 'students_tab.dart';
import 'trainers_tab.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(child: _bodyForTab(app)),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: BottomNavBar(app: app),
            ),
            if (app.isTrainer && app.tab == 2)
              Positioned(
                right: 20,
                bottom: 88 + MediaQuery.of(context).padding.bottom + 16,
                child: _Fab(onTap: () => openSlotFormSheet(context, app)),
              ),
            Positioned.fill(child: ToastOverlay(message: app.toast)),
          ],
        ),
      ),
    );
  }

  Widget _bodyForTab(AppState app) {
    if (app.tab == 5) return const NotificationsScreen();
    switch (app.tab) {
      case 1:
        return const HomeTab();
      case 2:
        return app.isTrainer ? const CalendarTab() : const BookTab();
      case 3:
        return app.isTrainer ? const StudentsTab() : const TrainersTab();
      case 4:
        return const ProfileTab();
      default:
        return const HomeTab();
    }
  }
}

class _Fab extends StatelessWidget {
  const _Fab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.green,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 10,
      shadowColor: AppColors.green.withValues(alpha: .5),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: const SizedBox(
          width: 58,
          height: 58,
          child: Icon(Icons.add, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}
