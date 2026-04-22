import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

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

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                _StatusCircle(status: status),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    sourceName,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            if (embeds.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: Column(
                  children: List<Widget>.generate(embeds.length, (int index) {
                    final ScrapeEmbedItem embed = embeds[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == embeds.length - 1 ? 0 : 10,
                      ),
                      child: Row(
                        children: <Widget>[
                          _StatusCircle(
                            status: embed.status,
                            size: 18,
                            strokeWidth: 2.5,
                          ),
                          const SizedBox(width: 10),
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
    this.size = 24,
    this.strokeWidth = 3,
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
            color: Colors.grey.shade500,
            strokeWidth: strokeWidth,
            child: const SizedBox.shrink(),
          ),
        ScrapeStatus.pending => _PendingCircle(
            size: size,
            strokeWidth: strokeWidth,
          ),
        ScrapeStatus.success => _BaseCircle(
            color: Colors.green,
            strokeWidth: strokeWidth,
            fillColor: Colors.green,
            child: Icon(
              Icons.check,
              size: size * 0.6,
              color: Colors.white,
            ),
          ),
        ScrapeStatus.failure => _BaseCircle(
            color: Colors.red,
            strokeWidth: strokeWidth,
            fillColor: Colors.red,
            child: Icon(
              Icons.close,
              size: size * 0.6,
              color: Colors.white,
            ),
          ),
        ScrapeStatus.notfound => _BaseCircle(
            color: Colors.red.shade300,
            strokeWidth: strokeWidth,
            fillColor: Colors.red.shade300,
            child: Icon(
              Icons.close,
              size: size * 0.6,
              color: Colors.white,
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
          color: const Color(0xFF8F5BFF),
          width: strokeWidth,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(
            colors: <Color>[
              const Color(0xFF8F5BFF).withValues(alpha: 0.15),
              const Color(0xFF8F5BFF),
              const Color(0xFF8F5BFF).withValues(alpha: 0.15),
            ],
          ),
        ),
        child: SizedBox.square(dimension: size),
      ),
    )
        .animate(onPlay: (AnimationController controller) => controller.repeat())
        .shimmer(
          duration: 900.ms,
          color: const Color(0xFFB9A1FF),
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
