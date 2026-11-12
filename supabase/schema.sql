create extension if not exists pgcrypto;

create table if not exists public.presenters (
  id text primary key,
  name text not null,
  sort_order integer not null unique,
  active boolean not null default true
);

insert into public.presenters (id, name, sort_order) values
  ('project-01', 'Roy yarhi', 1),
  ('project-02', 'Victoria Elkind', 2),
  ('project-03', 'Yaniv Afingar', 3),
  ('project-04', 'Dor Yosef', 4),
  ('project-05', 'Elias Khoury', 5),
  ('project-06', 'Roshdy Abu Alteef', 6),
  ('project-07', 'אלכס רויף', 7)
on conflict (id) do update
set name = excluded.name,
    sort_order = excluded.sort_order,
    active = true;

create table if not exists public.votes (
  id uuid primary key default gen_random_uuid(),
  voter_name text not null check (char_length(btrim(voter_name)) between 1 and 80),
  voter_name_key text generated always as (lower(btrim(voter_name))) stored,
  voter_role text not null check (voter_role in ('audience', 'judge')),
  presenter_id text not null references public.presenters(id) on update cascade on delete restrict,
  presenter_name text not null,
  score smallint not null check (score between 1 and 10),
  created_at timestamptz not null default now()
);

create unique index if not exists votes_one_per_voter_role_presenter
  on public.votes (voter_role, voter_name_key, presenter_id);

alter table public.presenters enable row level security;
alter table public.votes enable row level security;

revoke all on public.presenters from anon, authenticated;
revoke all on public.votes from anon, authenticated;
