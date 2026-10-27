import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_colors.dart';
import '../../core/audio_manager.dart';
import '../../core/localization.dart';
import '../../data/repositories/level_repository.dart';
import '../../data/repositories/progress_repository.dart';
import '../../services/daily_challenge_service.dart';
import '../main_menu/main_menu_screen.dart';
import '../shop/shop_screen.dart';
import '../settings/settings_screen.dart';

class MainShellScreen extends StatefulWidget {
  final int initialTab;

  const MainShellScreen({super.key, this.initialTab = 1});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> with WidgetsBindingObserver {
  late int _currentIndex;
  Timer? _freeGiftCheckTimer;
  bool _isFreeGiftAvailable = false;

  final List<Widget> _screens = const [
    ShopScreen(),
    MainMenuScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    _checkFreeGiftAvailability();
    _freeGiftCheckTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkFreeGiftAvailability();
    });
    WidgetsBinding.instance.addObserver(this);
    AudioManager.instance.playBgMusic();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      AudioManager.instance.pauseMusic();
    } else if (state == AppLifecycleState.resumed) {
      AudioManager.instance.resumeMusic();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _freeGiftCheckTimer?.cancel();
    super.dispose();
  }

  SharedPreferences? _cachedPrefs;

  Future<void> _checkFreeGiftAvailability() async {
    _cachedPrefs ??= await SharedPreferences.getInstance();
    final prefs = _cachedPrefs!;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // Daily Gift 24-Hour offer: available if never claimed (0) or if >= 24 hours passed
    final lastDailyMs = prefs.getInt('last_daily_gift_timestamp') ?? 0;
    final isDailyAvailable = lastDailyMs == 0 || (nowMs - lastDailyMs) >= (24 * 3600 * 1000);

    // Single Ad 50 Coins 4-Hour offer: available if never claimed (0) or if >= 4 hours passed
    final lastAdMs = prefs.getInt('last_single_ad_coin_timestamp') ?? 0;
    final isAdAvailable = lastAdMs == 0 || (nowMs - lastAdMs) >= (4 * 3600 * 1000);

    final available = isDailyAvailable || isAdAvailable;
    if (mounted && _isFreeGiftAvailable != available) {
      setState(() {
        _isFreeGiftAvailable = available;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final levelRepo = context.read<LevelRepository>();
    DailyChallengeService.instance.preGenerateTodayLevel(levelRepo);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ProgressRepository>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: SizedBox(
        height: 88,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // ── 1. Base Inactive Bar Container (Height 60px) ─────────────────
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 60,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.navBarBg,
                  border: Border(
                    top: BorderSide(
                      color: AppColors.navBarTopRail,
                      width: 3.5,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
              ),
            ),

            // ── 2. Tabs Row Overlay (Full 88px Height for Protruding Active Box) ──
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 88,
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Left Tab: SHOP / CART
                    _buildNavItem(
                      index: 0,
                      assetPath: 'assets/images/nav/cart.webp',
                      fallbackIcon: LucideIcons.shoppingCart,
                      label: context.tr('shop'),
                      showFreeGiftBadge: _isFreeGiftAvailable,
                    ),

                    // Center Tab: HOME
                    _buildNavItem(
                      index: 1,
                      assetPath: 'assets/images/nav/home2.webp',
                      fallbackIcon: LucideIcons.house,
                      label: context.tr('home'),
                    ),

                    // Right Tab: SETTINGS
                    _buildNavItem(
                      index: 2,
                      assetPath: 'assets/images/nav/setting.png',
                      fallbackIcon: LucideIcons.settings,
                      label: context.tr('settings'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String assetPath,
    required IconData fallbackIcon,
    required String label,
    bool showFreeGiftBadge = false,
  }) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () {
        if (_currentIndex != index) {
          AudioManager.instance.playClick();
          setState(() => _currentIndex = index);
        }
      },
      child: isSelected
          ? Stack(
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              children: [
                // Active elevated blue container (Height 74px: Protrudes 14px above 60px base bar!)
                Container(
                  width: 114,
                  height: 74,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.navTabActiveStart, AppColors.navTabActiveEnd],
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                    border: Border.all(
                      color: AppColors.navTabActiveBorder,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        label,
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ),

                // Overhanging 3D icon resting on top curve of blue container
                Positioned(
                  top: -18,
                  child: Image.asset(
                    assetPath,
                    width: 48,
                    height: 44,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        fallbackIcon,
                        size: 34,
                        color: const Color(0xFFFFD600),
                      );
                    },
                  ),
                ),
              ],
            )
          : Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Free Gift Tooltip Speech Bubble over inactive Shop tab (Animated)
                if (showFreeGiftBadge)
                  Positioned(
                    top: -24,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            'FREE GIFT!',
                            style: GoogleFonts.nunito(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF1E5AD6),
                            ),
                          ),
                        ),
                        CustomPaint(
                          size: const Size(8, 5),
                          painter: _BubbleTailPainter(color: Colors.white),
                        ),
                      ],
                    )
                        .animate(onPlay: (controller) => controller.repeat(reverse: true))
                        .moveY(begin: 0, end: -4, duration: 1000.ms, curve: Curves.easeInOut)
                        .scale(
                          begin: const Offset(1.0, 1.0),
                          end: const Offset(1.06, 1.06),
                          duration: 1000.ms,
                          curve: Curves.easeInOut,
                        ),
                  ),

                // Inactive Tab Icon Container (Height 60px matching base bar)
                SizedBox(
                  width: 80,
                  height: 60,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset(
                        assetPath,
                        width: 30,
                        height: 30,
                        fit: BoxFit.contain,
                        color: AppColors.navTabInactiveIcon,
                        colorBlendMode: BlendMode.srcIn,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            fallbackIcon,
                            size: 28,
                            color: AppColors.navTabInactiveIcon,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  final Color color;

  _BubbleTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BubbleTailPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
