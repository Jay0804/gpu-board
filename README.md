# 实验室 GPU 预约看板 · 部署指南

## 整体架构

纯前端单页 HTML + Supabase（数据库 / 魔法链接登录 / 实时同步），无后端服务。
静态文件托管在 GitHub Pages（或任何静态托管），成员访问一个固定链接即可。

## 第一步：创建 Supabase 项目

1. 打开 https://supabase.com 注册并登录
2. 点击 New Project，填名字（如 `gpu-board`），选区域（选离你近的，如 Northeast Asia / Singapore）
3. 设置一个数据库密码（记下来），创建
4. 等待 1~2 分钟项目就绪

## 第二步：运行建表 SQL

1. 进入项目后，左侧菜单点 **SQL Editor** → New query
2. 打开本目录下 `schema.sql`，整段复制粘贴进编辑器
3. 点 Run，应该无报错返回
4. 这会建好 4 张表（servers / gpus / profiles / reservations）、RLS 策略、Realtime 订阅，以及示例的 2 台服务器 × 4 GPU = 8 个 GPU 槽位

> 之后想加服务器/GPU：回到 SQL Editor 跑 INSERT 即可（文件末尾有示例）。

## 第三步：配置 Auth（魔法链接登录）

1. 左侧菜单 **Authentication** → **Providers**
2. 确认 **Email** 已启用（默认就是启用的）
3. （建议）**Authentication** → **URL Configuration**：
   - Site URL：填你将要部署的地址，如 `https://你的用户名.github.io/gpu-board`
   - Redirect URLs：加上同上
4. （可选）**Email Templates** → 模板里中文欢迎语，方便成员

> 按设计是开放注册：任何人用任意邮箱都能登录。若后续想收紧为白名单，
> 在 Authentication > Providers > Email 里开启 "Confirm email" 或用自定义钩子。

## 第四步：拿到 API 密钥

1. 左侧菜单 **Project Settings**（齿轮图标）→ **API**
2. 复制两项：
   - **Project URL**：形如 `https://xxxxx.supabase.co`
   - **anon public key**：一长串 eyJ... 开头的字符串

## 第五步：填入前端代码

1. 用文本编辑器打开 `index.html`
2. 找到这两行（约第 240 行附近）：

```js
const SUPABASE_URL = 'YOUR_SUPABASE_URL';
const SUPABASE_KEY = 'YOUR_SUPABASE_ANON_KEY';
```

3. 把引号里换成你刚才复制的值：

```js
const SUPABASE_URL = 'https://xxxxx.supabase.co';
const SUPABASE_KEY = 'eyJhbGciOi...你的 anon key...';
```

4. 保存

> anon key 是公开的（前端安全模型由 RLS 保护，泄露 anon key 不会让人绕过 RLS）。

## 第六步：部署到 GitHub Pages

1. 注册/登录 https://github.com，点右上 **+** → New repository
2. 仓库名填 `gpu-board`，选 Public，创建
3. 点 **uploading an existing file**，把改好 URL/Key 的 `index.html` 拖进去，提交
4. 仓库 **Settings** → **Pages**
5. **Source** 选 `Deploy from a branch`，Branch 选 `main` / `root`，Save
6. 等 1~2 分钟，上方会出现你的网站地址：`https://你的用户名.github.io/gpu-board`
7. 把这个链接发给实验室成员即可

> 不想用 GitHub？也可以用 [Netlify](https://app.netlify.com/drop) 拖拽部署，
> 或 Supabase 本身的静态托管。只要能公开访问到一个固定 URL 即可。

## 日常使用

- 成员首次打开链接 → 输邮箱 → 收魔法链接邮件 → 点链接登录 → 填名字 → 即可看/预约
- 点 **+ 新建预约** → 选 GPU + 起止时间 + 备注 → 保存（点"检查冲突"看是否和他人重叠）
- 点甘特图上已有色块 → 可编辑/删除自己的预约
- 别人提交的新预约会自动出现在你的甘特图上（Realtime），无需刷新
- 老的、已结束的预约色块会灰化

## 加服务器 / 加 GPU（只有项目 owner 做）

回到 Supabase SQL Editor，跑：

```sql
-- 加一台服务器
insert into public.servers (name, ssh_alias) values ('server-C', 'gpu-box-c');

-- 给 server-C 加 4 个 GPU（假设它的 id 是 3）
insert into public.gpus (server_id, slot_index, label)
values (3, 0, 'server-C/GPU-0'), (3, 1, 'server-C/GPU-1'), (3, 2, 'server-C/GPU-2'), (3, 3, 'server-C/GPU-3');
```

前端会自动读到新 GPU，不用改代码、不用重新部署。

## 技术细节备忘

- **数据模型**：servers / gpus（你手动维护）/ profiles（用户首登填名）/ reservations
- **RLS**：所有表 SELECT 公开（匿名可看预约）；写操作要求登录且只能动自己的；servers/gpus 不开放 UI 写
- **实时同步**：Supabase Realtime 订阅 reservations/gpus/servers 表变更，自动刷新
- **时区**：数据库存 UTC，前端按浏览器本地时间显示（国内成员都是北京时间）
- **甘特图**：手写 CSS 网格，无第三方依赖；可在日 / 周 / 月 / 年视图间切换并翻页
- **登录**：魔法链接，无密码
```
