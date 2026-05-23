-- ════════════════════════════════════════════════════════════
-- Vietnam Trip — Supabase Schema
-- Ejecuta este archivo en: Supabase Dashboard → SQL Editor
-- ════════════════════════════════════════════════════════════

-- ── Perfiles de usuario ──────────────────────────────────────
create table if not exists profiles (
  id            uuid references auth.users on delete cascade primary key,
  name          text        not null default 'Viajero',
  friend_id     text        not null default 'victor', -- 'victor' | 'ronald' | 'jose'
  avatar_emoji  text        not null default '🧳',
  color         text        not null default '#2dd4bf',
  role          text        not null default 'El Viajero',
  avatar_url    text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- ── Estado compartido del viaje (1 fila para el grupo) ───────
create table if not exists trip_state (
  id              int         primary key default 1,
  current_day     int         not null default 1,
  completed_days  int[]       not null default '{}',
  visited_cities  text[]      not null default '{}',
  tried_foods     text[]      not null default '{}',
  tried_drinks    text[]      not null default '{}',
  updated_at      timestamptz not null default now()
);
insert into trip_state (id) values (1) on conflict do nothing;

-- ── Registro de alcohol (por usuario y día) ──────────────────
create table if not exists alcohol_log (
  id          uuid        primary key default gen_random_uuid(),
  user_id     uuid        not null references auth.users on delete cascade,
  day_num     int         not null,
  beers       int         not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique(user_id, day_num)
);

-- ── Resultados de quiz (por usuario y día) ───────────────────
create table if not exists quiz_results (
  id          uuid        primary key default gen_random_uuid(),
  user_id     uuid        not null references auth.users on delete cascade,
  day_num     int         not null,
  score       int         not null,
  total       int         not null,
  created_at  timestamptz not null default now(),
  unique(user_id, day_num)
);

-- ── Valoraciones de comida/bebida (por usuario) ──────────────
create table if not exists food_ratings (
  id          uuid        primary key default gen_random_uuid(),
  user_id     uuid        not null references auth.users on delete cascade,
  food_name   text        not null,
  item_type   text        not null default 'food',
  rating      int,
  comment     text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique(user_id, food_name)
);

-- ── Notas personales (por usuario y día) ─────────────────────
create table if not exists notes (
  id          uuid        primary key default gen_random_uuid(),
  user_id     uuid        not null references auth.users on delete cascade,
  day_num     int         not null,
  content     text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique(user_id, day_num)
);

-- ── Logros desbloqueados (por usuario) ───────────────────────
create table if not exists user_achievements (
  id             uuid        primary key default gen_random_uuid(),
  user_id        uuid        not null references auth.users on delete cascade,
  achievement_id text        not null,
  unlocked_at    timestamptz not null default now(),
  unique(user_id, achievement_id)
);

-- ════════════════════════════════════════════════════════════
-- Row Level Security (RLS)
-- ════════════════════════════════════════════════════════════

alter table profiles          enable row level security;
alter table trip_state        enable row level security;
alter table alcohol_log       enable row level security;
alter table quiz_results      enable row level security;
alter table food_ratings      enable row level security;
alter table notes             enable row level security;
alter table user_achievements enable row level security;

-- profiles: todos los autenticados pueden leer, solo el propio puede editar
create policy "profiles_select" on profiles for select using (auth.role() = 'authenticated');
create policy "profiles_insert" on profiles for insert with check (auth.uid() = id);
create policy "profiles_update" on profiles for update using (auth.uid() = id);

-- trip_state: todos pueden leer y actualizar (estado compartido del grupo)
create policy "trip_state_select" on trip_state for select using (auth.role() = 'authenticated');
create policy "trip_state_update" on trip_state for update using (auth.role() = 'authenticated');

-- alcohol_log: todos pueden leer, solo el propio puede escribir
create policy "alcohol_log_select" on alcohol_log for select using (auth.role() = 'authenticated');
create policy "alcohol_log_insert" on alcohol_log for insert with check (auth.uid() = user_id);
create policy "alcohol_log_update" on alcohol_log for update using (auth.uid() = user_id);
create policy "alcohol_log_delete" on alcohol_log for delete using (auth.uid() = user_id);

-- quiz_results: todos pueden leer, solo el propio puede escribir
create policy "quiz_results_select" on quiz_results for select using (auth.role() = 'authenticated');
create policy "quiz_results_insert" on quiz_results for insert with check (auth.uid() = user_id);
create policy "quiz_results_update" on quiz_results for update using (auth.uid() = user_id);

-- food_ratings: todos pueden leer, solo el propio puede escribir
create policy "food_ratings_select" on food_ratings for select using (auth.role() = 'authenticated');
create policy "food_ratings_insert" on food_ratings for insert with check (auth.uid() = user_id);
create policy "food_ratings_update" on food_ratings for update using (auth.uid() = user_id);
create policy "food_ratings_delete" on food_ratings for delete using (auth.uid() = user_id);

-- notes: solo el propio usuario puede leer y escribir
create policy "notes_select" on notes for select using (auth.uid() = user_id);
create policy "notes_insert" on notes for insert with check (auth.uid() = user_id);
create policy "notes_update" on notes for update using (auth.uid() = user_id);
create policy "notes_delete" on notes for delete using (auth.uid() = user_id);

-- user_achievements: todos pueden leer, solo el propio puede insertar/borrar
create policy "achievements_select" on user_achievements for select using (auth.role() = 'authenticated');
create policy "achievements_insert" on user_achievements for insert with check (auth.uid() = user_id);
create policy "achievements_delete" on user_achievements for delete using (auth.uid() = user_id);

-- ════════════════════════════════════════════════════════════
-- Storage bucket para fotos de perfil
-- ════════════════════════════════════════════════════════════
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict do nothing;

create policy "Avatar images are public" on storage.objects
  for select using (bucket_id = 'avatars');

create policy "Users can upload own avatar" on storage.objects
  for insert with check (bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]);

create policy "Users can update own avatar" on storage.objects
  for update using (bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]);
