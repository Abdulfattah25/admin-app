-- Extensions (untuk gen_random_uuid)
create extension if not exists pgcrypto;

-- 1) users
create table if not exists public.users (
  id uuid primary key,
  email text not null,
  created_at timestamptz not null default now()
);

-- 2) daily_tasks_template (template harian)
create table if not exists public.daily_tasks_template (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  task_name text not null,
  priority text not null default 'sedang' check (priority in ('tinggi','sedang','rendah')),
  category text,
  jenis_task text not null default 'harian',
  deadline_date date,
  created_at timestamptz not null default now()
);

-- 3) daily_tasks_instance (salinan per tanggal)
create table if not exists public.daily_tasks_instance (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  task_id uuid references public.daily_tasks_template(id) on delete set null,
  task_name text not null,
  priority text not null default 'sedang' check (priority in ('tinggi','sedang','rendah')),
  category text,
  jenis_task text not null default 'harian',
  deadline_date date,
  date date not null,
  is_completed boolean not null default false,
  checked_at timestamptz,
  created_at timestamptz not null default now()
);

-- Ensure jenis_task allowed values
DO $$
BEGIN
  -- Ensure columns exist (safe for older DBs that lack these columns)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'daily_tasks_template' AND column_name = 'jenis_task'
  ) THEN
    ALTER TABLE public.daily_tasks_template ADD COLUMN jenis_task text not null default 'harian';
  ELSE
    -- enforce default and backfill NULLs if any
    ALTER TABLE public.daily_tasks_template ALTER COLUMN jenis_task SET DEFAULT 'harian';
    UPDATE public.daily_tasks_template SET jenis_task = 'harian' WHERE jenis_task IS NULL;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'daily_tasks_template' AND column_name = 'deadline_date'
  ) THEN
    ALTER TABLE public.daily_tasks_template ADD COLUMN deadline_date date;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'daily_tasks_instance' AND column_name = 'jenis_task'
  ) THEN
    ALTER TABLE public.daily_tasks_instance ADD COLUMN jenis_task text not null default 'harian';
  ELSE
    ALTER TABLE public.daily_tasks_instance ALTER COLUMN jenis_task SET DEFAULT 'harian';
    UPDATE public.daily_tasks_instance SET jenis_task = 'harian' WHERE jenis_task IS NULL;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'daily_tasks_instance' AND column_name = 'deadline_date'
  ) THEN
    ALTER TABLE public.daily_tasks_instance ADD COLUMN deadline_date date;
  END IF;

  -- Add CHECK constraints idempotently
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'daily_tasks_template_jenis_check'
  ) THEN
    ALTER TABLE public.daily_tasks_template ADD CONSTRAINT daily_tasks_template_jenis_check CHECK (jenis_task IN ('harian','deadline'));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'daily_tasks_instance_jenis_check'
  ) THEN
    ALTER TABLE public.daily_tasks_instance ADD CONSTRAINT daily_tasks_instance_jenis_check CHECK (jenis_task IN ('harian','deadline'));
  END IF;
END $$;

-- 4) score_log (pencatatan perubahan skor)
create table if not exists public.score_log (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  date date not null,
  score_delta integer not null,
  reason text not null,
  created_at timestamptz not null default now()
);

/******************************************************************
  PROFILES: role-based access (admin vs user)
******************************************************************/
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  role text not null default 'user' check (role in ('user','admin')),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Ensure required columns exist even if table already existed earlier
alter table public.profiles add column if not exists email text;
alter table public.profiles add column if not exists role text;
-- Backfill and enforce defaults/constraint for role
update public.profiles set role = 'user' where role is null;
alter table public.profiles alter column role set default 'user';
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'profiles_role_check'
  ) THEN
    ALTER TABLE public.profiles ADD CONSTRAINT profiles_role_check CHECK (role in ('user','admin'));
  END IF;
END $$;

alter table public.profiles add column if not exists is_active boolean;
update public.profiles set is_active = true where is_active is null;
alter table public.profiles alter column is_active set default true;
alter table public.profiles alter column is_active set not null;

alter table public.profiles add column if not exists created_at timestamptz not null default now();
alter table public.profiles add column if not exists updated_at timestamptz not null default now();

-- Keep updated_at fresh
create or replace function public.set_profiles_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at
before update on public.profiles
for each row execute function public.set_profiles_updated_at();

-- Auto-create profile row when a new auth user is created
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists trg_on_auth_user_created on auth.users;
create trigger trg_on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- (Optional) keep email in sync if auth.users.email changes
create or replace function public.sync_profile_email()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles
     set email = new.email,
         updated_at = now()
   where id = new.id;
  return new;
end $$;

drop trigger if exists trg_sync_profile_email on auth.users;
create trigger trg_sync_profile_email
after update of email on auth.users
for each row execute function public.sync_profile_email();

