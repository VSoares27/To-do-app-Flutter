# BUILD_LOG.md

Development history of the Flutter mobile to-do app. Entries are append-only:
earlier entries are never rewritten, corrections are added as new entries.

---
 
## AI Model Used

Lovable

## Entry 1 — Platform clarification

### Prompt / Request
"Faça em Flutter" followed by the full "Mobile To-Do App — Implementation
Specification".

### Decision Summary
The build environment used for this conversation can only compile and run web
applications (React); it has no Flutter SDK, Android SDK or emulator. The user
was asked how to proceed and chose: "Só o código Flutter em arquivos" — deliver
the complete Flutter source in files, to be compiled and run on the user's own
machine.

Consequence, recorded honestly: steps 19/20 of the spec ("build the project",
"run it", "inspect compiler output") could not be executed here. Code was
written carefully against the current APIs of the chosen packages, but it is
**unverified by a real build**.

### Actions Performed
- Created the project folder `flutter_todo/`.
- Created `BUILD_LOG.md` (this file) before writing any feature code.

### Result
Scope agreed, log started.

### Problems / Errors
No Flutter toolchain available in the environment.

### Fixes Attempted
Asked the user to choose between a web equivalent and a source-only Flutter
delivery; followed their choice.

### Current Status
Completed.

---

## Entry 2 — Dependencies and architecture

### Prompt / Request
Spec sections 15, 16, 17 (architecture, state management, dependencies).

### Decision Summary
Architecture: a light layered/repository structure, appropriate for a small
educational app, with no Clean-Architecture ceremony.

```
models  ->  plain data classes (Task, Category)
data    ->  AppDatabase (sqflite) + TaskRepository + CategoryRepository (raw SQL)
services->  NotificationService
state   ->  AppState (ChangeNotifier) — the single source of truth for the UI
screens ->  three Material screens
```

State management: `provider` + `ChangeNotifier`. Reason: smallest viable
solution that still refreshes every screen after create/edit/delete/complete/
filter/category changes. Riverpod and Bloc were considered and rejected as
unnecessary complexity for three screens.

Dependencies chosen:
- `sqflite` — SQLite access on Android/iOS; the de-facto standard, direct SQL,
  no code generation. (Drift was considered: nicer reactive queries, but adds
  build_runner codegen, which is heavy for this size.)
- `path` — to join the database filename with the platform database directory.
- `provider` — state management / dependency injection into the widget tree.
- `intl` — date/time formatting (`dd/MM/yyyy HH:mm`).
- `flutter_local_notifications` — scheduled local notifications, no push server.
- `timezone` + `flutter_timezone` — `zonedSchedule` requires a `TZDateTime`; the
  device timezone is resolved at startup.
- `permission_handler` — declared for completeness; the actual runtime request
  is done through flutter_local_notifications' own platform APIs.

### Actions Performed
- Created `pubspec.yaml` with the dependencies above and `analysis_options.yaml`.

### Result
Dependency set defined.

### Problems / Errors
None at this step.

### Fixes Attempted
n/a

### Current Status
Completed.

---

## Entry 3 — Data models and SQLite schema

### Prompt / Request
Spec sections 3, 4, 5 (task model, category model, SQLite persistence).

### Decision Summary
Two tables created in `onCreate` at schema version 1.

`tasks`: `id` (INTEGER PK AUTOINCREMENT), `title` (NOT NULL), `description`
(NOT NULL DEFAULT ''), `completed` (INTEGER 0/1 — SQLite has no boolean),
`due_date_time` (INTEGER, nullable, millisecondsSinceEpoch), `created_at`
(INTEGER NOT NULL), `category_id` (INTEGER, nullable, FK), `notification_id`
(INTEGER).

Additional field beyond the spec, as required to be documented:
- **`notification_id`** — the integer id handed to
  flutter_local_notifications. It is set equal to the task row id right after
  insert, which makes it stable and unique, so a reminder can be cancelled or
  replaced later without keeping any in-memory map.

`categories`: `id`, `name` (NOT NULL), `color` (INTEGER ARGB, optional extra
used to render a colored dot/chip per category).

Dates are stored as epoch milliseconds (integers) rather than ISO strings, which
makes SQL `ORDER BY due_date_time` correct without string parsing.

`PRAGMA foreign_keys = ON` is enabled in `onConfigure`, and
`category_id` uses `ON DELETE SET NULL`.

Four categories are seeded on first creation (Personal, Work, Study, Shopping)
so the first run is not empty.

### Actions Performed
- Created `lib/models/task.dart` (with `copyWith` supporting explicit
  `clearDueDateTime` / `clearCategory` flags, because a plain `copyWith` cannot
  distinguish "unchanged" from "set to null").
- Created `lib/models/category.dart`.
- Created `lib/data/app_database.dart`, `lib/data/task_repository.dart`,
  `lib/data/category_repository.dart`.

