-- =============================================================================
-- Galoppal — Supabase schema
-- Run this once in the Supabase SQL editor (or via `supabase db push`) on a
-- fresh project. Safe to re-run: every statement is guarded with IF NOT EXISTS
-- / OR REPLACE / DROP POLICY IF EXISTS where applicable.
-- =============================================================================

-- pgcrypto gives us gen_random_uuid(); Supabase projects have it enabled by
-- default, this is just a safety net for a bare Postgres instance.
create extension if not exists pgcrypto;

-- =============================================================================
-- 1. profiles — one row per auth user, extends auth.users with app data
-- =============================================================================

create table if not exists public.profiles (
  id                        uuid primary key references auth.users (id) on delete cascade,
  role                      text not null check (role in ('trainer', 'rider')), -- "active" role — which view the app currently shows
  full_name                 text not null,
  bio                       text,
  facility                  text,                 -- trainer: display name of their venue (e.g. "Reitanlage Sonnenhof")
  address                   text,                 -- trainer: postal address, shown to riders with an "open in Maps" link
  stable_name               text,                 -- rider: home stable (was stored in `facility` before dual-role)
  discipline                text,                 -- deprecated, kept nullable (UI removed)
  avatar_url                text,
  invite_code               text unique,          -- set once a profile becomes a trainer, e.g. "vogt-3f9a"
  is_trainer                boolean not null default false, -- can this account act as a trainer at all?
  is_rider                  boolean not null default false, -- can this account act as a rider at all?
  default_duration_minutes  int  not null default 45,
  default_capacity          int  not null default 3,
  default_slot_mode         text not null default 'single' check (default_slot_mode in ('single', 'range')),
  default_repeat            text not null default 'Einmalig' check (default_repeat in ('Einmalig', 'Wöchentlich', '14-tägig')),
  booking_lead_hours        int  not null default 12,
  reminder_hours            int  not null default 2,
  allow_requests            boolean not null default false, -- trainer: let linked riders request unlisted times
  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now()
);

comment on table public.profiles is 'App profile for every authenticated user, one row per auth.users id. A profile can be a trainer, a rider, or both (is_trainer/is_rider) — `role` is only which one is currently active in the UI.';

-- `create table if not exists` above is a no-op on a project that already
-- has this table — add the columns explicitly so re-running this file on an
-- existing project still picks them up.
alter table public.profiles add column if not exists allow_requests boolean not null default false;
alter table public.profiles add column if not exists default_slot_mode text not null default 'single';
alter table public.profiles add column if not exists default_repeat text not null default 'Einmalig';
alter table public.profiles add column if not exists address text;
alter table public.profiles add column if not exists stable_name text;
alter table public.profiles add column if not exists is_trainer boolean not null default false;
alter table public.profiles add column if not exists is_rider boolean not null default false;

-- Dual-role backfill for existing rows (idempotent: only ever turns flags on,
-- never off, so re-running this doesn't undo someone who since activated the
-- other role too).
update public.profiles set is_trainer = true where role = 'trainer' and not is_trainer;
update public.profiles set is_rider = true where role = 'rider' and not is_rider;
-- The rider's "home stable" used to live in `facility` (shared with the
-- trainer meaning of that column) — split it out once.
update public.profiles set stable_name = facility
  where role = 'rider' and stable_name is null and facility is not null;

-- =============================================================================
-- 2. trainer_rider_links — many-to-many connection between a trainer and
--    their riders, created when a rider redeems a trainer''s invite code.
-- =============================================================================

create table if not exists public.trainer_rider_links (
  id          uuid primary key default gen_random_uuid(),
  trainer_id  uuid not null references public.profiles (id) on delete cascade,
  rider_id    uuid not null references public.profiles (id) on delete cascade,
  created_at  timestamptz not null default now(),
  unique (trainer_id, rider_id)
);

-- =============================================================================
-- 3. lesson_slots — a bookable (or already-booked-out) lesson published by a
--    trainer. A recurring series shares the same series_id.
-- =============================================================================

