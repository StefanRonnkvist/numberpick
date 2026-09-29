import 'package:flutter/material.dart';

/// Presents game settings while delegating every state change to its parent.
class GameSettingsPanel extends StatelessWidget {
  const GameSettingsPanel({
    super.key,
    required this.operandRange,
    required this.numberCeiling,
    required this.operandMin,
    required this.operandMax,
    required this.resultMin,
    required this.resultMax,
    required this.squareCount,
    required this.minSquareCount,
    required this.maxSquareCount,
    required this.equationCount,
    required this.equationSliderMin,
    required this.equationSliderMax,
    required this.useAddition,
    required this.useSubtraction,
    required this.useMultiplication,
    required this.useDivision,
    required this.onOperandRangeChanged,
    required this.onSquareCountChanged,
    required this.onEquationCountChanged,
    required this.onAdditionChanged,
    required this.onSubtractionChanged,
    required this.onMultiplicationChanged,
    required this.onDivisionChanged,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.onResetScores,
    required this.mathType,
    required this.onMathTypeChanged,
  });

  final RangeValues operandRange;
  final int numberCeiling;
  final int operandMin;
  final int operandMax;
  final int resultMin;
  final int resultMax;
  final int squareCount;
  final int minSquareCount;
  final int maxSquareCount;
  final int equationCount;
  final int equationSliderMin;
  final int equationSliderMax;
  final bool useAddition;
  final bool useSubtraction;
  final bool useMultiplication;
  final bool useDivision;

  final ValueChanged<RangeValues> onOperandRangeChanged;
  final ValueChanged<double> onSquareCountChanged;
  final ValueChanged<double> onEquationCountChanged;
  final ValueChanged<bool?> onAdditionChanged;
  final ValueChanged<bool?> onSubtractionChanged;
  final ValueChanged<bool?> onMultiplicationChanged;
  final ValueChanged<bool?> onDivisionChanged;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final VoidCallback onResetScores;
  final String mathType;
  final ValueChanged<String> onMathTypeChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Minimum and Maximum Number',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          RangeSlider(
            values: operandRange,
            min: 0,
            max: numberCeiling.toDouble(),
            divisions: numberCeiling,
            labels: RangeLabels(operandMin.toString(), operandMax.toString()),
            onChanged: onOperandRangeChanged,
          ),
          Text(
            'Operands min: $operandMin   max: $operandMax',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 10),
          Text(
            'Results min: $resultMin   max: $resultMax',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 20),
          const Text(
            'Number of Squares to Display',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          Slider(
            value: squareCount.toDouble(),
            min: minSquareCount.toDouble(),
            max: maxSquareCount.toDouble(),
            divisions: maxSquareCount > minSquareCount
                ? maxSquareCount - minSquareCount
                : null,
            label: '$squareCount',
            onChanged: onSquareCountChanged,
          ),
          Text(
            'Squares displayed: $squareCount',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 20),
          const Text(
            'Number of Equations to Display',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          Slider(
            value: equationCount.toDouble(),
            min: equationSliderMin.toDouble(),
            max: equationSliderMax.toDouble(),
            divisions: equationSliderMax > equationSliderMin
                ? equationSliderMax - equationSliderMin
                : null,
            label: '$equationCount',
            onChanged: onEquationCountChanged,
          ),
          Text(
            'Displayed equations: $equationCount',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 20),
          const Text(
            'Operations',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: Colors.tealAccent,
            checkColor: Colors.black,
            value: useAddition,
            onChanged: onAdditionChanged,
            title: const Text(
              'Addition',
              style: TextStyle(color: Colors.white),
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: Colors.tealAccent,
            checkColor: Colors.black,
            value: useSubtraction,
            onChanged: onSubtractionChanged,
            title: const Text(
              'Subtraction',
              style: TextStyle(color: Colors.white),
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: Colors.tealAccent,
            checkColor: Colors.black,
            value: useMultiplication,
            onChanged: onMultiplicationChanged,
            title: const Text(
              'Multiplication',
              style: TextStyle(color: Colors.white),
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: Colors.tealAccent,
            checkColor: Colors.black,
            value: useDivision,
            onChanged: onDivisionChanged,
            title: const Text(
              'Division',
              style: TextStyle(color: Colors.white),
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: Colors.tealAccent,
            checkColor: Colors.black,
            value: mathType == 'Complex',
            onChanged: (bool? value) {
              if (value == true) {
                onMathTypeChanged('Complex');
              } else {
                onMathTypeChanged('Standard');
              }
            },
            title: const Text('Complex', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 20),
          const Text(
            'Mode',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<ThemeMode>(
            initialValue: themeMode,
            dropdownColor: const Color(0xFF252B38),
            decoration: const InputDecoration(
              filled: true,
              fillColor: Color(0xFF252B38),
              border: OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.tealAccent),
              ),
            ),
            style: const TextStyle(color: Colors.white),
            iconEnabledColor: Colors.white,
            items: const [
              DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
              DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
              DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
            ],
            onChanged: (ThemeMode? value) {
              if (value != null) {
                onThemeModeChanged(value);
              }
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onResetScores,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset Scores'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white30),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
