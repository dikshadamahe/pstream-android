import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pstream_android/config/app_theme.dart';
import 'package:pstream_android/config/breakpoints.dart';
import 'package:pstream_android/models/media_item.dart';
import 'package:pstream_android/providers/storage_provider.dart';
import 'package:pstream_android/widgets/media_card.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<MediaItem> history = ref.watch(historyProvider);
    final int columns = switch (windowClass(context)) {
      WindowClass.compact => 2,
      WindowClass.medium => 3,
      WindowClass.expanded => 4,
    };

    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      appBar: AppBar(title: const Text('History')),
      body: SafeArea(
        child: history.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.x6),
                  child: Text(
                    'No watch history yet.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : GridView.builder(
                padding: const EdgeInsets.all(AppSpacing.x4),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: AppSpacing.x3,
                  mainAxisSpacing: AppSpacing.x4,
                  childAspectRatio: 130 / 195,
                ),
                itemCount: history.length,
                itemBuilder: (BuildContext context, int index) {
                  return MediaCard(mediaItem: history[index]);
                },
              ),
      ),
    );
  }
}
