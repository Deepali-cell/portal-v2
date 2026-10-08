# TCB Portal — Release Notes (Mobile App)

The Flutter mobile app companion to **tcb_portal_erp** (Frappe custom app `tcb_inside`). All ERPNext interactions go through `tcb_inside.api.*` whitelisted endpoints; visibility is gated by `frappe.has_permission` per feature DocType.

The platform stack: Flutter 3.x / Dart 3.x, Riverpod 3 (AsyncNotifier + Notifier patterns), Dio 5 + per-user `api_key:api_secret` token in Keychain/Keystore, GoRouter (StatefulShellRoute), Material 3 light-only theme around primary `#031635`. iOS bundle id `com.tcbinfotech.tcbPortal`.

---

## 0.1.0 — Initial release (2026-05-30)

First commit to GitHub. Everything below is in the binary that's currently installed on the iPhone 16e simulator.

### Authentication & session

- Login screen — server URL is fixed at compile-time today (`tcb.local:8001`); will become a runtime field in the SaaS Phase A pass.
- Two-step handshake: `POST /api/method/login` to establish a Frappe session, then `tcb_inside.api.auth.get_credentials` returns the user's `api_key`/`api_secret`. Neither password nor session is retained on-device — every later request uses `Authorization: token KEY:SECRET`.
- Tokens persisted in iOS Keychain / Android Keystore via `flutter_secure_storage`.
- Biometric unlock (Face ID / Touch ID / device PIN) on resume, gated by the `TCB_BIOMETRIC_LOCK` dart-define (default off on the sim).
- Force-logout only on HTTP 401 — 403 surfaces an in-screen error instead.

### Capability-driven navigation

Server returns a `capabilities` map computed from `frappe.has_permission` per feature DocType. The nav destination list ([lib/features/home/presentation/nav_destinations.dart](lib/features/home/presentation/nav_destinations.dart)) only shows a tab when the matching cap is granted. Caps wired today:

| Cap | DocType / permission | Feature |
|---|---|---|
| `attendance` | Employee Checkin / create | Time tab |
| `leave` | Leave Application / create | Leave tab |
| `expense` | Expense Claim / create | Expenses tab |
| `task` | Task / create | Tasks tab |
| `timesheet` | Timesheet / create | Timesheet tab |
| `payslip` | Salary Slip / read | Payroll tab |
| `leads` | CRM Lead / create | Leads tab |
| `deals` | CRM Deal / read | Deals tab |
| `invoices` | synthetic: sales_invoice OR purchase_invoice | Invoices tab |
| — (always on) | — | Home, Directory, My Profile |

The mobile app shell ([app_shell.dart](lib/features/home/presentation/app_shell.dart)):
- Mobile (< 840 px): a horizontally-scrollable **bottom nav bar** (navy pill style), height 62, label 10.5 px.
- Tablet/desktop (≥ 840 px): persistent **side rail** — same destination list, same caps.
- A **thin "running timer" strip** above the bottom nav appears on every screen when a Timesheet timer is active (see Timesheet section).

### Home (`/home`)

- Welcome hero with greeting, name, and quick CTAs.
- Bento cards: **Today** (live attendance state), **Leave Balance** (top type + ring progress), **Last Payslip** (date + net pay, amount masked behind an eye toggle).
- **Recent Activity** card combining today's check-ins + recent leave applications.
- Top-left avatar (user initials) opens the Profile screen.

### Attendance (`/time`)

- Big circular clock-in/out button with the suggested next action (`IN` / `OUT`).
- **Mandatory location** for both IN and OUT (geofence enforced server-side via Haversine against `TCB Office Location` records).
- **Mandatory selfie** on Check-In: front camera via `image_picker`, validated server-side (JPEG/PNG magic bytes, 1 KB – 8 MB), saved as a private File attached to the Employee Checkin atomically with the row creation.
- Geofence chip (top of card) is tap-to-retry on failure.
- Today's logs list + week strip + stats tiles (logs today / inside-outside geofence).
- Offline queue: when no connectivity, checkins are stored in Hive and drained automatically on reconnect (selfie path included; file re-read at sync time).

### Leave (`/leave`)

- "Leave Balances" header + full-width Apply for Leave CTA.
- Bento balance grid with ring progress per leave type.
- My Requests list with status chips (Pending / Approved / Rejected / Cancelled).
- Apply sheet supports half-day, date pickers, reason.

### Payroll (`/payroll`)

- Hero **Net Salary** card with paid chip + grand total.
- **Period total** card (renamed from "Year to date") — totals across the currently-filtered window.
- Earnings vs Deductions split with itemised line components.
- Past Payslips list. Tap a payslip → detail screen with Net Pay + Earnings + Deductions breakdown.
- **Date-range filter** (chips: This month / Last month / Last 7 days / Custom). Default = current calendar year on first open so the YTD-style total makes sense.
- **Amount masking**: every monetary value is `••••••` until the eye toggle in the AppBar is tapped. The toggle is screen-scoped (`Notifier.autoDispose`) so reveal resets on screen reopen. Detail screen has its own toggle; the Home "Last Payslip" bento has a smaller per-card toggle.

