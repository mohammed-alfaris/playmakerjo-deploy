# Sports Venue — Admin Dashboard

## Project overview
React admin dashboard for a multi-sport public venue management platform.
Used by `super_admin` (full access) and `venue_owner` (scoped to own venues/bookings/revenue).
Primary market: **Jordan 🇯🇴** — default currency JOD, default phone prefix +962. Built for future multi-country expansion.

---

## Tech stack
| Layer | Technology |
|-------|-----------|
| Framework | React 19 + Vite 8 + TypeScript |
| UI | shadcn/ui (New York style, slate) + Tailwind CSS v3 |
| Routing | React Router v7 |
| Server state | TanStack Query v5 |
| Tables | TanStack Table |
| Forms | React Hook Form + Zod |
| Charts | Recharts + react-is |
| HTTP | Axios (JWT interceptor) |
| Global state | Zustand (auth only) |
| Backend | ASP.NET Core 9 Web API + EF Core 9 + MySQL (see `sports-venue-api/CLAUDE.md`) |
| Mock API | MSW v2 (available for offline dev, currently disabled) |

---

## Project structure
```
sports-venue-dashboard/
├── src/
│   ├── api/
│   │   ├── axios.ts          # Axios instance + request/response interceptors
│   │   ├── auth.ts           # login, logout, refreshToken — AuthUser includes avatar?
│   │   ├── venues.ts         # getVenues, getVenue, getVenueStats, createVenue, updateVenue, deleteVenue
│   │   ├── users.ts          # getUsers, updateUserStatus, updateUserRole, updateUserAvatar
│   │   ├── bookings.ts       # getBookings
│   │   ├── payments.ts       # getPayments
│   │   └── reports.ts        # getSummary, getRevenueChart, getTopVenues, getSportsBreakdown, exportReport
│   ├── components/
│   │   ├── ui/               # shadcn/ui components (don't edit manually)
│   │   └── shared/
│   │       ├── AppLayout.tsx     # ✅ Sidebar + header — role-aware nav + avatar + dark/lang toggles
│   │       ├── StatCard.tsx      # ✅ KPI card with trend arrow + skeleton
│   │       ├── PageHeader.tsx    # ✅ title + subtitle + action slot
│   │       ├── StatusBadge.tsx   # ✅ color-coded status badge (reused everywhere)
│   │       ├── DataTable.tsx     # ✅ reusable TanStack Table
│   │       └── ConfirmDialog.tsx # ✅ delete/ban confirmation
│   ├── features/
│   │   ├── auth/
│   │   │   └── LoginPage.tsx         # ✅ email + password, super_admin + venue_owner
│   │   ├── dashboard/
│   │   │   ├── DashboardPage.tsx     # ✅ KPIs + charts + recent bookings (role-aware)
│   │   │   ├── RevenueChart.tsx      # ✅ Recharts LineChart, 30 days
│   │   │   ├── TopVenuesChart.tsx    # ✅ Recharts BarChart horizontal
│   │   │   ├── SportsPieChart.tsx    # ✅ Recharts PieChart donut
│   │   │   └── RecentBookingsTable.tsx # ✅ last 10 bookings (owner-scoped)
│   │   ├── venues/
│   │   │   ├── VenuesPage.tsx        # ✅ role-scoped + thumbnail column
│   │   │   ├── VenueDetailPage.tsx   # ✅ image gallery + map link + stats + bookings
│   │   │   └── VenueFormDialog.tsx   # ✅ file upload (drag&drop) + lat/lng + owner lock
│   │   ├── users/
│   │   │   └── UsersPage.tsx         # ✅ avatar upload + ban/activate + role change
│   │   ├── bookings/
│   │   │   └── BookingsPage.tsx      # ✅ role-scoped + status/date/venue filters
│   │   ├── payments/
│   │   │   └── PaymentsPage.tsx      # ✅ super_admin only
│   │   └── reports/
│   │       └── ReportsPage.tsx       # ✅ role-scoped + CSV/PDF export
│   ├── i18n/
│   │   ├── translations.ts    # ✅ all EN + AR string pairs (flat dict, ~150 keys)
│   │   └── LanguageContext.tsx # ✅ LanguageProvider + useT() hook
│   ├── hooks/
│   │   ├── useAuth.ts         # thin wrapper over useAuthStore
│   │   ├── useRole.ts         # ✅ useRole() + useOwnerFilter()
│   │   └── usePagination.ts   # page + limit state helper
│   ├── lib/
│   │   ├── utils.ts           # cn() helper
│   │   ├── formatters.ts      # formatCurrency (JOD), formatDate, formatDateTime, formatPhone (+962)
│   │   └── constants.ts       # COUNTRIES config, SPORTS, statuses, roles, DEFAULT_PAGE_SIZE
│   ├── mocks/                 # MSW mock API — delete when real backend is ready
│   │   ├── browser.ts         # setupWorker()
│   │   ├── handlers.ts        # all endpoint handlers — owner_id scoping
│   │   └── data.ts            # mock users (with avatars), venues (with images + coords), bookings, payments
│   ├── store/
│   │   └── authStore.ts       # Zustand: user, accessToken, isAuthenticated
│   ├── router.tsx             # ProtectedRoute + PublicRoute + AdminRoute + all routes
│   └── main.tsx               # QueryClientProvider + RouterProvider + LanguageProvider + MSW init
├── public/
│   └── mockServiceWorker.js   # MSW service worker (auto-generated)
├── .env
├── components.json            # shadcn/ui config
├── package.json
├── tailwind.config.ts
└── vite.config.ts
```

