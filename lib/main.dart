import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:pstream_android/config/app_theme.dart';
import 'package:pstream_android/config/router.dart';
import 'package:pstream_android/storage/local_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await LocalStorage.init();
  runApp(const ProviderScope(child: VeilApp()));
}

class VeilApp extends StatelessWidget {
  const VeilApp({super.key});

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
