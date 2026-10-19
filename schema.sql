-- BlewChat reference schema aligned with the live project's column names.
-- Existing project tables already exist; review policies before running on that project.
create extension if not exists pgcrypto;
create table if not exists public.profiles(
 id uuid primary key references auth.users(id) on delete cascade,
 username text not null unique check(char_length(username) between 3 and 24),
 display_name text not null default 'New member' check(char_length(display_name) between 1 and 60),
 bio text not null default '' check(char_length(bio)<=240),
 avatar_url text, created_at timestamptz not null default now()
);
create table if not exists public.posts(
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.profiles(id) on delete cascade,
 body text not null check(char_length(body) between 1 and 2000),
 created_at timestamptz not null default now()
);
create table if not exists public.blocks(
 blocker_id uuid not null references public.profiles(id) on delete cascade,
 blocked_id uuid not null references public.profiles(id) on delete cascade,
 created_at timestamptz not null default now(), primary key(blocker_id,blocked_id),
 check(blocker_id<>blocked_id)
);
create table if not exists public.messages(
 id uuid primary key default gen_random_uuid(),
 sender_id uuid not null references public.profiles(id) on delete cascade,
 recipient_id uuid not null references public.profiles(id) on delete cascade,
 body text not null check(char_length(body) between 1 and 4000),
 created_at timestamptz not null default now(), check(sender_id<>recipient_id)
);
alter table public.profiles enable row level security;
alter table public.posts enable row level security;
alter table public.blocks enable row level security;
alter table public.messages enable row level security;
-- Add least-privilege policies after checking for similarly named policies already present.
drop policy if exists "profiles_read_authenticated" on public.profiles;
create policy "profiles_read_authenticated" on public.profiles for select to authenticated using(true);
drop policy if exists "profiles_insert_self" on public.profiles;
create policy "profiles_insert_self" on public.profiles for insert to authenticated with check((select auth.uid())=id);
drop policy if exists "profiles_update_self" on public.profiles;
create policy "profiles_update_self" on public.profiles for update to authenticated using((select auth.uid())=id) with check((select auth.uid())=id);
drop policy if exists "posts_read_unblocked" on public.posts;
create policy "posts_read_unblocked" on public.posts for select to authenticated using(not exists(select 1 from public.blocks b where (b.blocker_id=(select auth.uid()) and b.blocked_id=posts.user_id) or (b.blocker_id=posts.user_id and b.blocked_id=(select auth.uid()))));
drop policy if exists "posts_insert_self" on public.posts;
create policy "posts_insert_self" on public.posts for insert to authenticated with check((select auth.uid())=user_id);
drop policy if exists "posts_delete_self" on public.posts;
create policy "posts_delete_self" on public.posts for delete to authenticated using((select auth.uid())=user_id);
drop policy if exists "blocks_read_self" on public.blocks;
create policy "blocks_read_self" on public.blocks for select to authenticated using((select auth.uid())=blocker_id);
drop policy if exists "blocks_insert_self" on public.blocks;
create policy "blocks_insert_self" on public.blocks for insert to authenticated with check((select auth.uid())=blocker_id);
drop policy if exists "blocks_delete_self" on public.blocks;
create policy "blocks_delete_self" on public.blocks for delete to authenticated using((select auth.uid())=blocker_id);
drop policy if exists "messages_read_participants_unblocked" on public.messages;
create policy "messages_read_participants_unblocked" on public.messages for select to authenticated using(((select auth.uid())=sender_id or (select auth.uid())=recipient_id) and not exists(select 1 from public.blocks b where (b.blocker_id=messages.sender_id and b.blocked_id=messages.recipient_id) or (b.blocker_id=messages.recipient_id and b.blocked_id=messages.sender_id)));
drop policy if exists "messages_insert_sender_unblocked" on public.messages;
create policy "messages_insert_sender_unblocked" on public.messages for insert to authenticated with check((select auth.uid())=sender_id and sender_id<>recipient_id and not exists(select 1 from public.blocks b where (b.blocker_id=sender_id and b.blocked_id=recipient_id) or (b.blocker_id=recipient_id and b.blocked_id=sender_id)));
