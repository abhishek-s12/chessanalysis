import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A sleek, animated vertical evaluation bar displaying engine advantage,
/// matching Chess.com and Lichess visual aesthetics and interactive capabilities.
class EvalBar extends StatefulWidget {
  /// Centipawns from White's perspective (+ White ahead, - Black ahead).
  final int? centipawns;

  /// Moves to mate (+ White mating, - Black mating).
  final int? mateIn;

  /// Whether Black is displayed on the bottom (flipped board).
  final bool isFlipped;

  /// Animation duration when evaluation changes.
  final Duration animationDuration;

  const EvalBar({
    super.key,
    this.centipawns,
    this.mateIn,
    this.isFlipped = false,
    this.animationDuration = const Duration(milliseconds: 350),
  });

  /// Computes the exact winning probability percentage (0 to 100)
  /// using the official Chess.com / Lichess logistic formula.
  static double calculateWinProbability({int? centipawns, int? mateIn}) {
    if (mateIn != null) {
      return mateIn > 0 ? 100.0 : 0.0;
    }
    if (centipawns == null) return 50.0;
    // Logistic curve: 0 cp -> 50%, +300 cp -> ~75%, +1000 cp -> ~97%
    return 100.0 / (1.0 + math.exp(-0.00368208 * centipawns));
  }

  @override
  State<EvalBar> createState() => _EvalBarState();
}

class _EvalBarState extends State<EvalBar> {
  bool _showWinPercentage = false;

  void _toggleDisplayMode() {
    setState(() {
      _showWinPercentage = !_showWinPercentage;
    });
  }

  @override
  Widget build(BuildContext context) {
    final winProb = EvalBar.calculateWinProbability(
      centipawns: widget.centipawns,
      mateIn: widget.mateIn,
    );

    // Calculate White's target fraction (0.0 to 1.0) clamped to keep small bar edge visible
    double targetWhiteFraction = 0.5;
    if (widget.mateIn != null) {
      targetWhiteFraction = widget.mateIn! > 0 ? 0.98 : 0.02;
    } else if (widget.centipawns != null) {
      targetWhiteFraction = (winProb / 100.0).clamp(0.04, 0.96);
    }

    // Top fraction accounts for board flipping
    final double targetTopFraction =
        widget.isFlipped ? targetWhiteFraction : (1.0 - targetWhiteFraction);

    return Tooltip(
      message: _showWinPercentage
          ? 'Showing Win Probability. Tap to show Eval score.'
          : 'Showing Eval Score. Tap to show Win Probability.',
      child: GestureDetector(
        onTap: _toggleDisplayMode,
        child: Container(
          width: 26,
          decoration: BoxDecoration(
            color: const Color(0xFF262421),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: const Color(0xFF36322C), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(80),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: targetTopFraction),
              duration: widget.animationDuration,
              curve: Curves.easeInOutCubic,
              builder: (context, animatedTopFraction, _) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // The animated vertical dual-colored bar
                    Column(
                      children: [
                        // Top Section (Black when not flipped, White when flipped)
                        Expanded(
                          flex: (animatedTopFraction * 1000).toInt().clamp(1, 999),
                          child: Container(
                            decoration: BoxDecoration(
                              color: widget.isFlipped
                                  ? const Color(0xFFFFFFFF)
                                  : const Color(0xFF1E1C18),
                            ),
                          ),
                        ),
                        // Dividing hairline indicator
                        Container(
                          height: 1.5,
                          color: const Color(0xFF5C5549),
                        ),
                        // Bottom Section (White when not flipped, Black when flipped)
                        Expanded(
                          flex: ((1.0 - animatedTopFraction) * 1000).toInt().clamp(1, 999),
                          child: Container(
                            decoration: BoxDecoration(
                              color: widget.isFlipped
                                  ? const Color(0xFF1E1C18)
                                  : const Color(0xFFFFFFFF),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Evaluation or Win % Text Label
                    _buildLabel(targetWhiteFraction, winProb),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(double whiteFraction, double winProb) {
    final String labelText = _getLabelText(winProb);

    // Determine contrast color based on the dominant area
    // White dominant if fraction > 0.5
    final bool isWhiteDominant =
        widget.isFlipped ? (whiteFraction > 0.5) : (whiteFraction < 0.5);

    final Color textColor =
        isWhiteDominant ? const Color(0xFF161512) : const Color(0xFFF1F1F1);

    return RotatedBox(
      quarterTurns: 3,
      child: Text(
        labelText,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
          color: textColor,
          shadows: [
            Shadow(
              color: isWhiteDominant
                  ? Colors.white.withAlpha(120)
                  : Colors.black.withAlpha(150),
              blurRadius: 2,
            ),
          ],
        ),
      ),
    );
  }

  String _getLabelText(double winProb) {
    if (_showWinPercentage) {
      return '${winProb.round()}%';
    }

    if (widget.mateIn != null) {
      final mate = widget.mateIn!;
      return mate > 0 ? 'M$mate' : '-M${mate.abs()}';
    }

    if (widget.centipawns == null) {
      return '0.0';
    }

    final score = widget.centipawns! / 100.0;
    if (score == 0.0) return '0.0';
    return score > 0 ? '+${score.toStringAsFixed(1)}' : score.toStringAsFixed(1);
  }
}

