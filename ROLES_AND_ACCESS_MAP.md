# TCB Portal — Roles & Access Map

**As of 2026-08-26 (evening).** Single source of truth for "who sees what in the app".
Anything not listed here is visible to everyone with a valid session.

The app has **NO custom role system**. Everything is gated by:

1. **ERPNext roles** the user has (Sales User, HR Manager, Projects User, etc.)
2. **ERPNext DocType permissions** (`frappe.has_permission("Lead", "create")` etc.)
3. **Employee.reports_to** for hierarchy-based visibility (managers see their reportees)

`tcb_portal_erp.api.auth._capabilities()` computes a `capabilities: {…}` map
that the mobile reads once at login and uses to hide/show every UI surface.

---

## 1. The capability catalogue (all keys the API returns)

Every key is a boolean. `true` unlocks a UI surface.

### 1a. Feature-permission caps (from `FEATURE_PERMISSIONS`)

Each is `True` iff the user has the given ERPNext permission on the given
DocType. Source: `apps/tcb_portal_erp/tcb_portal_erp/api/auth.py`.

| Cap key | Backing check | What it unlocks |
|---|---|---|
| `attendance` | `Employee Checkin`: create | **Time** tab, Clock In on Home |
| `leave` | `Leave Application`: create | **Leave** tab, Apply Leave on Home |
| `expense` | `Expense Claim`: create | **Expenses** side-nav item |
| `payslip` | `Salary Slip`: read | **Payroll** tab, Payslip card in bento |
| `task` | `Task`: create | **Tasks** tab |
| `timesheet` | `Timesheet`: create | **Timesheet** tab + running-timer strip |
| `leads` | `Lead`: create | **Leads** side-nav, Today's Plan card, phone-lookup FAB on Leads |
| `deals` | `CRM Deal`: read | **Deals** side-nav |
| `sales_invoice` | `Sales Invoice`: read | (part of synthetic `invoices`) |
| `purchase_invoice` | `Purchase Invoice`: read | (part of synthetic `invoices`) |
| `invoices` | `sales_invoice OR purchase_invoice` | **Invoices** tab |

### 1b. Section-role caps (from `SECTION_ROLES`)

Each is `True` iff the user has one of the listed roles. Used to gate the
role-specific **home dashboard sections** (added 2026-08-26).

| Cap key | Roles that unlock it | Home section shown |
|---|---|---|
| `sees_sales` | Sales User · Sales Manager · Sales Master Manager · CRM Manager | Sales dashboard + Pipeline card + Call detection card (Android) |
| `sees_hr` | HR User · HR Manager | HR at a glance section |
| `sees_projects` | Projects User · Projects Manager | Projects section |
| `sees_accounts` | Accounts User · Accounts Manager | Accounts section |

**System Manager gets all four automatically.**

### 1c. Manager view (from `_MANAGER_ROLES`)

| Cap key | Roles that unlock it | What it unlocks |
|---|---|---|
| `manager_view` | System Manager · Sales Manager · Sales Master Manager · CRM Manager | Leaderboard card · Team Status card · **Field team** card (Android) · Team-scope toggle on Pipeline · Team-scope toggle on Projects dashboard |

*Note: `manager_view` is **sales-leadership specific**. A plain HR Manager
does NOT get `manager_view` unless they also have System Manager.*

### 1d. Hierarchy-based (server-enforced, no cap key)

