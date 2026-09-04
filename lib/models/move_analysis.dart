import 'dart:convert';
import 'package:flutter/material.dart';

/// Classification of an individual move's quality.
enum MoveClassification {
  brilliant,
  great,
  best,
  excellent,
  good,
  inaccuracy,
  mistake,
  blunder,
  miss,
  book,
}

extension MoveClassificationX on MoveClassification {
  String get displayLabel {
    switch (this) {
      case MoveClassification.brilliant:
        return 'Brilliant';
      case MoveClassification.great:
        return 'Great';
      case MoveClassification.best:
        return 'Best';
      case MoveClassification.excellent:
        return 'Excellent';
      case MoveClassification.good:
        return 'Good';
      case MoveClassification.inaccuracy:
        return 'Inaccuracy';
      case MoveClassification.mistake:
        return 'Mistake';
      case MoveClassification.blunder:
        return 'Blunder';
      case MoveClassification.miss:
        return 'Miss';
      case MoveClassification.book:
        return 'Book';
    }
  }

  Color get color {
    switch (this) {
      case MoveClassification.brilliant:
        return const Color(0xFF1BAAA6); // Cyan
      case MoveClassification.great:
        return const Color(0xFF4A90E2); // Blue
      case MoveClassification.best:
        return const Color(0xFF81B64C); // Chess.com Green
      case MoveClassification.excellent:
        return const Color(0xFF6DA33F); // Muted Green
      case MoveClassification.good:
        return const Color(0xFF9E9E9E); // Grey
      case MoveClassification.inaccuracy:
        return const Color(0xFFECC440); // Yellow
      case MoveClassification.mistake:
        return const Color(0xFFE6912C); // Orange
      case MoveClassification.blunder:
        return const Color(0xFFE05344); // Red
      case MoveClassification.miss:
        return const Color(0xFFEA5B4E); // Coral
      case MoveClassification.book:
        return const Color(0xFFA88865); // Brown
    }
  }

  IconData get icon {
    switch (this) {
      case MoveClassification.brilliant:
        return Icons.auto_awesome_rounded;
      case MoveClassification.great:
        return Icons.verified_rounded;
      case MoveClassification.best:
        return Icons.star_rounded;
      case MoveClassification.excellent:
        return Icons.thumb_up_rounded;
      case MoveClassification.good:
        return Icons.check_rounded;
      case MoveClassification.inaccuracy:
        return Icons.priority_high_rounded;
      case MoveClassification.mistake:
        return Icons.help_outline_rounded;
      case MoveClassification.blunder:
        return Icons.close_rounded;
      case MoveClassification.miss:
        return Icons.cancel_outlined;
      case MoveClassification.book:
        return Icons.menu_book_rounded;
    }
  }
}

/// Analysis metadata for a single move (ply) in a game.
class MoveAnalysis {
  /// 0-indexed ply number in the game.
  final int ply;

  /// 1-indexed turn move number (e.g. 1, 2, 3).
  final int moveNumber;

  /// True if White made this move, false if Black.
  final bool isWhite;

  /// Standard Algebraic Notation move (e.g. "e4", "Nf3", "Qxf7#").
  final String san;

  /// UCI notation move (e.g. "e2e4", "g1f3").
  final String uci;

  /// Board FEN before this move was executed.
  final String fenBefore;

  /// Board FEN after this move was executed.
  final String fenAfter;

  /// Best move recommended by the engine in UCI format.
  final String bestMove;

  /// Centipawns score before move (White's perspective).
  final int? scoreBefore;

  /// Centipawns score after move (White's perspective).
  final int? scoreAfter;

  /// Moves to mate before move (null if not a forced mate).
  final int? mateBefore;

  /// Moves to mate after move (null if not a forced mate).
  final int? mateAfter;

  /// Quality classification of the move.
  final MoveClassification classification;

  /// Win probability (0 to 100) before move for the side making the move.
  final double winProbabilityBefore;

  /// Win probability (0 to 100) after move for the side making the move.
  final double winProbabilityAfter;

  /// Win probability lost due to this move (>= 0).
  final double winProbabilityDelta;

  const MoveAnalysis({
    required this.ply,
    required this.moveNumber,
    required this.isWhite,
    required this.san,
    required this.uci,
    required this.fenBefore,
    required this.fenAfter,
    required this.bestMove,
    this.scoreBefore,
    this.scoreAfter,
    this.mateBefore,
    this.mateAfter,
    required this.classification,
    required this.winProbabilityBefore,
    required this.winProbabilityAfter,
    required this.winProbabilityDelta,
  });

  Map<String, dynamic> toJson() {
    return {
      'ply': ply,
      'moveNumber': moveNumber,
      'isWhite': isWhite,
      'san': san,
      'uci': uci,
      'fenBefore': fenBefore,
      'fenAfter': fenAfter,
      'bestMove': bestMove,
      'scoreBefore': scoreBefore,
      'scoreAfter': scoreAfter,
      'mateBefore': mateBefore,
      'mateAfter': mateAfter,
      'classification': classification.name,
      'winProbabilityBefore': winProbabilityBefore,
      'winProbabilityAfter': winProbabilityAfter,
      'winProbabilityDelta': winProbabilityDelta,
    };
  }

