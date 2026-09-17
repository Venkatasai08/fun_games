-- ============================================================
-- TAMBOLA GAME - SUPABASE SCHEMA
-- Run this in your Supabase SQL editor
-- ============================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ──────────────────────────────────────────────────────────
-- PROFILES TABLE
-- ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  username TEXT UNIQUE NOT NULL,
  email TEXT,
  avatar_color TEXT DEFAULT '#6C63FF',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public profiles are viewable by everyone"
  ON profiles FOR SELECT USING (true);

CREATE POLICY "Users can insert their own profile"
  ON profiles FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
  ON profiles FOR UPDATE USING (auth.uid() = id);

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, username, email)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1)),
    NEW.email
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ──────────────────────────────────────────────────────────
-- ROOMS TABLE
-- ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS rooms (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name TEXT NOT NULL,
  host_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  host_username TEXT NOT NULL,
  password TEXT,                        -- NULL = no password
  max_number INT DEFAULT 90 CHECK (max_number >= 10 AND max_number <= 990),
  status TEXT DEFAULT 'waiting'         -- waiting | playing | finished
    CHECK (status IN ('waiting', 'playing', 'finished')),
  called_numbers INT[] DEFAULT '{}',
  last_called INT,
  auto_call BOOLEAN DEFAULT FALSE,
  auto_call_interval INT DEFAULT 5,     -- seconds between auto-calls
  winner_id UUID REFERENCES profiles(id),
  winner_username TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE rooms ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Rooms are viewable by everyone"
  ON rooms FOR SELECT USING (true);

CREATE POLICY "Authenticated users can create rooms"
  ON rooms FOR INSERT WITH CHECK (auth.uid() = host_id);

CREATE POLICY "Hosts can update their rooms"
  ON rooms FOR UPDATE USING (auth.uid() = host_id);

CREATE POLICY "Hosts can delete their rooms"
  ON rooms FOR DELETE USING (auth.uid() = host_id);

-- ──────────────────────────────────────────────────────────
-- ROOM MEMBERS TABLE
-- ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS room_members (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  room_id UUID REFERENCES rooms(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  username TEXT NOT NULL,
  ticket JSONB NOT NULL,               -- 2D array: [[num|null, ...], ...]
  marked_numbers INT[] DEFAULT '{}',
  has_claimed_housie BOOLEAN DEFAULT FALSE,
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(room_id, user_id)
);

ALTER TABLE room_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Room members are viewable by everyone"
  ON room_members FOR SELECT USING (true);

CREATE POLICY "Authenticated users can join rooms"
  ON room_members FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Members can update their own data"
  ON room_members FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Members can leave rooms"
  ON room_members FOR DELETE USING (auth.uid() = user_id);

-- ──────────────────────────────────────────────────────────
-- REAL-TIME SUBSCRIPTIONS
-- Enable real-time for rooms and room_members tables
-- ──────────────────────────────────────────────────────────
ALTER PUBLICATION supabase_realtime ADD TABLE rooms;
ALTER PUBLICATION supabase_realtime ADD TABLE room_members;

-- ──────────────────────────────────────────────────────────
-- HELPER FUNCTION: Update room timestamp
-- ──────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION update_room_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER rooms_updated_at
  BEFORE UPDATE ON rooms
  FOR EACH ROW EXECUTE FUNCTION update_room_timestamp();
