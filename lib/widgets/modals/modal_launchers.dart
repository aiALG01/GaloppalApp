import 'package:flutter/material.dart';

import '../../models/lesson_slot.dart';
import '../../models/profile.dart';
import '../../state/app_state.dart';
import '../bottom_sheet_scaffold.dart';
import 'add_trainer_sheet.dart';
import 'confirm_booking_sheet.dart';
import 'edit_rider_settings_sheet.dart';
import 'edit_trainer_settings_sheet.dart';
import 'request_lesson_sheet.dart';
import 'slot_detail_sheet.dart';
import 'slot_form_sheet.dart';
import 'student_detail_sheet.dart';

Future<void> openSlotFormSheet(BuildContext context, AppState app) async {
  app.openSlotForm();
  await showAppBottomSheet(context, builder: (_) => const SlotFormSheet());
  app.closeModal();
}

Future<void> openSlotDetailSheet(
  BuildContext context,
  AppState app,
  LessonSlot slot,
) async {
  app.openDetail(slot);
  await showAppBottomSheet(
    context,
    builder: (_) => SlotDetailSheet(slot: slot),
  );
  app.closeModal();
}

Future<void> openConfirmBookingSheet(
  BuildContext context,
  AppState app,
  LessonSlot slot,
) async {
  app.openConfirm(slot);
  await showAppBottomSheet(
    context,
    builder: (_) => ConfirmBookingSheet(slot: slot),
  );
  app.closeModal();
}

Future<void> openAddTrainerSheet(BuildContext context, AppState app) async {
  app.openLink();
  await showAppBottomSheet(context, builder: (_) => const AddTrainerSheet());
  app.closeModal();
}

Future<void> openEditTrainerSettingsSheet(
  BuildContext context,
  AppState app,
) async {
  app.openEditSettings();
  await showAppBottomSheet(
    context,
    builder: (_) => const EditTrainerSettingsSheet(),
  );
  app.closeModal();
}

Future<void> openEditRiderSettingsSheet(
  BuildContext context,
  AppState app,
) async {
  app.openEditRiderSettings();
  await showAppBottomSheet(
    context,
    builder: (_) => const EditRiderSettingsSheet(),
  );
  app.closeModal();
}

Future<void> openRequestLessonSheet(BuildContext context, AppState app) async {
  app.openRequestLesson();
  await showAppBottomSheet(context, builder: (_) => const RequestLessonSheet());
  app.closeModal();
}

Future<void> openStudentDetailSheet(
  BuildContext context,
  AppState app,
  Profile rider,
) async {
  await showAppBottomSheet(
    context,
    builder: (_) => StudentDetailSheet(rider: rider),
  );
}
