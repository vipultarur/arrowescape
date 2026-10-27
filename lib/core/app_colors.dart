import 'package:flutter/material.dart';

enum AppThemeOption {
  darkMono,
  darkColor,
  lightMono,
  lightColor,
}

class AppColors {
  AppColors._();

  static AppThemeOption currentOption = AppThemeOption.lightColor;
  static bool get isDark => currentOption == AppThemeOption.darkMono || currentOption == AppThemeOption.darkColor;
  static bool get useColorArrows => currentOption == AppThemeOption.darkColor || currentOption == AppThemeOption.lightColor;

  static AppColorsExtension currentExtension = AppColorsExtension.fromOption(
    AppThemeOption.lightColor,
  );

  static void updateTheme(AppThemeOption option, {bool? colorArrows}) {
    currentOption = option;
    currentExtension = AppColorsExtension.fromOption(option);
  }

  // Brand
  static Color get primary => const Color(0xFF818CF8);
  static Color get primaryLight => const Color(0xFFA5B4FC);
  static Color get primaryDark => const Color(0xFF4F46E5);
  static Color get accent => const Color(0xFF2563EB);
  static Color get accentGold => const Color(0xFFFBBF24);
  static Color get accentGreen => const Color(0xFF34D399);
  static Color get accentOrange => const Color(0xFFFB923C);

  // Backgrounds & Surfaces (Delegated to currentExtension for dynamic multi-theme support)
  static Color get background => currentExtension.background;
  static Color get surface => currentExtension.surface;
  static Color get surfaceLight => currentExtension.surfaceLight;
  static Color get headerPillBg => currentExtension.headerPillBg;
  static Color get headerPillBorder => currentExtension.headerPillBorder;

  // Level Map Path Track
  static Color get pathLineChannel => currentExtension.pathLineChannel;
  static Color get pathLineRail => currentExtension.pathLineRail;
  static Color get pathLineFill => currentExtension.pathLineFill;

  // Bottom Navigation Bar
  static Color get navBarBg => currentExtension.navBarBg;
  static Color get navBarTopRail => currentExtension.navBarTopRail;
  static Color get navTabActiveStart => currentExtension.navTabActiveStart;
  static Color get navTabActiveEnd => currentExtension.navTabActiveEnd;
  static Color get navTabActiveBorder => currentExtension.navTabActiveBorder;
  static Color get navTabInactiveIcon => currentExtension.navTabInactiveIcon;

  // Game Canvas Grid
  static Color get gridBg => currentExtension.gridBg;
  static Color get gridDot => currentExtension.gridDot;

  // 3D Level Node Colors
  static Color get nodeGreen => const Color(0xFF34C759);
  static Color get nodeGreenShadow => const Color(0xFF1E8E3E);
  static Color get nodeYellowBorder => const Color(0xFFFFD600);
  static Color get nodeOrange => const Color(0xFFFF9500);
  static Color get nodeOrangeShadow => const Color(0xFFC66900);
  static Color get nodeLockedSilver => currentExtension.isDark ? const Color(0xFF8E9BAE) : const Color(0xFFD1D5DB);
  static Color get nodeLockedShadow => currentExtension.isDark ? const Color(0xFF6B7787) : const Color(0xFF9CA3AF);
  static Color get nodeLockedBevel => currentExtension.isDark ? const Color(0xFF475569) : const Color(0xFFC4D1DF);

  // Text Colors
  static Color get textPrimary => currentExtension.textPrimary;
  static Color get textSecondary => currentExtension.textSecondary;
  static Color get textMuted => currentExtension.textMuted;

  // Arrow direction colors
  static Color get arrowUp => currentExtension.isDark ? const Color(0xFFA5B4FC) : const Color(0xFF111827);
  static Color get arrowDown => currentExtension.isDark ? const Color(0xFFA5B4FC) : const Color(0xFF111827);
  static Color get arrowLeft => currentExtension.isDark ? const Color(0xFFA5B4FC) : const Color(0xFF111827);
  static Color get arrowRight => currentExtension.isDark ? const Color(0xFFA5B4FC) : const Color(0xFF111827);

  // UI Elements
  static Color get heartRed => const Color(0xFFFF2D55);
  static Color get heartEmpty => currentExtension.isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
  static Color get streakFire => const Color(0xFFFB923C);
  static Color get coinGold => const Color(0xFFFFC107);
  static Color get starYellow => const Color(0xFFFFCA28);
  static Color get borderGlow => const Color(0xFF2563EB);

  // Difficulty colors
  static Color get easy => const Color(0xFF34D399);
  static Color get medium => const Color(0xFF60A5FA);
  static Color get hard => const Color(0xFFFBBF24);
  static Color get expert => const Color(0xFFF87171);
  static Color get master => const Color(0xFFA78BFA);

  // Dialogs & Cards
  static Color get dialogBg => currentExtension.dialogBg;
  static Color get dialogBorder => currentExtension.dialogBorder;
  static Color get cardBorder => currentExtension.cardBorder;

  // Gradients
  static LinearGradient get bgGradient => LinearGradient(
        colors: [currentExtension.background, currentExtension.surface],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );

  static LinearGradient get primaryGradient => const LinearGradient(
        colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get secondaryGradient => LinearGradient(
        colors: [currentExtension.surface, currentExtension.surfaceLight],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get successGradient => const LinearGradient(
        colors: [Color(0xFF10B981), Color(0xFF34D399)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get dangerGradient => const LinearGradient(
        colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static Color getGroupColor(int groupIndex) {
    const list = [
      Color(0xFFF87171),
      Color(0xFF60A5FA),
      Color(0xFF34D399),
      Color(0xFFA78BFA),
      Color(0xFFFB923C),
      Color(0xFF38BDF8),
      Color(0xFFF472B6),
      Color(0xFFFBBF24),
      Color(0xFFA3E635),
      Color(0xFF2DD4BF),
    ];
    return list[groupIndex % list.length];
  }
}

/// ThemeExtension for AppColors to support Flutter's standard theme tree system
class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  final AppThemeOption themeOption;
  final bool isDark;
  final bool useColorArrows;

  final Color background;
  final Color surface;
  final Color surfaceLight;
  final Color headerPillBg;
  final Color headerPillBorder;

  final Color navBarBg;
  final Color navBarTopRail;
  final Color navTabActiveStart;
  final Color navTabActiveEnd;
  final Color navTabActiveBorder;
  final Color navTabInactiveIcon;

  final Color pathLineChannel;
  final Color pathLineRail;
  final Color pathLineFill;

  final Color gridBg;
  final Color gridDot;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  final Color dialogBg;
  final Color dialogBorder;
  final Color cardBorder;

  const AppColorsExtension({
    required this.themeOption,
    required this.isDark,
    required this.useColorArrows,
    required this.background,
    required this.surface,
    required this.surfaceLight,
    required this.headerPillBg,
    required this.headerPillBorder,
    required this.navBarBg,
    required this.navBarTopRail,
    required this.navTabActiveStart,
    required this.navTabActiveEnd,
    required this.navTabActiveBorder,
    required this.navTabInactiveIcon,
    required this.pathLineChannel,
    required this.pathLineRail,
    required this.pathLineFill,
    required this.gridBg,
    required this.gridDot,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.dialogBg,
    required this.dialogBorder,
    required this.cardBorder,
  });

  factory AppColorsExtension.fromOption(AppThemeOption option) {
    final bool isDark = option == AppThemeOption.darkMono || option == AppThemeOption.darkColor;
    final bool useColorArrows = option == AppThemeOption.darkColor || option == AppThemeOption.lightColor;

    if (isDark) {
      return AppColorsExtension(
        themeOption: option,
        isDark: true,
        useColorArrows: useColorArrows,
        background: const Color(0xFF161C2E),
        surface: const Color(0xFF212B46),
        surfaceLight: const Color(0xFF2D395B),
        headerPillBg: const Color(0xFF10192A),
        headerPillBorder: const Color(0xFF1E2B45),
        navBarBg: const Color(0xFF131E33),
        navBarTopRail: const Color(0xFF1E2D4A),
        navTabActiveStart: const Color(0xFF294A7D),
        navTabActiveEnd: const Color(0xFF1E3861),
        navTabActiveBorder: const Color(0xFF3B649E),
        navTabInactiveIcon: const Color(0xFF64748B),
        pathLineChannel: const Color(0xFF16233B),
        pathLineRail: const Color(0xFF223556),
        pathLineFill: const Color(0xFF00A3FF),
        gridBg: const Color(0xFF161C2E),
        gridDot: const Color(0xFF28354D),
        textPrimary: const Color(0xFFFFFFFF),
        textSecondary: const Color(0xFF94A3B8),
        textMuted: const Color(0xFF64748B),
        dialogBg: const Color(0xFF1B243B),
        dialogBorder: const Color(0xFF2E3D5C),
        cardBorder: const Color(0xFF2A3752),
      );
    } else {
      return AppColorsExtension(
        themeOption: option,
        isDark: false,
        useColorArrows: useColorArrows,
        background: const Color(0xFFF0F4FA),
        surface: const Color(0xFFFFFFFF),
        surfaceLight: const Color(0xFFD6E8F5),
        headerPillBg: const Color(0xFFFFFFFF),
        headerPillBorder: const Color(0xFFD6E0EA),
        navBarBg: const Color(0xFFFFFFFF),
        navBarTopRail: const Color(0xFFE2E8F0),
        navTabActiveStart: const Color(0xFF3B82F6),
        navTabActiveEnd: const Color(0xFF2563EB),
        navTabActiveBorder: const Color(0xFF60A5FA),
        navTabInactiveIcon: const Color(0xFF64748B),
        pathLineChannel: const Color(0xFFE2E8F0),
        pathLineRail: const Color(0xFFCBD5E1),
        pathLineFill: const Color(0xFF00A3FF),
        gridBg: const Color(0xFFF0F4FA),
        gridDot: const Color(0xFFCBD5E1),
        textPrimary: const Color(0xFF2B226D),
        textSecondary: const Color(0xFF4A4287),
        textMuted: const Color(0xFF8D85BD),
        dialogBg: const Color(0xFFFFFFFF),
        dialogBorder: const Color(0xFFE2E8F0),
        cardBorder: const Color(0xFFE2E8F0),
      );
    }
  }

  @override
  AppColorsExtension copyWith({
    AppThemeOption? themeOption,
    bool? isDark,
    bool? useColorArrows,
  }) {
    return AppColorsExtension.fromOption(
      themeOption ?? this.themeOption,
    );
  }

  @override
  AppColorsExtension lerp(ThemeExtension<AppColorsExtension>? other, double t) {
    if (other is! AppColorsExtension) return this;
    return t < 0.5 ? this : other;
  }
}

extension AppColorsContext on BuildContext {
  AppColorsExtension get appColors =>
      Theme.of(this).extension<AppColorsExtension>() ?? AppColors.currentExtension;
}
