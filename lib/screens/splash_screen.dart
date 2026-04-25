import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pstream_android/config/app_theme.dart';

/// First paint after cold start; hands off to the main shell.
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
    final double logoWidth = MediaQuery.sizeOf(context).shortestSide * 0.42;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              AppColors.blackC50,
              AppColors.splashGradientMid,
              AppColors.splashGradientEnd,
            ],
            stops: <double>[0, 0.48, 1],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                RepaintBoundary(
                  child: Image.asset(
                    'logo.png',
                    width: logoWidth,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                    errorBuilder:
                        (BuildContext context, Object error, StackTrace? st) {
                          return _VeilMark(
                            size:
                                MediaQuery.sizeOf(context).shortestSide * 0.18,
                          );
                        },
                  ),
                ),
                const SizedBox(height: AppSpacing.x5),
                Text(
                  'Veil',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: AppColors.typeEmphasis,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: AppSpacing.x2),
                Text(
                  'Browse. Resume. Watch.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.typeSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fallback mark when `logo.png` is missing or fails to decode.
class _VeilMark extends StatelessWidget {
  const _VeilMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.typeEmphasis, width: 3),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.splashGradientEnd.withValues(alpha: 0.45),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Text(
            'V',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              color: AppColors.typeEmphasis,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