---

## Pages & routes

| Route | Page | Roles | Status | Key features |
|-------|------|-------|--------|-------------|
| `/login` | Login | all | ✅ Done | Email + password |
| `/` | Dashboard | admin + owner | ✅ Done | Admin: platform KPIs + charts. Owner: own KPIs only |
| `/venues` | Venues list | admin + owner | ✅ Done | Thumbnail, role-scoped, search + filters |
| `/venues/:id` | Venue detail | admin + owner | ✅ Done | Image gallery, map link, stats, bookings |
| `/users` | Users | **admin only** | ✅ Done | Avatar upload, ban/activate, inline role change |
| `/bookings` | Bookings | admin + owner | ✅ Done | Status + date range + venue filters, role-scoped |
| `/payments` | Payments | **admin only** | ✅ Done | Transactions, status filter |
| `/reports` | Reports | admin + owner | ✅ Done | Summary stats + CSV/PDF export, role-scoped |

---

## Auth flow
- Login → `POST /api/v1/auth/login` → store access token in Zustand (memory)
- Refresh token stored in httpOnly cookie
- Axios request interceptor: attach `Authorization: Bearer <token>` on every request
- Axios response interceptor: on 401 → `POST /api/v1/auth/refresh` → retry original request → on failure redirect to `/login`
- Concurrent 401 handling: `isRefreshing` flag + pending request queue
- `ProtectedRoute` — redirects to `/login` if not authenticated
- `PublicRoute` — redirects to `/` if already authenticated (wraps `/login`)
- `AdminRoute` — redirects to `/` if role is not `super_admin` (wraps `/users`, `/payments`)
- Allowed roles: `super_admin` and `venue_owner` — all other roles get "Access denied"

---

## Role-based views

### How it works
One codebase, two scoped experiences driven by the logged-in user's role.

```
super_admin  →  sees all data, all sidebar items
venue_owner  →  sees only their own venues/bookings/revenue, hidden: Users + Payments
```

### `useRole()` hook — `src/hooks/useRole.ts`
```ts
const { role, isAdmin, isOwner, userId } = useRole()
```

### `useOwnerFilter()` hook — same file
Returns `{ owner_id: userId }` when `venue_owner`, `{}` when `super_admin`.
Spread into every API call that supports owner scoping:
```ts
const ownerFilter = useOwnerFilter()
queryFn: () => getVenues({ page, limit, ...ownerFilter })
```

### Sidebar by role
| Nav item | super_admin | venue_owner |
|----------|:-----------:|:-----------:|
| Dashboard | ✅ | ✅ |
| Venues | ✅ all | ✅ own only |
| Users | ✅ | ❌ hidden |
| Bookings | ✅ all | ✅ own only |
| Payments | ✅ | ❌ hidden |
| Reports | ✅ all | ✅ own only |

