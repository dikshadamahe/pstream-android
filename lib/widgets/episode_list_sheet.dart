import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:pstream_android/config/app_theme.dart';
import 'package:pstream_android/models/episode.dart';
import 'package:pstream_android/models/media_item.dart';
import 'package:pstream_android/models/season.dart';
import 'package:pstream_android/services/tmdb_service.dart';
import 'package:pstream_android/storage/local_storage.dart';
import 'package:shimmer/shimmer.dart';

class EpisodeSelection {
  const EpisodeSelection({required this.season, required this.episode});

  final int season;
  final int episode;
}

class EpisodeListSheet extends StatefulWidget {
  const EpisodeListSheet({
    super.key,
    required this.media,
    required this.tmdbService,
  });

  final MediaItem media;
  final TmdbService tmdbService;

  @override
  State<EpisodeListSheet> createState() => _EpisodeListSheetState();
}

class _EpisodeListSheetState extends State<EpisodeListSheet>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  final Map<int, List<Episode>> _episodesBySeason = <int, List<Episode>>{};
  final Map<int, bool> _loadingBySeason = <int, bool>{};
  EpisodeSelection? _currentSelection;

  @override
  void initState() {
    super.initState();
    final int initialIndex = _initialSeasonIndex();
    _tabController = TabController(
      length: widget.media.seasons.length,
      vsync: this,
      initialIndex: initialIndex,
    )..addListener(_handleTabChange);
    _currentSelection = _readCurrentSelection();
    _loadSeason(widget.media.seasons[initialIndex].number);
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChange)
      ..dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      return;
    }

    _loadSeason(widget.media.seasons[_tabController.index].number);
  }

  int _initialSeasonIndex() {
    final EpisodeSelection? selection = _readCurrentSelection();
    if (selection == null) {
      return 0;
    }

    final int index = widget.media.seasons.indexWhere(
      (Season season) => season.number == selection.season,
    );
    return index >= 0 ? index : 0;
  }

  EpisodeSelection? _readCurrentSelection() {
    final Map<String, dynamic>? latest = LocalStorage.getLatestEpisodeProgress(
      widget.media,
    );
    final String? mediaKey = latest?['mediaKey'] as String?;
    return mediaKey == null
        ? null
        : LocalStorage.parseEpisodeSelection(mediaKey);
  }

  Future<void> _loadSeason(int seasonNumber) async {
    if (_episodesBySeason.containsKey(seasonNumber) ||
        _loadingBySeason[seasonNumber] == true) {
      return;
    }

    setState(() {
      _loadingBySeason[seasonNumber] = true;
    });

    final List<Episode> episodes = await widget.tmdbService.getSeasonEpisodes(
      widget.media.tmdbId,
      seasonNumber,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _episodesBySeason[seasonNumber] = episodes;
      _loadingBySeason[seasonNumber] = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final int seasonNumber = widget.media.seasons[_tabController.index].number;
    final List<Episode> episodes =
        _episodesBySeason[seasonNumber] ?? const <Episode>[];
    final bool isLoading = _loadingBySeason[seasonNumber] == true;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.48,
      maxChildSize: 0.95,
      builder: (BuildContext context, ScrollController scrollController) {
        return DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.modalBackground,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppSpacing.x5),
            ),
          ),
          child: Column(
            children: <Widget>[
              const SizedBox(height: AppSpacing.x3),
              Container(
                width: AppSpacing.x12,
                height: AppSpacing.x1,
                decoration: BoxDecoration(
                  color: AppColors.typeSecondary,
                  borderRadius: BorderRadius.circular(AppSpacing.x1),
                ),
              ),
              const SizedBox(height: AppSpacing.x4),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: widget.media.seasons
                    .map((Season season) {
                      return Tab(text: 'Season ${season.number}');
                    })
                    .toList(growable: false),
              ),
              const SizedBox(height: AppSpacing.x2),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.x4,
                          AppSpacing.x2,
                          AppSpacing.x4,
                          AppSpacing.x6,
                        ),
                        itemCount: episodes.length,
                        itemBuilder: (BuildContext context, int index) {
                          final Episode episode = episodes[index];
                          final String mediaKey = LocalStorage.mediaKey(
                            widget.media,
                            season: seasonNumber,
                            episode: episode.number,
                          );
                          final Map<String, dynamic>? progress =
                              LocalStorage.getProgress(mediaKey);
                          final bool isCurrent =
                              _currentSelection?.season == seasonNumber &&
                              _currentSelection?.episode == episode.number;

                          return _EpisodeRow(
                            episode: episode,
                            mediaKey: mediaKey,
                            progress: progress,
                            isCurrent: isCurrent,
                            onTap: () {
                              Navigator.of(context).pop(
                                EpisodeSelection(
                                  season: seasonNumber,
                                  episode: episode.number,
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({
    required this.episode,
    required this.mediaKey,
    required this.progress,
    required this.isCurrent,
    required this.onTap,
  });

  final Episode episode;
  final String mediaKey;
  final Map<String, dynamic>? progress;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final int positionSecs = _readInt(progress?['positionSecs']);
    final int durationSecs = _readInt(progress?['durationSecs']);
    final double ratio = durationSecs > 0 ? positionSecs / durationSecs : 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x3),
      child: Material(
        color: isCurrent
            ? AppColors.mediaCardHoverBackground
            : AppColors.dropdownAltBackground,
        borderRadius: BorderRadius.circular(AppSpacing.x4),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.x4),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.x3),
                  child: SizedBox(
                    width: 120,
                    height: 68,
                    child: episode.stillPath == null
                        ? const _StillPlaceholder()
                        : CachedNetworkImage(
                            imageUrl:
                                'https://image.tmdb.org/t/p/w300${episode.stillPath}',
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const _StillPlaceholder(),
                            errorWidget: (_, __, ___) =>
                                const _StillPlaceholder(),
                          ),
                  ),
                ),
                const SizedBox(width: AppSpacing.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              'E${episode.number} ${episode.title}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: AppColors.typeEmphasis,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          if (isCurrent)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.x2,
                                vertical: AppSpacing.x1,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.buttonsPurple,
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.x3,
                                ),
                              ),
                              child: Text(
                                'Watching',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: AppColors.typeEmphasis),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.x2),
                      Text(
                        episode.overview.isEmpty
                            ? 'No overview available.'
                            : episode.overview,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.typeText,
                        ),
                      ),
                      if (progress != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.x3),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.x1,
                                ),
                                child: LinearProgressIndicator(
                                  minHeight: AppSpacing.x1,
                                  value: ratio.clamp(0.0, 1.0),
                                  backgroundColor: AppColors.mediaCardBarColor,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        AppColors.mediaCardBarFillColor,
                                      ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.x2),
                            Text(
                              _formatDuration(positionSecs),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: AppColors.typeSecondary),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse('$value') ?? 0;
  }

  static String _formatDuration(int seconds) {
    final Duration duration = Duration(seconds: seconds);
    final int minutes = duration.inMinutes.remainder(60);
    final int hours = duration.inHours;
    final int secs = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }
}

class _StillPlaceholder extends StatelessWidget {
  const _StillPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.mediaCardHoverBackground,
      highlightColor: AppColors.mediaCardHoverAccent,
      child: const ColoredBox(color: AppColors.mediaCardHoverBackground),
    );
  }
}
