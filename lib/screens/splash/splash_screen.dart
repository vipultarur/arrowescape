import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/menu');
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/logo/splesh screen.png'), context);
    precacheImage(const AssetImage('assets/images/nav/cart.webp'), context);
    precacheImage(const AssetImage('assets/images/nav/home2.webp'), context);
    precacheImage(const AssetImage('assets/images/nav/setting.png'), context);
    precacheImage(const AssetImage('assets/images/nav/daily.png'), context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SizedBox.expand(
        child: Image.asset(
          'assets/logo/splesh screen.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
