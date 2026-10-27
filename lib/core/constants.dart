import 'ad_secrets.dart';
import '../data/level_generator/level_schedule.dart';

// Core game constants
class AppConstants {
  AppConstants._();

  // App identity
  static const String appName = 'Arrow Puzzle';
  static const String packageId = 'com.tarurinfotech.arrowescape';
  static const String privacyPolicyUrl =
      'https://tarurinfotech.base44.app/privacy/arrow-puzzle';

  // Grid sizes: 10×10 minimum at level 1, up to 35×35 target (hard cap 40).
  // • Normal: 10×10 at level 4 → 35×35 around level 300+
  // • Boss:   20×20 at first boss → 30×30 at high cycles
  // • God:    22×22 at first god  → 35×35 at high cycles
  static const int startingGridSize = 10;
  static const int maxGridSize = 50;
  static const int tutorialLevels = 3;

  // Lives
  static const int maxLives = 3;

  // Special level cadence
  static const int bossLevelEvery = 3; // Every 3rd level is BOSS
  static const int godLevelEvery = 5; // Every 5th level is GOD (overrides boss)

  // Ads
  static const String admobAppIdAndroid = AdSecrets.admobAppIdAndroid;
  static const String admobBannerUnitId = AdSecrets.admobBannerUnitId;
  static const String admobInterstitialUnitId =
      AdSecrets.admobInterstitialUnitId;
  static const String admobRewardedUnitId = AdSecrets.admobRewardedUnitId;

  static const String unityGameId = 'YOUR_UNITY_GAME_ID';
  static const String unityBannerAdId = 'Banner_Android';
  static const String unityInterstitialAdId = 'Interstitial_Android';
  static const String unityRewardedAdId = 'Rewarded_Android';
  static const bool unityTestMode = true;

  // static const String applovinSdkKey = 'YOUR_APPLOVIN_SDK_KEY';
  // static const String applovinBannerAdId = 'YOUR_APPLOVIN_BANNER_AD_UNIT_ID';
  // static const String applovinInterstitialAdId = 'YOUR_APPLOVIN_INTERSTITIAL_AD_UNIT_ID';
  // static const String applovinRewardedAdId = 'YOUR_APPLOVIN_REWARDED_AD_UNIT_ID';

  // Ad Network Feature Toggles
  static const bool enableAdMob = true;
  static const bool enableUnityAds = false;
  static const bool enableAppLovin = false;

  static const int interstitialEveryNLevels = 4;

  // Animation durations
  static const Duration arrowSlideDuration = Duration(milliseconds: 220);
  // arrowExitDuration is now dynamic (based on path length) — this is the base
  static const Duration arrowExitDuration = Duration(milliseconds: 400);
  static const Duration arrowShakeDuration = Duration(milliseconds: 400);
  static const Duration levelCompleteDuration = Duration(milliseconds: 200);

  // Scoring & Economy
  static const int baseScore = 100;
  static const int bonusPerRemainingLife = 50;
  static const int bossBonus = 200;
  static const int godBonus = 500;

  // Economy & Shop Costs
  static const int heartCoinCost = 15; // Buying 1 Heart costs 15 coins

  /// Calculates coin reward earned on completing a level.
  /// Easy levels (Level <= 30) grant 5 coins.
  static int coinsForLevel(int levelNumber) {
    if (levelNumber <= 30) return 5;   // Easy / Tutorial (5 coins)
    if (levelNumber <= 70) return 10;  // Medium (10 coins)
    if (levelNumber <= 150) return 15; // Hard (15 coins)
    if (levelNumber <= 300) return 20; // Expert (20 coins)
    if (levelNumber <= 600) return 25; // Master (25 coins)
    return 30;                         // Legend (30 coins)
  }

  // Streak milestones
  static const int streakMilestone1 = 7;
  static const int streakMilestone2 = 30;
  static const int streakMilestone3 = 100;