### Tasks (`/tasks`)

- Header + New Task CTA. List of tasks with status chips (Open / Working / Pending Review / Completed / Cancelled / Overdue).
- Tap a row → status sheet to change status.
- Project picker on the New Task sheet uses the open Projects list.

### Timesheet (`/timesheet`)

- **Native ERPNext start/stop timer** — a Time Log child row with `from_time` set and `to_time` empty IS the running timer; no custom DocType.
- Start Timer flow: Activity → Project → Task → tap Start. Start datetime captured server-side.
- Running state shows as:
  - A big navy **RunningTimerCard** on the Timesheet screen with the task name, activity · project, and a 1-second live elapsed clock (`HH:MM:SS`, tabular figures).
  - A **thin strip** above the bottom nav on every other screen — same ticker, smaller.
  - Tap either → **Stop Timer** sheet → **mandatory description** (≥ 4 chars validated client + server) → Stop. End datetime captured server-side; ERPNext computes hours on save.
- One running timer per user (enforced server-side).
- Survives app kill / reinstall / a different device — the server is the source of truth (`get_active_timer()`).
- **Date-range filter** (shared widget with Expenses + Payroll), default current month.
- Period summary card: Total hours · Approved · Pending/Draft · Entries (all reflect the filter).
- Tap a timesheet row → **detail screen** with the time logs (activity, project · task, from→to, hours, description) + Submit action on drafts. Submit blocks if a running timer is still active or if any row has < 4 chars of description.

### Expenses (`/expenses`)

- Header + New Claim CTA.
- Claims summary card (Pending / Approved / Paid totals + claim count) — reflects the filtered window.
- My Claims list with status chips.
- **Date-range filter** (shared widget), default current month.
- Multi-item New Claim sheet with type / amount / description per row.

### Leads & Deals (`/leads`, `/deals`)

- Lists with status chips, search-by-perms (uses `frappe.get_list`, not `get_all`, so org-hierarchy permissions are honoured).
- New Lead sheet.
- **Pipeline card** on Deals — total pipeline value + weighted (probability-adjusted).
- Tap a row → existing CRM detail screen (Details, Comments, Notes, Attachments, Email, Assign to, plus other tabs from the original CRM integration).

### Directory (`/directory`)

- Searchable list of active employees (debounced 300 ms, searches name / role / department / email / phone).
- Each row: avatar (initials), name, designation · department, company email, mobile.
- **Tap-to-call** (`tel:` URI) + **tap-to-email** (`mailto:` URI) right on the row.
- Backend uses `frappe.get_list` so visibility honours ERPNext perms.

### My Profile (`/profile`)

- Avatar tap on the Home AppBar pushes this screen (root-nav push, not branched).
- Navy hero with initials, full name, designation, login email.
- Three info cards: **Work** (Employee ID, Designation, Department, Company, Date of Joining), **Contact** (Company Email, Personal Email, Mobile, Address), **Emergency Contact** (name, phone).
- Edit sheet covers exactly the five fields the user is allowed to update from mobile: personal_email, cell_number, current_address, emergency_phone_number, person_to_be_contacted. Server-side allow-list in `auth.EMPLOYEE_SELF_EDITABLE`.

### Invoices (`/invoices`)

A three-tab screen: **Sales | Purchase | Payments**.

**Sales / Purchase tabs:**
- Summary card on top — billed total · outstanding · paid count for the current view.
- List of invoices with party, name, posting date, grand total, outstanding (when applicable), status chip. Draft status shows "Draft" regardless of textual status (driven by `docstatus`).
- Tap a row → **Invoice detail screen**.
- FAB **+ New Sales** / **+ New Purchase** (hidden if user lacks create permission). The sheet has typeahead party picker (live search), posting date, due date, and items rows (each with item picker, qty, rate, auto-amount). Two buttons at the bottom: **Save** (draft, outlined) and **Save & Submit** (filled).
- **Purchase only** — extra block on the New Invoice sheet for **Supplier Bill**: optional Bill No, Bill Date, and **Attach supplier invoice** (PDF / JPEG / PNG via file_picker, validated server-side with magic bytes + size 256 B – 16 MB, saved as a private File attached to the new Purchase Invoice).

**Invoice detail screen:**
- Navy hero — invoice name, party, grand total, outstanding (when applicable), posting/due dates, status chip.
- Items card — line items with code, name, qty × rate, amount.
- Taxes card (when present) — itemised taxes.
- Totals card — Net + Taxes → Grand total → Outstanding.
- Linked Payments card — every Payment Entry referencing this invoice (name, posting date, mode of payment, ref no, allocated amount).
- Remarks card (when present).
- Bottom action bar:
  - **Submit** when invoice is a draft and user has submit perm (confirmation dialog → ERPNext computes status flow on submit).
  - **Record Payment** (text becomes "Record Receipt" for Sales) when submitted with outstanding > 0 and user has Payment Entry create perm.

