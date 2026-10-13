begin;
create or replace function public.validate_savings_goal() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
 perform pg_advisory_xact_lock(hashtextextended(new.account_id::text,0));
 perform 1 from public.accounts where id=new.account_id and user_id=new.user_id
 and kind='Savings' and currency=new.currency;
 if not found then raise exception 'Choose your savings account in this currency'; end if;
 if new.deadline < (now() at time zone 'Pacific/Honolulu')::date and
 (tg_op='INSERT' or new.deadline is distinct from old.deadline) then
 raise exception 'Choose today or a future deadline'; end if;
 new.name := trim(new.name);
 new.updated_at := now();
 return new;
end; $$;
create or replace function public.guard_goal_account() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
 perform pg_advisory_xact_lock(hashtextextended(old.id::text,0));
 if (new.kind,new.currency,new.user_id,new.id) is distinct from (old.kind,old.currency,old.user_id,old.id)
 and exists(select 1 from public.savings_goals where account_id=old.id and user_id=old.user_id) then
 raise exception 'Remove or relink the savings goal before changing this account'; end if;
 return new;
end; $$;
commit;
