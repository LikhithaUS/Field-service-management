# ServiceHub — Employee & Field Service Management

Full-stack portfolio project: a cross-platform **Flutter** app (Android, iOS, Web, Windows) backed by a
**Node.js / Express / MongoDB** REST API with JWT authentication and role-based access control.

| Folder | What | Docs |
|---|---|---|
| [`backend/`](backend) | REST API — Express 5, Mongoose, JWT, RBAC, Jest tests | [backend/README.md](backend/README.md) |
| [`frontend/fsm_app/`](frontend/fsm_app) | Flutter app — Riverpod, Dio, GoRouter, Material 3 | [frontend/fsm_app/README.md](frontend/fsm_app/README.md) |

## Features so far

- Authentication: register, login, logout (token revocation), forgot / reset password
- Roles: **admin**, **manager**, **employee**, enforced by the API and mirrored in the app
- Employees & departments: search, filters, pagination, onboarding with emailed setup codes
- Tasks: assignment, priorities, due dates, status workflow, overdue tracking, comment threads
- Attendance: check-in / check-out, late & half-day rules, monthly history, team report

Coming next: leave management, notifications, announcements, dashboard charts, file uploads.

## Quick start

```bash
# 1. API
cd backend
npm install
cp .env.example .env        # fill in MONGODB_URI and JWT_SECRET
npm run seed:admin
npm run dev                 # http://localhost:5000

# 2. App (in another terminal)
cd frontend/fsm_app
flutter pub get
flutter run -d chrome
```
