import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:google_fonts/google_fonts.dart';

import 'core/constants.dart';
import 'firebase_options.dart';

import 'app.dart';
import 'data/repositories/progress_repository.dart';
import 'data/repositories/level_repository.dart';
import 'ads/ad_manager.dart';
import 'core/audio_manager.dart';
import 'services/daily_challenge_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  // 0. Set up early error handlers BEFORE anything else — buffer until Crashlytics is ready
  final List<FlutterErrorDetails> pendingFlutterErrors = [];
  final List<(Object, StackTrace)> pendingPlatformErrors = [];

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    pendingFlutterErrors.add(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    pendingPlatformErrors.add((error, stack));
    return true;
  };

  // 1. System UI & Orientation (Lightweight synchronous calls)
  try {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ));
  } catch (e) {
    debugPrint('System UI init error: $e');
  }

  // 2. SharedPreferences (Quick async init)
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (e) {
    debugPrint('SharedPreferences init error: $e');
  }

  final progressRepo = ProgressRepository(prefs);
  final levelRepo = LevelRepository(prefs);
  final adManager = AdManager();

  // 3. Launch App IMMEDIATELY so splash screen renders in 0ms!
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => progressRepo),
        ChangeNotifierProvider.value(value: DailyChallengeService.instance),
        Provider<LevelRepository>(create: (_) => levelRepo),
        Provider<AdManager>(create: (_) => adManager),
      ],
      child: const ArrowPuzzleApp(),
    ),
  );

  // 4. Heavy background SDK initializations — non-blocking after first frame
  Future.microtask(() async {
    try {
      await levelRepo.loadPregeneratedLevels();
      levelRepo.preGenerateRangeAsync(1, 20);
    } catch (e) {
      debugPrint('LevelRepository init error: $e');
    }

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Flush any errors captured during startup to Crashlytics
      for (final details in pendingFlutterErrors) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      }
      pendingFlutterErrors.clear();
      for (final (error, stack) in pendingPlatformErrors) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      }
      pendingPlatformErrors.clear();

      // Set permanent error handlers now that Crashlytics is live
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    } catch (e) {
      debugPrint('Firebase init error: $e');
    }

    try {
      await AudioManager.instance.initialize();
    } catch (e) {
      debugPrint('AudioManager init error: $e');
    }

    if (AppConstants.enableAdMob) {
      try {
        await MobileAds.instance.initialize();
      } catch (e) {
        debugPrint('MobileAds init error: $e');
      }
    }

    try {
      adManager.initialize();
    } catch (e) {
      debugPrint('AdManager init error: $e');
    }

    try {
      await NotificationService.instance.initialize();
      await DailyChallengeService.instance.initialize();
    } catch (e) {
      debugPrint('Services init error: $e');
    }
  });
}
