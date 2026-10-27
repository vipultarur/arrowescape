import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../ads/ad_manager.dart';
import '../../core/app_colors.dart';
import '../../core/audio_manager.dart';
import '../../core/constants.dart';
import '../../core/localization.dart';
import '../../data/repositories/progress_repository.dart';
import '../../services/notification_service.dart';

/// Clean Shop Screen featuring:
/// 1. 1-Ad Watch -> 50 Coins (FREE)
/// 2. 5-Hour Countdown Daily Gift -> 50 Coins
/// 3. Multi-Ad Rewarded Offers (100-3, 200-6, 500-10)
/// 4. Animated 3D Coin Collect Particles flying to header appbar on claim
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> with TickerProviderStateMixin {
  // GlobalKey for measuring header coin position for flying coin animation
  final GlobalKey _headerCoinKey = GlobalKey();

  // Ad progress counters for multi-ad offers
  int _adProgress100 = 0; // 0 to 3
  int _adProgress200 = 0; // 0 to 6
  int _adProgress500 = 0; // 0 to 10

  // 1-Ad Watch Claim & 4-Hour Cooldown State
  bool _isSingleAdClaimable = false;
  DateTime? _lastSingleAdTime;
  Duration _remainingSingleAdCooldown = Duration.zero;

  // Daily Gift 24-Hour Countdown State
  DateTime? _lastDailyGiftTime;
  Timer? _countdownTimer;
  Duration _remainingGiftCooldown = Duration.zero;

  // Multi-Ad Offer Cooldown States (100 -> 5h, 200 -> 10h, 500 -> 12h)
  DateTime? _lastTime100;
  Duration _remainingCooldown100 = Duration.zero;

  DateTime? _lastTime200;
  Duration _remainingCooldown200 = Duration.zero;

  DateTime? _lastTime500;
  Duration _remainingCooldown500 = Duration.zero;

  // Flying Coins Particle Animation State
  late AnimationController _coinAnimController;
  final List<_FlyingCoinParticle> _flyingCoins = [];
  bool _isHeaderPillPulsing = false;

  @override
  void initState() {
    super.initState();
    _loadDailyGiftState();

    _coinAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..addListener(() {
        setState(() {});
      })
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _flyingCoins.clear();
          _isHeaderPillPulsing = true;
        });
        // Pulse header pill and finish animation
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted) {
            setState(() => _isHeaderPillPulsing = false);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _coinAnimController.dispose();
    super.dispose();
  }

  // ── Timers & Countdown Logic ────────────────────────────────────────────
  Future<void> _loadDailyGiftState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final now = DateTime.now();

    final lastDailyTimeMs = prefs.getInt('last_daily_gift_timestamp') ?? 0;
    if (lastDailyTimeMs > 0) {
      _lastDailyGiftTime = DateTime.fromMillisecondsSinceEpoch(lastDailyTimeMs);
      final nextDaily = _lastDailyGiftTime!.add(const Duration(hours: 24));
      if (nextDaily.isAfter(now)) {
        NotificationService.instance.scheduleDailyGiftReminder(nextDaily);
      }
    }

    final lastAdTimeMs = prefs.getInt('last_single_ad_coin_timestamp') ?? 0;
    if (lastAdTimeMs > 0) {
      _lastSingleAdTime = DateTime.fromMillisecondsSinceEpoch(lastAdTimeMs);
      final nextAd = _lastSingleAdTime!.add(const Duration(hours: 4));
      if (nextAd.isAfter(now)) {
        NotificationService.instance.scheduleFreeCoinsReminder(nextAd);
      }
    }

    final t100 = prefs.getInt('last_multi_ad_100_timestamp') ?? 0;
    if (t100 > 0) {
      _lastTime100 = DateTime.fromMillisecondsSinceEpoch(t100);
    }

    final t200 = prefs.getInt('last_multi_ad_200_timestamp') ?? 0;
    if (t200 > 0) {
      _lastTime200 = DateTime.fromMillisecondsSinceEpoch(t200);
    }

    final t500 = prefs.getInt('last_multi_ad_500_timestamp') ?? 0;
    if (t500 > 0) {
      _lastTime500 = DateTime.fromMillisecondsSinceEpoch(t500);
    }

    _updateDailyGiftTimer();
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateDailyGiftTimer();
    });
  }

  void _updateDailyGiftTimer() {
    if (!mounted) return;

    final now = DateTime.now();

    // 1. Daily Gift 24h Cooldown
    if (_lastDailyGiftTime == null) {
      _remainingGiftCooldown = Duration.zero;
    } else {
      final nextDailyTime = _lastDailyGiftTime!.add(const Duration(hours: 24));
      final diffDaily = nextDailyTime.difference(now);
      _remainingGiftCooldown = diffDaily.isNegative ? Duration.zero : diffDaily;
    }

    // 2. Single Ad 4h Cooldown
    if (_lastSingleAdTime == null) {
      _remainingSingleAdCooldown = Duration.zero;
    } else {
      final nextAdTime = _lastSingleAdTime!.add(const Duration(hours: 4));
      final diffAd = nextAdTime.difference(now);
      _remainingSingleAdCooldown = diffAd.isNegative ? Duration.zero : diffAd;
    }

    // 3. Multi-Ad 100 Cooldown (5 Hours)
    if (_lastTime100 == null) {
      _remainingCooldown100 = Duration.zero;
    } else {
      final nextTime = _lastTime100!.add(const Duration(hours: 5));
      final diff = nextTime.difference(now);
      _remainingCooldown100 = diff.isNegative ? Duration.zero : diff;
    }

    // 4. Multi-Ad 200 Cooldown (10 Hours)
    if (_lastTime200 == null) {
      _remainingCooldown200 = Duration.zero;
    } else {
      final nextTime = _lastTime200!.add(const Duration(hours: 10));
      final diff = nextTime.difference(now);
      _remainingCooldown200 = diff.isNegative ? Duration.zero : diff;
    }

    // 5. Multi-Ad 500 Cooldown (12 Hours)
    if (_lastTime500 == null) {
      _remainingCooldown500 = Duration.zero;
    } else {
      final nextTime = _lastTime500!.add(const Duration(hours: 12));
      final diff = nextTime.difference(now);
      _remainingCooldown500 = diff.isNegative ? Duration.zero : diff;
    }

    setState(() {});
  }

  Future<void> _claimDailyGift(Offset startPos) async {
    AudioManager.instance.playClick();
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setInt('last_daily_gift_timestamp', now.millisecondsSinceEpoch);

    final claimableAt = now.add(const Duration(hours: 24));
    NotificationService.instance.scheduleDailyGiftReminder(claimableAt);

    setState(() {
      _lastDailyGiftTime = now;
      _remainingGiftCooldown = const Duration(hours: 24);
    });

    _triggerCoinCollectAnimation(startPos, 50);
  }

  // ── 1-Ad Watch for 50 Coins ───────────────────────────────────────────────
  void _watchAdFor50Coins() {
    AudioManager.instance.playClick();
    final adManager = context.read<AdManager>();

    adManager.showRewardedWithLoader(
      context,
      onRewarded: () {
        if (mounted) {
          setState(() {
            _isSingleAdClaimable = true;
          });
        }
      },
    );
  }

  Future<void> _claimSingleAd50Coins(Offset startPos) async {
    AudioManager.instance.playClick();
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setInt('last_single_ad_coin_timestamp', now.millisecondsSinceEpoch);

    final claimableAt = now.add(const Duration(hours: 4));
    NotificationService.instance.scheduleFreeCoinsReminder(claimableAt);

    setState(() {
      _isSingleAdClaimable = false;
      _lastSingleAdTime = now;
      _remainingSingleAdCooldown = const Duration(hours: 4);
    });

    _triggerCoinCollectAnimation(startPos, 50);
  }

  // ── Multi-Ad Offer Handlers ───────────────────────────────────────────────
  void _watchAdForOffer(int offerCoins, int requiredAds, Offset startPos) {
    AudioManager.instance.playClick();
    final adManager = context.read<AdManager>();

    bool userEarnedReward = false;

    adManager.showRewardedWithLoader(
      context,
      onRewarded: () {
        userEarnedReward = true;
      },
      onDismissed: () {
        if (!mounted || !userEarnedReward) return;

        bool autoClaim = false;
        int currentAds = 0;

        setState(() {
          if (offerCoins == 100) {
            _adProgress100 = (_adProgress100 + 1).clamp(0, requiredAds);
            currentAds = _adProgress100;
            if (_adProgress100 >= requiredAds) autoClaim = true;
          } else if (offerCoins == 200) {
            _adProgress200 = (_adProgress200 + 1).clamp(0, requiredAds);
            currentAds = _adProgress200;
            if (_adProgress200 >= requiredAds) autoClaim = true;
          } else if (offerCoins == 500) {
            _adProgress500 = (_adProgress500 + 1).clamp(0, requiredAds);
            currentAds = _adProgress500;
            if (_adProgress500 >= requiredAds) autoClaim = true;
          }
        });

        if (autoClaim) {
          _claimMultiAdReward(offerCoins, startPos);
        } else if (currentAds < requiredAds) {
          // Auto-load & show the next ad one-by-one automatically after user closes current ad!
          Future.delayed(const Duration(milliseconds: 400), () {
            if (mounted) {
              _watchAdForOffer(offerCoins, requiredAds, startPos);
            }
          });
        }
      },
    );
  }

  Future<void> _claimMultiAdReward(int offerCoins, Offset startPos) async {
    AudioManager.instance.playClick();
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    if (offerCoins == 100) {
      _adProgress100 = 0;
      _lastTime100 = now;
      _remainingCooldown100 = const Duration(hours: 5);
      await prefs.setInt('last_multi_ad_100_timestamp', now.millisecondsSinceEpoch);
    } else if (offerCoins == 200) {
      _adProgress200 = 0;
      _lastTime200 = now;
      _remainingCooldown200 = const Duration(hours: 10);
      await prefs.setInt('last_multi_ad_200_timestamp', now.millisecondsSinceEpoch);
    } else if (offerCoins == 500) {
      _adProgress500 = 0;
      _lastTime500 = now;
      _remainingCooldown500 = const Duration(hours: 12);
      await prefs.setInt('last_multi_ad_500_timestamp', now.millisecondsSinceEpoch);
    }

    setState(() {});
    _triggerCoinCollectAnimation(startPos, offerCoins);
  }

  // ── Flying Coin Particle Animation Launcher ───────────────────────────────
  void _triggerCoinCollectAnimation(Offset startPos, int amount) {
    // Measure header coin pill position
    final RenderBox? headerBox = _headerCoinKey.currentContext?.findRenderObject() as RenderBox?;
    final targetPos = headerBox != null
        ? headerBox.localToGlobal(Offset(headerBox.size.width / 2, headerBox.size.height / 2))
        : const Offset(100, 60);

    final random = math.Random();
    _flyingCoins.clear();
    AudioManager.instance.playCoinCollect();

    const particleCount = 10;
    for (int i = 0; i < particleCount; i++) {
      final delay = (i * 0.05).clamp(0.0, 0.4);
      final spreadX = (random.nextDouble() - 0.5) * 60;
      final spreadY = (random.nextDouble() - 0.5) * 40;

      // Curved control point for Bezier trajectory
      final start = Offset(startPos.dx + spreadX, startPos.dy + spreadY);
      final control = Offset(
        (start.dx + targetPos.dx) / 2 + (random.nextDouble() - 0.5) * 80,
        math.min(start.dy, targetPos.dy) - 50 - random.nextDouble() * 40,
      );

      _flyingCoins.add(_FlyingCoinParticle(
        startPos: start,
        controlPos: control,
        targetPos: targetPos,
        delay: delay,
        rotationSpeed: (random.nextDouble() - 0.5) * 4,
      ));
    }

    _coinAnimController.forward(from: 0.0);

    // Award coins in progress repository after animation finishes
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) {
        context.read<ProgressRepository>().addCoins(amount);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressRepository>();
    final bool canClaimDailyGift = _remainingGiftCooldown == Duration.zero;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Column(
              children: [
                // ── 1. Top Scalloped Awning Roof with Header Stats ─────────────
                _buildHeaderAwning(context, progress.coins, progress.lives),

                const SizedBox(height: 12),

                // ── 2. REWARD COINS OFFER LIST ────────────────────────────────
                Expanded(
                  child: ClipRect(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        children: [

                          const SizedBox(height: 14),

                          // ── Hearts & Lives Refill Section ──────────────────
                          _buildHeartsSection(context, progress),

                          // ── Offer 1: Watch 1 Ad -> 50 COINS FREE ──────────
                          _buildSingleAd50CoinsCard(
                            isClaimable: _isSingleAdClaimable,
                            remainingCooldown: _remainingSingleAdCooldown,
                            onWatchAd: () => _watchAdFor50Coins(),
                            onClaim: (startPos) => _claimSingleAd50Coins(startPos),
                          ),

                          const SizedBox(height: 14),

                          // ── Offer 2: Daily Gift 5h Countdown -> 50 COINS ───
                          _buildDailyGift50CoinsCard(
                            canClaim: canClaimDailyGift,
                            remaining: _remainingGiftCooldown,
                            onClaim: (startPos) => _claimDailyGift(startPos),
                          ),

                          const SizedBox(height: 18),

                          // ── Section Title Banner ──────────────────────────
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                context.tr('more_reward_offers'),
                                style: GoogleFonts.nunito(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textSecondary,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          // ── Multi-Ad Offers (100-3, 200-6, 500-10) ────────
                          _buildAdRewardCard(
                            title: context.tr('classic_bundle'),
                            coins: 100,
                            requiredAds: 3,
                            currentAds: _adProgress100,
                            remainingCooldown: _remainingCooldown100,
                            bgGradient: const [Color(0xFFD83C6E), Color(0xFFC22B5D)],
                            shadowColor: const Color(0xFF881337),
                            assetPath: 'assets/images/shop/coin.png',
                            onWatchAd: (startPos) => _watchAdForOffer(100, 3, startPos),
                            onClaim: (startPos) => _claimMultiAdReward(100, startPos),
                          ),

                          _buildAdRewardCard(
                            title: context.tr('elite_bundle'),
                            coins: 200,
                            requiredAds: 6,
                            currentAds: _adProgress200,
                            remainingCooldown: _remainingCooldown200,
                            bgGradient: const [Color(0xFFA83BE0), Color(0xFF8E25C7)],
                            shadowColor: const Color(0xFF581C87),
                            assetPath: 'assets/images/shop/coins.png',
                            onWatchAd: (startPos) => _watchAdForOffer(200, 6, startPos),
                            onClaim: (startPos) => _claimMultiAdReward(200, startPos),
                          ),

                          _buildAdRewardCard(
                            title: context.tr('epic_bundle'),
                            coins: 500,
                            requiredAds: 10,
                            currentAds: _adProgress500,
                            remainingCooldown: _remainingCooldown500,
                            bgGradient: const [Color(0xFF00A3E0), Color(0xFF0082B8)],
                            shadowColor: const Color(0xFF0E7490),
                            assetPath: 'assets/images/shop/coin pack.png',
                            onWatchAd: (startPos) => _watchAdForOffer(500, 10, startPos),
                            onClaim: (startPos) => _claimMultiAdReward(500, startPos),
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // ── 3. Flying 3D Coin Collect Overlay ─────────────────────────────
            if (_coinAnimController.isAnimating)
              Positioned.fill(
                child: IgnorePointer(
                  child: Stack(
                    children: _flyingCoins.map((particle) {
                      final pos = particle.evaluate(_coinAnimController.value);
                      final opacity = particle.opacity(_coinAnimController.value);
                      final scale = particle.scale(_coinAnimController.value);

                      return Positioned(
                        left: pos.dx - 14,
                        top: pos.dy - 14,
                        child: Opacity(
                          opacity: opacity,
                          child: Transform.scale(
                            scale: scale,
                            child: Transform.rotate(
                              angle: particle.rotationSpeed * _coinAnimController.value * math.pi,
                              child: Image.asset(
                                'assets/images/shop/coin.png',
                                width: 32,
                                height: 32,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  

  Widget _buildHeartsSection(BuildContext context, ProgressRepository progress) {
    final timerText = progress.formattedTimeUntilNextLife;
    final isFull = progress.lives >= progress.maxLives;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              'HEARTS & LIVES',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: AppColors.textSecondary,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF3366), Color(0xFFE60039)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color(0xFF990022),
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Image.asset(
                'assets/images/shop/hart.webp',
                width: 48,
                height: 48,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HEARTS REFILL',
                      style: GoogleFonts.nunito(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      isFull
                          ? 'Hearts are Full (${progress.lives}/${progress.maxLives})'
                          : timerText.isNotEmpty
                              ? 'Next heart in $timerText'
                              : '${progress.lives}/${progress.maxLives} Hearts remaining',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: isFull
                    ? null
                    : () async {
                        if (progress.coins >= AppConstants.heartCoinCost) {
                          final success = await progress.buyHeart();
                          if (success && context.mounted) {
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Purchased 1 Heart!',
                                  style: GoogleFonts.nunito(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                backgroundColor: const Color(0xFF27AE60),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Need ${AppConstants.heartCoinCost} coins to buy a heart!',
                                style: GoogleFonts.nunito(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              backgroundColor: const Color(0xFFC0392B),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isFull ? Colors.white30 : const Color(0xFFFFD700),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      if (!isFull)
                        const BoxShadow(
                          color: Color(0xFFB38600),
                          offset: Offset(0, 3),
                        ),
                    ],
                  ),
                  child: Text(
                    isFull ? 'FULL' : 'BUY 15 🪙',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: isFull ? Colors.white70 : const Color(0xFF5B3E00),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),
      ],
    );
  }

  // ── Card 1: 1-Ad Watch for 50 Coins ("50 COINS FREE" -> CLAIM -> 30m Countdown) ─
  Widget _buildSingleAd50CoinsCard({
    required bool isClaimable,
    required Duration remainingCooldown,
    required VoidCallback onWatchAd,
    required void Function(Offset startPos) onClaim,
  }) {
    final bool isOnCooldown = remainingCooldown > Duration.zero;
    final hoursStr = (remainingCooldown.inHours).toString().padLeft(2, '0');
    final minsStr = (remainingCooldown.inMinutes % 60).toString().padLeft(2, '0');
    final secsStr = (remainingCooldown.inSeconds % 60).toString().padLeft(2, '0');
    final formattedTime = remainingCooldown.inHours > 0
        ? '${hoursStr}h ${minsStr}m ${secsStr}s'
        : '${minsStr}m ${secsStr}s';

    return Builder(
      builder: (btnContext) {
        return Container(
          height: 68,
          decoration: BoxDecoration(
            color: const Color(0xFF1D4ED8),
            borderRadius: BorderRadius.circular(34),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 4),
                // 3D Coins Stack Image
                Image.asset(
                  'assets/images/shop/coins.png',
                  width: 52,
                  height: 52,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Image.asset(
                    'assets/images/shop/coin.png',
                    width: 52,
                    height: 52,
                  ),
                ),
                const SizedBox(width: 12),

                Text(
                  '50 COINS',
                  style: GoogleFonts.nunito(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),

                const Spacer(),

                // Green 3D CLAIM Button when ready OR 30m Countdown OR Purple FREE Button
                if (isClaimable)
                  GestureDetector(
                    onTap: () {
                      final RenderBox box = btnContext.findRenderObject() as RenderBox;
                      final pos = box.localToGlobal(Offset(box.size.width / 2, box.size.height / 2));
                      onClaim(pos);
                    },
                    child: Container(
                      width: 124,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFF15803D),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 3.5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4ADE80), Color(0xFF22C55E)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.7),
                            width: 1.2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'CLAIM',
                            style: GoogleFonts.nunito(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.8,
                              shadows: const [
                                Shadow(
                                  color: Colors.black38,
                                  offset: Offset(0, 1.5),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                else if (isOnCooldown)
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'NEXT IN',
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF93C5FD),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const _AnimatedClockIcon(size: 20),
                            const SizedBox(width: 7),
                            Text(
                              formattedTime,
                              style: GoogleFonts.nunito(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  GestureDetector(
                    onTap: () => onWatchAd(),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 124,
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFF7E22CE),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 3.5),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFC084FC), Color(0xFFA855F7)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.6),
                                width: 1.2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'FREE',
                                style: GoogleFonts.nunito(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // 3D Clapperboard Asset Badge on top-left of button
                        Positioned(
                          top: -12,
                          left: -6,
                          child: Image.asset(
                            'assets/images/shop/claper.png',
                            width: 32,
                            height: 32,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF009CFF),
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                              child: const Icon(
                                LucideIcons.video,
                                color: Colors.white,
                                size: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Card 2: Daily Gift 5-Hour Countdown ("DAILY GIFT 50 COINS") ──────────
  Widget _buildDailyGift50CoinsCard({
    required bool canClaim,
    required Duration remaining,
    required void Function(Offset startPos) onClaim,
  }) {
    final hoursStr = remaining.inHours.toString().padLeft(2, '0');
    final minsStr = (remaining.inMinutes % 60).toString().padLeft(2, '0');
    final secsStr = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    final formattedTime = remaining.inHours > 0
        ? '${hoursStr}h ${minsStr}m ${secsStr}s'
        : '${minsStr}m ${secsStr}s';

    return Builder(
      builder: (btnContext) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              height: 68,
              decoration: BoxDecoration(
                color: const Color(0xFF6B21A8),
                borderRadius: BorderRadius.circular(34),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9333EA), Color(0xFF7E22CE)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 4),
                    // 3D Coins Stack Image
                    Image.asset(
                      'assets/images/shop/coins.png',
                      width: 52,
                      height: 52,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Image.asset(
                        'assets/images/shop/coin.png',
                        width: 52,
                        height: 52,
                      ),
                    ),
                    const SizedBox(width: 12),

                    Text(
                      '50 COINS',
                      style: GoogleFonts.nunito(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),

                    const Spacer(),

                    // Green 3D Claim Button
                    if (canClaim)
                      GestureDetector(
                        onTap: () {
                          final RenderBox box = btnContext.findRenderObject() as RenderBox;
                          final pos = box.localToGlobal(Offset(box.size.width / 2, box.size.height / 2));
                          onClaim(pos);
                        },
                        child: Container(
                          width: 124,
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFF15803D),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 3.5),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4ADE80), Color(0xFF22C55E)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.7),
                                width: 1.2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'CLAIM',
                                style: GoogleFonts.nunito(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.8,
                                  shadows: const [
                                    Shadow(
                                      color: Colors.black38,
                                      offset: Offset(0, 1.5),
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'NEXT IN',
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFD8B4FE),
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const _AnimatedClockIcon(size: 20),
                                const SizedBox(width: 7),
                                Text(
                                  formattedTime,
                                  style: GoogleFonts.nunito(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),

            // Top Overlapping Badge Tab "DAILY GIFT"
            Positioned(
              top: -2,
              left: 78,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3.5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                    bottomLeft: Radius.circular(6),
                    bottomRight: Radius.circular(6),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  'DAILY GIFT',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF2563EB),
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Multi-Ad Reward Card Helper Widget (Clean Clutter-Free Design) ───────
  Widget _buildAdRewardCard({
    required String title,
    required int coins,
    required int requiredAds,
    required int currentAds,
    required Duration remainingCooldown,
    required List<Color> bgGradient,
    required Color shadowColor,
    required String assetPath,
    String? badgeText,
    required void Function(Offset startPos) onWatchAd,
    required void Function(Offset startPos) onClaim,
  }) {
    final bool isOnCooldown = remainingCooldown > Duration.zero;
    final bool isReadyToClaim = !isOnCooldown && currentAds >= requiredAds;
    final double progressPercent = (currentAds / requiredAds).clamp(0.0, 1.0);

    final hoursStr = remainingCooldown.inHours.toString().padLeft(2, '0');
    final minsStr = (remainingCooldown.inMinutes % 60).toString().padLeft(2, '0');
    final secsStr = (remainingCooldown.inSeconds % 60).toString().padLeft(2, '0');
    final formattedTime = remainingCooldown.inHours > 0
        ? '${hoursStr}h ${minsStr}m ${secsStr}s'
        : '${minsStr}m ${secsStr}s';

    return Builder(
      builder: (btnContext) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              height: 78,
              decoration: BoxDecoration(
                color: shadowColor,
                borderRadius: BorderRadius.circular(36),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: bgGradient,
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(34),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 2),
                    // Left 3D Asset
                    Image.asset(
                      assetPath,
                      width: 54,
                      height: 54,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Image.asset(
                        'assets/images/shop/coin.png',
                        width: 54,
                        height: 54,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Center Details: Coins & Ad Progress Bar
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$coins COINS',
                            style: GoogleFonts.nunito(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),

                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: progressPercent,
                                    minHeight: 10,
                                    backgroundColor: Colors.black.withValues(alpha: 0.25),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isReadyToClaim ? const Color(0xFFFFD600) : const Color(0xFF4ADE80),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$currentAds/$requiredAds Ads',
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Cooldown Countdown Timer OR Action Button
                    if (isOnCooldown)
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'NEXT IN',
                            style: GoogleFonts.nunito(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.white70,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const _AnimatedClockIcon(size: 16),
                                const SizedBox(width: 5),
                                Text(
                                  formattedTime,
                                  style: GoogleFonts.nunito(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    else
                      GestureDetector(
                        onTap: () {
                          final RenderBox box = btnContext.findRenderObject() as RenderBox;
                          final pos = box.localToGlobal(Offset(box.size.width / 2, box.size.height / 2));
                          if (isReadyToClaim) {
                            onClaim(pos);
                          } else {
                            onWatchAd(pos);
                          }
                        },
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF15803D),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 3.5),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4ADE80), Color(0xFF22C55E)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.7),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isReadyToClaim ? LucideIcons.sparkles : LucideIcons.video,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isReadyToClaim ? 'CLAIM!' : 'WATCH',
                                  style: GoogleFonts.nunito(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.6,
                                    shadows: const [
                                      Shadow(
                                        color: Colors.black38,
                                        offset: Offset(0, 1.5),
                                        blurRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Top Badge Tab (e.g. 200% EXTRA or BEST VALUE)
            if (badgeText != null)
              Positioned(
                top: -2,
                left: 72,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF2A6D),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: Colors.white, width: 1),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    badgeText,
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // ── Header Awning Widget with GlobalKey for Flying Coins Destination ─────
  Widget _buildHeaderAwning(BuildContext context, int userCoins, int livesCount) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        SizedBox(
          height: 82,
          width: double.infinity,
          child: CustomPaint(
            painter: _StoreAwningPainter(),
          ),
        ),

        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Coins Pill with Scale Pulse Animation Key
              AnimatedScale(
                scale: _isHeaderPillPulsing ? 1.25 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: KeyedSubtree(
                  key: _headerCoinKey,
                  child: _buildAwningPill(
                    assetPath: 'assets/images/shop/coin.png',
                    text: '$userCoins',
                    showPlusBadge: false,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Hearts / Lives Pill matching Home Screen Header
              _buildAwningPill(
                assetPath: 'assets/images/shop/hart.webp',
                text: '$livesCount',
                overlayText: '$livesCount',
                showPlusBadge: false,
              ),
            ],
          ),
        ),

      ],
    );
  }

  Widget _buildAwningPill({
    required String assetPath,
    required String text,
    bool showPlusBadge = false,
    String? overlayText,
  }) {
    return Stack(
      alignment: Alignment.centerLeft,
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 36,
          margin: const EdgeInsets.only(left: 14),
          padding: const EdgeInsets.only(left: 28, right: 14),
          decoration: BoxDecoration(
            color: AppColors.headerPillBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.headerPillBorder,
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              text,
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),

        Positioned(
          left: 0,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Image.asset(
                assetPath,
                width: 36,
                height: 36,
                fit: BoxFit.contain,
              ),

              if (overlayText != null)
                Text(
                  overlayText,
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.8),
                        offset: const Offset(0, 1.5),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                ),

              if (showPlusBadge)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF22C55E),
                      border: Border.all(color: Colors.white, width: 1.2),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 9,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FlyingCoinParticle {
  final Offset startPos;
  final Offset controlPos;
  final Offset targetPos;
  final double delay;
  final double rotationSpeed;

  _FlyingCoinParticle({
    required this.startPos,
    required this.controlPos,
    required this.targetPos,
    required this.delay,
    required this.rotationSpeed,
  });

  Offset evaluate(double animValue) {
    if (animValue <= delay) return startPos;
    final t = ((animValue - delay) / (1.0 - delay)).clamp(0.0, 1.0);
    final u = 1 - t;

    // Quadratic Bezier curve: B(t) = (1-t)^2 * P0 + 2(1-t)t * P1 + t^2 * P2
    final x = u * u * startPos.dx + 2 * u * t * controlPos.dx + t * t * targetPos.dx;
    final y = u * u * startPos.dy + 2 * u * t * controlPos.dy + t * t * targetPos.dy;
    return Offset(x, y);
  }

  double opacity(double animValue) {
    if (animValue <= delay) return 0.0;
    final t = ((animValue - delay) / (1.0 - delay)).clamp(0.0, 1.0);
    if (t < 0.15) return t / 0.15;
    if (t > 0.85) return (1.0 - t) / 0.15;
    return 1.0;
  }

  double scale(double animValue) {
    if (animValue <= delay) return 0.2;
    final t = ((animValue - delay) / (1.0 - delay)).clamp(0.0, 1.0);
    if (t < 0.3) return 0.2 + (t / 0.3) * 0.9; // Scale up
    if (t > 0.7) return 1.1 - ((t - 0.7) / 0.3) * 0.7; // Scale down near target
    return 1.1;
  }
}

class _AnimatedClockIcon extends StatefulWidget {
  final double size;

  const _AnimatedClockIcon({this.size = 20.0});

  @override
  State<_AnimatedClockIcon> createState() => _AnimatedClockIconState();
}

class _AnimatedClockIconState extends State<_AnimatedClockIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final innerSize = size * 0.70;

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFEC4899),
      ),
      child: Center(
        child: Container(
          width: innerSize,
          height: innerSize,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF831843),
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.rotate(
                angle: _controller.value * 2 * math.pi,
                child: Center(
                  child: Container(
                    margin: EdgeInsets.only(left: innerSize * 0.25),
                    width: innerSize * 0.40,
                    height: innerSize * 0.18,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2.0),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StoreAwningPainter extends CustomPainter {
  final bool isDark = AppColors.isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const stripes = 8;
    final stripeW = w / stripes;

    final colorLight = isDark ? const Color(0xFF2C4875) : const Color(0xFFD4E5FF);
    final colorDark = isDark ? const Color(0xFF162540) : const Color(0xFF355B96);

    for (int i = 0; i < stripes; i++) {
      final paint = Paint()..color = (i % 2 == 0) ? colorLight : colorDark;
      final x = i * stripeW;

      final path = Path()
        ..moveTo(x, 0)
        ..lineTo(x + stripeW, 0)
        ..lineTo(x + stripeW, h - 14)
        ..arcToPoint(
          Offset(x, h - 14),
          radius: Radius.circular(stripeW / 2),
          clockwise: true,
        )
        ..close();

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StoreAwningPainter oldDelegate) => oldDelegate.isDark != isDark;
}
