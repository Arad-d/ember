begin;
create table public.expected_income (
 id uuid primary key,
 user_id uuid not null references auth.users(id) on delete cascade,
 title text not null check(length(trim(title)) between 1 and 120),
 category text not null,
 account_id uuid not null,
 amount bigint not null check(amount > 0 and amount <= 9000000000000),
 due_date date not null,
 note text not null default '' check(length(note)<=1000),
 paid_date date,
 created_at timestamptz not null default now(),
 foreign key(account_id,user_id) references public.accounts(id,user_id)
);
create index expected_income_owner_due on public.expected_income(user_id,due_date);
create index expected_income_account on public.expected_income(account_id,user_id);
alter table public.expected_income enable row level security;
revoke all on public.expected_income from public,anon,authenticated;
grant select,insert,update,delete on public.expected_income to authenticated;
create policy income_owner on public.expected_income for all to authenticated
 using((select auth.uid())=user_id) with check((select auth.uid())=user_id);
create table public.plan_settings (
 user_id uuid not null references auth.users(id) on delete cascade,
 currency text not null check(currency in ('IRT','USD','EUR','GBP')),
 account_ids uuid[],
 reserve bigint not null default 0 check(reserve>=0 and reserve<=9000000000000),
 primary key(user_id,currency)
);
alter table public.plan_settings enable row level security;
revoke all on public.plan_settings from public,anon,authenticated;
grant select,insert,update,delete on public.plan_settings to authenticated;
create policy settings_owner on public.plan_settings for all to authenticated
 using((select auth.uid())=user_id) with check((select auth.uid())=user_id);

create function public.save_expected_income(payload jsonb) returns void
language plpgsql security invoker set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 insert into public.expected_income(id,user_id,title,category,account_id,amount,due_date)
 values((payload->>'id')::uuid,auth.uid(),trim(payload->>'title'),payload->>'category',
 (payload->>'account_id')::uuid,(payload->>'amount')::bigint,(payload->>'due_date')::date)
 on conflict(id) do update set title=excluded.title,category=excluded.category,
 account_id=excluded.account_id,amount=excluded.amount,due_date=excluded.due_date
 where expected_income.user_id=auth.uid() and expected_income.paid_date is null;
 if not found then raise exception 'Income already received or unavailable'; end if;
end;
$$;
create function public.receive_expected_income(income_id uuid, receipt_date date) returns void
language plpgsql security invoker set search_path='' as $$
declare item public.expected_income;
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 if receipt_date is null or receipt_date > (now() at time zone 'Pacific/Kiritimati')::date then raise exception 'Invalid receipt date'; end if;
 select * into item from public.expected_income where id=income_id and user_id=auth.uid() for update;
 if not found then raise exception 'Income unavailable'; end if;
 if item.paid_date is not null then return; end if;
 insert into public.entries(id,user_id,title,type,category,account_id,amount,date)
 values(item.id,auth.uid(),item.title,'income',item.category,item.account_id,item.amount,receipt_date);
 update public.expected_income set paid_date=receipt_date where id=item.id and user_id=auth.uid();
end;
$$;
create function public.save_plan_settings(payload jsonb) returns void
language plpgsql security invoker set search_path='' as $$
declare ids uuid[];
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 if payload->'account_ids' is not null and payload->'account_ids'<>'null'::jsonb then
   ids := array(select jsonb_array_elements_text(payload->'account_ids')::uuid);
   if exists(select 1 from unnest(ids) i where not exists(select 1 from public.accounts a where a.id=i and a.user_id=auth.uid() and a.currency=payload->>'currency')) then raise exception 'Invalid account selection'; end if;
 end if;
 insert into public.plan_settings(user_id,currency,account_ids,reserve)
 values(auth.uid(),payload->>'currency',ids,(payload->>'reserve')::bigint)
 on conflict(user_id,currency) do update set account_ids=excluded.account_ids,reserve=excluded.reserve;
end;
$$;
revoke all on function public.save_expected_income(jsonb), public.receive_expected_income(uuid,date), public.save_plan_settings(jsonb) from public,anon;
grant execute on function public.save_expected_income(jsonb), public.receive_expected_income(uuid,date), public.save_plan_settings(jsonb) to authenticated;
create or replace function public.read_ledger() returns jsonb language sql stable security invoker set search_path='' as $$
select jsonb_build_object(
 'accounts',coalesce((select jsonb_agg(a order by a.created_at) from public.accounts a where a.user_id=(select auth.uid())),'[]'::jsonb),
 'entries',coalesce((select jsonb_agg(e order by e.date desc,e.created_at desc) from public.entries e where e.user_id=(select auth.uid())),'[]'::jsonb),
 'reminders',coalesce((select jsonb_agg(r order by r.due_date,r.created_at) from public.expense_reminders r where r.user_id=(select auth.uid())),'[]'::jsonb),
 'expected_income',coalesce((select jsonb_agg(i order by i.due_date,i.created_at) from public.expected_income i where i.user_id=(select auth.uid())),'[]'::jsonb),
 'plan_settings',coalesce((select jsonb_agg(p) from public.plan_settings p where p.user_id=(select auth.uid())),'[]'::jsonb)
);
$$;
revoke all on function public.read_ledger() from public,anon;
grant execute on function public.read_ledger() to authenticated;
commit;
