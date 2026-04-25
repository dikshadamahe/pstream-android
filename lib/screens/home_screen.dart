import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pstream_android/config/app_config.dart';
import 'package:pstream_android/config/app_theme.dart';
import 'package:pstream_android/config/breakpoints.dart';
import 'package:pstream_android/models/media_item.dart';
import 'package:pstream_android/providers/storage_provider.dart';
import 'package:pstream_android/providers/tmdb_provider.dart';
import 'package:pstream_android/widgets/category_row.dart';

enum _HomeCatalogFilter { all, movies, tv, webSeries, sports }

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final PageController _heroController = PageController();
  int _heroPage = 0;
  _HomeCatalogFilter _catalogFilter = _HomeCatalogFilter.all;

  @override
  void dispose() {
    _heroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.hasTmdbReadToken) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundMain,
        body: SafeArea(
          child: _HomeMessageState(
            title: 'App setup is incomplete.',
            message:
                'This build is missing TMDB_TOKEN. Rebuild or re-release the app with the TMDB read access token configured in GitHub secrets.',
          ),
        ),
      );
    }

    final WindowClass layoutClass = windowClass(context);
    final double horizontalPadding = switch (layoutClass) {
      WindowClass.compact => AppSpacing.x4,
      WindowClass.medium => AppSpacing.x5,
      WindowClass.expanded => AppSpacing.x6,
    };
    final double topPadding = switch (layoutClass) {
      WindowClass.compact => AppSpacing.x4,
      WindowClass.medium => AppSpacing.x5,
      WindowClass.expanded => AppSpacing.x6,
    };

    final AsyncValue<List<MediaItem>> trendingMovies = ref.watch(
      trendingMoviesProvider,
    );
    final AsyncValue<List<MediaItem>> trendingTv = ref.watch(
      trendingTVProvider,
    );
    final AsyncValue<List<MediaItem>> popular = ref.watch(
      popularMoviesProvider,
    );
    final List<MediaItem> continueWatching = ref.watch(
      continueWatchingProvider,
    );
    final List<MediaItem> bookmarks = ref.watch(bookmarksProvider);
    final Object? error =
        trendingMovies.error ?? trendingTv.error ?? popular.error;

    final bool showSportsOnly = _catalogFilter == _HomeCatalogFilter.sports;
    final bool showMovieRows =
        !showSportsOnly &&
        (_catalogFilter == _HomeCatalogFilter.all ||
            _catalogFilter == _HomeCatalogFilter.movies);
    final bool showTvRows =
        !showSportsOnly &&
        (_catalogFilter == _HomeCatalogFilter.all ||
            _catalogFilter == _HomeCatalogFilter.tv ||
            _catalogFilter == _HomeCatalogFilter.webSeries);

    final List<MediaItem> heroCandidates = _heroItems(
      trendingMovies: trendingMovies.value ?? const <MediaItem>[],
      trendingTv: trendingTv.value ?? const <MediaItem>[],
    );

    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(top: topPadding, bottom: AppSpacing.x6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: _HomeTopBar(
                  layoutClass: layoutClass,
                  onSearchTap: () => context.go('/search'),
                ),
              ),
              SizedBox(
                height: switch (layoutClass) {
                  WindowClass.compact => AppSpacing.x4,
                  _ => AppSpacing.x5,
                },
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: _HomeCategoryChips(
                  selected: _catalogFilter,
                  onSelected: (_HomeCatalogFilter next) {
                    setState(() {
                      _catalogFilter = next;
                      _heroPage = 0;
                    });
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.x4),
              if (error != null)
                _HomeMessageState(
                  title: 'Could not load the home feed.',
                  message: _friendlyMessage(error),
                )
              else if (trendingMovies.isLoading ||
                  trendingTv.isLoading ||
                  popular.isLoading)
                const _HomeLoadingState()
              else ...<Widget>[
                if (!showSportsOnly && heroCandidates.isNotEmpty) ...<Widget>[
                  RepaintBoundary(
                    child: _HomeHeroCarousel(
                      controller: _heroController,
                      items: heroCandidates,
                      layoutClass: layoutClass,
                      horizontalPadding: horizontalPadding,
                      pageIndex: _heroPage,
                      onPageChanged: (int i) => setState(() => _heroPage = i),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x6),
                ],
                if (showSportsOnly)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                    ),
                    child: const _HomeMessageState(
                      title: 'Sports',
                      message:
                          'Veil does not include a sports catalog yet. Browse movies and TV from the All filter.',
                    ),
                  ),
                if (!showSportsOnly && continueWatching.isNotEmpty) ...<Widget>[
                  CategoryRow(
                    title: 'Continue watching',
                    items: continueWatching,
                    useSectionAccent: true,
                    onSeeAll: () => context.go('/list'),
                  ),
                  const SizedBox(height: AppSpacing.x6),
                ],
                if (!showSportsOnly && bookmarks.isNotEmpty) ...<Widget>[
                  CategoryRow(
                    title: 'My list',
                    items: bookmarks,
                    useSectionAccent: true,
                    onSeeAll: () => context.go('/list'),
                  ),
                  const SizedBox(height: AppSpacing.x6),
                ],
                if (showMovieRows &&
                    (trendingMovies.value ?? const <MediaItem>[]).isNotEmpty)
                  CategoryRow(
                    title: 'Trending movies',
                    items: trendingMovies.value ?? const <MediaItem>[],
                    useSectionAccent: true,
                    onSeeAll: () => context.go('/search'),
                  ),
                if (showMovieRows &&
                    (trendingMovies.value ?? const <MediaItem>[]).isNotEmpty)
                  const SizedBox(height: AppSpacing.x6),
                if (showTvRows &&
                    (trendingTv.value ?? const <MediaItem>[]).isNotEmpty)
                  CategoryRow(
                    title: 'Trending TV',
                    items: trendingTv.value ?? const <MediaItem>[],
                    useSectionAccent: true,
                    onSeeAll: () => context.go('/search'),
                  ),
                if (showTvRows &&
                    (trendingTv.value ?? const <MediaItem>[]).isNotEmpty)
                  const SizedBox(height: AppSpacing.x6),
                if (showMovieRows &&
                    (popular.value ?? const <MediaItem>[]).isNotEmpty)
                  CategoryRow(
                    title: 'Popular',
                    items: popular.value ?? const <MediaItem>[],
                    useSectionAccent: true,
                    onSeeAll: () => context.go('/search'),
                  ),
                if (!showSportsOnly &&
                    (trendingMovies.value ?? const <MediaItem>[]).isEmpty &&
                    (trendingTv.value ?? const <MediaItem>[]).isEmpty &&
                    (popular.value ?? const <MediaItem>[]).isEmpty)
                  const _HomeMessageState(
                    title: 'Nothing to show yet.',
                    message: 'Trending data came back empty.',
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<MediaItem> _heroItems({
    required List<MediaItem> trendingMovies,
    required List<MediaItem> trendingTv,
  }) {
    switch (_catalogFilter) {
      case _HomeCatalogFilter.movies:
        return trendingMovies.take(8).toList(growable: false);
      case _HomeCatalogFilter.tv:
      case _HomeCatalogFilter.webSeries:
        return trendingTv.take(8).toList(growable: false);
      case _HomeCatalogFilter.sports:
        return const <MediaItem>[];
      case _HomeCatalogFilter.all:
        final List<MediaItem> merged = <MediaItem>[
          ...trendingMovies.take(5),
          ...trendingTv.take(5),
        ];
        return merged.take(8).toList(growable: false);
    }
  }
}

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar({required this.layoutClass, required this.onSearchTap});

  final WindowClass layoutClass;
  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    final double logoSize = switch (layoutClass) {
      WindowClass.compact => AppSpacing.x10,
      WindowClass.medium => AppSpacing.x12,
      WindowClass.expanded => AppSpacing.x12 + AppSpacing.x2,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        _VeilGlyph(size: logoSize),
        const SizedBox(width: AppSpacing.x3),
        Expanded(
          child: Text(
            'Veil',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.typeEmphasis,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
        ),
        Material(
          color: AppColors.searchPillSurface,
          borderRadius: BorderRadius.circular(AppSpacing.x4),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.x4),
            onTap: onSearchTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x3,
                vertical: AppSpacing.x2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'Search',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.searchPillOnSurface.withValues(
                        alpha: 0.55,
                      ),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x2),
                  Icon(
                    Icons.search_rounded,
                    size: AppSpacing.x5,
                    color: AppColors.searchPillOnSurface.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.x2),
        Tooltip(
          message: 'Notifications are not available yet.',
          child: IconButton(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            padding: EdgeInsets.zero,
            onPressed: () {},
            icon: Badge(
              smallSize: AppSpacing.x1,
              backgroundColor: AppColors.streamSectionAccent,
              child: Icon(
                Icons.notifications_none_rounded,
                color: AppColors.typeSecondary,
                size: switch (layoutClass) {
                  WindowClass.compact => AppSpacing.x5,
                  _ => AppSpacing.x6,
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VeilGlyph extends StatelessWidget {
  const _VeilGlyph({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.streamSectionAccent, width: 2),
        ),
        child: Center(
          child: Text(
            'V',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.streamSectionAccent,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeCategoryChips extends StatelessWidget {
  const _HomeCategoryChips({required this.selected, required this.onSelected});

  final _HomeCatalogFilter selected;
  final ValueChanged<_HomeCatalogFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    const List<({String label, _HomeCatalogFilter value})> options =
        <({String label, _HomeCatalogFilter value})>[
          (label: 'All', value: _HomeCatalogFilter.all),
          (label: 'Movies', value: _HomeCatalogFilter.movies),
          (label: 'TV', value: _HomeCatalogFilter.tv),
          (label: 'Web series', value: _HomeCatalogFilter.webSeries),
          (label: 'Sports', value: _HomeCatalogFilter.sports),
        ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.x2),
        itemBuilder: (BuildContext context, int index) {
          final ({String label, _HomeCatalogFilter value}) opt = options[index];
          final bool isOn = selected == opt.value;
          return Material(
            color: isOn ? AppColors.streamSectionAccent : AppColors.transparent,
            borderRadius: BorderRadius.circular(21),
            child: InkWell(
              borderRadius: BorderRadius.circular(21),
              onTap: () => onSelected(opt.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x4,
                  vertical: AppSpacing.x2,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(21),
                  border: Border.all(
                    color: isOn
                        ? AppColors.streamSectionAccent
                        : AppColors.ashC100,
                  ),
                ),
                child: Center(
                  child: Text(
                    opt.label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: isOn
                          ? AppColors.typeEmphasis
                          : AppColors.typeSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HomeHeroCarousel extends StatelessWidget {
  const _HomeHeroCarousel({
    required this.controller,
    required this.items,
    required this.layoutClass,
    required this.horizontalPadding,
    required this.pageIndex,
    required this.onPageChanged,
  });

  final PageController controller;
  final List<MediaItem> items;
  final WindowClass layoutClass;
  final double horizontalPadding;
  final int pageIndex;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final double width =
        MediaQuery.sizeOf(context).width - horizontalPadding * 2;
    final double height = switch (layoutClass) {
      WindowClass.compact => width * 0.52,
      WindowClass.medium => width * 0.42,
      WindowClass.expanded => width * 0.36,
    };

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.x5),
            child: SizedBox(
              height: height,
              child: PageView.builder(
                controller: controller,
                onPageChanged: onPageChanged,
                itemCount: items.length,
                itemBuilder: (BuildContext context, int index) {
                  return _HomeHeroSlide(media: items[index]);
                },
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.x3),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List<Widget>.generate(items.length, (int i) {
              final bool active = i == pageIndex;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: active ? AppSpacing.x3 : AppSpacing.x2,
                  height: AppSpacing.x2,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppSpacing.x1),
                    color: active
                        ? AppColors.streamSectionAccent
                        : AppColors.ashC600,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _HomeHeroSlide extends StatelessWidget {
  const _HomeHeroSlide({required this.media});

  final MediaItem media;

  @override
  Widget build(BuildContext context) {
    final String? backdrop = media.backdropUrl('w780');
    final String? castName = media.credits.isNotEmpty
        ? media.credits.first.name
        : null;
    final String yearLabel = media.year > 0 ? '${media.year}' : '—';

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ColoredBox(
          color: AppColors.blackC100,
          child: backdrop == null
              ? const Center(
                  child: Icon(
                    Icons.movie_creation_outlined,
                    color: AppColors.typeSecondary,
                    size: 48,
                  ),
                )
              : CachedNetworkImage(
                  imageUrl: backdrop,
                  fit: BoxFit.cover,
                  placeholder: (_, _) =>
                      const ColoredBox(color: AppColors.blackC100),
                  errorWidget: (_, _, _) =>
                      const ColoredBox(color: AppColors.blackC100),
                ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                AppColors.transparent,
                AppColors.transparent,
                AppColors.blackC50,
              ],
              stops: <double>[0, 0.45, 1],
            ),
          ),
        ),
        Positioned(
          left: AppSpacing.x4,
          right: AppSpacing.x4,
          bottom: AppSpacing.x4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Container(
                    width: AppSpacing.x2,
                    height: AppSpacing.x2,
                    decoration: const BoxDecoration(
                      color: AppColors.typeEmphasis,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x2),
                  Expanded(
                    child: Text(
                      media.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.typeEmphasis,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.x2),
              if (castName != null)
                _HeroMetaRow(label: 'Cast', value: castName),
              _HeroMetaRow(label: 'Release', value: yearLabel),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroMetaRow extends StatelessWidget {
  const _HeroMetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '$label ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.typeEmphasis.withValues(alpha: 0.85),
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.typeEmphasis.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeLoadingState extends StatelessWidget {
  const _HomeLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: <Widget>[
        CategoryRow(
          title: 'Continue watching',
          items: <MediaItem>[],
          isLoading: true,
          useSectionAccent: true,
        ),
        SizedBox(height: AppSpacing.x6),
        CategoryRow(
          title: 'My list',
          items: <MediaItem>[],
          isLoading: true,
          useSectionAccent: true,
        ),
        SizedBox(height: AppSpacing.x6),
        CategoryRow(
          title: 'Trending movies',
          items: <MediaItem>[],
          isLoading: true,
          useSectionAccent: true,
        ),
        SizedBox(height: AppSpacing.x6),
        CategoryRow(
          title: 'Trending TV',
          items: <MediaItem>[],
          isLoading: true,
          useSectionAccent: true,
        ),
        SizedBox(height: AppSpacing.x6),
        CategoryRow(
          title: 'Popular',
          items: <MediaItem>[],
          isLoading: true,
          useSectionAccent: true,
        ),
      ],
    );
  }
}

class _HomeMessageState extends StatelessWidget {
  const _HomeMessageState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.x4),
        decoration: BoxDecoration(
          color: AppColors.modalBackground,
          borderRadius: BorderRadius.circular(AppSpacing.x4),
          border: Border.all(color: AppColors.dropdownBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.x2),
            Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

String _friendlyMessage(Object error) {
  final String message = '$error';
  if (message.contains('TMDB authorization failed')) {
    return 'TMDB_TOKEN is invalid or expired in this build. Rebuild the app with the new read access token.';
  }
  if (message.contains('TimeoutException')) {
    return 'TMDB timed out on this network. The app now retries once, but if it still fails, rebuild with the new token and test again on a stable connection.';
  }
  return message;
}
