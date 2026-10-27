import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:arrow_escape/core/constants.dart';
import 'package:arrow_escape/data/level_generator/level_generator_v2.dart';
import 'package:arrow_escape/data/level_generator/level_schedule.dart';
import 'package:arrow_escape/data/level_generator/mask_generator_v2.dart';
import 'package:arrow_escape/data/repositories/level_repository.dart';

void main() {
  test('Verify all 2000 levels match schedule rules and resolve valid shape masks', () {
    final rng = Random(42);

    expect(LevelRepository.totalLevels, 2000);
    expect(LevelSchedule.getEntry(2000).levelNumber, 2000);

    for (int lvl = 1; lvl <= 2000; lvl++) {
      final entry = LevelSchedule.getEntry(lvl);
      expect(entry.levelNumber, lvl);

      final levelType = LevelSchedule.levelTypeFor(lvl);
      final maskShape = LevelSchedule.maskShapeFor(lvl);

      // Verify Level Type matches AppConstants delegate
      expect(AppConstants.levelTypeFor(lvl), levelType);

      // Verify shape mask resolution
      final gridSize = AppConstants.gridSizeForLevel(lvl);
      final mask = MaskGeneratorV2.shapeByName(maskShape.name, gridSize, rng);
      expect(
        mask.isNotEmpty,
        true,
        reason: 'Mask for level $lvl (${maskShape.name}) must not be empty',
      );
    }
  });

  test('Verify level generation logic across milestone levels (1..2000)', () {
    // Test milestone checkpoints across the entire 2000 level range
    final sampleLevels = [
      1, 2, 3, 4, 5, 10, 20, 50, 100, 250, 500, 750, 1000, 1001, 1010, 1250, 1500, 1750, 2000
    ];

    for (final lvl in sampleLevels) {
      final levelModel = LevelGeneratorV2.generateLevel(lvl);
      expect(levelModel.levelNumber, lvl);
      expect(levelModel.arrows.isNotEmpty, true, reason: 'Level $lvl must have arrows');
      expect(levelModel.solutionOrder.isNotEmpty, true, reason: 'Level $lvl must have solution order');
      expect(levelModel.mask.isNotEmpty, true, reason: 'Level $lvl mask must not be empty');
    }
  });
}
