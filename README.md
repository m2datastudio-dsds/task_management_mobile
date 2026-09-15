# Task Mobile

Flutter mobile frontend for the existing React/Node/Express/Prisma Task Management app.

## Web App Review Used

- Frontend: `m2task-frontend-main`
- API base in web: `http://localhost:5000/api`
- Auth flow: `POST /auth/login`, persist JWT, send `Authorization: Bearer <token>`
- Main web routes: Dashboard, My Tasks, Task Management, Organizations, Users, Roles
- Visual style: blue primary actions, gray workspace background, white 8px cards, dark sidebar navigation, compact admin layouts
- Roles: `super_admin`, `admin`, `employee`, `intern`

## Mobile Structure

```text
lib/
  models/
  providers/
  screens/
  services/
  utils/
  widgets/
```

## Run

If native platform folders do not exist yet, run this once from `task-mobile`:

```bash
flutter create . --platforms=android,ios
```

Then:

```bash
flutter pub get
flutter run --dart-define API_BASE_URL=http://10.0.2.2:5000/api
```

Use `http://10.0.2.2:5000/api` for Android emulator, `http://localhost:5000/api` for desktop, and your computer LAN IP for a physical phone.
