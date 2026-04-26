import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:pstream_android/config/app_theme.dart';
import 'package:pstream_android/config/breakpoints.dart';

/// First paint after cold start; hands off to the main shell.
///
/// Layered composition:
///   1. `assets/bg.png` cover-fitted (purple cracked texture)
///   2. dark scrim to mute brightness and lift contrast
///   3. radial glow + bottom gradient toward [AppColors.blackC100]
///   4. centered transparent `assets/logo1.png` + tagline
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const Duration displayDuration = Duration(milliseconds: 1800);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(SplashScreen.displayDuration, () {
      if (!mounted) {
        return;
      }
      context.replace('/');
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final WindowClass layout = windowClass(context);
    final double shortest = MediaQuery.sizeOf(context).shortestSide;
    final double logoWidth = switch (layout) {
      WindowClass.compact => shortest * 0.46,
      WindowClass.medium => shortest * 0.34,
      WindowClass.expanded => shortest * 0.26,
    };

    return Scaffold(
      backgroundColor: AppColors.blackC50,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Layer 1: textured purple background scaled to fill screen.
          const Image(
            image: AssetImage('assets/bg.png'),
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.medium,
          ),
          // Layer 2: dark scrim — keeps purple but lifts foreground contrast.
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.blackC50.withValues(alpha: 0.45),
            ),
          ),
          // Layer 3: centered radial glow + bottom fade for legibility.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.9,
                colors: <Color>[
                  AppColors.purpleC700.withValues(alpha: 0.35),
                  AppColors.transparent,
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  AppColors.transparent,
                  AppColors.transparent,
                  AppColors.blackC100.withValues(alpha: 0.85),
                ],
                stops: const <double>[0, 0.55, 1],
              ),
            ),
          ),
          // Layer 4: logo + tagline.
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  RepaintBoundary(
                    child: Image.asset(
                      'assets/logo1.png',
                      width: logoWidth,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                      errorBuilder:
                          (BuildContext context, Object error, StackTrace? st) {
                        return Text(
                          'Veil',
                          style:
                              Theme.of(context).textTheme.displayMedium?.copyWith(
                                    color: AppColors.typeLogo,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -1.2,
                                  ),
                        );
                      },
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 350.ms, curve: Curves.easeOut)
                      .scale(
                        begin: const Offset(0.92, 0.92),
                        end: const Offset(1, 1),
                        duration: 350.ms,
                        curve: Curves.easeOut,
                      ),
                  const SizedBox(height: AppSpacing.x5),
                  Text(
                    'Browse. Resume. Watch.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.typeEmphasis.withValues(alpha: 0.78),
                          letterSpacing: 0.2,
                        ),
                  ).animate().fadeIn(
                        delay: 200.ms,
                        duration: 300.ms,
                        curve: Curves.easeOut,
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