### Dashboard by role
- `super_admin`: 4 KPI cards + RevenueChart + TopVenuesChart + SportsPieChart + recent bookings
- `venue_owner`: 3 KPI cards (My Venues, My Bookings, My Revenue) + recent bookings for own venues only

### VenueFormDialog by role
- `super_admin`: Owner select is open — can assign any venue_owner
- `venue_owner`: Owner field is pre-filled and disabled — can only create venues for themselves

---

## Venue data model

```ts
interface Venue {
  id: string
  name: string
  owner: { id: string; name: string }
  sports: string[]
  city: string
  address: string
  pricePerHour: number
  status: "active" | "inactive" | "pending"
  description?: string
  images?: string[]        // array of URLs or base64 data URIs (first = cover)
  latitude?: number        // GPS coordinates
  longitude?: number
  createdAt: string
}
```

### Image handling
- Form uses `FileReader.readAsDataURL()` to convert uploaded files to base64
- Up to **5 images** per venue, first image = cover shown in list + gallery hero
- Drag & drop or click-to-browse; thumbnails shown with × remove + "Cover" label
- Images stored as base64 data URIs in the database (JSON array on Venue model)
- Future improvement: replace with a `POST /upload` endpoint that returns URLs

### Location
- `latitude` + `longitude` stored as numbers
- Detail page shows "View on Map" button → opens Google Maps at exact coordinates
- Coordinates shown in the info card below the stats

---

## User data model

```ts
interface User {
  id: string
  name: string
  email: string
  phone: string
  role: string
  status: "active" | "banned"
  avatar?: string    // URL or base64 data URI
  createdAt: string
}

interface AuthUser {
  id: string
  name: string
  email: string
  role: string
  avatar?: string   // shown in header
}
```

### Avatar handling
- Click any avatar in the Users table → camera icon appears on hover → click opens file picker
- `FileReader.readAsDataURL()` converts the image to base64
- Calls `PATCH /users/:id/avatar` → updates the database + toast
- Header shows the logged-in user's avatar from `AuthUser`

---

## Backend connection

The frontend connects to a **.NET Core 9 Web API** backend with MySQL database. See `sports-venue-api/CLAUDE.md` for full backend documentation.

**Dev credentials:**
| Role | Email | Password |
|------|-------|----------|
| super_admin | admin@sportsvenue.jo | admin123 |
| venue_owner | khalid@venues.jo | owner123 |

Khalid Al-Natour (`u2`) owns: Al-Ameen Football Arena, Aqaba Beach Sports, Madaba Aqua Sports.

**Seed data:** 15 users (with DiceBear avatars), 8 venues (Jordan cities, real GPS coords, picsum images), 25 bookings, 20 payments.

### Running the full stack
```bash
# 1. Start the backend (from sports-venue-api/SportsVenueApi/)
dotnet run                    # runs on http://localhost:8000

# 2. Start the frontend (from sports-venue-dashboard/)
npm run dev                   # runs on http://localhost:5173
```

### Mock API (MSW) — optional fallback
MSW is still available for offline development:
1. Set `VITE_MOCK_API=true` in `.env` to use mocks
2. Set `VITE_MOCK_API=false` to use the real backend (current setting)
3. All axios/API code works identically with both modes

---

## API conventions
- Base URL from env: `VITE_API_URL=http://localhost:8000/api/v1`
- All requests: `Content-Type: application/json`
- Standard response envelope:
```json
{
  "success": true,
  "data": {},
  "message": "string",
  "pagination": { "page": 1, "limit": 20, "total": 100 }
}
```
- Timestamps: ISO 8601 UTC — display in local timezone
- Currency: `formatCurrency()` from `lib/formatters.ts` — defaults to **JOD**

---

