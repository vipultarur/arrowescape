import 'package:arrow_escape/data/level_generator/level_schedule.dart';
import 'package:arrow_escape/core/constants.dart';

void main() {
  final Map<String, List<int>> comboToLevels = {};
  final Map<String, List<int>> shapeToLevels = {};
  final Map<String, Set<int>> shapeToSizes = {};

  for (int i = 1; i <= 2000; i++) {
    final shape = LevelSchedule.shapeNameFor(i);
    final size = AppConstants.gridSizeForLevel(i);
    final key = '$shape@$size';

    comboToLevels.putIfAbsent(key, () => []).add(i);
    shapeToLevels.putIfAbsent(shape, () => []).add(i);
    shapeToSizes.putIfAbsent(shape, () => {}).add(size);
  }

  print('=== REPEATED (SHAPE, SIZE) COMBINATIONS ===');
  int duplicateComboCount = 0;
  int duplicateCountTotal = 0;
  comboToLevels.forEach((combo, levels) {
    if (levels.length > 1) {
      duplicateComboCount++;
      duplicateCountTotal += (levels.length - 1);
      print('$combo appears ${levels.length} times in levels: $levels');
    }
  });
  print('Total distinct (shape, size) combos that repeat: $duplicateComboCount');
  print('Total extra level instances with duplicate (shape, size): $duplicateCountTotal');

  print('\n=== SUMMARY OF MOST REPEATED SHAPES & SIZES ===');
  shapeToLevels.forEach((shape, levels) {
    final sizes = shapeToSizes[shape]!;
    if (levels.length > 1) {
      print('Shape "$shape": ${levels.length} levels, sizes: $sizes');
    }
  });
}
