# ServiceHub — Flutter App

Cross-platform client (Android, iOS, Web, Windows) for **ServiceHub**, an Employee & Field Service
Management Platform. Talks to the Node.js/Express backend in `../../backend`.

> Status: **Phase 2 — app foundation + authentication** is complete: splash, login, register,
> session restore, logout and a role-aware dashboard placeholder.

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
├── models/           User, UserRole
├── services/         api_service, auth_service, storage_service
├── providers/        Riverpod providers (services, auth state)
├── routes/           GoRouter config
├── screens/
│   ├── auth/         splash, login, register
│   └── dashboard/
├── widgets/          shared UI components
├── app.dart
└── main.dart
```
