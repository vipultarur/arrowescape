import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_colors.dart';
import '../../core/audio_manager.dart';
import '../../core/constants.dart';
import '../../core/localization.dart';
import '../../data/repositories/progress_repository.dart';
import '../../widgets/app_bar_buttons.dart';
import '../../widgets/game_3d_toggle.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showLanguagesBottomSheet(BuildContext context) {
    AudioManager.instance.playClick();
    final progress = context.read<ProgressRepository>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LanguageBottomSheet(
        currentLanguage: progress.selectedLanguage,
        onSelected: (lang) {
          progress.setLanguage(lang);
        },
      ),
    );
  }

  String _getThemeName(BuildContext context, AppThemeOption option) {
    switch (option) {
      case AppThemeOption.darkMono:
        return context.tr('dark_theme');
      case AppThemeOption.darkColor:
        return context.tr('dark_color_arrow');
      case AppThemeOption.lightMono:
        return context.tr('light_theme');
      case AppThemeOption.lightColor:
        return context.tr('light_color_arrow');
    }
  }

  void _showThemeBottomSheet(BuildContext context, ProgressRepository progress) {
    AudioManager.instance.playClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ThemeBottomSheet(
        currentOption: progress.themeOption,
        onSelected: (newOption) {
          AudioManager.instance.playClick();
          progress.setThemeOption(newOption);
        },
      ),
    );
  }


  void _showTermsDialog(BuildContext context) {
    AudioManager.instance.playClick();
    showDialog(
      context: context,
      builder: (context) => _TermsModalDialog(onOpenUrl: _launchUrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressRepository>();
    final appColors = context.appColors;
    final isDark = appColors.isDark;

    final Color topBgColor = appColors.background;
    final Color textColor = appColors.textPrimary;

    return Scaffold(
      backgroundColor: topBgColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header Bar ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Row(
                children: [
                  if (Navigator.canPop(context)) ...[
                    const AppBackButton(),
                    const SizedBox(width: 12),
                  ],
                  Text(
                    context.tr('settings'),
                    style: GoogleFonts.nunito(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),

            // ── Scrollable Body (Single Unified Container) ────────────
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                children: [
                  // 1. Settings Items (MUSIC, SOUNDTRACK, VIBRATION)
                  _SettingsRowTile(
                    iconWidget: Icon(LucideIcons.music, size: 22, color: textColor),
                    label: context.tr('music'),
                    value: progress.musicEnabled,
                    onChanged: (val) {
                      AudioManager.instance.playClick();
                      progress.setMusicEnabled(val);
                    },
                  ),

                  if (progress.musicEnabled) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.disc,
                            size: 22,
                            color: textColor,
                          ),
                          const SizedBox(width: 14),
                          Text(
                            context.tr('bg_music'),
                            style: GoogleFonts.nunito(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const Spacer(),
                          _SoundtrackDropdown(
                            currentTrack: progress.bgMusicTrack,
                            onChanged: (val) {
                              progress.setBgMusicTrack(val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],

                  const SizedBox(height: 22),

                  _SettingsRowTile(
                    iconWidget: _buildVibrationIcon(textColor),
                    label: context.tr('vibration'),
                    value: progress.vibrationEnabled,
                    onChanged: (val) {
                      AudioManager.instance.playClick();
                      progress.setVibrationEnabled(val);
                    },
                  ),

                  const SizedBox(height: 24),

                  // 2. Action Buttons (Languages, Theme)
                  _Themed3DPillButton(
                    icon: LucideIcons.languages,
                    label: '${context.tr('languages')} (${progress.selectedLanguage})',
                    onTap: () => _showLanguagesBottomSheet(context),
                  ),
                  const SizedBox(height: 18),

                  _Themed3DPillButton(
                    icon: isDark ? LucideIcons.moon : LucideIcons.sun,
                    label: '${context.tr('theme')} (${_getThemeName(context, progress.themeOption).toUpperCase()})',
                    onTap: () => _showThemeBottomSheet(context, progress),
                  ),

                  const SizedBox(height: 26),

                  // 3. Small Side-by-Side 3D Pill Buttons (T&C and Privacy)
                  Row(
                    children: [
                      Expanded(
                        child: _Small3DPillButton(
                          label: 'T&C',
                          onTap: () => _showTermsDialog(context),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _Small3DPillButton(
                          label: 'Privacy',
                          onTap: () => _launchUrl(AppConstants.privacyPolicyUrl),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // 5. App Version Footer
                  GestureDetector(
                    onLongPress: () {
                      progress.toggleDemoMode();
                      AudioManager.instance.playClick();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            progress.isDemoMode
                                ? '🎮 Demo Mode Activated (Unlimited Lives & Levels)'
                                : '🔒 Demo Mode Deactivated',
                            style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
                          ),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: progress.isDemoMode
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Center(
                      child: Column(
                        children: [
                          FutureBuilder<PackageInfo>(
                            future: PackageInfo.fromPlatform(),
                            builder: (context, snapshot) {
                              final version = snapshot.data?.version ?? '1.3.3';
                              final buildNumber = snapshot.data?.buildNumber ?? '17';
                              return Text(
                                '${AppConstants.appName} v$version+$buildNumber',
                                style: GoogleFonts.nunito(
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppConstants.packageId,
                            style: GoogleFonts.nunito(
                              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (progress.isDemoMode) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF10B981), width: 1),
                              ),
                              child: Text(
                                'DEMO MODE ACTIVE',
                                style: GoogleFonts.nunito(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helper Icon Builders ───────────────────────────────────────────────────


  /// Mobile phone with vibration waves matching target image Vibration icon
  Widget _buildVibrationIcon(Color color) {
    return SizedBox(
      width: 28,
      height: 22,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 2,
            height: 10,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(1)),
          ),
          const SizedBox(width: 2),
          Icon(LucideIcons.smartphone, size: 18, color: color),
          const SizedBox(width: 2),
          Container(
            width: 2,
            height: 10,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(1)),
          ),
        ],
      ),
    );
  }
}

// ── Theme-matched Soundtrack Dropdown Picker ─────────────────────────────────
class _SoundtrackDropdown extends StatelessWidget {
  final String currentTrack;
  final ValueChanged<String> onChanged;

  const _SoundtrackDropdown({
    required this.currentTrack,
    required this.onChanged,
  });

  static const List<Map<String, dynamic>> tracks = [
    {
      'id': 'smooth_ambient.wav',
      'title': 'Smooth Ambient',
      'icon': LucideIcons.music,
    },
    {
      'id': 'underwater.mp3',
      'title': 'Underwater Calm',
      'icon': LucideIcons.waves,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;
    final backgroundColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2F5FC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFDBF2FA);
    final textColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF2B226D);
    final popupBgColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    final activeTrack = tracks.firstWhere(
      (t) => t['id'] == currentTrack,
      orElse: () => tracks.first,
    );

    return PopupMenuButton<String>(
      onSelected: (val) {
        AudioManager.instance.playClick();
        onChanged(val);
      },
      elevation: 6,
      color: popupBgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: borderColor, width: 1.5),
      ),
      offset: const Offset(0, 42),
      itemBuilder: (context) {
        return tracks.map((track) {
          final isSelected = track['id'] == currentTrack;
          return PopupMenuItem<String>(
            value: track['id'] as String,
            height: 44,
            child: Row(
              children: [
                Icon(
                  track['icon'] as IconData,
                  size: 18,
                  color: isSelected ? const Color(0xFF00AEEF) : textColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    track['title'] as String,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                      color: isSelected ? const Color(0xFF00AEEF) : textColor,
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(
                    LucideIcons.check,
                    color: Color(0xFF00AEEF),
                    size: 18,
                  ),
              ],
            ),
          );
        }).toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              activeTrack['icon'] as IconData,
              size: 16,
              color: const Color(0xFF00AEEF),
            ),
            const SizedBox(width: 8),
            Text(
              activeTrack['title'] as String,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              LucideIcons.chevronDown,
              size: 16,
              color: textColor.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Setting Row Tile with Custom 3D Toggle Switch ────────────────────────────
class _SettingsRowTile extends StatelessWidget {
  final Widget iconWidget;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsRowTile({
    required this.iconWidget,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;
    final textColor = isDark ? Colors.white : const Color(0xFF2B226D);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            height: 26,
            child: Center(child: iconWidget),
          ),
          const SizedBox(width: 14),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: textColor,
              letterSpacing: 0.8,
            ),
          ),
          const Spacer(),
          Game3DToggleSwitch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// ── Theme Selection Modal Bottom Sheet ─────────────────────────────────────────
// ── Theme Selection Modal Bottom Sheet ─────────────────────────────────────────
class _ThemeBottomSheet extends StatelessWidget {
  final AppThemeOption currentOption;
  final ValueChanged<AppThemeOption> onSelected;

  const _ThemeBottomSheet({
    required this.currentOption,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final backgroundColor = appColors.surface;
    final textColor = appColors.textPrimary;

    final List<Map<String, dynamic>> options = [
      {
        'option': AppThemeOption.darkMono,
        'title': 'Dark Theme',
        'bgColor': const Color(0xFF161C2E),
        'cardTextColor': Colors.white,
        'accentColor': const Color(0xFF6366F1),
      },
      {
        'option': AppThemeOption.darkColor,
        'title': 'Dark & Color Arrow',
        'bgColor': const Color(0xFF161C2E),
        'cardTextColor': Colors.white,
        'accentColor': const Color(0xFF00AEEF),
      },
      {
        'option': AppThemeOption.lightMono,
        'title': 'Light Theme',
        'bgColor': const Color(0xFFF0F4FA),
        'cardTextColor': const Color(0xFF2B226D),
        'accentColor': const Color(0xFF3B82F6),
      },
      {
        'option': AppThemeOption.lightColor,
        'title': 'Light & Color Arrow',
        'bgColor': const Color(0xFFF0F4FA),
        'cardTextColor': const Color(0xFF2B226D),
        'accentColor': const Color(0xFF00AEEF),
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: appColors.isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(
                    appColors.isDark ? LucideIcons.moon : LucideIcons.sun,
                    color: const Color(0xFF00AEEF),
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'SELECT THEME',
                    style: GoogleFonts.nunito(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  const AppCloseButton(size: 34),
                ],
              ),
            ),
            const Divider(height: 16, thickness: 1),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.0,
                ),
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final item = options[index];
                  final option = item['option'] as AppThemeOption;
                  final title = item['title'] as String;
                  final cardBgColor = item['bgColor'] as Color;
                  final cardTextColor = item['cardTextColor'] as Color;
                  final accentColor = item['accentColor'] as Color;
                  final isSelected = option == currentOption;

                  final activeBorderColor = const Color(0xFF22C55E);

                  return GestureDetector(
                    onTap: () {
                      onSelected(option);
                      Navigator.pop(context);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: BoxDecoration(
                        color: cardBgColor,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isSelected ? activeBorderColor : accentColor.withValues(alpha: 0.4),
                          width: isSelected ? 3.0 : 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isSelected ? 0.2 : 0.08),
                            blurRadius: isSelected ? 12 : 6,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(height: 8),
                                Expanded(
                                  child: Center(
                                    child: SizedBox(
                                      width: 76,
                                      height: 76,
                                      child: CustomPaint(
                                        painter: _ThemePreviewPainter(
                                          option: option,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    title,
                                    style: GoogleFonts.nunito(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: cardTextColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Positioned(
                              right: 10,
                              top: 10,
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF22C55E),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  LucideIcons.check,
                                  color: Colors.white,
                                  size: 15,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ── Mini Preview Painter for Theme Option Cards ──────────────────────────────
class _ThemePreviewPainter extends CustomPainter {
  final AppThemeOption option;

  _ThemePreviewPainter({
    required this.option,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double sw = w * 0.075;

    final Color colorTop;
    final Color colorCurved;
    final Color colorLeft;
    final Color colorRight;

    switch (option) {
      case AppThemeOption.darkMono:
        colorTop = const Color(0xFF94A3B8);
        colorCurved = const Color(0xFFCBD5E1);
        colorLeft = const Color(0xFF64748B);
        colorRight = const Color(0xFF475569);
        break;
      case AppThemeOption.darkColor:
        colorTop = const Color(0xFF38BDF8);
        colorCurved = const Color(0xFFA5B4FC);
        colorLeft = const Color(0xFF34D399);
        colorRight = const Color(0xFFFB923C);
        break;
      case AppThemeOption.lightMono:
        colorTop = const Color(0xFF475569);
        colorCurved = const Color(0xFF64748B);
        colorLeft = const Color(0xFF94A3B8);
        colorRight = const Color(0xFFCBD5E1);
        break;
      case AppThemeOption.lightColor:
        colorTop = const Color(0xFF3B82F6);
        colorCurved = const Color(0xFF818CF8);
        colorLeft = const Color(0xFF34D399);
        colorRight = const Color(0xFFF87171);
        break;
    }

    Paint buildPaint(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    Paint buildHeadPaint(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path1 = Path();
    final p1Start = Offset(w * 0.16, h * 0.84);
    final p1End = Offset(w * 0.72, h * 0.16);
    path1.moveTo(p1Start.dx, p1Start.dy);
    path1.lineTo(w * 0.16, h * 0.32);
    path1.quadraticBezierTo(w * 0.16, h * 0.16, w * 0.32, h * 0.16);
    path1.lineTo(p1End.dx, p1End.dy);
    canvas.drawPath(path1, buildPaint(colorTop));
    _drawArrowHead(canvas, p1End, const Offset(1, 0), sw * 1.7, buildHeadPaint(colorTop));

    final path2 = Path();
    final p2Start = Offset(w * 0.32, h * 0.36);
    final p2End = Offset(w * 0.78, h * 0.65);
    path2.moveTo(p2Start.dx, p2Start.dy);
    path2.lineTo(w * 0.64, h * 0.36);
    path2.quadraticBezierTo(w * 0.78, h * 0.36, w * 0.78, h * 0.50);
    path2.lineTo(p2End.dx, p2End.dy);
    canvas.drawPath(path2, buildPaint(colorCurved));
    _drawArrowHead(canvas, p2End, const Offset(0, 1), sw * 1.7, buildHeadPaint(colorCurved));

    final p3Start = Offset(w * 0.72, h * 0.52);
    final p3End = Offset(w * 0.26, h * 0.52);
    canvas.drawLine(p3Start, p3End, buildPaint(colorLeft));
    _drawArrowHead(canvas, p3End, const Offset(-1, 0), sw * 1.7, buildHeadPaint(colorLeft));

    final p4Start = Offset(w * 0.26, h * 0.72);
    final p4End = Offset(w * 0.72, h * 0.72);
    canvas.drawLine(p4Start, p4End, buildPaint(colorRight));
    _drawArrowHead(canvas, p4End, const Offset(1, 0), sw * 1.7, buildHeadPaint(colorRight));
  }

  void _drawArrowHead(Canvas canvas, Offset tip, Offset dir, double headSize, Paint paint) {
    final px = -dir.dy;
    final py = dir.dx;
    final base = tip - dir * headSize * 0.85;
    final hw = headSize * 0.55;

    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(base.dx + px * hw, base.dy + py * hw)
      ..lineTo(base.dx - px * hw, base.dy - py * hw)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ThemePreviewPainter oldDelegate) {
    return oldDelegate.option != option;
  }
}

// ── Theme-matched 3D Pill Button (TUTORIAL, LANGUAGES) ────────────────────────
class _Themed3DPillButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _Themed3DPillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_Themed3DPillButton> createState() => _Themed3DPillButtonState();
}

class _Themed3DPillButtonState extends State<_Themed3DPillButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pressAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _pressAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;

    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _pressAnim,
        builder: (context, child) {
          final double t = _pressAnim.value;
          final double bottomLip = 4.5 * (1.0 - t);
          final double topPush = 4.5 * t;

          final Color faceColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2F5FC);
          final Color shadowColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFC6E5F4);
          final Color textColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF2B226D);
          final Color borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFDBF2FA);

          return Container(
            height: 48,
            decoration: BoxDecoration(
              color: shadowColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                  blurRadius: 5,
                  offset: Offset(0, 2.5 * (1.0 - t)),
                ),
              ],
            ),
            child: Container(
              margin: EdgeInsets.only(bottom: bottomLip, top: topPush),
              decoration: BoxDecoration(
                color: faceColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: borderColor,
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.icon,
                    color: textColor,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.label,
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── White 3D Pill Button (HELP CENTRE, INVITE FRIENDS) ────────────────────────
class _White3DPillButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _White3DPillButton({
    required this.label,
    required this.onTap,
  });

  @override
  State<_White3DPillButton> createState() => _White3DPillButtonState();
}

class _White3DPillButtonState extends State<_White3DPillButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pressAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _pressAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;

    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _pressAnim,
        builder: (context, child) {
          final double t = _pressAnim.value;
          final double bottomLip = 4.5 * (1.0 - t);
          final double topPush = 4.5 * t;

          final Color faceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
          final Color shadowColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFD8E4F2);
          final Color textColor = isDark ? Colors.white : const Color(0xFF2B226D);

          return Container(
            height: 48,
            decoration: BoxDecoration(
              color: shadowColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                  blurRadius: 5,
                  offset: Offset(0, 2.5 * (1.0 - t)),
                ),
              ],
            ),
            child: Container(
              margin: EdgeInsets.only(bottom: bottomLip, top: topPush),
              decoration: BoxDecoration(
                color: faceColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFEFF5FC),
                  width: 1.2,
                ),
              ),
              child: Center(
                child: Text(
                  widget.label,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Small Bottom 3D Pill Button (T&C, Privacy) ───────────────────────────────
class _Small3DPillButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _Small3DPillButton({
    required this.label,
    required this.onTap,
  });

  @override
  State<_Small3DPillButton> createState() => _Small3DPillButtonState();
}

class _Small3DPillButtonState extends State<_Small3DPillButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pressAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _pressAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;

    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _pressAnim,
        builder: (context, child) {
          final double t = _pressAnim.value;
          final double bottomLip = 3.5 * (1.0 - t);
          final double topPush = 3.5 * t;

          final Color faceColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2F5FC);
          final Color shadowColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFC6E5F4);
          final Color textColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF2B226D);

          return Container(
            height: 40,
            decoration: BoxDecoration(
              color: shadowColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              margin: EdgeInsets.only(bottom: bottomLip, top: topPush),
              decoration: BoxDecoration(
                color: faceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFDBF2FA),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  widget.label,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}



// ── Language Modal Bottom Sheet ────────────────────────────────────────────────
class _LanguageBottomSheet extends StatelessWidget {
  final String currentLanguage;
  final ValueChanged<String> onSelected;

  const _LanguageBottomSheet({
    required this.currentLanguage,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;
    final backgroundColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF2B226D);
    final activeTileBg = isDark ? const Color(0xFF00AEEF).withValues(alpha: 0.15) : const Color(0xFFE2F5FC);
    final activeBorderColor = const Color(0xFF00AEEF);

    final languages = [
      {'name': 'English', 'flag': '🇺🇸'},
      {'name': 'Español', 'flag': '🇪🇸'},
      {'name': 'Français', 'flag': '🇫🇷'},
      {'name': 'Deutsch', 'flag': '🇩🇪'},
      {'name': 'Italiano', 'flag': '🇮🇹'},
      {'name': 'Português', 'flag': '🇵🇹'},
      {'name': 'Русский', 'flag': '🇷🇺'},
      {'name': '中文', 'flag': '🇨🇳'},
      {'name': '日本語', 'flag': '🇯🇵'},
      {'name': '한국어', 'flag': '🇰🇷'},
      {'name': 'हिन्दी', 'flag': '🇮🇳'},
      {'name': 'العربية', 'flag': '🇦🇪'},
      {'name': 'Türkçe', 'flag': '🇹🇷'},
      {'name': 'Tiếng Việt', 'flag': '🇻🇳'},
      {'name': 'Bahasa Indonesia', 'flag': '🇮🇩'},
    ];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            // Drag handle bar
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(LucideIcons.languages, color: Color(0xFF00AEEF), size: 24),
                  const SizedBox(width: 10),
                  Text(
                    context.tr('select_language'),
                    style: GoogleFonts.nunito(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  const AppCloseButton(size: 34),
                ],
              ),
            ),
            const Divider(height: 16, thickness: 1),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: languages.length,
                separatorBuilder: (context, index) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final lang = languages[index];
                  final isSelected = lang['name'] == currentLanguage;

                  return Container(
                    decoration: BoxDecoration(
                      color: isSelected ? activeTileBg : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? activeBorderColor : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      leading: Text(lang['flag']!, style: const TextStyle(fontSize: 24)),
                      title: Text(
                        lang['name']!,
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                          color: isSelected ? const Color(0xFF00AEEF) : textColor,
                        ),
                      ),
                      trailing: isSelected
                          ? Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFF00AEEF),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(LucideIcons.check, color: Colors.white, size: 14),
                            )
                          : null,
                      onTap: () {
                        AudioManager.instance.playClick();
                        onSelected(lang['name']!);
                        Navigator.pop(context);
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ── Help Centre Modal Dialog ──────────────────────────────────────────────────


// ── Terms & Conditions Modal Dialog ───────────────────────────────────────────
class _TermsModalDialog extends StatelessWidget {
  final Function(String) onOpenUrl;

  const _TermsModalDialog({required this.onOpenUrl});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.5),
            width: 2.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.2),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.fileText,
                color: Color(0xFF3B82F6),
                size: 32,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              context.tr('terms_conditions'),
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.tr('terms_desc'),
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 22),
            GestureDetector(
              onTap: () {
                AudioManager.instance.playClick();
                Navigator.pop(context);
                onOpenUrl(AppConstants.privacyPolicyUrl);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    context.tr('view_full_terms'),
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
