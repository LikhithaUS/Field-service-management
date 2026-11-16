# ServiceHub — Flutter App

Cross-platform client (Android, iOS, Web, Windows) for **ServiceHub**, an Employee & Field Service
Management Platform. Talks to the Node.js/Express backend in `../../backend`.

> Status: authentication (login, register, forgot/reset password, session restore), a role-aware
> dashboard, **Employees** (list with search/filters/pagination, details, create/edit/delete),
> **Departments** (admin CRUD), **Tasks** (assignment, status workflow, comments) and
> **Attendance** (check-in/out, history, team report), **Leave** (apply, approve/reject, cancel) and
> **Notifications** (bell with unread badge, inbox) and **Announcements** are complete.

## Screens

| Screen | Who |
|---|---|
| Splash, Login, Register, Forgot password, Reset password | Everyone |
| Dashboard | Signed-in users (tiles differ by role) |
| Employees list / details / create / edit | Admin, Manager (managers can't delete or assign roles) |
| Departments | Admin |
| Tasks list / details | Everyone (employees see only *My tasks*) |
| Create / edit task | Admin, Manager |
| Attendance (check in/out, this month's history) | Everyone |
| Team attendance report | Admin, Manager |
| My leave, apply for leave, leave details | Everyone |
| Leave requests (review queue) | Admin, Manager |
| Notifications | Everyone |
| Announcements list / details | Everyone |
| Post / edit announcement | Admin, Manager (managers only their own) |

Role rules are enforced by the backend; the app mirrors them (router guards and hidden buttons)
so users never see actions that would fail.

**New employee onboarding:** when an admin/manager creates an employee, the backend emails a setup
code (printed to the backend console for now). The employee opens the app, taps
*Forgot password?* → *I already have a code*, and sets their password.

**Tasks:** staff create a task, pick the assignee from a searchable employee list (or "Assign to
me"), and set priority, due date and job-site location. The assignee moves it through
*Start task* → *Mark completed* (and can *Reopen*); only staff can cancel, edit or delete.
Overdue tasks (still open, due date before today) are highlighted, and each task has a comment
thread for back-and-forth between the manager and the employee.

**Attendance:** a live clock with one *Check in* / *Check out* button per day. "Worked" counts up
while checked in. The backend decides *late* / *half day* from the company rules it sends back
(work start time, half-day hours), so the app never hard-codes them. Staff open *Team report* to see
everyone's records for a day or date range, filter by person or status, and see totals.

**Leave:** pick a type and a date range; the form previews the number of working days (weekends
are skipped, matching the backend). Staff review pending requests from *Requests* and approve or
reject with an optional note; nobody can review their own, and managers only review employees.
Approved days appear as *Leave* in attendance. Requests can be cancelled while pending, or after
approval if the leave hasn't started.

**Notifications:** the dashboard's bell shows the unread count. The backend creates notifications
for task assignments, comments, completions and leave requests/decisions. Tapping one marks it read
and opens the task or leave request it refers to. The count refreshes whenever you come back to the
dashboard (no live push yet).

**Announcements:** staff post notices with a category (General, Holiday, Maintenance, Meeting,
Important) and can pin them to the top. Posting notifies everyone. The top announcement is
shown on the dashboard; the full list has search and category chips.

## Tech Stack

| Concern | Choice |
|---|---|
| State management | Riverpod 3 (`AsyncNotifier`) |
| HTTP | Dio, with an auth interceptor |
| Navigation | GoRouter with auth-aware redirects |
| UI | Material 3, light/dark, responsive |
| Token storage | `flutter_secure_storage` |
| Testing | `flutter_test`, `mocktail` |

## Running

Start the backend first (`cd backend && npm run dev`), then:

```bash
flutter pub get
flutter run -d chrome        # Flutter Web
flutter run -d windows       # Windows desktop
flutter run                  # connected Android device / emulator
```

The API URL defaults to `http://localhost:5000/api` (`http://10.0.2.2:5000/api` on the Android
emulator). Point it elsewhere without code changes:

```bash
flutter run --dart-define=API_BASE_URL=https://your-api.example.com/api
```

## Tests

```bash
flutter analyze
flutter test
```

## How Authentication Works

1. **App start**: `AuthController.build()` reads the stored JWT and calls `GET /api/auth/me`.
   While that runs, the state is `AsyncLoading` and the router shows the splash screen.
2. **Login/Register**: `AuthService` posts credentials, saves the returned token in secure storage
   and the controller sets `AsyncData(user)`.
3. **Routing**: the router mirrors auth state into a `ValueNotifier` used as `refreshListenable`.
   Each change re-runs `redirect`, so screens never navigate after login/logout themselves.
4. **Every request**: a Dio interceptor adds `Authorization: Bearer <token>`.
5. **Expired/revoked token**: a 401 on an authenticated request triggers `onUnauthorized`, which
   clears the session and the router sends the user to login.
6. **Logout**: calls the backend (which revokes all tokens) and clears local storage.

## Project Structure

```
lib/
├── core/
│   ├── constants/    API base URL + endpoints
│   ├── exceptions/   ApiException (maps Dio errors + backend validation details)
│   ├── theme/        Material 3 theme
│   └── utils/        form validators (mirror backend rules)
├── models/           User, Employee, Department, EmployeeQuery, Paginated<T>
├── services/         api, auth, storage, employee, department services
├── providers/        Riverpod providers (services, auth, employees, departments)
├── routes/           GoRouter config + role guards
├── screens/
│   ├── auth/         splash, login, register, forgot/reset password
│   ├── dashboard/
│   ├── employees/    list, details, create/edit form
│   └── departments/
├── widgets/          shared UI components
├── app.dart
└── main.dart
```
