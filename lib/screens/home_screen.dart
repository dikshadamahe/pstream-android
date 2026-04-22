import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pstream_android/config/app_theme.dart';
import 'package:pstream_android/config/breakpoints.dart';
import 'package:pstream_android/models/media_item.dart';
import 'package:pstream_android/providers/storage_provider.dart';
import 'package:pstream_android/providers/tmdb_provider.dart';
import 'package:pstream_android/widgets/category_row.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final WindowClass layoutClass = windowClass(context);
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
    final bool isLoading =
        trendingMovies.isLoading || trendingTv.isLoading || popular.isLoading;

    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(top: topPadding, bottom: AppSpacing.x6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x4,
                ),
                child: Text(
                  'PStream',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppColors.typeEmphasis,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const SizedBox(height: AppSpacing.x5),
              if (isLoading)
                const _HomeLoadingState()
              else ...<Widget>[
                if (continueWatching.isNotEmpty) ...<Widget>[
                  CategoryRow(
                    title: 'Continue Watching',
                    items: continueWatching,
                  ),
                  const SizedBox(height: AppSpacing.x6),
                ],
                if (bookmarks.isNotEmpty) ...<Widget>[
                  CategoryRow(title: 'My List', items: bookmarks),
                  const SizedBox(height: AppSpacing.x6),
                ],
                CategoryRow(
                  title: 'Trending Movies',
                  items: trendingMovies.value ?? const <MediaItem>[],
                ),
                const SizedBox(height: AppSpacing.x6),
                CategoryRow(
                  title: 'Trending TV',
                  items: trendingTv.value ?? const <MediaItem>[],
                ),
                const SizedBox(height: AppSpacing.x6),
                CategoryRow(
                  title: 'Popular',
                  items: popular.value ?? const <MediaItem>[],
                ),
              ],
            ],
          ),
        ),
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
          title: 'Continue Watching',
          items: <MediaItem>[],
          isLoading: true,
        ),
        SizedBox(height: AppSpacing.x6),
        CategoryRow(title: 'My List', items: <MediaItem>[], isLoading: true),
        SizedBox(height: AppSpacing.x6),
        CategoryRow(
          title: 'Trending Movies',
          items: <MediaItem>[],
          isLoading: true,
        ),
        SizedBox(height: AppSpacing.x6),
        CategoryRow(
          title: 'Trending TV',
          items: <MediaItem>[],
          isLoading: true,
        ),
        SizedBox(height: AppSpacing.x6),
        CategoryRow(title: 'Popular', items: <MediaItem>[], isLoading: true),
      ],
    );
  }
}
