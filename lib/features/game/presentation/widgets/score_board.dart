import 'dart:math';

import 'package:flutter/material.dart';
import 'package:numberpick/features/game/domain/operation.dart';

/// Horizontal arrangement selected for the operation score cards.
enum ScoreBoardLayoutMode { evenlySpaced, horizontalScroll }

/// Chooses equal-width cards when they fit, otherwise a scrollable row.
ScoreBoardLayoutMode resolveScoreBoardLayout({
  required double availableWidth,
  required int cardCount,
  double minCardWidth = 220,
  double gap = 12,
}) {
  if (cardCount <= 0) {
    return ScoreBoardLayoutMode.evenlySpaced;
  }

  final double requiredWidth =
      (cardCount * minCardWidth) + (max(0, cardCount - 1) * gap);
  return availableWidth >= requiredWidth
      ? ScoreBoardLayoutMode.evenlySpaced
      : ScoreBoardLayoutMode.horizontalScroll;
}

/// Shows correct, incorrect, percentage, and grade totals by operation.
class ScoreBoard extends StatelessWidget {
  const ScoreBoard({
    super.key,
    required this.correctByOperation,
    required this.incorrectByOperation,
    required this.enabledOperations,
    this.showComplexScore = false,
  });

  final Map<Operation, int> correctByOperation;
  final Map<Operation, int> incorrectByOperation;
  final List<Operation> enabledOperations;
  final bool showComplexScore;

  @override
  Widget build(BuildContext context) {
    final List<Operation> ops = <Operation>[];
    // An empty filter means "show every standard operation", not "show none".
    if (enabledOperations.isEmpty) {
      ops.addAll(
        Operation.values.where((operation) => operation != Operation.complex),
      );
    } else {
      ops.addAll(enabledOperations);
    }

    if (showComplexScore && !ops.contains(Operation.complex)) {
      ops.add(Operation.complex);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final ScoreBoardLayoutMode layoutMode = resolveScoreBoardLayout(
          availableWidth: constraints.maxWidth,
          cardCount: ops.length,
        );

        final Widget content =
            layoutMode == ScoreBoardLayoutMode.horizontalScroll
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (int i = 0; i < ops.length; i++) ...[
                      SizedBox(
                        width: 220,
                        child: _ScoreCard(
                          operation: ops[i],
                          correct: correctByOperation[ops[i]] ?? 0,
                          incorrect: incorrectByOperation[ops[i]] ?? 0,
                        ),
                      ),
                      if (i < ops.length - 1) const SizedBox(width: 12),
                    ],
                  ],
                ),
              )
            : Row(
                children: [
                  for (int i = 0; i < ops.length; i++) ...[
                    Expanded(
                      child: _ScoreCard(
                        operation: ops[i],
                        correct: correctByOperation[ops[i]] ?? 0,
                        incorrect: incorrectByOperation[ops[i]] ?? 0,
                      ),
                    ),
                    if (i < ops.length - 1) const SizedBox(width: 12),
                  ],
                ],
              );

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F29),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: content,
        );
      },
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.operation,
    required this.correct,
    required this.incorrect,
  });

  final Operation operation;
  final int correct;
  final int incorrect;

  String _operationLabel(Operation operation) {
    switch (operation) {
      case Operation.addition:
        return 'Addition';
      case Operation.subtraction:
        return 'Subtraction';
      case Operation.multiplication:
        return 'Multiplication';
      case Operation.division:
        return 'Division';
      case Operation.complex:
        return 'Complex';
    }
  }

  String _gradeForPercent(double percentCorrect) {
    if (percentCorrect >= 90) {
      return 'A';
    }
    if (percentCorrect >= 80) {
      return 'B';
    }
    if (percentCorrect >= 70) {
      return 'C';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final int total = correct + incorrect;
    final double percentCorrect = total == 0 ? 0 : (correct / total) * 100;
    final String grade = _gradeForPercent(percentCorrect);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF252B38),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _operationLabel(operation),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Correct: $correct',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    Text(
                      'Incorrect: $incorrect',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    Text(
                      'Total: $total',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                fit: FlexFit.loose,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              percentCorrect.toStringAsFixed(0),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                            ),
                            Text(
                              '%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          grade,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
