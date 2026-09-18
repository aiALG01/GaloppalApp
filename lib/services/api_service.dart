import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_notification.dart';
import '../models/feature_request.dart';
import '../models/lesson_request.dart';
import '../models/lesson_slot.dart';
import '../models/profile.dart';
import '../models/student_note.dart';
import '../utils/date_utils.dart';
import 'supabase_client.dart';

const _bookingsEmbed =
    'bookings(id, rider_id, rider:profiles!bookings_rider_id_fkey(full_name))';

/// All Supabase data access for the app lives here so screens/state never
/// touch `supabase.from(...)` directly.
class ApiService {
  SupabaseClient get _db => supabase;

  // ---------------------------------------------------------------------
  // Profiles & links
  // ---------------------------------------------------------------------

  Future<Profile> fetchProfile(String userId) async {
    final row = await _db.from('profiles').select().eq('id', userId).single();
    return Profile.fromMap(row);
  }

  Future<void> updateProfile(
    String userId, {
    String? role,
    String? bio,
    String? facility,
    String? address,
    String? stableName,
    bool? isRider,
    int? defaultDurationMinutes,
    int? defaultCapacity,
    String? defaultSlotMode,
    String? defaultRepeat,
    int? bookingLeadHours,
    int? reminderHours,
    bool? allowRequests,
    String? avatarUrl,
  }) async {
    final patch = <String, dynamic>{
      'role': ?role,
      'bio': ?bio,
      'facility': ?facility,
      'address': ?address,
      'stable_name': ?stableName,
      'is_rider': ?isRider,
      'default_duration_minutes': ?defaultDurationMinutes,
      'default_capacity': ?defaultCapacity,
      'default_slot_mode': ?defaultSlotMode,
      'default_repeat': ?defaultRepeat,
      'booking_lead_hours': ?bookingLeadHours,
      'reminder_hours': ?reminderHours,
      'allow_requests': ?allowRequests,
      'avatar_url': ?avatarUrl,
    };
    if (patch.isEmpty) return;
    await _db.from('profiles').update(patch).eq('id', userId);
  }

  /// Activates the trainer role for the current user — generates an
  /// invite_code if they don't have one yet. See `activate_trainer_role` in
  /// supabase/schema.sql.
  Future<Profile> activateTrainerRole() async {
    final row = await _db.rpc('activate_trainer_role');
    return Profile.fromMap(row as Map<String, dynamic>);
  }

