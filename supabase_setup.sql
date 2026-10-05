-- Konj Planner: میز کار آنلاین
-- در Supabase > SQL Editor کل این فایل را یک‌بار اجرا کن.
-- مهم: Authentication > Providers > Email > «Confirm email» را خاموش کن.

create extension if not exists pgcrypto;

create table if not exists workspaces (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  code text not null unique default upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6)),
  owner uuid not null default auth.uid(),
  created_at timestamptz not null default now()
);

create table if not exists members (
  workspace_id uuid not null references workspaces(id) on delete cascade,
  user_id uuid not null default auth.uid(),
  name text not null,
  role text not null default 'member',
  primary key (workspace_id, user_id)
);

create table if not exists projects (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  title text not null,
  created_at timestamptz not null default now()
);

create table if not exists tasks (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  workspace_id uuid not null references workspaces(id) on delete cascade,
  title text not null,
  descr text not null default '',
  assignee uuid,
  status text not null default 'todo' check (status in ('todo','doing','done')),
  due date,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists reports (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references tasks(id) on delete cascade,
  workspace_id uuid not null references workspaces(id) on delete cascade,
  user_id uuid not null default auth.uid(),
  name text not null default '',
  kind text not null default 'report',
  text text not null default '',
  created_at timestamptz not null default now()
);

create or replace function is_member(w uuid) returns boolean
language sql security definer stable set search_path = public as $$
  select exists (select 1 from members where workspace_id = w and user_id = auth.uid());
$$;

create or replace function is_manager(w uuid) returns boolean
language sql security definer stable set search_path = public as $$
  select exists (select 1 from members where workspace_id = w and user_id = auth.uid() and role in ('manager', 'supervisor'));
$$;

create or replace function is_boss(w uuid) returns boolean
language sql security definer stable set search_path = public as $$
  select exists (select 1 from members where workspace_id = w and user_id = auth.uid() and role = 'manager');
$$;

alter table workspaces enable row level security;
alter table members enable row level security;
alter table projects enable row level security;
alter table tasks enable row level security;
alter table reports enable row level security;

drop policy if exists ws_sel on workspaces;
drop policy if exists ws_upd on workspaces;
drop policy if exists ws_del on workspaces;
create policy ws_sel on workspaces for select using (is_member(id));
create policy ws_upd on workspaces for update using (owner = auth.uid());
create policy ws_del on workspaces for delete using (owner = auth.uid());

drop policy if exists mem_sel on members;
drop policy if exists mem_upd on members;
drop policy if exists mem_del on members;
create policy mem_sel on members for select using (is_member(workspace_id));
create policy mem_upd on members for update using (is_boss(workspace_id));
create policy mem_del on members for delete using (is_boss(workspace_id) or user_id = auth.uid());

drop policy if exists prj_sel on projects;
drop policy if exists prj_ins on projects;
drop policy if exists prj_upd on projects;
drop policy if exists prj_del on projects;
create policy prj_sel on projects for select using (is_member(workspace_id));
create policy prj_ins on projects for insert with check (is_manager(workspace_id));
create policy prj_upd on projects for update using (is_manager(workspace_id));
create policy prj_del on projects for delete using (is_manager(workspace_id));

drop policy if exists tsk_sel on tasks;
drop policy if exists tsk_ins on tasks;
drop policy if exists tsk_upd on tasks;
drop policy if exists tsk_del on tasks;
create policy tsk_sel on tasks for select using (is_member(workspace_id));
create policy tsk_ins on tasks for insert with check (is_manager(workspace_id));
create policy tsk_upd on tasks for update using (is_manager(workspace_id) or assignee = auth.uid()) with check (is_member(workspace_id));
create policy tsk_del on tasks for delete using (is_manager(workspace_id));

drop policy if exists rep_sel on reports;
drop policy if exists rep_ins on reports;
create policy rep_sel on reports for select using (is_member(workspace_id));
create policy rep_ins on reports for insert with check (is_member(workspace_id) and user_id = auth.uid());

create or replace function create_workspace(p_name text, p_user text) returns workspaces
language plpgsql security definer set search_path = public as $$
declare w workspaces;
begin
  insert into workspaces(name, owner) values (p_name, auth.uid()) returning * into w;
  insert into members(workspace_id, user_id, name, role) values (w.id, auth.uid(), p_user, 'manager');
  return w;
end; $$;

create or replace function join_workspace(p_code text, p_user text) returns workspaces
language plpgsql security definer set search_path = public as $$
declare w workspaces;
begin
  select * into w from workspaces where code = upper(trim(p_code));
  if not found then raise exception 'کد دعوت پیدا نشد'; end if;
  insert into members(workspace_id, user_id, name, role) values (w.id, auth.uid(), p_user, 'member') on conflict do nothing;
  return w;
end; $$;

revoke all on function create_workspace(text, text) from public, anon;
revoke all on function join_workspace(text, text) from public, anon;
grant execute on function create_workspace(text, text) to authenticated;
grant execute on function join_workspace(text, text) to authenticated;


-- پشتیبان‌گیری آنلاین از اطلاعات برنامه (هر کاربر فقط پشتیبان خودش را می‌بیند)
create table if not exists backups (
  user_id uuid primary key default auth.uid(),
  data text not null,
  updated_at timestamptz not null default now()
);
alter table backups enable row level security;
drop policy if exists bk_all on backups;
create policy bk_all on backups for all using (user_id = auth.uid()) with check (user_id = auth.uid());
