import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A sleek vertical evaluation bar displaying the engine advantage.
class EvalBar extends StatelessWidget {
  /// Centipawns from White's perspective (+ White ahead, - Black ahead).
  final int? centipawns;

  /// Moves to mate (+ White mating, - Black mating).
  final int? mateIn;

  /// Whether Black is displayed on the bottom (flipped board).
  final bool isFlipped;

  const EvalBar({
    super.key,
    this.centipawns,
    this.mateIn,
    this.isFlipped = false,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate White's fraction (0.0 = completely Black, 1.0 = completely White)
    double whiteFraction = 0.5;

    if (mateIn != null) {
      whiteFraction = mateIn! > 0 ? 1.0 : 0.0;
    } else if (centipawns != null) {
      // Sigmoid mapping: 0 cp -> 0.5, +300 cp -> ~0.8, -300 cp -> ~0.2
      final double exponent = -0.004 * centipawns!;
      whiteFraction = (1.0 / (1.0 + math.exp(exponent))).clamp(0.05, 0.95);
    }

    final double topFraction = isFlipped ? whiteFraction : (1.0 - whiteFraction);
    final String label = _formatEval();

    return Container(
      width: 24,
      decoration: BoxDecoration(
        color: const Color(0xFF262421),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF36322C), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              children: [
                // Top half
                Expanded(
                  flex: (topFraction * 1000).toInt().clamp(1, 999),
                  child: Container(
                    color: isFlipped ? Colors.white : const Color(0xFF1E1C18),
                  ),
                ),
                // Bottom half
                Expanded(
                  flex: ((1.0 - topFraction) * 1000).toInt().clamp(1, 999),
                  child: Container(
                    color: isFlipped ? const Color(0xFF1E1C18) : Colors.white,
                  ),
                ),
              ],
            ),
            // Centipawn / Mate Label
            RotatedBox(
              quarterTurns: 3,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: _labelColor(whiteFraction),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _labelColor(double whiteFraction) {
    // If predominantly white, contrast with dark, else contrast with white
    final isWhiteDominant = isFlipped ? (whiteFraction > 0.5) : (whiteFraction < 0.5);
    return isWhiteDominant ? Colors.black87 : Colors.white70;
  }

  String _formatEval() {
    if (mateIn != null) {
      return mateIn! > 0 ? 'M${mateIn!.abs()}' : '-M${mateIn!.abs()}';
    }
    if (centipawns == null) {
      return '0.0';
    }
    final score = centipawns! / 100.0;
    if (score == 0.0) return '0.0';
    return score > 0 ? '+${score.toStringAsFixed(1)}' : score.toStringAsFixed(1);
  }
}
