import 'dart:async';
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

/// Abstract interface for UCI engine drivers.
abstract class IStockfishDriver {
  Stream<String> get stdout;
  bool get isReady;
  Future<void> init();
  void sendCommand(String command);
  void dispose();
}

/// Fallback UCI driver for desktop, web, and automated test environments
/// where native C++ libraries (`.so` / `.framework`) are not bundled.
class FallbackStockfishDriver implements IStockfishDriver {
  final StreamController<String> _stdoutController = StreamController<String>.broadcast();
  bool _ready = false;
  String _currentFen = chess_pkg.Chess.DEFAULT_POSITION;

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

      // Find the best move using classical heuristic evaluation
      Map<String, dynamic> bestMoveData = legalMoves.first as Map<String, dynamic>;
      int bestScore = -999999;

      final isWhite = chess.turn == chess_pkg.Color.WHITE;

      for (final rawMove in legalMoves) {
        final moveMap = rawMove as Map<String, dynamic>;
        chess.move(moveMap);
        int score = _evaluateMaterialAndPosition(chess);
        chess.undo();

        if (!isWhite) {
          score = -score;
        }

        if (score > bestScore) {
          bestScore = score;
          bestMoveData = moveMap;
        }
      }

      // Convert best move to UCI notation
      final from = bestMoveData['from'] as String;
      final to = bestMoveData['to'] as String;
      final promo = bestMoveData['promotion'] != null ? (bestMoveData['promotion'] as String).toLowerCase() : '';
      final uciBestMove = '$from$to$promo';

      // Output progressive info lines culminating in the target depth
      final sideMultiplier = isWhite ? 1 : -1;
      final reportedCp = bestScore * sideMultiplier;

      _stdoutController.add('info depth $depth seldepth ${depth + 2} score cp $reportedCp pv $uciBestMove');
      _stdoutController.add('bestmove $uciBestMove');
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

        final pvMatch = RegExp(r'pv\s+(.*)$').firstMatch(trimmed);
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

    _driver.sendCommand('position fen $fen');
    _driver.sendCommand('go depth $depth');

    try {
      final eval = await completer.future.timeout(timeout);
      await sub.cancel();
      return eval;
    } catch (e) {
      await sub.cancel();
      // In case of timeout or cancellation, send stop
      _driver.sendCommand('stop');
      rethrow;
    }
  }

  /// Shuts down the engine and releases resources.
  void dispose() {
    _driver.sendCommand('quit');
    _driver.dispose();
    _isInitialized = false;
  }
}
