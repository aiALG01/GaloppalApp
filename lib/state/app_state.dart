import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/app_notification.dart';
import '../models/feature_request.dart';
import '../models/lesson_request.dart';
import '../models/lesson_slot.dart';
import '../models/profile.dart';
import '../models/student_note.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/calendar_sync_service.dart';
import '../utils/date_utils.dart';
import 'slot_form_state.dart';

const _calendarSyncEnabledPrefsKey = 'calendar_sync_enabled';

enum ModalKind {
  none,
  slotForm,
  detail,
  confirm,
  link,
  editSettings,
  editRiderSettings,
  requestLesson,
}

const _uuid = Uuid();

/// Central app state: authentication, the current profile, lesson slots,
/// bookings, notifications and UI navigation (tab/day/modal). Screens read
/// derived getters from here instead of re-deriving them, mirroring the
/// `renderVals()` computed-props pattern of the original HTML prototype.
class AppState extends ChangeNotifier {
  AppState({
    AuthService? authService,
    ApiService? api,
    CalendarSyncService? calendarSync,
  }) : authService = authService ?? AuthService(),
       api = api ?? ApiService(),
       calendarSync = calendarSync ?? CalendarSyncService();

  final AuthService authService;
  final ApiService api;
  final CalendarSyncService calendarSync;

  StreamSubscription<AuthState>? _authSub;
  RealtimeChannel? _slotsChannel;
  RealtimeChannel? _bookingsChannel;
  RealtimeChannel? _notifChannel;
  RealtimeChannel? _requestsChannel;
  Timer? _toastTimer;

  // ---------------------------------------------------------------------
  // Core state
  // ---------------------------------------------------------------------

  bool isLoading = true;
  String? authError;
  bool needsEmailConfirmation = false;
  bool calendarSyncEnabled = false;
  bool calendarSyncBusy = false;

  Profile? profile;
  List<LessonSlot> slots = [];
  List<Profile> linkedRiders = []; // trainer's riders
  List<Profile> linkedTrainers = []; // rider's trainers
  List<AppNotification> notifications = [];
  List<LessonRequest> lessonRequests =
      []; // trainer: requests aimed at them · rider: their own requests
  bool savingRequest = false;

  int tab = 1;
  DateTime selectedDay = dateOnly(DateTime.now());
  DateTime calendarMonth = firstOfMonth(DateTime.now());

  ModalKind modal = ModalKind.none;
  LessonSlot? activeSlot;
  String? toast;

  bool savingSlot = false;
  bool savingProfile = false;

  final SlotFormState form = SlotFormState();

  // ---------------------------------------------------------------------
  // Bootstrap
  // ---------------------------------------------------------------------

  void init() {
    _authSub = authService.onAuthStateChange.listen((state) {
      final event = state.event;
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed) {
        if (profile == null) unawaited(loadEverything());
      } else if (event == AuthChangeEvent.signedOut) {
        _resetSessionState();
      }
    });

    unawaited(_loadCalendarSyncPref());

