-- Run in Supabase SQL Editor (or via supabase migration tooling)

create extension if not exists "pgcrypto";

create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  username text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint username_length check (char_length(username) between 1 and 30)
);

create table if not exists public.user_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  goal_weight numeric(5,2) not null default 75,
  start_weight numeric(5,2),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint goal_weight_range check (goal_weight between 30 and 300),
  constraint start_weight_range check (start_weight is null or start_weight between 30 and 400)
);

create table if not exists public.weight_entries (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  entry_date date not null,
  raw_weight numeric(5,2) not null,
  protein boolean not null default false,
  steps boolean not null default false,
  context text not null default 'Normal',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint raw_weight_range check (raw_weight between 30 and 400),
  constraint context_length check (char_length(context) <= 100),
  unique (user_id, entry_date)
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

drop trigger if exists trg_user_settings_updated_at on public.user_settings;
create trigger trg_user_settings_updated_at
before update on public.user_settings
for each row execute function public.set_updated_at();

drop trigger if exists trg_weight_entries_updated_at on public.weight_entries;
create trigger trg_weight_entries_updated_at
before update on public.weight_entries
for each row execute function public.set_updated_at();

alter table public.profiles enable row level security;
alter table public.user_settings enable row level security;
alter table public.weight_entries enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
drop policy if exists "profiles_insert_own" on public.profiles;
drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_select_own" on public.profiles
for select using (auth.uid() = user_id);
create policy "profiles_insert_own" on public.profiles
for insert with check (auth.uid() = user_id);
create policy "profiles_update_own" on public.profiles
for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "settings_select_own" on public.user_settings;
drop policy if exists "settings_insert_own" on public.user_settings;
drop policy if exists "settings_update_own" on public.user_settings;
create policy "settings_select_own" on public.user_settings
for select using (auth.uid() = user_id);
create policy "settings_insert_own" on public.user_settings
for insert with check (auth.uid() = user_id);
create policy "settings_update_own" on public.user_settings
for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "entries_select_own" on public.weight_entries;
drop policy if exists "entries_insert_own" on public.weight_entries;
drop policy if exists "entries_update_own" on public.weight_entries;
drop policy if exists "entries_delete_own" on public.weight_entries;
create policy "entries_select_own" on public.weight_entries
for select using (auth.uid() = user_id);
create policy "entries_insert_own" on public.weight_entries
for insert with check (auth.uid() = user_id);
create policy "entries_update_own" on public.weight_entries
for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "entries_delete_own" on public.weight_entries
for delete using (auth.uid() = user_id);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  user_name text;
begin
  user_name := coalesce(
    new.raw_user_meta_data ->> 'username',
    'user_' || left(replace(new.id::text, '-', ''), 24)
  );

  insert into public.profiles(user_id, username)
  values (new.id, left(user_name, 30))
  on conflict (user_id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();