-- Helpful index for ordering/filtering
create index if not exists idx_profiles_email on public.profiles (email);

-- Indeks penting
create index if not exists idx_template_user_created on public.daily_tasks_template(user_id, created_at desc);
create index if not exists idx_instance_user_date on public.daily_tasks_instance(user_id, date);
create index if not exists idx_instance_user_created on public.daily_tasks_instance(user_id, created_at desc);
create index if not exists idx_score_user_date on public.score_log(user_id, date);

-- Cegah duplikasi materialisasi untuk task yang sama pada hari yang sama
create unique index if not exists ux_instance_user_date_task
  on public.daily_tasks_instance(user_id, date, task_id)
  where task_id is not null;

-- Cegah duplikasi ad-hoc task (berdasarkan nama) pada hari yang sama
create unique index if not exists ux_instance_user_date_taskname_adhoc
  on public.daily_tasks_instance(user_id, date, task_name)
  where task_id is null;

-- RLS: aktifkan dan kebijakan per tabel
alter table public.users enable row level security;
alter table public.daily_tasks_template enable row level security;
alter table public.daily_tasks_instance enable row level security;
alter table public.score_log enable row level security;
alter table public.profiles enable row level security;

-- USERS policies
drop policy if exists users_select_own on public.users;
create policy users_select_own on public.users
  for select using (id = auth.uid());

drop policy if exists users_insert_self on public.users;
create policy users_insert_self on public.users
  for insert with check (id = auth.uid());

drop policy if exists users_update_self on public.users;
create policy users_update_self on public.users
  for update using (id = auth.uid()) with check (id = auth.uid());

-- (Opsional) hapus sendiri
drop policy if exists users_delete_self on public.users;
create policy users_delete_self on public.users
  for delete using (id = auth.uid());

-- DAILY_TASKS_TEMPLATE policies
drop policy if exists dtt_select_own on public.daily_tasks_template;
create policy dtt_select_own on public.daily_tasks_template
  for select using (user_id = auth.uid());

drop policy if exists dtt_insert_own on public.daily_tasks_template;
create policy dtt_insert_own on public.daily_tasks_template
  for insert with check (user_id = auth.uid());

drop policy if exists dtt_update_own on public.daily_tasks_template;
create policy dtt_update_own on public.daily_tasks_template
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists dtt_delete_own on public.daily_tasks_template;
create policy dtt_delete_own on public.daily_tasks_template
  for delete using (user_id = auth.uid());

-- DAILY_TASKS_INSTANCE policies
drop policy if exists dti_select_own on public.daily_tasks_instance;
create policy dti_select_own on public.daily_tasks_instance
  for select using (user_id = auth.uid());

drop policy if exists dti_insert_own on public.daily_tasks_instance;
create policy dti_insert_own on public.daily_tasks_instance
  for insert with check (user_id = auth.uid());

drop policy if exists dti_update_own on public.daily_tasks_instance;
create policy dti_update_own on public.daily_tasks_instance
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists dti_delete_own on public.daily_tasks_instance;
create policy dti_delete_own on public.daily_tasks_instance
  for delete using (user_id = auth.uid());

-- SCORE_LOG policies
drop policy if exists sl_select_own on public.score_log;
create policy sl_select_own on public.score_log
  for select using (user_id = auth.uid());

drop policy if exists sl_insert_own on public.score_log;
create policy sl_insert_own on public.score_log
  for insert with check (user_id = auth.uid());

drop policy if exists sl_update_own on public.score_log;
create policy sl_update_own on public.score_log
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists sl_delete_own on public.score_log;
create policy sl_delete_own on public.score_log
  for delete using (user_id = auth.uid());

-- Admin can SELECT all rows
drop policy if exists "profiles admin read" on public.profiles;
drop policy if exists "profiles admin update" on public.profiles;

-- Helper: returns true when the current auth.uid() is an active admin
create or replace function public.is_current_user_admin()
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists(
    select 1 from public.profiles
    where id = auth.uid()
      and role = 'admin'
      and is_active = true
  );
$$;

-- Grant execute so policy evaluation can call it (safe to allow execute)
grant execute on function public.is_current_user_admin() to public;

-- Admin policies that use the helper (no recursive SELECT from within policy)
create policy "profiles admin read" on public.profiles
  for select
  using ( public.is_current_user_admin() );

create policy "profiles admin update" on public.profiles
  for update
  using ( public.is_current_user_admin() )
  with check ( public.is_current_user_admin() );

-- Users can read their own profile
drop policy if exists "profiles self read" on public.profiles;
create policy "profiles self read" on public.profiles
for select
using (id = auth.uid());

