-- Synthetic records only; every change is rolled back.
begin;
insert into auth.users(id) values ('11111111-1111-4111-8111-111111111111'),('22222222-2222-4222-8222-222222222222');
insert into public.accounts(id,user_id,name,kind,currency,opening) values
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','11111111-1111-4111-8111-111111111111','Test savings','Savings','IRT',0),
('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','22222222-2222-4222-8222-222222222222','Other savings','Savings','IRT',0);
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select public.save_savings_goal(jsonb_build_object('id','cccccccc-cccc-4ccc-8ccc-cccccccccccc','name','Test goal','target',100,'currency','IRT','deadline',current_date+60,'account_id','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'));
do $$ begin
 if (select count(*) from public.savings_goals)<>1 then raise exception 'Owner read failed'; end if;
 begin
  perform public.save_savings_goal(jsonb_build_object('id','dddddddd-dddd-4ddd-8ddd-dddddddddddd','name','Duplicate','target',100,'currency','IRT','deadline',current_date+60,'account_id','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'));
  raise exception 'Duplicate accepted';
 exception when unique_violation then null; end;
 begin
  perform public.save_savings_goal(jsonb_build_object('id','dddddddd-dddd-4ddd-8ddd-dddddddddddd','name','Cross owner','target',100,'currency','IRT','deadline',current_date+60,'account_id','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'));
  raise exception 'Cross-owner account accepted';
 exception when raise_exception then if sqlerrm='Cross-owner account accepted' then raise; end if; end;
 begin
  delete from public.accounts where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  raise exception 'Linked account deleted';
 exception when foreign_key_violation then null; end;
 update public.savings_goals set name='Updated' where id='cccccccc-cccc-4ccc-8ccc-cccccccccccc';
 if (select name from public.savings_goals) <> 'Updated' then raise exception 'Owner edit failed'; end if;
 begin
  update public.savings_goals set user_id='22222222-2222-4222-8222-222222222222';
  raise exception 'Owner reassignment accepted';
 exception when others then if sqlerrm='Owner reassignment accepted' then raise; end if; end;
end; $$;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
do $$ begin
 if exists(select 1 from public.savings_goals) then raise exception 'Cross-owner read leaked'; end if;
 update public.savings_goals set name='Stolen' where id='cccccccc-cccc-4ccc-8ccc-cccccccccccc';
 if found then raise exception 'Cross-owner edit accepted'; end if;
 delete from public.savings_goals where id='cccccccc-cccc-4ccc-8ccc-cccccccccccc';
 if found then raise exception 'Cross-owner delete accepted'; end if;
end; $$;
reset role;
-- Account kind/currency are not client-editable; exercise guard with owner role.
do $$ begin
 begin
 update public.accounts set kind='Bank' where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
 raise exception 'Linked kind changed';
 exception when raise_exception then if sqlerrm='Linked kind changed' then raise; end if; end;
 begin
 update public.accounts set currency='USD' where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
 raise exception 'Linked currency changed';
 exception when raise_exception then if sqlerrm='Linked currency changed' then raise; end if; end;
end; $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
delete from public.savings_goals where id='cccccccc-cccc-4ccc-8ccc-cccccccccccc';
do $$ begin if exists(select 1 from public.savings_goals) then raise exception 'Owner delete failed'; end if; end; $$;
set local role anon;
do $$ begin
 begin perform 1 from public.savings_goals; raise exception 'Anonymous read permitted'; exception when insufficient_privilege then null; end;
end; $$;
rollback;
