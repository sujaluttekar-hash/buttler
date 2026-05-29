# StayVista Butler Ops

Butler Operations Management Platform built with Next.js 15, Supabase, and Tailwind CSS.

## Modules

| # | Module | Description |
|---|--------|-------------|
| 1 | **Guest Delight** | Calendar view with photo uploads, per-butler tracking |
| 2 | **Butler Huddle** | Twice-monthly scheduling, attendance, participant log |
| 3 | **Training Quiz** | MCQ/T-F quizzes assigned at huddles, leaderboard |
| 4 | **Functional Training** | Twice-yearly sessions, attendance + quiz at huddle |
| 5 | **Roster** | CSV upload, weekly shift view, swap requests |
| 6 | **Credentials** | Admin-only login vault for butlers/admins/supervisors |
| 7 | **Util. Tasks** | Arrival selfie, guest welcome, table layout, exit selfie |

## Tech Stack

- **Frontend:** Next.js 15 (App Router), React, Tailwind CSS
- **Backend:** Supabase (Auth, Postgres, Realtime, Storage)
- **Deployment:** Vercel

---

## Setup

### 1. Clone and install

```bash
git clone https://github.com/your-org/stayvista-butler-ops.git
cd stayvista-butler-ops
npm install
```

### 2. Create Supabase project

1. Go to [supabase.com](https://supabase.com) and create a new project
2. Go to **SQL Editor** and run the full migration:
   ```
   supabase/migrations/001_initial_schema.sql
   ```
3. Go to **Storage** and create these buckets:
   - `delight-photos` (private)
   - `task-photos` (private)
   - `training-materials` (private)

### 3. Configure environment variables

```bash
cp .env.local.example .env.local
```

Fill in your Supabase project URL and keys (found in Supabase Dashboard > Settings > API):

```env
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
NEXT_PUBLIC_APP_URL=http://localhost:3000
```

### 4. Create initial admin user

In Supabase Dashboard > Authentication > Users, create a user manually.
Then in SQL Editor, set their role:

```sql
UPDATE profiles SET role = 'admin', full_name = 'Aditi R.' WHERE email = 'aditi@stayvista.in';
```

### 5. Run locally

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000)

---

## Deployment (Vercel)

### One-click deploy

[![Deploy with Vercel](https://vercel.com/button)](https://vercel.com/new/clone?repository-url=https://github.com/your-org/stayvista-butler-ops)

### Manual deploy

1. Push to GitHub
2. Import to [vercel.com](https://vercel.com)
3. Add environment variables in Vercel dashboard:
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY`
   - `SUPABASE_SERVICE_ROLE_KEY`
   - `NEXT_PUBLIC_APP_URL` (your Vercel domain)
4. Deploy

---

## User Roles

| Role | Access |
|------|--------|
| `super_admin` | Everything |
| `admin` | All modules, credentials management (Aditi) |
| `supervisor` | All modules except credentials |
| `butler` | Own tasks, delights, roster view |

---

## Roster CSV Format

Upload via the Roster page. Required columns:

```csv
butler_email,property_name,work_date,shift
rahul@stayvista.in,Villa Pebble,2025-06-02,day
priya@stayvista.in,Seabreeze,2025-06-02,evening
ajay@stayvista.in,The Nest,2025-06-02,off
```

Valid shift values: `day`, `evening`, `night`, `off`

---

## Project Structure

```
src/
├── app/
│   ├── auth/login/          # Login page
│   ├── dashboard/           # Main dashboard
│   ├── delight/             # Guest delight module
│   ├── huddle/              # Butler huddle module
│   ├── quiz/                # Training quiz module
│   ├── training/            # Functional training module
│   ├── roster/              # Roster management
│   ├── credentials/         # Credentials vault
│   └── tasks/               # Utilisation tasks
├── components/
│   ├── layout/              # Sidebar, Topbar
│   ├── modules/             # Per-module components
│   └── ui/                  # Shared UI primitives
├── hooks/                   # useAuth, etc.
├── lib/
│   ├── supabase/            # Client and server Supabase instances
│   └── utils.ts             # Helpers
└── types/                   # TypeScript types + Database type
supabase/
└── migrations/
    └── 001_initial_schema.sql   # Full DB schema + RLS + seed
```

---

## Huddle Schedule Logic

Huddles are scheduled twice per month (every ~15 days). The recommended schedule is:
- Huddle 1: ~5th–6th of each month
- Huddle 2: ~20th–21st of each month

Functional trainings (twice a year, Jan + Jul) are **conducted at a huddle** — link them to a specific huddle when creating.

---

## Storage Setup (Supabase)

After creating buckets, add these policies in **Storage > Policies**:

```sql
-- delight-photos: authenticated users can upload
create policy "delight photos upload" on storage.objects for insert
  with check (bucket_id = 'delight-photos' and auth.uid() is not null);

-- task-photos: butler can upload their own
create policy "task photos upload" on storage.objects for insert
  with check (bucket_id = 'task-photos' and auth.uid() is not null);
```
