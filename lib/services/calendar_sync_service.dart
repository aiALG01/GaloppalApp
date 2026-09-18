import 'dart:convert';

import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One lesson to reconcile against the device calendar.
class CalendarSyncItem {
  const CalendarSyncItem({
    required this.key,
    required this.title,
    required this.start,
    required this.end,
    this.location,
  });

  /// Stable id (the lesson slot id) used to find/update/delete the matching
  /// device event across syncs.
  final String key;
  final String title;
  final DateTime start;
  final DateTime end;
  final String? location;
}

/// An existing device-calendar appointment that overlaps a time being
/// scheduled in the app (a personal event, not one this app created).
class DeviceBusyBlock {
  const DeviceBusyBlock({
    required this.title,
    required this.start,
    required this.end,
    this.allDay = false,
  });

  final String title;
  final DateTime start;
  final DateTime end;

  /// All-day entries are surfaced only as a soft hint ("Du hast an dem Tag
  /// einen ganztägigen Termin: …"), never as a hard scheduling conflict.
  final bool allDay;

  bool overlaps(DateTime otherStart, DateTime otherEnd) =>
      start.isBefore(otherEnd) && otherStart.isBefore(end);
}

/// Writes lesson slots into a dedicated "Galoppal" calendar on the device
/// (Apple Calendar on iOS, the device's calendar provider — commonly backed
/// by a synced Google account — on Android). One-way: app -> device.
class CalendarSyncService {
  final DeviceCalendarPlugin _plugin = DeviceCalendarPlugin();

  static const _calendarIdPrefsKey = 'calendar_sync_calendar_id';
  static const _eventMapPrefsKey = 'calendar_sync_event_map';
  static const _calendarName = 'Galoppal';

  Future<bool> requestPermissions() async {
    final existing = await _plugin.hasPermissions();
    if (existing.isSuccess && existing.data == true) return true;
    final requested = await _plugin.requestPermissions();
    return requested.isSuccess && requested.data == true;
  }

  Future<String?> _ensureCalendar() async {
    final prefs = await SharedPreferences.getInstance();
    final calendarsResult = await _plugin.retrieveCalendars();
    final calendars = calendarsResult.data ?? [];

    final existingId = prefs.getString(_calendarIdPrefsKey);
    if (existingId != null && calendars.any((c) => c.id == existingId)) {
      return existingId;
    }

    final byName = calendars.where(
      (c) => c.name == _calendarName && c.isReadOnly != true,
    );
    if (byName.isNotEmpty) {
      final id = byName.first.id!;
      await prefs.setString(_calendarIdPrefsKey, id);
      return id;
    }

    final created = await _plugin.createCalendar(
      _calendarName,
      calendarColor: const Color(0xFF3E5C4E),
      localAccountName: _calendarName,
    );
    if (!created.isSuccess || created.data == null) return null;
    await prefs.setString(_calendarIdPrefsKey, created.data!);
    return created.data;
  }