create table if not exists public.lesson_slots (
  id                 uuid primary key default gen_random_uuid(),
  trainer_id         uuid not null references public.profiles (id) on delete cascade,
  lesson_date        date not null,
  start_time         time not null,
  duration_minutes   int  not null check (duration_minutes > 0),
  discipline         text,                 -- deprecated (UI removed); kept nullable for now
  location_kind      text,                 -- deprecated (UI removed); kept nullable for now
  facility           text not null,
  capacity           int  not null check (capacity between 1 and 20),
  series_id          uuid,                 -- null for one-off slots
  status             text not null default 'open' check (status in ('open', 'canceled')),
  cancel_reason      text,                 -- optional, shown to riders when the trainer cancels
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

-- `create table if not exists` above is a no-op on a project that already
-- has this table — apply the incremental changes explicitly so re-running
-- this file on an existing project still picks them up.
alter table public.lesson_slots add column if not exists cancel_reason text;
-- Disziplin / Reithalle-vs-Reitplatz were removed from the UI. Drop the
-- constraints so inserts without them succeed; the columns stay for a
-- possible later reactivation.
alter table public.lesson_slots alter column discipline drop not null;
alter table public.lesson_slots alter column location_kind drop not null;
alter table public.lesson_slots drop constraint if exists lesson_slots_discipline_check;
alter table public.lesson_slots drop constraint if exists lesson_slots_location_kind_check;

-- =============================================================================
-- 4. bookings — a rider reserving one seat in a lesson slot
-- =============================================================================

create table if not exists public.bookings (
  id          uuid primary key default gen_random_uuid(),
  slot_id     uuid not null references public.lesson_slots (id) on delete cascade,
  rider_id    uuid not null references public.profiles (id) on delete cascade,
  created_at  timestamptz not null default now(),
  unique (slot_id, rider_id)
);

-- =============================================================================
-- 4b. lesson_requests — a rider proposing a lesson time the trainer hasn't
--     published. Only insertable when the trainer has `allow_requests` on
--     and the two are linked. Approving one creates the matching
--     lesson_slots + bookings rows (see approve_lesson_request() below).
-- =============================================================================

create table if not exists public.lesson_requests (
  id                 uuid primary key default gen_random_uuid(),
  trainer_id         uuid not null references public.profiles (id) on delete cascade,
  rider_id           uuid not null references public.profiles (id) on delete cascade,
  requested_date     date not null,
  requested_time     time not null,
  duration_minutes   int  not null check (duration_minutes > 0),
  discipline         text,                 -- deprecated (UI removed); kept nullable for now
  location_kind      text,                 -- deprecated (UI removed); kept nullable for now
  note               text,
  status             text not null default 'pending' check (status in ('pending', 'approved', 'declined')),
  resulting_slot_id  uuid references public.lesson_slots (id) on delete set null,
  created_at         timestamptz not null default now()
);

alter table public.lesson_requests alter column discipline drop not null;
alter table public.lesson_requests alter column location_kind drop not null;
alter table public.lesson_requests drop constraint if exists lesson_requests_discipline_check;
alter table public.lesson_requests drop constraint if exists lesson_requests_location_kind_check;

-- =============================================================================
-- 4c. student_notes — private trainer notes about a rider: either general
--     (slot_id null) or tied to one lesson, before/after it. An append-only
--     trail — no update policy, so the write date always matches the note.
-- =============================================================================

create table if not exists public.student_notes (
  id          uuid primary key default gen_random_uuid(),
  trainer_id  uuid not null references public.profiles (id) on delete cascade,
  rider_id    uuid not null references public.profiles (id) on delete cascade,
  slot_id     uuid references public.lesson_slots (id) on delete set null, -- null = general note
  phase       text check (phase in ('before', 'after')), -- only set when slot_id is set
  body        text not null,
  created_at  timestamptz not null default now()
);

create index if not exists idx_student_notes_trainer_rider on public.student_notes (trainer_id, rider_id, created_at desc);

-- =============================================================================
-- 5. notifications — per-user notification feed
-- =============================================================================

create table if not exists public.notifications (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles (id) on delete cascade,
  kind        text not null check (kind in ('clock', 'cal', 'user')),
  title       text not null,
  body        text not null,
  is_read     boolean not null default false,
  slot_id     uuid references public.lesson_slots (id) on delete set null, -- the lesson this notification is about, if any
  created_at  timestamptz not null default now()
);

-- `create table if not exists` above is a no-op on a project that already
-- has this table — add the column explicitly so re-running this file on an
-- existing project still picks it up.
alter table public.notifications add column if not exists slot_id uuid references public.lesson_slots (id) on delete set null;

-- =============================================================================
-- Indexes
-- =============================================================================

create index if not exists idx_lesson_slots_trainer_date on public.lesson_slots (trainer_id, lesson_date);
create index if not exists idx_lesson_slots_series on public.lesson_slots (series_id) where series_id is not null;
create index if not exists idx_bookings_slot on public.bookings (slot_id);
create index if not exists idx_bookings_rider on public.bookings (rider_id);
create index if not exists idx_links_trainer on public.trainer_rider_links (trainer_id);
create index if not exists idx_links_rider on public.trainer_rider_links (rider_id);
create index if not exists idx_notifications_user_created on public.notifications (user_id, created_at desc);
create index if not exists idx_lesson_requests_trainer_status on public.lesson_requests (trainer_id, status);
create index if not exists idx_lesson_requests_rider on public.lesson_requests (rider_id);

-- =============================================================================
-- updated_at helper trigger
-- =============================================================================

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

drop trigger if exists trg_lesson_slots_updated_at on public.lesson_slots;
create trigger trg_lesson_slots_updated_at
  before update on public.lesson_slots
  for each row execute function public.set_updated_at();

-- =============================================================================
-- Invite code generation for trainers ("vogt-3f9a" style)
-- =============================================================================

create or replace function public.generate_invite_code(p_full_name text)
returns text
language plpgsql
set search_path = public, extensions
as $$
declare
  base text;
  candidate text;
  suffix text;
  attempt int := 0;
begin
  base := lower(regexp_replace(coalesce(split_part(p_full_name, ' ', 2), split_part(p_full_name, ' ', 1)), '[^a-zA-Z0-9]', '', 'g'));
  if base is null or base = '' then
    base := 'trainer';
  end if;

  loop
    suffix := lower(substr(encode(gen_random_bytes(4), 'hex'), 1, 4));
    candidate := base || '-' || suffix;
    exit when not exists (select 1 from public.profiles where invite_code = candidate);
    attempt := attempt + 1;
    exit when attempt > 20; -- practically unreachable, just a safety valve
  end loop;

  return candidate;
end;
$$;

-- =============================================================================
-- auth.users -> public.profiles bootstrap
-- Reads role/full_name/facility/discipline and the trainer's slot-creation
-- defaults out of the signUp() `data` payload sent from the Flutter app and
-- creates the matching profile row.
-- =============================================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_role text;
  v_full_name text;
  v_facility text;
  v_discipline text;
  v_default_duration int;
  v_default_slot_mode text;
  v_default_repeat text;
begin
  v_role := coalesce(new.raw_user_meta_data ->> 'role', 'rider');
  v_full_name := coalesce(new.raw_user_meta_data ->> 'full_name', split_part(new.email, '@', 1));
  v_facility := new.raw_user_meta_data ->> 'facility';
  v_discipline := new.raw_user_meta_data ->> 'discipline';
  v_default_duration := coalesce((new.raw_user_meta_data ->> 'default_duration_minutes')::int, 45);
  v_default_slot_mode := coalesce(new.raw_user_meta_data ->> 'default_slot_mode', 'single');
  v_default_repeat := coalesce(new.raw_user_meta_data ->> 'default_repeat', 'Einmalig');

  insert into public.profiles (
    id, role, full_name, facility, discipline, invite_code,
    is_trainer, is_rider,
    default_duration_minutes, default_slot_mode, default_repeat
  )
  values (
    new.id,
    v_role,
    v_full_name,
    v_facility,
    v_discipline,
    case when v_role = 'trainer' then public.generate_invite_code(v_full_name) else null end,
    v_role = 'trainer',
    v_role = 'rider',
    v_default_duration,
    v_default_slot_mode,
    v_default_repeat
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists trg_on_auth_user_created on auth.users;
create trigger trg_on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- =============================================================================
-- Redeem a trainer's invite link/code (rider action). Trainers are never
-- publicly listable — this SECURITY DEFINER function is the only way a rider
-- can resolve a trainer profile, and only if they already hold the exact code.
-- =============================================================================

create or replace function public.link_trainer_by_code(p_code text)
returns public.profiles
language plpgsql
security definer set search_path = public
as $$
declare
  v_trainer public.profiles;
  v_code text;
begin
  -- accepts either a bare code ("vogt-3f9a") or a full share link
  -- ("reitstunden.app/k/vogt-3f9a")
  v_code := regexp_replace(trim(p_code), '^.*/', '');

  select * into v_trainer from public.profiles
    where invite_code = v_code and is_trainer = true;

  if v_trainer.id is null then
    raise exception 'Kein Reitlehrer mit diesem Link gefunden.';
  end if;

  if auth.uid() is null then
    raise exception 'Nicht angemeldet.';
  end if;

  insert into public.trainer_rider_links (trainer_id, rider_id)
  values (v_trainer.id, auth.uid())
  on conflict (trainer_id, rider_id) do nothing;

  return v_trainer;
end;
$$;

grant execute on function public.link_trainer_by_code(text) to authenticated;

-- =============================================================================
-- Turning an existing (rider-only) account into a trainer too, or vice versa
-- for the rider side — "beide Rollen gleichzeitig". Becoming a trainer needs
-- an invite_code, generated once and kept from then on; becoming a rider
-- needs no extra data, so the app just flips `is_rider` via a plain update
-- (already allowed by profiles_update_own).
-- =============================================================================

create or replace function public.activate_trainer_role()
returns public.profiles
language plpgsql
set search_path = public, extensions
as $$
declare
  v_profile public.profiles;
begin
  if auth.uid() is null then
    raise exception 'Nicht angemeldet.';
  end if;

  update public.profiles
  set is_trainer = true,
      invite_code = coalesce(invite_code, public.generate_invite_code(full_name))
  where id = auth.uid()
  returning * into v_profile;

  return v_profile;
end;
$$;

grant execute on function public.activate_trainer_role() to authenticated;

-- =============================================================================
-- Approve a rider's lesson request: publishes the matching lesson_slots row
-- (capacity 1) and books the requesting rider into it, atomically. Runs as
-- the trainer (checked via auth.uid()), so it needs no extra insert policies
-- on lesson_slots/bookings beyond the ones trainers already have.
-- =============================================================================

create or replace function public.approve_lesson_request(p_request_id uuid)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  v_req public.lesson_requests;
  v_facility text;
  v_slot_id uuid;
begin
  select * into v_req from public.lesson_requests where id = p_request_id for update;

  if v_req.id is null then
    raise exception 'Anfrage nicht gefunden.';
  end if;
  if v_req.trainer_id <> auth.uid() then
    raise exception 'Nicht berechtigt.';
  end if;
  if v_req.status <> 'pending' then
    raise exception 'Anfrage wurde bereits bearbeitet.';
  end if;

  select facility into v_facility from public.profiles where id = v_req.trainer_id;

  insert into public.lesson_slots
    (trainer_id, lesson_date, start_time, duration_minutes, discipline, location_kind, facility, capacity, status)
  values
    (v_req.trainer_id, v_req.requested_date, v_req.requested_time, v_req.duration_minutes,
     v_req.discipline, v_req.location_kind, coalesce(v_facility, ''), 1, 'open')
  returning id into v_slot_id;

  insert into public.bookings (slot_id, rider_id) values (v_slot_id, v_req.rider_id);

  update public.lesson_requests
    set status = 'approved', resulting_slot_id = v_slot_id
    where id = p_request_id;

  return v_slot_id;
end;
$$;

grant execute on function public.approve_lesson_request(uuid) to authenticated;

-- =============================================================================
-- Guard against overbooking a slot (race-safe seat check on insert)
-- =============================================================================

create or replace function public.check_slot_capacity()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_capacity int;
  v_status text;
  v_taken int;
begin
  select capacity, status into v_capacity, v_status
    from public.lesson_slots where id = new.slot_id
    for update; -- serializes concurrent bookings against the same slot

  if v_status <> 'open' then
    raise exception 'Diese Stunde ist nicht mehr buchbar.';
  end if;

  select count(*) into v_taken from public.bookings where slot_id = new.slot_id;

  if v_taken >= v_capacity then
    raise exception 'Diese Stunde ist bereits ausgebucht.';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_check_slot_capacity on public.bookings;
create trigger trg_check_slot_capacity
  before insert on public.bookings
  for each row execute function public.check_slot_capacity();

-- =============================================================================
-- Row Level Security
-- =============================================================================

alter table public.profiles enable row level security;
alter table public.trainer_rider_links enable row level security;
alter table public.lesson_slots enable row level security;
alter table public.bookings enable row level security;
alter table public.notifications enable row level security;
alter table public.lesson_requests enable row level security;
alter table public.student_notes enable row level security;

-- ---------- profiles ----------
-- Trainers are a public directory ("Trainer finden") — any signed-in user
-- can read a trainer's public fields (name/facility/address/invite_code) to
-- search and link. Non-trainer profiles stay private to the owner and
-- whoever they're linked with.

drop policy if exists "profiles_select_own_or_linked" on public.profiles;
create policy "profiles_select_own_or_linked"
  on public.profiles for select
  using (
    id = auth.uid()
    or exists (
      select 1 from public.trainer_rider_links l
      where (l.trainer_id = profiles.id and l.rider_id = auth.uid())
         or (l.rider_id = profiles.id and l.trainer_id = auth.uid())
    )
  );

drop policy if exists "profiles_select_public_trainers" on public.profiles;
create policy "profiles_select_public_trainers"
  on public.profiles for select
  using (is_trainer = true);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update
  using (id = auth.uid())
  with check (id = auth.uid());

-- No insert policy: rows are created exclusively by the handle_new_user()
-- trigger (SECURITY DEFINER), never directly by clients.

-- ---------- trainer_rider_links ----------
-- No insert/delete policy for clients: links are created exclusively via the
-- link_trainer_by_code() RPC (SECURITY DEFINER) so a rider can never link an
-- arbitrary trainer_id without holding that trainer's invite code.

drop policy if exists "links_select_own" on public.trainer_rider_links;
create policy "links_select_own"
  on public.trainer_rider_links for select
  using (trainer_id = auth.uid() or rider_id = auth.uid());

-- ---------- lesson_slots ----------

drop policy if exists "slots_select_own_trainer" on public.lesson_slots;
create policy "slots_select_own_trainer"
  on public.lesson_slots for select
  using (trainer_id = auth.uid());

drop policy if exists "slots_select_linked_rider" on public.lesson_slots;
create policy "slots_select_linked_rider"
  on public.lesson_slots for select
  using (
    exists (
      select 1 from public.trainer_rider_links l
      where l.trainer_id = lesson_slots.trainer_id and l.rider_id = auth.uid()
    )
  );

drop policy if exists "slots_insert_own_trainer" on public.lesson_slots;
create policy "slots_insert_own_trainer"
  on public.lesson_slots for insert
  with check (
    trainer_id = auth.uid()
    and exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_trainer = true)
  );

drop policy if exists "slots_update_own_trainer" on public.lesson_slots;
create policy "slots_update_own_trainer"
  on public.lesson_slots for update
  using (trainer_id = auth.uid())
  with check (trainer_id = auth.uid());

drop policy if exists "slots_delete_own_trainer" on public.lesson_slots;
create policy "slots_delete_own_trainer"
  on public.lesson_slots for delete
  using (trainer_id = auth.uid());

-- ---------- bookings ----------

drop policy if exists "bookings_select_own_rider" on public.bookings;
create policy "bookings_select_own_rider"
  on public.bookings for select
  using (rider_id = auth.uid());

drop policy if exists "bookings_select_trainer_of_slot" on public.bookings;
create policy "bookings_select_trainer_of_slot"
  on public.bookings for select
  using (
    exists (
      select 1 from public.lesson_slots s
      where s.id = bookings.slot_id and s.trainer_id = auth.uid()
    )
  );

drop policy if exists "bookings_insert_own_rider" on public.bookings;
create policy "bookings_insert_own_rider"
  on public.bookings for insert
  with check (
    rider_id = auth.uid()
    and exists (
      select 1 from public.lesson_slots s
      join public.trainer_rider_links l on l.trainer_id = s.trainer_id
      where s.id = bookings.slot_id
        and s.status = 'open'
        and l.rider_id = auth.uid()
    )
  );

drop policy if exists "bookings_delete_own_rider" on public.bookings;
create policy "bookings_delete_own_rider"
  on public.bookings for delete
  using (rider_id = auth.uid());

-- A trainer can also remove a rider from one of their own lesson slots
-- ("ausladen") — e.g. to free up the seat or move them to another time.
drop policy if exists "bookings_delete_own_trainer" on public.bookings;
create policy "bookings_delete_own_trainer"
  on public.bookings for delete
  using (
    exists (
      select 1 from public.lesson_slots s
      where s.id = bookings.slot_id and s.trainer_id = auth.uid()
    )
  );

-- ---------- notifications ----------

drop policy if exists "notifications_select_own" on public.notifications;
create policy "notifications_select_own"
  on public.notifications for select
  using (user_id = auth.uid());

drop policy if exists "notifications_update_own" on public.notifications;
create policy "notifications_update_own"
  on public.notifications for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "notifications_delete_own" on public.notifications;
create policy "notifications_delete_own"
  on public.notifications for delete
  using (user_id = auth.uid());

-- A user may create a notification for themself, or for the counterpart of
-- an existing trainer<->rider link (e.g. a trainer notifying a linked rider
-- that a new slot was published, or a rider notifying their trainer about a
-- new booking).
drop policy if exists "notifications_insert_own_or_linked" on public.notifications;
create policy "notifications_insert_own_or_linked"
  on public.notifications for insert
  with check (
    user_id = auth.uid()
    or exists (
      select 1 from public.trainer_rider_links l
      where (l.trainer_id = auth.uid() and l.rider_id = notifications.user_id)
         or (l.rider_id = auth.uid() and l.trainer_id = notifications.user_id)
    )
  );

-- ---------- lesson_requests ----------

drop policy if exists "lesson_requests_select_own_rider" on public.lesson_requests;
create policy "lesson_requests_select_own_rider"
  on public.lesson_requests for select
  using (rider_id = auth.uid());

drop policy if exists "lesson_requests_select_own_trainer" on public.lesson_requests;
create policy "lesson_requests_select_own_trainer"
  on public.lesson_requests for select
  using (trainer_id = auth.uid());

-- A rider may only request a time from a trainer they're linked to, and
-- only while that trainer has opted into requests.
drop policy if exists "lesson_requests_insert_own_rider" on public.lesson_requests;
create policy "lesson_requests_insert_own_rider"
  on public.lesson_requests for insert
  with check (
    rider_id = auth.uid()
    and exists (
      select 1 from public.trainer_rider_links l
      where l.trainer_id = lesson_requests.trainer_id and l.rider_id = auth.uid()
    )
    and exists (
      select 1 from public.profiles p
      where p.id = lesson_requests.trainer_id and p.allow_requests = true
    )
  );

-- Status changes (approve/decline) go through approve_lesson_request() or a
-- plain decline update — both run as the trainer.
drop policy if exists "lesson_requests_update_own_trainer" on public.lesson_requests;
create policy "lesson_requests_update_own_trainer"
  on public.lesson_requests for update
  using (trainer_id = auth.uid())
  with check (trainer_id = auth.uid());

-- A rider may withdraw a request they haven't heard back on yet.
drop policy if exists "lesson_requests_delete_own_rider_pending" on public.lesson_requests;
create policy "lesson_requests_delete_own_rider_pending"
  on public.lesson_requests for delete
  using (rider_id = auth.uid() and status = 'pending');

-- ---------- student_notes ----------
-- Private to the trainer who wrote them — riders never see these.

drop policy if exists "student_notes_select_own_trainer" on public.student_notes;
create policy "student_notes_select_own_trainer"
  on public.student_notes for select
  using (trainer_id = auth.uid());

drop policy if exists "student_notes_insert_own_trainer" on public.student_notes;
create policy "student_notes_insert_own_trainer"
  on public.student_notes for insert
  with check (
    trainer_id = auth.uid()
    and exists (
      select 1 from public.trainer_rider_links l
      where l.trainer_id = auth.uid() and l.rider_id = student_notes.rider_id
    )
  );

drop policy if exists "student_notes_delete_own_trainer" on public.student_notes;
create policy "student_notes_delete_own_trainer"
  on public.student_notes for delete
  using (trainer_id = auth.uid());

-- =============================================================================
-- Feature requests — an open in-app board where any signed-in user (trainer
-- or rider) can propose a feature and up-/downvote others' proposals. One
-- vote per user per request; voting again with the same value removes it,
-- a different value replaces it (handled client-side via upsert/delete).
-- =============================================================================

create table if not exists public.feature_requests (
  id           uuid primary key default gen_random_uuid(),
  author_id    uuid not null references public.profiles (id) on delete cascade,
  title        text not null,
  description  text,
  created_at   timestamptz not null default now()
);

create table if not exists public.feature_votes (
  id          uuid primary key default gen_random_uuid(),
  request_id  uuid not null references public.feature_requests (id) on delete cascade,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  value       int not null check (value in (-1, 1)),
  created_at  timestamptz not null default now(),
  unique (request_id, user_id)
);

create index if not exists idx_feature_votes_request on public.feature_votes (request_id);

alter table public.feature_requests enable row level security;
alter table public.feature_votes enable row level security;

drop policy if exists "feature_requests_select_all" on public.feature_requests;
create policy "feature_requests_select_all"
  on public.feature_requests for select
  using (true);

drop policy if exists "feature_requests_insert_own" on public.feature_requests;
create policy "feature_requests_insert_own"
  on public.feature_requests for insert
  with check (author_id = auth.uid());

drop policy if exists "feature_requests_delete_own" on public.feature_requests;
create policy "feature_requests_delete_own"
  on public.feature_requests for delete
  using (author_id = auth.uid());

drop policy if exists "feature_votes_select_all" on public.feature_votes;
create policy "feature_votes_select_all"
  on public.feature_votes for select
  using (true);

drop policy if exists "feature_votes_insert_own" on public.feature_votes;
create policy "feature_votes_insert_own"
  on public.feature_votes for insert
  with check (user_id = auth.uid());

drop policy if exists "feature_votes_update_own" on public.feature_votes;
create policy "feature_votes_update_own"
  on public.feature_votes for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "feature_votes_delete_own" on public.feature_votes;
create policy "feature_votes_delete_own"
  on public.feature_votes for delete
  using (user_id = auth.uid());

-- =============================================================================
-- Avatar storage — a public "avatars" bucket, each user may only
-- write/update/delete files under a path prefixed with their own uid
-- (e.g. "<uid>/avatar.jpg"); anyone can read (avatars are public images).
-- =============================================================================

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

drop policy if exists "avatar_public_read" on storage.objects;
create policy "avatar_public_read"
  on storage.objects for select
  using (bucket_id = 'avatars');

drop policy if exists "avatar_owner_write" on storage.objects;
create policy "avatar_owner_write"
  on storage.objects for insert
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "avatar_owner_update" on storage.objects;
create policy "avatar_owner_update"
  on storage.objects for update
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "avatar_owner_delete" on storage.objects;
create policy "avatar_owner_delete"
  on storage.objects for delete
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

-- =============================================================================
-- Realtime (optional but used by the Flutter app for live slot/booking/
-- notification updates)
-- =============================================================================

do $$
begin
  alter publication supabase_realtime add table public.lesson_slots;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.bookings;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.notifications;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.lesson_requests;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.feature_requests;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.feature_votes;
exception when duplicate_object then null;
end $$;