  /// Public trainer directory — "Trainer finden". Matches on name, venue
  /// name or address; empty query returns the first page of all trainers.
  Future<List<Profile>> searchTrainers(String query) async {
    final q = query.trim();
    var builder = _db.from('profiles').select().eq('is_trainer', true);
    if (q.isNotEmpty) {
      final escaped = q.replaceAll(',', ' ');
      builder = builder.or(
        'full_name.ilike.%$escaped%,facility.ilike.%$escaped%,address.ilike.%$escaped%',
      );
    }
    final rows = await builder.order('full_name').limit(30);
    return (rows as List)
        .map((r) => Profile.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Uploads a profile picture to the public "avatars" bucket at
  /// `<userId>/avatar.<ext>` (overwriting any previous one) and returns its
  /// public URL.
  Future<String> uploadAvatar(
    String userId,
    Uint8List bytes,
    String ext,
  ) async {
    final path = '$userId/avatar.$ext';
    await _db.storage
        .from('avatars')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    // Busts CDN/client caches so the new image shows immediately.
    return '${_db.storage.from('avatars').getPublicUrl(path)}?t=${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Every trainer linked to this rider, most recently linked first.
  Future<List<Profile>> fetchLinkedTrainers(String riderId) async {
    final rows = await _db
        .from('trainer_rider_links')
        .select(
          'created_at, trainer:profiles!trainer_rider_links_trainer_id_fkey(*)',
        )
        .eq('rider_id', riderId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map(
          (r) => Profile.fromMap(
            (r as Map<String, dynamic>)['trainer'] as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  /// Every rider linked to this trainer.
  Future<List<Profile>> fetchLinkedRiders(String trainerId) async {
    final rows = await _db
        .from('trainer_rider_links')
        .select(
          'created_at, rider:profiles!trainer_rider_links_rider_id_fkey(*)',
        )
        .eq('trainer_id', trainerId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map(
          (r) => Profile.fromMap(
            (r as Map<String, dynamic>)['rider'] as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  /// Redeems an invite link/code and returns the now-linked trainer profile.
  Future<Profile> linkTrainerByCode(String code) async {
    final row = await _db.rpc('link_trainer_by_code', params: {'p_code': code});
    return Profile.fromMap(row as Map<String, dynamic>);
  }

  // ---------------------------------------------------------------------
  // Lesson slots
  // ---------------------------------------------------------------------

  /// All slots for one trainer (used by both the trainer's own calendar and
  /// a linked rider's booking screen — RLS decides who is allowed to read).
  Future<List<LessonSlot>> fetchSlotsForTrainer(String trainerId) async {
    final rows = await _db
        .from('lesson_slots')
        .select('*, $_bookingsEmbed')
        .eq('trainer_id', trainerId)
        .order('lesson_date')
        .order('start_time');
    return (rows as List)
        .map((r) => LessonSlot.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Publishes one or more slots (a "series" shares a client-generated
  /// series_id). Returns the created rows.
  Future<List<LessonSlot>> publishSlots(List<Map<String, dynamic>> rows) async {
    final inserted = await _db
        .from('lesson_slots')
        .insert(rows)
        .select('*, $_bookingsEmbed');
    return (inserted as List)
        .map((r) => LessonSlot.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> cancelSlot(String slotId, {String? reason}) async {
    await _db
        .from('lesson_slots')
        .update({'status': 'canceled', 'cancel_reason': ?reason})
        .eq('id', slotId);
  }

  /// Cancels every still-open slot of a series from [fromDate] onward (past
  /// lessons are left untouched). Returns the affected slot rows so the
  /// caller can notify the riders who had booked them.
  Future<List<LessonSlot>> cancelSlotsInSeries(
    String seriesId, {
    required DateTime fromDate,
    String? reason,
  }) async {
    final rows = await _db
        .from('lesson_slots')
        .update({'status': 'canceled', 'cancel_reason': ?reason})
        .eq('series_id', seriesId)
        .eq('status', 'open')
        .gte('lesson_date', isoDate(fromDate))
        .select('*, $_bookingsEmbed');
    return (rows as List)
        .map((r) => LessonSlot.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteSlot(String slotId) async {
    await _db.from('lesson_slots').delete().eq('id', slotId);
  }

  /// Edits an existing slot — e.g. raising [capacity] to fit in more riders
  /// after approving a request that only booked one seat.
  Future<void> updateSlot(
    String slotId, {
    int? capacity,
    int? durationMinutes,
    String? facility,
  }) async {
    final patch = <String, dynamic>{
      'capacity': ?capacity,
      'duration_minutes': ?durationMinutes,
      'facility': ?facility,
    };
    if (patch.isEmpty) return;
    await _db.from('lesson_slots').update(patch).eq('id', slotId);
  }

  // ---------------------------------------------------------------------
  // Bookings
  // ---------------------------------------------------------------------

  Future<void> bookSlot({
    required String slotId,
    required String riderId,
  }) async {
    await _db.from('bookings').insert({'slot_id': slotId, 'rider_id': riderId});
  }

  /// Removes a booking (trainer un-enrolling a rider, or a rider
  /// withdrawing their own). Returns the deleted row, or null if nothing
  /// was actually deleted — e.g. an RLS policy silently excluded it, which
  /// a plain `.delete()` would otherwise report as a no-op "success".
  Future<Map<String, dynamic>?> removeBooking(String bookingId) async {
    final rows = await _db
        .from('bookings')
        .delete()
        .eq('id', bookingId)
        .select();
    return rows.isEmpty ? null : rows.first;
  }

  // ---------------------------------------------------------------------
  // Lesson requests — a rider proposing a time the trainer hasn't published
  // ---------------------------------------------------------------------

  static const _requestRiderEmbed =
      'rider:profiles!lesson_requests_rider_id_fkey(full_name)';
  static const _requestTrainerEmbed =
      'trainer:profiles!lesson_requests_trainer_id_fkey(full_name)';

  Future<LessonRequest> createLessonRequest({
    required String trainerId,
    required String riderId,
    required DateTime date,
    required String time,
    required int durationMinutes,
    String? note,
  }) async {
    final row = await _db
        .from('lesson_requests')
        .insert({
          'trainer_id': trainerId,
          'rider_id': riderId,
          'requested_date': isoDate(date),
          'requested_time': time,
          'duration_minutes': durationMinutes,
          'note': ?note,
        })
        .select('*, $_requestTrainerEmbed')
        .single();
    return LessonRequest.fromMap(row);
  }

  Future<List<LessonRequest>> fetchRequestsForTrainer(String trainerId) async {
    final rows = await _db
        .from('lesson_requests')
        .select('*, $_requestRiderEmbed')
        .eq('trainer_id', trainerId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => LessonRequest.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<LessonRequest>> fetchRequestsForRider(String riderId) async {
    final rows = await _db
        .from('lesson_requests')
        .select('*, $_requestTrainerEmbed')
        .eq('rider_id', riderId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => LessonRequest.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Approves a request: creates the matching lesson_slots + bookings rows
  /// server-side (see `approve_lesson_request` in supabase/schema.sql).
  /// Returns the id of the newly published slot.
  Future<String> approveLessonRequest(String requestId) async {
    final slotId = await _db.rpc(
      'approve_lesson_request',
      params: {'p_request_id': requestId},
    );
    return slotId as String;
  }

  Future<void> declineLessonRequest(String requestId) async {
    await _db
        .from('lesson_requests')
        .update({'status': 'declined'})
        .eq('id', requestId);
  }

  Future<void> withdrawLessonRequest(String requestId) async {
    await _db.from('lesson_requests').delete().eq('id', requestId);
  }

  // ---------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------

  Future<List<AppNotification>> fetchNotifications(String userId) async {
    final rows = await _db
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => AppNotification.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> markNotificationRead(String id) async {
    await _db.from('notifications').update({'is_read': true}).eq('id', id);
  }

  Future<void> markAllNotificationsRead(String userId) async {
    await _db
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  Future<void> deleteNotification(String id) async {
    await _db.from('notifications').delete().eq('id', id);
  }

  Future<void> createNotification({
    required String userId,
    required String kind,
    required String title,
    required String body,
    String? slotId,
  }) async {
    await _db.from('notifications').insert({
      'user_id': userId,
      'kind': kind,
      'title': title,
      'body': body,
      if (slotId != null) 'slot_id': slotId,
    });
  }

  Future<void> notifyMany({
    required List<String> userIds,
    required String kind,
    required String title,
    required String body,
    String? slotId,
  }) async {
    if (userIds.isEmpty) return;
    await _db.from('notifications').insert([
      for (final id in userIds)
        {
          'user_id': id,
          'kind': kind,
          'title': title,
          'body': body,
          if (slotId != null) 'slot_id': slotId,
        },
    ]);
  }

  // ---------------------------------------------------------------------
  // Student notes (trainer-private)
  // ---------------------------------------------------------------------

  Future<List<StudentNote>> fetchStudentNotes(String riderId) async {
    final rows = await _db
        .from('student_notes')
        .select()
        .eq('rider_id', riderId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => StudentNote.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> addStudentNote({
    required String trainerId,
    required String riderId,
    required String body,
    String? slotId,
    String? phase,
  }) async {
    await _db.from('student_notes').insert({
      'trainer_id': trainerId,
      'rider_id': riderId,
      'body': body,
      if (slotId != null) 'slot_id': slotId,
      if (phase != null) 'phase': phase,
    });
  }

  Future<void> deleteStudentNote(String id) async {
    await _db.from('student_notes').delete().eq('id', id);
  }

  // ---------------------------------------------------------------------
  // Feature requests (open board — every signed-in user can post/vote)
  // ---------------------------------------------------------------------

  Future<List<FeatureRequest>> fetchFeatureRequests() async {
    final rows = await _db
        .from('feature_requests')
        .select('*, author:profiles!feature_requests_author_id_fkey(full_name)')
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => FeatureRequest.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> createFeatureRequest({
    required String authorId,
    required String title,
    String? description,
  }) async {
    await _db.from('feature_requests').insert({
      'author_id': authorId,
      'title': title,
      'description': ?description,
    });
  }

  Future<void> deleteFeatureRequest(String id) async {
    await _db.from('feature_requests').delete().eq('id', id);
  }

  /// Every vote on every request — a small dataset, cheap to aggregate client-side.
  Future<List<Map<String, dynamic>>> fetchFeatureVotes() async {
    final rows = await _db
        .from('feature_votes')
        .select('request_id, user_id, value');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> setFeatureVote({
    required String requestId,
    required String userId,
    required int value,
  }) async {
    await _db.from('feature_votes').upsert({
      'request_id': requestId,
      'user_id': userId,
      'value': value,
    }, onConflict: 'request_id,user_id');
  }

  Future<void> clearFeatureVote({
    required String requestId,
    required String userId,
  }) async {
    await _db
        .from('feature_votes')
        .delete()
        .eq('request_id', requestId)
        .eq('user_id', userId);
  }

  // ---------------------------------------------------------------------
  // Realtime
  // ---------------------------------------------------------------------

  /// Subscribes to every change on [table] and calls [onChange] afterwards
  /// so callers can simply re-run their normal (joined) select query rather
  /// than trying to keep a hand-rolled local cache in sync row by row.
  RealtimeChannel watchTable(
    String table, {
    required String channelName,
    required void Function() onChange,
  }) {
    final channel = _db.channel(channelName);
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: table,
      callback: (payload) => onChange(),
    );
    channel.subscribe();
    return channel;
  }
}
