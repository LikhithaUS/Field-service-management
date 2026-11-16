# ServiceHub — Backend API

REST API for **ServiceHub**, an Employee & Field Service Management Platform.
Built with Node.js, Express 5, MongoDB (Mongoose), JWT authentication and role-based access control.

> Status: authentication (incl. forgot/reset password), **employees**, **departments**, **tasks**
> (with comments) and **attendance** are complete. Leaves, notifications and dashboard modules are coming next.

## Tech Stack

| Concern | Choice |
|---|---|
| Runtime / framework | Node.js 20+, Express 5 |
| Database | MongoDB Atlas via Mongoose |
| Auth | JWT (`jsonwebtoken`), bcrypt password hashing (`bcryptjs`) |
| Validation | `express-validator` |
| Security | `helmet`, `cors`, `express-rate-limit` on auth routes |
| Testing | Jest, Supertest, `mongodb-memory-server` |

## Getting Started

```bash
npm install
cp .env.example .env      # then fill in MONGODB_URI and JWT_SECRET
npm run seed:admin        # creates the first admin from ADMIN_* vars
npm run seed:departments  # optional: IT, HR, Finance, Marketing, Sales, Operations
npm run dev               # starts on http://localhost:5000 with auto-reload
```

Generate a JWT secret:

```bash
node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"
```

## Scripts

| Script | Description |
|---|---|
| `npm run dev` | Start with auto-reload (`node --watch`) |
| `npm start` | Start in production mode |
| `npm test` | Run the Jest test suite against an in-memory MongoDB |
| `npm run seed:admin` | Create the first admin account |
| `npm run seed:departments` | Create the default departments |

## Environment Variables

See [`.env.example`](.env.example). The real `.env` is git-ignored and must never be committed.

| Variable | Required | Description |
|---|---|---|
| `MONGODB_URI` | ✅ | MongoDB Atlas connection string |
| `JWT_SECRET` | ✅ | Secret used to sign tokens |
| `JWT_EXPIRES_IN` | | Token lifetime (default `1d`) |
| `PORT` | | Default `5000` |
| `CORS_ORIGINS` | | Comma-separated allowed origins (default `*`) |
| `BCRYPT_SALT_ROUNDS` | | Default `10` |
| `APP_TIMEZONE` | | Company time zone for attendance (default `Asia/Kolkata`) |
| `WORK_START_TIME` | | `HH:mm`; checking in after this is *late* (default `09:30`) |
| `HALF_DAY_HOURS` | | Working fewer hours is a *half day* (default `4`) |

## API

All responses share one shape:

```json
{ "success": true, "data": { ... } }
{ "success": false, "message": "Validation failed", "details": [{ "field": "email", "message": "..." }] }
```

### Auth

| Method | Endpoint | Access | Description |
|---|---|---|---|
| GET | `/api/health` | Public | Health check |
| POST | `/api/auth/register` | Public | Register (always creates an `employee`) |
| POST | `/api/auth/login` | Public | Returns `{ token, user }` |
| POST | `/api/auth/logout` | Authenticated | Revokes all of the user's existing tokens |
| GET | `/api/auth/me` | Authenticated | Current user |
| POST | `/api/auth/forgot-password` | Public | Emails a 6-digit code (same response whether or not the email exists) |
| POST | `/api/auth/reset-password` | Public | `{ email, code, password }`; sets password, revokes old sessions, returns `{ token, user }` |

Protected requests send `Authorization: Bearer <token>`.

### Departments

| Method | Endpoint | Access | Description |
|---|---|---|---|
| GET | `/api/departments` | Authenticated | All departments with `employeeCount` |
| GET | `/api/departments/:id` | Authenticated | One department |
| POST | `/api/departments` | Admin | Create (`name` unique, case-insensitive) |
| PUT | `/api/departments/:id` | Admin | Update |
| DELETE | `/api/departments/:id` | Admin | Delete (409 while employees are assigned) |

### Employees

| Method | Endpoint | Access | Description |
|---|---|---|---|
| GET | `/api/employees` | Admin, Manager | `?search=&department=<id\|none>&role=&status=&sort=&page=&limit=` |
| GET | `/api/employees/:id` | Admin, Manager | One employee (department populated) |
| POST | `/api/employees` | Admin, Manager | Creates the record **and** login account; emails a setup code |
| PUT | `/api/employees/:id` | Admin, Manager | Update; syncs name/email/role/status to the login account |
| DELETE | `/api/employees/:id` | Admin | Deletes the record and login account |

List responses: `{ items: [...], pagination: { page, limit, total, totalPages } }`.

**Business rules**

- Managers can only create/edit users with the `employee` role and cannot change roles or delete.
- Admins cannot change their own role, deactivate themselves or delete themselves.
- Setting `status: inactive` blocks login and revokes the person's sessions immediately.
- Creating an employee whose email belongs to a self-registered account links that account
  instead of creating a second one.

### Tasks