For **live location tracking**, the manager view uses
`Employee.reports_to` walked up to 8 hops. There is no `sees_field_team`
cap — server enforces `_is_reportee()` on every read. Client just shows the
**Field team** card whenever `manager_view` is true; if the user has no
reportees, the map shows an empty state ("You don't have any direct or
indirect reports").

---

## 2. Bottom navigation tabs

Source: `lib/features/home/presentation/nav_destinations.dart`.

Every tab is auto-hidden when the gating cap is `false`.

| Tab | Gate cap | Route | Screen |
|---|---|---|---|
| **Home** | (always) | `/home` | HomeScreen (role-based sections inside) |
| **Time** | `attendance` | `/time` | AttendanceScreen |
| **Leave** | `leave` | `/leave` | LeaveScreen |
| **Payroll** | `payslip` | `/payroll` | PayslipsScreen |
| **Tasks** | `task` | `/tasks` | TasksScreen |
| **Timesheet** | `timesheet` | `/timesheet` | TimesheetScreen |
| **Expenses** | `expense` | `/expenses` | ExpensesScreen |
| **Leads** | `leads` | `/leads` | LeadsScreen |
| **Deals** | `deals` | `/deals` | DealsScreen |
| **Directory** | (always) | `/directory` | DirectoryScreen |
| **Invoices** | `invoices` | `/invoices` | InvoicesScreen |

*The bottom nav is scrollable, so a super-user sees all 11 items horizontally.*

---

## 3. Home-screen sections (top → bottom)

Source: `lib/features/home/presentation/home_screen.dart` build method.

**2026-08-26 evening restructure:** the sales sprawl (SalesDashboardSection
+ Pipeline card + Call detection card + Leaderboard + Team status + Field
team + Location banner) has been collapsed into ONE "Sales workspace" CTA
that opens a dedicated tabbed screen. Home now stays visually clean for
every role, including managers. Details in section 3a below.

| # | Section | Gate | Contents |
|---|---|---|---|
| 1 | **Welcome hero** | always | `Good {morning/evening}, {name}!` + Clock In + Apply Leave buttons |
| 2 | **Today's Plan** | `leads` | Sales-agent daily plan (overdue count, new leads, next call) |
| 3 | **Sales workspace** card | `sees_sales` | CTA → `/sales-workspace`. Single entry point for the whole CRM suite (Overview, Pipeline, Calls, Team). Replaces the old sales-dashboard sprawl on Home. |
| 4 | **HR at a glance** section | `sees_hr` | KPI tiles (pending leaves, absent today, exits <30d) + birthdays this week |
| 5 | **Projects** section | `sees_projects` | KPI tiles (active projects, tasks due, overdue, unbilled hrs) + next deadlines |
| 6 | **Accounts** section | `sees_accounts` | KPI tiles (receivable, payable, overdue count, receipts/payments in period) + top overdue list |
| 7 | **Leaderboard** card | `manager_view` **AND NOT `sees_sales`** | Fallback for non-sales managers who don't have the Sales workspace. Sales managers reach this from inside the workspace. |
| 8 | **Team status** card | `manager_view` **AND NOT `sees_sales`** | Same fallback rule. |
| 9 | **Field team** card | `manager_view` **AND NOT `sees_sales`** **AND** Android | Same fallback rule. |
| 10 | **Location status banner** | `sees_sales` **AND** Android AND permissions/service missing | Red banner explaining what to fix. Hidden when everything works. **No user toggle any more.** |
| 11 | **Today** bento tile | always | Clock-in status |
| 12 | **Leave Balance** bento tile | always | Days remaining |
| 13 | **Last Payslip** bento tile | always | Latest slip date (amount masked) |
| 14 | **Recent Activity** | always | Recent leave approvals, task completions, etc. |

**Note on row 12 (updated 2026-08-26 evening):** the user-facing toggle
has been removed. Location sharing is a **policy** for the sales team, not
a choice. Tracking auto-starts silently for any Sales user when the app
launches. The banner in row 12 only appears when something is broken
(permission revoked, background permission missing, notification perm off,
system Location service off) and disappears as soon as it's fixed. Non-
sales users see no location UI on Home at all.

---

## 3a. Sales workspace tabs (`/sales-workspace`)

Opened via the "Sales workspace" card on Home. Gated on `sees_sales`.
The Team tab appears only for `manager_view`.

| Tab | Gate | What's inside |
|---|---|---|
| **Overview** | `sees_sales` | The full SalesDashboardSection (My/Team toggle, Today counters, Follow-ups, Leads by status, Deals by stage, Sales team today). |
| **Pipeline** | `sees_sales` | Funnel view CTA (`/pipeline`) + Kanban board CTA (`/lead-kanban`). |
| **Calls** | `sees_sales` | Call Detection settings CTA (`/call-detection`, Android only) + info card explaining per-lead call history. On iOS the CTA is replaced by an "iOS notice" info card. |
| **Team** | `manager_view` | Leaderboard CTA + Team status CTA + Field team CTA (Android only). Non-managers don't see this tab at all. |

Nothing was removed. Every surface that was on Home before is still
reachable; it now lives inside a proper workspace instead of scattered
across the home screen.

---

## 4. Screen-level access (deep routes)

| Screen | Route | Gate | Extra rules |
|---|---|---|---|
| Pipeline | `/pipeline` | `leads` OR `deals` (defence in depth) | Team-scope toggle visible only if `manager_view` |
| Lead Kanban | `/lead-kanban` | `leads` | FAB (new lead) hidden if no create perm |
| Lead detail | `/lead-detail/:name` | `leads` | Backend enforces owner OR territory-share |
| Deal detail | `/deal-detail/:name` | `deals` | Backend enforces owner OR territory-share |
| Invoice detail | `/invoice-detail/:name` | `invoices` | Submit / Record Payment shown only if server returns `can_submit`/`can_record_payment` = true |
| Team status | `/team-status` | `manager_view` | Backend also enforces the manager-role check |
| Leaderboard | `/leaderboard` | `manager_view` | Backend enforces same |
| Call Detection settings | `/call-detection` | `sees_sales` **AND** Android | iOS users see an "iOS notice" widget explaining Apple sandbox limits |
| **Sales workspace** | `/sales-workspace` | `sees_sales` | Tabbed screen (Overview / Pipeline / Calls / Team). Team tab visible only to `manager_view`. |
| **Field team list** (landing) | `/location/team` | `manager_view` **AND** Android | List of trackable reportees with status pill + last-known position + minutes ago. App-bar has map + refresh actions. Refresh spins the icon and shows a snackbar. Auto-refresh every 60 s. |
| **Field team map** | `/location/team/map` | `manager_view` **AND** Android | Map with a pin per person. Coloured by status. Pull-to-refresh + spinning refresh + auto-refresh every 60 s. |
| **Person live location** | `/location/person/:employee` | `manager_view` **AND** the target employee is a direct/transitive report | Server 403s if the caller is not authorized |
| Directory | `/directory` | (always) | Any authenticated user can browse the employee list |
| Notifications | `/notifications` | (always) | Notification Log is per-user |
| Profile | `/profile` | (always) | Own profile only |

---

## 5. Feature-level access (finer than screen-level)

| Feature | Where | Gate |
|---|---|---|
| Create Sales Invoice | Invoices FAB | Server sets `can_create_sales` in `invoices.get_context`, based on `Sales Invoice: create` perm |
| Create Purchase Invoice | Invoices FAB | Same via `can_create_purchase` |
| Submit invoice | Invoice detail | Server `can_submit` = `docstatus==0 AND has Submit perm` |
| Record Payment | Invoice detail | Server `can_record_payment` = `docstatus==1 AND outstanding>0 AND has Payment Entry: create` |
| Convert Lead → Customer | Lead detail menu | `leads` cap + backend Lead-convert perm |
| Apply AI suggested status | Recording detail | `leads` cap + own the lead OR manager |
| Start/stop timer | Timesheet tab | `timesheet` cap; one active timer per user enforced server-side |
| Enable location tracking | Home toggle | Android only, requires Employee record |
| See any reportee's live location | Field team map | `manager_view` cap AND `Employee.reports_to` graph |

---

## 6. Minimum roles for each key surface

Answers the question "kaunse role ke bina ye cheez nahi dikhegi":

| To see this | Minimum you need |
|---|---|
| **Nothing** (base user) | Any active `User` record (login-able) |
| **Basic ESS** (Home bento + Time + Leave + Payroll + Tasks + Timesheet) | Role `Employee` (grants Employee Checkin, Leave, Salary Slip, Task, Timesheet permissions) |
| **Expenses tab** | Role that grants `Expense Claim: create` (typically `Employee` + org policy) |
| **Leads / Deals tabs, Sales home section, Pipeline, Call detection card** | Role `Sales User` (or higher: Sales Manager, Sales Master Manager, CRM Manager). This gives `leads` + `deals` + `sees_sales` |
| **HR home section** (pending leaves, birthdays, absentees) | Role `HR User` or `HR Manager` |
| **Projects home section** | Role `Projects User` or `Projects Manager` |
| **Accounts home section** | Role `Accounts User` or `Accounts Manager` |
| **Invoices tab, Invoice create/submit, Record Payment** | Role that grants `Sales Invoice: read` OR `Purchase Invoice: read` (typically `Accounts User` or `Sales User` with company scope) |
| **Leaderboard, Team status, Field team map, Team-scope on Pipeline** | Role `Sales Manager` / `Sales Master Manager` / `CRM Manager` / `System Manager` |
| **Field team map showing a specific person's location** | Above manager role AND that person's `Employee.reports_to` chain leads to the caller AND that person has one of the sales roles |
| **Be tracked yourself (location shared with manager)** | One of `Sales User`, `Sales Manager`, `Sales Master Manager`, `CRM Manager`. Automatic, no toggle. Only opt-out is revoking Android location permission. |
| **Everything (super-user)** | Role `System Manager` |

---

## 7. Demo-user matrix (what each seeded user sees today)

Test creds set up 2026-08-26 for the demo.

| User (Employee) | Password | Roles | Bottom nav | Home sections shown |
|---|---|---|---|---|
| **Administrator** | `admin` | System Manager (super) | All 11 tabs | Every section (sees everything) |
| **ess.test@tcb.local** (ESS Tester, HR-EMP-00066) | (ask admin) | Employee | Home · Time · Leave · Payroll · Tasks · Timesheet · Directory | Welcome + Location toggle (Android) + Bento + Recent Activity. **No CRM. No HR. No Projects. No Accounts. No Manager cards.** |
| **karishma.jain@tcbinfotech.co.in** (HR-EMP-00029, reports to Aditi) | (ask admin) | Employee · Projects User · Sales User | All ESS tabs + Leads + Deals + Directory | Welcome + Today's Plan + **Sales dashboard** + Pipeline + Call detection (Android) + **Projects section** + Bento + Recent Activity. **Location tracking auto-starts silently at boot; no user toggle.** Aditi sees Karishma on Field team map. |
| **ajay.verma@tcbinfotech.co.in** (HR-EMP-00026) | (ask admin) | Agent · Employee · Helpdesk Contact · Projects User | ESS tabs + Directory | Welcome + **Projects section** + Bento + Recent Activity. **No CRM at all. NO location tracking either (Projects User isn't a sales role).** |
| **mukesh.kumar@tcbinfotech.co.in** (HR-EMP-00025, developer) | (ask admin) | Employee · Projects User | ESS tabs + Directory | Same as Ajay — Welcome + Projects section + Bento + Recent Activity. **Verified 2026-08-26 evening: home has zero location UI, backend refuses any pings from him.** The canonical "not tracked" user for demos. |
| **rajesh.kumar@tcbinfotech.demo** (HR-EMP-00068) | (ask admin) | Employee · HR Manager · Item Manager · Leave Approver · Purchase User · Sales Manager · Sales Master Manager | ESS + Leads + Deals + Invoices + Directory | Welcome + Today's Plan + **Sales** + Pipeline + Call detection + **HR** + Leaderboard + Team status + Field team + Location toggle + Bento + Recent. No Projects/Accounts (no those specific roles). |
| **hr@tcbinfotech.com** — Yashvi (HR-EMP-00027) | (ask admin) | 50+ roles incl. System Manager, HR Manager, Sales User, Accounts Manager, Projects User | All 11 tabs | Every home section (super-user via System Manager). Field team map empty (no reportees under Yashvi). |
| **aditi.malusare@tcbinfotech.co.in** (HR-EMP-00022) | (ask admin) | 50+ roles incl. System Manager, Accounts Manager, HR Manager, Sales Manager, Projects Manager, Purchase Manager, etc. | All 11 tabs | Every home section. **Field team map shows her 5 reportees**: Sahil Dhania, Shivam Singhal, Anuj Sharma, Varsha Mehta, and one more under HR-EMP-00022. |
| **rishab.gupta@tcbinfotech.co.in** | (ask admin) | 50+ roles incl. System Manager (super) | All 11 tabs | Every home section (same as Yashvi). No reportees under Rishab in current data → Field team map empty. |
| **sahil.dhania@tcbinfotech.co.in** (HR-EMP-00004) | (ask admin) | Employee · Projects User (via role chain) | ESS tabs + Directory | Welcome + Location toggle + Bento + Recent Activity. **Reports to Aditi**, so his pings are visible to her on the Field team map. |

---

## 8. Location-tracking mapping (LOC.1 — policy revision 2026-08-26 evening)

Because this feature just tightened significantly, calling it out explicitly:

- **Who is tracked:** ONLY users with one of `Sales User`, `Sales Manager`,
  `Sales Master Manager`, or `CRM Manager` role. Non-sales employees
  (developers like Mukesh, HR, accounts, projects) are NOT tracked. The
  app never even tries to start the location service for them; the backend
  refuses their pings with `{ok: false, reason: "not_trackable"}` as a
  second line of defence.
- **How it starts:** automatically at app launch. No user-facing toggle.
  For a sales user, the app requests permissions (fine, background,
  notifications) on first launch, opens a backend Tracking Session
  silently, and starts the native foreground service.
- **How to opt out:** the sales user CANNOT turn tracking off from within
  the app. The only opt-out is revoking the OS-level location permission
  in Android Settings — and even then, the manager still sees a "Permission
  off" status on the map, so the fact that the user opted out is visible.
- **Ping cadence:** every 10 min, or when the user moves > 100 m,
  whichever comes first. Trades freshness for battery.
- **Who sees the "Field team" map card:** any user with `manager_view`
  on Android.
- **Whose location shows on that map:** every Active Employee who
  (a) has one of the sales roles AND (b) whose `Employee.reports_to`
  chain resolves to the caller (up to 8 hops). System Manager sees every
  Active sales employee.
- **Person detail view:** allowed if the target is the caller, is a
  transitive report, or the caller is System Manager. Otherwise HTTP 403.
- **Backend enforces every rule** — the client-side gating is a UX
  nicety, not a security boundary.
- **iOS:** entire location feature is Android-only in this pass.

### The five statuses a manager sees, with meaning

| Status pill | Colour | Meaning |
|---|---|---|
| **Online** | green | Fresh ping in last 15 min |
| **Stale** | amber | Last ping 15-45 min ago |
| **Offline** | grey | Last ping >45 min OR never |
| **Permission off** | red | User revoked location permission in Android Settings |
| **Location off** | red | System-wide Location service is off |
| **No GPS fix** | amber | App is running but can't get a fix (indoor, tunnel) |
| **No network** | grey | Heartbeat couldn't reach the server (phone offline) |

**Last-known position stays visible.** Even when the latest event is a
heartbeat (Permission off / Location off), the map pin still shows the
last real coordinate the user reported. Manager sees WHERE they were
plus WHY updates stopped.

### Practical example (with current demo data)

Aditi (HR-EMP-00022) has these direct reports:

- HR-EMP-00004 Sahil Dhania — has `Sales User` → **shows on map**
- HR-EMP-00009 Shivam Singhal — Employee only → hidden
- HR-EMP-00019 Anuj Sharma — Employee only → hidden
- HR-EMP-00023 Varsha Mehta — Employee only → hidden
- HR-EMP-00026 Ajay Verma — Projects User only → hidden
- HR-EMP-00029 Karishma Jain (added 2026-08-26) — `Sales User` → **shows on map**

So Aditi's Field team map today shows Sahil + Karishma. The rest of her
reports (developers / project members) are correctly invisible.

---

## 9. What is deliberately NOT gated

- **Directory:** everyone can browse the employee list (like a global
  address book). No cap.
- **Home welcome + bento (Today/Leave Balance/Last Payslip):** always
  shown. These are per-user data and the individual cards silently
  hide if the underlying cap is missing (e.g. no Payslip card if
  `payslip` cap is false).
- **Notifications, Profile:** always. Both are per-user.

---

**End of mapping.**

For code truth, cross-reference:

- `apps/tcb_portal_erp/tcb_portal_erp/api/auth.py` (`_capabilities()`)
- `lib/features/home/presentation/nav_destinations.dart` (tab list)
- `lib/features/home/presentation/home_screen.dart` (home section gates)
- `lib/core/router/app_router.dart` (route table)
- `lib/features/location_tracking/DESIGN.md` (location tracking full spec)
