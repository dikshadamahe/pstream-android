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
  String? _selectedQualityKey;
  String? _selectedQualityUrl;
  StreamCaption? _selectedCaption;
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

  Future<void> _openStream({int? resumeFrom}) async {
    final StreamPlayback playback = widget.args.streamResult.stream;
    final String? url = _selectedQualityUrl ?? _resolvePlayableUrl(playback);
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
      if (resumeFrom != null && resumeFrom > 0) {
        _resumeFromOverride = resumeFrom;
      }
      _resumeApplied = false;
      await _player.open(
        Media(
          url,
          httpHeaders: headers,
        ),
      );
      await _applySelectedSubtitleTrack();
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
    await _openStream(resumeFrom: _position.inSeconds);
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

  Future<T?> _showPlayerSheet<T>({
    required WidgetBuilder builder,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      barrierColor: AppColors.blackC50.withValues(alpha: 0.82),
      builder: (BuildContext context) {
        return builder(context);
      },
    );
  }

  Future<void> _openPlayerSettingsSheet() async {
    _showControls();
    final bool subtitlesAvailable =
        _availableCaptions.isNotEmpty || _player.state.tracks.subtitle.isNotEmpty;

    await _showPlayerSheet<void>(
      builder: (BuildContext context) {
        return _PlayerSheetScaffold(
          child: _PlayerSettingsHomeSheet(
            qualityLabel: _currentQualityLabel,
            sourceLabel: widget.args.streamResult.sourceName,
            subtitleLabel: _currentSubtitleLabel,
            audioLabel: _currentAudioLabel,
            subtitlesEnabled: _subtitlesEnabled,
            subtitlesAvailable: subtitlesAvailable,
            onQualityTap: () {
              Navigator.of(context).pop();
              _openQualitySheet();
            },
            onSourceTap: () {
              Navigator.of(context).pop();
              _openSourceSheet();
            },
            onSubtitlesTap: () {
              Navigator.of(context).pop();
              _openSubtitlesSheet();
            },
            onSubtitleToggle: (bool value) {
              Navigator.of(context).pop();
              if (value) {
                _enableAutoSubtitles();
              } else {
                _disableSubtitles();
              }
            },
          ),
        );
      },
    );
  }

  Future<void> _openSourceSheet() async {
    _showControls();
    final String? selectedSourceId = await _showPlayerSheet<String>(
      builder: (BuildContext context) {
        return _PlayerSheetScaffold(
          child: FutureBuilder<ScrapeCatalog>(
            future: _streamService.fetchCatalog(),
            builder: (BuildContext context, AsyncSnapshot<ScrapeCatalog> snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(AppSpacing.x6),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final List<ScrapeSourceDefinition> sources =
                  snapshot.data?.sources ?? const <ScrapeSourceDefinition>[];

              return _PlayerOptionSheet(
                title: 'Sources',
                trailingText: 'Find next source',
                onBack: () => Navigator.of(context).pop(),
                onTrailingTap: () async {
                  final NavigatorState modalNavigator = Navigator.of(context);
                  final NavigatorState screenNavigator =
                      Navigator.of(this.context);
                  await _persistProgress();
                  if (!mounted) {
                    return;
                  }
                  modalNavigator.pop();
                  await screenNavigator.pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => ScrapingScreen(
                        mediaItem: widget.args.mediaItem,
                        season: widget.args.season,
                        episode: widget.args.episode,
                      ),
                    ),
                  );
                },
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: sources.length,
                  itemBuilder: (BuildContext context, int index) {
                    final ScrapeSourceDefinition source = sources[index];
                    final bool isCurrent =
                        source.id == widget.args.streamResult.sourceId;

                    return _PlayerOptionRow(
                      title: source.name,
                      selected: isCurrent,
                      onTap: () => Navigator.of(context).pop(source.id),
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );

    if (selectedSourceId == null ||
        selectedSourceId == widget.args.streamResult.sourceId) {
      return;
    }

    await _switchSource(selectedSourceId);
  }

  Future<void> _openQualitySheet() async {
    _showControls();
    final List<MapEntry<String, StreamQuality>> qualities = _availableQualities;

    await _showPlayerSheet<void>(
      builder: (BuildContext context) {
        return _PlayerSheetScaffold(
          child: _PlayerOptionSheet(
            title: 'Quality',
            onBack: () => Navigator.of(context).pop(),
            footer: _PlayerToggleRow(
              title: 'Automatic quality',
              subtitle:
                  'Use the source default unless you explicitly select a stream quality.',
              value: _selectedQualityKey == null,
              onChanged: (bool value) {
                Navigator.of(context).pop();
                if (value) {
                  _selectQuality(null);
                }
              },
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: qualities.length,
              itemBuilder: (BuildContext context, int index) {
                final MapEntry<String, StreamQuality> quality = qualities[index];
                final bool isSelected = _selectedQualityKey == quality.key ||
                    (_selectedQualityKey == null &&
                        widget.args.streamResult.stream.selectedQuality ==
                            quality.key);

                return _PlayerOptionRow(
                  title: quality.key,
                  subtitle: quality.value.type,
                  selected: isSelected,
                  onTap: () {
                    Navigator.of(context).pop();
                    _selectQuality(quality.key);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _openSubtitlesSheet() async {
    _showControls();
    final Map<String, List<StreamCaption>> groupedCaptions =
        _groupedCaptionsByLanguage;

    await _showPlayerSheet<void>(
      builder: (BuildContext context) {
        return _PlayerSheetScaffold(
          child: _PlayerOptionSheet(
            title: 'Subtitles',
            onBack: () => Navigator.of(context).pop(),
            child: ListView(
              shrinkWrap: true,
              children: <Widget>[
                _PlayerOptionRow(
                  title: 'Off',
                  selected: !_subtitlesEnabled,
                  onTap: () {
                    Navigator.of(context).pop();
                    _disableSubtitles();
                  },
                ),
                _PlayerOptionRow(
                  title: 'Auto select',
                  subtitle: 'Tap again to auto select a different subtitle',
                  selected: _subtitlesEnabled && _selectedCaption == null,
                  onTap: () {
                    Navigator.of(context).pop();
                    _enableAutoSubtitles();
                  },
                ),
                for (final MapEntry<String, List<StreamCaption>> entry
                    in groupedCaptions.entries)
                  _PlayerOptionRow(
                    title: entry.key,
                    subtitle: '${entry.value.length} track${entry.value.length == 1 ? '' : 's'}',
                    selected: _selectedCaption != null &&
                        entry.value.contains(_selectedCaption),
                    showChevron: true,
                    onTap: () {
                      Navigator.of(context).pop();
                      _openSubtitleLanguageSheet(entry.key, entry.value);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openSubtitleLanguageSheet(
    String language,
    List<StreamCaption> captions,
  ) async {
    await _showPlayerSheet<void>(
      builder: (BuildContext context) {
        return _PlayerSheetScaffold(
          child: _PlayerOptionSheet(
            title: language,
            trailingIcon: Icons.sync_alt_rounded,
            onBack: () => Navigator.of(context).pop(),
            onTrailingTap: () {
              Navigator.of(context).pop();
              _openSubtitlesSheet();
            },
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: captions.length,
              itemBuilder: (BuildContext context, int index) {
                final StreamCaption caption = captions[index];
                final bool isSelected = caption == _selectedCaption;

                return _PlayerCaptionRow(
                  caption: caption,
                  selected: isSelected,
                  onTap: () {
                    Navigator.of(context).pop();
                    _selectCaption(caption);
                  },
                );
              },
            ),
          ),
        );
      },
    );
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

    final NavigatorState navigator = Navigator.of(context);
    await _persistProgress();
    if (!mounted) {
      return;
    }
    await navigator.pushReplacement(
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

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          unawaited(_persistProgress());
        }
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
                  qualityLabel: _currentQualityLabel,
                  subtitleLabel: _currentSubtitleLabel,
                  isPlaying: _playing,
                  position: _position,
                  duration: _duration,
                  buffered: _buffer,
                  showNextEpisode: _shouldShowNextEpisode,
                  nextEpisodeLabel: _nextEpisodeTarget?.label,
                  onBack: () async {
                    final NavigatorState navigator = Navigator.of(context);
                    await _persistProgress();
                    if (!mounted) {
                      return;
                    }
                    await navigator.maybePop();
                  },
                  onPlayPause: _togglePlayback,
                  onSeekBack: () => _seekRelative(-10),
                  onSeekForward: () => _seekRelative(10),
                  onSeek: _seekToFraction,
                  onOpenSettings: _openPlayerSettingsSheet,
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

  List<MapEntry<String, StreamQuality>> get _availableQualities {
    return widget.args.streamResult.stream.qualities.entries
        .where((MapEntry<String, StreamQuality> entry) {
          return entry.value.url?.isNotEmpty == true;
        })
        .toList(growable: false);
  }

  Map<String, List<StreamCaption>> get _groupedCaptionsByLanguage {
    final Map<String, List<StreamCaption>> grouped =
        <String, List<StreamCaption>>{};
    for (final StreamCaption caption in _availableCaptions) {
      final String key = caption.language ?? caption.label ?? 'Unknown';
      grouped.putIfAbsent(key, () => <StreamCaption>[]).add(caption);
    }
    return grouped;
  }

  String get _currentQualityLabel {
    return _selectedQualityKey ??
        widget.args.streamResult.stream.selectedQuality ??
        (_availableQualities.isNotEmpty ? _availableQualities.first.key : 'Auto');
  }

  String get _currentSubtitleLabel {
    if (!_subtitlesEnabled) {
      return 'Off';
    }
    return _selectedCaption?.label ??
        _selectedCaption?.language ??
        (_availableCaptions.isNotEmpty ? 'Auto' : 'Embedded');
  }

  String get _currentAudioLabel {
    return widget.args.streamResult.stream.playbackType ??
        widget.args.streamResult.embedName ??
        'Default';
  }

  Future<void> _applySelectedSubtitleTrack() async {
    if (!_subtitlesEnabled) {
      await _player.setSubtitleTrack(SubtitleTrack.no());
      return;
    }

    if (_selectedCaption?.url?.isNotEmpty == true) {
      final StreamCaption caption = _selectedCaption!;
      await _player.setSubtitleTrack(
        SubtitleTrack.uri(
          caption.url!,
          title: caption.label ?? caption.language ?? 'Subtitles',
          language: caption.language ?? 'unknown',
        ),
      );
      return;
    }

    if (_player.state.tracks.subtitle.isNotEmpty) {
      await _player.setSubtitleTrack(SubtitleTrack.auto());
      return;
    }

    if (_availableCaptions.isNotEmpty) {
      final StreamCaption caption = _availableCaptions.first;
      _selectedCaption = caption;
      await _player.setSubtitleTrack(
        SubtitleTrack.uri(
          caption.url!,
          title: caption.label ?? caption.language ?? 'Subtitles',
          language: caption.language ?? 'unknown',
        ),
      );
      return;
    }

    _subtitlesEnabled = false;
  }

  Future<void> _selectQuality(String? qualityKey) async {
    final int resumeFrom = _position.inSeconds;
    final String? qualityUrl = qualityKey == null
        ? null
        : widget.args.streamResult.stream.qualities[qualityKey]?.url;

    if (qualityKey != null && (qualityUrl == null || qualityUrl.isEmpty)) {
      _setSubtitleState(
        enabled: _subtitlesEnabled,
        message: 'Selected quality is unavailable',
      );
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedQualityKey = qualityKey;
      _selectedQualityUrl = qualityUrl;
      _playerReady = false;
      _buffering = true;
    });

    await _openStream(resumeFrom: resumeFrom);
    _setSubtitleState(
      enabled: _subtitlesEnabled,
      message:
          qualityKey == null ? 'Automatic quality enabled' : 'Quality: $qualityKey',
    );
  }

  Future<void> _disableSubtitles() async {
    _selectedCaption = null;
    await _player.setSubtitleTrack(SubtitleTrack.no());
    _setSubtitleState(enabled: false, message: 'Subtitles off');
    _showControls();
  }

  Future<void> _enableAutoSubtitles() async {
    _selectedCaption = null;

    if (_availableCaptions.isEmpty && _player.state.tracks.subtitle.isEmpty) {
      _setSubtitleState(enabled: false, message: 'No subtitles available');
      _showControls();
      return;
    }

    _subtitlesEnabled = true;
    await _applySelectedSubtitleTrack();
    _setSubtitleState(enabled: true, message: 'Subtitles auto');
    _showControls();
  }

  Future<void> _selectCaption(StreamCaption caption) async {
    if (caption.url?.isEmpty != false) {
      _setSubtitleState(enabled: false, message: 'Subtitle track unavailable');
      return;
    }

    _selectedCaption = caption;
    await _player.setSubtitleTrack(
      SubtitleTrack.uri(
        caption.url!,
        title: caption.label ?? caption.language ?? 'Subtitles',
        language: caption.language ?? 'unknown',
      ),
    );
    _setSubtitleState(
      enabled: true,
      message: caption.label ?? caption.language ?? 'Subtitles on',
    );
    _showControls();
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

class _PlayerSheetScaffold extends StatelessWidget {
  const _PlayerSheetScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x3,
          AppSpacing.x3,
          AppSpacing.x3,
          AppSpacing.x4,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.blackC50.withValues(alpha: 0.98),
            borderRadius: BorderRadius.circular(AppSpacing.x5),
            border: Border.all(color: AppColors.videoContextBorder),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.x5),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _PlayerSettingsHomeSheet extends StatelessWidget {
  const _PlayerSettingsHomeSheet({
    required this.qualityLabel,
    required this.sourceLabel,
    required this.subtitleLabel,
    required this.audioLabel,
    required this.subtitlesEnabled,
    required this.subtitlesAvailable,
    required this.onQualityTap,
    required this.onSourceTap,
    required this.onSubtitlesTap,
    required this.onSubtitleToggle,
  });

  final String qualityLabel;
  final String sourceLabel;
  final String subtitleLabel;
  final String audioLabel;
  final bool subtitlesEnabled;
  final bool subtitlesAvailable;
  final VoidCallback onQualityTap;
  final VoidCallback onSourceTap;
  final VoidCallback onSubtitlesTap;
  final ValueChanged<bool> onSubtitleToggle;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: AppSpacing.x3,
            runSpacing: AppSpacing.x3,
            children: <Widget>[
              _PlayerSettingsCard(
                title: 'Quality',
                subtitle: qualityLabel,
                onTap: onQualityTap,
              ),
              _PlayerSettingsCard(
                title: 'Source',
                subtitle: sourceLabel,
                onTap: onSourceTap,
              ),
              _PlayerSettingsCard(
                title: 'Subtitles',
                subtitle: subtitleLabel,
                onTap: onSubtitlesTap,
              ),
              _PlayerSettingsCard(
                title: 'Audio',
                subtitle: audioLabel,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x5),
          const Divider(color: AppColors.utilsDivider, height: AppSpacing.x0),
          const SizedBox(height: AppSpacing.x4),
          _PlayerToggleRow(
            title: 'Enable subtitles',
            subtitle: subtitlesAvailable
                ? 'Use auto select or choose a language-specific track.'
                : 'No subtitle tracks are available for this stream.',
            value: subtitlesEnabled,
            enabled: subtitlesAvailable,
            onChanged: onSubtitleToggle,
          ),
          const SizedBox(height: AppSpacing.x3),
          const _PlayerInlineInfoRow(
            title: 'Playback settings',
            subtitle: 'Quality, source, subtitles, and stream-specific options.',
          ),
        ],
      ),
    );
  }
}

class _PlayerSettingsCard extends StatelessWidget {
  const _PlayerSettingsCard({
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final double width = (MediaQuery.sizeOf(context).width - AppSpacing.x12) / 2;
    return SizedBox(
      width: width.clamp(140, 220).toDouble(),
      child: Material(
        color: AppColors.blackC125,
        borderRadius: BorderRadius.circular(AppSpacing.x4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.x4),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x4,
              vertical: AppSpacing.x4,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.typeEmphasis,
                      ),
                ),
                const SizedBox(height: AppSpacing.x2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.typeSecondary,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerOptionSheet extends StatelessWidget {
  const _PlayerOptionSheet({
    required this.title,
    required this.child,
    required this.onBack,
    this.footer,
    this.trailingText,
    this.trailingIcon,
    this.onTrailingTap,
  });

  final String title;
  final Widget child;
  final VoidCallback onBack;
  final Widget? footer;
  final String? trailingText;
  final IconData? trailingIcon;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: AppSpacing.x2),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.typeEmphasis,
                      ),
                ),
              ),
              if (trailingText != null)
                TextButton(
                  onPressed: onTrailingTap,
                  child: Text(trailingText!),
                ),
              if (trailingIcon != null)
                IconButton(
                  onPressed: onTrailingTap,
                  icon: Icon(trailingIcon),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.x3),
          const Divider(color: AppColors.utilsDivider, height: AppSpacing.x0),
          const SizedBox(height: AppSpacing.x3),
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.46,
            child: child,
          ),
          if (footer != null) ...<Widget>[
            const SizedBox(height: AppSpacing.x3),
            const Divider(color: AppColors.utilsDivider, height: AppSpacing.x0),
            const SizedBox(height: AppSpacing.x3),
            footer!,
          ],
        ],
      ),
    );
  }
}

class _PlayerOptionRow extends StatelessWidget {
  const _PlayerOptionRow({
    required this.title,
    required this.onTap,
    this.subtitle,
    this.selected = false,
    this.showChevron = false,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool selected;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.x4),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x2,
            vertical: AppSpacing.x3,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: selected
                                ? AppColors.typeEmphasis
                                : AppColors.typeText,
                          ),
                    ),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.x1),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              if (showChevron)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.typeSecondary,
                ),
              if (selected)
                const Padding(
                  padding: EdgeInsets.only(left: AppSpacing.x2),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.purpleC100,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerCaptionRow extends StatelessWidget {
  const _PlayerCaptionRow({
    required this.caption,
    required this.selected,
    required this.onTap,
  });

  final StreamCaption caption;
  final bool selected;
  final VoidCallback onTap;

  String _languageBadge(String? value) {
    final String normalized = (value == null || value.trim().isEmpty)
        ? '??'
        : value.trim().toUpperCase();
    return normalized.length >= 2 ? normalized.substring(0, 2) : normalized;
  }

  @override
  Widget build(BuildContext context) {
    final List<String> badges = <String>[
      if (caption.type?.isNotEmpty == true) caption.type!,
      if (caption.raw['source'] != null) '${caption.raw['source']}',
    ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.x4),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x2,
            vertical: AppSpacing.x3,
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: AppSpacing.x10,
                height: AppSpacing.x10,
                decoration: BoxDecoration(
                  color: AppColors.blackC125,
                  borderRadius: BorderRadius.circular(AppSpacing.x3),
                ),
                alignment: Alignment.center,
                child: Text(
                  _languageBadge(caption.language),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.typeEmphasis,
                      ),
                ),
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      caption.label ?? caption.language ?? 'Subtitle track',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.typeEmphasis,
                          ),
                    ),
                    if (badges.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.x2),
                      Wrap(
                        spacing: AppSpacing.x2,
                        runSpacing: AppSpacing.x2,
                        children: badges
                            .map(
                              (String badge) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.x2,
                                  vertical: AppSpacing.x1,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.blackC125,
                                  borderRadius:
                                      BorderRadius.circular(AppSpacing.x2),
                                ),
                                child: Text(
                                  badge.toUpperCase(),
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: AppColors.typeEmphasis,
                                      ),
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.purpleC100,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerToggleRow extends StatelessWidget {
  const _PlayerToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: enabled
                          ? AppColors.typeEmphasis
                          : AppColors.typeSecondary,
                    ),
              ),
              const SizedBox(height: AppSpacing.x1),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.x3),
        Switch(
          value: value,
          onChanged: enabled ? onChanged : null,
        ),
      ],
    );
  }
}

class _PlayerInlineInfoRow extends StatelessWidget {
  const _PlayerInlineInfoRow({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.x1),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        const Icon(
          Icons.chevron_right_rounded,
          color: AppColors.typeSecondary,
        ),
      ],
    );
  }
}
