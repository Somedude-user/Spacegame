import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error('Missing Supabase environment variables');
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

// Game database functions
export class SpaceGameDB {
  
  // Get or create player profile
  static async getOrCreatePlayer(nickname) {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        throw new Error('User not authenticated');
      }

      // Try to get existing player
      let { data: player, error } = await supabase
        .from('space_game_players')
        .select('*')
        .eq('user_id', user.id)
        .single();

      if (error && error.code !== 'PGRST116') { // PGRST116 = no rows returned
        throw error;
      }

      // Create player if doesn't exist
      if (!player) {
        const { data: newPlayer, error: createError } = await supabase
          .from('space_game_players')
          .insert({
            user_id: user.id,
            nickname: nickname.trim()
          })
          .select()
          .single();

        if (createError) throw createError;
        player = newPlayer;

        // Create initial stats
        await supabase
          .from('space_game_stats')
          .insert({
            player_id: player.id
          });
      } else if (player.nickname !== nickname.trim()) {
        // Update nickname if changed
        const { data: updatedPlayer, error: updateError } = await supabase
          .from('space_game_players')
          .update({ nickname: nickname.trim() })
          .eq('id', player.id)
          .select()
          .single();

        if (updateError) throw updateError;
        player = updatedPlayer;
      }

      return player;
    } catch (error) {
      console.error('Error getting/creating player:', error);
      throw error;
    }
  }

  // Save game score and update stats
  static async saveScore(playerId, gameData) {
    try {
      const { score, duration, enemiesKilled, asteroidsDestroyed, nukesUsed } = gameData;

      // Insert score record
      const { error: scoreError } = await supabase
        .from('space_game_scores')
        .insert({
          player_id: playerId,
          score,
          game_duration: duration,
          enemies_killed: enemiesKilled,
          asteroids_destroyed: asteroidsDestroyed,
          nukes_used: nukesUsed
        });

      if (scoreError) throw scoreError;

      // Update player stats
      const { data: currentStats, error: statsError } = await supabase
        .from('space_game_stats')
        .select('*')
        .eq('player_id', playerId)
        .single();

      if (statsError) throw statsError;

      const updatedStats = {
        total_games: currentStats.total_games + 1,
        best_score: Math.max(currentStats.best_score, score),
        total_score: currentStats.total_score + score,
        total_enemies_killed: currentStats.total_enemies_killed + enemiesKilled,
        total_asteroids_destroyed: currentStats.total_asteroids_destroyed + asteroidsDestroyed,
        total_nukes_used: currentStats.total_nukes_used + nukesUsed,
        total_playtime: currentStats.total_playtime + duration
      };

      const { error: updateError } = await supabase
        .from('space_game_stats')
        .update(updatedStats)
        .eq('player_id', playerId);

      if (updateError) throw updateError;

      return true;
    } catch (error) {
      console.error('Error saving score:', error);
      throw error;
    }
  }

  // Get global leaderboard (top scores)
  static async getGlobalLeaderboard(limit = 10) {
    try {
      const { data, error } = await supabase
        .from('space_game_scores')
        .select(`
          score,
          game_duration,
          enemies_killed,
          asteroids_destroyed,
          created_at,
          space_game_players!inner(nickname)
        `)
        .order('score', { ascending: false })
        .limit(limit);

      if (error) throw error;

      return data.map(record => ({
        nickname: record.space_game_players.nickname,
        score: record.score,
        duration: record.game_duration,
        enemiesKilled: record.enemies_killed,
        asteroidsDestroyed: record.asteroids_destroyed,
        date: new Date(record.created_at).toLocaleDateString('fi-FI')
      }));
    } catch (error) {
      console.error('Error getting leaderboard:', error);
      throw error;
    }
  }

  // Get player stats
  static async getPlayerStats(playerId) {
    try {
      const { data, error } = await supabase
        .from('space_game_stats')
        .select(`
          *,
          space_game_players!inner(nickname)
        `)
        .eq('player_id', playerId)
        .single();

      if (error) throw error;

      return {
        nickname: data.space_game_players.nickname,
        totalGames: data.total_games,
        bestScore: data.best_score,
        totalScore: data.total_score,
        totalEnemiesKilled: data.total_enemies_killed,
        totalAsteroidsDestroyed: data.total_asteroids_destroyed,
        totalNukesUsed: data.total_nukes_used,
        totalPlaytime: data.total_playtime,
        averageScore: data.total_games > 0 ? Math.round(data.total_score / data.total_games) : 0
      };
    } catch (error) {
      console.error('Error getting player stats:', error);
      throw error;
    }
  }

  // Get recent scores for a player
  static async getPlayerRecentScores(playerId, limit = 5) {
    try {
      const { data, error } = await supabase
        .from('space_game_scores')
        .select('*')
        .eq('player_id', playerId)
        .order('created_at', { ascending: false })
        .limit(limit);

      if (error) throw error;

      return data.map(score => ({
        score: score.score,
        duration: score.game_duration,
        enemiesKilled: score.enemies_killed,
        asteroidsDestroyed: score.asteroids_destroyed,
        nukesUsed: score.nukes_used,
        date: new Date(score.created_at).toLocaleDateString('fi-FI')
      }));
    } catch (error) {
      console.error('Error getting recent scores:', error);
      throw error;
    }
  }

  // Authentication helpers
  static async signInAnonymously() {
    try {
      const { data, error } = await supabase.auth.signInAnonymously();
      if (error) throw error;
      return data;
    } catch (error) {
      console.error('Error signing in anonymously:', error);
      throw error;
    }
  }

  static async getCurrentUser() {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      return user;
    } catch (error) {
      console.error('Error getting current user:', error);
      return null;
    }
  }
}