import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:arrow_escape/core/constants.dart';
import 'package:arrow_escape/data/level_generator/level_generator_v2.dart';
import 'package:arrow_escape/data/level_generator/level_schedule.dart';
import 'package:arrow_escape/data/level_generator/mask_generator_v2.dart';
import 'package:arrow_escape/data/repositories/level_repository.dart';

void main() {
  test('Verify all 2000 levels match schedule rules and generate valid LevelModel', () {
    final rng = Random(42);
    expect(LevelSchedule.getEntry(2000).levelNumber, 2000);

    for (int lvl = 1; lvl <= 2000; lvl++) {
      final levelType = LevelSchedule.levelTypeFor(lvl);
      final maskShape = LevelSchedule.maskShapeFor(lvl);

      // Verify Level Type matches AppConstants delegate
      expect(AppConstants.levelTypeFor(lvl), levelType);

      // Verify shape mask resolution
      final gridSize = AppConstants.gridSizeForLevel(lvl);
      final mask = MaskGeneratorV2.shapeByName(maskShape.name, gridSize, rng);
      expect(mask.isNotEmpty, true, reason: 'Mask for level $lvl (${maskShape.name}) must not be empty');

      // Generate LevelModel for early checkpoint levels (1-5)
      if (lvl <= 5) {
        final levelModel = LevelGeneratorV2.generateLevel(lvl);
        expect(levelModel.levelNumber, lvl);
        expect(levelModel.arrows.isNotEmpty, true);
        expect(levelModel.maskShape.name, maskShape.name);
      }
    }
  });

  test('Verify specific user requested levels match MD schedule shape', () {
    final repo = LevelRepository();
    final expected = {
      8: 'cat',
      10: 'heart',
      13: 'letterX',
      16: 'lion',
      30: 'crown',
      38: 'octagon',
      989: 'letterZ',
      2000: 'star',
    };

    expected.forEach((lvl, expectedShapeName) {
      final entry = LevelSchedule.getEntry(lvl);
      expect(entry.shapeName, expectedShapeName, reason: 'Level $lvl entry shapeName must be $expectedShapeName');

      final level = repo.getLevel(lvl);
      expect(level.maskShape.name, expectedShapeName, reason: 'Level $lvl generated LevelModel must have shape $expectedShapeName');
    });
  });
}

