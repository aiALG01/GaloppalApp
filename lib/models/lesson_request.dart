import 'lesson_slot.dart' show normalizeTime, addMinutesToTime;

/// A rider proposing a lesson time their trainer hasn't published. Approving
/// one turns it into a real [LessonSlot] (see `approve_lesson_request` in
/// supabase/schema.sql).
class LessonRequest {
  const LessonRequest({
    required this.id,
    required this.trainerId,
    required this.riderId,
    required this.date,
    required this.time,
    required this.durationMinutes,
    required this.status,
    this.note,
    this.resultingSlotId,
    this.riderName,
    this.trainerName,
  });

  final String id;
  final String trainerId;
  final String riderId;
  final DateTime date; // date-only, local
  final String time; // "HH:mm"
  final int durationMinutes;
  final String status; // 'pending' | 'approved' | 'declined'
  final String? note;
  final String? resultingSlotId;
  final String? riderName;
  final String? trainerName;

  bool get isPending => status == 'pending';
  String get endTime => addMinutesToTime(time, durationMinutes);

  factory LessonRequest.fromMap(Map<String, dynamic> map) {
    final rider = map['rider'] as Map<String, dynamic>?;
    final trainer = map['trainer'] as Map<String, dynamic>?;
    return LessonRequest(
      id: map['id'] as String,
      trainerId: map['trainer_id'] as String,
      riderId: map['rider_id'] as String,
      date: DateTime.parse(map['requested_date'] as String),
      time: normalizeTime(map['requested_time'] as String),
      durationMinutes: (map['duration_minutes'] as num).toInt(),
      status: map['status'] as String,
      note: map['note'] as String?,
      resultingSlotId: map['resulting_slot_id'] as String?,
      riderName: rider?['full_name'] as String?,
      trainerName: trainer?['full_name'] as String?,
    );
  }
}
