import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

/// Optional libmpv tuning for Android native [Player] (playback parity / headroom).
///
/// Safe no-ops on web or non-native backends.
Future<void> applyNativePlaybackTune(Player player) async {
  if (kIsWeb) {
    return;
  }
  final PlatformPlayer? platform = player.platform;
  if (platform is! NativePlayer) {
    return;
  }
  try {
    await platform.setProperty('volume-max', '150');
    await platform.setProperty('demuxer-readahead-secs', '20');
  } catch (error, stackTrace) {
    debugPrint('applyNativePlaybackTune: $error\n$stackTrace');
  }
}