  Future<Map<String, String>> _loadEventMap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_eventMapPrefsKey);
    if (raw == null) return {};
    return (jsonDecode(raw) as Map).cast<String, String>();
  }

  Future<void> _saveEventMap(Map<String, String> map) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_eventMapPrefsKey, jsonEncode(map));
  }

  /// Reconciles the device calendar so it holds exactly [items]: creates
  /// missing events, updates changed ones, and deletes device events for
  /// lessons no longer in [items] (canceled, unbooked, or past).
  Future<void> sync(List<CalendarSyncItem> items) async {
    final calendarId = await _ensureCalendar();
    if (calendarId == null) return;

    final eventMap = await _loadEventMap();
    final seenKeys = <String>{};

    for (final item in items) {
      seenKeys.add(item.key);
      final event = Event(
        calendarId,
        eventId: eventMap[item.key],
        title: item.title,
        start: item.start,
        end: item.end,
      )..location = item.location;
      final result = await _plugin.createOrUpdateEvent(event);
      final newEventId = result?.data;
      if (result?.isSuccess == true && newEventId != null) {
        eventMap[item.key] = newEventId;
      }
    }

    final staleKeys = eventMap.keys
        .where((k) => !seenKeys.contains(k))
        .toList();
    for (final key in staleKeys) {
      await _plugin.deleteEvent(calendarId, eventMap[key]);
      eventMap.remove(key);
    }

    await _saveEventMap(eventMap);
  }

  /// True for calendars we don't want all-day entries from — holiday
  /// subscriptions and the birthdays calendar would otherwise flag a "soft
  /// conflict" on basically every day. Timed events from these are still
  /// read (rare, but real).
  static bool _skipAllDayFrom(Calendar c) {
    final type = (c.accountType ?? '').toLowerCase();
    return c.isReadOnly == true ||
        type.contains('birthday') ||
        type.contains('subscri') ||
        type.contains('holiday');
  }

  /// Reads every *other* device calendar (i.e. the user's normal personal
  /// calendar, not the "Galoppal" one this app writes to) for events
  /// overlapping [day], so the app can warn about or skip double-bookings.
  /// Timed events become hard conflicts; all-day events from personal
  /// calendars come back flagged [DeviceBusyBlock.allDay] for a soft hint.
  Future<List<DeviceBusyBlock>> fetchBusyBlocks(DateTime day) async {
    final granted = await requestPermissions();
    debugPrint('[CalendarSync] permission granted: $granted');
    if (!granted) return [];

    final calendarsResult = await _plugin.retrieveCalendars();
    debugPrint(
      '[CalendarSync] retrieveCalendars isSuccess=${calendarsResult.isSuccess} '
      'errors=${calendarsResult.errors.map((e) => e.errorMessage).toList()} '
      'names=${calendarsResult.data?.map((c) => '${c.name} (${c.accountType})').toList()}',
    );
    final calendars = (calendarsResult.data ?? []).where(
      (c) => c.name != _calendarName && c.id != null,
    );

    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final blocks = <DeviceBusyBlock>[];
    for (final calendar in calendars) {
      final result = await _plugin.retrieveEvents(
        calendar.id,
        RetrieveEventsParams(startDate: dayStart, endDate: dayEnd),
      );
      // `retrieveEvents` hands back a *lazy* map iterable, so materialise it
      // here (inside the try) — a parse error on one event then can't escape
      // as a swallowed exception that silently empties the whole result.
      final events = (result.data ?? const <Event>[]).toList();
      debugPrint(
        '[CalendarSync] retrieveEvents(${calendar.name}) isSuccess=${result.isSuccess} '
        'errors=${result.errors.map((e) => e.errorMessage).toList()} count=${events.length}',
      );
      final skipAllDay = _skipAllDayFrom(calendar);
      for (final event in events) {
        if (event.start == null || event.end == null) continue;
        final isAllDay = event.allDay == true;
        if (isAllDay && skipAllDay) continue;
        blocks.add(
          DeviceBusyBlock(
            title: event.title ?? 'Termin',
            start: isAllDay ? dayStart : event.start!,
            end: isAllDay ? dayEnd : event.end!,
            allDay: isAllDay,
          ),
        );
      }
    }
    blocks.sort((a, b) => a.start.compareTo(b.start));
    debugPrint(
      '[CalendarSync] fetchBusyBlocks(${day.toIso8601String()}) -> ${blocks.length} block(s)',
    );
    return blocks;
  }

  /// Removes every event this app has created, for when the user turns sync
  /// off. Leaves the "Galoppal" calendar itself in place (harmless, and
  /// avoids re-prompting for calendar choice if they turn sync back on).
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    final calendarId = prefs.getString(_calendarIdPrefsKey);
    final eventMap = await _loadEventMap();
    if (calendarId != null) {
      for (final eventId in eventMap.values) {
        await _plugin.deleteEvent(calendarId, eventId);
      }
    }
    await prefs.remove(_eventMapPrefsKey);
  }
}
