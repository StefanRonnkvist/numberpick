import 'package:flutter/material.dart';
import 'package:numberpick/features/game/domain/operation.dart';

/// An equation shown to the player and its expected integer answer.
class MathProblem {
  const MathProblem({
    required this.id,
    required this.operation,
    required this.expression,
    required this.result,
  });

  final int id;
  final Operation operation;
  final String expression;
  final int result;
}

/// An immutable number tile and its logical position on the game board.
class NumberTile {
  const NumberTile({
    required this.id,
    required this.value,
    required this.column,
    required this.row,
    required this.color,
  });

  final int id;
  final int value;
  final int column;
  final int row;
  final Color color;
}

/// The minimal tile data transferred by Flutter's drag-and-drop system.
class DraggedNumber {
  const DraggedNumber({required this.tileId, required this.value});

  final int tileId;
  final int value;
}