## Key API endpoints
```
Auth
  POST   /auth/login
  POST   /auth/refresh
  POST   /auth/logout

Dashboard
  GET    /reports/summary?owner_id=          ← owner_id optional, scopes to owner
  GET    /reports/revenue-chart?days=30
  GET    /reports/top-venues
  GET    /reports/sports-breakdown

Venues
  GET    /venues?page=&limit=&search=&sport=&status=&owner_id=
  POST   /venues                              ← body includes images[], latitude, longitude
  GET    /venues/:id
  PATCH  /venues/:id
  DELETE /venues/:id
  GET    /venues/:id/stats

Users
  GET    /users?page=&limit=&role=&search=
  PATCH  /users/:id/status                   ← { status: "active" | "banned" }
  PATCH  /users/:id/role                     ← { role: string }
  PATCH  /users/:id/avatar                   ← { avatar: string } (base64 or URL)

Bookings
  GET    /bookings?page=&limit=&status=&venue_id=&from=&to=&owner_id=

Payments
  GET    /payments?page=&limit=&status=

Reports
  GET    /reports/export?format=csv&from=&to=&venue_id=
  GET    /reports/export?format=pdf&from=&to=&venue_id=
```

---

## Shared components
| Component | Props | Status | Usage |
|-----------|-------|--------|-------|
| `AppLayout` | — | ✅ | Sidebar + header — role-aware nav, avatar, dark mode toggle, language toggle |
| `StatCard` | title, value, change?, icon, color, isLoading | ✅ | Dashboard + Reports KPIs |
| `PageHeader` | title, subtitle?, action? | ✅ | All pages |
| `StatusBadge` | status | ✅ | Color-coded + translated status badge |
| `DataTable` | columns, data, pagination, isLoading | ✅ | All list pages — translated pagination |
| `ConfirmDialog` | title, description, onConfirm, isLoading? | ✅ | Delete / ban — translated buttons |

---

## Status badge colors
| Status | Color |
|--------|-------|
| active / confirmed / paid | green |
| pending | amber |
| cancelled / banned / failed / inactive | red |
| refunded | purple |
| completed | blue |

---

## Country & currency config (`lib/constants.ts`)
```ts
// Expand this array as the platform grows to new markets
export const COUNTRIES = [
  { code: "JO", name: "Jordan", currency: "JOD", phonePrefix: "+962", locale: "ar-JO" },
  // { code: "SA", ... }, { code: "AE", ... }, { code: "KW", ... }
]
export const DEFAULT_COUNTRY  = COUNTRIES[0]   // Jordan
export const DEFAULT_CURRENCY = "JOD"
export const DEFAULT_PHONE_PREFIX = "+962"
```
All formatters use `DEFAULT_CURRENCY` — never hardcode "SAR".

---

## User roles
| Role | Arabic | Dashboard access |
|------|--------|-----------------|
| `super_admin` | سوبر أدمن | Yes — full platform access |
| `venue_owner` | صاحب ملعب | Yes — scoped to own venues/bookings/revenue |
| `venue_staff` | مشرف ملعب | No |
| `player` | لاعب | No |

---

## Code conventions
- `cn()` from `lib/utils.ts` for all conditional classNames
- TanStack Query for ALL server state — no useState for API data
- React Hook Form + Zod for ALL forms — schema defined before the component
- Use `z.number()` with `register("field", { valueAsNumber: true })` — NOT `z.coerce.number()` (causes Resolver type mismatch)
- Use `z.number({ error: "..." })` NOT `z.number({ invalid_type_error: "..." })` — Zod v4 syntax
- TanStack Table with server-side pagination — pass `page` and `limit` as query params
- All API functions in `src/api/` — never call axios directly from components
- Mutations: `useMutation` + `onSuccess` toast (sonner) + `queryClient.invalidateQueries()`
- Skeleton loaders on every data-fetching component (shadcn Skeleton)
- Empty state when table/list has zero results
- Tailwind classes only — no inline styles
- `StatusBadge` for every status field — never inline badge colors
- Role scoping via `useOwnerFilter()` — spread into API call params, never hardcode role checks in queries
- File uploads: `FileReader.readAsDataURL()` converts to base64, stored directly in database
- **i18n**: use `const { t, lang } = useT()` from `@/i18n/LanguageContext` — NEVER hardcode visible UI strings, always use `t("key")`
- **Constants with Arabic labels**: `SPORTS`, `VENUE_STATUSES`, `BOOKING_STATUSES`, `PAYMENT_STATUSES`, `USER_STATUSES`, `USER_ROLES` all have `labelAr` — use `lang === "ar" ? s.labelAr : s.label` when rendering them

