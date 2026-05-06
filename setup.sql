-- ============================================================
--  Build & Inspect — Supabase Schema Setup
--  Run this entire file in: Supabase → SQL Editor → New query
-- ============================================================

-- PROFILES (extends Supabase auth.users)
create table if not exists public.profiles (
  id uuid references auth.users on delete cascade primary key,
  full_name text not null,
  role text default 'technician',
  created_at timestamptz default now()
);
alter table public.profiles enable row level security;
create policy "Users can read all profiles" on public.profiles for select using (auth.role() = 'authenticated');
create policy "Users can update own profile" on public.profiles for update using (auth.uid() = id);
create policy "Users can insert own profile" on public.profiles for insert with check (auth.uid() = id);

-- Auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email,'@',1)));
  return new;
end;
$$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- MACHINES
create table if not exists public.machines (
  id uuid primary key default gen_random_uuid(),
  type text not null check (type in ('FSWB','FSDWB')),
  serial text not null,
  customer text,
  so text,
  ship_date date,
  created_by uuid references public.profiles(id),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
alter table public.machines enable row level security;
create policy "Auth users can read machines" on public.machines for select using (auth.role() = 'authenticated');
create policy "Auth users can insert machines" on public.machines for insert with check (auth.role() = 'authenticated');
create policy "Auth users can update machines" on public.machines for update using (auth.role() = 'authenticated');
create policy "Auth users can delete machines" on public.machines for delete using (auth.role() = 'authenticated');

-- BUILD ENTRIES
create table if not exists public.build_entries (
  id uuid primary key default gen_random_uuid(),
  machine_id uuid references public.machines(id) on delete cascade not null,
  stage text not null,
  tech_id uuid references public.profiles(id),
  tech_name text,
  hours numeric(5,2) default 0,
  entry_date date,
  notes text,
  created_at timestamptz default now()
);
alter table public.build_entries enable row level security;
create policy "Auth users can read build_entries" on public.build_entries for select using (auth.role() = 'authenticated');
create policy "Auth users can insert build_entries" on public.build_entries for insert with check (auth.role() = 'authenticated');
create policy "Auth users can update build_entries" on public.build_entries for update using (auth.role() = 'authenticated');
create policy "Auth users can delete build_entries" on public.build_entries for delete using (auth.role() = 'authenticated');

-- PHOTOS
create table if not exists public.photos (
  id uuid primary key default gen_random_uuid(),
  machine_id uuid references public.machines(id) on delete cascade not null,
  build_entry_id uuid references public.build_entries(id) on delete cascade,
  context text not null check (context in ('build','qc')),
  storage_path text not null,
  url text,
  uploaded_by uuid references public.profiles(id),
  created_at timestamptz default now()
);
alter table public.photos enable row level security;
create policy "Auth users can read photos" on public.photos for select using (auth.role() = 'authenticated');
create policy "Auth users can insert photos" on public.photos for insert with check (auth.role() = 'authenticated');
create policy "Auth users can delete photos" on public.photos for delete using (auth.role() = 'authenticated');

-- QC RESULTS
create table if not exists public.qc_results (
  id uuid primary key default gen_random_uuid(),
  machine_id uuid references public.machines(id) on delete cascade not null unique,
  checks jsonb default '{}',
  fail_notes jsonb default '{}',
  inspector_id uuid references public.profiles(id),
  inspector_name text,
  notes text,
  sign_off_date date,
  updated_at timestamptz default now()
);
alter table public.qc_results enable row level security;
create policy "Auth users can read qc_results" on public.qc_results for select using (auth.role() = 'authenticated');
create policy "Auth users can insert qc_results" on public.qc_results for insert with check (auth.role() = 'authenticated');
create policy "Auth users can update qc_results" on public.qc_results for update using (auth.role() = 'authenticated');

-- ============================================================
--  STORAGE BUCKET
--  After running this SQL, also do:
--  Supabase → Storage → New bucket → name: "photos" → Public: ON
-- ============================================================
