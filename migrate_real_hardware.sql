-- 一次性迁移：删除所有旧 GPU 与预约，再按真实硬件重建。
-- 在 Supabase Dashboard > SQL Editor 中执行。

delete from public.gpus;
delete from public.servers;

insert into public.servers (name, ssh_alias) values
  ('Server A · 4090D', 'server-a'),
  ('Server B · 4090 ×2', 'server-b'),
  ('Server C · H100 ×4', 'server-c'),
  ('Server D · A100 ×2', 'server-d');

insert into public.gpus (server_id, slot_index, label)
select s.id, v.slot, s.name || ' / GPU-' || v.slot
from public.servers s
cross join lateral (select generate_series(0, case s.name when 'Server A · 4090D' then 0 when 'Server B · 4090 ×2' then 1 when 'Server C · H100 ×4' then 3 when 'Server D · A100 ×2' then 1 end) as slot) v
order by s.id, v.slot;
