# ServiceHub — Flutter App

Cross-platform client (Android, iOS, Web, Windows) for **ServiceHub**, an Employee & Field Service
Management Platform. Talks to the Node.js/Express backend in `../../backend`.

> Status: authentication (login, register, forgot/reset password, session restore), a role-aware
> dashboard, **Employees** (list with search/filters/pagination, details, create/edit/delete) and
> **Departments** (admin CRUD) are complete.

## Screens

| Screen | Who |
|---|---|
| Splash, Login, Register, Forgot password, Reset password | Everyone |
| Dashboard | Signed-in users (tiles differ by role) |
| Employees list / details / create / edit | Admin, Manager (managers can't delete or assign roles) |
| Departments | Admin |

Role rules are enforced by the backend; the app mirrors them (router guards and hidden buttons)
so users never see actions that would fail.

**New employee onboarding:** when an admin/manager creates an employee, the backend emails a setup
code (printed to the backend console for now). The employee opens the app, taps
*Forgot password?* → *I already have a code*, and sets their password.

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
