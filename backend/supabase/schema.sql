-- ============================================================
-- Taka ID — Supabase schema
-- Run this once in: Supabase Dashboard → SQL Editor → New query
-- ============================================================

-- ── 1. Table ──────────────────────────────────────────────────────────────────

create table if not exists public.history_records (
  id               uuid        primary key default gen_random_uuid(),
  label            text        not null,
  confidence       float8      not null check (confidence between 0 and 1),
  top_results      jsonb       not null default '[]'::jsonb,
  image_url        text,
  local_image_path text        not null default '',
  -- When the scan actually happened on the device (sent by the app).
  timestamp        timestamptz not null default now(),
  -- Server-side audit columns.
  created_at       timestamptz not null default now()
);

-- Index: fastest path for the default "newest first" listing.
create index if not exists history_records_timestamp_idx
  on public.history_records (timestamp desc);

-- ── 2. Row Level Security ─────────────────────────────────────────────────────
-- The Express backend uses the SERVICE ROLE key which bypasses RLS entirely.
-- Enable RLS anyway so direct client access (e.g. Supabase Studio) is safe.

alter table public.history_records enable row level security;

-- No client-facing policies are needed for this project because all access
-- goes through the Express backend.  Add user-scoped policies here if you
-- add authentication later.

-- ── 3. Storage bucket ─────────────────────────────────────────────────────────
-- Creates a PUBLIC bucket called "banknotes" for storing banknote images.
-- Images get a permanent public URL usable by the Flutter app.
--
-- Alternatively create the bucket in:
--   Supabase Dashboard → Storage → New bucket → name: banknotes → Public ✓

insert into storage.buckets (id, name, public)
values ('banknotes', 'banknotes', true)
on conflict (id) do nothing;

-- Allow public read access to every file in the bucket.
create policy "Public read banknotes"
  on storage.objects for select
  using (bucket_id = 'banknotes');

-- Allow the service role (backend) to upload / delete objects.
-- The service role already has full access, but this policy documents intent.
create policy "Service role manage banknotes"
  on storage.objects for all
  using (bucket_id = 'banknotes');