    if (authService.isSignedIn) {
      unawaited(loadEverything());
    } else {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadCalendarSyncPref() async {
    final prefs = await SharedPreferences.getInstance();
    calendarSyncEnabled = prefs.getBool(_calendarSyncEnabledPrefsKey) ?? false;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _slotsChannel?.unsubscribe();
    _bookingsChannel?.unsubscribe();
    _notifChannel?.unsubscribe();
    _toastTimer?.cancel();
    _resendTimer?.cancel();
    super.dispose();
  }

  Future<void> loadEverything() async {
    final uid = authService.currentUserId;
    if (uid == null) return;
    isLoading = true;
    notifyListeners();
    try {
      profile = await api.fetchProfile(uid);
      await _reloadRoleData();
      notifications = await api.fetchNotifications(uid);
      _subscribeRealtime();
      unawaited(_syncDeviceCalendarIfEnabled());
      unawaited(loadDeviceBusyBlocksForSelectedDay());
      unawaited(_tryConsumePendingInviteCode());
    } catch (e) {
      authError = 'Profil konnte nicht geladen werden.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _reloadRoleData() async {
    final p = profile;
    if (p == null) return;
    if (p.isTrainer) {
      linkedRiders = await api.fetchLinkedRiders(p.id);
      slots = await api.fetchSlotsForTrainer(p.id);
      lessonRequests = await api.fetchRequestsForTrainer(p.id);
    } else {
      linkedTrainers = await api.fetchLinkedTrainers(p.id);
      slots = primaryTrainer == null
          ? []
          : await api.fetchSlotsForTrainer(primaryTrainer!.id);
      lessonRequests = await api.fetchRequestsForRider(p.id);
    }
  }

  void _subscribeRealtime() {
    _slotsChannel?.unsubscribe();
    _bookingsChannel?.unsubscribe();
    _notifChannel?.unsubscribe();
    _requestsChannel?.unsubscribe();

    _slotsChannel = api.watchTable(
      'lesson_slots',
      channelName: 'lesson_slots-${_uuid.v4()}',
      onChange: refreshSlots,
    );
    _bookingsChannel = api.watchTable(
      'bookings',
      channelName: 'bookings-${_uuid.v4()}',
      onChange: refreshSlots,
    );
    _notifChannel = api.watchTable(
      'notifications',
      channelName: 'notifications-${_uuid.v4()}',
      onChange: refreshNotifications,
    );
    _requestsChannel = api.watchTable(
      'lesson_requests',
      channelName: 'lesson_requests-${_uuid.v4()}',
      onChange: refreshRequests,
    );
  }

  void _resetSessionState() {
    profile = null;
    slots = [];
    linkedRiders = [];
    linkedTrainers = [];
    notifications = [];
    lessonRequests = [];
    tab = 1;
    modal = ModalKind.none;
    activeSlot = null;
    _slotsChannel?.unsubscribe();
    _bookingsChannel?.unsubscribe();
    _notifChannel?.unsubscribe();
    _requestsChannel?.unsubscribe();
    notifyListeners();
  }

  Future<void> refreshSlots() async {
    final trainerId = isTrainer ? profile?.id : primaryTrainer?.id;
    if (trainerId == null) {
      slots = [];
    } else {
      slots = await api.fetchSlotsForTrainer(trainerId);
    }
    notifyListeners();
    unawaited(_syncDeviceCalendarIfEnabled());
  }

  // ---------------------------------------------------------------------
  // Device calendar sync (Apple Calendar / device calendar provider)
  // ---------------------------------------------------------------------

  /// Turns device-calendar sync on or off. Enabling asks for calendar
  /// permission and does a first full sync; disabling removes every event
  /// this app previously created.
  Future<void> setCalendarSyncEnabled(bool value) async {
    if (value == calendarSyncEnabled) return;
    calendarSyncBusy = true;
    notifyListeners();
    try {
      if (value) {
        final granted = await calendarSync.requestPermissions();
        if (!granted) {
          flash('Kalenderzugriff wurde nicht erlaubt.');
          return;
        }
        calendarSyncEnabled = true;
        await _syncDeviceCalendarIfEnabled();
        flash('Kalendersynchronisierung aktiviert');
      } else {
        calendarSyncEnabled = false;
        await calendarSync.clear();
        flash('Kalendersynchronisierung deaktiviert');
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_calendarSyncEnabledPrefsKey, calendarSyncEnabled);
    } catch (e) {
      flash('Kalendersynchronisierung fehlgeschlagen.');
    } finally {
      calendarSyncBusy = false;
      notifyListeners();
    }
  }

  Future<void> _syncDeviceCalendarIfEnabled() async {
    if (!calendarSyncEnabled) return;
    final p = profile;
    if (p == null) return;

    final items = p.isTrainer
        ? slots
              .where((s) => !s.isCanceled)
              .map(
                (s) => CalendarSyncItem(
                  key: s.id,
                  title:
                      'Reitstunde · ${s.bookings.length}/${s.capacity} Schüler',
                  start: combineDateAndTime(s.date, s.startTime),
                  end: combineDateAndTime(s.date, s.endTime),
                  location: s.facility,
                ),
              )
        : slots
              .where((s) => !s.isCanceled && s.bookedByRider(p.id))
              .map(
                (s) => CalendarSyncItem(
                  key: s.id,
                  title: 'Reitstunde',
                  start: combineDateAndTime(s.date, s.startTime),
                  end: combineDateAndTime(s.date, s.endTime),
                  location: s.facility,
                ),
              );

    try {
      await calendarSync.sync(items.toList());
    } catch (_) {
      // Best-effort background sync; surfacing a toast here would fire on
      // every realtime update, so failures are silently skipped.
    }
  }

  Future<void> refreshNotifications() async {
    final uid = profile?.id;
    if (uid == null) return;
    notifications = await api.fetchNotifications(uid);
    notifyListeners();
  }

  Future<void> refreshRequests() async {
    final p = profile;
    if (p == null) return;
    lessonRequests = p.isTrainer
        ? await api.fetchRequestsForTrainer(p.id)
        : await api.fetchRequestsForRider(p.id);
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Auth actions
  // ---------------------------------------------------------------------

  Future<bool> login({required String email, required String password}) async {
    authError = null;
    try {
      await authService.signIn(email: email, password: password);
      await loadEverything();
      return true;
    } on AuthException catch (e) {
      authError = e.message;
      notifyListeners();
      return false;
    } catch (_) {
      authError = 'Anmeldung fehlgeschlagen. Bitte versuche es erneut.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> registerTrainer({
    required String email,
    required String password,
    required String fullName,
    required String facility,
    int? defaultDurationMinutes,
    String? defaultSlotMode,
    String? defaultRepeat,
  }) => _register(
    email: email,
    password: password,
    fullName: fullName,
    role: 'trainer',
    facility: facility,
    defaultDurationMinutes: defaultDurationMinutes,
    defaultSlotMode: defaultSlotMode,
    defaultRepeat: defaultRepeat,
  );

  Future<bool> registerRider({
    required String email,
    required String password,
    required String fullName,
  }) => _register(
    email: email,
    password: password,
    fullName: fullName,
    role: 'rider',
  );

  Future<bool> _register({
    required String email,
    required String password,
    required String fullName,
    required String role,
    String? facility,
    int? defaultDurationMinutes,
    String? defaultSlotMode,
    String? defaultRepeat,
  }) async {
    authError = null;
    needsEmailConfirmation = false;
    try {
      await authService.signUp(
        email: email,
        password: password,
        fullName: fullName,
        role: role,
        facility: facility,
        defaultDurationMinutes: defaultDurationMinutes,
        defaultSlotMode: defaultSlotMode,
        defaultRepeat: defaultRepeat,
      );
      if (authService.isSignedIn) {
        await loadEverything();
      } else {
        needsEmailConfirmation = true;
        _pendingConfirmationEmail = email;
        _startResendCooldown();
        notifyListeners();
      }
      return true;
    } on AuthException catch (e) {
      authError = e.message;
      notifyListeners();
      return false;
    } catch (_) {
      authError = 'Registrierung fehlgeschlagen. Bitte versuche es erneut.';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await authService.signOut();
  }

  // ---------------------------------------------------------------------
  // Email confirmation resend — Supabase rate-limits server-side; we also
  // gate the button behind a visible 30-second countdown.
  // ---------------------------------------------------------------------

  static const resendCooldownDuration = Duration(seconds: 30);

  String? _pendingConfirmationEmail;
  int resendSecondsLeft = 0;
  Timer? _resendTimer;

  bool get canResendConfirmation =>
      resendSecondsLeft == 0 && _pendingConfirmationEmail != null;

  void _startResendCooldown() {
    _resendTimer?.cancel();
    resendSecondsLeft = resendCooldownDuration.inSeconds;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      resendSecondsLeft--;
      if (resendSecondsLeft <= 0) {
        resendSecondsLeft = 0;
        t.cancel();
      }
      notifyListeners();
    });
  }

  Future<void> resendConfirmationEmail() async {
    final email = _pendingConfirmationEmail;
    if (email == null || !canResendConfirmation) return;
    try {
      await authService.resendConfirmationEmail(email);
      _startResendCooldown();
      flash('Bestätigungs-E-Mail erneut gesendet.');
    } catch (_) {
      flash('Konnte die E-Mail nicht erneut senden. Bitte kurz warten.');
    }
  }

  // ---------------------------------------------------------------------
  // Password reset ("Passwort vergessen") — 6-digit recovery code flow
  // ---------------------------------------------------------------------

  bool passwordResetBusy = false;
  String? passwordResetError;
  String? _passwordResetEmail;

  /// null → not started · 'code' → code sent, awaiting entry · 'password' →
  /// code verified, awaiting new password.
  String? passwordResetStage;

  void beginPasswordReset() {
    passwordResetStage = null;
    passwordResetError = null;
    _passwordResetEmail = null;
    notifyListeners();
  }

  Future<void> sendPasswordResetCode(String email) async {
    passwordResetBusy = true;
    passwordResetError = null;
    notifyListeners();
    try {
      await authService.sendPasswordResetCode(email.trim());
      _passwordResetEmail = email.trim();
      passwordResetStage = 'code';
    } catch (_) {
      passwordResetError = 'E-Mail konnte nicht gesendet werden.';
    } finally {
      passwordResetBusy = false;
      notifyListeners();
    }
  }

  Future<void> verifyPasswordResetCode(String code) async {
    final email = _passwordResetEmail;
    if (email == null) return;
    passwordResetBusy = true;
    passwordResetError = null;
    notifyListeners();
    try {
      await authService.verifyPasswordResetCode(email: email, token: code.trim());
      passwordResetStage = 'password';
    } catch (_) {
      passwordResetError = 'Code ungültig oder abgelaufen.';
    } finally {
      passwordResetBusy = false;
      notifyListeners();
    }
  }

  Future<bool> setNewPassword(String newPassword) async {
    passwordResetBusy = true;
    passwordResetError = null;
    notifyListeners();
    try {
      await authService.updatePassword(newPassword);
      passwordResetStage = null;
      _passwordResetEmail = null;
      flash('Passwort geändert. Du bist angemeldet.');
      await loadEverything();
      return true;
    } catch (_) {
      passwordResetError = 'Passwort konnte nicht gesetzt werden.';
      return false;
    } finally {
      passwordResetBusy = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------

  bool get isTrainer => profile?.isTrainer ?? false;

  void goTab(int t) {
    tab = t;
    modal = ModalKind.none;
    notifyListeners();
  }

  /// Changes [selectedDay] and re-checks the device calendar for that new
  /// day — used for slot creation (trainer) and browsing free slots to
  /// book (rider) alike.
  void selectDay(DateTime d) {
    selectedDay = dateOnly(d);
    calendarMonth = firstOfMonth(selectedDay);
    notifyListeners();
    unawaited(loadDeviceBusyBlocksForSelectedDay());
  }

  void shiftCalendarMonth(int delta) {
    calendarMonth = DateTime(
      calendarMonth.year,
      calendarMonth.month + delta,
      1,
    );
    notifyListeners();
  }

  /// Moves [selectedDay] a whole week forward/backward, keeping the same
  /// weekday (e.g. rider browsing further weeks in the booking tab).
  void shiftSelectedWeek(int deltaWeeks) {
    selectDay(selectedDay.add(Duration(days: 7 * deltaWeeks)));
  }

  void closeModal() {
    modal = ModalKind.none;
    activeSlot = null;
    notifyListeners();
  }

  void flash(String message) {
    toast = message;
    notifyListeners();
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 2600), () {
      toast = null;
      notifyListeners();
    });
  }

  // ---------------------------------------------------------------------
  // Trainer: slot creation / cancellation
  // ---------------------------------------------------------------------

  void openSlotForm() {
    // Seed the draft from the trainer's saved defaults (chosen at sign-up,
    // editable in settings) so the form opens on their usual choices.
    final p = profile;
    form.reset(
      mode: slotModeFromString(p?.defaultSlotMode),
      duration: '${p?.defaultDurationMinutes ?? 45}',
      repeat: p?.defaultRepeat ?? 'Einmalig',
    );
    modal = ModalKind.slotForm;
    notifyListeners();
    unawaited(loadDeviceBusyBlocksForSelectedDay());
  }

  List<DeviceBusyBlock> deviceBusyBlocks = [];
  bool loadingBusyBlocks = false;

  Future<void> loadDeviceBusyBlocksForSelectedDay() async {
    final requestedDay = selectedDay;
    loadingBusyBlocks = true;
    notifyListeners();
    try {
      final blocks = await calendarSync.fetchBusyBlocks(requestedDay);
      // The selected day may have changed while this was in flight — don't
      // clobber a newer result with this now-stale one.
      if (!isSameDate(requestedDay, selectedDay)) return;
      deviceBusyBlocks = blocks;
    } catch (_) {
      if (isSameDate(requestedDay, selectedDay)) deviceBusyBlocks = [];
    } finally {
      if (isSameDate(requestedDay, selectedDay)) loadingBusyBlocks = false;
      notifyListeners();
    }
  }

  /// Only *timed* device events count as a hard scheduling conflict; all-day
  /// events are surfaced separately as a soft hint ([deviceAllDayHints]).
  DeviceBusyBlock? _conflictFor(DateTime start, DateTime end) {
    for (final b in deviceBusyBlocks) {
      if (!b.allDay && b.overlaps(start, end)) return b;
    }
    return null;
  }

  /// All-day personal appointments on the selected day — shown as a
  /// non-blocking note ("Du hast an dem Tag einen ganztägigen Termin: …").
  List<DeviceBusyBlock> get deviceAllDayHints =>
      deviceBusyBlocks.where((b) => b.allDay).toList();

  /// The device-calendar appointment (if any) a published [slot] collides
  /// with — used when a rider is browsing free slots to book.
  DeviceBusyBlock? conflictForSlot(LessonSlot slot) {
    if (!isSameDate(slot.date, selectedDay)) return null;
    final start = combineDateAndTime(slot.date, slot.startTime);
    final end = combineDateAndTime(slot.date, slot.endTime);
    return _conflictFor(start, end);
  }

  /// One-off check — independent of [deviceBusyBlocks], which only tracks
  /// the currently selected day — for a personal device-calendar (or synced
  /// Google-calendar) appointment overlapping an arbitrary date/time. Used
  /// before a trainer accepts a lesson request for a day they're not
  /// currently looking at. Returns null on any error or missing permission.
  Future<DeviceBusyBlock?> calendarConflictFor({
    required DateTime date,
    required String time,
    required int durationMinutes,
  }) async {
    try {
      final blocks = await calendarSync.fetchBusyBlocks(date);
      final start = combineDateAndTime(date, time);
      final end = start.add(Duration(minutes: durationMinutes));
      for (final b in blocks) {
        if (!b.allDay && b.overlaps(start, end)) return b;
      }
    } catch (_) {}
    return null;
  }

  /// Titles of any all-day personal appointments on [date] — a soft,
  /// non-blocking hint (e.g. before approving a lesson request).
  Future<List<String>> calendarAllDayTitlesFor(DateTime date) async {
    try {
      final blocks = await calendarSync.fetchBusyBlocks(date);
      return [for (final b in blocks) if (b.allDay) b.title];
    } catch (_) {
      return const [];
    }
  }

  /// Single-mode: the device-calendar appointment (if any) that the chosen
  /// start time collides with.
  DeviceBusyBlock? get formSingleConflict {
    if (form.isRange) return null;
    final start = combineDateAndTime(selectedDay, form.time);
    final end = combineDateAndTime(
      selectedDay,
      addMinutesToTime(form.time, int.parse(form.duration)),
    );
    return _conflictFor(start, end);
  }

  /// Range mode: the back-to-back start times with no device-calendar
  /// conflict — lessons that would collide with an existing personal
  /// appointment are silently skipped.
  List<String> get formRangeFreeStartTimes {
    if (!form.isRange) return [];
    final durationMinutes = int.parse(form.duration);
    return form.rangeStartTimes.where((t) {
      final start = combineDateAndTime(selectedDay, t);
      return _conflictFor(
            start,
            start.add(Duration(minutes: durationMinutes)),
          ) ==
          null;
    }).toList();
  }

  void setFormMode(SlotFormMode v) {
    form.mode = v;
    notifyListeners();
  }

  void setFormTime(String v) {
    form.time = v;
    notifyListeners();
  }

  void setFormRangeStart(String v) {
    form.rangeStart = v;
    notifyListeners();
  }

  void setFormRangeEnd(String v) {
    form.rangeEnd = v;
    notifyListeners();
  }

  void setFormDuration(String v) {
    form.duration = v;
    notifyListeners();
  }

  void setFormRepeat(String v) {
    form.repeat = v;
    notifyListeners();
  }

  void setFormCount(String v) {
    form.count = v;
    notifyListeners();
  }

  void setFormAwayFacility(String v) {
    form.awayFacility = v;
    notifyListeners();
  }

  void toggleFormAway() {
    form.away = !form.away;
    notifyListeners();
  }

  void capMinus() {
    form.capacity = (form.capacity - 1).clamp(1, 12);
    notifyListeners();
  }

  void capPlus() {
    form.capacity = (form.capacity + 1).clamp(1, 12);
    notifyListeners();
  }

  String get formFacilityLabel =>
      form.away && form.awayFacility.trim().isNotEmpty
      ? form.awayFacility.trim()
      : (profile?.facility ?? '');

  String get formSummary {
    final loc = formFacilityLabel.isEmpty ? '–' : formFacilityLabel;
    if (form.isRange) {
      final total = form.rangeStartTimes.length;
      final free = formRangeFreeStartTimes.length;
      if (total == 0)
        return 'Zeitraum zu kurz für eine ${form.duration}-Minuten-Stunde.';
      final blockedNote = free < total
          ? ' · ${total - free} durch Kalender belegt'
          : '';
      final repeatNote = form.isRepeating
          ? ' · ${form.repeatCount}× ${form.repeat.toLowerCase()}'
          : '';
      return '$free× ${form.duration} Min ab ${form.rangeStart} Uhr, ${longDayLabel(selectedDay)} · '
          '${form.capacity} Plätze · $loc$blockedNote$repeatNote';
    }
    final conflict = formSingleConflict;
    if (conflict != null) {
      return 'Kollidiert mit „${conflict.title}“ in deinem Kalender (${_hm(conflict.start)}–${_hm(conflict.end)}).';
    }
    final reps = form.repeatCount;
    if (reps > 1) {
      return '$reps× ${form.repeat.toLowerCase()} ab ${longDayLabel(selectedDay)}, ${form.time} Uhr · ${form.capacity} Plätze · $loc';
    }
    final end = addMinutesToTime(form.time, int.parse(form.duration));
    return '${longDayLabel(selectedDay)}, ${form.time}–$end Uhr · ${form.capacity} Plätze · $loc';
  }

  String _hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  /// Publishes the slot(s) described by [form]. Pass [ignoreCalendarConflict]
  /// when the trainer has explicitly chosen "Trotzdem veröffentlichen" after
  /// being warned that a single slot's time collides with their calendar.
  Future<void> saveSlot({bool ignoreCalendarConflict = false}) async {
    final p = profile;
    if (p == null || !p.isTrainer) return;
    if (form.away && form.awayFacility.trim().isEmpty) {
      flash('Bitte eine Anlage angeben.');
      return;
    }
    if (!form.isRange && formSingleConflict != null && !ignoreCalendarConflict) {
      flash('Diese Zeit ist in deinem Kalender bereits belegt.');
      return;
    }

    final startTimes = form.isRange ? formRangeFreeStartTimes : [form.time];
    if (startTimes.isEmpty) {
      flash(
        form.rangeStartTimes.isEmpty
            ? 'Zeitraum ist zu kurz für eine Stunde dieser Länge.'
            : 'Der ganze Zeitraum ist in deinem Kalender bereits belegt.',
      );
      return;
    }

    final seriesId = form.isRepeating ? _uuid.v4() : null;
    final dayCount = form.repeatCount;
    final rows = <Map<String, dynamic>>[];
    for (var i = 0; i < dayCount; i++) {
      final d = selectedDay.add(Duration(days: i * form.repeatStepDays));
      for (final start in startTimes) {
        rows.add({
          'trainer_id': p.id,
          'lesson_date': isoDate(d),
          'start_time': start,
          'duration_minutes': int.parse(form.duration),
          'facility': formFacilityLabel,
          'capacity': form.capacity,
          'series_id': seriesId,
          'status': 'open',
        });
      }
    }

    savingSlot = true;
    notifyListeners();
    try {
      final published = await api.publishSlots(rows);
      closeModal();
      await refreshSlots();

      final riderIds = linkedRiders.map((r) => r.id).toList();
      final title = rows.length > 1
          ? 'Neue Serie veröffentlicht'
          : 'Neue Stunde veröffentlicht';
      final seriesPrefix = rows.length > 1 ? '${rows.length} Termine ab ' : '';
      final body =
          '$seriesPrefix${longDayLabel(selectedDay)}, ${startTimes.first} Uhr · '
          '$formFacilityLabel · ${form.capacity} Plätze.';
      await api.notifyMany(
        userIds: riderIds,
        kind: 'cal',
        title: title,
        body: body,
        slotId: published.isEmpty ? null : published.first.id,
      );

      flash(
        rows.length > 1
            ? '${rows.length} Termine veröffentlicht'
            : 'Stunde veröffentlicht · ${startTimes.first}',
      );
      form.reset(
        mode: slotModeFromString(p.defaultSlotMode),
        duration: '${p.defaultDurationMinutes}',
        repeat: p.defaultRepeat,
      );
    } catch (e) {
      flash('Konnte Stunde nicht veröffentlichen.');
    } finally {
      savingSlot = false;
      notifyListeners();
    }
  }

  void openDetail(LessonSlot slot) {
    activeSlot = slot;
    modal = ModalKind.detail;
    notifyListeners();
  }

  /// Cancels [activeSlot]. When [wholeSeries] is set (only offered for a slot
  /// that belongs to a series), every still-open lesson of that series from
  /// today onward is canceled too.
  Future<void> cancelActiveSlot({String? reason, bool wholeSeries = false}) async {
    final s = activeSlot;
    if (s == null) return;
    final reasonSuffix = (reason ?? '').trim().isEmpty ? '' : ' Grund: $reason';

    try {
      if (wholeSeries && s.seriesId != null) {
        final today = dateOnly(DateTime.now());
        // Cancel every open future slot of the series (booked + empty)...
        final canceled = await api.cancelSlotsInSeries(
          s.seriesId!,
          fromDate: today,
          reason: reason,
        );
        // ...then tidy up the ones nobody had booked.
        for (final slot in canceled.where((x) => x.bookings.isEmpty)) {
          await api.deleteSlot(slot.id);
        }
        final riderIds = <String>{
          for (final slot in canceled)
            for (final b in slot.bookings) b.riderId,
        }.toList();
        if (riderIds.isNotEmpty) {
          await api.notifyMany(
            userIds: riderIds,
            kind: 'clock',
            title: 'Serie abgesagt',
            body:
                'Die Serie ab ${longDayLabel(s.date)}, ${s.startTime} Uhr entfällt.$reasonSuffix '
                'Melde dich bei deinem Reitlehrer, falls das für dich ein Problem ist.',
            slotId: s.id,
          );
        }
        closeModal();
        await refreshSlots();
        flash('Serie abgesagt');
        return;
      }

      // Nobody had booked it — no need for a "canceled" tombstone, just
      // remove it outright. Otherwise mark it canceled and notify the
      // riders who'd booked; they can be deleted afterwards from the
      // detail sheet once that's no longer needed.
      if (s.bookings.isEmpty) {
        await api.deleteSlot(s.id);
        closeModal();
        await refreshSlots();
        flash('Stunde gelöscht');
        return;
      }

      await api.cancelSlot(s.id, reason: reason);
      final riderIds = s.bookings.map((b) => b.riderId).toList();
      await api.notifyMany(
        userIds: riderIds,
        kind: 'clock',
        title: 'Stunde abgesagt',
        body:
            '${longDayLabel(s.date)}, ${s.startTime} Uhr entfällt.$reasonSuffix '
            'Melde dich bei deinem Reitlehrer, falls das für dich ein Problem ist.',
        slotId: s.id,
      );
      closeModal();
      await refreshSlots();
      flash('Stunde abgesagt');
    } catch (e) {
      flash('Absage fehlgeschlagen.');
    }
  }

  /// Permanently removes a canceled, unbooked lesson slot — for tidying up
  /// after a cancellation nobody had booked anyway.
  Future<void> deleteSlotPermanently(LessonSlot s) async {
    try {
      await api.deleteSlot(s.id);
      closeModal();
      await refreshSlots();
      flash('Stunde gelöscht');
    } catch (e) {
      flash('Löschen fehlgeschlagen.');
    }
  }

  /// Edits an already-published slot — e.g. raising capacity after
  /// approving a request that only booked the one seat.
  Future<void> updateActiveSlot({
    int? capacity,
    int? durationMinutes,
    String? facility,
  }) async {
    final s = activeSlot;
    if (s == null) return;
    savingSlot = true;
    notifyListeners();
    try {
      await api.updateSlot(
        s.id,
        capacity: capacity,
        durationMinutes: durationMinutes,
        facility: facility,
      );
      await refreshSlots();
      activeSlot = slotById(s.id) ?? s;
      flash('Stunde aktualisiert');
    } catch (e) {
      flash('Konnte Stunde nicht aktualisieren.');
    } finally {
      savingSlot = false;
      notifyListeners();
    }
  }

  /// Removes one rider from [activeSlot] ("ausladen") — either as a plain
  /// cancellation, or as the first half of proposing them a different time
  /// (see [proposeAlternateTimeFor]).
  Future<void> removeBookingFromActiveSlot(
    SlotBooking booking, {
    bool notify = true,
  }) async {
    final s = activeSlot;
    if (s == null) return;
    try {
      final deleted = await api.removeBooking(booking.id);
      if (deleted == null) {
        // RLS silently excluded the row — nothing was actually removed.
        // Most likely cause: the DB is missing the "bookings_delete_own_trainer"
        // policy from a schema.sql update that hasn't been re-run yet.
        flash('Konnte nicht ausladen — bitte schema.sql erneut ausführen.');
        return;
      }
      if (notify) {
        await api.createNotification(
          userId: booking.riderId,
          kind: 'clock',
          title: 'Aus Stunde ausgetragen',
          body:
              '${longDayLabel(s.date)}, ${s.startTime} Uhr — dein Platz wurde storniert.',
          slotId: s.id,
        );
      }
      await refreshSlots();
      activeSlot = slotById(s.id) ?? s;
      flash('${booking.riderName} ausgetragen');
    } catch (e) {
      flash('Konnte nicht ausladen.');
    }
  }

  /// A rider withdrawing their own booking (self-serve) — only allowed
  /// until [Profile.bookingLeadHours] before the lesson starts, mirroring
  /// the trainer's own booking-lead-time setting.
  Future<void> withdrawOwnBooking(LessonSlot s) async {
    final uid = profile?.id;
    if (uid == null) return;
    SlotBooking? mine;
    for (final b in s.bookings) {
      if (b.riderId == uid) mine = b;
    }
    if (mine == null) return;
    try {
      final deleted = await api.removeBooking(mine.id);
      if (deleted == null) {
        flash('Stornierung fehlgeschlagen.');
        return;
      }
      await api.createNotification(
        userId: s.trainerId,
        kind: 'user',
        title: 'Buchung storniert',
        body:
            '${profile?.fullName ?? 'Ein Schüler'} hat ${longDayLabel(s.date)}, ${s.startTime} Uhr storniert.',
        slotId: s.id,
      );
      await refreshSlots();
      activeSlot = slotById(s.id) ?? s;
      flash('Buchung storniert');
    } catch (e) {
      flash('Stornierung fehlgeschlagen.');
    }
  }

  /// Removes [booking] from the current slot and creates a fresh one-off
  /// slot (capacity 1) for them at the proposed time, booking them straight
  /// in — the trainer already decided, no approval round-trip needed.
  Future<void> proposeAlternateTimeFor(
    SlotBooking booking, {
    required DateTime date,
    required String time,
    required int durationMinutes,
  }) async {
    final s = activeSlot;
    final p = profile;
    if (s == null || p == null) return;
    savingSlot = true;
    notifyListeners();
    try {
      final removed = await api.removeBooking(booking.id);
      if (removed == null) {
        flash(
          'Konnte den alten Platz nicht freigeben — bitte schema.sql erneut ausführen.',
        );
        return;
      }
      final created = await api.publishSlots([
        {
          'trainer_id': p.id,
          'lesson_date': isoDate(date),
          'start_time': time,
          'duration_minutes': durationMinutes,
          'facility': s.facility,
          'capacity': 1,
          'status': 'open',
        },
      ]);
      final newSlot = created.first;
      await api.bookSlot(slotId: newSlot.id, riderId: booking.riderId);
      await api.createNotification(
        userId: booking.riderId,
        kind: 'cal',
        title: 'Neuer Termin vorgeschlagen',
        body:
            'Statt ${longDayLabel(s.date)}, ${s.startTime} Uhr jetzt ${longDayLabel(date)}, $time Uhr.',
        slotId: newSlot.id,
      );
      await refreshSlots();
      activeSlot = slotById(s.id) ?? s;
      flash('Neuer Termin für ${booking.riderName} vorgeschlagen');
    } catch (e) {
      flash('Konnte keinen neuen Termin anlegen.');
    } finally {
      savingSlot = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------
  // Rider: booking
  // ---------------------------------------------------------------------

  void openConfirm(LessonSlot slot) {
    activeSlot = slot;
    modal = ModalKind.confirm;
    notifyListeners();
  }

  Future<void> confirmBookingActive() async {
    final s = activeSlot;
    final p = profile;
    if (s == null || p == null) return;
    try {
      await api.bookSlot(slotId: s.id, riderId: p.id);
      await api.createNotification(
        userId: s.trainerId,
        kind: 'user',
        title: 'Neue Buchung',
        body:
            '${p.fullName} hat ${longDayLabel(s.date)}, ${s.startTime} Uhr gebucht.',
        slotId: s.id,
      );
      closeModal();
      tab = 1;
      await refreshSlots();
      flash('Platz gebucht · ${s.startTime} Uhr');
    } on PostgrestException catch (e) {
      flash(e.message);
    } catch (e) {
      flash('Buchung fehlgeschlagen.');
    }
  }

  // ---------------------------------------------------------------------
  // Lesson requests — a rider proposing a time the trainer hasn't published
  // (only when the linked trainer has turned this on in their settings)
  // ---------------------------------------------------------------------

  List<LessonRequest> get pendingRequests =>
      lessonRequests.where((r) => r.isPending).toList();

  Future<bool> submitLessonRequest({
    required DateTime date,
    required String time,
    required int durationMinutes,
    String? note,
  }) async {
    final p = profile;
    final trainer = primaryTrainer;
    if (p == null || trainer == null) return false;
    if (!trainer.allowRequests) {
      flash('Dein Reitlehrer nimmt aktuell keine Anfragen an.');
      return false;
    }

    savingRequest = true;
    notifyListeners();
    try {
      await api.createLessonRequest(
        trainerId: trainer.id,
        riderId: p.id,
        date: date,
        time: time,
        durationMinutes: durationMinutes,
        note: note,
      );
      await api.createNotification(
        userId: trainer.id,
        kind: 'user',
        title: 'Neue Stundenanfrage',
        body: '${p.fullName} fragt ${longDayLabel(date)}, $time Uhr an.',
      );
      await refreshRequests();
      flash('Anfrage gesendet');
      return true;
    } catch (e) {
      flash('Anfrage konnte nicht gesendet werden.');
      return false;
    } finally {
      savingRequest = false;
      notifyListeners();
    }
  }

  Future<void> approveRequest(LessonRequest request) async {
    try {
      final slotId = await api.approveLessonRequest(request.id);
      await api.createNotification(
        userId: request.riderId,
        kind: 'cal',
        title: 'Anfrage angenommen',
        body:
            '${longDayLabel(request.date)}, ${request.time} Uhr wurde bestätigt.',
        slotId: slotId,
      );
      await refreshRequests();
      await refreshSlots();
      flash('Anfrage angenommen · Stunde veröffentlicht');
    } catch (e) {
      flash('Konnte Anfrage nicht annehmen.');
    }
  }

  Future<void> declineRequest(LessonRequest request) async {
    try {
      await api.declineLessonRequest(request.id);
      await api.createNotification(
        userId: request.riderId,
        kind: 'user',
        title: 'Anfrage abgelehnt',
        body:
            '${longDayLabel(request.date)}, ${request.time} Uhr wurde leider abgelehnt.',
      );
      await refreshRequests();
      flash('Anfrage abgelehnt');
    } catch (e) {
      flash('Konnte Anfrage nicht ablehnen.');
    }
  }

  // ---------------------------------------------------------------------
  // Student notes (trainer-private) — general or tied to one lesson
  // ---------------------------------------------------------------------

  List<StudentNote> studentNotes = [];
  bool loadingStudentNotes = false;

  /// This trainer's lessons with [riderId], most recent first.
  List<LessonSlot> lessonsForRider(String riderId) =>
      _sorted(slots.where((s) => s.bookedByRider(riderId))).reversed.toList();

  Future<void> loadStudentNotes(String riderId) async {
    loadingStudentNotes = true;
    notifyListeners();
    try {
      studentNotes = await api.fetchStudentNotes(riderId);
    } catch (_) {
      studentNotes = [];
    } finally {
      loadingStudentNotes = false;
      notifyListeners();
    }
  }

  /// [slotId] + [phase] ('before' | 'after') tie the note to one lesson;
  /// leave both null for a general note about the student.
  Future<void> addStudentNote({
    required String riderId,
    required String body,
    String? slotId,
    String? phase,
  }) async {
    final p = profile;
    if (p == null || body.trim().isEmpty) return;
    try {
      await api.addStudentNote(
        trainerId: p.id,
        riderId: riderId,
        body: body.trim(),
        slotId: slotId,
        phase: phase,
      );
      await loadStudentNotes(riderId);
    } catch (e) {
      flash('Notiz konnte nicht gespeichert werden.');
    }
  }

  Future<void> deleteStudentNote(StudentNote note) async {
    studentNotes = studentNotes.where((n) => n.id != note.id).toList();
    notifyListeners();
    try {
      await api.deleteStudentNote(note.id);
    } catch (e) {
      flash('Notiz konnte nicht gelöscht werden.');
      await loadStudentNotes(note.riderId);
    }
  }

  // ---------------------------------------------------------------------
  // Feature requests (open board — every signed-in user can post/vote)
  // ---------------------------------------------------------------------

  List<FeatureRequest> featureRequests = [];
  Map<String, int> featureScores = {};
  Map<String, int> myFeatureVotes = {};
  bool loadingFeatureRequests = false;

  /// [featureRequests] sorted by net score (highest first).
  List<FeatureRequest> get sortedFeatureRequests {
    final list = List<FeatureRequest>.from(featureRequests);
    list.sort(
      (a, b) => (featureScores[b.id] ?? 0).compareTo(featureScores[a.id] ?? 0),
    );
    return list;
  }

  Future<void> loadFeatureRequests() async {
    loadingFeatureRequests = true;
    notifyListeners();
    try {
      featureRequests = await api.fetchFeatureRequests();
      final votes = await api.fetchFeatureVotes();
      final uid = profile?.id;
      final scores = <String, int>{};
      final mine = <String, int>{};
      for (final v in votes) {
        final rid = v['request_id'] as String;
        final value = v['value'] as int;
        scores[rid] = (scores[rid] ?? 0) + value;
        if (v['user_id'] == uid) mine[rid] = value;
      }
      featureScores = scores;
      myFeatureVotes = mine;
    } catch (_) {
      featureRequests = [];
    } finally {
      loadingFeatureRequests = false;
      notifyListeners();
    }
  }

  Future<void> submitFeatureRequest({
    required String title,
    String? description,
  }) async {
    final p = profile;
    if (p == null || title.trim().isEmpty) return;
    try {
      await api.createFeatureRequest(
        authorId: p.id,
        title: title.trim(),
        description: description?.trim(),
      );
      await loadFeatureRequests();
    } catch (e) {
      flash('Konnte Vorschlag nicht speichern.');
    }
  }

  Future<void> deleteFeatureRequest(FeatureRequest r) async {
    featureRequests = featureRequests.where((x) => x.id != r.id).toList();
    notifyListeners();
    try {
      await api.deleteFeatureRequest(r.id);
    } catch (e) {
      flash('Konnte Vorschlag nicht löschen.');
      await loadFeatureRequests();
    }
  }

  /// Casts (or toggles off, if already this value) an up/down vote.
  Future<void> voteFeature(String requestId, int value) async {
    final uid = profile?.id;
    if (uid == null) return;
    final current = myFeatureVotes[requestId];
    final turningOff = current == value;

    final scores = Map<String, int>.from(featureScores);
    final mine = Map<String, int>.from(myFeatureVotes);
    scores[requestId] =
        (scores[requestId] ?? 0) - (current ?? 0) + (turningOff ? 0 : value);
    if (turningOff) {
      mine.remove(requestId);
    } else {
      mine[requestId] = value;
    }
    featureScores = scores;
    myFeatureVotes = mine;
    notifyListeners();

    try {
      if (turningOff) {
        await api.clearFeatureVote(requestId: requestId, userId: uid);
      } else {
        await api.setFeatureVote(
          requestId: requestId,
          userId: uid,
          value: value,
        );
      }
    } catch (e) {
      flash('Stimme konnte nicht gespeichert werden.');
      await loadFeatureRequests();
    }
  }

  Future<void> withdrawRequest(LessonRequest request) async {
    try {
      await api.withdrawLessonRequest(request.id);
      await refreshRequests();
      flash('Anfrage zurückgezogen');
    } catch (e) {
      flash('Konnte Anfrage nicht zurückziehen.');
    }
  }

  void openLink() {
    modal = ModalKind.link;
    notifyListeners();
  }

  void openEditSettings() {
    modal = ModalKind.editSettings;
    notifyListeners();
  }

  void openEditRiderSettings() {
    modal = ModalKind.editRiderSettings;
    notifyListeners();
  }

  void openRequestLesson() {
    modal = ModalKind.requestLesson;
    notifyListeners();
  }

  Future<void> submitLinkCode(String code) async {
    if (code.trim().isEmpty) return;
    try {
      final trainer = await api.linkTrainerByCode(code.trim());
      linkedTrainers = [
        trainer,
        ...linkedTrainers.where((t) => t.id != trainer.id),
      ];
      closeModal();
      await refreshSlots();
      flash('${trainer.fullName} verknüpft');
    } on PostgrestException catch (e) {
      flash(e.message);
    } catch (e) {
      flash('Link ungültig.');
    }
  }

  // ---------------------------------------------------------------------
  // Trainer finden — public search
  // ---------------------------------------------------------------------

  List<Profile> trainerSearchResults = [];
  bool searchingTrainers = false;

  Future<void> searchTrainers(String query) async {
    searchingTrainers = true;
    notifyListeners();
    try {
      trainerSearchResults = await api.searchTrainers(query);
    } catch (_) {
      trainerSearchResults = [];
    } finally {
      searchingTrainers = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------
  // Dual role — one account acting as trainer and/or rider
  // ---------------------------------------------------------------------

  bool switchingRole = false;

  /// Switches which role's UI is currently shown. If the account hasn't
  /// activated [newRole] yet, activates it first (generating an invite code
  /// for a brand-new trainer role).
  Future<void> switchActiveRole(String newRole) async {
    final p = profile;
    if (p == null || p.role == newRole || switchingRole) return;
    switchingRole = true;
    notifyListeners();
    try {
      if (newRole == 'trainer' && !p.canBeTrainer) {
        final updated = await api.activateTrainerRole();
        profile = updated.copyWith(role: newRole);
        await api.updateProfile(p.id, role: newRole);
      } else if (newRole == 'rider' && !p.canBeRider) {
        await api.updateProfile(p.id, role: newRole, isRider: true);
        profile = p.copyWith(role: newRole, canBeRider: true);
      } else {
        await api.updateProfile(p.id, role: newRole);
        profile = p.copyWith(role: newRole);
      }
      tab = 1;
      await _reloadRoleData();
      flash(
        newRole == 'trainer' ? 'Als Reitlehrer:in aktiv' : 'Als Schüler:in aktiv',
      );
    } catch (e) {
      flash('Rolle konnte nicht gewechselt werden.');
    } finally {
      switchingRole = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------
  // Incoming invite links (https://galoppal.de/t/<code>) — Universal/App
  // Links land here from main.dart's app_links listener. If we're not
  // signed in yet, or not currently in rider view, the code is remembered
  // and applied automatically the next time that becomes possible.
  // ---------------------------------------------------------------------

  String? pendingInviteCode;

  void handleIncomingInviteCode(String code) {
    if (code.trim().isEmpty) return;
    pendingInviteCode = code.trim();
    _tryConsumePendingInviteCode();
  }

  Future<void> _tryConsumePendingInviteCode() async {
    final code = pendingInviteCode;
    final p = profile;
    if (code == null || p == null) return;
    if (p.isTrainer) {
      // Signed in as a trainer right now — a trainer account can also be
      // linked as a rider once they switch, but auto-switching them without
      // asking would be surprising. Leave the code pending.
      return;
    }
    pendingInviteCode = null;
    await submitLinkCode(code);
  }

  // ---------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------

  Future<void> openNotification(AppNotification n) async {
    if (!n.isRead) {
      await api.markNotificationRead(n.id);
      await refreshNotifications();
    }
  }

  Future<void> deleteNotification(AppNotification n) async {
    notifications = notifications.where((x) => x.id != n.id).toList();
    notifyListeners();
    try {
      await api.deleteNotification(n.id);
    } catch (e) {
      flash('Konnte Mitteilung nicht löschen.');
      await refreshNotifications();
    }
  }

  Future<void> markAllNotificationsRead() async {
    final uid = profile?.id;
    if (uid == null) return;
    await api.markAllNotificationsRead(uid);
    await refreshNotifications();
  }

  int get unreadCount => notifications.where((n) => !n.isRead).length;
  bool get hasUnread => unreadCount > 0;

  // ---------------------------------------------------------------------
  // Profile
  // ---------------------------------------------------------------------

  Future<void> updateProfileFields({
    String? bio,
    String? facility,
    String? address,
    String? stableName,
    int? defaultDurationMinutes,
    int? defaultCapacity,
    String? defaultSlotMode,
    String? defaultRepeat,
    int? bookingLeadHours,
    int? reminderHours,
    bool? allowRequests,
    String? avatarUrl,
  }) async {
    final p = profile;
    if (p == null) return;
    savingProfile = true;
    notifyListeners();
    try {
      await api.updateProfile(
        p.id,
        bio: bio,
        facility: facility,
        address: address,
        stableName: stableName,
        defaultDurationMinutes: defaultDurationMinutes,
        defaultCapacity: defaultCapacity,
        defaultSlotMode: defaultSlotMode,
        defaultRepeat: defaultRepeat,
        bookingLeadHours: bookingLeadHours,
        reminderHours: reminderHours,
        allowRequests: allowRequests,
        avatarUrl: avatarUrl,
      );
      profile = p.copyWith(
        bio: bio,
        facility: facility,
        address: address,
        stableName: stableName,
        defaultDurationMinutes: defaultDurationMinutes,
        defaultCapacity: defaultCapacity,
        defaultSlotMode: defaultSlotMode,
        defaultRepeat: defaultRepeat,
        bookingLeadHours: bookingLeadHours,
        reminderHours: reminderHours,
        allowRequests: allowRequests,
        avatarUrl: avatarUrl,
      );
      flash('Einstellungen gespeichert');
    } catch (e) {
      flash('Konnte Einstellungen nicht speichern.');
    } finally {
      savingProfile = false;
      notifyListeners();
    }
  }

  /// Picks an image (gallery or camera) and sets it as the profile picture.
  Future<void> pickAndUpdateAvatar(ImageSource source) async {
    final p = profile;
    if (p == null) return;
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;

    savingProfile = true;
    notifyListeners();
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.path.split('.').last.toLowerCase();
      final url = await api.uploadAvatar(
        p.id,
        bytes,
        ext.isEmpty ? 'jpg' : ext,
      );
      await api.updateProfile(p.id, avatarUrl: url);
      profile = p.copyWith(avatarUrl: url);
      flash('Profilbild aktualisiert');
    } catch (e) {
      flash('Profilbild konnte nicht gespeichert werden.');
    } finally {
      savingProfile = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------
  // Derived data
  // ---------------------------------------------------------------------

  Profile? get primaryTrainer =>
      linkedTrainers.isEmpty ? null : linkedTrainers.first;

  String get homeFacility =>
      isTrainer ? (profile?.facility ?? '') : (primaryTrainer?.facility ?? '');

  List<LessonSlot> _sorted(Iterable<LessonSlot> input) {
    final list = input.toList();
    list.sort((a, b) {
      final d = a.date.compareTo(b.date);
      return d != 0 ? d : a.startTime.compareTo(b.startTime);
    });
    return list;
  }

  List<LessonSlot> get todaySlotsForTrainer {
    final today = dateOnly(DateTime.now());
    return _sorted(slots.where((s) => isSameDate(s.date, today)));
  }

  List<LessonSlot> get myBookedSlotsForRider {
    final uid = profile?.id;
    if (uid == null) return [];
    return _sorted(slots.where((s) => !s.isCanceled && s.bookedByRider(uid)));
  }

  LessonSlot? get nextSlot {
    if (isTrainer) {
      final upcoming = todaySlotsForTrainer.where((s) => !s.isCanceled);
      return upcoming.isEmpty ? null : upcoming.first;
    }
    final mine = myBookedSlotsForRider;
    return mine.isEmpty ? null : mine.first;
  }

  List<LessonSlot> get homeList {
    if (isTrainer) return todaySlotsForTrainer;
    final mine = myBookedSlotsForRider;
    return mine.length > 1 ? mine.sublist(1) : [];
  }

  bool get homeListEmpty => isTrainer
      ? todaySlotsForTrainer.isEmpty
      : myBookedSlotsForRider.length < 2;

  List<LessonSlot> get daySlots =>
      _sorted(slots.where((s) => isSameDate(s.date, selectedDay)));

  LessonSlot? slotById(String id) {
    for (final s in slots) {
      if (s.id == id) return s;
    }
    return null;
  }

  List<LessonSlot> get freeSlotsForSelectedDay {
    final uid = profile?.id;
    if (uid == null) return [];
    return daySlots.where((s) => s.isOpen && !s.bookedByRider(uid)).toList();
  }

  /// Days-of-month (1-based) in [calendarMonth] that have at least one
  /// active (non-canceled) slot — drives the little dot under each date.
  Set<int> get monthActiveDays {
    return {
      for (final s in slots)
        if (!s.isCanceled &&
            s.date.year == calendarMonth.year &&
            s.date.month == calendarMonth.month)
          s.date.day,
    };
  }

  int get monthSlotCount => slots
      .where(
        (s) =>
            !s.isCanceled &&
            s.date.year == calendarMonth.year &&
            s.date.month == calendarMonth.month,
      )
      .length;
}
