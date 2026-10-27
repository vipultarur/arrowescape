import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import '../core/constants.dart';

class UnifiedBannerAd extends StatefulWidget {
  final String admobUnitId;
  final String unityPlacementId;

  const UnifiedBannerAd({
    super.key,
    required this.admobUnitId,
    required this.unityPlacementId,
  });

  @override
  State<UnifiedBannerAd> createState() => _UnifiedBannerAdState();
}

class _UnifiedBannerAdState extends State<UnifiedBannerAd> {
  BannerAd? _admobBanner;
  bool _admobLoaded = false;
  bool _admobFailed = false;
  Timer? _retryTimer;
  AdSize? _adSize;

  @override
  void initState() {
    super.initState();
    if (AppConstants.enableAdMob) {
      _loadAdmobBanner();
    } else {
      _admobFailed = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppConstants.enableAdMob && _adSize == null) {
      _setAdSize();
    }
  }

  Future<void> _setAdSize() async {
    final width = MediaQuery.of(context).size.width.truncate();
    if (width > 0) {
      final AnchoredAdaptiveBannerAdSize? size =
          await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
      if (mounted && size != null) {
        setState(() {
          _adSize = size;
        });
      }
    }
  }

  void _loadAdmobBanner() {
    _retryTimer?.cancel();
    _admobBanner?.dispose();
    _admobBanner = null;

    final targetSize = _adSize ?? AdSize.banner;

    _admobBanner = BannerAd(
      adUnitId: widget.admobUnitId,
      size: targetSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _admobLoaded = true;
              _admobFailed = false;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('AdMob Banner failed to load: $error');
          ad.dispose();
          _admobBanner = null;
          if (mounted) {
            setState(() {
              _admobLoaded = false;
              _admobFailed = true;
            });
            // Automatically retry after 10 seconds
            _retryTimer = Timer(const Duration(seconds: 10), () {
              if (mounted) {
                _loadAdmobBanner();
              }
            });
          }
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _admobBanner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. AdMob (Priority 1)
    if (AppConstants.enableAdMob) {
      if (_admobLoaded && _admobBanner != null) {
        final double adWidth = _admobBanner!.size.width.toDouble();
        final double adHeight = _admobBanner!.size.height.toDouble();
        return SizedBox(
          width: adWidth > 0 ? adWidth : 320.0,
          height: adHeight > 0 ? adHeight : 50.0,
          child: AdWidget(ad: _admobBanner!),
        );
      } else if (!_admobFailed) {
        // Loading placeholder space
        return const SizedBox(
          width: 320,
          height: 50,
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      }
    }

    // 2. Unity Ads (Priority 2)
    if (AppConstants.enableUnityAds) {
      return SizedBox(
        width: 320,
        height: 50,
        child: UnityBannerAd(
          placementId: widget.unityPlacementId,
          onFailed: (placementId, error, message) {
            debugPrint('Unity Banner failed: $error - $message');
          },
        ),
      );
    }

    // If no ad network is active or ad failed, reserve minimal safe height
    return const SizedBox(height: 50);
  }
}
