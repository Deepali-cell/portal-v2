# TCB Portal — Handoff (2026-05-30)

Last working session: **2026-05-30 (evening)**. The user is pausing and will resume the next session. Pick up from here.

## GitHub

- Mobile app (this repo): **`tcbinfotechpvtltd/tcb_portal_app`** — https://github.com/tcbinfotechpvtltd/tcb_portal_app
- ERPNext custom app: **`tcbinfotechpvtltd/tcb_portal_erp`** (renamed from `office_tcb`) — https://github.com/tcbinfotechpvtltd/tcb_portal_erp

> **✅ Repo correction completed 2026-06-02.**
> `tcb_portal_erp` GitHub repo has been force-replaced with a brand-new standalone Frappe custom app `tcb_portal_erp` containing only the mobile-app dependencies (everything previously listed below). The old `tcb_inside` Frappe app stays on the bench for TCB's internal accounts/HR/projects/purchase customisations. The two apps coexist on `tcb.local`. Mobile endpoint paths were bulk-renamed from `tcb_inside.api.*` → `tcb_portal_erp.api.*` in [api_paths.dart](lib/core/network/api_paths.dart) (71 changes).
>
> **⚠️ Previously planned (now done) — repo correction.**
> Earlier session pushed the entire `tcb_inside` Frappe app (which also contains TCB's internal `accounts_customizations`, `hr_customizations` (beyond the geofence DocType), `projects_customizations`, `purchase_customizations`, invoice approval workflow, recurring invoice templates, etc.). That's TCB's private internal customisations and should not be in the SaaS-rebranded mobile-companion repo.
>
> **What the repo should contain** (only the mobile-app dependencies):
> - A standalone Frappe custom app — proposal: **app name `tcb_portal_api`** (since the GitHub repo is already `tcb_portal_erp`, the *app* needs a single-word snake_case name distinct from the repo).
> - `<app>/api/` — exactly the modules under `tcb_inside.api.*` today: `auth, attendance, leave, expense, payslip, task, timesheet, leads, deals, directory, invoices, notifications` + the CRM-collab set (`notes, crm_tasks, comments, attachments, assignments, crm_calls, emails, events, timeline`).
> - `<app>/doctype/tcb_device_token/` — FCM/APNs token registration.
> - `<app>/doctype/tcb_office_location/` — geofence reference data (move here from `hr_customizations`).
> - `hooks.py` — only the entries the mobile depends on: `doc_events["Notification Log"]["after_insert"] = "<app>.api.notifications.on_notification_log"`. Nothing else.
>
> **Tomorrow's plan, concrete steps:**
> 1. `bench new-app tcb_portal_api` (or whatever app name we settle on — confirm with user).
> 2. Copy the relevant files out of `apps/tcb_inside/tcb_inside/api/` into the new app's `api/` dir. Copy `tcb_device_token` and `tcb_office_location` DocTypes too.
> 3. Bulk-rename every `tcb_inside.api.` → `<new_app>.api.` inside the new app's files. Bulk-rename every `tcb_inside.api.` → `<new_app>.api.` in the mobile app's `lib/core/network/api_paths.dart`.
> 4. Leave `tcb_inside` alone on the bench — TCB's existing customisations keep running from there. The two apps will coexist (both installed on `tcb.local`); the mobile API endpoints just move to the new namespace.
> 5. **Force-reset the `tcb_portal_erp` repo on GitHub.** Either delete and recreate, or `git push --force` an orphan branch over `main`. The current commit on the repo (sha after the rename) is wrong content and should not be in history.
> 6. Push the new clean app to `tcb_portal_erp`.
> 7. Re-test on the sim — should still work because the endpoint payloads are identical, only the dotted path changes.
>
> The `tcb_inside` repo (the existing TCB internal app) stays on its own; it does NOT need its own GitHub repo unless TCB wants to back it up — confirm with the user.

The Frappe app inside `tcb_portal_erp` *should* (after tomorrow's correction) be a brand-new app like `tcb_portal_api`, not `tcb_inside`. Today the repo wrongly contains `tcb_inside` in full — fix first thing tomorrow.

---

## Session-2 update (2026-05-30 evening) — what shipped after the morning session

The morning session's notes start lower at "## What is built (live in the app today)" — those are still accurate. This block describes everything added on top.

### Shipped

✅ **Timesheet → start/stop timer (item #4 from morning backlog).** Native ERPNext flow — a Timesheet Detail row with `from_time` set + `to_time` empty IS the running timer; no custom doctype. Endpoints `start_timer(activity_type, project, task)`, `stop_timer(description)`, `get_active_timer()`, `get_project_tasks(project)`. `get_context` returns `active_timer` so the running chip persists across launches and devices. UX: Start sheet picks Activity → Project → Task → Start; running timer shows as a navy card on the Timesheet screen and as a thin strip above the bottom nav on every screen (1-second tick); tap either → Stop sheet → description (mandatory, ≥4 chars) → Stop. ERPNext computes hours on save. Old manual `_LogSheet` removed.

✅ **Date-range filters on Expenses and Payroll (item #7).** Extracted `_RangeBar` from Timesheet into `lib/shared/widgets/date_range_bar.dart` — now powers all three screens. Backend: `expense.get_context` filters by `posting_date BETWEEN`; `payslip.get_list` filters by overlap (`start_date ≤ to_date AND end_date ≥ from_date`). Payroll's old "Year to date" card renamed to **Period total** and reflects the filtered window.

✅ **Invoice creation (#6, first half).** New endpoints `search_customers / search_suppliers / search_items / create_sales_invoice / create_purchase_invoice`. Permissions enforced (no `ignore_permissions`). The new invoice sheet has typeahead party picker, dates, items rows with item picker + qty + rate + auto-amount, and **two buttons: Save (Draft) + Save & Submit**. Capability flags `can_create_sales` / `can_create_purchase` on the get_context response so the FAB hides when the user lacks create permission.

✅ **Invoice detail screen.** Tap any invoice row to open. Hero (party, grand total, outstanding, status chip), Items card, Taxes card, Totals card (Net + Taxes → Grand total → Outstanding), linked Payment Entries timeline, Remarks. Status chip respects `docstatus=0` and shows "Draft" regardless of textual status. Submit CTA on draft (with confirmation dialog, perm-gated via `can_submit`).

✅ **Supplier bill attachment on Purchase Invoice.** Added Bill no + Bill date fields (native ERPNext `bill_no` / `bill_date`) and an Attach Supplier Invoice button (file_picker for `pdf, jpg, jpeg, png`). Backend decodes base64, validates magic bytes (`%PDF-` / `FFD8FF` / `89PNG`) + size 256 B – 16 MB, saves as a **private** File attached to the new Purchase Invoice. Validated **before** insert so a bad file can't half-create a doc.

✅ **Timesheet detail screen + Submit (item Tonight).** Backend `get_detail(name)` returns time logs + `can_submit` + `has_active_timer`. Submit CTA at the bottom on drafts; disabled with a helper line "Stop the running timer before submitting." when there's a running row (ERPNext requires both from_time and to_time to submit). Backend `submit_timesheet(name)` enforces own-record + draft + no-active-timer + every-row-has-description-≥-4.

✅ **Record Payment against an invoice (#6, second half).** A submitted invoice with outstanding > 0 shows a **Record Payment** button (text becomes **Record Receipt** for Sales). Sheet pre-fills outstanding (editable), captures Mode of Payment (dropdown from enabled Modes), Posting Date, optional Reference No + Date. Backend `record_payment` uses ERPNext's own `get_payment_entry(dt, dn)` helper to pre-fill accounts/party/currency, then overrides amount + mode + dates, inserts, submits. **ERPNext recomputes the invoice status** (Partly Paid → Paid → etc) — the mobile never touches status. Invoice detail re-fetches after recording; outstanding drops and status chip flips automatically.

✅ **Linked Payment Entries on invoice detail.** New "Payments" card lists every Payment Entry referencing this invoice (name, posting date, mode of payment, ref no, allocated amount). Only shown if `Payment Entry: read` is granted.

✅ **Payments tab (3rd tab on Invoices).** Lists all Payment Entries the user can read with `DateRangeBar` filter (defaults current month). Summary card: Received total + Paid total (submitted entries only) for the window. Each row: down-arrow for Receive (green), up-arrow for Pay (navy); party name; name · date · mode of payment; signed amount on the right. **No FAB on this tab** — payments are recorded against an invoice from its detail screen, never standalone here.

### Backlog status after this session

| # | Item | Status |
|---|---|---|
| 1 | Department-scoped home pages | Deferred (user said "skip as of now") |
| 2 | Push notifications activation | Blocked on Firebase creds (user) |
| 3 | WhatsApp integration activation | Blocked on Meta creds + Cloudflare tunnel (user) |
| 4 | Timesheet start/stop timer | **DONE this session** |
| 5 | SaaS-ify | Not started — Phase A first (runtime baseUrl) |
| 6 | Invoices + Payments | **DONE this session** (create, draft/submit, supplier bill attach, Record Payment, Payments tab, linked Payment Entries on detail) |
| 7 | Expenses + Payroll date filters | **DONE this session** |
| — | R5 — CRM Lead/Deal detail re-skin | Still deferred |
| — | "Log Past Time" manual fallback | Removed when the timer flow replaced `_LogSheet`. If anyone forgets to start the timer, they currently can't enter past time from mobile — flag this if the user wants it back. |

### New backend endpoints added this session (under `tcb_inside.api.*`)

- `timesheet.start_timer(activity_type, project, task)`
- `timesheet.stop_timer(description)`
- `timesheet.get_active_timer()`
- `timesheet.get_project_tasks(project, query=None)`
- `timesheet.get_detail(name)` (own-record check)
- `timesheet.submit_timesheet(name)`
- `expense.get_context(from_date, to_date)` — extended with date filter
- `payslip.get_list(from_date, to_date)` — extended with date filter, returns `PayslipContext` shape
- `invoices.search_customers / search_suppliers / search_items`
- `invoices.create_sales_invoice / create_purchase_invoice` — `submit` param to separate Draft vs Submit. Purchase variant accepts `bill_no / bill_date / supplier_invoice_file (base64) / supplier_invoice_filename`.
- `invoices.get_invoice_detail(name, kind)` — items, taxes, totals, `can_submit`, `can_record_payment`, linked Payment Entries
- `invoices.submit_invoice(name, kind)`
- `invoices.list_modes_of_payment()`
- `invoices.record_payment(invoice_kind, invoice_name, paid_amount, mode_of_payment, posting_date, reference_no, reference_date, submit=1)` — wraps ERPNext's own `get_payment_entry` helper
- `invoices.list_payments(from_date, to_date, limit=200)` — Payments tab list

### New client files added this session

```
lib/
  features/timesheet/presentation/
    timesheet_detail_screen.dart        ← detail screen with Submit CTA on drafts
    timer_sheets.dart                   ← StartTimerSheet + StopTimerSheet
    running_timer.dart                  ← RunningTimerCard (on Timesheet) + RunningTimerStrip (above bottom nav)
  features/invoices/presentation/
    invoice_detail_screen.dart          ← detail screen with Submit / Record Payment CTAs + linked payments
    new_invoice_sheet.dart              ← party + items + Purchase-only Supplier bill block
    record_payment_sheet.dart           ← Record Payment / Receipt sheet
  shared/widgets/
    date_range_bar.dart                 ← shared chips + custom-range picker (Timesheet/Expenses/Payroll/Payments)
```

### Pending state on the sim

- iPhone 16e (`A372EC54-A841-4FAE-AB28-01DDA67E0BFF`), bundle `com.tcbinfotech.tcbPortal`, last PID 2566.
- Analyzer clean, 10/10 unit tests passing.

---

---

## Where to read this from next time

When the user returns, read this whole file first, then run `flutter analyze` and `flutter test` to confirm the codebase is still clean.

The auto-memory pointers stay correct:
- `[TCB Portal project]` → resume via this file.
- `[ERPNext multi-site bench]` → unrelated to this project; ignore here.

---

## What is built (live in the app today)

The TCB Portal is a Flutter mobile app for **Employee Self-Service + CRM**, backed by a Frappe v16 site `tcb.local` (port 8001) with a custom app **`tcb_inside`** (under `/Users/tcbinfotech/development/frappe-bench-v16`).

**Standing rules** (preserve across sessions):
- All ERPNext-side dev in `tcb_inside` only — never touch core (`frappe`, `erpnext`, `hrms`, `crm`).
- Best practices, latest stable packages, phase-wise delivery.
- Use existing ERPNext fields only — don't invent fields.
- Permissions enforced server-side via `frappe.has_permission` and `frappe.get_list`. Capability gating drives nav visibility.
- After every deployment: run analyzer + unit tests, build and verify on the iOS simulator, then report.
- Brand colours: `#022B60 / #FAFAFA`. Light-only UI. Material 3 tonal palette around primary `#031635`.

### Auth & session
- Login via `POST /api/method/login` then exchange for per-user `api_key:api_secret` via `tcb_inside.api.auth.get_credentials`.
- `Authorization: token KEY:SECRET` on every later request. Tokens in iOS Keychain / Android Keystore via `flutter_secure_storage`.
- Biometric unlock gated by `TCB_BIOMETRIC_LOCK` dart-define (default off for sim).
- Test user: **`karishma.jain@tcbinfotech.co.in`** (Employee + Sales User + Projects User). Passwords are never kept in the repo — ask the site admin.

### Permission-driven UI
- `tcb_inside.api.auth.get_profile` returns `capabilities` — booleans from `frappe.has_permission(<doctype>, <ptype>)`.
- The nav destination list ([lib/features/home/presentation/nav_destinations.dart](lib/features/home/presentation/nav_destinations.dart)) filters by these caps.
- Synthetic cap **`invoices`** = `sales_invoice OR purchase_invoice` (the unified screen unlocks if either is allowed).

### Navigation shell
- Mobile (< 840 px): horizontally-scrollable **bottom nav bar** (navy pill style) — [lib/features/home/presentation/app_shell.dart](lib/features/home/presentation/app_shell.dart).
- Tablet/desktop (≥ 840 px): persistent **side rail**, same source of truth.
- Bottom-nav height 62, label 10.5 px, no vertical padding inside the scrollview — the bar sits flush above the home indicator safe area.

### Feature screens (all redesigned to mockup quality, M3 surfaces, status-chip palette: Pending `#FFF3E0/#E65100`, Approved `tertiaryFixed/onTertiaryFixedVariant`, Rejected `errorContainer/onErrorContainer`, Cancelled `surfaceContainerHigh/onSurfaceVariant`)

| Route | Screen | Notes |
|---|---|---|
| `/home` | `HomeScreen` | Welcome hero + bento (Today / Leave / Last Payslip) + Recent Activity. The Last Payslip net is **masked** behind an eye toggle. The top-left avatar opens the profile screen. |
| `/time` | `AttendanceScreen` | Big circular clock-in/out button. Geofence chip on top tappable to retry. **Selfie + location both mandatory** for IN; OUT requires location only. |
| `/leave` | `LeaveScreen` | "Apply for Leave" CTA, bento balance grid w/ circular ring progress, My Requests list. |
| `/payroll` | `PayslipsScreen` | Hero net-salary card, YTD card, Earnings/Deductions split, Past Payslips list. **Every amount masked behind eye toggle (AppBar action)**. Detail screen has its own toggle. |
| `/tasks` | `TasksScreen` | Header + CTA, Card list, change-status sheet. |
| `/timesheet` | `TimesheetScreen` | **Date range filter** with chips (This month / Last month / Last 7 days / Custom). Default = current month. Total hours, Approved, Pending/Draft, Entries — all reflect the filtered window. |
| `/expenses` | `ExpensesScreen` | Summary card (Pending/Approved/Paid totals) + claims list. |
| `/leads` | `LeadsScreen` | List + new lead sheet. Detail uses original CRM lead detail screen. |
| `/deals` | `DealsScreen` | Pipeline summary card + list. |
| `/directory` | `DirectoryScreen` | Searchable list of active employees: name, designation/dept, **company email** (mail icon → `mailto:`), **mobile** (call icon → `tel:`). Backend uses `frappe.get_list` so visibility honours ERPNext perms. |
| `/invoices` | `InvoicesScreen` | TabBar — **Sales** ┃ **Purchase**. Summary card (billed total, outstanding, paid count) + list of invoices with party, amount, due, status chip. Tab is hidden via cap if user can read neither. |
| `/profile` | `ProfileScreen` | Avatar/name/role hero, Work / Contact / Emergency info cards. Edit sheet for: personal email, mobile, address, emergency contact, emergency phone (only these five are server-side whitelisted in `EMPLOYEE_SELF_EDITABLE`). |

### Mandatory location + selfie on attendance
- Backend `tcb_inside.api.attendance.mark` enforces lat/lon presence and validates geofence server-side (Haversine distance against `TCB Office Location` records).
- Selfie required when `log_type=IN`. Sent inline as base64 (data URL accepted). Backend validates JPEG/PNG magic bytes, size 1 KB – 8 MB, and saves it as a **private** File attached to the Employee Checkin.
- Client uses `image_picker` with `source: camera`, `preferredCameraDevice: CameraDevice.front`, `imageQuality: 70`, `maxWidth: 1280`. Cancelling the camera cancels the mark.
- Offline queue (Hive) carries the selfie path; on sync, the file is read, base64-encoded and submitted atomically.

### Payroll amount masking
- Per-screen `Notifier<bool>` toggle (`NotifierProvider.autoDispose`) so reveal resets on screen reopen.
- `••••••` placeholder + eye/eye-off `IconButton` in the AppBar (also one per hero, plus per-card on Home).

---

## Backend (tcb_inside) — file map

All endpoints whitelisted under `tcb_inside.api.*`:

```
apps/tcb_inside/tcb_inside/api/
  auth.py            ← get_credentials, get_profile, update_my_profile, FEATURE_PERMISSIONS
  attendance.py      ← get_context, mark (location + selfie mandatory for IN, saves File atomically)
  leave.py           ← apply, balances
  expense.py         ← apply, get_context
  payslip.py         ← get_list, get_detail
  task.py            ← create, set_status, get_context
  timesheet.py       ← get_context (from_date/to_date filter, default current month), create
  leads.py           ← get_list (uses frappe.get_list, NOT get_all), get_detail, create, update, convert_to_deal
  deals.py           ← get_list, get_detail, update
  notes.py crm_tasks.py comments.py attachments.py assignments.py crm_calls.py emails.py events.py timeline.py
  notifications.py   ← register_device, on_notification_log hook (PUSHABLE_NOTIFICATION_TYPES filter)
  directory.py       ← list_employees (NEW)
  invoices.py        ← get_context with sales[] + purchase[] (NEW)
  hr_customizations/ ← leave_policy.py, retention_and_latemark.py + tests
hooks.py             ← doc_events (Leave Application validate, Notification Log after_insert)
```

DocTypes owned by `tcb_inside`:
- `TCB Office Location` (geofence)
- `TCB Device Token` (push registration)

### auth.py — `EMPLOYEE_SELF_EDITABLE`
Only these fields are settable from the mobile Edit Profile sheet:
```python
{"personal_email", "cell_number", "current_address",
 "emergency_phone_number", "person_to_be_contacted"}
```

### auth.py — capability map (NEW entries marked)
```python
FEATURE_PERMISSIONS = {
    "timesheet": ("Timesheet", "create"),
    "task": ("Task", "create"),
    "attendance": ("Employee Checkin", "create"),
    "leave": ("Leave Application", "create"),
    "expense": ("Expense Claim", "create"),
    "payslip": ("Salary Slip", "read"),
    "leads": ("CRM Lead", "create"),
    "deals": ("CRM Deal", "read"),
    "sales_invoice": ("Sales Invoice", "read"),       # NEW
    "purchase_invoice": ("Purchase Invoice", "read"), # NEW
}
# Synthetic: "invoices" = sales_invoice OR purchase_invoice
```

### timesheet.py — date filter
`get_context(from_date=None, to_date=None)` returns timesheets where `start_date ≤ to_date AND end_date ≥ from_date` (overlap test). Defaults to `[first-of-current-month, today]`. Returns `from_date` and `to_date` in the response so the client knows what was applied.

---

## Client (tcb_portal) — file map (new/changed since previous handoff)

```
lib/
  core/
    network/api_paths.dart                      ← + directoryList, invoicesContext, profileUpdate
    router/app_router.dart                      ← Routes.directory, Routes.invoices, Routes.profile (root-nav push)
    theme/app_dimens.dart                       ← bottomNavHeight = 62
  features/
    home/presentation/
      app_shell.dart                            ← scrollable bottom nav + tight pill metrics
      nav_destinations.dart                     ← + Directory, + Invoices (cap='invoices')
      home_screen.dart                          ← avatar → /profile; Last Payslip amount masked
    attendance/
      application/attendance_controller.dart    ← mark(selfiePath) fresh GPS always
      data/attendance_repository.dart           ← selfie base64 inline; rejects missing selfie for IN
      presentation/attendance_screen.dart       ← opens camera before IN; "Selfie + location required" hint
    auth/
      domain/profile.dart                       ← Employee now has companyEmail/personalEmail/cellNumber/
                                                  currentAddress/emergencyPhone/emergencyContact + copyWith
      application/auth_controller.dart          ← updateMyProfile(patch) → server, state.withEmployee()
      data/auth_repository.dart                 ← updateMyProfile()
    payslips/presentation/
      payslips_screen.dart                      ← eye toggle masks ALL amounts (NotifierProvider.autoDispose)
      payslip_detail_screen.dart                ← same toggle on detail
    timesheet/
      application/timesheet_controller.dart     ← _from/_to + setRange(from, to)
      data/timesheet_repository.dart            ← getContext({from, to})
      domain/models.dart                        ← fromDate/toDate on TimesheetContext + totalHours getter
      presentation/timesheet_screen.dart        ← _RangeBar (chips + custom range picker) + Entries kpi
    directory/                                  ← NEW feature module
      domain/models.dart                        ← DirectoryEntry
      data/directory_repository.dart            ← list({search})
      application/directory_controller.dart     ← _search field + setSearch(debounced)
      presentation/directory_screen.dart        ← search bar + list, tap-to-call + mailto
    invoices/                                   ← NEW feature module
      domain/models.dart                        ← Invoice (InvoiceKind enum), InvoicesContext
      data/invoices_repository.dart
      application/invoices_controller.dart
      presentation/invoices_screen.dart         ← TabBar(Sales|Purchase), summary card per tab
    profile/                                    ← NEW feature module
      presentation/profile_screen.dart          ← Work / Contact / Emergency cards + edit sheet
```

Total branches in the StatefulShellRoute: 11 (home, time, leave, payroll, tasks, timesheet, expenses, leads, deals, directory, invoices). Profile is a separate top-level GoRoute pushed on the root navigator.

---

## What works on the sim right now (2026-05-30)

- App is installed on **iPhone 16e** simulator (`A372EC54-A841-4FAE-AB28-01DDA67E0BFF`), bundle id `com.tcbinfotech.tcbPortal`, last PID 76726.
- `flutter analyze` → **No issues found**.
- `flutter test` → **10 tests passing**.
- Backend cache cleared after every backend change in this session.

To rebuild + relaunch:
```bash
export PATH="/Users/tcbinfotech/development/flutter/bin:$PATH"
cd /Users/tcbinfotech/development/tcb_portal
flutter build ios --simulator --dart-define=TCB_BIOMETRIC_LOCK=off
xcrun simctl terminate A372EC54-A841-4FAE-AB28-01DDA67E0BFF com.tcbinfotech.tcbPortal
xcrun simctl install   A372EC54-A841-4FAE-AB28-01DDA67E0BFF build/ios/iphonesimulator/Runner.app
xcrun simctl launch    A372EC54-A841-4FAE-AB28-01DDA67E0BFF com.tcbinfotech.tcbPortal
```

To reload the Frappe bench after Python edits:
```bash
cd /Users/tcbinfotech/development/frappe-bench-v16
bench --site tcb.local clear-cache
```

---

## What this session shipped

✅ Scrollable bottom nav (no drawer); overflow + over-tall navy area fixed; height 62.
✅ Every feature screen polished to mockup quality (Leave, Payroll, Tasks, Timesheet, Expenses, Leads, Deals).
✅ Mandatory **location + selfie** on Clock-In; mandatory location on Clock-Out (server-enforced).
✅ Directory tab — searchable employee list with tap-to-call + mailto.
✅ Homepage avatar → My Profile (view + edit limited fields).
✅ Payroll amounts hidden behind eye toggle (Payroll list, Payroll detail, Home Last Payslip card).
✅ Timesheet date-range filter (default current month).
✅ Invoices tab — Sales + Purchase invoice listings with summary card.

---

## Open / deferred

1. **R5** — CRM Lead/Deal **detail** screens still use the older brand-aliased palette (navy/canvas). The list screens were re-skinned this session; the detail screens were intentionally left until a dedicated pass.
2. **Push notifications** — Firebase/FCM is wired on the backend (`notifications.py`, NotificationLog → push bridge). Dart-side is a no-op until a Firebase project + service-account JSON is provided.
3. **WhatsApp** — code in place, needs Meta Cloud API creds (App ID, Phone Number ID, Business Account ID, Permanent Access Token, Webhook Verify Token) + Cloudflare tunnel for `office.tcbinfotech.com`.
4. **Push HTTPS prerequisite** — `office.tcbinfotech.com` Cloudflare tunnel for webhooks.

---

## Pick-up suggestion for next session

Greet the user, confirm what they want to verify first on the sim, then choose:
- If everything looks good → start the deferred R5 re-skin (CRM Lead/Deal detail).
- If anything is off → fix that first.
- Push notifications and WhatsApp need user-supplied credentials, so prompt them if they want to activate either.

---

## Next session — planned work (added 2026-05-30, end of day)

The user listed five items to pick up tomorrow. Tackle them in this order (push notifications and WhatsApp are blocked on user-supplied credentials, so ask for those early):

### 1. Department-scoped home pages — **DEFERRED**
User said 2026-05-30: "home part skip as of now". They will provide the department-to-layout mapping later. Don't start this until they bring it up again.

Reference plan kept here for when they do:
- The department is already available — `profile.employee?.department`.
- Define a `HomeLayout` enum/registry and a small mapper `homeLayoutFor(profile)`.
- Replace `_BentoGrid` body with a layout-driven widget tree. Layouts compose existing cards in a different order + can include layout-specific tiles.
- Keep the welcome hero + Recent Activity stable; vary only the bento.

### 2. Push live notifications (Firebase / FCM)
**Goal:** Frappe `Notification Log` rows fire a push to the recipient's device.

Backend is already wired — `tcb_inside/api/notifications.py` has `register_device`, `unregister_device`, `send_to_user`, and `on_notification_log` (hook fires on `Notification Log` `after_insert`, filtered by `PUSHABLE_NOTIFICATION_TYPES = {"Mention", "Assignment", "Alert"}`). FCM HTTP v1 client stub is in place. Dart-side is currently a no-op.

What's missing — **user must supply:**
- Firebase project (create at console.firebase.google.com — name it `tcb-portal` or similar).
- `GoogleService-Info.plist` for iOS bundle id `com.tcbinfotech.tcbPortal`.
- `google-services.json` for Android applicationId `com.tcbinfotech.tcb_portal` (or update the manifest to match the iOS bundle).
- A **service account JSON** with role "Firebase Cloud Messaging API Admin" (or just Messaging Admin) — store contents in `Notification Settings` / a `TCB Push Config` singleton doctype, NOT in code.
- APNs auth key (`.p8` from Apple Developer) uploaded to Firebase project settings → Cloud Messaging.

Implementation order once creds are in hand:
1. Add `firebase_core`, `firebase_messaging` to `pubspec.yaml`. Pin to latest stable.
2. `flutterfire configure` to drop `firebase_options.dart`. Sanity check Info.plist permissions (`UIBackgroundModes` → `remote-notification`).
3. In `main.dart` after Riverpod wiring: `Firebase.initializeApp()`, request `requestPermission` on first launch.
4. On login, listen `FirebaseMessaging.instance.onTokenRefresh` + read current `getToken()`, POST to `ApiPaths.registerDevice`.
5. Foreground handler (`onMessage`): show a `flutter_local_notifications` notification banner. Background (`onBackgroundMessage`): system handles. Tap handler navigates via deeplink → e.g. `/lead-detail` with extras.
6. Backend test: create a Notification Log row of type Mention → confirm the device receives the push.
7. On logout, call `ApiPaths.unregisterDevice` with the current token.

Verify: send a manual push from Firebase console → app shows notification.

### 3. WhatsApp integration (Meta Cloud API)
**Goal:** send WhatsApp messages from inside the app (lead/deal detail) and log inbound replies to the timeline.

What's already there: scaffolding inside `tcb_inside` (WhatsApp integration code lives next to `emails.py`-style endpoints). Activation is gated on creds + a public webhook URL.

User must supply:
- Meta App ID + App Secret
- Phone Number ID (the WhatsApp business number)
- Business Account ID
- **Permanent** access token (system user token, not a 24-hour one)
- Webhook Verify Token (any random string — the same on both Meta dashboard and `tcb_inside` config)
- A working HTTPS URL for the webhook. Prereq: bring up the Cloudflare tunnel for `office.tcbinfotech.com` — needed anyway for production push too.

Implementation order:
1. Add `TCB WhatsApp Config` singleton doctype (`tcb_inside`) with the five fields above; password fields encrypted at rest.
2. POST endpoint `tcb_inside.api.whatsapp.send` — wraps Meta Cloud API send-message (template or text). Honour ERPNext perms on the linked Lead/Deal.
3. Webhook endpoint `tcb_inside.api.whatsapp.webhook` — verify token, parse incoming message, attach to matching CRM Lead/Deal (lookup by phone), insert a Communication row so it appears in the existing timeline.
4. Mobile: add a "WhatsApp" tab/button in lead/deal detail. Composer reuses the existing email pattern but routes through `/whatsapp/send`.

Status chips: queued / sent / delivered / read / failed (Meta provides these via webhook updates).

### 4. Timesheet — start/stop timer with mandatory description
**Goal:** replace the manual "from-time + hours" entry with a one-tap **Start** → **Stop** flow.

Current screen: [lib/features/timesheet/presentation/timesheet_screen.dart](lib/features/timesheet/presentation/timesheet_screen.dart) `_LogSheet` requires the user to enter start, hours, description. Hours and description are both optional under "Description (optional)".

**UX locked in by user 2026-05-30:**
1. **Start flow:** tap "Start" → pick **Activity** → pick **Project** → pick **Task** → tap Start. Start datetime captured automatically (server `now`).
2. **Running state:** the running timer is shown as a **task chip / card** at the top of the Timesheet screen (and as a small persistent strip on other screens) — e.g. "Building dashboard widget · Project Phoenix · 00:42:13".
3. **Stop flow:** tap the running task chip → opens a sheet → enter **description** (mandatory, ≥ 4 chars) → tap **Stop**. End datetime captured automatically. Hours computed = `(end − start) / 3600`, rounded to 2 decimals. Saved as a Time Log row on a draft Timesheet (Frappe auto-rolls timesheets by week — keep that behaviour).

Backend:
- New endpoint `tcb_inside.api.timesheet.start_timer(activity_type, project, task)` — all three required.
  - Creates a server-side running record (a `TCB Timer` singleton-per-user doctype in `tcb_inside`, or a `User Setting` JSON blob — singleton doctype is cleaner). Returns `start_time` + `timer_id`.
- New endpoint `tcb_inside.api.timesheet.stop_timer(timer_id, description)` — description required, ≥ 4 chars validated server-side.
  - Reads `start_time`, computes hours, throws if hours ≤ 0 or description blank, appends Time Log to today's Timesheet (creates one if none exists), clears the running record.
- `get_context` also returns `active_timer` so the client can show the running chip after a restart (or on a different device).

Client:
- Persist nothing locally — server is source of truth (timer survives app kill / reinstall / different device).
- `RunningTimerNotifier` polls `active_timer` from context; a `Stream.periodic(1s)` ticks the displayed Duration for live updates.
- A `RunningTimerStrip` widget rendered above the bottom nav on every screen when `active_timer != null`. Tap → opens Stop sheet.

Edge cases to handle:
- App killed mid-timer → reload from server.
- Network blip on stop → retry queue with the description preserved.
- User has more than one open timer → backend rejects (one timer per user; rejected on `start_timer`).
- User selects an Activity but the selected Project has no Tasks → block Start with a clear message ("Pick a task to track time against").

### 5. SaaS-ify (multi-tenant, per-customer ERPNext server URL)
**Goal:** the app stops being TCB-only. On sign-up the customer enters **server URL + email + password**. Multiple ERPNext-backed companies onboard themselves. TCB = Super Admin (control plane). Each customer's company = Organisation Admin.

This is the biggest item — a significant architectural change. Suggested staging:

**Phase A — per-device tenant binding (no central control plane yet):**
1. Replace `AppConfig.baseUrl` (currently a compile-time constant) with a **runtime** value stored in secure storage alongside the auth token.
2. Add a "Server URL" field to the login screen — **free text only** (user's choice 2026-05-30; no dropdown of past servers, no autocomplete). Pre-fill with the last successful URL on next launch. Sanity-check by hitting `/api/method/ping` before accepting credentials.
3. The Dio client must read the base URL from a `Notifier` and rebuild when it changes. Update `core/providers.dart` and `core/config/app_config.dart` accordingly.
4. Sign-up button on the login screen → "How to onboard" guide for now (no real self-serve sign-up — that needs control plane).
5. Strip the `tcb.local` / `office.tcbinfotech.com` hardcodes from `AppConfig` — make them defaults for dev only (gated by `--dart-define=TCB_DEFAULT_URL=…`).

**Phase B — control plane (TCB Super Admin):**
1. Provision a separate tiny Frappe site `portal.tcbinfotech.com` (or a hosted Postgres-backed service — whichever fits). This is the **registry** of customer tenants, not the data plane.
2. Doctypes there: `Customer Tenant` (server_url, plan, status, owner_email), `Tenant User` (email, tenant link, invited_on), `Tenant Plan` (limits).
3. Endpoints: tenant create/freeze/restore, plan-limit checks, license verification ping the apps make on cold start.
4. Self-serve sign-up flow on the app: enter company name + server URL + admin email → email magic link → on click, app receives a deep link with a one-time token that completes registration and creates the Organisation Admin on the customer's ERPNext via an installer script.
5. Billing hook (later) — Stripe or manual invoicing.

**Phase C — Organisation Admin tooling inside the app:**
1. Inside-the-tenant "Admin" section visible only to users with role `Tenant Admin` (custom role added by the installer).
2. Manage roles, invite users, view usage, request plan changes.

**Cross-cutting:**
- Branding becomes per-tenant: name, logo, primary colour from a small `Tenant Branding` singleton on each customer site.
- The current TCB brand (`#022B60` / Hanken Grotesk) becomes the default theme when a tenant hasn't overridden anything.
- The custom app rename: `tcb_inside` is fine for TCB but customers will install it under a generic name. Plan a rename to `tcb_portal_app` (or similar neutral) at the same time we start Phase B — keep `tcb_inside` as an alias for backwards compat.

**Decisions locked in by user 2026-05-30:**
- **Hosting:** customers always **self-host ERPNext**. TCB hosts ONLY the control plane / Super Admin portal. The mobile app is published once to App Store + Play Store (one binary, multi-tenant via runtime server URL).
- **Whitelabel:** YES — fully whitelabeled per tenant. TCB Super Admin portal lets TCB upload, per customer:
  - Organisation name (shown in app title bar and login screen)
  - Logo (PNG/SVG, used everywhere the app says "TCB Portal" today)
  - Primary brand colour (replaces `#022B60` for that tenant)
- **Pricing/plan model:** still to be confirmed — ask the user when starting Phase B.

**Implementation note from those decisions:**
- The Super Admin portal (Phase B) must include a `Tenant Branding` editor (logo upload + name + primary colour picker) per customer tenant.
- On app cold start (after tenant URL is set), fetch the tenant's branding from the control plane (NOT from the customer's ERPNext, since the app shows the branding even before the user logs in). Cache it locally and apply on next launch.
- Theme system: the M3 ColorScheme is derived from a single seed colour — easy to swap per tenant. `app_theme.dart` should take a `seedColor` parameter sourced from the tenant config.
- The Super Admin portal itself is a separate small Frappe site (`portal.tcbinfotech.com`) — design it as a web admin UI, not part of the mobile app.

**Decisions locked in by user 2026-06-15 — SUPERSEDES the 2026-05-30 lock-in above:**

The Phase B middleware is now firmly designed. These answers are final and the implementation should follow them when development starts:

1. **Middleware hosting site:** **`office.tcbinfotech.com`** (TCB's existing ERPNext site — not a new dedicated `portal.tcbinfotech.com`). The middleware app is installed alongside `tcb_portal_erp` on that same bench. Rationale: keeps TCB's footprint at one server; avoids extra DNS/SSL/maintenance overhead.
2. **Middleware app name:** **`tcb_portal_control`**. Created via `bench new-app tcb_portal_control` on `frappe-bench-v16`, installed only on `office.tcbinfotech.com`.
3. **`company_id` format:** **user-written text field** (free-form Data). TCB Admin enters whatever value they want when creating each `Customer Tenant` record manually. Not auto-generated. Stored unique (case-insensitive recommended). Examples: `TCB`, `ACMECORP`, `DELTA123`. The customer types this exact value on the mobile login screen.
4. **Middleware call cadence:** **on login only, never on every request.** After the resolve_tenant call returns the server URL + brand colors, the mobile app caches them in `flutter_secure_storage` and points Dio at the customer's ERPNext directly. All subsequent traffic (timer ticks, attendance pings, notification polls, etc.) bypasses the middleware. Rationale: latency — every request hopping through TCB's server would degrade UX badly, and would also make TCB a single point of failure for every customer's day-to-day usage.
5. **Per-tenant active flag:** every `Customer Tenant` record has an **`is_active` (Check)** field. Only `is_active = 1` tenants return a valid response from `resolve_tenant`. Tenants with `is_active = 0` get a clean "This account is not active. Contact TCB Infotech." error on login — and since middleware is only consulted on login (decision 4), a deactivated tenant can keep using the app **until their current session ends or they log out**. Acceptable trade-off; if instant kill is ever needed, that's a future enhancement (heartbeat call).

**Locked DocType shape — `Customer Tenant`** (in `tcb_portal_control` module):
| Field | Type | Notes |
|---|---|---|
| `company_id` | Data | unique, mandatory, the value the user types on login |
| `company_name` | Data | display name (used on login screen header after company_id is entered) |
| `server_url` | Data | full URL of the customer's ERPNext, e.g. `https://erp.acmecorp.com` |
| `is_active` | Check | default 1; setting to 0 blocks new logins |
| `color_p1` | Color | "primary" — surface/background. TCB default `#FFFFFF` (white) |
| `color_p2` | Color | "secondary" — primary brand. TCB default `#022B60` (dark blue) |
| `color_p3` | Color | "tertiary" — accent. TCB default `#67B7E5` (light blue, placeholder — pick exact value with user) |
| `logo` | Attach Image | optional, replaces "TCB Portal" wordmark in app |
| `contact_email` | Data | primary contact for the tenant |
| `notes` | Small Text | internal notes for TCB Admin |

**Locked endpoint — `tcb_portal_control.api.tenant.resolve(company_id)`:**
- Whitelisted, **`allow_guest=True`** (mobile must call this BEFORE having any credentials).
- Looks up by `company_id` (case-insensitive). Throws `frappe.DoesNotExistError` if not found.
- If `is_active = 0` → throws with message "This account is not active. Contact TCB Infotech."
- Returns: `{ company_name, server_url, color_p1, color_p2, color_p3, logo_url }`.
- Rate-limit it (Frappe's `rate_limit` decorator) — say 30/hour per IP — since it's guest and reveals "is this company_id valid" info.

**Mobile-side login flow change (locked):**
1. Login screen shows three fields: **Company ID**, **Username**, **Password** (in that order). Username/password fields disabled until Company ID is resolved.
2. On Company ID blur (or a "Continue" button): mobile calls `https://office.tcbinfotech.com/api/method/tcb_portal_control.api.tenant.resolve?company_id=…`.
3. On success: store `server_url` + `color_p1/p2/p3` + `logo_url` + `company_name` in `flutter_secure_storage`. Apply theme immediately so the rest of the login form re-renders in the tenant's colors and shows `company_name` above the username field. Re-init Dio with the new `baseUrl`.
4. User enters username + password → standard ERPNext `/api/method/login` against the (now correctly pointed) Dio → continue as today.
5. On subsequent app launches: if `server_url` is already in secure storage, **skip the middleware** and go straight to the login form (still pre-themed from cached colors). Show a "Switch company" link in the corner that clears the cache and brings back the Company ID step.
6. On logout: keep `server_url` + colors cached (so login form stays themed). On "Switch company": clear all of it.

**Mobile-side theme system (locked):**
- Stop using the M3 single-seed-color trick. Instead derive ColorScheme from the **three explicit values P1/P2/P3**:
  - P1 → `surface`, `surfaceContainerLowest`, `background`
  - P2 → `primary`, `onSecondary` contrasts, AppBar bg
  - P3 → `secondary`, `secondaryContainer`, accent chips
  - All other tokens (errors, outlines, surfaces tints) derived algorithmically from P1+P2+P3 via a single mapping function in `app_theme.dart`.
- Until middleware is called the FIRST time on a fresh install, use TCB defaults baked into `AppConfig` (so the login screen has a color identity even before tenant resolve).
- `AppColors.*` constants get deprecated. New approach: `Theme.of(context).colorScheme.primary` etc. everywhere. This will touch every screen — mechanical but big.

**Acceptance test for the SaaS phase:**
- TCB Admin creates two tenants in `tcb_portal_control` on `office.tcbinfotech.com`:
  - `company_id=TCB`, server_url=`https://office.tcbinfotech.com`, P1=white, P2=#022B60, P3=#67B7E5.
  - `company_id=DEMO`, server_url=`https://demo.tcbinfotech.com` (or any other ERPNext we can point at), P1/P2/P3 different (e.g. orange theme).
- Mobile login as TCB → sees navy theme + TCB Portal logo, hits TCB ERPNext.
- Logout → "Switch company" → enter DEMO → sees orange theme + (optional) DEMO logo, hits demo ERPNext.
- TCB Admin toggles `DEMO.is_active = 0`. Mobile is forced to re-login (or fresh install) → login fails with the inactive-tenant message.

**Open questions deliberately deferred (do NOT block start of Phase B work):**
- Logo storage: do customers upload through the TCB Admin UI (TCB controls), or upload themselves through a separate portal? Assume TCB-controlled for now (matches "we control the brand" stance).
- Color picker UI for the DocType: Frappe's native `Color` field gives a swatch + hex input — fine. No custom widget needed unless user later wants live preview.
- Token refresh / session expiry behavior — no change from today's flow; still client ERPNext's responsibility.
- Migration path for the ~existing TCB-only install of `tcb_portal_erp` on `office.tcbinfotech.com`: when middleware ships, the mobile app stops shipping a hardcoded TCB URL. TCB Admin must create the first `Customer Tenant` (company_id=`TCB`) BEFORE the new APK rolls out, else existing users can't log in. Plan a coordinated cut-over.

### 6. Invoices + Payments — follow ERPNext-native flow
**User direction 2026-05-30:** "for accounts, i want to use basic erpnext flow — first user will create sales invoice and against that, user will create payment entry → ERPNext will automatically change the status and mobile app will show that only".

So the mobile app mirrors the native ERPNext flow exactly:
1. User creates a **Sales Invoice**.
2. Against that invoice, user creates a **Payment Entry** (linked via `references` child table to the invoice).
3. ERPNext recomputes Sales Invoice `status` automatically (`Paid` / `Partly Paid` / `Unpaid` / `Overdue` / `Return` / `Credit Note Issued` / `Cancelled`).
4. Mobile app **displays** the status — it never sets the status directly, only triggers actions that cause ERPNext to recompute it.

Scope locked in:
- **Invoice detail screen** — tap an Invoice row → see full doc (items, taxes, totals, outstanding, due date, posting date, party, linked Payment Entries timeline).
- **"Record Payment" action** on the invoice detail screen (visible only when user has `Payment Entry: create` permission). Opens a sheet pre-filled with the outstanding amount, payment date = today, payment account = default. On submit it creates a Payment Entry on the server with the reference pointing to this invoice → ERPNext updates the Sales Invoice status → app refreshes and shows the new chip.
- **Payments tab** — third tab on the existing Invoices screen (default choice): `Sales | Purchase | Payments`. Payments list shows all `Payment Entry` rows the user can read, with type (Receive / Pay), party, paid_amount, reference invoice (if linked), posting_date, status.
- **Standalone Payment Entries** (advances, journal entries) — out of scope for this iteration. Only invoice-linked payments shown initially. Note: we can show them later by widening the filter, but for v1 keep it simple per the user's "basic erpnext flow" guidance.
- **Invoice creation from mobile** — not in the user's explicit ask, but implied ("user will create sales invoice"). Plan to add a "New Sales Invoice" CTA on the Sales tab. Use the standard ERPNext required fields only (customer, items rows, due date). Don't reinvent.

Backend work:
- `tcb_inside.api.invoices.get_detail(name, kind)` → full doc + items + taxes + linked Payment Entries (via `frappe.get_all("Payment Entry Reference", filters={"reference_doctype": "Sales Invoice", "reference_name": name})` → fetch parents).
- `tcb_inside.api.invoices.create_sales_invoice(customer, items[], due_date, ...)` → wraps the standard create flow, returns the new name. Honour `frappe.has_permission`.
- `tcb_inside.api.payments.get_context(from_date, to_date)` → list of Payment Entries via `frappe.get_list`. Fields: `name, posting_date, payment_type, party_type, party, paid_amount, reference_no, status`.
- `tcb_inside.api.payments.record_against_invoice(invoice_kind, invoice_name, paid_amount, mode_of_payment, posting_date)` → uses ERPNext's `make_payment_entry(...)` helper (it knows the right accounts), saves + submits the Payment Entry. Returns the new name.
- `FEATURE_PERMISSIONS["payment_entry"] = ("Payment Entry", "read")` + `payment_entry_create = ("Payment Entry", "create")` for the action visibility.

Client work:
- `lib/features/invoices/presentation/invoice_detail_screen.dart` (new) — hero (party + outstanding/total), tabs/sections for Items / Taxes / Payments timeline / Activity. "Record Payment" CTA when permitted.
- `lib/features/invoices/presentation/new_sales_invoice_screen.dart` (new) — guided form. Reuse existing customer-picker pattern.
- Extend `InvoicesScreen` `TabController` to length 3, add Payments tab feeding from a new `PaymentsContext`.
- Keep models split: `Invoice` vs `Payment`.
- Status chip logic on the row stays as-is — ERPNext is the source of truth.

**Purchase Invoice symmetry (confirmed 2026-05-30):** YES, mirror the same flow.
- User creates a **Purchase Invoice** (supplier bill) → records a **Payment Entry** against it → ERPNext recomputes Purchase Invoice status → mobile displays it.
- Apply the same detail screen + Record Payment CTA pattern on the Purchase tab.
- Distinguish: Sales Invoice → Payment Entry of type "Receive". Purchase Invoice → Payment Entry of type "Pay".
- `make_payment_entry` from ERPNext supports both — pass `dt="Sales Invoice"` vs `dt="Purchase Invoice"`.

**Out of v1 scope (note for later):**
- Editing existing invoices from mobile.
- Cancelling invoices.
- Credit notes / debit notes.
- Standalone advances (not against an invoice).

### 7. Expenses + Payroll — date-range filters — **DONE** (2026-05-30 end-of-day)
Shipped. `DateRangeBar` extracted to `lib/shared/widgets/date_range_bar.dart` and now powers Timesheet, Expenses, and Payroll. Backend filters added on `expense.get_context` (`posting_date BETWEEN`) and `payslip.get_list` (overlap). Payroll's old "Year to date" card renamed to "Period total" — now reflects the filtered window. The full plan below is kept for reference but no further action needed.

#### (original plan, archived)
**Goal:** mirror the Timesheet filter UX on Expenses and Payroll so totals reflect a chosen window. Default = current month.

Reference implementation shipped today: [`_RangeBar` in lib/features/timesheet/presentation/timesheet_screen.dart](lib/features/timesheet/presentation/timesheet_screen.dart) + backend `tcb_inside.api.timesheet.get_context(from_date, to_date)` with overlap filtering and the `from_date`/`to_date` echoed in the response.

**Expenses ([lib/features/expenses/presentation/expenses_screen.dart](lib/features/expenses/presentation/expenses_screen.dart)):**
- Backend: extend `tcb_inside.api.expense.get_context` to accept `from_date` / `to_date`. Filter by `posting_date BETWEEN [from, to]` on `Expense Claim`. Echo the applied window in the response. Default = `[first-of-current-month, today]`.
- Model: add `fromDate`/`toDate` to `ExpenseContext` (same shape as `TimesheetContext`).
- Controller: add `_from` / `_to` + `setRange(from, to)` (same shape as `TimesheetController`).
- Screen: place a `_RangeBar` widget below the header CTA. Show the chosen window in the summary card title ("Claims summary · 1 May 2026 – 30 May 2026"). Already-shown totals (Pending / Approved / Paid) automatically reflect the filtered claims list.
- Empty state copy: "No expense claims between {from} and {to}."

**Payroll ([lib/features/payslips/presentation/payslips_screen.dart](lib/features/payslips/presentation/payslips_screen.dart)):**
- **User chose 2026-05-30: Option B — same chips as Timesheet** (This month / Last month / Last 7 days / Custom range). Filter payslips whose `[start_date, end_date]` overlaps the window.
- Backend: extend `tcb_inside.api.payslip.get_list` to accept `from_date` / `to_date`. Default = current calendar year (so the YTD card still makes sense). Echo `from_date`/`to_date` in the response.
- YTD card already filters `slips.startDate.year == now.year` client-side. After this change, YTD should reflect the **filtered window** instead — rename to "Period total" if it's no longer strictly year-to-date.
- The amount-masking eye toggle continues to apply to all amounts shown.

Shared bits worth extracting:
- The `_RangeBar` + `_Chip` widgets from `timesheet_screen.dart` would be cleaner pulled into `lib/shared/widgets/` as `DateRangeBar`. Three screens using the same pattern is the threshold where extraction pays. Worth doing as part of this work.

### 8. "Ask Anything" chat tab — conversational AI agent (post-SaaS)
**Spec captured 2026-06-15. Do not build until Phase 5 (SaaS) is done.**

**User vision verbatim:** *"AsAnythink tab: just before Home: On that: Screen looks like chat: User can ask: Put my timesheet for today → I have started working on this project with this task → system will automatically perform the task. That AI will perform: create, update, read."*

**Goal:** an LLM-powered chat tab where users speak naturally and the assistant translates their intent into the right Frappe API calls. Read, create, and update — the same surface the rest of the app exposes through buttons, now exposed through conversation.

**UX shape (locked from user's description):**
- **New nav tab, positioned BEFORE Home** — leftmost in the bottom nav, so it becomes the literal first thing a user sees.
- Screen looks like a chat (message bubbles, input box at the bottom, send button).
- User types or speaks → assistant responds in chat → may ask follow-up questions if intent is ambiguous → confirms before executing destructive/creative actions → reports outcome with a tappable deep-link to the new/updated doc.

**Concrete example flows the user gave:**
| User says | Assistant does |
|---|---|
| "Put my timesheet for today" | Asks: which project + task + hours? → creates a Timesheet via `tcb_portal_erp.api.timesheet.*` |
| "I have started working on Project Alpha, Task Foo" | Starts a running Time Log on that project+task (existing native ERPNext start-timer flow) |
| "Show me my pending leaves" | Calls `leave.get_context` → renders summary inline |
| "Apply leave from Mon to Wed, sick leave" | Asks for reason → calls `leave.apply` |

**Architecture options (decide before building):**

**Option A — direct mobile → Anthropic:** mobile holds API key, calls Anthropic directly, executes returned tool calls against the customer's ERPNext. Simplest. Worst: API key in APK (reversible), no central metering.

**Option B — server-side via middleware on `office.tcbinfotech.com`:** mobile sends user message to TCB middleware → middleware calls Anthropic → returns tool calls → mobile executes against customer ERPNext. Better: API key central, TCB meters/bills per tenant. **Worst: contradicts the SaaS spec's decision 4 ("middleware on login only").** AI traffic would hit middleware on every message.

**Option C — server-side in customer's own ERPNext:** add `tcb_portal_erp.api.ai.ask(message, history)` endpoint. Customer configures their own Anthropic key in a Settings DocType. Mobile only ever talks to customer ERPNext (consistent with SaaS spec). **Best privacy** (data stays in customer's environment). **Worst billing UX** (each customer pays their own Anthropic bill, manages their own key).

**Option D (recommended) — hybrid metered:** customer's ERPNext calls TCB's central LLM proxy (one new endpoint on `office.tcbinfotech.com` or a dedicated billing service). TCB owns the Anthropic relationship; each tenant has a per-month token budget enforced by the proxy. Customer ERPNext receives the LLM response and executes tool calls locally. Mobile only ever talks to customer ERPNext. Reconciles **everything**: SaaS spec stays clean (mobile never re-hits middleware), TCB centrally bills, customer data only briefly transits through the proxy on its way to Anthropic.

**Decide which option when starting this phase.** Recommend Option D.

**Tool surface (the "functions" the LLM can call):**
- Reuse the **existing whitelisted endpoints** in `tcb_portal_erp`. Don't build a parallel AI-only backend.
- Generate a tool manifest from `ApiPaths` + Python docstrings. Each endpoint becomes one Anthropic tool with: `name`, `description` (from docstring), `input_schema` (from function signature). Keep this auto-generated so the surface stays in sync as endpoints evolve.
- Server-side guardrails enforced **the same way the buttons enforce them today** — `frappe.has_permission`, own-record checks, etc. The AI gets no special privileges; it operates as the logged-in user. (Critical: never use `ignore_permissions=True` in the AI path.)

**Conversation memory:**
- v1: single-turn (each message standalone, no context).
- v2: multi-turn — keep last N messages + a structured "recent entities" cache (last project/task/employee the user mentioned, so "log 2 hours on it" resolves "it" correctly).

**Confirmation pattern (mandatory for write operations):**
- Read calls (list leaves, show today's checkins) execute immediately, render inline.
- Create/update calls render a confirmation card first: "About to create Timesheet for today: 2h on Project Alpha / Task Foo. Confirm or cancel." User taps Confirm → execute. Cancel → discard. No silent writes from chat.
- After execution, show a small success card with a tap-target that deep-links into the affected screen (`go_router` push to `/timesheet?selected=…`).

**Failure modes to design for:**
- LLM hallucinates an endpoint/field that doesn't exist → tool execution fails → assistant says "couldn't do that, here's why" with the raw error.
- LLM picks the wrong entity because of ambiguous name ("which Alpha? You have 'Project Alpha' and 'Alpha Demo'") → ask the user to disambiguate in chat.
- Customer ERPNext rejects on permission/validation → show the ERPNext error verbatim in chat.
- Network/LLM timeout → graceful "couldn't reach the assistant, try again" + a Retry button on the last user message.

**Phasing (when this phase is reached):**
- **8a — proof-of-concept:** 3-5 hardcoded tools (timesheet create/list, leave apply, task create). Single-turn. Option A architecture initially for fastest iteration, swap to Option D before any real tenant gets it.
- **8b — full tool registry:** auto-generated from `tcb_portal_erp` endpoints. Multi-turn memory. Confirmation cards. Deep-links to created docs.
- **8c — polish:** voice input (`speech_to_text` package), suggested-prompt chips below the input box ("Try: 'log 2 hours against...'"), undo for last create (where ERPNext allows delete), per-tenant token budget UI on the TCB Admin side.

**Open questions deferred (record now, decide at start of Phase 8):**
- Architecture: Option A / B / C / D — recommend D.
- LLM provider: Claude (Anthropic). Confirm. Falling back to a cheaper model for routine "show me X" reads vs. Sonnet/Opus for complex multi-tool flows is worth designing.
- Voice input from v1 or v2? Voice is high-impact on mobile, low effort with `speech_to_text` + on-device transcription.
- Position: literally first tab (leftmost). Replaces nothing — Home + Timesheet + Leaves + Tasks + More all shift right by one slot. Confirm visual budget on small screens.
- Cost cap per tenant per month — what's the default? Need a stub Customer Tenant field for `monthly_token_budget` on the middleware side.

**Why this belongs AFTER SaaS, not before:**
- Tool execution must respect tenant boundaries — the AI must run against the user's own ERPNext, not TCB's. That requires the runtime-baseUrl plumbing the SaaS phase delivers.
- Token budgeting per tenant needs the `Customer Tenant` registry the SaaS phase delivers.
- Trying to bolt this on before SaaS would force a hardcoded-URL design that immediately breaks once we go multi-tenant. Sequencing matters.

---

## Snapshot of decisions/values to preserve

- iOS sim: iPhone 16e `A372EC54-A841-4FAE-AB28-01DDA67E0BFF`.
- Bundle id: `com.tcbinfotech.tcbPortal`.
- Latest PID this session: 76726.
- Bench: `/Users/tcbinfotech/development/frappe-bench-v16`, site `tcb.local`, port 8001.
- Custom app: `tcb_inside`.
- Test user: `karishma.jain@tcbinfotech.co.in` (password: ask the site admin).
- Admin: `Administrator` (password: ask the site admin).
- Brand: `#022B60` / `#FAFAFA` (light-only). M3 tonal palette around `#031635`.
