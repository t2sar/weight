# Burn Rate Dashboard

Single-page weight tracking dashboard with optional cloud sync.

## Local run

No build step is required.

1. Copy config template:
   ```bash
   cp app-config.example.js app-config.js
   ```
2. Edit `app-config.js` and set:
   - `supabaseUrl`
   - `supabaseAnonKey`
3. Serve the project directory (example):
   ```bash
   cd /tmp/workspace/t2sar/weight
   python3 -m http.server 8080
   ```
4. Open:
   - `http://localhost:8080/burn%20app.html`

If `app-config.js` is left empty, the app still works in local-only mode (browser storage, no auth, no sync).

## Backend setup (Supabase)

Use Supabase for managed authentication and cloud storage.

1. Create a Supabase project.
2. In Supabase SQL Editor, run:
   - `supabase/schema.sql`
3. In Supabase Auth settings:
   - enable Email auth
   - configure email confirmation policy (optional but recommended)

### What the SQL setup creates

- `profiles` table (per-user profile metadata)
- `user_settings` table (goal + start weight)
- `weight_entries` table (daily entries)
- Row Level Security policies so users can only read/write their own rows
- Trigger to auto-create a profile row on new sign-up

## Authentication + sync flows

- **Sign Up**: username + email + password (8-72 chars)
- **Login**: email + password
- **Logout**: ends Supabase session
- **Sync status**: shown in the "Account & Sync" panel

When signed in, changes sync to Supabase and can be loaded on another device after login with the same account.

## Security notes

- Passwords are handled by Supabase Auth (hashed + salted by backend)
- App never stores plaintext passwords
- Data access is protected by Supabase Row Level Security policies tied to authenticated user id

## Validation

- Client-side validation for email/password/username and weight ranges
- Server-side validation via SQL constraints and RLS policies in `supabase/schema.sql`

## Tests

This repository currently has no automated test suite.

Smoke-check manually:
1. Sign up and log in.
2. Add/update/delete entries and confirm sync status updates.
3. Log out and verify local-only mode messaging.
4. Log in from another browser/device and verify synced data appears.
