begin;
create table public.savings_goals (
 id uuid primary key,
 user_id uuid not null references auth.users(id) on delete cascade,
 name text not null check(length(trim(name)) between 1 and 120),
 target bigint not null check(target > 0 and target <= 9000000000000),
 currency text not null check(currency in ('IRT','USD','EUR','GBP')),
 deadline date not null,
 account_id uuid not null,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(user_id,account_id),
 foreign key(account_id,user_id) references public.accounts(id,user_id)
);
create index savings_goals_account_owner on public.savings_goals(account_id,user_id);
alter table public.savings_goals enable row level security;
revoke all on public.savings_goals from public,anon,authenticated;
grant select,insert,update,delete on public.savings_goals to authenticated;
create policy goals_owner on public.savings_goals for all to authenticated
 using((select auth.uid())=user_id) with check((select auth.uid())=user_id);

create function public.validate_savings_goal() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
 perform 1 from public.accounts where id=new.account_id and user_id=new.user_id
 and kind='Savings' and currency=new.currency for update;
 if not found then raise exception 'Choose your savings account in this currency'; end if;
 if new.deadline < (now() at time zone 'Pacific/Honolulu')::date and
 (tg_op='INSERT' or new.deadline is distinct from old.deadline) then
 raise exception 'Choose today or a future deadline'; end if;
 new.name := trim(new.name);
 new.updated_at := now();
 return new;
end; $$;
revoke all on function public.validate_savings_goal() from public,anon,authenticated;
create trigger validate_savings_goal before insert or update on public.savings_goals
 for each row execute function public.validate_savings_goal();

create function public.guard_goal_account() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
 if (new.kind,new.currency,new.user_id,new.id) is distinct from (old.kind,old.currency,old.user_id,old.id)
 and exists(select 1 from public.savings_goals where account_id=old.id and user_id=old.user_id) then
 raise exception 'Remove or relink the savings goal before changing this account'; end if;
 return new;
end; $$;
revoke all on function public.guard_goal_account() from public,anon,authenticated;
create trigger guard_goal_account before update on public.accounts for each row execute function public.guard_goal_account();

create function public.save_savings_goal(payload jsonb) returns void
language plpgsql security invoker set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 -- Use UPDATE first so unchanged overdue deadlines remain editable without an insert trigger.
 update public.savings_goals set name=trim(payload->>'name'),target=(payload->>'target')::bigint,
 currency=payload->>'currency',deadline=(payload->>'deadline')::date,account_id=(payload->>'account_id')::uuid
 where id=(payload->>'id')::uuid and user_id=auth.uid();
 if not found then
 insert into public.savings_goals(id,user_id,name,target,currency,deadline,account_id)
 values((payload->>'id')::uuid,auth.uid(),trim(payload->>'name'),(payload->>'target')::bigint,
 payload->>'currency',(payload->>'deadline')::date,(payload->>'account_id')::uuid);
 end if;
end; $$;
revoke all on function public.save_savings_goal(jsonb) from public,anon;
grant execute on function public.save_savings_goal(jsonb) to authenticated;

create or replace function public.read_ledger() returns jsonb language sql stable security invoker set search_path='' as $$
select jsonb_build_object(
 'accounts',coalesce((select jsonb_agg(a order by a.created_at) from public.accounts a where a.user_id=(select auth.uid())),'[]'::jsonb),
 'entries',coalesce((select jsonb_agg(e order by e.date desc,e.created_at desc) from public.entries e where e.user_id=(select auth.uid())),'[]'::jsonb),
 'reminders',coalesce((select jsonb_agg(r order by r.due_date,r.created_at) from public.expense_reminders r where r.user_id=(select auth.uid())),'[]'::jsonb),
 'expected_income',coalesce((select jsonb_agg(i order by i.due_date,i.created_at) from public.expected_income i where i.user_id=(select auth.uid())),'[]'::jsonb),
 'plan_settings',coalesce((select jsonb_agg(p) from public.plan_settings p where p.user_id=(select auth.uid())),'[]'::jsonb),
 'savings_goals',coalesce((select jsonb_agg(g order by g.created_at) from public.savings_goals g where g.user_id=(select auth.uid())),'[]'::jsonb)
); $$;
revoke all on function public.read_ledger() from public,anon;
grant execute on function public.read_ledger() to authenticated;
commit;