---

## Environment variables
```env
VITE_API_URL=http://localhost:8000/api/v1
VITE_MOCK_API=false         # set to true to use MSW mocks for offline dev
```

---

## Commands
```bash
npm install
npm run dev
npm run build
npm run typecheck
# Add shadcn component (use v2 CLI for Tailwind v3 compatibility):
printf "\n" | npx shadcn@2.3.0 add <component> -y
```

> ⚠️ Use `shadcn@2.3.0` not `shadcn@latest` — latest (v4) requires Tailwind v4.
> After adding components, verify they land in `src/components/ui/` not `@/`.

---

## Build order & status
| Step | Description | Status |
|------|-------------|--------|
| 1 | Project setup + dependencies + sidebar layout | ✅ Done |
| 2 | Axios interceptors + Zustand auth + LoginPage + ProtectedRoute | ✅ Done |
| 2b | MSW mock API (all endpoints) | ✅ Done |
| 3 | Dashboard overview (KPIs + 3 charts + recent bookings) | ✅ Done |
| 4 | DataTable + Venues CRUD (list, form dialog, detail page) | ✅ Done |
| 4b | Role-based views (venue_owner scoped access) | ✅ Done |
| 5 | Users, Bookings, Payments, Reports pages | ✅ Done |
| 6 | Venue images (file upload) + GPS coordinates + user avatars | ✅ Done |
| 7 | Design System — slate palette, brand color, Outfit+Inter fonts, dark mode default + toggle | ✅ Done |
| 8 | Bilingual (AR/EN) + RTL — custom i18n context, all pages translated, Cairo font | ✅ Done |
| 9 | .NET Core 9 backend — ASP.NET Core Web API + EF Core + MySQL | ✅ Done |
| 10 | Frontend connected to real backend (VITE_MOCK_API=false) | ✅ Done |

---

## Design system

### Colors
- Base palette: **slate** (shadcn/ui `baseColor: "slate"` in `components.json`)
- Dark mode: **default** — `class="dark"` on `<html>`, toggled via button in header, persisted to `localStorage("theme")`
- CSS variables in `src/index.css` (both `:root` light and `.dark` dark variants):

```css
--brand: 142 72% 29%;           /* emerald green — primary action color */
--brand-foreground: 0 0% 100%;
--surface: 222 47% 11%;         /* dark card background (dark mode only) */
--surface-raised: 222 47% 14%;  /* elevated card (dark mode only) */
```

- Tailwind color tokens: `bg-brand`, `text-brand-foreground`, `bg-surface`, `bg-surface-raised`

### Typography
Fonts loaded via Google Fonts in `src/index.css`:
- **Outfit** → `font-display` — used on sidebar logo, page titles
- **Inter** → `font-body` (default body font, set on `body` element)
- **Cairo** → active automatically when `dir="rtl"` — supports Arabic + Latin

---

## i18n & Bilingual support (AR / EN)

### Architecture
Lightweight custom context — no external library.

```
src/i18n/
├── translations.ts      # flat dict: { en: { key: "..." }, ar: { key: "..." } }
└── LanguageContext.tsx  # LanguageProvider + useT() hook
```

### Usage in components
```ts
import { useT } from "@/i18n/LanguageContext"

const { t, lang, setLang } = useT()

// Translate a key
<Button>{t("add_venue")}</Button>

// Render constants with Arabic labels
{lang === "ar" ? sport.labelAr : sport.label}
```

### Language toggle
- **"ع" / "EN"** button in the header — switches language and flips layout
- Persisted to `localStorage("lang")` — default is `"en"`
- On switch: sets `document.documentElement.dir` (`"rtl"` / `"ltr"`) and `lang` attribute

### RTL behavior
- Setting `dir="rtl"` on `<html>` handles most layout flipping automatically (text alignment, flex direction, borders)
- Cairo font loads automatically for Arabic via `[dir="rtl"] body { font-family: 'Cairo' }`
- All pages, shared components, DataTable pagination, StatusBadge, and ConfirmDialog are fully translated

