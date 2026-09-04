import 'package:hive/hive.dart';
import '../models/move_analysis.dart';

/// Manages caching of completed game analyses in Hive keyed by game URL.
class AnalysisCacheService {
  static const String boxName = 'game_analysis_cache';
  Box<String>? _box;

  AnalysisCacheService([this._box]);

  Future<Box<String>> _getBox() async {
    if (_box != null && _box!.isOpen) {
      return _box!;
    }
    _box = await Hive.openBox<String>(boxName);
    return _box!;
  }

  /// Checks whether an analysis already exists for [gameUrl].
  Future<bool> hasAnalysis(String gameUrl) async {
    if (gameUrl.isEmpty) return false;
    try {
      final box = await _getBox();
      return box.containsKey(gameUrl);
    } catch (_) {
      return false;
    }
  }

  /// Retrieves cached analysis for [gameUrl], or null if not found.
  Future<GameAnalysisResult?> getAnalysis(String gameUrl) async {
    if (gameUrl.isEmpty) return null;
    try {
      final box = await _getBox();
      final jsonString = box.get(gameUrl);
      if (jsonString == null) return null;
      return GameAnalysisResult.fromJsonString(jsonString);
    } catch (_) {
      return null;
    }
  }

  /// Saves [result] into Hive keyed by its `gameUrl`.
  Future<void> saveAnalysis(GameAnalysisResult result) async {
    if (result.gameUrl.isEmpty) return;
    final box = await _getBox();
    await box.put(result.gameUrl, result.toJsonString());
  }

  /// Clears the analysis cache.
  Future<void> clearCache() async {
    final box = await _getBox();
    await box.clear();
  }
}
