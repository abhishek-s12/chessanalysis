import 'dart:async';
import 'dart:math' as math;
import 'package:chess/chess.dart' as chess_pkg;
import 'stockfish_driver_stub.dart'
    if (dart.library.io) 'stockfish_driver_io.dart';

export 'stockfish_driver_stub.dart'
    if (dart.library.io) 'stockfish_driver_io.dart';

/// Represents an engine evaluation of a chess position.
class StockfishEvaluation {
  /// Centipawn score normalized to White's perspective:
  /// positive values indicate White is ahead, negative values indicate Black is ahead.
  /// Null if the position is a forced mate.
  final int? centipawns;

  /// Moves until checkmate (positive if White is mating, negative if Black is mating).
  /// Null if no forced mate was detected.
  final int? mateIn;

  /// The engine's recommended best move in UCI format (e.g. "e2e4", "e1g1", "e7e8q").
  final String bestMove;

  /// Principal variation (the best sequence of moves identified by the engine).
  final List<String> pv;

  /// The search depth reached for this evaluation.
  final int depth;

  const StockfishEvaluation({
    this.centipawns,
    this.mateIn,
    required this.bestMove,
    this.pv = const [],
    required this.depth,
  });

  /// Whether a forced mate was found.
  bool get isMate => mateIn != null;

  @override
  String toString() {
    if (isMate) {
      return 'StockfishEvaluation(mate: $mateIn, bestMove: $bestMove, depth: $depth)';
    }
    return 'StockfishEvaluation(cp: $centipawns, bestMove: $bestMove, depth: $depth)';
  }
}

/// Represents a candidate line evaluated by the engine under MultiPV mode.
class EngineLine {
  /// Line rank (1 for top choice, 2 for second choice, etc.)
  final int multipv;

  /// Centipawn score normalized to White's perspective (+ White ahead, - Black ahead).
  final int? centipawns;

  /// Moves to mate (+ White mating, - Black mating).
  final int? mateIn;

  /// Recommended move in UCI format (e.g. "e2e4").
  final String bestMoveUci;

  /// Recommended move in standard algebraic notation (e.g. "e4", "Nf3").
  final String bestMoveSan;

  /// Full continuation sequence in UCI notation.
  final List<String> pvUci;

  /// Full continuation sequence in SAN notation.
  final List<String> pvSan;

  /// Search depth reached.
  final int depth;

  const EngineLine({
    required this.multipv,
    this.centipawns,
    this.mateIn,
    required this.bestMoveUci,
    required this.bestMoveSan,
    this.pvUci = const [],
    this.pvSan = const [],
    required this.depth,
  });

  bool get isMate => mateIn != null;

  /// Formatted score string (e.g. "+1.5", "-0.8", "+M2", "-M1").
  String get scoreString {
    if (mateIn != null) {
      return mateIn! > 0 ? '+M$mateIn' : '-M${mateIn!.abs()}';
    }
    if (centipawns == null) return '0.0';
    final score = centipawns! / 100.0;
    return score >= 0 ? '+${score.toStringAsFixed(1)}' : score.toStringAsFixed(1);
  }

  /// Formatted sequence preview of the first few continuation moves.
  String get formattedContinuation {
    if (pvSan.length > 1) {
      return pvSan.skip(1).take(5).join(' ');
    }
    return '';
  }

  @override
  String toString() {
    return 'EngineLine(multipv: $multipv, eval: $scoreString, move: $bestMoveSan, pv: $pvSan)';
  }
}

/// Abstract interface for UCI engine drivers.
abstract class IStockfishDriver {
  Stream<String> get stdout;
  bool get isReady;
  Future<void> init();
  void sendCommand(String command);
  void dispose();
}

class _ScoredMove {
  final Map<String, dynamic> move;
  final int sideScore;
  final String uci;
  _ScoredMove({required this.move, required this.sideScore, required this.uci});
}

/// Fallback UCI driver for desktop, web, and automated test environments
/// where native C++ libraries (`.so` / `.framework`) are not bundled.
class FallbackStockfishDriver implements IStockfishDriver {
  final StreamController<String> _stdoutController = StreamController<String>.broadcast();
  bool _ready = false;
  String _currentFen = chess_pkg.Chess.DEFAULT_POSITION;
  int _multiPv = 1;

  @override
  Stream<String> get stdout => _stdoutController.stream;

  @override
  bool get isReady => _ready;

  @override
  Future<void> init() async {
    _ready = true;
  }