### Adding new strings
1. Add the key + English value to `translations.en` in `src/i18n/translations.ts`
2. Add the Arabic translation to `translations.ar`
3. The TypeScript type `TranslationKey` is auto-derived — missing keys cause a compile error

---

## UI Improvement Roadmap

> هذه التحسينات مقسّمة على أجزاء مستقلة — ابدأ بأي جزء تريد دون الحاجة لإكمال الباقي أولاً.

---

### Part 1 — Design System & Visual Identity ✅ Done

~~**المشكلة:** shadcn/ui بدون تخصيص يبدو generic جداً — كل dashboard يبدو متطابق.~~

**مكتمل:** slate palette + brand color + Outfit/Inter/Cairo fonts + dark mode default + Sun/Moon toggle. انظر قسم **Design system** أعلاه للتفاصيل الكاملة.

<!-- original notes kept for reference:
**المشكلة:** shadcn/ui بدون تخصيص يبدو generic جداً — كل dashboard يبدو متطابق.

**التحسينات:**

**1.1 — Custom color palette in `tailwind.config.ts`**
- استبدل zinc بـ palette مخصص يعكس الرياضة: ألوان داكنة كـ `slate-950` للخلفية الرئيسية + لون accent نابض (أخضر زمردي أو برتقالي).
- أضف CSS variables في `globals.css`:
```css
:root {
  --brand: 142 72% 29%;          /* emerald-700 — اللون الرئيسي */
  --brand-foreground: 0 0% 100%;
  --surface: 222 47% 11%;        /* خلفية البطاقات */
  --surface-raised: 222 47% 14%;
}
```

**1.2 — Dark mode أولاً**
- لوحات التحكم الاحترافية (Vercel, Linear, Grafana) كلها dark-first.
- في `tailwind.config.ts` اضبط `darkMode: 'class'` وأضف زر toggle في الـ header.
- يضيف احترافية فورية بدون أي تعديل على المنطق.

**1.3 — Typography upgrade**
```bash
# أضف Google Fonts في index.html
# Geist (Vercel) أو Outfit للعناوين + Inter للجسم
```
```css
@import url('https://fonts.googleapis.com/css2?family=Outfit:wght@400;600;700&family=Inter:wght@400;500&display=swap');
```
في `tailwind.config.ts`:
```ts
fontFamily: {
  display: ['Outfit', 'sans-serif'],
  body: ['Inter', 'sans-serif'],
}
```
استخدم `font-display` على العناوين الكبيرة فقط (KPI values, page titles).

**ملفات تُعدَّل:** `tailwind.config.ts`, `src/index.css`, `components.json`
-->

---

### Part 2 — Sidebar & Navigation (الشريط الجانبي)

**المشكلة:** الـ sidebar الافتراضي flat وبدون عمق بصري.

**التحسينات:**

**2.1 — Sidebar collapsible (icon-only mode)**
- أضف زر toggle يُخفي النصوص ويبقي الأيقونات فقط (عرض 64px).
- احفظ الحالة في `localStorage` أو Zustand.
- يوفّر مساحة شاشة ويبدو أكثر احترافية.

```tsx
// في AppLayout.tsx
const [collapsed, setCollapsed] = useLocalStorage('sidebar-collapsed', false)
// width: collapsed ? 'w-16' : 'w-64'
// النصوص: collapsed ? 'hidden' : 'block'
```

**2.2 — Active state أوضح**
```tsx
// بدل الـ default shadcn active — استخدم:
className={cn(
  "relative flex items-center gap-3 px-3 py-2 rounded-lg transition-all",
  isActive
    ? "bg-brand/10 text-brand font-medium before:absolute before:left-0 before:top-2 before:bottom-2 before:w-0.5 before:bg-brand before:rounded-full"
    : "text-muted-foreground hover:text-foreground hover:bg-muted/50"
)}
```

**2.3 — User card في أسفل الـ sidebar**
- بدل عرض المستخدم في الـ header فقط — أضف بطاقة صغيرة في أسفل الـ sidebar تعرض الاسم والدور والأفاتار.
- زر logout واضح بجانبها.

**2.4 — Sidebar sections / groups**
```tsx
// قسّم الـ nav إلى مجموعتين:
// [Main] Dashboard, Venues, Bookings
// [Management] Users, Payments, Reports
// أضف label صغير فوق كل مجموعة
```

