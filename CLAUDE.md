# PlayMaker JO — Platform Index

## What this is
PlayMaker JO is a multi-sport venue booking platform for the Jordanian market (currency **JOD**, phone prefix **+962**).
Players discover and book venues through a Flutter mobile app; venue owners and admins manage venues, bookings,
and payments through a React dashboard; a marketing website fronts the platform. Everything talks to one
ASP.NET Core 9 Web API backed by MySQL. Payments run via CliQ (player uploads a transfer-proof screenshot,
owner approves/rejects) with a **5% platform fee** on every booking. The whole platform is bilingual **EN/AR with RTL**.

This folder is the **deploy repo** (`playmakerjo-deploy`) — it holds docker-compose, nginx config, and runbooks.
The four source repos are cloned side-by-side inside it.

---

## The 5 repositories

All under **https://github.com/mohammed-alfaris/**:

| Folder | GitHub repo | Branch | Tech | Details |
|---|---|---|---|---|
| *(this root)* | `playmakerjo-deploy` | `master` | docker-compose + nginx + runbooks | `DEPLOY.md` |
| `playmakerjo-api/` | `playmakerjo-api` | `master` | ASP.NET Core 9 + EF Core 9 + MySQL 8 | `playmakerjo-api/CLAUDE.md` |
| `playmakerjo-dashboard/` | `playmakerjo-dashboard` | `master` | React 19 + Vite + TS (admin dashboard) | `playmakerjo-dashboard/CLAUDE.md` |
| `playmakerjo-website/` | `playmakerjo-website` | `main` | React 19 + Vite + TS (marketing site) | — |
| `playmakerjo-app/` | `playmakerjo-app` | `master` | Flutter 3 + Dart + Riverpod (mobile) | `playmakerjo-app/CLAUDE.md` |

Each subrepo's own `CLAUDE.md` is the source of truth for its structure, commands, and conventions —
don't duplicate that detail here.

---

## Where to look

| File | Purpose |
|---|---|
| `START-HERE.md` | Project guide — what everything is, how to run the full stack locally |
| `DEPLOY.md` | Production runbook — server setup, SSL, hardening, backups, common ops |
| `SECRETS.md` + `_SECRETS/` | All credentials & key files — **local only, never committed** |

Production: API at `https://api.playmakerjo.com`, dashboard at `https://admin.playmakerjo.com`,
website at `https://playmakerjo.com` — all on one VPS via Docker Compose behind Nginx + Certbot.

---

## Cross-repo conventions

- All API endpoints return the `ApiResponse<T>` envelope — JSON fields are **camelCase**, DB columns are **snake_case**.
- Roles: `super_admin`, `venue_owner`, `venue_staff`, `player`. Dashboard is for admin + owner; app is for player + owner.
- Venue images, avatars, and payment proofs are **files on disk** under `wwwroot/uploads/`, served statically by the API — NOT base64 in the DB.
- Auth: JWT access token (15 min, `Authorization: Bearer`) + refresh token in an httpOnly cookie.
- Owner scoping is **enforced server-side** — a logged-in `venue_owner` only ever gets their own venues/bookings/stats.
- Revenue split: 5% platform fee, owner gets 95% (`system_fee` / `owner_amount` on Booking).
- EN/AR everywhere: dashboard uses a custom `useT()` context, app uses ARB files (`flutter gen-l10n`), both flip to RTL.

---

## Deploy in one breath

After pushing the change to GitHub:

```bash
ssh root@178.104.136.20
cd /opt/playmakerjo/playmakerjo-api      # or playmakerjo-dashboard / playmakerjo-website
git pull
cd /opt/playmakerjo
docker compose up -d --build api         # or dashboard / website
docker compose logs -f api               # EF migrations auto-apply on startup
```

The Flutter app is not server-deployed — build the APK against prod:

```bash
cd playmakerjo-app
flutter build apk --release --dart-define=API_BASE_URL=https://api.playmakerjo.com/api/v1
```
