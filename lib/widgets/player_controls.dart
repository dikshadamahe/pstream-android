import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:pstream_android/config/app_theme.dart';

class PlayerControls extends StatelessWidget {
  const PlayerControls({
    super.key,
    required this.visible,
    required this.mediaTitle,
    required this.sourceLabel,
    required this.qualityLabel,
    required this.subtitleLabel,
    required this.volumeLabel,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.buffered,
    required this.showNextEpisode,
    required this.onBack,
    required this.onPlayPause,
    required this.onSeekBack,
    required this.onSeekForward,
    required this.onSeek,
    required this.onOpenSettings,
    required this.onOpenBrightness,
    required this.onOpenVolume,
    required this.onFullscreen,
    required this.onNextEpisode,
    this.nextEpisodeLabel,
  });

  final bool visible;
  final String mediaTitle;
  final String sourceLabel;
  final String qualityLabel;
  final String subtitleLabel;
  final String volumeLabel;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final Duration buffered;
  final bool showNextEpisode;
  final VoidCallback onBack;
  final Future<void> Function() onPlayPause;
  final Future<void> Function() onSeekBack;
  final Future<void> Function() onSeekForward;
  final Future<void> Function(double fraction) onSeek;
  final Future<void> Function() onOpenSettings;
  final Future<void> Function() onOpenBrightness;
  final Future<void> Function() onOpenVolume;
  final Future<void> Function() onFullscreen;
  final Future<void> Function() onNextEpisode;
  final String? nextEpisodeLabel;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: RepaintBoundary(
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Positioned(
                left: AppSpacing.x4,
                right: AppSpacing.x4,
                top: AppSpacing.x4,
                child: _GlassContainer(
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: AppSpacing.x2),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              mediaTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: AppSpacing.x1),
                            Text(
                              sourceLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          onOpenSettings();
                        },
                        icon: const Icon(Icons.tune_rounded),
                        tooltip: 'Playback settings',
                      ),
                    ],
                  ),
                ),
              ),
              Center(
                child: RepaintBoundary(
                  child: _GlassContainer(
                    borderRadius: BorderRadius.circular(AppSpacing.x16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.x4,
                      vertical: AppSpacing.x3,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IconButton(
                          onPressed: () {
                            onSeekBack();
                          },
                          iconSize: AppSpacing.x8,
                          icon: const Icon(Icons.replay_10_rounded),
                        ),
                        const SizedBox(width: AppSpacing.x2),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(AppSpacing.x4),
                            backgroundColor: AppColors.buttonsPurple,
                          ),
                          onPressed: () {
                            onPlayPause();
                          },
                          child: Icon(
                            isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: AppSpacing.x10,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.x2),
                        IconButton(
                          onPressed: () {
                            onSeekForward();
                          },
                          iconSize: AppSpacing.x8,
                          icon: const Icon(Icons.forward_10_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: AppSpacing.x4,
                right: AppSpacing.x4,
                bottom: AppSpacing.x4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Wrap(
                      spacing: AppSpacing.x2,
                      runSpacing: AppSpacing.x2,
                      children: <Widget>[
                        _InfoChip(
                          icon: Icons.wifi_tethering_rounded,
                          label: sourceLabel,
                        ),
                        _InfoChip(
                          icon: Icons.high_quality_rounded,
                          label: qualityLabel,
                        ),
                        _InfoChip(
                          icon: Icons.subtitles_rounded,
                          label: subtitleLabel,
                        ),
                        _InfoChip(
                          icon: Icons.volume_up_rounded,
                          label: volumeLabel,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.x3),
                    if (showNextEpisode)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.x3),
                        child: RepaintBoundary(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: _GlassActionButton(
                              icon: Icons.skip_next_rounded,
                              label: nextEpisodeLabel == null
                                  ? 'Next Episode'
                                  : 'Next Episode - $nextEpisodeLabel',
                              onPressed: onNextEpisode,
                            ),
                          ),
                        ),
                      ),
                    _GlassContainer(
                      child: Column(
                        children: <Widget>[
                          _SeekBar(
                            position: position,
                            duration: duration,
                            buffered: buffered,
                            onSeek: onSeek,
                          ),
                          const SizedBox(height: AppSpacing.x3),
                          Row(
                            children: <Widget>[
                              Text(
                                _formatDuration(position),
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                              const SizedBox(width: AppSpacing.x2),
                              Text(
                                '/ ${_formatDuration(duration)}',
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () {
                                  unawaited(onOpenBrightness());
                                },
                                icon: const Icon(Icons.brightness_6_rounded),
                                tooltip: 'Brightness',
                              ),
                              IconButton(
                                onPressed: () {
                                  unawaited(onOpenVolume());
                                },
                                icon: const Icon(Icons.volume_up_rounded),
                                tooltip: 'Volume',
                              ),
                              IconButton(
                                onPressed: () {
                                  onOpenSettings();
                                },
                                icon: const Icon(Icons.settings_outlined),
                                tooltip: 'Settings',
                              ),
                              IconButton(
                                onPressed: () {
                                  onFullscreen();
                                },
                                icon: const Icon(Icons.fullscreen_rounded),
                                tooltip: 'Fullscreen',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration value) {
    final int totalSeconds = value.inSeconds;
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }

    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class PlayerInfoPill extends StatelessWidget {
  const PlayerInfoPill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return _GlassContainer(
      borderRadius: BorderRadius.circular(AppSpacing.x10),
      child: Text(label, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return _GlassContainer(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x3,
        vertical: AppSpacing.x2,
      ),
      borderRadius: BorderRadius.circular(AppSpacing.x10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: AppSpacing.x4, color: AppColors.typeSecondary),
          const SizedBox(width: AppSpacing.x2),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.3,
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _SeekBar extends StatelessWidget {
  const _SeekBar({
    required this.position,
    required this.duration,
    required this.buffered,
    required this.onSeek,
  });

  final Duration position;
  final Duration duration;
  final Duration buffered;
  final Future<void> Function(double fraction) onSeek;

  @override
  Widget build(BuildContext context) {
    final double totalMs = duration.inMilliseconds.toDouble();
    final double bufferedFraction = totalMs <= 0
        ? 0
        : (buffered.inMilliseconds / totalMs).clamp(0, 1).toDouble();
    final double playedFraction = totalMs <= 0
        ? 0
        : (position.inMilliseconds / totalMs).clamp(0, 1).toDouble();

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (TapDownDetails details) {
              final double fraction =
                  (details.localPosition.dx / constraints.maxWidth)
                      .clamp(0, 1)
                      .toDouble();
              onSeek(fraction);
            },
            onHorizontalDragUpdate: (DragUpdateDetails details) {
              final double fraction =
                  (details.localPosition.dx / constraints.maxWidth)
                      .clamp(0, 1)
                      .toDouble();
              onSeek(fraction);
            },
            child: SizedBox(
              height: AppSpacing.x12,
              child: Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Container(
                      height: AppSpacing.x1,
                      decoration: BoxDecoration(
                        color: AppColors.progressBackground.withValues(
                          alpha: 0.35,
                        ),
                        borderRadius: BorderRadius.circular(AppSpacing.x2),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: bufferedFraction,
                      child: Container(
                        height: AppSpacing.x1,
                        decoration: BoxDecoration(
                          color: AppColors.semanticSilverC400,
                          borderRadius: BorderRadius.circular(AppSpacing.x2),
                        ),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: playedFraction,
                      child: Container(
                        height: AppSpacing.x1,
                        decoration: BoxDecoration(
                          color: AppColors.progressFilled,
                          borderRadius: BorderRadius.circular(AppSpacing.x2),
                        ),
                      ),
                    ),
                    Positioned(
                      left:
                          (constraints.maxWidth * playedFraction) -
                          AppSpacing.x2,
                      top: -AppSpacing.x2,
                      child: Container(
                        width: AppSpacing.x4,
                        height: AppSpacing.x4,
                        decoration: const BoxDecoration(
                          color: AppColors.progressFilled,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GlassActionButton extends StatelessWidget {
  const _GlassActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return _GlassContainer(
      borderRadius: BorderRadius.circular(AppSpacing.x10),
      child: TextButton.icon(
        onPressed: () {
          onPressed();
        },
        icon: Icon(icon, color: AppColors.typeEmphasis),
        label: Text(label),
      ),
    );
  }
}

class _GlassContainer extends StatelessWidget {
  const _GlassContainer({
    required this.child,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.x4,
      vertical: AppSpacing.x3,
    ),
    this.borderRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final BorderRadius effectiveRadius =
        borderRadius ?? BorderRadius.circular(AppSpacing.x4);

    return ClipRRect(
      borderRadius: effectiveRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: AppSpacing.x5, sigmaY: AppSpacing.x5),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.videoContextBackground.withValues(alpha: 0.62),
            borderRadius: effectiveRadius,
            border: Border.all(
              color: AppColors.videoContextBorder.withValues(alpha: 0.7),
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
