import 'package:shared_preferences/shared_preferences.dart';

class StreakService {
  static const String _lastDateKey = 'streak_last_date';
  static const String _streakKey = 'streak_count';
  static const String _dailyWordsKey = 'daily_words';
  static const int dailyGoal = 500;

  static Future<Map<String, dynamic>> getStreakInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T').first;
    final lastDate = prefs.getString(_lastDateKey);
    
    int streak = prefs.getInt(_streakKey) ?? 0;
    int dailyWords = prefs.getInt(_dailyWordsKey) ?? 0;

    if (lastDate != today) {
      // If last written date was yesterday, keep streak. Else reset.
      final yesterday = DateTime.now().subtract(const Duration(days: 1)).toIso8601String().split('T').first;
      if (lastDate != yesterday) {
        streak = 0;
      }
      dailyWords = 0;
      // We don't set lastDate to today yet, until they actually write.
    }

    return {
      'streak': streak,
      'dailyWords': dailyWords,
      'dailyGoal': dailyGoal,
    };
  }

  static Future<void> addWords(int newWords) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T').first;
    final lastDate = prefs.getString(_lastDateKey);
    
    int streak = prefs.getInt(_streakKey) ?? 0;
    int dailyWords = prefs.getInt(_dailyWordsKey) ?? 0;

    if (lastDate != today) {
      final yesterday = DateTime.now().subtract(const Duration(days: 1)).toIso8601String().split('T').first;
      if (lastDate == yesterday) {
        streak += 1;
      } else {
        streak = 1;
      }
      dailyWords = newWords;
    } else {
      dailyWords += newWords;
    }

    await prefs.setString(_lastDateKey, today);
    await prefs.setInt(_streakKey, streak);
    await prefs.setInt(_dailyWordsKey, dailyWords);
  }
}
