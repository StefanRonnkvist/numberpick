import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:numberpick/contact/contact_page.dart';
import 'package:numberpick/contact/submissions_csv_page.dart';
import 'package:numberpick/features/game/data/score_storage.dart';
import 'package:numberpick/features/game/domain/models.dart';
import 'package:numberpick/features/game/domain/operation.dart';
import 'package:numberpick/features/game/presentation/widgets/game_settings_panel.dart';
import 'package:numberpick/features/game/presentation/widgets/number_tiles_board.dart';
import 'package:numberpick/features/game/presentation/widgets/score_board.dart';

enum _EquationFeedback { correct, incorrect }

/// Selects either one-operation equations or grouped multi-operation equations.
enum GameMode { standard, complex }

class _SpeechBubbleTailPainter extends CustomPainter {
  _SpeechBubbleTailPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color;
    final Path path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SpeechBubbleTailPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// Builds shuffled, unique tile values that include each required answer.
///
/// When the requested range is too small, its upper bound is expanded enough
/// to fill [tileCount]. Callers must provide no more unique required answers
/// than the requested tile count.
List<int> buildUniqueTileValues({
  required int tileCount,
  required int minValue,
  required int maxValue,
  required List<int> requiredValues,
  required Random random,
}) {
  final Set<int> usedValues = <int>{};
  final List<int> values = <int>[];

  for (final int requiredValue in requiredValues) {
    if (!usedValues.contains(requiredValue)) {
      usedValues.add(requiredValue);
      values.add(requiredValue);
    }
  }

  final int neededValues = max(0, tileCount - values.length);
  final int expandedMaxValue = maxValue + max(0, neededValues);
  final List<int> candidates = List<int>.generate(
    expandedMaxValue - minValue + 1,
    (index) => minValue + index,
  )..shuffle(random);

  for (final int candidate in candidates) {
    if (values.length >= tileCount) {
      break;
    }

    if (usedValues.contains(candidate)) {
      continue;
    }

    usedValues.add(candidate);
    values.add(candidate);
  }

  if (values.length < tileCount) {
    for (int candidate = minValue; candidate <= expandedMaxValue; candidate++) {
      if (values.length >= tileCount) {
        break;
      }

      if (usedValues.contains(candidate)) {
        continue;
      }

      usedValues.add(candidate);
      values.add(candidate);
    }
  }

  values.shuffle(random);
  return values;
}

/// Coordinates problem generation, draggable answers, scoring, and settings.
class NumberPickPage extends StatefulWidget {
  const NumberPickPage({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<NumberPickPage> createState() => _NumberPickPageState();
}

String _operatorSymbol(Operation operation) {
  switch (operation) {
    case Operation.addition:
      return '+';
    case Operation.subtraction:
      return '-';
    case Operation.multiplication:
      return '*';
    case Operation.division:
      return '/';
    case Operation.complex:
      return '∘';
  }
}

/// Divides only when the divisor is non-zero and the result is an integer.
int? resolveWholeNumberDivision(int dividend, int divisor) {
  if (divisor == 0) {
    return null;
  }
  if (dividend % divisor != 0) {
    return null;
  }
  return dividend ~/ divisor;
}

/// Formats `(left op middle) outer (middle op right)` for complex problems.
String buildComplexMathExpression({
  required int leftValue,
  required int middleValue,
  required int rightValue,
  required Operation leftOperation,
  required Operation rightOperation,
  required Operation outerOperation,
}) {
  final String leftExpr = _formatComplexOperand(
    leftOperation,
    leftValue,
    middleValue,
  );
  final String rightExpr = _formatComplexOperand(
    rightOperation,
    middleValue,
    rightValue,
  );
  return '$leftExpr${_operatorSymbol(outerOperation)}$rightExpr';
}

/// Evaluates a standard operation, returning `null` for invalid division.
///
/// [Operation.complex] is assembled from multiple calls and is therefore not
/// directly evaluable by this helper.
int? evaluateOperation(Operation operation, int left, int right) {
  switch (operation) {
    case Operation.addition:
      return left + right;
    case Operation.subtraction:
      return left - right;
    case Operation.multiplication:
      return left * right;
    case Operation.division:
      return resolveWholeNumberDivision(left, right);
    case Operation.complex:
      return null;
  }
}

String _formatComplexOperand(
  Operation operation,
  int leftValue,
  int rightValue,
) {
  final String leftExpr = '$leftValue';
  final String rightExpr = '$rightValue';
  switch (operation) {
    case Operation.addition:
      return '($leftExpr+$rightExpr)';
    case Operation.subtraction:
      return '($leftExpr-$rightExpr)';
    case Operation.multiplication:
      return '($leftExpr*$rightExpr)';
    case Operation.division:
      return '($leftExpr/$rightExpr)';
    case Operation.complex:
      return '($leftExpr?$rightExpr)';
  }
}

class _NumberPickPageState extends State<NumberPickPage>
    with SingleTickerProviderStateMixin {
  static const int _gameTabIndex = 0;
  static const int _helpTabIndex = 2;
  static const int _problemCount = 12;
  static const int _minimumEquationDisplayCount = 1;
  static const int _defaultSquaresPerEquation = 3;
  static const int _maxNumberTileCount = 48;
  static const double _tileSize = 42.5;
  static const double _tileGap = 24;
  static const int _numberCeiling = 999;
  static const int _maxColumns = 6;
  static const Duration _answerBubbleDuration = Duration(seconds: 2);
  static final Uri _contactServerUri = Uri.parse(
    'https://stefanronnkvist.com/contact.php',
  );

  final Random _random = Random();
  final ScoreStorage _scoreStorage = ScoreStorage();
  late final TabController _tabController;
  GameMode _gameMode = GameMode.standard;
  String _mathType = 'Standard';

  RangeValues _operandRange = const RangeValues(0, 20);
  int _columnCount = 2;
  bool _didAutoSetDefaultColumns = false;
  int _numberTileCount = _defaultSquaresPerEquation;
  int _equationCount = _defaultSquaresPerEquation;
  int _equationSliderMax = _minimumEquationDisplayCount;
  bool _didAutoSetDefaultEquationCount = false;
  int? _savedEquationCount;

  bool _useAddition = true;
  bool _useSubtraction = false;
  bool _useMultiplication = false;
  bool _useDivision = false;

  final Map<Operation, int> _correctByOperation = <Operation, int>{
    for (final Operation op in Operation.values) op: 0,
  };
  final Map<Operation, int> _incorrectByOperation = <Operation, int>{
    for (final Operation op in Operation.values) op: 0,
  };
  final Map<int, _EquationFeedback> _equationFeedbackByProblemId =
      <int, _EquationFeedback>{};
  final Map<int, Timer> _feedbackTimersByProblemId = <int, Timer>{};
  final Set<int> _lockedTileIds = <int>{};
  OverlayEntry? _equationAnswerOverlay;
  Timer? _equationAnswerTimer;

  int _nextProblemId = 1;
  int _nextTileId = 1;

  late List<MathProblem> _mathProblems;
  late List<NumberTile> _numberTiles;

  int get _operandMin => _operandRange.start.round();
  int get _operandMax => _operandRange.end.round();
  int get _minimumSquareCount => _equationCount * 3;

  List<Operation> get _enabledOperations {
    final List<Operation> result = <Operation>[];
    if (_useAddition) {
      result.add(Operation.addition);
    }
    if (_useSubtraction) {
      result.add(Operation.subtraction);
    }
    if (_useMultiplication) {
      result.add(Operation.multiplication);
    }
    if (_useDivision) {
      result.add(Operation.division);
    }
    return result;
  }

  int get _resultMin {
    if (_mathProblems.isEmpty) {
      return _operandMin;
    }
    return _mathProblems.map((p) => p.result).reduce(min);
  }

  int get _resultMax {
    if (_mathProblems.isEmpty) {
      return _operandMax;
    }
    return _mathProblems.map((p) => p.result).reduce(max);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _rebuildAll();
    _loadScores();
  }

  @override
  void dispose() {
    _dismissEquationAnswerBubble();
    _clearAllFeedback();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() => setState(() {});

  /// Regenerates the problem set and all answer tiles after settings change.
  void _rebuildAll() {
    _clearAllFeedback();
    _mathProblems = List<MathProblem>.generate(
      _problemCount,
      (_) => _buildMathProblem(),
    );
    _rebuildNumberTiles();
  }

  /// Rebuilds tiles while ensuring every currently visible answer is present.
  void _rebuildNumberTiles() {
    final int minResult = _resultMin;
    final int maxResult = _resultMax;
    final int visibleEquationCount = min(_equationCount, _mathProblems.length);
    final List<int> requiredAnswers = _mathProblems
        .take(visibleEquationCount)
        .map((problem) => problem.result)
        .toList();
    final List<int> tileValues = buildUniqueTileValues(
      tileCount: _numberTileCount,
      minValue: minResult,
      maxValue: maxResult,
      requiredValues: requiredAnswers,
      random: _random,
    );

    _numberTiles = List<NumberTile>.generate(
      _numberTileCount,
      (index) => _buildNumberTile(
        index,
        minResult,
        maxResult,
        forcedValue: tileValues[index],
      ),
    );
  }

  void _clearAllFeedback() {
    for (final Timer timer in _feedbackTimersByProblemId.values) {
      timer.cancel();
    }
    _feedbackTimersByProblemId.clear();
    _equationFeedbackByProblemId.clear();
    _lockedTileIds.clear();
  }

  void _showEquationFeedback(
    int problemId,
    _EquationFeedback feedback, {
    required VoidCallback onElapsed,
  }) {
    // Only one expiry timer may own a problem's feedback at a time.
    _feedbackTimersByProblemId.remove(problemId)?.cancel();
    _equationFeedbackByProblemId[problemId] = feedback;
    _feedbackTimersByProblemId[problemId] = Timer(
      const Duration(seconds: 1),
      () {
        if (!mounted) {
          return;
        }

        setState(() {
          _feedbackTimersByProblemId.remove(problemId);
          _equationFeedbackByProblemId.remove(problemId);
          onElapsed();
        });
      },
    );
  }

  /// Maps an integer to a stable color so equal values look identical.
  Color _colorForValue(int value) {
    final int normalized = value.abs() % 512;
    final int redBand = normalized ~/ 64;
    final int greenBand = (normalized ~/ 8) % 8;
    final int blueBand = normalized % 8;

    return Color.fromARGB(
      255,
      10 + 20 * redBand,
      10 + 20 * greenBand,
      10 + 20 * blueBand,
    );
  }

  /// Chooses an initial column count once the board reports its actual width.
  ///
  /// The update is deferred because this callback is invoked during layout.
  void _setDefaultColumnsFromAvailableWidth(double width) {
    if (_didAutoSetDefaultColumns) {
      return;
    }

    const double horizontalPadding = 10;
    final double usableWidth = width - (horizontalPadding * 2);
    final int fitColumns = resolveColumnCount(
      availableWidth: usableWidth,
      tileSize: _tileSize,
      maxColumns: _maxColumns,
      horizontalPadding: 10,
    );

    _didAutoSetDefaultColumns = true;
    if (fitColumns == _columnCount) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _columnCount = fitColumns;
        _rebuildAll();
      });
    });
  }

