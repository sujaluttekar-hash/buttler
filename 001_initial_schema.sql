-- ============================================================
-- StayVista Butler Ops — Supabase Schema
-- Run this in Supabase SQL editor (Dashboard > SQL Editor)
-- ============================================================

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- ============================================================
-- ENUMS
-- ============================================================
create type user_role as enum ('super_admin', 'admin', 'supervisor', 'butler');
create type delight_status as enum ('pending', 'completed', 'delayed');
create type task_type as enum ('arrival_selfie', 'guest_welcome', 'table_layout', 'exit_selfie');
create type task_status as enum ('pending', 'submitted', 'approved', 'rejected');
create type shift_type as enum ('day', 'evening', 'night', 'off');
create type huddle_status as enum ('scheduled', 'completed', 'cancelled');
create type quiz_question_type as enum ('mcq', 'true_false', 'short_answer');

-- ============================================================
-- SQUADS (regional teams)
-- ============================================================
create table squads (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  region text not null,
  created_at timestamptz default now()
);

insert into squads (name, region) values
  ('Karjat', 'Maharashtra'),
  ('Lonavala', 'Maharashtra'),
  ('Pune', 'Maharashtra'),
  ('Alibaug', 'Maharashtra'),
  ('Nashik', 'Maharashtra');

-- ============================================================
-- PROPERTIES
-- ============================================================
create table properties (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  squad_id uuid references squads(id),
  address text,
  city text,
  active boolean default true,
  created_at timestamptz default now()
);

insert into properties (name, city, squad_id) values
  ('Villa Pebble', 'Lonavala', (select id from squads where name='Lonavala')),
  ('Seabreeze', 'Alibaug', (select id from squads where name='Alibaug')),
  ('The Nest', 'Karjat', (select id from squads where name='Karjat')),
  ('Hilltop House', 'Pune', (select id from squads where name='Pune')),
  ('Vineyard Stay', 'Nashik', (select id from squads where name='Nashik')),
  ('Cloud Nine', 'Lonavala', (select id from squads where name='Lonavala')),
  ('Ocean Breeze', 'Alibaug', (select id from squads where name='Alibaug'));

-- ============================================================
-- USERS (extends Supabase auth.users)
-- ============================================================
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  email text not null unique,
  role user_role not null default 'butler',
  squad_id uuid references squads(id),
  property_id uuid references properties(id),
  phone text,
  active boolean default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Auto-create profile on auth signup