**Record Payment sheet:**
- Pre-fills the full outstanding amount (editable).
- Mode of Payment dropdown from enabled `Mode of Payment` records.
- Posting date, optional Reference No (cheque / UTR / txn id), optional Reference Date.
- Uses ERPNext's own `erpnext.accounts.doctype.payment_entry.payment_entry.get_payment_entry(dt, dn)` helper to pre-fill accounts/party/currency, then overrides amount + mode + dates, inserts, submits.
- ERPNext recomputes the invoice status (Partly Paid → Paid → etc) — mobile never touches the status.

**Payments tab:**
- Lists all `Payment Entry` rows the user can read with `DateRangeBar` filter (defaults current month).
- Summary card: Received + Paid totals (submitted entries only) for the window.
- Each row: green down-arrow for Receive, navy up-arrow for Pay; party name; name · date · mode of payment; signed amount.
- No FAB — payments are always recorded against an invoice from its detail screen.

### CRM features (still present from prior integration)

Inside Lead / Deal detail screens: Details, Comments, Notes, Attachments, Email (compose + send via Communication doctype), Assign to (Frappe's standard ToDo assignment), Status changes, Convert-to-Deal from Lead, tap-to-call the contact number. These are backed by the `crm_*` / `notes` / `comments` / `attachments` / `assignments` / `emails` / `events` / `timeline` API modules on the ERPNext side.

### Push notifications — **backend ready, mobile no-op**

Frappe `Notification Log` → push bridge is wired on the ERPNext side (`tcb_inside.api.notifications.on_notification_log` hook, filtered to `Mention | Assignment | Alert`). FCM HTTP v1 send is in place. The mobile app does **not** initialise Firebase yet — a no-op until a Firebase project + service-account JSON + APNs `.p8` are provided.

### WhatsApp — **backend scaffolded, not active**

Scaffolding sits next to `emails.py` on the ERPNext side. Needs Meta Cloud API credentials (App ID + Secret, Phone Number ID, Business Account ID, Permanent Access Token, Webhook Verify Token) and a public HTTPS webhook (Cloudflare tunnel for `office.tcbinfotech.com`) to activate.

---

## Tech inventory

**Dart packages (key ones)**: flutter_riverpod 3, dio 5, go_router 17, flutter_secure_storage 9, geolocator 14, image_picker 1, file_picker 3, hive 2, connectivity_plus, url_launcher, local_auth 3, intl, google_fonts (Hanken Grotesk), material_symbols_icons.

**Theme**: M3 ColorScheme around primary `#031635`. Light-only. Status-chip palette: Pending `#FFF3E0`/`#E65100`, Approved/Completed/Won/Paid → tertiaryFixed/onTertiaryFixedVariant, Rejected/Lost → errorContainer/onErrorContainer, Cancelled/Draft → surfaceContainerHigh/onSurfaceVariant, Default → secondaryFixed/onSecondaryFixedVariant.

**Code quality**: `flutter analyze` returns "No issues found"; 10 unit tests passing covering profile parsing, attendance models, api_exception extraction.

**Verified on**: iPhone 16e simulator (iOS 26.3), running against a Frappe v16 site at `tcb.local:8001` with HRMS + Frappe CRM + ERPNext.

---

## Known limitations of 0.1.0

- **Server URL is hard-coded** at compile time (`tcb.local:8001`). SaaS Phase A will move this to a login-screen field with secure storage of the chosen URL.
- **No push delivery** on the device yet — Firebase not initialised (creds needed from operator).
- **No WhatsApp** activation — Meta creds needed.
- **No past-time entry** in Timesheet — when the new start/stop timer replaced the manual `_LogSheet`, the ability to enter a past time block was removed. Flag if this needs to come back as a "Log Past Time" secondary action.
- **CRM Lead/Deal *detail* screens** still use the older brand-aliased palette (`AppColors.navy` / `AppColors.canvas` etc) — a re-skin to the new M3 token palette is queued.
- **Department-scoped home content** is deferred — Home is one layout for everyone today.

---

## Next planned work (in HANDOFF.md detail)

1. Push notifications activation (Firebase project + service-account JSON + APNs key).
2. WhatsApp activation (Meta Cloud API creds + Cloudflare tunnel).
3. SaaS Phase A — runtime server URL field on login.
4. CRM Lead/Deal detail re-skin to M3 tokens.
5. Department-scoped home (when the user provides the department → layout mapping).
6. SaaS Phase B — TCB Super Admin portal (control plane) + Phase C in-tenant Organisation Admin tooling.
