# Live Location Tracking — Design + Test Plan

**Date:** 2026-08-26
**Branch:** `feat/salesmax-phase-a`
**Author:** Claude (mobile + Frappe)
**Goal:** A manager can see where any of their direct/transitive reportees are
right now, and view today's trail — with the tracked user opted in and aware.

---

## 1. Product spec (crisp)

- **Who is tracked:** any Employee whose home-screen toggle is ON. Defaults to OFF.
- **Who sees whom:** a manager sees an employee iff `Employee.reports_to`
  (direct OR transitive) resolves to the manager. System Manager sees all.
- **When it pings:** every N minutes while the app is alive OR in background
  (foreground service running). Default N = **1 min** (user-locked 2026-08-26).
  Also on significant movement (>20 m) between the timers.
- **What is stored:** `sales_person` (actually Employee.name), lat, lng,
  accuracy_m, speed_mps, battery_level, recorded_at.
- **Retention:** pings older than 30 days deleted by daily scheduler.
- **Privacy guardrails:**
  - Persistent notification while tracking is on ("TCB Portal is sharing your
    location with your manager").
  - Home banner reminder if tracking has been on for >8 h continuously.
  - Tracked user can turn it OFF anytime; the foreground service stops
    immediately and no more pings upload.
  - Managers cannot access pings from before tracking was enabled.

## 2. Data model (ERPNext-native, custom app only)

DocType `TCB Location Ping` in `tcb_portal_erp` module `location_tracking`:

| Fieldname | Type | Description |
|---|---|---|
| `employee` | Link (Employee) | The person the ping belongs to. Index. |
| `user` | Data (fetch from employee.user_id) | Redundant for fast filtering. |
| `latitude` | Float, precision 8 | |
| `longitude` | Float, precision 8 | |
| `accuracy_m` | Float | Reported by native fused-location provider. |
| `speed_mps` | Float | Optional; 0 when unknown. |
| `battery_level` | Int | 0-100. Optional. |
| `recorded_at` | Datetime | Device clock. Index. |
| `source` | Select | `auto` / `manual` |

Naming: hash naming (default). No child tables.

Indexes: `(employee, recorded_at DESC)` for "latest ping per person"
lookups; `(recorded_at)` for retention purge.

Employee custom field (via `custom_fields` fixture): none required.
Tracking-on is a runtime state — no DocType field — see `TCB Tracking Session`.

DocType `TCB Tracking Session` — represents "user X has tracking currently
enabled from ts A to (possibly ongoing) ts B":

| Fieldname | Type | |
|---|---|---|
| `employee` | Link | |
| `started_at` | Datetime | |
| `ended_at` | Datetime, optional | Null while active. |
| `end_reason` | Select | `user_off` / `app_uninstalled` / `session_timeout` / `admin_off` |

Rules:
- Enabling tracking closes any prior open session (auto `ended_at = now()`,
  `end_reason = "session_timeout"`) and opens a new one.
- Disabling tracking sets `ended_at = now()` on the current session.
- Managers can only see pings where `recorded_at` falls INSIDE a Tracking
  Session (i.e. before this cutoff, no visibility).

## 3. Backend endpoints (`tcb_portal_erp.api.location_tracking`)

All `@frappe.whitelist()`, session-authenticated. No `ignore_permissions`.

### 3.1 Own-tracking control

- `set_tracking_enabled(enabled: bool)`
  - Opens/closes Tracking Session for `frappe.session.user`'s Employee.
  - Returns `{enabled: bool, session_id, started_at}`.
- `get_tracking_status()`
  - Returns `{enabled, session_id, started_at, last_ping_at, minutes_running}`.

### 3.2 Own-tracking data upload

- `record_ping(latitude, longitude, accuracy_m=None, speed_mps=None, battery_level=None, recorded_at=None, source="auto")`
  - Only own user's Employee. Silently ignores if user has no active
    Tracking Session (server-enforced).
  - Rate-limited: 30/min per user.
  - Returns `{ok: true, ping_id, stored_at}`.
- `record_pings_batch(pings: list)`
  - Batched variant; caps 20 per call. Same rules.

### 3.3 Manager-side viewing

- `my_team_live()`
  - Returns list of direct + transitive reportees who ever had tracking on,
    with their last ping:
    `[{employee, employee_name, image, latitude, longitude, minutes_ago, status: online|stale|offline, tracking_enabled: bool}, …]`
  - `online` = last ping ≤ 5 min ago; `stale` = 5-30 min; `offline` = >30 min or no session.
- `person_current(employee)`
  - `{employee_name, tracking_enabled, latest_ping: {…}, session_started_at}`.
  - 403 if `employee` is not a reportee AND caller ≠ System Manager.
- `person_trail(employee, from_ts, to_ts)`
  - List of pings in the window. Same reportee gate.
  - Optional `simplify_m` for polyline downsampling (Ramer-Douglas-Peucker).

### 3.4 Hierarchy helper

- `_is_reportee(manager_employee, target_employee)` (internal)
  - Walks `Employee.reports_to` up to 8 hops. Returns bool.
- `_my_reportees()` (internal)
  - BFS over `Employee.reports_to`, cached in `frappe.local` for the request.

## 4. Permissions

Standard DocPerm:
- `TCB Location Ping`: read/write to System Manager. All other roles read
  through the API which enforces the reportee check itself.
- `TCB Tracking Session`: same.

The API path (not DocPerm) is the primary permission boundary because
"read all my reportees' pings" is a graph query, not a row-level check.

## 5. Retention

Scheduled hook (`scheduler_events.daily`):
- Delete `TCB Location Ping` where `recorded_at < now() - 30 days`.
- Delete closed `TCB Tracking Session` where `ended_at < now() - 90 days`.

## 6. Mobile client

### 6.1 Native (Kotlin foreground service)

New file: `LocationTrackingService.kt` (foreground service, sticky).
- Uses `FusedLocationProviderClient` with `LocationRequest.Builder`:
  interval = 180_000 ms (3 min), min-distance = 50 m, priority BALANCED.
- Persistent notification (channel `location_tracking`, LOW importance)
  with title "TCB Portal: sharing your location with your manager" and
  a "Turn off" action.
- On each location callback, calls back to Flutter via method channel
  `tcb_portal/location_tracking` method `onLocationUpdate` with
  `{lat, lng, accuracy, speed, battery, timestamp}`.

Manifest additions:
- `<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>`
- `<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/>`
- `<service android:name=".location.LocationTrackingService"
     android:foregroundServiceType="location" android:exported="false"/>`
- `targetSdk` stays at current.

### 6.2 Dart

New feature folder `lib/features/location_tracking/`:

- `domain/models.dart` — `LocationPing`, `TeamLivePerson`, `TrackingStatus`,
  `TrailPoint`.
- `data/location_tracking_repository.dart` — Dio wrapper for the 6 API
  endpoints.
- `application/location_tracking_controller.dart` — Riverpod:
  - `trackingStatusProvider` (FutureProvider)
  - `teamLiveProvider` (FutureProvider.autoDispose, refresh every 60 s)
  - `personCurrentProvider(family)`
  - `personTrailProvider(family)`
  - `LocationBridge` (start/stop native service + relay pings to `record_ping`).
- `presentation/`:
  - `tracking_toggle_card.dart` — Home + Profile widget. Toggle, "Sharing
    since" timestamp, "Turn off" CTA.
  - `team_live_map_screen.dart` — Manager's map (`flutter_map` + OSM tiles).
    Pins per online/stale/offline reportee. Tap → person detail.
  - `person_location_screen.dart` — Current position + today's trail polyline.
    Refresh + share-my-location gate.

Home wiring:
- Show "My tracking" toggle card if the current Employee has any manager
  above (reports_to is set OR reverse-lookup finds them as someone's report).
  Wrap in `sees_sales` cap? No — this feature is not sales-only; gate on
  "user is an Employee".
- Show "Field team" CTA card in the `manager_view` section, opens Team Live map.

Deps to add:
- `flutter_map: ^7.0.0`
- `latlong2: ^0.9.0`

## 7. Test sheet — verified in-order before ship

Every row must be GREEN before commit + push. If any row goes RED,
stop and fix at the same layer before touching later rows.

| # | Area | Test | How | Expected | Actual |
|---|---|---|---|---|---|
| B1 | DocType | Create `TCB Location Ping` row | bench-execute insert | Row exists, hash-named | |
| B2 | Own upload | `record_ping` w/ no active session | HTTPS as Karishma | ignored (or friendly error) | |
| B3 | Own upload | `set_tracking_enabled(true)` then `record_ping` | HTTPS as Karishma | ping stored, id returned | |
| B4 | Own upload | `record_ping` from unauth caller | HTTPS no cookie | 403 | |
| B5 | Rate limit | 40 pings in 60 s | HTTPS burst | first 30 ok, rest 429 | |
| B6 | Retention | Insert ping 40 d old, run purge fn | bench-execute | row deleted | |
| B7 | Hierarchy | `_is_reportee` returns True for direct report | bench-execute | True | |
| B8 | Hierarchy | Same for transitive (2-hop) | bench-execute | True | |
| B9 | Hierarchy | False for random employee | bench-execute | False | |
| B10 | Manager view | `my_team_live()` returns Ajay for Ajay's manager | HTTPS | includes Ajay | |
| B11 | Manager view | `person_current(Ajay)` when caller is NOT Ajay's manager | HTTPS | 403 | |
| B12 | Trail | `person_trail(Ajay, today)` before tracking session started | HTTPS | empty (no leak) | |
| B13 | Session | 2nd `set_tracking_enabled(true)` closes 1st + opens 2nd | HTTPS | ended_at set on 1st | |
| N1 | Native | Start foreground service | tap toggle | notification appears | |
| N2 | Native | Kill app | swipe from recents | notification persists, service alive | |
| N3 | Native | onLocationUpdate fires at 3-min interval | wait 6 min | ≥1 ping uploaded | |
| N4 | Native | User taps "Turn off" from notif | tap | service stops, notif gone | |
| N5 | Native | Perm denied (background) | deny prompt | toggle stays off, in-app snackbar | |
| C1 | Client | Toggle card shows "Sharing since X" | after enable | timestamp correct | |
| C2 | Client | Team live map shows all reportees | as Aditya's manager | pins visible | |
| C3 | Client | Pin colour reflects online/stale/offline | wait 6 min | pin flips green→orange→grey | |
| C4 | Client | Tap pin → person detail | tap | trail polyline renders | |
| C5 | Client | Non-manager cannot open Field Team from Home | as Karishma (no reports) | CTA hidden | |
| C6 | Client | Refresh (pull-down) invalidates providers | pull | teamLiveProvider refetches | |
| C7 | Client | Persistent notif reminder after 8 h | leave on 8h | banner shown on Home | |
| E1 | E2E | Walk 200 m with tracking on | real walk | trail shows movement | |
| E2 | E2E | Manager on 2nd device sees the walk | 2 devices | new pings appear in ≤60 s | |

## 8. Rollout order

1. Backend DocTypes + endpoints + all B* tests GREEN.
2. Native FGS + manifest + N* tests GREEN.
3. Flutter repo/controller/toggle + C1-C7 GREEN.
4. E2E on device (E1, E2) after user hands me the phone.
5. Commit both repos with recommended message. Push. Update memory.

## 9. Deliberate NON-goals (out of scope for this pass)

- iOS support. iOS 15+ background location requires "Always" permission
  which triggers Apple review scrutiny; not needed for the Realme demo.
  A follow-up ticket will handle iOS.
- Geofencing (arrive/leave events).
- Turn-by-turn navigation.
- Multi-tenant SaaS notes: tenant isolation is already enforced by every
  endpoint reading `frappe.session.user`; no new tenancy code needed.

---

**When every row of the test sheet is GREEN and no issue is unresolved,
we ship.**