create or replace function handle_new_user()
returns trigger as $$
begin
  insert into profiles (id, full_name, email, role)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', ''), new.email, 
          coalesce((new.raw_user_meta_data->>'role')::user_role, 'butler'));
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- ============================================================
-- CREDENTIALS (login credentials only — butlers/admins/supervisors)
-- ============================================================
create table credentials (
  id uuid primary key default uuid_generate_v4(),
  profile_id uuid references profiles(id) on delete cascade,
  email text not null,
  -- Note: actual passwords managed by Supabase Auth. 
  -- This table stores temp/reset notes and metadata only.
  notes text,
  last_reset timestamptz,
  created_by uuid references profiles(id),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Credential access log
create table credential_access_logs (
  id uuid primary key default uuid_generate_v4(),
  credential_id uuid references credentials(id),
  accessed_by uuid references profiles(id),
  action text not null, -- 'viewed', 'reset', 'created', 'deleted'
  created_at timestamptz default now()
);

-- ============================================================
-- GUEST DELIGHTS
-- ============================================================
create table guest_delights (
  id uuid primary key default uuid_generate_v4(),
  guest_name text not null,
  property_id uuid references properties(id),
  butler_id uuid references profiles(id),
  category text not null, -- 'birthday', 'anniversary', 'welcome', 'honeymoon', 'special_request'
  scheduled_date date not null,
  status delight_status default 'pending',
  notes text,
  completed_at timestamptz,
  created_by uuid references profiles(id),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Delight photos
create table delight_photos (
  id uuid primary key default uuid_generate_v4(),
  delight_id uuid references guest_delights(id) on delete cascade,
  storage_path text not null,
  uploaded_by uuid references profiles(id),
  created_at timestamptz default now()
);

-- ============================================================
-- BUTLER HUDDLES (twice a month / every 15 days)
-- ============================================================
create table huddles (
  id uuid primary key default uuid_generate_v4(),
  title text not null,
  scheduled_date date not null,
  scheduled_time time not null default '11:00',
  location text default 'Virtual',
  squad_id uuid references squads(id), -- null = all squads
  status huddle_status default 'scheduled',
  agenda text,
  notes text,
  created_by uuid references profiles(id),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Huddle attendance
create table huddle_attendance (
  id uuid primary key default uuid_generate_v4(),
  huddle_id uuid references huddles(id) on delete cascade,
  butler_id uuid references profiles(id),
  present boolean default false,
  joined_at timestamptz,
  notes text
);

-- ============================================================
-- FUNCTIONAL TRAININGS (twice a year, conducted at huddle)
-- ============================================================
create table functional_trainings (
  id uuid primary key default uuid_generate_v4(),
  title text not null,
  scheduled_date date not null,
  huddle_id uuid references huddles(id), -- training conducted at this huddle
  squad_id uuid references squads(id),   -- null = all squads
  material_url text,
  notes text,
  created_by uuid references profiles(id),
  created_at timestamptz default now()
);

-- Training attendance (tracked at the huddle)
create table training_attendance (
  id uuid primary key default uuid_generate_v4(),
  training_id uuid references functional_trainings(id) on delete cascade,
  butler_id uuid references profiles(id),
  present boolean default false,
  notes text
);

-- ============================================================
-- QUIZZES (assigned after trainings / at huddles)
-- ============================================================
create table quizzes (
  id uuid primary key default uuid_generate_v4(),
  title text not null,
  description text,
  training_id uuid references functional_trainings(id),
  huddle_id uuid references huddles(id), -- quiz assigned at this huddle
  passing_score integer default 70,
  active boolean default true,
  created_by uuid references profiles(id),
  created_at timestamptz default now()
);

create table quiz_questions (
  id uuid primary key default uuid_generate_v4(),
  quiz_id uuid references quizzes(id) on delete cascade,
  question_text text not null,
  question_type quiz_question_type default 'mcq',
  options jsonb, -- array of option strings for MCQ
  correct_answer text not null,
  order_index integer default 0
);

create table quiz_attempts (
  id uuid primary key default uuid_generate_v4(),
  quiz_id uuid references quizzes(id),
  butler_id uuid references profiles(id),
  huddle_id uuid references huddles(id),
  score integer,
  answers jsonb, -- {question_id: answer}
  completed_at timestamptz,
  created_at timestamptz default now()
);

-- ============================================================
-- ROSTER
-- ============================================================
create table roster_entries (
  id uuid primary key default uuid_generate_v4(),
  butler_id uuid references profiles(id),
  property_id uuid references properties(id),
  work_date date not null,
  shift shift_type not null,
  start_time time,
  end_time time,
  notes text,
  created_by uuid references profiles(id),
  created_at timestamptz default now(),
  unique(butler_id, work_date)
);

create table shift_swap_requests (
  id uuid primary key default uuid_generate_v4(),
  requester_id uuid references profiles(id),
  target_id uuid references profiles(id),
  roster_entry_id uuid references roster_entries(id),
  swap_date date not null,
  reason text,
  status text default 'pending', -- 'pending', 'approved', 'denied'
  reviewed_by uuid references profiles(id),
  reviewed_at timestamptz,
  created_at timestamptz default now()
);

-- ============================================================
-- UTILISATION TASKS
-- ============================================================
create table utilisation_tasks (
  id uuid primary key default uuid_generate_v4(),
  butler_id uuid references profiles(id),
  property_id uuid references properties(id),
  task_type task_type not null,
  task_date date not null,
  status task_status default 'pending',
  photo_path text,
  latitude decimal(10, 8),
  longitude decimal(11, 8),
  notes text,
  submitted_at timestamptz,
  reviewed_by uuid references profiles(id),
  reviewed_at timestamptz,
  rejection_reason text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ============================================================
-- NOTIFICATIONS
-- ============================================================
create table notifications (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references profiles(id),
  title text not null,
  body text not null,
  type text, -- 'huddle_reminder', 'task_overdue', 'quiz_assigned', 'delight_pending'
  read boolean default false,
  created_at timestamptz default now()
);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

alter table profiles enable row level security;
alter table squads enable row level security;
alter table properties enable row level security;
alter table credentials enable row level security;
alter table credential_access_logs enable row level security;
alter table guest_delights enable row level security;
alter table delight_photos enable row level security;
alter table huddles enable row level security;
alter table huddle_attendance enable row level security;
alter table functional_trainings enable row level security;
alter table training_attendance enable row level security;
alter table quizzes enable row level security;
alter table quiz_questions enable row level security;
alter table quiz_attempts enable row level security;
alter table roster_entries enable row level security;
alter table shift_swap_requests enable row level security;
alter table utilisation_tasks enable row level security;
alter table notifications enable row level security;

-- Helper: get current user role
create or replace function get_user_role()
returns user_role as $$
  select role from profiles where id = auth.uid();
$$ language sql security definer stable;

-- Helper: is admin or above
create or replace function is_admin()
returns boolean as $$
  select get_user_role() in ('super_admin', 'admin');
$$ language sql security definer stable;

-- Profiles: users see own, admins see all
create policy "profiles_select" on profiles for select
  using (id = auth.uid() or is_admin() or get_user_role() = 'supervisor');

create policy "profiles_update_own" on profiles for update
  using (id = auth.uid());

create policy "profiles_admin_all" on profiles for all
  using (is_admin());

-- Squads & Properties: all authenticated users can read
create policy "squads_select" on squads for select using (auth.uid() is not null);
create policy "properties_select" on properties for select using (auth.uid() is not null);
create policy "properties_admin_write" on properties for all using (is_admin());

-- Credentials: admin only
create policy "credentials_admin_only" on credentials for all
  using (is_admin());

create policy "credential_logs_admin_only" on credential_access_logs for all
  using (is_admin());

-- Guest delights: butlers see own, supervisors/admins see all
create policy "delights_butler_own" on guest_delights for select
  using (butler_id = auth.uid() or get_user_role() in ('super_admin', 'admin', 'supervisor'));

create policy "delights_butler_insert" on guest_delights for insert
  with check (auth.uid() is not null);

create policy "delights_butler_update" on guest_delights for update
  using (butler_id = auth.uid() or get_user_role() in ('super_admin', 'admin', 'supervisor'));

create policy "delight_photos_all_auth" on delight_photos for all
  using (auth.uid() is not null);

-- Huddles: all auth users read, admin/supervisor write
create policy "huddles_read" on huddles for select using (auth.uid() is not null);
create policy "huddles_write" on huddles for all
  using (get_user_role() in ('super_admin', 'admin', 'supervisor'));

create policy "huddle_attendance_read" on huddle_attendance for select
  using (butler_id = auth.uid() or get_user_role() in ('super_admin', 'admin', 'supervisor'));

create policy "huddle_attendance_write" on huddle_attendance for all
  using (get_user_role() in ('super_admin', 'admin', 'supervisor'));

-- Trainings: all read, admin write
create policy "trainings_read" on functional_trainings for select using (auth.uid() is not null);
create policy "trainings_write" on functional_trainings for all using (is_admin());
create policy "training_attendance_read" on training_attendance for select using (auth.uid() is not null);
create policy "training_attendance_write" on training_attendance for all
  using (get_user_role() in ('super_admin', 'admin', 'supervisor'));

-- Quizzes: all read, admin write; butler can submit attempts
create policy "quizzes_read" on quizzes for select using (auth.uid() is not null);
create policy "quizzes_write" on quizzes for all using (is_admin());
create policy "quiz_questions_read" on quiz_questions for select using (auth.uid() is not null);
create policy "quiz_questions_write" on quiz_questions for all using (is_admin());
create policy "quiz_attempts_own" on quiz_attempts for all
  using (butler_id = auth.uid() or get_user_role() in ('super_admin', 'admin', 'supervisor'));

-- Roster: all read, admin/supervisor write
create policy "roster_read" on roster_entries for select using (auth.uid() is not null);
create policy "roster_write" on roster_entries for all
  using (get_user_role() in ('super_admin', 'admin', 'supervisor'));

create policy "swap_requests_own" on shift_swap_requests for all
  using (requester_id = auth.uid() or target_id = auth.uid() 
         or get_user_role() in ('super_admin', 'admin', 'supervisor'));

-- Tasks: butlers own, supervisors/admins all
create policy "tasks_butler_own" on utilisation_tasks for select
  using (butler_id = auth.uid() or get_user_role() in ('super_admin', 'admin', 'supervisor'));

create policy "tasks_butler_insert" on utilisation_tasks for insert
  with check (butler_id = auth.uid() or is_admin());

create policy "tasks_butler_update" on utilisation_tasks for update
  using (butler_id = auth.uid() or get_user_role() in ('super_admin', 'admin', 'supervisor'));

-- Notifications: own only
create policy "notifications_own" on notifications for all
  using (user_id = auth.uid());

-- ============================================================
-- STORAGE BUCKETS (run in Supabase Dashboard > Storage)
-- ============================================================
-- Create buckets:
--   delight-photos  (public: false)
--   task-photos     (public: false)
--   training-materials (public: false)

-- ============================================================
-- SEED DATA (sample)
-- ============================================================
-- Note: Real users must be created via Supabase Auth first.
-- Then update profile roles. Sample below is illustrative.

-- Sample huddles for current month
insert into huddles (title, scheduled_date, scheduled_time, location, agenda) values
  ('May Huddle 1', '2025-05-06', '11:00', 'Virtual', 'Q1 review · Guest feedback · Roster update'),
  ('May Huddle 2', '2025-05-21', '11:00', 'Virtual', 'May mid-month check · Training session'),
  ('Jun Huddle 1', '2025-06-05', '11:00', 'Virtual', 'Q2 review · Training updates · Roster changes'),
  ('Jun Huddle 2', '2025-06-20', '11:00', 'Virtual', 'Mid-June check');

-- Sample functional trainings
insert into functional_trainings (title, scheduled_date, notes) values
  ('H1 2025 — F&B & Guest Protocol', '2025-01-15', 'Conducted at Jan Huddle 2'),
  ('H2 2025 — Safety & Emergency SOP', '2025-07-14', 'To be conducted at Jul Huddle 1');
