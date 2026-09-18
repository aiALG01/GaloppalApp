import '../models/lesson_slot.dart' show addMinutesToTime;

const List<String> kSlotDurations = ['30', '45', '60'];
const List<String> kSlotRepeats = ['Einmalig', 'Wöchentlich', '14-tägig'];
const List<String> kSlotCounts = ['4', '8', '12'];

/// Placeholder values still written to the (now hidden) `discipline` /
/// `location_kind` columns so old rows and any future re-activation keep a
/// sane default. The pickers for these were removed from the UI.
const String kDefaultDiscipline = 'Dressur';
const String kDefaultLocationKind = 'Reithalle';

enum SlotFormMode {
  /// One lesson at a fixed start time (optionally repeating weekly/biweekly).
  single,

  /// Several back-to-back lessons of [SlotFormState.duration] each, filling
  /// a time span on the selected day (e.g. 14:00–18:00 in 1h blocks).
  range,
}

String slotModeToString(SlotFormMode m) =>
    m == SlotFormMode.range ? 'range' : 'single';

SlotFormMode slotModeFromString(String? s) =>
    s == 'range' ? SlotFormMode.range : SlotFormMode.single;

/// Mutable draft backing the "Buchbare Stunde" bottom sheet. Mirrors the
/// prototype's `form` state object.
class SlotFormState {
  SlotFormState({
    this.mode = SlotFormMode.single,
    this.time = '09:00',
    this.rangeStart = '14:00',
    this.rangeEnd = '18:00',
    this.duration = '45',
    this.capacity = 3,
    this.away = false,
    this.awayFacility = '',
    this.repeat = 'Einmalig',
    this.count = '4',
  });

  SlotFormMode mode;
  String time;
  String rangeStart;
  String rangeEnd;
  String duration;
  int capacity;
  bool away;
  String awayFacility;
  String repeat;
  String count;

  bool get isRange => mode == SlotFormMode.range;
  bool get isRepeating => repeat != 'Einmalig';
  int get repeatCount => isRepeating ? int.parse(count) : 1;
  int get repeatStepDays => repeat == '14-tägig' ? 14 : 7;

  /// Back-to-back start times between [rangeStart] and [rangeEnd], each
  /// [duration] minutes long. Empty if nothing fits (end before/equal start,
  /// or the span is shorter than one lesson).
  List<String> get rangeStartTimes {
    final durationMinutes = int.parse(duration);
    final starts = <String>[];
    var t = rangeStart;
    while (true) {
      final lessonEnd = addMinutesToTime(t, durationMinutes);
      if (lessonEnd.compareTo(rangeEnd) > 0) break;
      starts.add(t);
      t = lessonEnd;
    }
    return starts;
  }

  /// Reapplies the given trainer defaults (used when opening a fresh form).
  SlotFormState reset({
    SlotFormMode mode = SlotFormMode.single,
    String duration = '45',
    String repeat = 'Einmalig',
  }) {
    this.mode = mode;
    time = '09:00';
    rangeStart = '14:00';
    rangeEnd = '18:00';
    this.duration = kSlotDurations.contains(duration) ? duration : '45';
    capacity = 3;
    away = false;
    awayFacility = '';
    this.repeat = kSlotRepeats.contains(repeat) ? repeat : 'Einmalig';
    count = '4';
    return this;
  }
}
