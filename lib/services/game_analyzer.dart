import 'dart:math' as math;
import '../models/move_analysis.dart';
import 'analysis_cache_service.dart';
import 'opening_service.dart';
import 'pgn_parser.dart';
import 'stockfish_engine.dart';

/// Analyzes full chess games move-by-move using Stockfish and generates move classifications,
/// player accuracies, and caches results in Hive.
class GameAnalyzer {
  final StockfishEngine _engine;
  final AnalysisCacheService _cacheService;
  final OpeningService _openingService;

  GameAnalyzer({
    StockfishEngine? engine,
    AnalysisCacheService? cacheService,
    OpeningService? openingService,
  })  : _engine = engine ?? StockfishEngine(),
        _cacheService = cacheService ?? AnalysisCacheService(),
        _openingService = openingService ?? OpeningService();

  /// Analyzes a game from its [pgn] string.
  ///
  /// If [gameUrl] is provided and an analysis is already cached, returns the cached result
  /// unless [forceReanalyze] is true.
  ///
  /// Reports progress via [onProgress] with (currentMove, totalMoves).
  Future<GameAnalysisResult> analyzeGame({
    required String pgn,
    String? gameUrl,
    int depth = 10,
    void Function(int current, int total)? onProgress,
    bool forceReanalyze = false,
  }) async {
    final cleanUrl = gameUrl ?? '';

    // 1. Check cache first
    if (!forceReanalyze && cleanUrl.isNotEmpty) {
      final cached = await _cacheService.getAnalysis(cleanUrl);
      if (cached != null) {
        onProgress?.call(cached.moves.length, cached.moves.length);
        return cached;
      }
    }

    // 2. Parse PGN and detect Opening metadata
    final parsed = PgnParser.parse(pgn);
    final totalMoves = parsed.moveCount;
    final openingInfo = _openingService.detectFromPgnOrUrl(pgn: pgn);

    if (totalMoves == 0) {
      final emptyResult = GameAnalysisResult(
        gameUrl: cleanUrl,
        moves: [],
        whiteAccuracy: 100.0,
        blackAccuracy: 100.0,
        openingName: openingInfo.name,
        ecoCode: openingInfo.eco,
        analyzedAt: DateTime.now(),
      );
      return emptyResult;
    }

    // 3. Ensure engine is initialized
    await _engine.init();

    // 4. Initial evaluation before first move
    StockfishEvaluation currentEval = await _engine.evaluatePosition(
      parsed.initialFen,
      depth: depth,
    );

    final List<MoveAnalysis> analyzedMoves = [];
    final List<double> whiteDeltas = [];
    final List<double> blackDeltas = [];

    // 5. Analyze each move sequentially
    for (int i = 0; i < totalMoves; i++) {
      final isWhite = i % 2 == 0;
      final moveNumber = (i ~/ 2) + 1;
      final san = parsed.sanMoves[i];
      final uci = parsed.uciMoves[i];
      final fenBefore = parsed.fensBeforeMoves[i];
      final fenAfter = parsed.fenAfterMove(i);

      final scoreBefore = currentEval.centipawns;
      final mateBefore = currentEval.mateIn;
      final bestMove = currentEval.bestMove;

      final winProbBefore = calculateWinProbability(
        centipawns: scoreBefore,
        mateIn: mateBefore,
        forWhite: isWhite,
      );

      // Evaluate resulting position after this move
      final nextEval = await _engine.evaluatePosition(
        fenAfter,
        depth: depth,
      );

      final scoreAfter = nextEval.centipawns;
      final mateAfter = nextEval.mateIn;

      final winProbAfter = calculateWinProbability(
        centipawns: scoreAfter,
        mateIn: mateAfter,
        forWhite: isWhite,
      );

      // Win probability loss (clamped >= 0)
      double delta = winProbBefore - winProbAfter;
      if (delta < 0.0) delta = 0.0;

      // Check if this move is within the recognized theoretical opening book
      final isBookMove = i < openingInfo.bookPlyCount;

      // Check for Brilliant move: piece sacrifice where evaluation remains solid/winning
      bool isBrilliant = false;
      if (!isBookMove &&
          bestMove.isNotEmpty &&
          uci.toLowerCase() == bestMove.toLowerCase() &&
          delta <= 0.5) {
        final myBefore = _countMaterial(fenBefore, isWhite);
        final myAfter = _countMaterial(fenAfter, isWhite);
        final oppBefore = _countMaterial(fenBefore, !isWhite);
        final oppAfter = _countMaterial(fenAfter, !isWhite);
        final netSacrifice = (myBefore - myAfter) - (oppBefore - oppAfter);
        if (netSacrifice >= 2 && winProbAfter >= 50.0) {
          isBrilliant = true;
        }
      }

      final MoveClassification classification;
      if (isBookMove) {
        classification = MoveClassification.book;
      } else if (isBrilliant) {
        classification = MoveClassification.brilliant;
      } else {
        classification = classifyMove(
          uci: uci,
          bestMove: bestMove,
          winProbDelta: delta,
          scoreBefore: scoreBefore,
          scoreAfter: scoreAfter,
          mateBefore: mateBefore,
          mateAfter: mateAfter,
          isWhite: isWhite,
        );
      }

      // Book and brilliant moves do not penalize accuracy
      final effectiveDelta = (isBookMove || isBrilliant) ? 0.0 : delta;

      if (isWhite) {
        whiteDeltas.add(effectiveDelta);
      } else {
        blackDeltas.add(effectiveDelta);
      }

      analyzedMoves.add(MoveAnalysis(
        ply: i,
        moveNumber: moveNumber,
        isWhite: isWhite,
        san: san,
        uci: uci,
        fenBefore: fenBefore,
        fenAfter: fenAfter,
        bestMove: bestMove,
        scoreBefore: scoreBefore,
        scoreAfter: scoreAfter,
        mateBefore: mateBefore,
        mateAfter: mateAfter,
        classification: classification,
        winProbabilityBefore: winProbBefore,
        winProbabilityAfter: winProbAfter,
        winProbabilityDelta: delta,
      ));

      // Advance evaluation
      currentEval = nextEval;

      onProgress?.call(i + 1, totalMoves);
    }

    // 6. Calculate player accuracies and estimated ratings
    final whiteAccuracy = _calculateAccuracy(whiteDeltas);
    final blackAccuracy = _calculateAccuracy(blackDeltas);
    final estimatedWhiteElo = calculateEstimatedElo(whiteAccuracy);
    final estimatedBlackElo = calculateEstimatedElo(blackAccuracy);

    final result = GameAnalysisResult(
      gameUrl: cleanUrl,
      moves: analyzedMoves,
      whiteAccuracy: whiteAccuracy,
      blackAccuracy: blackAccuracy,
      openingName: openingInfo.name,
      ecoCode: openingInfo.eco,
      estimatedWhiteElo: estimatedWhiteElo,
      estimatedBlackElo: estimatedBlackElo,
      analyzedAt: DateTime.now(),
    );

    // 7. Cache in Hive
    if (cleanUrl.isNotEmpty) {
      await _cacheService.saveAnalysis(result);
    }

    return result;
  }

