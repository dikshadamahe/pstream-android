import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pstream_android/config/app_config.dart';
import 'package:pstream_android/config/app_theme.dart';
import 'package:pstream_android/providers/storage_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const String _releasesUrl =
      'https://github.com/dikshadamahe/pstream-android/releases';

  Future<void> _clearWatchHistory() async {
    await ref.read(storageControllerProvider).clearHistory();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Watch history cleared')),
    );
  }

  Future<void> _clearBookmarks() async {
    await ref.read(storageControllerProvider).clearBookmarks();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bookmarks cleared')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.x4),
          itemCount: _settingsItems.length + _actionItems.length,
          itemBuilder: (BuildContext context, int index) {
            if (index < _settingsItems.length) {
              final _SettingsItem item = _settingsItems[index];
              return _SettingsTile(title: item.title, subtitle: item.subtitle);
            }

            final int actionIndex = index - _settingsItems.length;
            if (actionIndex == 0) {
              return Padding(
                padding: const EdgeInsets.only(top: AppSpacing.x4),
                child: FilledButton(
                  onPressed: _clearWatchHistory,
                  child: const Text('Clear Watch History'),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.only(top: AppSpacing.x3),
              child: OutlinedButton(
                onPressed: _clearBookmarks,
                child: const Text('Clear Bookmarks'),
              ),
            );
          },
        ),
      ),
    );
  }

  static final List<_SettingsItem> _settingsItems = <_SettingsItem>[
    _SettingsItem(title: 'Oracle proxy', subtitle: AppConfig.proxyBaseUrl),
    const _SettingsItem(title: 'App version', subtitle: '1.0.0+1'),
    const _SettingsItem(title: 'GitHub releases', subtitle: _releasesUrl),
  ];

  static const List<String> _actionItems = <String>[
    'Clear Watch History',
    'Clear Bookmarks',
  ];
}

class _SettingsItem {
  const _SettingsItem({required this.title, required this.subtitle});

  final String title;
  final String subtitle;
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.x3),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.x2),
            SelectableText(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.typeText,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
