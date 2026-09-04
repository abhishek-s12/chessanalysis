import 'package:chess/chess.dart' as chess_pkg;

/// Holds the parsed move lists and board states aligned by move index.
class ParsedPgn {
  /// Standard Algebraic Notation for each move, e.g. `['e4', 'e5', 'Nf3']`.
  final List<String> sanMoves;

  /// Universal Chess Interface notation for each move, e.g. `['e2e4', 'e7e5', 'g1f3']`.
  final List<String> uciMoves;

  /// Board position (FEN) immediately preceding each move.
  /// Index `i` contains the FEN before move `i` is played.
  final List<String> fensBeforeMoves;

  /// The board position (FEN) before the first move (initial position).
  final String initialFen;

  /// The board position (FEN) after all moves have been played.
  final String finalFen;

  /// PGN header tags (e.g., Event, Site, White, Black, Result).
  final Map<String, String> headers;

  const ParsedPgn({
    required this.sanMoves,
    required this.uciMoves,
    required this.fensBeforeMoves,
    required this.initialFen,
    required this.finalFen,
    required this.headers,
  });

  /// Number of half-moves (plies) in the game.
  int get moveCount => sanMoves.length;

  /// Returns the FEN after move at [index] (0-indexed).
  /// For example, index 0 is the FEN after the first move.
  String fenAfterMove(int index) {
    if (index < 0 || index >= moveCount) {
      throw RangeError.index(index, sanMoves, 'Move index out of bounds');
    }
    if (index + 1 < fensBeforeMoves.length) {
      return fensBeforeMoves[index + 1];
    }
    return finalFen;
  }
}

/// Service to parse raw PGN strings into aligned SAN moves, UCI moves, and FEN states.
class PgnParser {
  /// Parses a raw [pgnString] and returns index-aligned [ParsedPgn].
  static ParsedPgn parse(String pgnString) {
    final cleanPgn = _sanitizePgn(pgnString);

    final game = chess_pkg.Chess();
    final bool loaded = game.load_pgn(cleanPgn);

    final Map<String, String> headers = {};
    for (final entry in game.header.entries) {
      if (entry.key != null && entry.value != null) {
        headers[entry.key.toString()] = entry.value.toString();
      }
    }

    final String initialFen = headers['FEN'] ?? chess_pkg.Chess.DEFAULT_POSITION;

    final List<String> sanMoves = [];
    final List<String> uciMoves = [];
    final List<String> fensBeforeMoves = [];

    if (!loaded && game.history.isEmpty) {
      return ParsedPgn(
        sanMoves: sanMoves,
        uciMoves: uciMoves,
        fensBeforeMoves: fensBeforeMoves,
        initialFen: initialFen,
        finalFen: initialFen,
        headers: headers,
      );
    }

    // Replay the moves step-by-step from initial position to extract FEN before each move.
    final replayGame = chess_pkg.Chess.fromFEN(initialFen);

    for (final historyItem in game.history) {
      final move = historyItem.move;

      // 1. Record FEN before this move
      fensBeforeMoves.add(replayGame.fen);

      // 2. Generate SAN move notation
      final san = replayGame.move_to_san(move);
      sanMoves.add(san);

      // 3. Generate UCI move notation (e.g. 'e2e4', 'e1g1', 'e7e8q')
      final promotion = move.promotion != null
          ? move.promotion!.name.toLowerCase()
          : '';
      final uci = '${move.fromAlgebraic}${move.toAlgebraic}$promotion';
      uciMoves.add(uci);

      // 4. Advance replay state
      replayGame.make_move(move);
    }

    return ParsedPgn(
      sanMoves: List.unmodifiable(sanMoves),
      uciMoves: List.unmodifiable(uciMoves),
      fensBeforeMoves: List.unmodifiable(fensBeforeMoves),
      initialFen: initialFen,
      finalFen: replayGame.fen,
      headers: Map.unmodifiable(headers),
    );
  }

  /// Removes comments, clock timestamps, and evaluations that might interfere with PGN parsing.
  static String _sanitizePgn(String pgn) {
    // Remove inline curly brace comments e.g. {[%clk 0:03:00]} or {Annotator note}
    final withoutComments = pgn.replaceAll(RegExp(r'\{[^}]*\}'), '');
    // Remove recursive variations e.g. (1... d5 2. exd5)
    final withoutVariations = withoutComments.replaceAll(RegExp(r'\([^)]*\)'), '');
    // Remove NAG numeric annotations like $1, $2, etc.
    final withoutNags = withoutVariations.replaceAll(RegExp(r'\$\d+'), '');
    return withoutNags.trim();
  }
}
