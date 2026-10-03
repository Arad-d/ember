-- Apply after schema.sql to add bill reminders.
begin;
create table public.expense_reminders (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (length(trim(title)) between 1 and 120),
  category text not null,
  account_id uuid not null,
  amount bigint not null check (amount > 0 and amount <= 9000000000000),
  due_date date not null,
  note text not null default '' check (length(note) <= 1000),
  paid_date date,
  created_at timestamptz not null default now(),
  foreign key(account_id, user_id) references public.accounts(id, user_id)
);
create index reminders_owner_due on public.expense_reminders(user_id, due_date);
create index reminders_account on public.expense_reminders(account_id, user_id);
alter table public.expense_reminders enable row level security;
revoke all on public.expense_reminders from anon, authenticated;
grant select, insert, update, delete on public.expense_reminders to authenticated;
create policy reminders_read on public.expense_reminders for select to authenticated using ((select auth.uid()) = user_id);
create policy reminders_add on public.expense_reminders for insert to authenticated with check ((select auth.uid()) = user_id);
create policy reminders_edit on public.expense_reminders for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy reminders_remove on public.expense_reminders for delete to authenticated using ((select auth.uid()) = user_id);

create function public.save_expense_reminder(payload jsonb) returns void
language plpgsql security invoker set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  insert into public.expense_reminders (id, user_id, title, category, account_id, amount, due_date, note)
  values ((payload->>'id')::uuid, auth.uid(), trim(payload->>'title'), payload->>'category',
    (payload->>'account_id')::uuid, (payload->>'amount')::bigint, (payload->>'due_date')::date, coalesce(payload->>'note', ''))
  on conflict (id) do update set title = excluded.title, category = excluded.category,
    account_id = excluded.account_id, amount = excluded.amount, due_date = excluded.due_date, note = excluded.note
  where expense_reminders.user_id = auth.uid() and expense_reminders.paid_date is null;
  if not found then raise exception 'Reminder was already paid or is unavailable'; end if;
end;
$$;

-- Lock the reminder so simultaneous payments on two devices create one expense.
-- Insertion and the paid state commit together; a failed request can be retried.
create function public.pay_expense_reminder(reminder_id uuid, payment_date date) returns void
language plpgsql security invoker set search_path = '' as $$
declare bill public.expense_reminders;
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  if payment_date is null or payment_date > (now() at time zone 'Pacific/Kiritimati')::date then
    raise exception 'Invalid payment date';
  end if;
  select * into bill from public.expense_reminders
    where id = reminder_id and user_id = auth.uid() for update;
  if not found then raise exception 'Reminder unavailable'; end if;
  if bill.paid_date is not null then return; end if;
  insert into public.entries (id, user_id, title, type, category, account_id, amount, date)
    values (bill.id, auth.uid(), bill.title, 'expense', bill.category, bill.account_id, bill.amount, payment_date);
  update public.expense_reminders set paid_date = payment_date where id = bill.id and user_id = auth.uid();
end;
$$;
revoke all on function public.save_expense_reminder(jsonb), public.pay_expense_reminder(uuid,date) from public, anon;
grant execute on function public.save_expense_reminder(jsonb), public.pay_expense_reminder(uuid,date) to authenticated;

create or replace function public.read_ledger() returns jsonb language sql stable security invoker set search_path = '' as $$
 select jsonb_build_object(
   'accounts', coalesce((select jsonb_agg(a order by a.created_at) from public.accounts a where a.user_id=(select auth.uid())), '[]'::jsonb),
   'entries', coalesce((select jsonb_agg(e order by e.date desc,e.created_at desc) from public.entries e where e.user_id=(select auth.uid())), '[]'::jsonb),
   'reminders', coalesce((select jsonb_agg(r order by r.due_date,r.created_at) from public.expense_reminders r where r.user_id=(select auth.uid())), '[]'::jsonb)
 );
$$;
revoke all on function public.read_ledger() from public, anon;
grant execute on function public.read_ledger() to authenticated;
commit;
