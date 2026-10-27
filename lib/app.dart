import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'core/app_colors.dart';
import 'core/localization.dart';
import 'data/repositories/progress_repository.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/main_shell/main_shell_screen.dart';
import 'screens/daily_challenges/daily_challenges_screen.dart';
import 'screens/level_select/level_select_screen.dart';
import 'screens/game/game_screen.dart';
import 'screens/game_over/game_over_screen.dart';
import 'screens/settings/settings_screen.dart';

class ArrowPuzzleApp extends StatelessWidget {
  const ArrowPuzzleApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeOption = context.select<ProgressRepository, AppThemeOption>((p) => p.themeOption);
    final useColorArrows = context.select<ProgressRepository, bool>((p) => p.useColorArrows);
    final selectedLanguage = context.select<ProgressRepository, String>((p) => p.selectedLanguage);

    AppColors.updateTheme(themeOption, colorArrows: useColorArrows);
    final appColorsExt = AppColors.currentExtension;
    final isDark = appColorsExt.isDark;

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: appColorsExt.navBarBg,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    ));

    final themeData = ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: isDark ? Brightness.dark : Brightness.light,
      ),
      textTheme: GoogleFonts.nunitoTextTheme(
        (isDark ? ThemeData.dark() : ThemeData.light()).textTheme,
      ),
      scaffoldBackgroundColor: appColorsExt.background,
      dialogTheme: DialogThemeData(backgroundColor: appColorsExt.dialogBg),
      extensions: [
        appColorsExt,
      ],
    );

    return AppLocalizationWrapper(
      language: selectedLanguage,
      child: MaterialApp(
        title: 'Arrow Puzzle',
        locale: AppLocalizations.getLocale(selectedLanguage),
        debugShowCheckedModeBanner: false,
        theme: themeData,
        initialRoute: '/splash',
        onGenerateRoute: (settings) {
          if (settings.name == '/menu') {
            return PageRouteBuilder(
              settings: settings,
              pageBuilder: (_, __, ___) => const MainShellScreen(),
              transitionsBuilder: (_, animation, __, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 200),
            );
          }
          return null;
        },
        routes: {
          '/splash': (_) => const SplashScreen(),
          '/daily': (_) => const MainShellScreen(initialTab: 1),
          '/daily_challenges': (_) => const DailyChallengesScreen(),
          '/levels': (_) => const LevelSelectScreen(),
          '/game': (_) => const GameScreen(),
          '/game_over': (_) => const GameOverScreen(),
          '/settings': (_) => const SettingsScreen(),
          '/shop': (_) => const MainShellScreen(initialTab: 0),
        },
      ),
    );
  }
}