-- Users can update their own profile (if needed)
drop policy if exists "profiles self update" on public.profiles;
create policy "profiles self update" on public.profiles
for update
using (id = auth.uid())
with check (id = auth.uid());

-- Backfill: ensure every existing auth user has a profile row
insert into public.profiles (id, email)
select u.id, u.email
from auth.users u
left join public.profiles p on p.id = u.id
where p.id is null;

-- ============================================================
-- Licenses: table, RLS, dan fungsi RPC untuk validasi/assign
-- ============================================================

-- Enum status lisensi (idempoten)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'license_status') THEN
    CREATE TYPE public.license_status AS ENUM ('valid','used','revoked','expired');
  END IF;
END $$;

-- Tabel licenses
create table if not exists public.licenses (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  status public.license_status not null default 'valid',
  assigned_email text,
  created_at timestamptz not null default now(),
  used_at timestamptz
);

-- Index tambahan
create index if not exists idx_licenses_status on public.licenses(status);
create index if not exists idx_licenses_created on public.licenses(created_at desc);

-- RLS dan kebijakan (hanya admin)
alter table public.licenses enable row level security;

drop policy if exists "licenses admin read" on public.licenses;
create policy "licenses admin read" on public.licenses
  for select
  using ( public.is_current_user_admin() );

drop policy if exists "licenses admin write" on public.licenses;
create policy "licenses admin write" on public.licenses
  for all
  using ( public.is_current_user_admin() )
  with check ( public.is_current_user_admin() );

-- RPC: Validasi lisensi (boolean) - aman untuk anon (SECURITY DEFINER)
create or replace function public.validate_license(p_code text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  c int;
begin
  select count(*) into c
  from public.licenses
  where code = upper(p_code) and status = 'valid';
  return c > 0;
end
$$;

grant execute on function public.validate_license(text) to public;

-- RPC: Tandai lisensi sebagai used + catat email (boolean keberhasilan)
create or replace function public.use_license(p_code text, p_email text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  updated_count int;
begin
  update public.licenses
     set status = 'used',
         assigned_email = p_email,
         used_at = now()
   where code = upper(p_code)
     and status = 'valid';
  GET DIAGNOSTICS updated_count = ROW_COUNT;
  return updated_count = 1;
end
$$;

grant execute on function public.use_license(text, text) to public;

-- RPC: Generate lisensi baru (hanya admin, SECURITY DEFINER)
-- Kode 6-karakter alfanumerik uppercase berbasis UUID (lebih kompatibel)
create or replace function public.admin_generate_license()
returns public.licenses
language plpgsql
security definer
set search_path = public
as $$
declare
  new_code text;
  rec public.licenses;
  random_uuid text;
begin
  -- Pastikan hanya admin dapat mengeksekusi
  if not public.is_current_user_admin() then
    raise exception 'Only admins can generate licenses';
  end if;

  -- Coba generate unik (loop jika bentrok)
  loop
    -- Generate 6 karakter dari UUID (lebih kompatibel)
    random_uuid := replace(gen_random_uuid()::text, '-', '');
    new_code := upper(substr(random_uuid, 1, 6));

    begin
      insert into public.licenses(code, status)
      values (new_code, 'valid')
      returning * into rec;
      return rec;
    exception
      when unique_violation then
        -- Ulangi jika bentrok
        continue;
    end;
  end loop;

  -- Tidak akan sampai sini
  return rec;
end
$$;

grant execute on function public.admin_generate_license() to authenticated;
alter publication supabase_realtime add table public.licenses;
-- Ganti {EMAIL_ADMIN} dengan email Anda
update public.profiles
set role = 'admin', is_active = true
where email = '{fattahula98@gmail.com}';
-- Admin can delete profiles
create policy "profiles admin delete" on public.profiles
  for delete
  using ( public.is_current_user_admin() );
  
  -- Tabel untuk aplikasi yang terdaftar
CREATE TABLE applications (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE,
  description TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Insert aplikasi yang sudah ada
INSERT INTO applications (name, description) VALUES 
('Produktivity', 'Aplikasi manajemen produktivitas'),
('Cashflow', 'Aplikasi manajemen keuangan');

-- Modifikasi tabel users untuk menambah app_name dan role
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS app_name VARCHAR(100) REFERENCES applications(name),
ADD COLUMN IF NOT EXISTS role VARCHAR(50) DEFAULT 'user',
ADD COLUMN IF NOT EXISTS status VARCHAR(50) DEFAULT 'active';

-- Tabel untuk lisensi
CREATE TABLE licenses (
  id SERIAL PRIMARY KEY,
  license_code VARCHAR(255) NOT NULL UNIQUE,
  app_name VARCHAR(100) REFERENCES applications(name),
  is_used BOOLEAN DEFAULT FALSE,
  used_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMP DEFAULT NOW(),
  used_at TIMESTAMP
);

-- RLS (Row Level Security) policies
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE licenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE applications ENABLE ROW LEVEL SECURITY;

-- Policy untuk admin bisa akses semua data
CREATE POLICY "Admin can access all users" ON users
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM users u 
      WHERE u.id = auth.uid() AND u.role = 'admin'
    )
  );

CREATE POLICY "Admin can access all licenses" ON licenses
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM users u 
      WHERE u.id = auth.uid() AND u.role = 'admin'
    )
  );
  -- 0) Safety: ensure pgcrypto exists for uuid ops in case needed elsewhere
