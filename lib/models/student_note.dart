/// A private trainer note about a rider — either general (no [slotId]) or
/// tied to one lesson, written before or after it. Append-only: [createdAt]
/// is always the true write date since notes can't be edited, only deleted.
class StudentNote {
  const StudentNote({
    required this.id,
    required this.trainerId,
    required this.riderId,
    required this.body,
    required this.createdAt,
    this.slotId,
    this.phase,
  });

  final String id;
  final String trainerId;
  final String riderId;
  final String body;
  final DateTime createdAt;
  final String? slotId;
  final String? phase; // 'before' | 'after' | null (general note)

  bool get isGeneral => slotId == null;

  factory StudentNote.fromMap(Map<String, dynamic> map) {
    return StudentNote(
      id: map['id'] as String,
      trainerId: map['trainer_id'] as String,
      riderId: map['rider_id'] as String,
      body: map['body'] as String,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      slotId: map['slot_id'] as String?,
      phase: map['phase'] as String?,
    );
  }
}
