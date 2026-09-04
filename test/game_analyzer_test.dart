import 'package:flutter_test/flutter_test.dart';
import 'package:chess_analyzer/models/move_analysis.dart';
import 'package:chess_analyzer/services/analysis_cache_service.dart';
import 'package:chess_analyzer/services/game_analyzer.dart';
import 'package:chess_analyzer/services/stockfish_engine.dart';

/// In-memory mock cache for testing without native file system Hive locks
class InMemoryAnalysisCacheService extends AnalysisCacheService {
  final Map<String, String> _storage = {};

  @override
  Future<bool> hasAnalysis(String gameUrl) async {
    return _storage.containsKey(gameUrl);
  }

  @override
  Future<GameAnalysisResult?> getAnalysis(String gameUrl) async {
    final raw = _storage[gameUrl];
    if (raw == null) return null;
    return GameAnalysisResult.fromJsonString(raw);
  }

  @override
  Future<void> saveAnalysis(GameAnalysisResult result) async {
    _storage[result.gameUrl] = result.toJsonString();
  }

  @override
  Future<void> clearCache() async {
    _storage.clear();
  }
}

void main() {
  group('MoveAnalysis & Classification Models', () {
    test('MoveClassification visual properties are defined', () {
      for (final c in MoveClassification.values) {
        expect(c.displayLabel, isNotEmpty);
        expect(c.color, isNotNull);
        expect(c.icon, isNotNull);
      }
    });

    test('MoveAnalysis serialization round-trip', () {
      const move = MoveAnalysis(
        ply: 0,
        moveNumber: 1,
        isWhite: true,
        san: 'e4',
        uci: 'e2e4',
        fenBefore: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        fenAfter: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1',
        bestMove: 'e2e4',
        scoreBefore: 20,
        scoreAfter: 25,
        classification: MoveClassification.best,
        winProbabilityBefore: 51.0,
        winProbabilityAfter: 51.5,
        winProbabilityDelta: 0.0,
      );

      final json = move.toJson();
      final revived = MoveAnalysis.fromJson(json);

      expect(revived.ply, 0);
      expect(revived.san, 'e4');
      expect(revived.uci, 'e2e4');
      expect(revived.classification, MoveClassification.best);
      expect(revived.scoreBefore, 20);
    });
  });

  group('GameAnalyzer Logic & Calculations', () {
    test('calculateWinProbability returns realistic values', () {
      // Equal position (~0 cp) should be ~50%
      final equalProb = GameAnalyzer.calculateWinProbability(
        centipawns: 0,
        mateIn: null,
        forWhite: true,
      );
      expect(equalProb, closeTo(50.0, 1.0));

      // White ahead by +300 cp (3 pawns)
      final aheadProb = GameAnalyzer.calculateWinProbability(
        centipawns: 300,
        mateIn: null,
        forWhite: true,
      );
      expect(aheadProb, greaterThan(70.0));

      // Black ahead by -300 cp from Black's perspective
      final blackAheadProb = GameAnalyzer.calculateWinProbability(
        centipawns: -300,
        mateIn: null,
        forWhite: false,
      );
      expect(blackAheadProb, greaterThan(70.0));

      // Mate in 1 for White
      expect(
        GameAnalyzer.calculateWinProbability(
          centipawns: null,
          mateIn: 1,
          forWhite: true,
        ),
        100.0,
      );
    });

    test('classifyMove categorizes moves appropriately', () {
      // Direct best move match
      expect(
        GameAnalyzer.classifyMove(
          uci: 'e2e4',
          bestMove: 'e2e4',
          winProbDelta: 0.0,
          scoreBefore: 20,
          scoreAfter: 20,
          mateBefore: null,
          mateAfter: null,
          isWhite: true,
        ),
        MoveClassification.best,
      );

      // Minor drop <= 3.5% gives excellent
      expect(
        GameAnalyzer.classifyMove(
          uci: 'd2d4',
          bestMove: 'e2e4',
          winProbDelta: 2.0,
          scoreBefore: 20,
          scoreAfter: 15,
          mateBefore: null,
          mateAfter: null,
          isWhite: true,
        ),
        MoveClassification.excellent,
      );

      // Severe drop >= 25% gives blunder
      expect(
        GameAnalyzer.classifyMove(
          uci: 'g2g4',
          bestMove: 'e2e4',
          winProbDelta: 30.0,
          scoreBefore: 20,
          scoreAfter: -200,
          mateBefore: null,
          mateAfter: null,
          isWhite: true,
        ),
        MoveClassification.blunder,
      );
    });
  });

  group('Full Game Analysis & Caching Flow', () {
    test('analyzes short game, reports progress, and caches result', () async {
      final engine = StockfishEngine(driver: FallbackStockfishDriver());
      final cacheService = InMemoryAnalysisCacheService();
      final analyzer = GameAnalyzer(engine: engine, cacheService: cacheService);

      const pgn = '''
[Event "Mini Game"]
[Site "Chess.com"]
[White "Player1"]
[Black "Player2"]

1. e4 e5 2. Nf3 Nc6 1-0
''';
      const gameUrl = 'https://www.chess.com/game/live/99999999';

      final progressReports = <int>[];

      // First run: analyze and cache
      final result = await analyzer.analyzeGame(
        pgn: pgn,
        gameUrl: gameUrl,
        depth: 6,
        onProgress: (current, total) {
          progressReports.add(current);
        },
      );

      expect(result.moves.length, 4);
      expect(result.whiteAccuracy, inInclusiveRange(0.0, 100.0));
      expect(result.blackAccuracy, inInclusiveRange(0.0, 100.0));
      expect(progressReports, containsAll([1, 2, 3, 4]));

      // Verify cached in cacheService
      final isCached = await cacheService.hasAnalysis(gameUrl);
      expect(isCached, isTrue);

      // Second run: verify skips re-analysis and loads directly from cache
      int secondRunProgressCalls = 0;
      final cachedResult = await analyzer.analyzeGame(
        pgn: pgn,
        gameUrl: gameUrl,
        depth: 6,
        onProgress: (current, total) {
          secondRunProgressCalls++;
        },
      );

      expect(cachedResult.gameUrl, gameUrl);
      expect(cachedResult.moves.length, 4);
      expect(cachedResult.whiteAccuracy, result.whiteAccuracy);
      expect(secondRunProgressCalls, 1); // Only initial complete notification
    });

    test('classifies opening moves as book and captures opening metadata', () async {
      final engine = StockfishEngine(driver: FallbackStockfishDriver());
      final cacheService = InMemoryAnalysisCacheService();
      final analyzer = GameAnalyzer(engine: engine, cacheService: cacheService);

      const pgn = '''
[Event "Live Chess"]
[Site "Chess.com"]
[White "Hikaru"]
[Black "only_strong_moves"]
[ECO "B15"]
[ECOUrl "https://www.chess.com/openings/Caro-Kann-Defense-Gurgenidze-System-4.h3-Bg7"]

1. e4 g6 2. d4 c6 3. Nc3 d5 4. h3 Bg7 0-1
''';

      final result = await analyzer.analyzeGame(
        pgn: pgn,
        depth: 5,
      );

      expect(result.ecoCode, equals('B15'));
      expect(result.openingName, equals('Caro-Kann Defense: Gurgenidze System'));
      expect(result.hasOpening, isTrue);

      // Verify that estimated Elo was calculated
      expect(result.estimatedWhiteElo, isNotNull);
      expect(result.estimatedWhiteElo, inInclusiveRange(1000, 3000));
      expect(result.estimatedBlackElo, isNotNull);
      expect(result.estimatedBlackElo, inInclusiveRange(1000, 3000));

      // Verify that the moves are classified as Book
      final bookMoves = result.moves.where((m) => m.classification == MoveClassification.book).toList();
      expect(bookMoves, isNotEmpty);
      expect(bookMoves.length, greaterThanOrEqualTo(4));
    });

    test('calculateEstimatedElo scales logically with accuracy', () {
      expect(GameAnalyzer.calculateEstimatedElo(99.0), greaterThanOrEqualTo(2800));
      expect(GameAnalyzer.calculateEstimatedElo(95.0), inInclusiveRange(2400, 2500));
      expect(GameAnalyzer.calculateEstimatedElo(85.0), inInclusiveRange(1800, 2000));
      expect(GameAnalyzer.calculateEstimatedElo(75.0), inInclusiveRange(1300, 1500));
      expect(GameAnalyzer.calculateEstimatedElo(50.0), lessThan(1200));
    });
  });
}
