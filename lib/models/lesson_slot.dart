/// A single rider's reservation inside a [LessonSlot], as returned by the
/// `bookings` table joined with the rider's `full_name`.
class SlotBooking {
  const SlotBooking({
    required this.id,
    required this.riderId,
    required this.riderName,
  });

  final String id;
  final String riderId;
  final String riderName;

  factory SlotBooking.fromMap(Map<String, dynamic> map) {
    final rider = map['rider'] as Map<String, dynamic>?;
    return SlotBooking(
      id: map['id'] as String,
      riderId: map['rider_id'] as String,
      riderName: rider?['full_name'] as String? ?? '',
    );
  }
}

class LessonSlot {
  const LessonSlot({
    required this.id,
    required this.trainerId,
    required this.date,
    required this.startTime,
    required this.durationMinutes,
    required this.facility,
    required this.capacity,
    required this.status,
    this.seriesId,
    this.bookings = const [],
    this.cancelReason,
  });

  final String id;
  final String trainerId;
  final DateTime date; // date-only, local
  final String startTime; // "HH:mm"
  final int durationMinutes;
  final String facility;
  final int capacity;
  final String status; // 'open' | 'canceled'
  final String? seriesId;
  final List<SlotBooking> bookings;
  final String? cancelReason;

  bool get isCanceled => status == 'canceled';
  bool get isFull => !isCanceled && bookings.length >= capacity;
  bool get isOpen => !isCanceled && !isFull;
  int get freeSeats => (capacity - bookings.length).clamp(0, capacity);
  bool get isSeries => seriesId != null;

  String get endTime => addMinutesToTime(startTime, durationMinutes);

  /// [date] + [startTime] combined into one local [DateTime].
  DateTime get startDateTime {
    final parts = startTime.split(':');
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  bool bookedByRider(String riderId) =>
      bookings.any((b) => b.riderId == riderId);

  /// Where the lesson takes place — the home facility name, or the away
  /// facility if it differs.
  String placeLabel(String homeFacility) => facility;

  factory LessonSlot.fromMap(Map<String, dynamic> map) {
    final bookingsRaw = (map['bookings'] as List?) ?? const [];
    return LessonSlot(
      id: map['id'] as String,
      trainerId: map['trainer_id'] as String,
      date: DateTime.parse(map['lesson_date'] as String),
      startTime: normalizeTime(map['start_time'] as String),
      durationMinutes: (map['duration_minutes'] as num).toInt(),
      facility: map['facility'] as String,
      capacity: (map['capacity'] as num).toInt(),
      status: map['status'] as String,
      seriesId: map['series_id'] as String?,
      bookings: bookingsRaw
          .map((b) => SlotBooking.fromMap(b as Map<String, dynamic>))
          .toList(),
      cancelReason: map['cancel_reason'] as String?,
    );
  }
}

/// Postgres `time` columns come back as "HH:mm:ss" — trim to "HH:mm".
String normalizeTime(String raw) => raw.length >= 5 ? raw.substring(0, 5) : raw;

String addMinutesToTime(String start, int minutes) {
  final parts = start.split(':');
  final h = int.parse(parts[0]);
  final m = int.parse(parts[1]);
  final total = h * 60 + m + minutes;
  final nh = (total ~/ 60) % 24;
  final nm = total % 60;
  return '${nh.toString().padLeft(2, '0')}:${nm.toString().padLeft(2, '0')}';
}
