import 'package:numberpick/features/game/domain/operation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A single persisted view of scores and game settings.
class ScoreSnapshot {
  const ScoreSnapshot({
    required this.correctByOperation,
    required this.incorrectByOperation,
    required this.equationCount,
    required this.squareCount,
    required this.operandMin,
    required this.operandMax,
    required this.useAddition,
    required this.useSubtraction,
    required this.useMultiplication,
    required this.useDivision,
    required this.mathType,
  });

  final Map<Operation, int> correctByOperation;
  final Map<Operation, int> incorrectByOperation;
  final int? equationCount;
  final int squareCount;
  final int? operandMin;
  final int? operandMax;
  final bool useAddition;
  final bool useSubtraction;
  final bool useMultiplication;
  final bool useDivision;
  final String mathType;
}

/// Reads and writes game state using stable `SharedPreferences` keys.
class ScoreStorage {
  static const String scoreCorrectPrefix = 'score.correct.';
  static const String scoreIncorrectPrefix = 'score.incorrect.';
  static const String equationCountKey = 'settings.equationCount';
  static const String squareCountKey = 'settings.squareCount';
  static const String operandMinKey = 'settings.operandMin';
  static const String operandMaxKey = 'settings.operandMax';
  static const String useAdditionKey = 'settings.useAddition';
  static const String useSubtractionKey = 'settings.useSubtraction';
  static const String useMultiplicationKey = 'settings.useMultiplication';
  static const String useDivisionKey = 'settings.useDivision';
  static const String mathTypeKey = 'settings.mathType';

  /// Loads all score categories and settings with first-run defaults.
  ///
  /// Every [Operation] receives a score entry, even when no value has yet been
  /// persisted, so callers can update the maps without checking for missing
  /// operation keys.
  Future<ScoreSnapshot> loadSnapshot() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final Map<Operation, int> correctByOperation = <Operation, int>{
      for (final Operation operation in Operation.values)
        operation: prefs.getInt('$scoreCorrectPrefix${operation.name}') ?? 0,
    };

    final Map<Operation, int> incorrectByOperation = <Operation, int>{
      for (final Operation operation in Operation.values)
        operation: prefs.getInt('$scoreIncorrectPrefix${operation.name}') ?? 0,
    };

    return ScoreSnapshot(
      correctByOperation: correctByOperation,
      incorrectByOperation: incorrectByOperation,
      equationCount: prefs.getInt(equationCountKey),
      squareCount: prefs.getInt(squareCountKey) ?? 3,
      operandMin: prefs.getInt(operandMinKey),
      operandMax: prefs.getInt(operandMaxKey),
      useAddition: prefs.getBool(useAdditionKey) ?? true,
      useSubtraction: prefs.getBool(useSubtractionKey) ?? false,
      useMultiplication: prefs.getBool(useMultiplicationKey) ?? false,
      useDivision: prefs.getBool(useDivisionKey) ?? false,
      mathType: prefs.getString(mathTypeKey) ?? 'Standard',
    );
  }

  /// Persists correct and incorrect totals for every operation.
  Future<void> persistScores({
    required Map<Operation, int> correctByOperation,
    required Map<Operation, int> incorrectByOperation,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    for (final Operation operation in Operation.values) {
      await prefs.setInt(
        '$scoreCorrectPrefix${operation.name}',
        correctByOperation[operation] ?? 0,
      );
      await prefs.setInt(
        '$scoreIncorrectPrefix${operation.name}',
        incorrectByOperation[operation] ?? 0,
      );
    }
  }

  Future<void> persistEquationCount(int equationCount) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(equationCountKey, equationCount);
  }

  Future<void> persistSquareCount(int squareCount) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(squareCountKey, squareCount);
  }

  Future<void> persistOperandRange(int operandMin, int operandMax) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(operandMinKey, operandMin);
    await prefs.setInt(operandMaxKey, operandMax);
  }

  Future<void> persistOperations({
    required bool useAddition,
    required bool useSubtraction,
    required bool useMultiplication,
    required bool useDivision,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(useAdditionKey, useAddition);
    await prefs.setBool(useSubtractionKey, useSubtraction);
    await prefs.setBool(useMultiplicationKey, useMultiplication);
    await prefs.setBool(useDivisionKey, useDivision);
  }

  Future<void> persistMathType(String mathType) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(mathTypeKey, mathType);
  }
}
