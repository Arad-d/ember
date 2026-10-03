-- Run once when upgrading an existing Ember database.
alter table public.accounts
  add column if not exists currency text not null default 'IRT'
  check (currency in ('IRT','USD','EUR','GBP'));
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
drop trigger if exists entries_currency_check on public.entries;
create trigger entries_currency_check before insert or update on public.entries for each row execute function public.check_transfer_currency();
