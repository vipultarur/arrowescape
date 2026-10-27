import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:arrow_escape/app.dart';
import 'package:arrow_escape/data/repositories/progress_repository.dart';
import 'package:arrow_escape/data/repositories/level_repository.dart';
import 'package:arrow_escape/ads/ad_manager.dart';
import 'package:arrow_escape/services/daily_challenge_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('ArrowPuzzleApp smoke test', (WidgetTester tester) async {
    final progress = ProgressRepository();
    final levelRepo = LevelRepository();
    final adManager = AdManager();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: progress),
          ChangeNotifierProvider.value(value: DailyChallengeService.instance),
          Provider<LevelRepository>.value(value: levelRepo),
          Provider<AdManager>.value(value: adManager),
        ],
        child: const ArrowPuzzleApp(),
      ),
    );

    expect(find.byType(ArrowPuzzleApp), findsOneWidget);
    progress.dispose();
  });
}
