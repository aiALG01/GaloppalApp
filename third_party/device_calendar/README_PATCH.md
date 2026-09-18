# Local patch: device_calendar 3.9.0

Vendored copy of `device_calendar` 3.9.0 with two fixes applied, used via a
`dependency_overrides: device_calendar: {path: ...}` entry in the app's
`pubspec.yaml`.

---

## Patch 1 — iOS 17+ permission check

### Why

Upstream's iOS permission check only recognizes the legacy
`EKAuthorizationStatus.authorized` case:

```swift
private func hasEventPermissions() -> Bool {
    let status = EKEventStore.authorizationStatus(for: .event)
    return status == EKAuthorizationStatus.authorized
}
```

On iOS 17+, a user granting full calendar access makes
`authorizationStatus(for: .event)` report `.fullAccess`, not `.authorized`.
Every call gated by this check (`retrieveCalendars`, `retrieveEvents`,
`createOrUpdateEvent`, `deleteEvent`, ...) then silently fails as
"unauthorized" even though access was actually granted — the Dart-side call
just comes back with empty/null data, no visible error.

`createCalendar` happens to skip this gate entirely, which is why writing a
new calendar (and the first event that triggers its creation) can appear to
work while reading events from other calendars does not.

### The fix

`ios/Classes/SwiftDeviceCalendarPlugin.swift`, `hasEventPermissions()`: on
iOS 17+, check for `.fullAccess` instead of `.authorized`.

---

## Patch 2 — null `availability` crashes `Event.fromJson`

### Why

`retrieveEvents` builds its result as a *lazy* `.map(Event.fromJson)`
iterable, so `result.data.length` reports a count without ever parsing an
event — the parse only happens when the caller iterates. `Event.fromJson`
then calls `parseStringToAvailability(String value)` with a **non-nullable**
parameter.

iOS "local" calendars (including the Simulator's default *Calendar*) don't
support availability, so the native side sends `null` for that field. The
non-nullable signature throws `TypeError: Null is not a subtype of String`
*mid-iteration in the caller's loop* — where it's easily swallowed by a
surrounding `catch`, leaving the event list silently empty and no visible
error. This made the whole "personal calendar conflict" feature a no-op on
the Simulator and on any account whose events sit in a local calendar.

### The fix

`lib/src/models/event.dart`: `parseStringToAvailability` now takes a
`String?` and its existing `switch` returns `null` for an unmatched/null
value. `Event.fromJson` passes `json['availability'] as String?`.

(The app also defensively `.toList()`s the lazy iterable in
`CalendarSyncService.fetchBusyBlocks` so any future per-event parse error
can't escape as a swallowed exception.)

---

## Removing these patches

Once upstream ships fixes (track
https://github.com/builttoroam/device_calendar), delete this directory,
remove the `dependency_overrides` entry in the app's `pubspec.yaml`, and run
`flutter pub get`.
