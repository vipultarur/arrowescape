import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:arrow_escape/core/constants.dart';
import 'package:arrow_escape/data/models/level.dart';
import 'package:arrow_escape/data/repositories/progress_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('When lives count is 0 and player starts/clicks a level, lives refill to max and level starts', () async {
    final progress = ProgressRepository();

    // Drain lives to 0
    await progress.syncLives(0);

    expect(progress.lives, 0);
    expect(progress.hasLives, isFalse);

    // Simulate level click action when lives are 0
    if (!progress.hasLives) {
      await progress.restoreLives();
    }
    await progress.recordLevelComplete(LevelResult(
      levelNumber: 1,
      stars: 3,
      score: 100,
      movesUsed: 5,
      livesLost: 0,
      completed: true,
      completedAt: DateTime.now(),
    ));

    expect(progress.lives, AppConstants.maxLives);
    expect(progress.hasLives, isTrue);
    expect(progress.currentLevel, 2);
  });
}
