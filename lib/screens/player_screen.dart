import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:pstream_android/config/app_theme.dart';
import 'package:pstream_android/models/media_item.dart';
import 'package:pstream_android/models/episode.dart';
import 'package:pstream_android/models/season.dart';
import 'package:pstream_android/models/scrape_event.dart';
import 'package:pstream_android/models/stream_result.dart';
import 'package:pstream_android/providers/storage_provider.dart';
import 'package:pstream_android/providers/stream_provider.dart';
import 'package:pstream_android/screens/scraping_screen.dart';
import 'package:pstream_android/services/stream_service.dart';
import 'package:pstream_android/widgets/player_controls.dart';

class PlayerScreenArgs {
  const PlayerScreenArgs({
    required this.mediaItem,
    required this.streamResult,
    this.season,
    this.episode,
    this.resumeFrom,
  });

  final MediaItem mediaItem;
  final StreamResult streamResult;
  final int? season;
  final int? episode;
  final int? resumeFrom;
}

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({
    super.key,
    required this.args,
  });

  final PlayerScreenArgs args;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen>
    with WidgetsBindingObserver {
  late final Player _player = Player(
    configuration: const PlayerConfiguration(
      title: 'Veil',
      bufferSize: 32 * 1024 * 1024,
    ),
  );
  late final VideoController _videoController = VideoController(_player);

  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];
  Timer? _controlsHideTimer;
  Timer? _progressTimer;
  String? _subtitleToast;
  Timer? _subtitleToastTimer;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _buffer = Duration.zero;
  bool _playing = false;
  bool _buffering = true;
  bool _controlsVisible = true;
  bool _subtitlesEnabled = false;
  bool _resumeApplied = false;
  bool _playerReady = false;
  bool _hasPlaybackError = false;
  bool _sourceSwitching = false;
  bool _wasBackgrounded = false;
  String? _playbackError;
  int? _resumeFromOverride;
  late final StorageController _storageController;
  late final StreamService _streamService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _storageController = ref.read(storageControllerProvider);
    _streamService = ref.read(streamServiceProvider);
    _applyPlayerChrome();
    _bindPlayerStreams();
    _openStream();
    _progressTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _persistProgress(),
    );
    _armControlsHideTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_persistProgress(refresh: false));
    for (final StreamSubscription<dynamic> subscription in _subscriptions) {
      subscription.cancel();
    }
    _controlsHideTimer?.cancel();
    _progressTimer?.cancel();
    _subtitleToastTimer?.cancel();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _applyPlayerChrome() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        _wasBackgrounded = true;
        if (_position.inSeconds > 0) {
          _resumeFromOverride = _position.inSeconds;
        }
        unawaited(_persistProgress());
        break;
      case AppLifecycleState.resumed:
        unawaited(_recoverFromBackground());
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  void _bindPlayerStreams() {
    _subscriptions.addAll(<StreamSubscription<dynamic>>[
      _player.stream.position.listen((Duration value) {
        if (!mounted) {
          return;
        }
        setState(() {
          _position = value;
        });
      }),
      _player.stream.duration.listen((Duration value) {
        if (!mounted) {
          return;
        }
        setState(() {
          _duration = value;
        });
      }),
      _player.stream.buffer.listen((Duration value) {
        if (!mounted) {
          return;
        }
        setState(() {
          _buffer = value;
        });
      }),
      _player.stream.playing.listen((bool value) {
        if (!mounted) {
          return;
        }
        setState(() {
          _playing = value;
        });
        if (value) {
          _seekToResumePositionIfNeeded();
        }
      }),
      _player.stream.buffering.listen((bool value) {
        if (!mounted) {
          return;
        }
        setState(() {
          _buffering = value;
        });
      }),
    ]);
  }

  Future<void> _openStream() async {
    final StreamPlayback playback = widget.args.streamResult.stream;
    final String? url = _resolvePlayableUrl(playback);
    final Map<String, String> headers = playback.preferredHeaders.isNotEmpty
        ? playback.preferredHeaders
        : playback.headers;

    if (url == null || url.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _hasPlaybackError = true;
        _playerReady = false;
        _buffering = false;
        _playbackError = 'No playable stream URL was provided.';
      });
      return;
    }

    try {
      await _player.open(
        Media(
          url,
          httpHeaders: headers,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _playerReady = true;
        _hasPlaybackError = false;
        _playbackError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _hasPlaybackError = true;
        _playerReady = false;
        _buffering = false;
        _playbackError = '$error';
      });
    }
  }

  Future<void> _seekToResumePositionIfNeeded() async {
    if (_resumeApplied) {
      return;
    }

    final int? resumeFrom = _resolvedResumeFrom;
    if (resumeFrom == null || resumeFrom <= 0) {
      _resumeApplied = true;
      return;
    }

    _resumeApplied = true;
    await _player.seek(Duration(seconds: resumeFrom));
  }

  int? get _resolvedResumeFrom {
    if (_resumeFromOverride != null && _resumeFromOverride! > 0) {
      return _resumeFromOverride;
    }
    if (widget.args.resumeFrom != null) {
      return widget.args.resumeFrom;
    }

    final Map<String, dynamic>? progress = ref.read(
      progressEntryProvider(
        ProgressRequest(
          mediaItem: widget.args.mediaItem,
          season: widget.args.season,
          episode: widget.args.episode,
        ),
      ),
    );
    if (progress == null) {
      return null;
    }

    final int positionSecs = _readInt(progress['positionSecs']);
    return positionSecs > 0 ? positionSecs : null;
  }

  Future<void> _recoverFromBackground() async {
    await _applyPlayerChrome();
    if (!_wasBackgrounded || !mounted) {
      return;
    }

    _wasBackgrounded = false;
    _resumeApplied = false;
    await _openStream();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _persistProgress({bool refresh = true}) async {
    if (!_playerReady || _duration.inSeconds <= 0) {
      return;
    }

    await _storageController.saveProgress(
      widget.args.mediaItem,
      positionSecs: _position.inSeconds,
      durationSecs: _duration.inSeconds,
      season: widget.args.season,
      episode: widget.args.episode,
      refresh: refresh,
    );
  }

  Future<void> _toggleSubtitles() async {
    final List<StreamCaption> captions = _availableCaptions;

    if (_subtitlesEnabled) {
      await _player.setSubtitleTrack(SubtitleTrack.no());
      _setSubtitleState(enabled: false, message: 'Subtitles off');
      _showControls();
      return;
    }

    if (captions.isNotEmpty) {
      final StreamCaption caption = captions.first;
      await _player.setSubtitleTrack(
        SubtitleTrack.uri(
          caption.url!,
          title: caption.label ?? caption.language ?? 'Subtitles',
          language: caption.language ?? 'unknown',
        ),
      );
      _setSubtitleState(
        enabled: true,
        message: caption.label ?? 'Subtitles on',
      );
      _showControls();
      return;
    }

    if (_player.state.tracks.subtitle.isNotEmpty) {
      await _player.setSubtitleTrack(SubtitleTrack.auto());
      _setSubtitleState(enabled: true, message: 'Subtitles on');
      _showControls();
      return;
    }

    _setSubtitleState(enabled: false, message: 'No subtitles available');
    _showControls();
  }

  Future<void> _togglePlayback() async {
    if (_playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
    _showControls();
  }

  Future<void> _seekRelative(int seconds) async {
    final int targetMs =
        ((_position.inMilliseconds + (seconds * 1000)).clamp(
                  0,
                  _duration.inMilliseconds > 0 ? _duration.inMilliseconds : 0,
                )
                as num)
            .toInt();
    await _player.seek(Duration(milliseconds: targetMs));
    _showControls();
  }

  Future<void> _seekToFraction(double fraction) async {
    if (_duration.inMilliseconds <= 0) {
      return;
    }

    final int targetMs =
        ((_duration.inMilliseconds * fraction)
                    .round()
                    .clamp(0, _duration.inMilliseconds)
                as num)
            .toInt();
    await _player.seek(Duration(milliseconds: targetMs));
    _showControls();
  }

  void _showControls() {
    if (!mounted) {
      return;
    }
    setState(() {
      _controlsVisible = true;
    });
    _armControlsHideTimer();
  }

  void _armControlsHideTimer() {
    _controlsHideTimer?.cancel();
    _controlsHideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _controlsVisible = false;
      });
    });
  }

  Future<void> _openSourceSheet() async {
    _showControls();
    final String? selectedSourceId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.modalBackground,
      builder: (BuildContext context) {
        return FutureBuilder<ScrapeCatalog>(
          future: _streamService.fetchCatalog(),
          builder: (BuildContext context, AsyncSnapshot<ScrapeCatalog> snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.x6),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            final List<ScrapeSourceDefinition> sources =
                snapshot.data?.sources ?? const <ScrapeSourceDefinition>[];

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.x4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Choose source',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.x2),
                    Text(
                      'Current: ${widget.args.streamResult.sourceName}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.typeText,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.x3),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: sources.length,
                        itemBuilder: (BuildContext context, int index) {
                          final ScrapeSourceDefinition source = sources[index];
                          final bool isCurrent =
                              source.id == widget.args.streamResult.sourceId;

                          return ListTile(
                            leading: Icon(
                              isCurrent
                                  ? Icons.play_circle_fill_rounded
                                  : Icons.cloud_outlined,
                            ),
                            title: Text(source.name),
                            subtitle: isCurrent ? const Text('Current source') : null,
                            onTap: () => Navigator.of(context).pop(source.id),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x3),
                    FilledButton.icon(
                      onPressed: () async {
                        await _persistProgress();
                        Navigator.of(context).pop();
                        Navigator.of(this.context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) => ScrapingScreen(
                              mediaItem: widget.args.mediaItem,
                              season: widget.args.season,
                              episode: widget.args.episode,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.sync_alt_rounded),
                      label: const Text('Run auto selection'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (selectedSourceId == null ||
        selectedSourceId == widget.args.streamResult.sourceId) {
      return;
    }

    await _switchSource(selectedSourceId);
  }

  Future<void> _switchSource(String sourceId) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _sourceSwitching = true;
      _buffering = true;
    });

    try {
      await _persistProgress();
      final StreamResult? result = await _streamService.scrapeSingleSource(
        widget.args.mediaItem,
        sourceId: sourceId,
        season: widget.args.season,
        episode: widget.args.episode,
      );

      if (!mounted) {
        return;
      }

      if (result == null) {
        setState(() {
          _sourceSwitching = false;
          _buffering = false;
        });
        _setSubtitleState(
          enabled: _subtitlesEnabled,
          message: 'Source did not return a playable stream',
        );
        return;
      }

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => PlayerScreen(
            args: PlayerScreenArgs(
              mediaItem: widget.args.mediaItem,
              streamResult: result,
              season: widget.args.season,
              episode: widget.args.episode,
              resumeFrom: _position.inSeconds,
            ),
          ),
        ),
      );

    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _sourceSwitching = false;
        _buffering = false;
      });
      _setSubtitleState(
        enabled: _subtitlesEnabled,
        message: 'Could not switch source',
      );
    }
  }

  void _handleScreenTap() {
    setState(() {
      _controlsVisible = !_controlsVisible;
    });
    if (_controlsVisible) {
      _armControlsHideTimer();
    } else {
      _controlsHideTimer?.cancel();
    }
  }

  _NextEpisodeTarget? get _nextEpisodeTarget {
    if (!widget.args.mediaItem.isShow ||
        widget.args.season == null ||
        widget.args.episode == null) {
      return null;
    }

    final List<Season> seasons = widget.args.mediaItem.seasons;
    final int currentSeasonNumber = widget.args.season!;
    final int currentEpisodeNumber = widget.args.episode!;
    final int seasonIndex = seasons.indexWhere(
      (Season season) => season.number == currentSeasonNumber,
    );
    if (seasonIndex == -1) {
      return null;
    }

    final Season currentSeason = seasons[seasonIndex];
    final int episodeIndex = currentSeason.episodes.indexWhere(
      (Episode episode) => episode.number == currentEpisodeNumber,
    );
    if (episodeIndex == -1) {
      return null;
    }

    if (episodeIndex + 1 < currentSeason.episodes.length) {
      final Episode nextEpisode = currentSeason.episodes[episodeIndex + 1];
      return _NextEpisodeTarget(
        season: currentSeason.number,
        episode: nextEpisode.number,
        label: 'S${currentSeason.number}:E${nextEpisode.number}',
      );
    }

    if (seasonIndex + 1 < seasons.length &&
        seasons[seasonIndex + 1].episodes.isNotEmpty) {
      final Season nextSeason = seasons[seasonIndex + 1];
      final Episode nextEpisode = nextSeason.episodes.first;
      return _NextEpisodeTarget(
        season: nextSeason.number,
        episode: nextEpisode.number,
        label: 'S${nextSeason.number}:E${nextEpisode.number}',
      );
    }

    return null;
  }

  Future<void> _playNextEpisode() async {
    final _NextEpisodeTarget? nextEpisode = _nextEpisodeTarget;
    if (nextEpisode == null) {
      return;
    }

    await _persistProgress();
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ScrapingScreen(
          mediaItem: widget.args.mediaItem,
          season: nextEpisode.season,
          episode: nextEpisode.episode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String title;
    if (widget.args.mediaItem.isShow &&
        widget.args.season != null &&
        widget.args.episode != null) {
      title =
          '${widget.args.mediaItem.title} - S${widget.args.season}E${widget.args.episode}';
    } else {
      title = widget.args.mediaItem.title;
    }

    return WillPopScope(
      onWillPop: () async {
        await _persistProgress();
        return true;
      },
      child: Scaffold(
        backgroundColor: AppColors.blackC50,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _handleScreenTap,
          child: SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
              _PlayerBackdrop(mediaItem: widget.args.mediaItem),
              Positioned.fill(
                child: IgnorePointer(
                  child: _playerReady
                      ? ColoredBox(
                          color: AppColors.blackC50,
                          child: Video(
                            controller: _videoController,
                            controls: NoVideoControls,
                            fit: BoxFit.contain,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      AppColors.blackC50.withValues(alpha: 0.35),
                      AppColors.blackC50.withValues(alpha: 0.65),
                      AppColors.blackC50.withValues(alpha: 0.92),
                    ],
                  ),
                ),
              ),
              Center(
                child: _hasPlaybackError
                    ? _PlaybackErrorCard(
                        message: _playbackError ?? 'Playback failed.',
                      )
                    : _sourceSwitching
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const CircularProgressIndicator(),
                          const SizedBox(height: AppSpacing.x3),
                          Text(
                            'Switching source...',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: AppColors.typeEmphasis),
                          ),
                        ],
                      )
                    : !_playerReady
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.play_circle_fill_rounded,
                            color: AppColors.typeEmphasis.withValues(
                              alpha: 0.18,
                            ),
                            size: MediaQuery.sizeOf(context).shortestSide *
                                0.24,
                          ),
                          const SizedBox(height: AppSpacing.x3),
                          Text(
                            _playerReady ? 'Streaming' : 'Loading stream...',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: AppColors.typeEmphasis,
                                ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
              if (_buffering && !_hasPlaybackError)
                const Center(
                  child: RepaintBoundary(
                    child: CircularProgressIndicator(),
                  ),
                ),
              if (_subtitleToast != null)
                Positioned(
                  top: AppSpacing.x8,
                  left: AppSpacing.x0,
                  right: AppSpacing.x0,
                  child: RepaintBoundary(
                    child: AnimatedOpacity(
                      opacity: _subtitleToast == null ? 0 : 1,
                      duration: const Duration(milliseconds: 180),
                      child: Center(
                        child: PlayerInfoPill(label: _subtitleToast!),
                      ),
                    ),
                  ),
                ),
                PlayerControls(
                  visible: _controlsVisible,
                  mediaTitle: title,
                  sourceLabel: widget.args.streamResult.embedName ??
                      widget.args.streamResult.sourceName,
                  isPlaying: _playing,
                  subtitlesEnabled: _subtitlesEnabled,
                  position: _position,
                  duration: _duration,
                  buffered: _buffer,
                  showNextEpisode: _shouldShowNextEpisode,
                  nextEpisodeLabel: _nextEpisodeTarget?.label,
                  onBack: () async {
                    await _persistProgress();
                    if (mounted) {
                      await Navigator.of(context).maybePop();
                    }
                  },
                  onSubtitleToggle: _toggleSubtitles,
                  onPlayPause: _togglePlayback,
                  onSeekBack: () => _seekRelative(-10),
                  onSeekForward: () => _seekRelative(10),
                  onSeek: _seekToFraction,
                  onSourceSwitcher: _openSourceSheet,
                  onFullscreen: _applyPlayerChrome,
                  onNextEpisode: _playNextEpisode,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _shouldShowNextEpisode {
    if (!widget.args.mediaItem.isShow || _nextEpisodeTarget == null) {
      return false;
    }
    if (_duration.inMilliseconds <= 0) {
      return false;
    }
    return _position.inMilliseconds / _duration.inMilliseconds > 0.90;
  }

  int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse('$value') ?? 0;
  }

  List<StreamCaption> get _availableCaptions {
    return widget.args.streamResult.stream.captions
        .where((StreamCaption caption) => caption.url?.isNotEmpty == true)
        .toList(growable: false);
  }

  void _setSubtitleState({
    required bool enabled,
    required String message,
  }) {
    if (!mounted) {
      return;
    }

    setState(() {
      _subtitlesEnabled = enabled;
      _subtitleToast = message;
    });

    _subtitleToastTimer?.cancel();
    _subtitleToastTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _subtitleToast = null;
      });
    });
  }

  String? _resolvePlayableUrl(StreamPlayback playback) {
    if (playback.proxiedPlaylist?.isNotEmpty == true) {
      return playback.proxiedPlaylist;
    }
    if (playback.playlist?.isNotEmpty == true) {
      return playback.playlist;
    }
    if (playback.playbackUrl?.isNotEmpty == true) {
      return playback.playbackUrl;
    }

    final String? selectedQuality = playback.selectedQuality;
    if (selectedQuality != null &&
        playback.qualities[selectedQuality]?.url?.isNotEmpty == true) {
      return playback.qualities[selectedQuality]?.url;
    }

    for (final StreamQuality quality in playback.qualities.values) {
      if (quality.url?.isNotEmpty == true) {
        return quality.url;
      }
    }

    return null;
  }
}

class _PlayerBackdrop extends StatelessWidget {
  const _PlayerBackdrop({required this.mediaItem});

  final MediaItem mediaItem;

  @override
  Widget build(BuildContext context) {
    final String? backdropUrl = mediaItem.backdropUrl();

    if (backdropUrl == null) {
      return const ColoredBox(color: AppColors.blackC50);
    }

    return CachedNetworkImage(
      imageUrl: backdropUrl,
      fit: BoxFit.cover,
      errorWidget: (_, loadError, stackTrace) =>
          const ColoredBox(color: AppColors.blackC50),
    );
  }
}

class _PlaybackErrorCard extends StatelessWidget {
  const _PlaybackErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.7,
      ),
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: AppColors.videoContextBackground.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(AppSpacing.x4),
        border: Border.all(color: AppColors.videoContextError),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.videoContextError,
            size: AppSpacing.x10,
          ),
          const SizedBox(height: AppSpacing.x3),
          Text(
            'Playback failed',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _NextEpisodeTarget {
  const _NextEpisodeTarget({
    required this.season,
    required this.episode,
    required this.label,
  });

  final int season;
  final int episode;
  final String label;
}
