import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/move_analysis.dart';

/// An interactive, custom-painted evaluation momentum graph.
///
/// Plots evaluation swings across the game, highlights critical blunders and brilliancies,
/// and allows smooth scrubbing by dragging or tapping along the chart.
class AdvantageGraph extends StatefulWidget {
  final List<MoveAnalysis> moves;
  final int selectedPlyIndex;
  final ValueChanged<int> onSelectPly;
  final bool isFlipped;

  const AdvantageGraph({
    super.key,
    required this.moves,
    required this.selectedPlyIndex,
    required this.onSelectPly,
    this.isFlipped = false,
  });

  @override
  State<AdvantageGraph> createState() => _AdvantageGraphState();
}

class _AdvantageGraphState extends State<AdvantageGraph> {
  bool _isDragging = false;

  void _handleTouch(double dx, double width) {
    if (widget.moves.isEmpty || width <= 0) return;
    final total = widget.moves.length;
    final fraction = (dx / width).clamp(0.0, 1.0);
    final targetIndex = (fraction * (total - 1)).round().clamp(-1, total - 1);
    widget.onSelectPly(targetIndex);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.moves.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 90,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1C18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF36322C), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) {
                _handleTouch(details.localPosition.dx, width);
              },
              onHorizontalDragStart: (_) {
                setState(() => _isDragging = true);
              },
              onHorizontalDragUpdate: (details) {
                _handleTouch(details.localPosition.dx, width);
              },
              onHorizontalDragEnd: (_) {
                setState(() => _isDragging = false);
              },
              child: Stack(
                children: [
                  // 1. Custom painted area chart
                  CustomPaint(
                    size: Size(width, height),
                    painter: _AdvantageChartPainter(
                      moves: widget.moves,
                      isFlipped: widget.isFlipped,
                    ),
                  ),

                  // 2. Vertical scrubber indicator needle
                  if (widget.selectedPlyIndex >= 0 && widget.selectedPlyIndex < widget.moves.length)
                    _buildScrubber(width, height),

                  // 3. Header badge overlay
                  Positioned(
                    top: 6,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0x99000000),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.show_chart_rounded, size: 12, color: Color(0xFF81B64C)),
                          SizedBox(width: 4),
                          Text(
                            'Advantage Momentum',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildScrubber(double width, double height) {
    final total = widget.moves.length;
    final double x = total > 1
        ? (widget.selectedPlyIndex / (total - 1)) * width
        : width / 2;

    final move = widget.moves[widget.selectedPlyIndex];
    final String evalLabel = _formatEval(move.scoreAfter, move.mateAfter);

    return Positioned(
      left: (x - 1).clamp(0.0, width - 2),
      top: 0,
      bottom: 0,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Vertical needle line
          Container(
            width: _isDragging ? 2.5 : 2.0,
            height: height,
            color: _isDragging ? Colors.white : Colors.white.withAlpha(220),
          ),

          // Glowing dot on needle
          Positioned(
            top: height / 2 - (_isDragging ? 5 : 4),
            child: Container(
              width: _isDragging ? 10 : 8,
              height: _isDragging ? 10 : 8,
              decoration: BoxDecoration(
                color: move.classification.color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: move.classification.color.withAlpha(_isDragging ? 220 : 150),
                    blurRadius: _isDragging ? 9 : 6,
                    spreadRadius: _isDragging ? 3 : 2,
                  ),
                ],
              ),
            ),
          ),

          // Tooltip badge above needle
          Positioned(
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xE6262421),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white30, width: 0.5),
              ),
              child: Text(
                '${move.moveNumber}${move.isWhite ? "." : "..."} ($evalLabel)',
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatEval(int? cp, int? mate) {
    if (mate != null) return mate > 0 ? '+M$mate' : '-M${mate.abs()}';
    if (cp == null) return '0.0';
    final s = cp / 100.0;
    return s >= 0 ? '+${s.toStringAsFixed(1)}' : s.toStringAsFixed(1);
  }
}

class _AdvantageChartPainter extends CustomPainter {
  final List<MoveAnalysis> moves;
  final bool isFlipped;