  factory MoveAnalysis.fromJson(Map<String, dynamic> json) {
    return MoveAnalysis(
      ply: json['ply'] as int,
      moveNumber: json['moveNumber'] as int,
      isWhite: json['isWhite'] as bool,
      san: json['san'] as String,
      uci: json['uci'] as String,
      fenBefore: json['fenBefore'] as String,
      fenAfter: json['fenAfter'] as String,
      bestMove: (json['bestMove'] as String?) ?? '',
      scoreBefore: json['scoreBefore'] as int?,
      scoreAfter: json['scoreAfter'] as int?,
      mateBefore: json['mateBefore'] as int?,
      mateAfter: json['mateAfter'] as int?,
      classification: MoveClassification.values.firstWhere(
        (c) => c.name == json['classification'],
        orElse: () => MoveClassification.good,
      ),
      winProbabilityBefore: (json['winProbabilityBefore'] as num).toDouble(),
      winProbabilityAfter: (json['winProbabilityAfter'] as num).toDouble(),
      winProbabilityDelta: (json['winProbabilityDelta'] as num).toDouble(),
    );
  }
}

/// Aggregated analysis result for an entire game.
class GameAnalysisResult {
  /// Unique identifier or URL of the game.
  final String gameUrl;

  /// Move-by-move analysis list.
  final List<MoveAnalysis> moves;

  /// Overall White player accuracy percentage (0.0 - 100.0).
  final double whiteAccuracy;

  /// Overall Black player accuracy percentage (0.0 - 100.0).
  final double blackAccuracy;

  /// Name of the detected opening (e.g. "Sicilian Defense: Najdorf Variation").
  final String? openingName;

  /// ECO classification code (e.g. "B90", "C65").
  final String? ecoCode;

  /// Estimated performance rating (Elo) for White based on game accuracy.
  final int? estimatedWhiteElo;

  /// Estimated performance rating (Elo) for Black based on game accuracy.
  final int? estimatedBlackElo;

  /// Timestamp when this analysis was completed.
  final DateTime analyzedAt;

  const GameAnalysisResult({
    required this.gameUrl,
    required this.moves,
    required this.whiteAccuracy,
    required this.blackAccuracy,
    this.openingName,
    this.ecoCode,
    this.estimatedWhiteElo,
    this.estimatedBlackElo,
    required this.analyzedAt,
  });

  /// Whether an opening or ECO code was detected.
  bool get hasOpening =>
      (openingName != null && openingName!.isNotEmpty) ||
      (ecoCode != null && ecoCode!.isNotEmpty);

  /// Formatted opening label with ECO code if available (e.g. "B15 - Caro-Kann Defense").
  String get formattedOpening {
    if (ecoCode != null && openingName != null && openingName!.isNotEmpty) {
      return '$ecoCode - $openingName';
    }
    return openingName ?? ecoCode ?? '';
  }

  /// Total count of classified moves for White.
  int countClassificationForWhite(MoveClassification classification) {
    return moves.where((m) => m.isWhite && m.classification == classification).length;
  }

  /// Total count of classified moves for Black.
  int countClassificationForBlack(MoveClassification classification) {
    return moves.where((m) => !m.isWhite && m.classification == classification).length;
  }

  Map<String, dynamic> toJson() {
    return {
      'gameUrl': gameUrl,
      'moves': moves.map((m) => m.toJson()).toList(),
      'whiteAccuracy': whiteAccuracy,
      'blackAccuracy': blackAccuracy,
      'openingName': openingName,
      'ecoCode': ecoCode,
      'estimatedWhiteElo': estimatedWhiteElo,
      'estimatedBlackElo': estimatedBlackElo,
      'analyzedAt': analyzedAt.toIso8601String(),
    };
  }

  factory GameAnalysisResult.fromJson(Map<String, dynamic> json) {
    return GameAnalysisResult(
      gameUrl: (json['gameUrl'] as String?) ?? '',
      moves: (json['moves'] as List<dynamic>)
          .map((m) => MoveAnalysis.fromJson(m as Map<String, dynamic>))
          .toList(),
      whiteAccuracy: (json['whiteAccuracy'] as num).toDouble(),
      blackAccuracy: (json['blackAccuracy'] as num).toDouble(),
      openingName: json['openingName'] as String?,
      ecoCode: json['ecoCode'] as String?,
      estimatedWhiteElo: json['estimatedWhiteElo'] as int?,
      estimatedBlackElo: json['estimatedBlackElo'] as int?,
      analyzedAt: json['analyzedAt'] != null
          ? DateTime.parse(json['analyzedAt'] as String)
          : DateTime.now(),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory GameAnalysisResult.fromJsonString(String jsonString) {
    return GameAnalysisResult.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }
}