  /// How many boss levels have occurred up to and including [level].
  static int bossCycleCount(int level) {
    if (level <= tutorialLevels) return 0;
    int count = 0;
    for (int l = tutorialLevels + 1; l <= level; l++) {
      if (levelTypeFor(l) == LevelType.boss) count++;
    }
    return count;
  }

  /// How many god levels have occurred up to and including [level].
  static int godCycleCount(int level) {
    if (level <= tutorialLevels) return 0;
    int count = 0;
    for (int l = tutorialLevels + 1; l <= level; l++) {
      if (levelTypeFor(l) == LevelType.god) count++;
    }
    return count;
  }

  /// Grid size for a given level number.
  ///   Tutorial :  10×10 (fixed small canvas for guidance)
  ///   Normal   :  15×15 minimum at level 4, ramps to 24×24 at level 19
  /// Calculates the grid size for a given level.
  /// • Levels 1 - 3 (Tutorial): 10×10
  /// • Levels 4 - 9           : 12×12 to 18×18
  /// • Levels 10 - 19         : 20×20 to 25×25
  /// • Level 20+              : Rapidly increases (26×26 to 50×50)
  /// • Varied level-to-level size oscillation so consecutive levels feel distinct!
  static int gridSizeForLevel(int level) {
    if (level <= tutorialLevels) return 10;

    final type = levelTypeFor(level);

    // Special Boss & God levels are extra large & impressive!
    if (type == LevelType.boss) {
      final cycle = bossCycleCount(level);
      final raw = 32 + (cycle * 1);
      return raw.clamp(32, 50);
    }

    if (type == LevelType.god) {
      final cycle = godCycleCount(level);
      final raw = 35 + (cycle * 1);
      return raw.clamp(35, 50);
    }

    // Normal levels progression:
    int baseSize;
    if (level < 10) {
      // Levels 4 - 9: 12 -> 18
      baseSize = 12 + ((level - 4) * 1.2).round();
    } else if (level < 20) {
      // Levels 10 - 19: 20 -> 25
      baseSize = 20 + ((level - 10) * 0.5).round();
    } else if (level < 35) {
      // Levels 20 - 34: 26 -> 34 (big increase after level 20!)
      baseSize = 26 + ((level - 20) * 0.6).round();
    } else if (level < 60) {
      // Levels 35 - 59: 35 -> 44 (large maze sizes!)
      baseSize = 35 + ((level - 35) * 0.4).round();
    } else if (level <= 500) {
      // Levels 60 - 500: 45 -> 48
      baseSize = 45 + ((level - 60) * (3.0 / 440.0)).round();
    } else {
      // Levels 500+: 48 -> 50 (3x enlarged shape canvas!)
      baseSize = 48 + ((level - 500) * (2.0 / 1500.0)).round();
    }

    // Add level-to-level size variation (±2) so consecutive levels don't feel identical!
    final variation = (level % 4 == 1) ? 2 : (level % 4 == 3) ? -2 : 0;

    return (baseSize + variation).clamp(10, 50);
  }

  /// Returns the level type: tutorial, god, boss, or normal.
  /// Delegates to the hardcoded 2000-level master schedule.
  static LevelType levelTypeFor(int level) {
    return LevelSchedule.levelTypeFor(level);
  }

  /// Clean standalone helper: true when n is a boss level.
  static bool isBossLevel(int n) => levelTypeFor(n) == LevelType.boss;

  /// True for god levels.
  static bool isGodLevel(int n) => levelTypeFor(n) == LevelType.god;

  /// Canvas scale factor: higher scale factor zooms in default game canvas area.
  static double canvasScaleForType(LevelType type) {
    switch (type) {
      case LevelType.god:
        return 0.97;
      case LevelType.boss:
        return 0.97;
      default:
        return 1.2;
    }
  }
}

enum LevelType {
  tutorial,
  normal,
  boss,
  god;

  String get label {
    switch (this) {
      case LevelType.tutorial:
        return 'Tutorial';
      case LevelType.normal:
        return '';
      case LevelType.boss:
        return 'Boss';
      case LevelType.god:
        return 'God';
    }
  }

  bool get isSpecial => this == LevelType.boss || this == LevelType.god;
}