  @override
  void sendCommand(String command) {
    final cmd = command.trim();
    if (cmd == 'uci') {
      _stdoutController.add('id name Stockfish Analyzer');
      _stdoutController.add('id author Chess Analyzer Team');
      _stdoutController.add('uciok');
    } else if (cmd == 'isready') {
      _stdoutController.add('readyok');
    } else if (cmd.startsWith('setoption name MultiPV value ')) {
      final valStr = cmd.substring('setoption name MultiPV value '.length).trim();
      _multiPv = int.tryParse(valStr) ?? 1;
    } else if (cmd.startsWith('position fen ')) {
      _currentFen = cmd.substring('position fen '.length).trim();
    } else if (cmd.startsWith('position startpos')) {
      _currentFen = chess_pkg.Chess.DEFAULT_POSITION;
    } else if (cmd.startsWith('go')) {
      _handleGoCommand(cmd);
    }
  }

  void _handleGoCommand(String cmd) {
    int depth = 10;
    final depthMatch = RegExp(r'depth (\d+)').firstMatch(cmd);
    if (depthMatch != null) {
      depth = int.parse(depthMatch.group(1)!);
    }

    Timer.run(() {
      final chess = chess_pkg.Chess.fromFEN(_currentFen);
      if (chess.in_checkmate) {
        _stdoutController.add('info depth $depth score mate 0 pv');
        _stdoutController.add('bestmove (none)');
        return;
      }

      final legalMoves = chess.moves({'verbose': true});
      if (legalMoves.isEmpty) {
        _stdoutController.add('info depth $depth score cp 0 pv');
        _stdoutController.add('bestmove (none)');
        return;
      }

      final isWhite = chess.turn == chess_pkg.Color.WHITE;
      final List<_ScoredMove> scored = [];

      for (final rawMove in legalMoves) {
        final moveMap = rawMove as Map<String, dynamic>;
        chess.move(moveMap);
        int score = _evaluateMaterialAndPosition(chess);
        chess.undo();

        final sideScore = isWhite ? score : -score;

        final from = moveMap['from'] as String;
        final to = moveMap['to'] as String;
        final promo = moveMap['promotion'] != null ? (moveMap['promotion'] as String).toLowerCase() : '';
        final uci = '$from$to$promo';

        scored.add(_ScoredMove(move: moveMap, sideScore: sideScore, uci: uci));
      }

      // Sort candidate moves descending by side score
      scored.sort((a, b) => b.sideScore.compareTo(a.sideScore));

      final linesToEmit = math.min(scored.length, _multiPv);
      for (int i = 0; i < linesToEmit; i++) {
        final candidate = scored[i];
        final rank = i + 1;
        _stdoutController.add(
          'info depth $depth multipv $rank score cp ${candidate.sideScore} pv ${candidate.uci}',
        );
      }

      final bestUci = scored.first.uci;
      _stdoutController.add('bestmove $bestUci');
    });
  }

  int _evaluateMaterialAndPosition(chess_pkg.Chess game) {
    const pieceValues = {
      'p': 100,
      'n': 320,
      'b': 330,
      'r': 500,
      'q': 900,
      'k': 0,
    };

    int score = 0;
    final fenBoard = game.fen.split(' ')[0];

    for (int i = 0; i < fenBoard.length; i++) {
      final char = fenBoard[i];
      final lower = char.toLowerCase();
      if (pieceValues.containsKey(lower)) {
        final val = pieceValues[lower]!;
        if (char == char.toUpperCase()) {
          score += val;
        } else {
          score -= val;
        }
      }
    }

    // Small mobility factor
    if (game.turn == chess_pkg.Color.WHITE) {
      score += game.moves().length * 2;
    } else {
      score -= game.moves().length * 2;
    }

    return score;
  }

  @override
  void dispose() {
    _stdoutController.close();
    _ready = false;
  }
}

class _RawEngineLine {
  final int multipv;
  int? centipawns;
  int? mateIn;
  List<String> pvUci = [];
  int depth = 1;

  _RawEngineLine({required this.multipv});
}

/// High-level Stockfish Engine service that manages initialization,
/// position analysis, and UCI evaluation.
class StockfishEngine {
  IStockfishDriver _driver;
  bool _isInitialized = false;

  StockfishEngine({IStockfishDriver? driver})
      : _driver = driver ?? _createDefaultDriver();

  static IStockfishDriver _createDefaultDriver() {
    return createPlatformStockfishDriver();
  }

  /// Whether the engine has completed UCI handshake and is ready for commands.
  bool get isReady => _isInitialized && _driver.isReady;

