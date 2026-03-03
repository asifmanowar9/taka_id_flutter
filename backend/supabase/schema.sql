-- ============================================================
-- Taka ID — Supabase schema  (idempotent — safe to re-run)
-- Run in: Supabase Dashboard → SQL Editor → New query
-- ============================================================

-- ── 1. Table ──────────────────────────────────────────────────────────────────

create table if not exists public.history_records (
  id               uuid        primary key default gen_random_uuid(),
  label            text        not null,
  confidence       float8      not null check (confidence between 0 and 1),
  top_results      jsonb       not null default '[]'::jsonb,
  image_url        text,
  local_image_path text        not null default '',
  timestamp        timestamptz not null default now(),
  created_at       timestamptz not null default now()
);

-- ── 2. Add user_id (works for both fresh installs and existing tables) ────────
-- Adding as nullable first so it never fails on tables that already have rows.
alter table public.history_records
  add column if not exists user_id uuid references auth.users(id) on delete cascade;

-- ── 3. Indexes ────────────────────────────────────────────────────────────────

create index if not exists history_records_timestamp_idx
  on public.history_records (timestamp desc);

create index if not exists history_records_user_id_idx
  on public.history_records (user_id);

-- ── 4. Row Level Security ─────────────────────────────────────────────────────
-- The Express backend uses the SERVICE ROLE key which bypasses RLS entirely.
-- RLS policies scope direct Studio / client access to the owning user.

alter table public.history_records enable row level security;

-- Drop first so re-running this script never raises "policy already exists".
drop policy if exists "Users read own records"   on public.history_records;
drop policy if exists "Users insert own records" on public.history_records;
drop policy if exists "Users delete own records" on public.history_records;

create policy "Users read own records"
  on public.history_records for select
  using (auth.uid() = user_id);

create policy "Users insert own records"
  on public.history_records for insert
  with check (auth.uid() = user_id);

create policy "Users delete own records"
  on public.history_records for delete
  using (auth.uid() = user_id);

-- ── 5. Storage bucket ─────────────────────────────────────────────────────────

insert into storage.buckets (id, name, public)
values ('banknotes', 'banknotes', true)
on conflict (id) do nothing;

drop policy if exists "Public read banknotes"        on storage.objects;
drop policy if exists "Service role manage banknotes" on storage.objects;

create policy "Public read banknotes"
  on storage.objects for select
  using (bucket_id = 'banknotes');

create policy "Service role manage banknotes"
  on storage.objects for all
  using (bucket_id = 'banknotes');

