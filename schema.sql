-- BLEWCHAT v1: complete schema, matching what is applied to the live "BlewChat" Supabase project.
-- FOR A FRESH, EMPTY BLEWCHAT PROJECT ONLY. The live project already has all of this: do not re-run it there,
-- and never run it in any other project.

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text not null unique,
  display_name text not null default 'New member',
  bio text not null default '',
  avatar_url text,
  created_at timestamptz not null default now(),
  constraint profiles_username_length check (char_length(username) between 3 and 24),
  constraint profiles_username_format check (username ~ '^[a-z0-9_]+$'),
  constraint profiles_display_name_length check (char_length(display_name) between 1 and 60),
  constraint profiles_bio_length check (char_length(bio) <= 240)
);

create table public.posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  body text not null check (char_length(body) between 1 and 2000),
  link_url text check (link_url is null or (link_url ~* '^https?://' and char_length(link_url) <= 500)),
  created_at timestamptz not null default now()
);
create index posts_created_at_idx on public.posts (created_at desc);

create table public.likes (
  post_id uuid not null references public.posts (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);
create index likes_user_idx on public.likes (user_id);

create table public.blocks (
  blocker_id uuid not null references public.profiles (id) on delete cascade,
  blocked_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint blocks_not_self check (blocker_id <> blocked_id)
);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.profiles (id) on delete cascade,
  recipient_id uuid not null references public.profiles (id) on delete cascade,
  body text not null check (char_length(body) between 1 and 4000),
  created_at timestamptz not null default now(),
  constraint messages_not_self check (sender_id <> recipient_id)
);
create index messages_conversation_idx on public.messages (sender_id, recipient_id, created_at desc);
create index messages_recipient_idx on public.messages (recipient_id, created_at desc);

-- Private helper: not reachable through the public API. Answers only for the caller's own pairs.
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create function private.blocked_either_way(x uuid, y uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select (select auth.uid()) in (x, y)
     and exists (select 1 from public.blocks
                 where (blocker_id = x and blocked_id = y) or (blocker_id = y and blocked_id = x));
$$;
revoke all on function private.blocked_either_way(uuid, uuid) from public, anon;
grant execute on function private.blocked_either_way(uuid, uuid) to authenticated;

-- Row Level Security on every table
alter table public.profiles enable row level security;
alter table public.posts enable row level security;
alter table public.likes enable row level security;
alter table public.blocks enable row level security;
alter table public.messages enable row level security;

create policy "Profiles are viewable by signed-in members" on public.profiles for select to authenticated using (true);
create policy "Members create their own profile" on public.profiles for insert to authenticated with check ((select auth.uid()) = id);
create policy "Members update their own profile" on public.profiles for update to authenticated
  using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

create policy "Signed-in members can read the community feed" on public.posts for select to authenticated using (true);
create policy "Members publish their own posts" on public.posts for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "Members edit their own posts" on public.posts for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "Members delete their own posts" on public.posts for delete to authenticated using ((select auth.uid()) = user_id);

create policy "Members read likes" on public.likes for select to authenticated using (true);
create policy "Members like as themselves" on public.likes for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "Members remove their own likes" on public.likes for delete to authenticated using ((select auth.uid()) = user_id);

create policy "Members can see blocks they created" on public.blocks for select to authenticated using ((select auth.uid()) = blocker_id);
create policy "Members can block others" on public.blocks for insert to authenticated with check ((select auth.uid()) = blocker_id);
create policy "Members can unblock" on public.blocks for delete to authenticated using ((select auth.uid()) = blocker_id);

create policy "Members send messages as themselves unless blocked" on public.messages for insert to authenticated
  with check (sender_id = (select auth.uid()) and not private.blocked_either_way(sender_id, recipient_id));
create policy "Participants read their messages unless blocked" on public.messages for select to authenticated
  using ((sender_id = (select auth.uid()) or recipient_id = (select auth.uid()))
         and not private.blocked_either_way(sender_id, recipient_id));

-- Profile creation at sign-up (runs with owner rights so RLS does not block the auth service)
create function public.create_profile_for_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
declare chosen_username text;
begin
  chosen_username := lower(regexp_replace(coalesce(new.raw_user_meta_data ->> 'username', split_part(new.email, '@', 1), 'member'), '[^a-zA-Z0-9_]', '', 'g'));
  if char_length(chosen_username) < 3 then
    chosen_username := 'member' || substr(replace(new.id::text, '-', ''), 1, 8);
  end if;
  chosen_username := substr(chosen_username, 1, 24);
  insert into public.profiles (id, username, display_name)
  values (new.id, chosen_username, coalesce(nullif(new.raw_user_meta_data ->> 'display_name', ''), chosen_username))
  on conflict (id) do nothing;
  return new;
end;
$$;
revoke all on function public.create_profile_for_new_user() from public, anon, authenticated;
create trigger on_auth_user_created_profile after insert on auth.users
  for each row execute function public.create_profile_for_new_user();

-- Username availability before sign-up (returns only true/false; intentionally callable by anon)
create function public.username_available(name text) returns boolean
language sql stable security definer set search_path = '' as $$
  select not exists (select 1 from public.profiles where username = lower(name));
$$;
revoke all on function public.username_available(text) from public;
grant execute on function public.username_available(text) to anon, authenticated;

-- Realtime for private messages (RLS still decides who receives each row)
alter publication supabase_realtime add table public.messages;
