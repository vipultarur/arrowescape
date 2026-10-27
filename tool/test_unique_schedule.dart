import 'dart:math';
import 'package:arrow_escape/data/models/level.dart';
import 'package:arrow_escape/data/level_generator/level_schedule.dart';
import 'package:arrow_escape/data/level_generator/mask_generator_v2.dart';
import 'package:arrow_escape/core/constants.dart';

void main() {
  final Map<int, String> finalShapes = {};
  final Map<int, int> finalSizes = {};
  final Set<String> usedCombos = {};

  // Available shape names by category from MaskGeneratorV2 & MaskShape
  final List<String> allShapeNames = MaskShape.values.map((e) => e.name).toList();

  int sizeAdjustments = 0;
  int shapeSwaps = 0;

  for (int i = 1; i <= 2000; i++) {
    final entry = LevelSchedule.getEntry(i);
    final baseShape = entry.shapeName;
    final baseSize = AppConstants.gridSizeForLevel(i);

    String chosenShape = baseShape;
    int chosenSize = baseSize;

    String key = '$chosenShape@$chosenSize';

    if (usedCombos.contains(key)) {
      // 1. Try adjusting size ±1, ±2, ±3 ... up to ±10
      bool foundSize = false;
      final sizeOffsets = <int>[];
      for (int offset = 1; offset <= 15; offset++) {
        sizeOffsets.add(offset);
        sizeOffsets.add(-offset);
      }

      for (final offset in sizeOffsets) {
        final candidateSize = (baseSize + offset).clamp(10, 50);
        final candidateKey = '$baseShape@$candidateSize';
        if (!usedCombos.contains(candidateKey)) {
          chosenSize = candidateSize;
          chosenShape = baseShape;
          key = candidateKey;
          foundSize = true;
          sizeAdjustments++;
          break;
        }
      }

      // 2. If no size offset works for baseShape, try alternative shapes near baseSize
      if (!foundSize) {
        bool foundShape = false;
        // Prioritize shapes of similar theme
        for (final candidateShape in allShapeNames) {
          for (int offset = 0; offset <= 15; offset++) {
            final candidateSize1 = (baseSize + offset).clamp(10, 50);
            final candidateKey1 = '$candidateShape@$candidateSize1';
            if (!usedCombos.contains(candidateKey1)) {
              chosenShape = candidateShape;
              chosenSize = candidateSize1;
              key = candidateKey1;
              foundShape = true;
              shapeSwaps++;
              break;
            }
            if (offset > 0) {
              final candidateSize2 = (baseSize - offset).clamp(10, 50);
              final candidateKey2 = '$candidateShape@$candidateSize2';
              if (!usedCombos.contains(candidateKey2)) {
                chosenShape = candidateShape;
                chosenSize = candidateSize2;
                key = candidateKey2;
                foundShape = true;
                shapeSwaps++;
                break;
              }
            }
          }
          if (foundShape) break;
        }
      }
    }

    usedCombos.add(key);
    finalShapes[i] = chosenShape;
    finalSizes[i] = chosenSize;
  }

  print('=== ALGORITHM RESULTS ===');
  print('Total levels processed: ${finalShapes.length}');
  print('Unique (shape, size) combos: ${usedCombos.length} / 2000');
  print('Collisions: ${2000 - usedCombos.length}');
  print('Size adjustments made: $sizeAdjustments');
  print('Shape swaps made: $shapeSwaps');

  // Verify first 20 levels
  print('\nFirst 20 levels:');
  for (int i = 1; i <= 20; i++) {
    print('Level $i: shape=${finalShapes[i]}, size=${finalSizes[i]}');
  }
}
