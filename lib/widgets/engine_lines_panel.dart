import 'package:flutter/material.dart';
import '../services/stockfish_engine.dart';

/// A sleek panel showing top candidate engine lines (MultiPV) above the move list,
/// styled identically to Chess.com and Lichess analysis panels.
class EngineLinesPanel extends StatefulWidget {
  final List<EngineLine> lines;
  final bool isLoading;
  final String? selectedLineUci;
  final ValueChanged<EngineLine>? onSelectLine;

  const EngineLinesPanel({
    super.key,
    required this.lines,
    this.isLoading = false,
    this.selectedLineUci,
    this.onSelectLine,
  });

  @override
  State<EngineLinesPanel> createState() => _EngineLinesPanelState();
}

class _EngineLinesPanelState extends State<EngineLinesPanel> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF211F1C),
        border: Border(
          bottom: BorderSide(color: Color(0xFF36322C), width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Bar
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.isLoading ? const Color(0xFFECC440) : const Color(0xFF81B64C),
                      boxShadow: [
                        BoxShadow(
                          color: (widget.isLoading ? const Color(0xFFECC440) : const Color(0xFF81B64C))
                              .withAlpha(120),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Stockfish Engine',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D2A26),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      widget.lines.isNotEmpty ? 'Depth ${widget.lines.first.depth}' : 'Top 3 Lines',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: Colors.white54,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),

          // Engine Lines Body
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: widget.isLoading && widget.lines.isEmpty
                  ? _buildLoadingSkeletons()
                  : widget.lines.isEmpty
                      ? _buildEmptyState()
                      : Column(
                          children: widget.lines.map((line) => _buildLineRow(line)).toList(),
                        ),
            ),
        ],
      ),
    );
  }

  Widget _buildLineRow(EngineLine line) {
    final isSelected = widget.selectedLineUci == line.bestMoveUci;
    final isWhiteAdvantage = (line.centipawns ?? 0) >= 0;
    final evalBgColor = line.isMate
        ? const Color(0xFFECC440).withAlpha(45)
        : (isWhiteAdvantage
            ? const Color(0xFF81B64C).withAlpha(40)
            : const Color(0xFFE05344).withAlpha(40));

    final evalTextColor = line.isMate
        ? const Color(0xFFECC440)
        : (isWhiteAdvantage ? const Color(0xFF9ECE6A) : const Color(0xFFFF7F70));

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF36322C) : const Color(0xFF1E1C18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isSelected ? const Color(0xFF81B64C) : const Color(0xFF2C2824),
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => widget.onSelectLine?.call(line),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                // Line Rank Badge (1, 2, 3)
                Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2723),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${line.multipv}',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Eval Score Pill
                Container(
                  constraints: const BoxConstraints(minWidth: 44),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: evalBgColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    line.scoreString,
                    style: TextStyle(
                      color: evalTextColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Best Move SAN Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2F2C27),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF3F3B35)),
                  ),
                  child: Text(
                    line.bestMoveSan,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Continuation PV Line
                Expanded(
                  child: Text(
                    line.formattedContinuation,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontFamily: 'RobotoMono',
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),

                // Preview indicator icon
                if (isSelected)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.navigation_rounded,
                      size: 14,
                      color: Color(0xFF81B64C),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingSkeletons() {
    return Column(
      children: List.generate(3, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1C18),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Container(
                width: 18,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(15),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 44,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(15),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 38,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(15),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(10),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      alignment: Alignment.center,
      child: const Text(
        'Evaluating lines...',
        style: TextStyle(
          color: Colors.white38,
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
