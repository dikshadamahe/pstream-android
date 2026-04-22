import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pstream_android/config/app_theme.dart';

enum ScrapeStatus {
  waiting,
  pending,
  success,
  failure,
  notfound,
}

class ScrapeSourceCard extends StatelessWidget {
  const ScrapeSourceCard({
    super.key,
    required this.sourceName,
    required this.status,
    this.embeds = const <ScrapeEmbedItem>[],
  });

  final String sourceName;
  final ScrapeStatus status;
  final List<ScrapeEmbedItem> embeds;
  static const double estimatedHeight = AppSpacing.x16 + AppSpacing.x12;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.x2),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                _StatusCircle(status: status),
                const SizedBox(width: AppSpacing.x3),
                Expanded(
                  child: Text(
                    sourceName,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            if (embeds.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.x3),
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.x10),
                child: Column(
                  children: List<Widget>.generate(embeds.length, (int index) {
                    final ScrapeEmbedItem embed = embeds[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == embeds.length - 1
                            ? AppSpacing.x0
                            : AppSpacing.x2,
                      ),
                      child: Row(
                        children: <Widget>[
                          _StatusCircle(
                            status: embed.status,
                            size: AppSpacing.x5,
                            strokeWidth: AppSpacing.x1,
                          ),
                          const SizedBox(width: AppSpacing.x2),
                          Expanded(
                            child: Text(
                              embed.name,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ScrapeEmbedItem {
  const ScrapeEmbedItem({
    required this.name,
    required this.status,
  });

  final String name;
  final ScrapeStatus status;
}

class _StatusCircle extends StatelessWidget {
  const _StatusCircle({
    required this.status,
    this.size = AppSpacing.x6,
    this.strokeWidth = AppSpacing.x1,
  });

  final ScrapeStatus status;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final Widget circle = SizedBox.square(
      dimension: size,
      child: switch (status) {
        ScrapeStatus.waiting => _BaseCircle(
            color: AppColors.videoScrapingNoresult,
            strokeWidth: strokeWidth,
            child: const SizedBox.shrink(),
          ),
        ScrapeStatus.pending => _PendingCircle(
            size: size,
            strokeWidth: strokeWidth,
          ),
        ScrapeStatus.success => _BaseCircle(
            color: AppColors.videoScrapingSuccess,
            strokeWidth: strokeWidth,
            fillColor: AppColors.videoScrapingSuccess,
            child: Icon(
              Icons.check,
              size: size * 0.6,
              color: AppColors.typeEmphasis,
            ),
          ),
        ScrapeStatus.failure => _BaseCircle(
            color: AppColors.videoScrapingError,
            strokeWidth: strokeWidth,
            fillColor: AppColors.videoScrapingError,
            child: Icon(
              Icons.close,
              size: size * 0.6,
              color: AppColors.typeEmphasis,
            ),
          ),
        ScrapeStatus.notfound => _BaseCircle(
            color: AppColors.videoScrapingError,
            strokeWidth: strokeWidth,
            fillColor: AppColors.videoScrapingError,
            child: Icon(
              Icons.close,
              size: size * 0.6,
              color: AppColors.typeEmphasis,
            ),
          ),
      },
    );

    return RepaintBoundary(child: circle);
  }
}

class _PendingCircle extends StatelessWidget {
  const _PendingCircle({
    required this.size,
    required this.strokeWidth,
  });

  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.videoScrapingLoading,
          width: strokeWidth,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(
            colors: <Color>[
              AppColors.videoScrapingLoading.withValues(alpha: 0.15),
              AppColors.videoScrapingLoading,
              AppColors.videoScrapingLoading.withValues(alpha: 0.15),
            ],
          ),
        ),
        child: SizedBox.square(dimension: size),
      ),
    )
        .animate(onPlay: (AnimationController controller) => controller.repeat())
        .shimmer(
          duration: 1.seconds,
          color: AppColors.typeLink,
        );
  }
}

class _BaseCircle extends StatelessWidget {
  const _BaseCircle({
    required this.color,
    required this.strokeWidth,
    required this.child,
    this.fillColor,
  });

  final Color color;
  final Color? fillColor;
  final double strokeWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fillColor,
        border: Border.all(
          color: color,
          width: strokeWidth,
        ),
      ),
      child: Center(child: child),
    );
  }
}