**ملفات تُعدَّل:** `src/components/shared/AppLayout.tsx`

---

### Part 3 — Dashboard Page (الصفحة الرئيسية)

**المشكلة:** الـ KPI cards والـ charts أساسية جداً.

**التحسينات:**

**3.1 — StatCard upgrade**
```tsx
// أضف للـ StatCard:
// - gradient خلفية خفيف بلون الأيقونة
// - sparkline صغير (7 نقاط) بجانب الـ trend
// - animate-in عند أول load (count-up animation)
interface StatCard {
  // أضف:
  sparkline?: number[]   // آخر 7 قيم للرسم السريع
  prefix?: string        // "JOD" أمام الرقم
}
```

**3.2 — Chart headers موحدة**
- كل chart تأخذ `ChartCard` wrapper مع:
  - عنوان + subtitle
  - زر "..." لـ dropdown (export, fullscreen, date range)
  - حالة loading/empty موحدة
```tsx
// src/components/shared/ChartCard.tsx — component جديد
<ChartCard title="Revenue" subtitle="Last 30 days" onExport={...}>
  <RevenueChart />
</ChartCard>
```

**3.3 — Date range quick filters**
```tsx
// فوق الـ charts — أضف pill buttons:
// [7D] [30D] [90D] [This Year]
// تمرر الـ days param للـ API
```

**3.4 — Recent Bookings → Activity Feed**
- بدل جدول عادي — حوّله لـ feed بسيط:
- كل booking = صف مع أيقونة الرياضة + اسم الملعب + الوقت relative ("2 hours ago") + badge.

**3.5 — "Quick Actions" section (super_admin فقط)**
```tsx
// بطاقة صغيرة بأزرار سريعة:
// [+ Add Venue] [+ Add User] [Export Report]
// تختصر الـ navigation
```

**ملفات تُعدَّل:** `src/features/dashboard/`, `src/components/shared/StatCard.tsx`

---

### Part 4 — Data Tables (الجداول)

**المشكلة:** الجداول تبدو flat وبدون شخصية.

**التحسينات:**

**4.1 — Row hover state واضح**
```tsx
// في DataTable.tsx
<tr className="border-b transition-colors hover:bg-muted/30 cursor-pointer">
```

**4.2 — Column visibility toggle**
- أضف زر "Columns" في الـ toolbar يفتح dropdown لإخفاء/إظهار أعمدة.
- TanStack Table يدعم هذا built-in عبر `column.getToggleVisibilityHandler()`.

**4.3 — Bulk actions**
- Checkbox على كل صف + header checkbox للـ select all.
- عند التحديد: تظهر action bar في الأسفل (أو الأعلى) مع أزرار: Export Selected, Change Status.
- مفيد جداً في Users و Bookings.

**4.4 — Filters bar أوضح**
```tsx
// بدل وضع الفلاتر inline مع الـ table
// أضف FilterBar component:
// [Search input] [Status ▾] [Sport ▾] [Date Range ▾] [Clear filters × ]
// عدد الفلاتر النشطة يظهر كـ badge على زر "Filters"
```

**4.5 — Empty state مخصص لكل جدول**
```tsx
// بدل نص عادي "No results"
// أيقونة + رسالة + action button مناسبة:
// Venues: "No venues yet" + [+ Add Venue]
// Bookings: "No bookings found" + [Clear filters]
```

**ملفات تُعدَّل:** `src/components/shared/DataTable.tsx`, كل page فيها جدول

---

### Part 5 — Venue Detail Page (صفحة تفاصيل الملعب)

**المشكلة:** الصفحة تعرض المعلومات لكن بدون تنظيم بصري مميز.

**التحسينات:**

**5.1 — Hero section**
```tsx
// أعلى الصفحة: صورة غلاف full-width (height: 280px) مع gradient overlay
// فوقها: اسم الملعب + المدينة + status badge
// أزرار: Edit, View on Map, Delete — على اليمين
```

**5.2 — Image gallery lightbox**
- عند النقر على أي صورة في الـ gallery → lightbox يفتح مع navigation بين الصور.
- استخدم `yet-another-react-lightbox` (خفيف جداً).
```bash
npm install yet-another-react-lightbox
```