### Result
Persistence layer implemented. Data survives navigation, app close/reopen and
device restart because everything is written to the SQLite file immediately on
each mutation (no in-memory-only state).

### Problems / Errors
Anticipated pitfall handled during writing: `copyWith(dueDateTime: null)` would
silently keep the old value. Solved with the explicit clear flags described
above.

### Fixes Attempted
n/a

### Current Status
Completed — needs testing on a device.

---

## Entry 4 — Filtering strategy

### Prompt / Request
Spec section 12 (filtering by status and category).

### Decision Summary
Filtering is done **in SQLite**, not in memory: `TaskRepository.fetch()` builds
a `WHERE` clause from the active `StatusFilter` (all / pending / completed) and
the optional `categoryId`. Ordering is also done in SQL: pending first, then
tasks with a due date (soonest first), then newest created.

`AppState` holds the current filters; changing one triggers a re-query and
`notifyListeners()`, so the list refreshes reactively.

### Actions Performed
- `StatusFilter` enum + `fetch()` query in `task_repository.dart`.
- `setStatusFilter` / `setCategoryFilter` in `lib/state/app_state.dart`.

### Result
Both filters work through SQL and combine with each other.

### Problems / Errors
None.

### Fixes Attempted
n/a

### Current Status
Completed — needs testing.

---

## Entry 5 — Notifications strategy and permissions

### Prompt / Request
Spec sections 9, 10, 11 (due dates, local notifications, permissions).

### Decision Summary
One method does all the work: `NotificationService.sync(task)`.
It always cancels the notification id of the task first, then schedules a new
one only when: the task is pending **and** has a due date **and** that due date
is in the future. This single method therefore satisfies every required
behavior:

- created with a future due date -> scheduled;
- due date changed -> old cancelled, new scheduled;
- due date removed -> cancelled, nothing scheduled;
- completed -> cancelled;
- reopened with a future due date -> scheduled again;
- deleted -> `AppState.deleteTask` calls `cancel(notificationId)` explicitly.

Notification id = task row id (see Entry 3).

Scheduling uses `zonedSchedule` with `AndroidScheduleMode.inexactAllowWhileIdle`.
Reason: exact alarms on Android 13+ require the user to grant a special
"alarms & reminders" privilege; inexact mode works without it, at the cost of a
possible few minutes of delay. Documented as a deliberate trade-off.

Permissions: requested once from the task list screen after the first frame,
through the plugin's own Android 13+/iOS APIs. Denial is handled gracefully —
a snackbar explains that tasks still work without reminders, `permissionGranted`
stays false, and every notification call is wrapped in try/catch, so a denial or
a platform failure can never crash the app. Timezone resolution failure falls
back to UTC instead of throwing.

The Android manifest declares `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`,
`VIBRATE`, `SCHEDULE_EXACT_ALARM` and the plugin's boot receiver so pending
reminders survive a reboot.

### Actions Performed
- Created `lib/services/notification_service.dart`.
- Created `android/app/src/main/AndroidManifest.xml` with permissions and
  receivers.
- Wired `sync`/`cancel` into `AppState.saveTask`, `toggleCompleted`,
  `deleteTask`.

### Result
Notification lifecycle implemented.

### Problems / Errors
Not verifiable in this environment: scheduling can only be confirmed on a real
device/emulator with the system clock.

### Fixes Attempted
n/a

### Current Status
Needs testing (on device).

---

## Entry 6 — Screens and navigation

### Prompt / Request
Spec sections 6, 7, 8 (three screens, navigation, task operations).

### Decision Summary
Navigation uses the built-in `Navigator` with `MaterialPageRoute`; no routing
package, since there are only three screens and no deep links.

Data transfer strategy for editing: **pass only the task id**. `TaskEditorScreen`
receives `taskId` and loads the row from SQLite itself. Chosen over passing the
full object so the form can never display a stale copy, and over global shared
state so the screen stays self-contained.

Screens:
1. `TaskListScreen` — segmented control for All/Pending/Completed, horizontal
   choice chips for categories ("All categories" + one per category), each row
   shows title, Pending/Completed, category name in its color, and due date
   (rendered in the error color when overdue). Checkbox toggles complete/reopen.
   AppBar action opens category management; FAB creates a task.
2. `TaskEditorScreen` — title (validated as required), description, category
   dropdown (including "No category"), date picker, time picker, "Remove due
   date", Completed switch, Save / Cancel, and Delete (with confirmation) when
   editing. If a date is picked without a time, 09:00 is assumed and the UI says
   so. A past due date shows a note that no reminder will be scheduled.
3. `CategoryScreen` — list with color dot, create/rename dialog with a small
   color palette, delete with confirmation.

Category deletion behavior (spec section 6 requires a documented decision):
**tasks become uncategorized.** Implemented at the schema level with
`ON DELETE SET NULL`, so no task is ever lost. The confirmation dialog states
how many tasks will be affected, and if the deleted category was the active
filter, the filter resets to "All categories".

