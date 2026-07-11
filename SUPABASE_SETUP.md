# Supabase Setup for Jisr

The app now uses Supabase (Postgres + Auth + Realtime + Storage) instead of
Firebase. Follow these steps to set it up.

## 1) Create a Supabase project
1. Go to https://supabase.com → New project
2. Note your **Project URL** and **anon public key** (Settings → API)

## 2) Provide credentials to the app
Pass them at build time:
```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://deep-shopping-2022--jisr-fastapi-app.modal.run \
  --dart-define=GROQ_KEY=gsk_your_key \
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your_anon_key
```
Or add SUPABASE_URL and SUPABASE_ANON_KEY as GitHub Secrets and inject them
in the workflow (like GROQ_KEY).

## 3) Create the database tables
In Supabase → SQL Editor, run this:

```sql
-- Users
create table users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  display_name text,
  photo_url text,
  subscribed boolean default false,
  plan text default 'free',
  used_messages int default 0,
  contribute_to_training boolean default false,
  created_at timestamptz default now()
);

-- Corrections (training data)
create table corrections (
  id bigint generated always as identity primary key,
  user_id uuid references users(id) on delete cascade,
  audio_url text,
  original_text text not null,
  corrected_text text not null,
  language text not null,
  audio_duration real,
  edit_ratio real,
  quality_score real,
  status text default 'pending',
  created_at timestamptz default now()
);

-- Learned phrases
create table learned_phrases (
  id bigint generated always as identity primary key,
  user_id uuid references users(id) on delete cascade,
  source_text text not null,
  target_text text not null,
  source_lang text not null,
  target_lang text not null,
  review_count int default 0,
  mastered boolean default false,
  created_at timestamptz default now()
);

-- Learning summaries
create table learning_summaries (
  id bigint generated always as identity primary key,
  user_id uuid references users(id) on delete cascade,
  source_lang text,
  target_lang text,
  phrases text[],
  created_at timestamptz default now()
);

-- Rooms (voice rooms — signaling)
create table rooms (
  code text primary key,
  host_id uuid,
  host_name text,
  host_lang text,
  guest_id uuid,
  guest_name text,
  guest_lang text,
  active boolean default true,
  created_at timestamptz default now()
);

-- Room messages
create table room_messages (
  id bigint generated always as identity primary key,
  room_code text references rooms(code) on delete cascade,
  sender_id text,
  sender_name text,
  original_text text,
  translated_text text,
  source_lang text,
  target_lang text,
  audio_url text,
  ts bigint
);
```

## 4) Enable Row Level Security (RLS)
Run this so users only touch their own data (and rooms are shared by code):

```sql
-- Users: each user sees/edits their own row
alter table users enable row level security;
create policy "own_user" on users
  for all using (auth.uid() = id) with check (auth.uid() = id);

-- Corrections
alter table corrections enable row level security;
create policy "own_corrections" on corrections
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Learned phrases
alter table learned_phrases enable row level security;
create policy "own_phrases" on learned_phrases
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Learning summaries
alter table learning_summaries enable row level security;
create policy "own_summaries" on learning_summaries
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Rooms: any authenticated user can read/write (they're shared by code)
alter table rooms enable row level security;
create policy "rooms_shared" on rooms
  for all using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

alter table room_messages enable row level security;
create policy "room_msgs_shared" on room_messages
  for all using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');
```

## 5) Enable Realtime
Realtime is needed for rooms and live user sync.
- Supabase → Database → Replication → enable for `rooms`, `room_messages`, `users`.

## 6) Create Storage buckets
Supabase → Storage → create two buckets (public):
- `training` — for training audio (correction consent)
- `rooms` — for cloned room audio

## 7) Enable auth providers
- Supabase → Authentication → Providers
- **Email**: enabled by default (email/password)
- **Google**: enable, add your Google OAuth client ID + secret
  (from Google Cloud Console → Credentials)
- Add redirect URL: `io.jisr.app://login-callback`

## 8) Android deep link (for Google OAuth)
In `android/app/src/main/AndroidManifest.xml`, inside the main `<activity>`:
```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="io.jisr.app" android:host="login-callback" />
</intent-filter>
```

## Notes
- Email/password works immediately after tables + auth are set up.
- Google sign-in needs the OAuth client + deep link (steps 7-8).
- If SUPABASE_URL / SUPABASE_ANON_KEY are empty, the app still opens but
  login and cloud features are disabled (no crash).