  _AdvantageChartPainter({
    required this.moves,
    required this.isFlipped,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (moves.isEmpty) return;

    final centerY = size.height / 2;
    final total = moves.length;
    final dx = total > 1 ? size.width / (total - 1) : size.width;

    // 1. Draw horizontal parity baseline (0.0 eval)
    final baseLinePaint = Paint()
      ..color = const Color(0xFF36322C)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), baseLinePaint);

    // 2. Compute points for each ply
    final List<Offset> points = [];

    for (int i = 0; i < total; i++) {
      final m = moves[i];
      final double normalized = _normalizeEval(m.scoreAfter, m.mateAfter);
      // Normalized: -1.0 (Black crushing) to +1.0 (White crushing)
      final effectiveNorm = isFlipped ? -normalized : normalized;

      // Map to Y: +1.0 -> top (margin 10), -1.0 -> bottom (margin 10)
      final y = centerY - (effectiveNorm * (centerY - 10));
      final x = i * dx;
      points.add(Offset(x, y));
    }

    // 3. Draw gradient filled areas
    final fillWhitePath = Path()..moveTo(0, centerY);
    final fillBlackPath = Path()..moveTo(0, centerY);

    for (final pt in points) {
      if (pt.dy < centerY) {
        fillWhitePath.lineTo(pt.dx, pt.dy);
        fillBlackPath.lineTo(pt.dx, centerY);
      } else {
        fillWhitePath.lineTo(pt.dx, centerY);
        fillBlackPath.lineTo(pt.dx, pt.dy);
      }
    }

    fillWhitePath.lineTo(size.width, centerY);
    fillWhitePath.close();

    fillBlackPath.lineTo(size.width, centerY);
    fillBlackPath.close();

    // White advantage fill (Green)
    final whiteShader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF81B64C).withAlpha(120),
        const Color(0xFF81B64C).withAlpha(10),
      ],
    ).createShader(Rect.fromLTWH(0, 0, size.width, centerY));

    canvas.drawPath(fillWhitePath, Paint()..shader = whiteShader);

    // Black advantage fill (Coral / Slate Red)
    final blackShader = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [
        const Color(0xFFE05344).withAlpha(120),
        const Color(0xFFE05344).withAlpha(10),
      ],
    ).createShader(Rect.fromLTWH(0, centerY, size.width, centerY));

    canvas.drawPath(fillBlackPath, Paint()..shader = blackShader);

    // 4. Draw advantage line
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final midX = (prev.dx + curr.dx) / 2;
      linePath.cubicTo(midX, prev.dy, midX, curr.dy, curr.dx, curr.dy);
    }

    final linePaint = Paint()
      ..color = Colors.white.withAlpha(180)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawPath(linePath, linePaint);

    // 5. Draw key moment badges on the curve (Blunder, Mistake, Brilliant)
    for (int i = 0; i < moves.length; i++) {
      final cat = moves[i].classification;
      if (cat == MoveClassification.blunder ||
          cat == MoveClassification.mistake ||
          cat == MoveClassification.brilliant) {
        final pt = points[i];
        final badgePaint = Paint()
          ..color = cat.color
          ..style = PaintingStyle.fill;

        canvas.drawCircle(pt, 3.5, badgePaint);
        canvas.drawCircle(
          pt,
          3.5,
          Paint()
            ..color = Colors.white
            ..strokeWidth = 1
            ..style = PaintingStyle.stroke,
        );
      }
    }
  }

  /// Normalizes evaluation into [-1.0, 1.0] range using smooth sigmoid curve.
  static double _normalizeEval(int? cp, int? mate) {
    if (mate != null) {
      return mate > 0 ? 1.0 : -1.0;
    }
    if (cp == null) return 0.0;
    // 0 cp -> 0.0, +300 cp -> ~0.7, +600 cp -> ~0.9
    final double exponent = -0.004 * cp;
    final double prob = 1.0 / (1.0 + math.exp(exponent)); // 0.0 to 1.0
    return (prob - 0.5) * 2.0; // -1.0 to 1.0
  }

  @override
  bool shouldRepaint(covariant _AdvantageChartPainter oldDelegate) {
    return oldDelegate.moves != moves || oldDelegate.isFlipped != isFlipped;
  }
}
