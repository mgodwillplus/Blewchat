# BLEWCHAT v1

*"also another eccentric build from the King"*

A mobile-first static web app (plain HTML/JS, no build step) on its own Supabase project, **BlewChat**. No other Supabase project is touched by this app.

## Setup (the database is already built in the BlewChat project)
1. Put the supplied `config.js` next to `index.html` (it holds the BlewChat project URL and the **public anon key** only; safe to commit). If you ever rebuild, copy `config.example.js` and fill it in. Never use the `service_role` key.
2. In Supabase (BlewChat project) → **Authentication → URL Configuration**: set **Site URL** to your deployed address (e.g. `https://YOURNAME.github.io/blewchat/`) and add it under **Redirect URLs**. Verification and password-reset links need this.
3. **Authentication → Providers → Email**: keep **Confirm email** switched on for real use.
4. Preview locally with `npx serve .` (or `python3 -m http.server`); deploy with GitHub Pages (**Settings → Pages → Deploy from branch → main / root**).

`supabase/schema.sql` rebuilds the full schema in a fresh, empty BlewChat project only. Do not run it in the live project or any other project.

## Fonts
Interface: `--font` at the top of the `<style>` block in `index.html`. Wordmark: the `<style>` block in `assets/wordmark.svg` (system fonts only when loaded as an image).

## In v1
Intro screen (first visit; tap the header wordmark to replay) · email/password sign-up, verification, sign-in, sign-out, password reset · feed: text posts, YouTube thumbnail with click-to-play and fallback link, likes, delete own post, "Load more" paging · one-to-one realtime messages · block/unblock · row-level security on every table.

## Not yet in v1
Photo uploads and storage policies · comments · profile and avatar editing · post editing in the interface (database rule exists) · link titles/descriptions · member search beyond exact username · notifications.

## Test report
**Tested against the live BlewChat database** (three throwaway accounts, rolled back, nothing left behind):
- Sign-up creates profiles; username format and length rules; taken/free username check.
- Posts: only you can publish, edit, delete your own; forged authors rejected; `javascript:` links rejected.
- Likes: no forging, no duplicates. Profiles: only you can edit yours.
- Messages: no forged senders; a third account reads, edits and deletes nothing; anonymous direct API calls get nothing.
- Blocking: blocked and blocker both stopped from sending; thread hidden while blocked; works again after unblock; block helper not callable from the public API.
- Found and fixed during testing: a blocked user could previously still write messages to the person who blocked them.
- Security advisor: one intentional warning remains (`username_available` is public on purpose and returns only true/false).

**Not tested yet** (needs a browser and real email): the screens themselves, real verification and reset emails, realtime delivery in two live browsers, YouTube embedding, narrow-Android layout. Please run these after deploying and report anything that fails.
