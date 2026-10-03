-- Run once in a new Supabase project's SQL Editor.
create table public.accounts (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (length(trim(name)) between 1 and 60),
  kind text not null check (kind in ('Bank','Cash','Savings','Other')),
  currency text not null default 'IRT' check (currency in ('IRT','USD','EUR','GBP')),
  opening bigint not null check (abs(opening) <= 9000000000000),
  created_at timestamptz not null default now(),
  unique(id,user_id)
);
create table public.entries (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (length(trim(title)) between 1 and 120),
  type text not null check (type in ('expense','income','transfer')),
  category text not null,
  account_id uuid not null,
  destination_id uuid,
  amount bigint not null check (amount > 0 and amount <= 9000000000000),
  date date not null,
  created_at timestamptz not null default now(),
  foreign key(account_id,user_id) references public.accounts(id,user_id),
  foreign key(destination_id,user_id) references public.accounts(id,user_id),
  check ((type='transfer' and destination_id is not null and destination_id<>account_id) or (type<>'transfer' and destination_id is null))
);
create index accounts_owner on public.accounts(user_id);
create index entries_owner_date on public.entries(user_id,date);
create index entries_source_account on public.entries(account_id,user_id);
create index entries_destination_account on public.entries(destination_id,user_id)
  where destination_id is not null;
alter table public.accounts enable row level security;
alter table public.entries enable row level security;
revoke all on public.accounts, public.entries from anon,authenticated;
grant select,insert,delete on public.accounts, public.entries to authenticated;
create policy accounts_read on public.accounts for select to authenticated using ((select auth.uid())=user_id);
create policy accounts_add on public.accounts for insert to authenticated with check ((select auth.uid())=user_id);
create policy accounts_delete on public.accounts for delete to authenticated using ((select auth.uid())=user_id);
create policy entries_read on public.entries for select to authenticated using ((select auth.uid())=user_id);
create policy entries_add on public.entries for insert to authenticated with check ((select auth.uid())=user_id);
create policy entries_delete on public.entries for delete to authenticated using ((select auth.uid())=user_id);
-- One consistent snapshot, without the REST API's default 1,000-row limit.
create function public.read_ledger() returns jsonb language sql stable security invoker set search_path=public as $$
 select jsonb_build_object(
   'accounts',coalesce((select jsonb_agg(a order by a.created_at) from public.accounts a where a.user_id=(select auth.uid())),'[]'::jsonb),
   'entries',coalesce((select jsonb_agg(e order by e.date desc,e.created_at desc) from public.entries e where e.user_id=(select auth.uid())),'[]'::jsonb)
 );
$$;
revoke all on function public.read_ledger() from public,anon;
grant execute on function public.read_ledger() to authenticated;

create or replace function public.check_transfer_currency() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if new.type = 'transfer' and not exists (
 select 1 from public.accounts a join public.accounts b on b.id=new.destination_id and b.user_id=new.user_id
 where a.id=new.account_id and a.user_id=new.user_id and a.currency=b.currency
 ) then raise exception 'Transfers require accounts with the same currency'; end if;
 return new;
end;
$$;
revoke all on function public.check_transfer_currency() from public,anon,authenticated;
create trigger entries_currency_check before insert or update on public.entries for each row execute function public.check_transfer_currency();