  /// Calculates win probability percentage (0.0 to 100.0) for the specified side.
  static double calculateWinProbability({
    required int? centipawns,
    required int? mateIn,
    required bool forWhite,
  }) {
    if (mateIn != null) {
      if (mateIn > 0) {
        return forWhite ? 100.0 : 0.0;
      } else {
        return forWhite ? 0.0 : 100.0;
      }
    }

    final cp = centipawns ?? 0;
    // Standard model: 50 + 50 * (2 / (1 + exp(-0.00368208 * cp)) - 1)
    final double exponent = -0.00368208 * cp;
    final double whiteWinProb = 100.0 / (1.0 + math.exp(exponent));

    return forWhite ? whiteWinProb : (100.0 - whiteWinProb);
  }

  /// Classifies a move based on win probability loss and best move matching.
  static MoveClassification classifyMove({
    required String uci,
    required String bestMove,
    required double winProbDelta,
    required int? scoreBefore,
    required int? scoreAfter,
    required int? mateBefore,
    required int? mateAfter,
    required bool isWhite,
  }) {
    // If move matches the engine's primary recommendation
    if (bestMove.isNotEmpty && uci.toLowerCase() == bestMove.toLowerCase()) {
      return MoveClassification.best;
    }

    // Classify by Win Probability drop
    if (winProbDelta <= 1.0) {
      return MoveClassification.best;
    } else if (winProbDelta <= 3.5) {
      return MoveClassification.excellent;
    } else if (winProbDelta <= 7.0) {
      return MoveClassification.good;
    } else if (winProbDelta <= 14.0) {
      return MoveClassification.inaccuracy;
    } else if (winProbDelta <= 24.0) {
      return MoveClassification.mistake;
    } else {
      return MoveClassification.blunder;
    }
  }

  /// Calculates accuracy percentage (0.0 to 100.0) from a list of win probability deltas.
  static double _calculateAccuracy(List<double> deltas) {
    if (deltas.isEmpty) return 100.0;

    double sumAccuracy = 0.0;
    for (final delta in deltas) {
      // Harmonic formula penalizing larger drops smoothly:
      // A move with 0 delta gives 100%, 5 delta gives ~88%, 20 delta gives ~50%
      final double moveAcc = 100.0 * math.exp(-0.035 * delta);
      sumAccuracy += moveAcc;
    }

    final rawAccuracy = sumAccuracy / deltas.length;
    return double.parse(rawAccuracy.clamp(0.0, 100.0).toStringAsFixed(1));
  }

  /// Calculates realistic estimated player performance rating (Elo) from accuracy.
  static int calculateEstimatedElo(double accuracy) {
    double elo;
    if (accuracy >= 98.0) {
      elo = 2750 + (accuracy - 98.0) * 80;
    } else if (accuracy >= 95.0) {
      elo = 2450 + (accuracy - 95.0) * 100;
    } else if (accuracy >= 90.0) {
      elo = 2050 + (accuracy - 90.0) * 80;
    } else if (accuracy >= 80.0) {
      elo = 1600 + (accuracy - 80.0) * 45;
    } else if (accuracy >= 70.0) {
      elo = 1200 + (accuracy - 70.0) * 40;
    } else {
      elo = (accuracy / 70.0) * 1200;
    }
    // Round to nearest 10
    final rounded = ((elo.clamp(400.0, 2950.0) / 10).round()) * 10;
    return rounded;
  }

  /// Counts piece material points from a FEN string for a given color.
  static int _countMaterial(String fen, bool forWhite) {
    final board = fen.split(' ')[0];
    const pieceValues = {
      'p': 1,
      'n': 3,
      'b': 3,
      'r': 5,
      'q': 9,
    };
    int total = 0;
    for (int i = 0; i < board.length; i++) {
      final ch = board[i];
      final lower = ch.toLowerCase();
      if (pieceValues.containsKey(lower)) {
        final isWhitePiece = ch == ch.toUpperCase();
        if (isWhitePiece == forWhite) {
          total += pieceValues[lower]!;
        }
      }
    }
    return total;
  }
}
