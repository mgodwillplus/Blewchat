# BlewChat

A mobile-first static social app for GitHub Pages, connected to the separate BlewChat Supabase project.

## Features in this first version
- Email/password sign-up and sign-in
- Profile username, display name, bio and avatar URL
- Community posts and feed
- Member search
- One-to-one direct messages with realtime refresh
- Block and unblock members
- Supabase row-level security reference SQL in `schema.sql`

## Upload from your phone
1. Extract `BlewChat.zip`.
2. Open https://github.com/mgodwillplus/Blewchat
3. In the Blewchat repository only, choose **Add file → Upload files**.
4. Upload `index.html`, `README.md`, and `schema.sql` into the repository root and commit. Do not upload these files to MGodwill+.
5. Go to **Settings → Pages**. Select **Deploy from a branch**, choose your default branch and `/(root)`, then save.
6. Wait for GitHub Pages to provide the site URL.

## Supabase
The app is preconfigured for the BlewChat project:
- URL: `https://oyopdidnsaqimshgylmx.supabase.co`
- The browser key embedded in `index.html` is a publishable key. Never put a secret/service-role key in client code. RLS must protect the tables.

The core tables and policies were already applied to this project earlier. `schema.sql` is a reference/setup script for a fresh project; do not run it blindly on an existing project. Review the existing tables/policies first.

Check Supabase **Authentication → Providers → Email** is enabled. In **Authentication → URL Configuration**, add the eventual GitHub Pages URL to allowed redirect URLs. If email confirmation is enabled, users need to confirm their email before signing in.

## Custom domain
Once GitHub Pages works, set `blew.chat` in the Blewchat repository's **Settings → Pages**, then configure the DNS records at the domain registrar according to GitHub's current instructions and enable HTTPS after verification.

## Limitations
This first version does not include media uploads, likes, comments, group chats, notifications, or an admin/moderation console. Test registration, posting, profile editing, messaging and blocking with two test accounts before inviting others.


## Schema compatibility note
The frontend uses `posts.body` and `messages.body`, matching the existing BlewChat project. The reference SQL also uses these column names. The existing live tables were inspected; they have RLS enabled. The reference SQL is not a request to recreate or reset the existing database.
