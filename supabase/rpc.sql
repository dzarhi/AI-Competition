create table if not exists public.judge_access (
  singleton boolean primary key default true check (singleton),
  code text not null
);

alter table public.judge_access enable row level security;
revoke all on public.judge_access from anon, authenticated;

create or replace function public.list_presenters()
returns table (id text, name text, sort_order integer)
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select p.id, p.name, p.sort_order
  from public.presenters as p
  where p.active
  order by p.sort_order;
$$;

create or replace function public.get_my_votes(
  p_voter_name text,
  p_voter_role text,
  p_judge_code text default null
)
returns table (presenter_id text, score smallint)
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare
  normalized_name text;
begin
  if p_voter_role not in ('audience', 'judge') then
    raise exception using errcode = '22023', message = 'Invalid voter role.';
  end if;
  if char_length(btrim(p_voter_name)) not between 1 and 80 then
    raise exception using errcode = '22023', message = 'Invalid voter name.';
  end if;
  if p_voter_role = 'judge' and not exists (
    select 1 from public.judge_access where singleton and code = p_judge_code
  ) then
    raise exception using errcode = '42501', message = 'Judge code is invalid.';
  end if;

  normalized_name := lower(btrim(p_voter_name));
  return query
    select v.presenter_id, v.score
    from public.votes as v
    where v.voter_role = p_voter_role
      and v.voter_name_key = normalized_name;
end;
$$;

create or replace function public.submit_vote(
  p_voter_name text,
  p_voter_role text,
  p_judge_code text,
  p_presenter_id text,
  p_score integer
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  normalized_name text;
  presenter_row public.presenters%rowtype;
  inserted_id uuid;
begin
  if p_voter_role not in ('audience', 'judge') then
    raise exception using errcode = '22023', message = 'Invalid voter role.';
  end if;
  if char_length(btrim(p_voter_name)) not between 1 and 80 then
    raise exception using errcode = '22023', message = 'Invalid voter name.';
  end if;
  if p_score not between 1 and 10 then
    raise exception using errcode = '22023', message = 'Score must be from 1 to 10.';
  end if;
  if p_voter_role = 'judge' and not exists (
    select 1 from public.judge_access where singleton and code = p_judge_code
  ) then
    raise exception using errcode = '42501', message = 'Judge code is invalid.';
  end if;

  select * into presenter_row
  from public.presenters
  where id = p_presenter_id and active;
  if not found then
    raise exception using errcode = '22023', message = 'Presenter was not found.';
  end if;

  normalized_name := lower(btrim(p_voter_name));
  insert into public.votes (voter_name, voter_role, presenter_id, presenter_name, score)
  values (btrim(p_voter_name), p_voter_role, presenter_row.id, presenter_row.name, p_score)
  returning id into inserted_id;
  return inserted_id;
exception
  when unique_violation then
    raise exception using errcode = '23505', message = 'A vote for this presenter and voter already exists.';
end;
$$;

create or replace function public.get_results()
returns table (
  presenter_id text,
  presenter_name text,
  audience_count bigint,
  audience_average numeric,
  judge_count bigint,
  judge_average numeric,
  weighted_score numeric
)
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  with aggregates as (
    select
      p.id,
      p.name,
      count(v.id) filter (where v.voter_role = 'audience') as audience_count,
      avg(v.score) filter (where v.voter_role = 'audience') as audience_average,
      count(v.id) filter (where v.voter_role = 'judge') as judge_count,
      avg(v.score) filter (where v.voter_role = 'judge') as judge_average
    from public.presenters as p
    left join public.votes as v on v.presenter_id = p.id
    where p.active
    group by p.id, p.name, p.sort_order
  )
  select
    id,
    name,
    audience_count,
    audience_average,
    judge_count,
    judge_average,
    case when audience_average is not null and judge_average is not null
      then audience_average * 0.4 + judge_average * 0.6
      else null
    end as weighted_score
  from aggregates
  order by weighted_score desc nulls last, name;
$$;

revoke all on function public.list_presenters() from public, anon, authenticated;
revoke all on function public.get_my_votes(text, text, text) from public, anon, authenticated;
revoke all on function public.submit_vote(text, text, text, text, integer) from public, anon, authenticated;
revoke all on function public.get_results() from public, anon, authenticated;

grant execute on function public.list_presenters() to anon, authenticated;
grant execute on function public.get_my_votes(text, text, text) to anon, authenticated;
grant execute on function public.submit_vote(text, text, text, text, integer) to anon, authenticated;
grant execute on function public.get_results() to anon, authenticated;

-- Replace the placeholder with a private judge code in the SQL Editor before running this insert.
-- insert into public.judge_access (singleton, code)
-- values (true, 'REPLACE_WITH_A_PRIVATE_JUDGE_CODE')
-- on conflict (singleton) do update set code = excluded.code;