  /// Keeps visible equations and the minimum tile count within height limits.
  ///
  /// A saved equation count is applied only on the first measured layout; later
  /// size changes clamp the active values without replacing user choices.
  void _syncEquationCountFromAvailableHeight(double height) {
    final int maxRowsByHeight = max(
      1,
      ((height + _tileSize) / (_tileSize + _tileGap)).floor(),
    );
    final int maxVisibleEquations = min(maxRowsByHeight, _mathProblems.length);
    final int minVisibleEquations = min(
      _minimumEquationDisplayCount,
      maxVisibleEquations,
    );

    if (_didAutoSetDefaultEquationCount &&
        _equationSliderMax == maxVisibleEquations &&
        _equationCount >= minVisibleEquations &&
        _equationCount <= maxVisibleEquations) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      setState(() {
        final int previousEquationCount = _equationCount;
        final int previousTileCount = _numberTileCount;
        _equationSliderMax = maxVisibleEquations;
        if (!_didAutoSetDefaultEquationCount) {
          final int preferredDefault =
              _savedEquationCount ?? _defaultSquaresPerEquation;
          _equationCount = preferredDefault.clamp(
            minVisibleEquations,
            maxVisibleEquations,
          );
          _didAutoSetDefaultEquationCount = true;
        } else if (_equationCount > maxVisibleEquations) {
          _equationCount = maxVisibleEquations;
        } else if (_equationCount < minVisibleEquations) {
          _equationCount = minVisibleEquations;
        }

        final int clampedSquareCount = _numberTileCount.clamp(
          _minimumSquareCount,
          _maxNumberTileCount,
        );
        if (clampedSquareCount != _numberTileCount) {
          _numberTileCount = clampedSquareCount;
        }

        if (previousEquationCount != _equationCount ||
            previousTileCount != _numberTileCount) {
          _rebuildAll();
        }
      });
    });
  }

  /// Generates a problem from the current mode, range, and enabled operations.
  MathProblem _buildMathProblem() {
    if (_gameMode == GameMode.complex) {
      return _buildComplexMathProblem();
    }

    final int minValue = _operandMin;
    final int maxValue = _operandMax;
    final List<Operation> operations = _enabledOperations;
    if (operations.isEmpty) {
      return _buildMathProblem();
    }

    final Operation selected = operations[_random.nextInt(operations.length)];

    switch (selected) {
      case Operation.addition:
        final int a = _randomIntInRange(minValue, maxValue);
        final int b = _randomIntInRange(minValue, maxValue);
        return MathProblem(
          id: _nextProblemId++,
          operation: Operation.addition,
          expression: '$a+$b',
          result: a + b,
        );
      case Operation.subtraction:
        final int a = _randomIntInRange(minValue, maxValue);
        final int b = _randomIntInRange(minValue, maxValue);
        final int left = max(a, b);
        final int right = min(a, b);
        return MathProblem(
          id: _nextProblemId++,
          operation: Operation.subtraction,
          expression: '$left-$right',
          result: left - right,
        );
      case Operation.multiplication:
        final int a = _randomIntInRange(minValue, maxValue);
        final int b = _randomIntInRange(minValue, maxValue);
        return MathProblem(
          id: _nextProblemId++,
          operation: Operation.multiplication,
          expression: '$a*$b',
          result: a * b,
        );
      case Operation.division:
        final int divisorMin = max(1, minValue);
        final int maxDivisor = max(divisorMin, maxValue);
        final List<int> divisors = <int>[];
        for (int candidate = divisorMin; candidate <= maxDivisor; candidate++) {
          if (candidate == 0) {
            continue;
          }
          divisors.add(candidate);
        }

        if (divisors.isEmpty) {
          return MathProblem(
            id: _nextProblemId++,
            operation: Operation.addition,
            expression: '$minValue+$maxValue',
            result: minValue + maxValue,
          );
        }

        final int divisor = divisors[_random.nextInt(divisors.length)];
        final int quotientMin = max(1, minValue);
        final int quotientMax = maxValue;
        final List<int> validQuotients = <int>[];
        for (int quotient = quotientMin; quotient <= quotientMax; quotient++) {
          final int? result = resolveWholeNumberDivision(
            quotient * divisor,
            divisor,
          );
          if (result != null && result == quotient) {
            validQuotients.add(quotient);
          }
        }

        if (validQuotients.isEmpty) {
          return MathProblem(
            id: _nextProblemId++,
            operation: Operation.addition,
            expression: '$minValue+$maxValue',
            result: minValue + maxValue,
          );
        }

        final int quotient =
            validQuotients[_random.nextInt(validQuotients.length)];
        final int dividend = divisor * quotient;
        return MathProblem(
          id: _nextProblemId++,
          operation: Operation.division,
          expression: '$dividend/$divisor',
          result: quotient,
        );
      case Operation.complex:
        return _buildComplexMathProblem();
    }
  }

  /// Tries bounded random combinations until every intermediate result is valid.
  MathProblem _buildComplexMathProblem() {
    final int minValue = _operandMin;
    final int maxValue = _operandMax;
    final List<Operation> operations = _enabledOperations;
    if (operations.isEmpty) {
      return _buildMathProblem();
    }

    for (int attempt = 0; attempt < 50; attempt++) {
      final Operation firstOp = operations[_random.nextInt(operations.length)];
      final Operation secondOp = operations[_random.nextInt(operations.length)];
      final Operation thirdOp = operations[_random.nextInt(operations.length)];

      final int a = _randomIntInRange(minValue, maxValue);
      final int b = _randomIntInRange(minValue, maxValue);
      final int c = _randomIntInRange(minValue, maxValue);

      final int? leftResult = _applyOperation(firstOp, a, b);
      final int? rightResult = _applyOperation(thirdOp, b, c);
      if (leftResult == null || rightResult == null) {
        continue;
      }

      final int? combinedResult = _applyOperation(
        secondOp,
        leftResult,
        rightResult,
      );

      if (!_isWholeNumberResult(firstOp, leftResult) ||
          !_isWholeNumberResult(thirdOp, rightResult) ||
          !_isWholeNumberResult(secondOp, combinedResult)) {
        continue;
      }

      if (combinedResult == null) {
        continue;
      }

      final String expression = buildComplexMathExpression(
        leftValue: a,
        middleValue: b,
        rightValue: c,
        leftOperation: firstOp,
        rightOperation: thirdOp,
        outerOperation: secondOp,
      );

      return MathProblem(
        id: _nextProblemId++,
        operation: Operation.complex,
        expression: expression,
        result: combinedResult,
      );
    }

    return _buildMathProblem();
  }

  bool _isWholeNumberResult(Operation operation, int? result) {
    if (result == null) {
      return false;
    }
    if (operation == Operation.division) {
      return result == result.toDouble().truncateToDouble();
    }
    return true;
  }

  int? _applyOperation(Operation operation, int left, int right) {
    return evaluateOperation(operation, left, right);
  }

  void _dismissEquationAnswerBubble() {
    _equationAnswerTimer?.cancel();
    _equationAnswerTimer = null;
    _equationAnswerOverlay?.remove();
    _equationAnswerOverlay = null;
  }

  /// Displays an answer near the tap point and removes it after a short delay.
  void _showEquationAnswerBubble(TapDownDetails details, MathProblem problem) {
    _dismissEquationAnswerBubble();

    final OverlayState overlay = Overlay.of(context);

    const TextStyle bubbleTextStyle = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w700,
      fontSize: 13,
    );
    const double bubbleMinWidth = 100;
    const double bubbleMaxWidth = 200;
    const double bubbleHeight = 34;
    const double tailHeight = 8;
    const double screenEdgePadding = 8;

    final String answerText = 'Answer: ${problem.result}';
    final TextPainter painter =
        TextPainter(
            text: const TextSpan(text: ''),
            textDirection: Directionality.of(context),
            maxLines: 1,
          )
          ..text = TextSpan(text: answerText, style: bubbleTextStyle)
          ..layout();

    final RenderBox overlayBox =
        overlay.context.findRenderObject()! as RenderBox;
    final Size overlaySize = overlayBox.size;
    final double bubbleWidth = (painter.width + 24).clamp(
      bubbleMinWidth,
      bubbleMaxWidth,
    );

    final double left = (details.globalPosition.dx - (bubbleWidth / 2)).clamp(
      screenEdgePadding,
      overlaySize.width - bubbleWidth - screenEdgePadding,
    );
    final double top =
        (details.globalPosition.dy - bubbleHeight - tailHeight - 10).clamp(
          screenEdgePadding,
          overlaySize.height - bubbleHeight - tailHeight - screenEdgePadding,
        );

    final OverlayEntry entry = OverlayEntry(
      builder: (_) => Positioned(
        left: left,
        top: top,
        child: IgnorePointer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                color: Colors.transparent,
                elevation: 6,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: bubbleHeight,
                  constraints: BoxConstraints(minWidth: bubbleWidth),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF252B38),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  alignment: Alignment.center,
                  child: Text(answerText, style: bubbleTextStyle),
                ),
              ),
              CustomPaint(
                size: const Size(14, tailHeight),
                painter: _SpeechBubbleTailPainter(
                  color: const Color(0xFF252B38),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    overlay.insert(entry);
    _equationAnswerOverlay = entry;
    _equationAnswerTimer = Timer(_answerBubbleDuration, () {
      if (!mounted) {
        return;
      }
      _dismissEquationAnswerBubble();
    });
  }

  NumberTile _buildNumberTile(
    int index,
    int minResult,
    int maxResult, {
    int? forcedValue,
  }) {
    final int column = index % _columnCount;
    final int row = index ~/ _columnCount;
    final int value = forcedValue ?? _randomIntInRange(minResult, maxResult);

    return NumberTile(
      id: _nextTileId++,
      value: value,
      column: column,
      row: row,
      color: _colorForValue(value),
    );
  }

  void _randomizeNumberTilePositions() {
    final List<NumberTile> oldTiles = List<NumberTile>.from(_numberTiles);
    final List<int> shuffledSlots = List<int>.generate(
      oldTiles.length,
      (index) => index,
    )..shuffle(_random);

    _numberTiles = List<NumberTile>.generate(oldTiles.length, (index) {
      final NumberTile tile = oldTiles[index];
      final int slot = shuffledSlots[index];
      return NumberTile(
        id: tile.id,
        value: tile.value,
        column: slot % _columnCount,
        row: slot ~/ _columnCount,
        color: tile.color,
      );
    });
  }

  /// Records a drop and replaces a correctly answered problem after feedback.
  ///
  /// Correct tiles are temporarily locked so repeated drops cannot score while
  /// the success indicator is visible. Incorrect problems remain unchanged.
  void _handleDrop(int problemId, int tileId, int droppedValue) {
    final int problemIndex = _mathProblems.indexWhere((p) => p.id == problemId);
    final int tileIndex = _numberTiles.indexWhere((t) => t.id == tileId);
    if (problemIndex == -1 ||
        tileIndex == -1 ||
        _equationFeedbackByProblemId.containsKey(problemId)) {
      return;
    }

    final MathProblem currentProblem = _mathProblems[problemIndex];
    final bool isCorrect = droppedValue == currentProblem.result;
    final Operation scoreOperation =
        currentProblem.operation == Operation.complex
        ? Operation.complex
        : currentProblem.operation;

    setState(() {
      if (isCorrect) {
        _correctByOperation[scoreOperation] =
            (_correctByOperation[scoreOperation] ?? 0) + 1;
      } else {
        _incorrectByOperation[scoreOperation] =
            (_incorrectByOperation[scoreOperation] ?? 0) + 1;
      }

      if (isCorrect) {
        _lockedTileIds.add(tileId);
      }

      _showEquationFeedback(
        problemId,
        isCorrect ? _EquationFeedback.correct : _EquationFeedback.incorrect,
        onElapsed: () {
          if (!isCorrect) {
            return;
          }

          final int nextProblemIndex = _mathProblems.indexWhere(
            (problem) => problem.id == problemId,
          );
          final int nextTileIndex = _numberTiles.indexWhere(
            (tile) => tile.id == tileId,
          );
          _lockedTileIds.remove(tileId);
          if (nextProblemIndex == -1 || nextTileIndex == -1) {
            return;
          }

          final MathProblem newProblem = _buildMathProblem();
          _mathProblems[nextProblemIndex] = newProblem;
          _rebuildNumberTiles();
          _randomizeNumberTilePositions();
        },
      );
    });

    _persistScores();
  }

  /// Restores persisted state and directs first-time players to the help tab.
  Future<void> _loadScores() async {
    final ScoreSnapshot snapshot = await _scoreStorage.loadSnapshot();
    if (!mounted) {
      return;
    }

    final bool shouldDefaultToHelp = _areAllScoresZero(snapshot);

    setState(() {
      for (final Operation operation in Operation.values) {
        _correctByOperation[operation] =
            snapshot.correctByOperation[operation] ?? 0;
        _incorrectByOperation[operation] =
            snapshot.incorrectByOperation[operation] ?? 0;
      }
      _savedEquationCount = snapshot.equationCount;
      _numberTileCount = snapshot.squareCount;
      if (snapshot.operandMin != null && snapshot.operandMax != null) {
        _operandRange = RangeValues(
          snapshot.operandMin!.toDouble(),
          snapshot.operandMax!.toDouble(),
        );
      }
      _useAddition = snapshot.useAddition;
      _useSubtraction = snapshot.useSubtraction;
      _useMultiplication = snapshot.useMultiplication;
      _useDivision = snapshot.useDivision;
      _mathType = snapshot.mathType;
      _rebuildAll();
    });

    if (shouldDefaultToHelp && _tabController.index == _gameTabIndex) {
      _tabController.index = _helpTabIndex;
    }
  }

  bool _areAllScoresZero(ScoreSnapshot snapshot) {
    final int totalCorrect = snapshot.correctByOperation.values.fold(
      0,
      (sum, value) => sum + value,
    );
    final int totalIncorrect = snapshot.incorrectByOperation.values.fold(
      0,
      (sum, value) => sum + value,
    );
    return totalCorrect == 0 && totalIncorrect == 0;
  }

  Future<void> _persistScores() async {
    await _scoreStorage.persistScores(
      correctByOperation: _correctByOperation,
      incorrectByOperation: _incorrectByOperation,
    );
  }

  Future<void> _persistEquationCount() async {
    await _scoreStorage.persistEquationCount(_equationCount);
  }

  Future<void> _persistSquareCount() async {
    await _scoreStorage.persistSquareCount(_numberTileCount);
  }

  Future<void> _persistSettings() async {
    await _scoreStorage.persistOperandRange(_operandMin, _operandMax);
    await _scoreStorage.persistOperations(
      useAddition: _useAddition,
      useSubtraction: _useSubtraction,
      useMultiplication: _useMultiplication,
      useDivision: _useDivision,
    );
    await _scoreStorage.persistMathType(_mathType);
  }

  Future<void> _resetScores() async {
    setState(() {
      for (final Operation operation in Operation.values) {
        _correctByOperation[operation] = 0;
        _incorrectByOperation[operation] = 0;
      }
    });

    await _persistScores();
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Scores reset.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _confirmAndResetScores() async {
    final bool? shouldReset = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Reset scores?'),
          content: const Text(
            'This will clear all correct and incorrect score values.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );

    if (shouldReset == true) {
      await _resetScores();
    }
  }

  int _randomIntInRange(int minValue, int maxValue) {
    if (maxValue <= minValue) {
      return minValue;
    }
    return minValue + _random.nextInt(maxValue - minValue + 1);
  }

  void _toggleOperation(
    bool currentValue,
    bool? nextValue,
    void Function(bool) assign,
  ) {
    final bool value = nextValue ?? false;

    if (currentValue && !value && _enabledOperations.length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least one operation must stay checked.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      assign(value);
      _rebuildAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1100) {
          return _buildDesktopLayout();
        } else if (constraints.maxWidth >= 600) {
          return _buildTabletLayout();
        }
        return _buildPhoneLayout();
      },
    );
  }

  // Phone layout: AppBar with TabBar + TabBarView
  Widget _buildPhoneLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFF101216),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1F29),
        foregroundColor: Colors.white,
        title: const Text('Number Pick'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Game', icon: Icon(Icons.sports_esports_outlined)),
            Tab(text: 'Setting', icon: Icon(Icons.settings_outlined)),
            Tab(text: 'Help', icon: Icon(Icons.help_outline)),
            Tab(text: 'Information', icon: Icon(Icons.info_outline)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGameContent(),
          _buildSettingsContent(),
          _buildHelpContent(),
          _buildInformationContent(),
        ],
      ),
    );
  }

  // Tablet layout: AppBar + NavigationRail + single content pane
  Widget _buildTabletLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFF101216),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1F29),
        foregroundColor: Colors.white,
        title: const Text('Number Pick'),
      ),
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: const Color(0xFF1A1F29),
            selectedIndex: _tabController.index,
            onDestinationSelected: (index) {
              setState(() {
                _tabController.index = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.sports_esports_outlined),
                label: Text('Game'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                label: Text('Setting'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.help_outline),
                label: Text('Help'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.info_outline),
                label: Text('Information'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1, color: Colors.white12),
          Expanded(child: _buildContentForTabIndex(_tabController.index)),
        ],
      ),
    );
  }

  // Desktop layout: AppBar + persistent settings sidebar + game panel
  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFF101216),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1F29),
        foregroundColor: Colors.white,
        title: const Text('Number Pick'),
      ),
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: const Color(0xFF1A1F29),
            selectedIndex: _tabController.index,
            onDestinationSelected: (index) {
              setState(() {
                _tabController.index = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.sports_esports_outlined),
                label: Text('Game'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                label: Text('Setting'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.help_outline),
                label: Text('Help'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.info_outline),
                label: Text('Information'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1, color: Colors.white12),
          Expanded(child: _buildContentForTabIndex(_tabController.index)),
        ],
      ),
    );
  }

  Widget _buildContentForTabIndex(int index) {
    if (index == 0) {
      return _buildGameContent();
    }

    if (index == 1) {
      return _buildSettingsContent();
    }

    if (index == 2) {
      return _buildHelpContent();
    }

    return _buildInformationContent();
  }

  Widget _buildHelpContent() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: _panel(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'How to play',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Solve each equation, then drag the matching number tile onto it. Number Pick gives immediate feedback and keeps the practice moving with fresh problems.',
                style: TextStyle(color: Colors.white70, height: 1.5),
              ),
              const SizedBox(height: 16),
              _buildHelpSection(
                title: 'Play a round',
                bullets: [
                  'Work out an equation, then drag its result tile from the number board onto the equation.',
                  'A correct drop turns green, adds to your correct score, and replaces the equation. An incorrect drop turns red, adds to your incorrect score, and leaves the equation in play.',
                  'Tap an equation to reveal its answer briefly. Revealing an answer does not change your score.',
                ],
              ),
              const SizedBox(height: 16),
              _buildHelpSection(
                title: 'Choose your challenge',
                bullets: [
                  'In the Setting tab, choose Addition, Subtraction, Multiplication, or Division. At least one operation always stays enabled.',
                  'Set the operand range and choose how many equations and number tiles appear. Available space may limit how many equations fit on screen.',
                  'Standard mode uses one operation per equation. Complex mode creates longer parenthesized expressions with whole-number results.',
                  'Choose System, Dark, or Light mode for the app appearance.',
                ],
              ),
              const SizedBox(height: 16),
              _buildHelpSection(
                title: 'Track your progress',
                bullets: [
                  'The score board shows correct, incorrect, total, accuracy, and grade results for each active operation.',
                  'Scores and game settings are stored locally on your device and restored when you return.',
                  'Reset Scores clears correct and incorrect counters after confirmation without changing your game settings.',
                ],
              ),
              const SizedBox(height: 16),
              _buildHelpSection(
                title: 'Contact and submissions',
                bullets: [
                  'The Information tab lets you send a question and review submissions associated with this app.',
                  'Sending a question includes the name, email, and message you enter, plus the displayed app version, package, platform, orientation, and layout details.',
                  'The game remains playable offline, but contact and submissions require an internet connection.',
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHelpSection({
    required String title,
    required List<String> bullets,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        ...bullets.map(
          (bullet) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(color: Colors.tealAccent)),
                Expanded(
                  child: Text(
                    bullet,
                    style: const TextStyle(color: Colors.white70, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInformationContent() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: _panel(
        padding: const EdgeInsets.all(16),
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              TabBar(
                tabs: const [
                  Tab(
                    text: 'Contact',
                    icon: Icon(Icons.contact_support_outlined),
                  ),
                  Tab(
                    text: 'Submissions',
                    icon: Icon(Icons.table_chart_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  children: [
                    ContactPage(
                      serverUri: _contactServerUri,
                      showAppBar: false,
                    ),
                    const SubmissionsCsvPage(showAppBar: false),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameContent() {
    _gameMode = _mathType == 'Complex' ? GameMode.complex : GameMode.standard;
    return _buildGameContentBody();
  }

  Widget _buildGameContentBody() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ScoreBoard(
            correctByOperation: _correctByOperation,
            incorrectByOperation: _incorrectByOperation,
            enabledOperations: _enabledOperations,
            showComplexScore: _gameMode == GameMode.complex,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double mathPanelWidth = _mathPanelWidth(
                  context,
                  constraints.maxWidth,
                );

                return Row(
                  children: [
                    SizedBox(
                      width: mathPanelWidth,
                      child: _panel(child: _buildMathDisplay()),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _panel(
                        backgroundColor: const Color(0xFFADADAD),
                        child: NumberTilesBoard(
                          numberTiles: _numberTiles,
                          columnCount: _columnCount,
                          lockedTileIds: _lockedTileIds,
                          tileSize: _tileSize,
                          onAvailableWidth:
                              _setDefaultColumnsFromAvailableWidth,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsContent() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: _panel(
        padding: const EdgeInsets.all(16),
        child: GameSettingsPanel(
          operandRange: _operandRange,
          numberCeiling: _numberCeiling,
          operandMin: _operandMin,
          operandMax: _operandMax,
          resultMin: _resultMin,
          resultMax: _resultMax,
          squareCount: _numberTileCount,
          minSquareCount: _minimumSquareCount,
          maxSquareCount: _maxNumberTileCount,
          equationCount: _equationCount,
          equationSliderMin: _minimumEquationDisplayCount,
          equationSliderMax: _equationSliderMax,
          useAddition: _useAddition,
          useSubtraction: _useSubtraction,
          useMultiplication: _useMultiplication,
          useDivision: _useDivision,
          onOperandRangeChanged: (RangeValues values) {
            setState(() {
              _operandRange = values;
              _rebuildAll();
            });
            _persistSettings();
          },
          onSquareCountChanged: (double value) {
            setState(() {
              _numberTileCount = value.round();
              _rebuildAll();
            });
            _persistSquareCount();
          },
          onEquationCountChanged: (double value) {
            setState(() {
              _equationCount = value.round();
              _numberTileCount = _numberTileCount.clamp(
                _minimumSquareCount,
                _maxNumberTileCount,
              );
              _savedEquationCount = _equationCount;
              _rebuildAll();
            });
            _persistEquationCount();
            _persistSettings();
          },
          onAdditionChanged: (bool? v) {
            _toggleOperation(_useAddition, v, (x) => _useAddition = x);
            _persistSettings();
          },
          onSubtractionChanged: (bool? v) {
            _toggleOperation(_useSubtraction, v, (x) => _useSubtraction = x);
            _persistSettings();
          },
          onMultiplicationChanged: (bool? v) {
            _toggleOperation(
              _useMultiplication,
              v,
              (x) => _useMultiplication = x,
            );
            _persistSettings();
          },
          onDivisionChanged: (bool? v) {
            _toggleOperation(_useDivision, v, (x) => _useDivision = x);
            _persistSettings();
          },
          themeMode: widget.themeMode,
          onThemeModeChanged: widget.onThemeModeChanged,
          onResetScores: _confirmAndResetScores,
          mathType: _mathType,
          onMathTypeChanged: (String value) {
            setState(() {
              _mathType = value;
              if (value == 'Complex') {
                _useAddition = true;
                _useSubtraction = true;
                _useMultiplication = true;
                _useDivision = true;
              }
              _rebuildAll();
            });
            _persistSettings();
          },
        ),
      ),
    );
  }

  Widget _panel({
    required Widget child,
    EdgeInsetsGeometry? padding,
    Color backgroundColor = const Color(0xFF1A1F29),
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.zero,
        child: ClipRRect(borderRadius: BorderRadius.circular(16), child: child),
      ),
    );
  }

  double _mathPanelWidth(BuildContext context, double availableWidth) {
    const TextStyle textStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
    );
    const double horizontalInset = 10 + 4 + 4 + 10;

    final String longestExpression = _mathProblems
        .map((p) => p.expression)
        .fold<String>('', (a, b) => a.length >= b.length ? a : b);

    final TextPainter painter = TextPainter(
      text: TextSpan(text: longestExpression, style: textStyle),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout();

    final double desiredWidth = painter.width + horizontalInset;
    final double maxWidthForLayout = max(90.0, availableWidth * 0.4);
    return desiredWidth.clamp(90.0, min(280.0, maxWidthForLayout));
  }

  Widget _buildMathDisplay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final int maxRows = max(
          1,
          ((constraints.maxHeight + _tileSize) / (_tileSize + _tileGap))
              .floor(),
        );
        _syncEquationCountFromAvailableHeight(constraints.maxHeight);

        final int currentMaxVisible = min(maxRows, _mathProblems.length);
        final int itemCount = min(_equationCount, currentMaxVisible);

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: itemCount,
          separatorBuilder: (_, _) => const SizedBox(height: _tileGap),
          itemBuilder: (context, index) {
            final MathProblem problem = _mathProblems[index];
            final Color tileColor = _colorForValue(problem.result);

            return SizedBox(
              height: _tileSize,
              child: DragTarget<DraggedNumber>(
                onWillAcceptWithDetails: (details) {
                  if (_equationFeedbackByProblemId.containsKey(problem.id)) {
                    return false;
                  }
                  return true;
                },
                onAcceptWithDetails: (details) {
                  _handleDrop(
                    problem.id,
                    details.data.tileId,
                    details.data.value,
                  );
                },
                builder: (context, candidateData, rejectedData) {
                  final _EquationFeedback? feedback =
                      _equationFeedbackByProblemId[problem.id];
                  final Color backgroundColor = candidateData.isNotEmpty
                      ? Colors.amber.shade700
                      : feedback == _EquationFeedback.correct
                      ? Colors.green.shade700
                      : feedback == _EquationFeedback.incorrect
                      ? Colors.red.shade700
                      : tileColor;
                  final Color textColor =
                      backgroundColor.computeLuminance() > 0.55
                      ? Colors.black
                      : Colors.white;

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      _showEquationAnswerBubble(details, problem);
                    },
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              problem.expression,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.visible,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
