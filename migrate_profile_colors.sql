-- 为现有资料表启用跨设备同步的预约颜色。
-- 在 Supabase Dashboard > SQL Editor 中运行一次。
alter table public.profiles add column if not exists color text;

alter publication supabase_realtime add table public.profiles;