  /// Initializes the UCI engine and performs handshake.
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      await _driver.init();
    } catch (_) {
      // If live driver failed on host OS, gracefully fall back
      _driver = FallbackStockfishDriver();
      await _driver.init();
    }

    // Perform standard UCI handshake
    final completer = Completer<void>();
    late StreamSubscription sub;

    sub = _driver.stdout.listen((line) {
      if (line.trim() == 'uciok' && !completer.isCompleted) {
        completer.complete();
      }
    });

    _driver.sendCommand('uci');
    await completer.future.timeout(
      const Duration(seconds: 4),
      onTimeout: () => null,
    );
    await sub.cancel();

    _driver.sendCommand('isready');
    _isInitialized = true;
  }

  /// Evaluates a chess position represented by [fen] at the given [depth].
  ///
  /// Returns a [StockfishEvaluation] containing the centipawn score,
  /// best move in UCI format, and search depth.
  Future<StockfishEvaluation> evaluatePosition(
    String fen, {
    int depth = 10,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (!_isInitialized) {
      await init();
    }

    final completer = Completer<StockfishEvaluation>();
    late StreamSubscription sub;

    int? lastCp;
    int? lastMate;
    List<String> lastPv = [];

    // Check whose turn it is in this position
    final parts = fen.trim().split(RegExp(r'\s+'));
    final bool isWhiteToMove = parts.length > 1 ? parts[1] == 'w' : true;

    sub = _driver.stdout.listen((line) {
      final trimmed = line.trim();

      // Parse score and pv from info lines
      if (trimmed.startsWith('info') && trimmed.contains('score')) {
        final cpMatch = RegExp(r'score cp (-?\d+)').firstMatch(trimmed);
        if (cpMatch != null) {
          final rawCp = int.parse(cpMatch.group(1)!);
          // Normalize to White's perspective
          lastCp = isWhiteToMove ? rawCp : -rawCp;
          lastMate = null;
        }

        final mateMatch = RegExp(r'score mate (-?\d+)').firstMatch(trimmed);
        if (mateMatch != null) {
          final rawMate = int.parse(mateMatch.group(1)!);
          // Normalize mate count: positive = White winning, negative = Black winning
          lastMate = isWhiteToMove ? rawMate : -rawMate;
          lastCp = null;
        }

        final pvMatch = RegExp(r'\bpv\s+(.*)$').firstMatch(trimmed);
        if (pvMatch != null) {
          lastPv = pvMatch.group(1)!.trim().split(RegExp(r'\s+'));
        }
      }

      // Check for completion line: bestmove <move>
      if (trimmed.startsWith('bestmove')) {
        final moveMatch = RegExp(r'bestmove\s+([a-h1-8qrbn]+|\(none\))').firstMatch(trimmed);
        final bestMove = moveMatch != null ? moveMatch.group(1)! : '';

        if (!completer.isCompleted) {
          completer.complete(StockfishEvaluation(
            centipawns: lastCp ?? 0,
            mateIn: lastMate,
            bestMove: bestMove,
            pv: lastPv,
            depth: depth,
          ));
        }
      }
    });

    _driver.sendCommand('setoption name MultiPV value 1');
    _driver.sendCommand('position fen $fen');
    _driver.sendCommand('go depth $depth');

    try {
      final eval = await completer.future.timeout(timeout);
      await sub.cancel();
      return eval;
    } catch (e) {
      await sub.cancel();
      _driver.sendCommand('stop');
      rethrow;
    }
  }

  /// Evaluates the top candidate lines (MultiPV) for the given [fen] position.
  ///
  /// Converts all UCI moves into readable algebraic notation (SAN) based on the board state.
  Future<List<EngineLine>> evaluateTopLines(
    String fen, {
    int multiPv = 3,
    int depth = 10,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (!_isInitialized) {
      await init();
    }

    final completer = Completer<List<EngineLine>>();
    final Map<int, _RawEngineLine> rawLines = {};
    late StreamSubscription sub;

    final parts = fen.trim().split(RegExp(r'\s+'));
    final bool isWhiteToMove = parts.length > 1 ? parts[1] == 'w' : true;

    sub = _driver.stdout.listen((line) {
      final trimmed = line.trim();

      if (trimmed.startsWith('info') && trimmed.contains('score')) {
        // MultiPV rank
        final mpMatch = RegExp(r'multipv (\d+)').firstMatch(trimmed);
        final mp = mpMatch != null ? int.parse(mpMatch.group(1)!) : 1;

        final raw = rawLines.putIfAbsent(mp, () => _RawEngineLine(multipv: mp));

        // Depth
        final depthMatch = RegExp(r'depth (\d+)').firstMatch(trimmed);
        if (depthMatch != null) {
          raw.depth = int.parse(depthMatch.group(1)!);
        }

        // Score
        final cpMatch = RegExp(r'score cp (-?\d+)').firstMatch(trimmed);
        if (cpMatch != null) {
          final rawCp = int.parse(cpMatch.group(1)!);
          raw.centipawns = isWhiteToMove ? rawCp : -rawCp;
          raw.mateIn = null;
        }

        final mateMatch = RegExp(r'score mate (-?\d+)').firstMatch(trimmed);
        if (mateMatch != null) {
          final rawMate = int.parse(mateMatch.group(1)!);
          raw.mateIn = isWhiteToMove ? rawMate : -rawMate;
          raw.centipawns = null;
        }

        // PV line
        final pvMatch = RegExp(r'\bpv\s+(.*)$').firstMatch(trimmed);
        if (pvMatch != null) {
          raw.pvUci = pvMatch.group(1)!.trim().split(RegExp(r'\s+'));
        }
      }

      if (trimmed.startsWith('bestmove')) {
        if (!completer.isCompleted) {
          final sortedRaws = rawLines.values.toList()
            ..sort((a, b) => a.multipv.compareTo(b.multipv));

          final List<EngineLine> results = [];
          for (final raw in sortedRaws) {
            final bestMoveUci = raw.pvUci.isNotEmpty ? raw.pvUci.first : '';
            if (bestMoveUci.isEmpty || bestMoveUci == '(none)') continue;

            final sanPv = _convertPvToSan(fen, raw.pvUci);
            final bestMoveSan = sanPv.isNotEmpty ? sanPv.first : bestMoveUci;

            results.add(EngineLine(
              multipv: raw.multipv,
              centipawns: raw.centipawns,
              mateIn: raw.mateIn,
              bestMoveUci: bestMoveUci,
              bestMoveSan: bestMoveSan,
              pvUci: raw.pvUci,
              pvSan: sanPv,
              depth: raw.depth,
            ));
          }
          completer.complete(results);
        }
      }
    });

    _driver.sendCommand('setoption name MultiPV value $multiPv');
    _driver.sendCommand('position fen $fen');
    _driver.sendCommand('go depth $depth');

    try {
      final lines = await completer.future.timeout(timeout);
      await sub.cancel();
      return lines;
    } catch (_) {
      await sub.cancel();
      _driver.sendCommand('stop');
      // If timed out, return whatever lines were parsed so far
      final sortedRaws = rawLines.values.toList()
        ..sort((a, b) => a.multipv.compareTo(b.multipv));

      final List<EngineLine> results = [];
      for (final raw in sortedRaws) {
        final bestMoveUci = raw.pvUci.isNotEmpty ? raw.pvUci.first : '';
        if (bestMoveUci.isEmpty || bestMoveUci == '(none)') continue;

        final sanPv = _convertPvToSan(fen, raw.pvUci);
        final bestMoveSan = sanPv.isNotEmpty ? sanPv.first : bestMoveUci;

        results.add(EngineLine(
          multipv: raw.multipv,
          centipawns: raw.centipawns,
          mateIn: raw.mateIn,
          bestMoveUci: bestMoveUci,
          bestMoveSan: bestMoveSan,
          pvUci: raw.pvUci,
          pvSan: sanPv,
          depth: raw.depth,
        ));
      }
      return results;
    }
  }

  static List<String> _convertPvToSan(String fen, List<String> pvUci) {
    final List<String> sanMoves = [];
    try {
      final chess = chess_pkg.Chess.fromFEN(fen);
      for (final uci in pvUci) {
        if (uci.length < 4) break;
        final from = uci.substring(0, 2);
        final to = uci.substring(2, 4);
        final promo = uci.length > 4 ? uci.substring(4, 5).toLowerCase() : null;

        final legalMoves = chess.moves({'verbose': true});
        Map<String, dynamic>? match;
        for (final m in legalMoves) {
          final moveMap = m as Map<String, dynamic>;
          final mPromo = moveMap['promotion'] != null
              ? (moveMap['promotion'] as String).toLowerCase()
              : null;
          if (moveMap['from'] == from &&
              moveMap['to'] == to &&
              (promo == null || mPromo == promo)) {
            match = moveMap;
            break;
          }
        }

        if (match != null) {
          final san = match['san'] as String;
          sanMoves.add(san);
          chess.move(san);
        } else {
          break;
        }
      }
    } catch (_) {}
    return sanMoves;
  }

  /// Shuts down the engine and releases resources.
  void dispose() {
    _driver.sendCommand('quit');
    _driver.dispose();
    _isInitialized = false;
  }
}

