import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pstream_android/config/app_theme.dart';
import 'package:pstream_android/config/breakpoints.dart';
import 'package:pstream_android/models/media_item.dart';
import 'package:pstream_android/providers/tmdb_provider.dart';
import 'package:pstream_android/widgets/media_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
    _controller.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    final String query = _controller.text.trim();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _query = query;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool hasQuery = _query.isNotEmpty;
    final AsyncValue<List<MediaItem>> data = hasQuery
        ? ref.watch(searchProvider(_query))
        : ref.watch(trendingMoviesProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      appBar: AppBar(
        titleSpacing: AppSpacing.x4,
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: AppColors.searchText),
          decoration: InputDecoration(
            hintText: 'Search movies and shows',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: hasQuery
                ? IconButton(
                    onPressed: () {
                      _controller.clear();
                    },
                    icon: const Icon(Icons.close_rounded),
                  )
                : null,
          ),
        ),
      ),
      body: SafeArea(
        child: _SearchResultsGrid(
          title: hasQuery ? null : 'Trending Suggestions',
          items: data.value ?? const <MediaItem>[],
          isLoading: data.isLoading,
        ),
      ),
    );
  }
}

class _SearchResultsGrid extends StatelessWidget {
  const _SearchResultsGrid({
    this.title,
    required this.items,
    required this.isLoading,
  });

  final String? title;
  final List<MediaItem> items;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final int columns = switch (windowClass(context)) {
      WindowClass.compact => 2,
      WindowClass.medium => 3,
      WindowClass.expanded => 4,
    };

    final int itemCount = isLoading ? columns * 3 : items.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x4,
              AppSpacing.x4,
              AppSpacing.x4,
              AppSpacing.x2,
            ),
            child: Text(
              title!,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: AppColors.typeEmphasis),
            ),
          ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.x4),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: AppSpacing.x3,
              mainAxisSpacing: AppSpacing.x4,
              childAspectRatio: 130 / 195,
            ),
            itemCount: itemCount,
            itemBuilder: (BuildContext context, int index) {
              if (isLoading) {
                return const MediaCardSkeleton();
              }

              if (items.isEmpty) {
                return const SizedBox.shrink();
              }

              return MediaCard(mediaItem: items[index]);
            },
          ),
        ),
      ],
    );
  }
}