create extension if not exists pgcrypto;

-- 1) applications: allow authenticated users to SELECT (or restrict to admin if you prefer)
alter table public.applications enable row level security;

drop policy if exists applications_read_auth on public.applications;
create policy applications_read_auth on public.applications
  for select
  using ( auth.role() = 'authenticated' );

-- 2) users: ensure required columns exist
alter table public.users
  add column if not exists app_name varchar(100) references public.applications(name),
  add column if not exists role varchar(50) default 'user',
  add column if not exists status varchar(50) default 'active',
  add column if not exists updated_at timestamptz default now();

-- Optional: add a display name column (UI shows "No Name" if absent)
alter table public.users
  add column if not exists name text;

-- Helpful indexes
create index if not exists idx_users_app_name on public.users(app_name);
create index if not exists idx_users_role on public.users(role);
create index if not exists idx_users_status on public.users(status);
create index if not exists idx_users_created_at on public.users(created_at);

-- 3) licenses: fix FK to reference public.users(id) so Supabase nested selects work
-- Drop old FK if it targeted auth.users
do $$
declare
  fk_exists boolean;
begin
  select exists (
    select 1
    from information_schema.table_constraints tc
    where tc.constraint_schema = 'public'
      and tc.table_name = 'licenses'
      and tc.constraint_type = 'FOREIGN KEY'
      and tc.constraint_name = 'licenses_used_by_fkey'
  ) into fk_exists;

  if fk_exists then
    execute 'alter table public.licenses drop constraint licenses_used_by_fkey';
  end if;
end $$;

-- Re-add FK to public.users(id) with ON DELETE SET NULL
alter table public.licenses
  add constraint licenses_used_by_fkey
  foreign key (used_by) references public.users(id) on delete set null;

-- Helpful indexes
create index if not exists idx_licenses_app_name on public.licenses(app_name);
create index if not exists idx_licenses_is_used on public.licenses(is_used);
create index if not exists idx_licenses_created_at on public.licenses(created_at);

-- 4) RLS: users table
alter table public.users enable row level security;

-- Self policies so a user (including the admin) can read/update their own row,
-- and create their own row on first login if needed.
drop policy if exists users_self_select on public.users;
create policy users_self_select on public.users
  for select
  using ( id = auth.uid() );

drop policy if exists users_self_insert on public.users;
create policy users_self_insert on public.users
  for insert
  with check ( id = auth.uid() );

drop policy if exists users_self_update on public.users;
create policy users_self_update on public.users
  for update
  using ( id = auth.uid() )
  with check ( id = auth.uid() );

-- Admin policy with USING + WITH CHECK so INSERT/UPDATE/DELETE also pass
drop policy if exists "Admin can access all users" on public.users;
create policy "Admin can access all users" on public.users
  for all
  using (
    exists (
      select 1 from public.users u
      where u.id = auth.uid()
        and u.role = 'admin'
    )
  )
  with check (
    exists (
      select 1 from public.users u
      where u.id = auth.uid()
        and u.role = 'admin'
    )
  );

-- 5) RLS: licenses table
alter table public.licenses enable row level security;

-- Admin-only full access (SELECT/INSERT/UPDATE/DELETE)
drop policy if exists "Admin can access all licenses" on public.licenses;
create policy "Admin can access all licenses" on public.licenses
  for all
  using (
    exists (
      select 1 from public.users u
      where u.id = auth.uid()
        and u.role = 'admin'
    )
  )
  with check (
    exists (
      select 1 from public.users u
      where u.id = auth.uid()
        and u.role = 'admin'
    )
  );

-- 6) OPTIONAL but recommended: keep users.updated_at fresh
create or replace function public.set_users_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists trg_users_updated_at on public.users;
create trigger trg_users_updated_at
before update on public.users
for each row execute function public.set_users_updated_at();

-- 7) OPTIONAL: auto-create a row in public.users when a new auth user is created
-- (this avoids the app needing to insert on first login)
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
end $$;

-- You may need to drop any existing trigger first
drop trigger if exists trg_on_auth_user_created on auth.users;
create trigger trg_on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_auth_user();