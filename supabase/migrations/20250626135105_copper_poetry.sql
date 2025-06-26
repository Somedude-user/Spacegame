/*
  # Space Game Database Schema

  1. New Tables
    - `space_game_players`
      - `id` (uuid, primary key)
      - `user_id` (uuid, foreign key to auth.users)
      - `nickname` (text, player display name)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)
    
    - `space_game_scores`
      - `id` (uuid, primary key)
      - `player_id` (uuid, foreign key to space_game_players)
      - `score` (integer)
      - `game_duration` (integer, seconds)
      - `enemies_killed` (integer)
      - `asteroids_destroyed` (integer)
      - `nukes_used` (integer)
      - `created_at` (timestamp)
    
    - `space_game_stats`
      - `id` (uuid, primary key)
      - `player_id` (uuid, foreign key to space_game_players)
      - `total_games` (integer)
      - `best_score` (integer)
      - `total_score` (integer)
      - `total_enemies_killed` (integer)
      - `total_asteroids_destroyed` (integer)
      - `total_nukes_used` (integer)
      - `total_playtime` (integer, seconds)
      - `updated_at` (timestamp)

  2. Security
    - Enable RLS on all tables
    - Add policies for authenticated users to manage their own data
    - Add policies for public read access to leaderboards
*/

-- Create space_game_players table
CREATE TABLE IF NOT EXISTS space_game_players (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  nickname text NOT NULL CHECK (length(trim(nickname)) > 0 AND length(trim(nickname)) <= 20),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(user_id)
);

-- Create space_game_scores table
CREATE TABLE IF NOT EXISTS space_game_scores (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id uuid REFERENCES space_game_players(id) ON DELETE CASCADE NOT NULL,
  score integer NOT NULL DEFAULT 0 CHECK (score >= 0),
  game_duration integer NOT NULL DEFAULT 0 CHECK (game_duration >= 0),
  enemies_killed integer NOT NULL DEFAULT 0 CHECK (enemies_killed >= 0),
  asteroids_destroyed integer NOT NULL DEFAULT 0 CHECK (asteroids_destroyed >= 0),
  nukes_used integer NOT NULL DEFAULT 0 CHECK (nukes_used >= 0),
  created_at timestamptz DEFAULT now()
);

-- Create space_game_stats table
CREATE TABLE IF NOT EXISTS space_game_stats (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id uuid REFERENCES space_game_players(id) ON DELETE CASCADE NOT NULL,
  total_games integer NOT NULL DEFAULT 0 CHECK (total_games >= 0),
  best_score integer NOT NULL DEFAULT 0 CHECK (best_score >= 0),
  total_score bigint NOT NULL DEFAULT 0 CHECK (total_score >= 0),
  total_enemies_killed integer NOT NULL DEFAULT 0 CHECK (total_enemies_killed >= 0),
  total_asteroids_destroyed integer NOT NULL DEFAULT 0 CHECK (total_asteroids_destroyed >= 0),
  total_nukes_used integer NOT NULL DEFAULT 0 CHECK (total_nukes_used >= 0),
  total_playtime integer NOT NULL DEFAULT 0 CHECK (total_playtime >= 0),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(player_id)
);

-- Enable Row Level Security
ALTER TABLE space_game_players ENABLE ROW LEVEL SECURITY;
ALTER TABLE space_game_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE space_game_stats ENABLE ROW LEVEL SECURITY;

-- Policies for space_game_players
CREATE POLICY "Users can read all players for leaderboard"
  ON space_game_players
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can insert their own player profile"
  ON space_game_players
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own player profile"
  ON space_game_players
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Policies for space_game_scores
CREATE POLICY "Users can read all scores for leaderboard"
  ON space_game_scores
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can insert their own scores"
  ON space_game_scores
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM space_game_players 
      WHERE id = player_id AND user_id = auth.uid()
    )
  );

-- Policies for space_game_stats
CREATE POLICY "Users can read all stats for leaderboard"
  ON space_game_stats
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can insert their own stats"
  ON space_game_stats
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM space_game_players 
      WHERE id = player_id AND user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update their own stats"
  ON space_game_stats
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM space_game_players 
      WHERE id = player_id AND user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM space_game_players 
      WHERE id = player_id AND user_id = auth.uid()
    )
  );

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS space_game_scores_player_id_idx ON space_game_scores(player_id);
CREATE INDEX IF NOT EXISTS space_game_scores_score_idx ON space_game_scores(score DESC);
CREATE INDEX IF NOT EXISTS space_game_scores_created_at_idx ON space_game_scores(created_at DESC);
CREATE INDEX IF NOT EXISTS space_game_stats_best_score_idx ON space_game_stats(best_score DESC);
CREATE INDEX IF NOT EXISTS space_game_stats_total_score_idx ON space_game_stats(total_score DESC);

-- Create trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_space_game_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_space_game_players_updated_at
    BEFORE UPDATE ON space_game_players
    FOR EACH ROW
    EXECUTE FUNCTION update_space_game_updated_at_column();

CREATE TRIGGER update_space_game_stats_updated_at
    BEFORE UPDATE ON space_game_stats
    FOR EACH ROW
    EXECUTE FUNCTION update_space_game_updated_at_column();