Error handling: every repository call in `AppState` runs through a `_guard`
helper that catches exceptions and exposes `state.error`, which the list screen
shows and the editor surfaces as a snackbar. Empty titles and empty category
names are rejected with user feedback rather than exceptions.

### Actions Performed
- Created `lib/screens/task_list_screen.dart`,
  `lib/screens/task_editor_screen.dart`, `lib/screens/category_screen.dart`.
- Created `lib/state/app_state.dart` and `lib/main.dart`.
- Created `README.md` with run instructions.

### Result
All required screens, operations and navigation implemented in source form.

### Problems / Errors
No compiler output available here, so type errors cannot be ruled out.

### Fixes Attempted
n/a

### Current Status
Completed in source — needs testing.

---

## Entry 7 — Final review against the acceptance criteria

### Prompt / Request
Spec sections 20 and 21 (functional acceptance criteria, final review).

### Decision Summary
Reviewed each criterion against the written code and marked honestly what is
implemented versus what is verified. "Implemented" means the code path exists;
it is not the same as tested, because no build was possible here.

| Criterion | Status |
| --- | --- |
| application builds successfully | Not verified (no Flutter SDK here) |
| application starts successfully | Not verified |
| tasks created / edited / deleted | Implemented |
| tasks marked completed / reopened | Implemented |
| tasks persist in SQLite | Implemented |
| categories created / renamed / deleted | Implemented |
| tasks optionally belong to categories | Implemented |
| status filtering / category filtering | Implemented (SQL WHERE) |
| navigation between the three screens | Implemented |
| due dates assigned | Implemented |
| local notifications scheduled | Implemented, not verified on device |
| notifications updated when due date changes | Implemented (`sync`) |
| notifications cancelled on delete / complete | Implemented |
| notification permission handled safely | Implemented (try/catch + snackbar) |
| data available after restart | Implemented (file-backed SQLite) |
| BUILD_LOG.md contains the history | Completed |

### Actions Performed
Re-read all source files for consistency: import paths, `copyWith` clear flags,
notification id propagation after insert, filter reset after category deletion.

### Result
Feature-complete source delivery.

### Problems / Errors / Known limitations
- **Not compiled or run.** The environment has no Flutter toolchain, so
  compiler errors and runtime behavior are unverified. This is the main known
  risk of this delivery.
- Platform folders (`android/` except the manifest, `ios/`) are not included;
  `flutter create .` must be run once in the project folder.
- iOS requires manually setting `UNUserNotificationCenter.delegate` in
  `AppDelegate.swift` (documented in README).
- Notifications use inexact alarms on Android, so delivery may be a few minutes
  late when the device is dozing.
- Reminders fire at the due moment only; no snooze, repetition or lead time.
- Category colors come from a fixed six-color palette, no free color picker.
- No automated tests were written.

### Fixes Attempted
n/a

### Current Status
Needs testing — run `flutter pub get` and `flutter run`, then record any
compiler/runtime errors and their fixes as new entries below this one.

---

## Final summary

- **Architecture:** layered / repository (models -> data -> state -> screens),
  feature-light and suited to a small educational app.
- **Important dependencies:** sqflite (SQLite), provider (state), intl (dates),
  flutter_local_notifications + timezone/flutter_timezone (reminders), path.
- **SQLite strategy:** single sqflite database `todo.db`, schema version 1, raw
  SQL inside two repositories, foreign keys on, `ON DELETE SET NULL` for
  categories, epoch-millisecond timestamps, four seeded categories.
- **State management:** one `AppState` ChangeNotifier exposed with provider;
  every mutation writes to SQLite then re-queries and notifies.
- **Navigation:** built-in Navigator with MaterialPageRoute; the editor receives
  only the task id and loads the row itself.
- **Notifications:** one id per task (equal to its row id), single `sync(task)`
  method that cancels then conditionally reschedules, explicit cancel on
  delete, permission requested once with graceful denial.
- **Known limitations / remaining risks:** never compiled or executed in this
  environment; platform folders must be generated with `flutter create`; iOS
  delegate step is manual; inexact Android alarms; no tests.

---

## Entry 8 — Correction: removed an unused dependency

### Prompt / Request
Spec section 17: "Avoid adding unnecessary libraries."

### Decision Summary
Entry 2 listed `permission_handler` as a dependency "for completeness". On
review it is never imported: the notification permission is requested through
flutter_local_notifications' own Android/iOS APIs. Keeping it would violate the
"no unnecessary libraries" rule. Entry 2 is intentionally left unchanged; this
entry records the correction.

### Actions Performed
- Removed `permission_handler` from `pubspec.yaml`.

### Result
Dependency list now matches what the code actually imports.

### Problems / Errors
Incorrect earlier assumption that a separate permission package would be needed.

### Fixes Attempted
n/a

### Current Status
Completed.
