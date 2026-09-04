import 'package:flutter/material.dart';
import '../models/chess_game.dart';
import '../models/move_analysis.dart';

class GameCard extends StatelessWidget {
  final ChessGame game;
  final String searchedUsername;
  final VoidCallback? onTap;
  final VoidCallback? onAnalyze;
  final VoidCallback? onReview;
  final bool isAnalyzing;
  final int analyzedMoves;
  final int totalMoves;
  final GameAnalysisResult? cachedAnalysis;

  const GameCard({
    super.key,
    required this.game,
    required this.searchedUsername,
    this.onTap,
    this.onAnalyze,
    this.onReview,
    this.isAnalyzing = false,
    this.analyzedMoves = 0,
    this.totalMoves = 0,
    this.cachedAnalysis,
  });

  @override
  Widget build(BuildContext context) {
    final isWhite = game.isUserWhite(searchedUsername);
    final user = game.getUser(searchedUsername);
    final opponent = game.getOpponent(searchedUsername);
    final outcome = game.getUserOutcome(searchedUsername);
    final outcomeText = game.getOutcomeDescription(searchedUsername);

    final Color outcomeColor;
    final IconData outcomeIcon;
    final String outcomeLabel;

    switch (outcome) {
      case GameOutcome.win:
        outcomeColor = const Color(0xFF81B64C);
        outcomeIcon = Icons.check_circle_rounded;
        outcomeLabel = 'WIN';
        break;
      case GameOutcome.loss:
        outcomeColor = const Color(0xFFE05344);
        outcomeIcon = Icons.cancel_rounded;
        outcomeLabel = 'LOSS';
        break;
      case GameOutcome.draw:
        outcomeColor = const Color(0xFF9E9E9E);
        outcomeIcon = Icons.remove_circle_rounded;
        outcomeLabel = 'DRAW';
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF262421),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: outcomeColor.withAlpha(50),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap ?? onReview ?? onAnalyze,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Opponent info & Outcome badge
                Row(
                  children: [
                    // Color piece indicator badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isWhite ? Colors.white.withAlpha(25) : Colors.black.withAlpha(60),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isWhite ? Colors.white38 : Colors.white12,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isWhite ? Icons.circle : Icons.circle_outlined,
                            size: 10,
                            color: isWhite ? Colors.white : Colors.white70,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isWhite ? 'White' : 'Black',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isWhite ? Colors.white : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Opponent username & rating
                    Expanded(
                      child: Row(
                        children: [
                          const Text(
                            'vs ',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              opponent.username,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (opponent.rating != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF36322C),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${opponent.rating}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Outcome badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: outcomeColor.withAlpha(35),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: outcomeColor.withAlpha(90),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(outcomeIcon, size: 13, color: outcomeColor),
                          const SizedBox(width: 5),
                          Text(
                            outcomeLabel,
                            style: TextStyle(
                              color: outcomeColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Middle row: outcome detail text (e.g. "Won by checkmate")
                Text(
                  outcomeText,
                  style: TextStyle(
                    color: outcomeColor.withAlpha(220),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 10),

                // Metadata row: time control, date, player rating
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Time control tag
                    Row(
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 14,
                          color: Colors.white54,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          game.formattedTimeControl,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        if (user.rating != null) ...[
                          const SizedBox(width: 10),
                          const Text(
                            '•',
                            style: TextStyle(color: Colors.white30, fontSize: 12),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Rating: ${user.rating}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                    // Date
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 13,
                          color: Colors.white38,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          game.formattedDate,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Opening & ECO badge if available
                if ((cachedAnalysis?.openingName != null && cachedAnalysis!.openingName!.isNotEmpty) ||
                    (game.openingName != null && game.openingName!.isNotEmpty) ||
                    (game.eco != null && game.eco!.isNotEmpty)) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5C8BB0).withAlpha(35),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF5C8BB0).withAlpha(80)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.menu_book_rounded, size: 11, color: Color(0xFF7AA2C2)),
                            if ((cachedAnalysis?.ecoCode ?? game.eco) != null) ...[
                              const SizedBox(width: 4),
                              Text(
                                cachedAnalysis?.ecoCode ?? game.eco!,
                                style: const TextStyle(
                                  color: Color(0xFF8BB3D6),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          cachedAnalysis?.openingName ?? game.openingName ?? 'Theoretical Line',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFBBB3A8),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),
                const Divider(color: Color(0xFF36322C), height: 1),
                const SizedBox(height: 10),

                // Bottom Analysis Section
                _buildAnalysisRow(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnalysisRow(BuildContext context) {
    final isWhite = game.isUserWhite(searchedUsername);
    if (isAnalyzing) {
      final progressPercent = totalMoves > 0 ? (analyzedMoves / totalMoves) : 0.0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF81B64C),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Analyzing ($analyzedMoves/$totalMoves moves)...',
                    style: const TextStyle(
                      color: Color(0xFF81B64C),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Text(
                '${(progressPercent * 100).toInt()}%',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: totalMoves > 0 ? progressPercent : null,
              backgroundColor: const Color(0xFF36322C),
              color: const Color(0xFF81B64C),
              minHeight: 5,
            ),
          ),
        ],
      );
    }

    if (cachedAnalysis != null) {
      final userAccuracy = isWhite
          ? cachedAnalysis!.whiteAccuracy
          : cachedAnalysis!.blackAccuracy;
      final opponentAccuracy = isWhite
          ? cachedAnalysis!.blackAccuracy
          : cachedAnalysis!.whiteAccuracy;

      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF81B64C).withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF81B64C).withAlpha(80)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.analytics_rounded,
                      size: 14,
                      color: Color(0xFF81B64C),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Accuracy: $userAccuracy%',
                      style: const TextStyle(
                        color: Color(0xFF81B64C),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Opponent: $opponentAccuracy%',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
          Row(
            children: [
              if (onReview != null)
                ElevatedButton.icon(
                  onPressed: onReview,
                  icon: const Icon(Icons.rate_review_rounded, size: 14),
                  label: const Text('Review'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF81B64C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              if (onAnalyze != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onAnalyze,
                  tooltip: 'Re-analyze',
                  icon: const Icon(Icons.refresh, size: 16, color: Colors.white38),
                ),
              ],
            ],
          ),
        ],
      );
    }

    // Default unanalyzed state: Show Analyze Button
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'No engine analysis yet',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
        if (onAnalyze != null)
          ElevatedButton.icon(
            onPressed: onAnalyze,
            icon: const Icon(Icons.bolt_rounded, size: 16),
            label: const Text('Analyze'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF36322C),
              foregroundColor: const Color(0xFF81B64C),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Color(0x3381B64C)),
              ),
              elevation: 0,
            ),
          ),
      ],
    );
  }
}