| Method | Endpoint | Access | Description |
|---|---|---|---|
| GET | `/api/tasks` | Authenticated | `?search=&status=&priority=&assignedTo=&mine=true&overdue=true&sort=&page=&limit=` |
| GET | `/api/tasks/:id` | Staff, or the assignee | One task with `assignedTo`/`assignedBy` populated and `commentCount` |
| POST | `/api/tasks` | Admin, Manager | Create; gets a sequential `taskNumber` (`TSK-0001`) |
| PUT | `/api/tasks/:id` | Staff, or the assignee | Staff edit anything; the assignee can only change `status` |
| DELETE | `/api/tasks/:id` | Admin, Manager | Deletes the task and its comments |
| GET | `/api/tasks/:id/comments` | Staff, or the assignee | Thread, oldest first, with each author |
| POST | `/api/tasks/:id/comments` | Staff, or the assignee | `{ message }` (1–1000 chars) |

- Statuses: `pending`, `in_progress`, `completed`, `cancelled`. Priorities: `low`, `medium`, `high`, `urgent`.
- `sort`: `createdAt`, `dueDate`, `title` (prefix `-` for descending; default `-createdAt`).

**Business rules**

- Employees only ever see tasks assigned to them; `assignedTo` filters are ignored for them, and
  someone else's task returns **404** (not 403), so its existence isn't revealed.
- The assignee may move between `pending`, `in_progress` and `completed`, but cannot cancel a task
  or change a cancelled one.
- `completedAt` is set automatically when a task becomes `completed` and cleared if it is reopened.
- A task is **overdue** when it is still open and its due date is before today. Due dates are
  stored as midnight UTC of the chosen day.
- Tasks can only be assigned to active accounts. Assignees reference **users** (login accounts),
  because permissions are checked against the signed-in user.

### Attendance

| Method | Endpoint | Access | Description |
|---|---|---|---|
| GET | `/api/attendance/today` | Authenticated | `{ date, attendance \| null, rules }` for the signed-in user |
| POST | `/api/attendance/check-in` | Authenticated | Creates today's record (409 if already checked in) |
| POST | `/api/attendance/check-out` | Authenticated | Sets `checkOut` and `workingMinutes` (400 before check-in, 409 if done) |
| GET | `/api/attendance` | Authenticated | `?from=YYYY-MM-DD&to=&user=&status=&page=&limit=` plus a `summary` of the whole range |

- Statuses: `present`, `late`, `half_day`, `absent`, `leave`.
- Employees always get their own history; staff see everyone and can filter by `user`.
- The **work day** is the calendar date in `APP_TIMEZONE`, so results don't depend on the server's
  location. It is stored as midnight UTC.
- Check-in after `WORK_START_TIME` → `late`. Check-out with less than `HALF_DAY_HOURS` worked →
  `half_day` (this also overrides `late`).
- A unique `(user, date)` index prevents double check-ins, even under concurrent requests.
- No scheduled job writes `absent` yet: a day without a record counts as absent. `leave` will be
  written by the leave module.

## Password Reset & Account Setup

One mechanism serves both "forgot password" and new employees choosing their first password:

- A 6-digit code from `crypto.randomInt` is emailed; only an **HMAC-SHA256** of it is stored
  (a plain hash of 6 digits could be brute-forced from a DB leak).
- Reset codes expire after 15 minutes, setup codes after 3 days. Codes are single-use and locked
  after 5 wrong attempts. They are compared with `crypto.timingSafeEqual`.
- A successful reset bumps `tokenVersion`, signing out every other session.
- **Email transport:** currently *console*, so emails are printed to the server log.
  `src/services/email.service.js` is the single place to plug in SMTP (Nodemailer) or Resend later.

## Authentication & RBAC Design

- **Password hashing**: a Mongoose `pre('save')` hook hashes with bcrypt; the `password` field is
  `select: false`, so it is never returned by queries.
- **JWT**: the payload contains `sub` (user id), `role` and `tv` (token version).
- **Logout / revocation**: JWTs are stateless, so each user has a `tokenVersion`. Logout increments it,
  and `protect` rejects any token whose `tv` doesn't match. This logs out every device.
- **Roles**: `admin`, `manager`, `employee`. Routes are guarded with
  `protect, authorize('admin', 'manager')`. Public registration can never assign a role; admins
  are created with `npm run seed:admin`.
- **Errors**: Express 5 forwards async errors automatically; a central handler maps `ApiError`,
  Mongoose validation/duplicate-key/cast errors and malformed JSON to consistent JSON responses.

## Project Structure

```
src/
├── config/        env loading + MongoDB connection
├── controllers/   request handlers
├── middleware/    auth (protect/authorize), validation, error handling
├── models/        Mongoose schemas
├── routes/        route definitions
├── services/      reusable logic (JWT)
├── utils/         ApiError, roles
├── validators/    express-validator rule sets
├── scripts/       one-off scripts (seed admin)
├── app.js         Express app (importable by tests)
└── server.js      starts the HTTP server
tests/             Jest + Supertest
```