**5.3 — Stats mini-cards أفقية**
```tsx
// 4 بطاقات صغيرة في صف واحد:
// Total Bookings | Revenue This Month | Avg Rating | Active Since
```

**5.4 — Sports tags مرئية**
```tsx
// بدل نص "Football, Basketball"
// أيقونات رياضة ملوّنة (Lucide أو custom SVG) + اسم
```

**ملفات تُعدَّل:** `src/features/venues/VenueDetailPage.tsx`

---

### Part 6 — Login Page (صفحة الدخول)

**المشكلة:** صفحة login بسيطة جداً — أول ما يراه المستخدم.

**التحسينات:**

**6.1 — Split layout**
```
[  Left 50%: Brand side  ] [  Right 50%: Login form  ]
  - خلفية داكنة
  - لوغو المنصة
  - اقتباس أو إحصائية
  - صور venues في خلفية blurred
```

**6.2 — Brand side content**
```tsx
// إحصائيات حية من المنصة (mock):
"8+ Venues across Jordan"
"500+ Bookings this month"
"⭐ Trusted by 15+ venue owners"
```

**6.3 — Form polish**
- "Remember me" checkbox
- Password visibility toggle (العين)
- زر Login مع loading spinner حقيقي (disabled أثناء الطلب)
- Error message تحت الفورم مع أيقونة

**ملفات تُعدَّل:** `src/features/auth/LoginPage.tsx`

---

### Part 7 — Micro-interactions & Polish (اللمسات الأخيرة)

**المشكلة:** التطبيق يعمل لكن يفتقر للـ "feel" الاحترافي.

**التحسينات:**

**7.1 — Page transitions**
```bash
npm install framer-motion
```
```tsx
// في كل page — wrap المحتوى بـ:
<motion.div
  initial={{ opacity: 0, y: 8 }}
  animate={{ opacity: 1, y: 0 }}
  transition={{ duration: 0.2 }}
>
```

**7.2 — Toast notifications upgrade**
```tsx
// sonner موجود بالفعل — لكن خصّصه:
toast.success("Venue created", {
  description: "Al-Ameen Arena is now live",
  action: { label: "View", onClick: () => navigate(`/venues/${id}`) }
})
```

**7.3 — Loading states للأزرار**
```tsx
// كل زر mutation يكون:
<Button disabled={isPending}>
  {isPending ? <Loader2 className="h-4 w-4 animate-spin mr-2" /> : null}
  {isPending ? "Saving..." : "Save"}
</Button>
```

**7.4 — Keyboard shortcuts**
```tsx
// أضف useHotkeys أو useKeyPress بسيط:
// G + D → Dashboard
// G + V → Venues
// G + B → Bookings
// N → New (يفتح form dialog الصفحة الحالية)
// أظهرها في tooltip صغير أو صفحة help
```

**7.5 — Breadcrumbs**
```tsx
// في VenueDetailPage:
// Venues > Al-Ameen Football Arena
// أضف Breadcrumb component من shadcn
```

**ملفات تُعدَّل:** موزعة على كل الملفات — ابدأ بالـ pages الأكثر استخداماً

---

### Recommended Build Order للـ UI Improvements

| الأولوية | الجزء | الوقت التقديري | الأثر |
|----------|--------|----------------|--------|
| ~~1️⃣ أولاً~~ | ~~Part 1 — Design System~~ | ~~2-3 ساعات~~ | ✅ **مكتمل** |
| 1️⃣ أولاً | Part 2 — Sidebar | 1-2 ساعة | مرئي دائماً |
| 2️⃣ ثانياً | Part 3 — Dashboard | 2-3 ساعات | الصفحة الرئيسية |
| 3️⃣ ثالثاً | Part 6 — Login | 1 ساعة | أول انطباع |
| 4️⃣ رابعاً | Part 4 — Tables | 2-3 ساعات | معظم الوقت هنا |
| 5️⃣ خامساً | Part 5 — Venue Detail | 1-2 ساعة | تجربة مميزة |
| 6️⃣ أخيراً | Part 7 — Polish | متفرق | الإحساس الاحترافي |
