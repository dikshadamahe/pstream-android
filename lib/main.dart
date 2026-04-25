import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:pstream_android/config/app_theme.dart';
import 'package:pstream_android/config/router.dart';
import 'package:pstream_android/providers/storage_provider.dart';
import 'package:pstream_android/providers/tmdb_provider.dart';
import 'package:pstream_android/storage/local_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await LocalStorage.init();
  runApp(const ProviderScope(child: VeilApp()));
}

class VeilApp extends ConsumerStatefulWidget {
  const VeilApp({super.key});

  @override
  ConsumerState<VeilApp> createState() => _VeilAppState();
}

class _VeilAppState extends ConsumerState<VeilApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }

    ref.invalidate(continueWatchingProvider);
    ref.invalidate(bookmarksProvider);
    ref.invalidate(historyProvider);
    ref.invalidate(trendingMoviesProvider);
    ref.invalidate(trendingTVProvider);
    ref.invalidate(popularMoviesProvider);

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Veil',
      theme: AppTheme.dark(),
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
