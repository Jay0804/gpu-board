-- ============================================================
-- 实验室 GPU 预约看板 · Supabase 建表脚本
-- 在 Supabase Dashboard > SQL Editor 里整段粘贴运行
-- ============================================================

-- ---------- 1. servers 表 ----------
create table if not exists public.servers (
    id          bigint generated always as identity primary key,
    name        text not null,                 -- 显示名，如 "server-A"
    ssh_alias   text,                          -- 可选：SSH 别名，方便备注
    created_at  timestamptz not null default now()
);

-- ---------- 2. gpus 表 ----------
create table if not exists public.gpus (
    id          bigint generated always as identity primary key,
    server_id   bigint not null references public.servers(id) on delete cascade,
    slot_index  int  not null,                 -- GPU 编号 0,1,2...
    label       text not null,                 -- 显示标签，如 "server-A/GPU-0"
    created_at  timestamptz not null default now(),
    unique (server_id, slot_index)
);

-- ---------- 3. profiles 表 ----------
create table if not exists public.profiles (
    user_id      uuid primary key references auth.users(id) on delete cascade,
    display_name text not null,
    created_at   timestamptz not null default now()
);

-- ---------- 4. reservations 表 ----------
create table if not exists public.reservations (
    id          bigint generated always as identity primary key,
    gpu_id      bigint not null references public.gpus(id) on delete cascade,
    user_id     uuid    not null references auth.users(id) on delete cascade,
    start_time  timestamptz not null,
    end_time    timestamptz not null,
    note        text,
    created_at  timestamptz not null default now(),
    constraint reservations_time_chk check (end_time > start_time)
);

create index if not exists idx_reservations_gpu on public.reservations(gpu_id);
create index if not exists idx_reservations_time on public.reservations(start_time, end_time);

-- ============================================================
-- RLS 策略
-- ============================================================

-- 开启 RLS
alter table public.servers      enable row level security;
alter table public.gpus          enable row level security;
alter table public.profiles     enable row level security;
alter table public.reservations enable row level security;

-- ---------- servers / gpus：所有人可读，仅 service_role 可写（你用控制台 SQL 跑 INSERT）
drop policy if exists "servers_read_all" on public.servers;
create policy "servers_read_all" on public.servers
    for select using (true);

drop policy if exists "gpus_read_all" on public.gpus;
create policy "gpus_read_all" on public.gpus
    for select using (true);

-- ---------- profiles：所有人可读（看板要显示名字），只能插/改自己的
drop policy if exists "profiles_read_all" on public.profiles;
create policy "profiles_read_all" on public.profiles
    for select using (true);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles
    for insert with check (auth.uid() = user_id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
    for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---------- reservations：所有人可读（公开只读），登录后只能动自己的
drop policy if exists "reservations_read_all" on public.reservations;
create policy "reservations_read_all" on public.reservations
    for select using (true);

drop policy if exists "reservations_insert_own" on public.reservations;
create policy "reservations_insert_own" on public.reservations
    for insert with check (auth.uid() = user_id);

drop policy if exists "reservations_update_own" on public.reservations;
create policy "reservations_update_own" on public.reservations
    for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "reservations_delete_own" on public.reservations;
create policy "reservations_delete_own" on public.reservations
    for delete using (auth.uid() = user_id);

-- ============================================================
-- Realtime：把 reservations 表加入 Supabase Realtime publication
-- 这样前端能订阅 insert/update/delete 事件实时刷新
-- ============================================================
do $$
begin
  -- 检查 publication 是否存在，不存在则创建
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
end $$;

alter publication supabase_realtime add table public.reservations;
alter publication supabase_realtime add table public.gpus;
alter publication supabase_realtime add table public.servers;

-- ============================================================
-- Seed：示例数据（按需修改 / 删除）
-- ============================================================
insert into public.servers (name, ssh_alias) values
    ('server-A', 'gpu-box-a'),
    ('server-B', 'gpu-box-b')
on conflict do nothing;

insert into public.gpus (server_id, slot_index, label)
select s.id, g.slot,
       s.name || '/GPU-' || g.slot
from public.servers s
cross join (values (0),(1),(2),(3)) as g(slot)
where not exists (select 1 from public.gpus where server_id = s.id and slot_index = g.slot);
