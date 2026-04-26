import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pstream_android/config/app_theme.dart';
import 'package:pstream_android/config/breakpoints.dart';
import 'package:pstream_android/providers/storage_provider.dart';
import 'package:pstream_android/storage/local_storage.dart';

/// Read-only summary derived from [LocalStorage.getWatchStats]. No new
/// persistence: numbers come from the existing progress / history /
/// bookmarks Hive boxes.
class WatchStatsScreen extends ConsumerWidget {
  const WatchStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final WatchStats stats = ref.watch(watchStatsProvider);
    final double horizontal = switch (windowClass(context)) {
      WindowClass.compact => AppSpacing.x4,
      WindowClass.medium => AppSpacing.x5,
      WindowClass.expanded => AppSpacing.x6,
    };

    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      appBar: AppBar(
        title: const Text('Watch statistics'),
        backgroundColor: AppColors.backgroundMain,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            AppSpacing.x4,
            horizontal,
            AppSpacing.x6,
          ),
          children: <Widget>[
            _StatHeroCard(stats: stats),
            const SizedBox(height: AppSpacing.x4),
            _StatGrid(stats: stats),
            const SizedBox(height: AppSpacing.x4),
            _StatFootnote(),
          ],
        ),
      ),
    );
  }
}

class _StatHeroCard extends StatelessWidget {
  const _StatHeroCard({required this.stats});

  final WatchStats stats;

  String _formatTotal(Duration total) {
    if (total.inMinutes < 1) {
      return '0 min';
    }
    final int hours = total.inHours;
    final int minutes = total.inMinutes.remainder(60);
    if (hours <= 0) {
      return '$minutes min';
    }
    if (minutes == 0) {
      return '$hours hr';
    }
    return '$hours hr $minutes min';
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.x5),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.blackC125,
            AppColors.blackC100,
            AppColors.purpleC900.withValues(alpha: 0.95),
          ],
        ),
        border: Border.all(color: AppColors.settingsCardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Total time watched',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.typeSecondary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: AppSpacing.x2),
            Text(
              _formatTotal(stats.totalWatched),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: AppColors.typeEmphasis,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                  ),
            ),
            const SizedBox(height: AppSpacing.x2),
            Text(
              'Across every title with saved progress on this device.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats});

  final WatchStats stats;

  @override
  Widget build(BuildContext context) {
    final List<({IconData icon, String label, String value})> tiles =
        <({IconData icon, String label, String value})>[
      (
        icon: Icons.check_circle_rounded,
        label: 'Finished',
        value: '${stats.finishedTitles}',
      ),
      (
        icon: Icons.play_circle_rounded,
        label: 'In progress',
        value: '${stats.inProgressTitles}',
      ),
      (
        icon: Icons.history_rounded,
        label: 'History',
        value: '${stats.historyEntries}',
      ),
      (
        icon: Icons.bookmark_rounded,
        label: 'Bookmarks',
        value: '${stats.bookmarks}',
      ),
    ];

    return Wrap(
      spacing: AppSpacing.x3,
      runSpacing: AppSpacing.x3,
      children: tiles.map((tile) {
        return _StatCard(icon: tile.icon, label: tile.label, value: tile.value);
      }).toList(growable: false),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final double width =
        (MediaQuery.sizeOf(context).width - AppSpacing.x12) / 2;
    return SizedBox(
      width: width.clamp(150, 220).toDouble(),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.settingsCardBackground,
          borderRadius: BorderRadius.circular(AppSpacing.x4),
          border: Border.all(color: AppColors.dropdownBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, color: AppColors.typeLink),
              const SizedBox(height: AppSpacing.x3),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.typeEmphasis,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpacing.x1),
              Text(label, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatFootnote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      'Counts are derived from local Hive boxes (progress, history, bookmarks). Clearing watch history or bookmarks resets these numbers.',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}
