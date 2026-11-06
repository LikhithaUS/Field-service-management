# ServiceHub — Backend API

REST API for **ServiceHub**, an Employee & Field Service Management Platform.
Built with Node.js, Express 5, MongoDB (Mongoose), JWT authentication and role-based access control.

> Status: **Phase 1 — project setup + authentication** is complete. Employees, departments, tasks,
> attendance, leaves, notifications and dashboard modules are coming next.

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
npm run seed:admin        # optional: creates the first admin from ADMIN_* vars
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

Protected requests send `Authorization: Bearer <token>`.

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
