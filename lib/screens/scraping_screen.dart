import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pstream_android/models/media_item.dart';
import 'package:pstream_android/models/scrape_event.dart';
import 'package:pstream_android/models/stream_result.dart';
import 'package:pstream_android/screens/player_screen.dart';
import 'package:pstream_android/services/stream_service.dart';
import 'package:pstream_android/widgets/scrape_source_card.dart';

class ScrapingScreenArgs {
  const ScrapingScreenArgs({
    required this.mediaItem,
    this.season,
    this.episode,
  });

  final MediaItem mediaItem;
  final int? season;
  final int? episode;
}

class ScrapingScreen extends StatefulWidget {
  const ScrapingScreen({
    super.key,
    required this.mediaItem,
    this.season,
    this.episode,
    this.streamService = const StreamService(),
  });

  final MediaItem mediaItem;
  final int? season;
  final int? episode;
  final StreamService streamService;

  @override
  State<ScrapingScreen> createState() => _ScrapingScreenState();
}

class _ScrapingScreenState extends State<ScrapingScreen> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, ScrapeStatus> _statuses = <String, ScrapeStatus>{};
  final Map<String, _ScrapeNode> _nodes = <String, _ScrapeNode>{};
  final List<String> _sourceOrder = <String>[];
  final Map<String, String> _embedNameByScraperId = <String, String>{};

  StreamSubscription<ScrapeEvent>? _scrapeSubscription;
  bool _isLoading = true;
  bool _allFailure = false;
  String? _failureMessage;
  String? _currentPendingSourceId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _primeCatalogAndStart();
    });
  }

  @override
  void dispose() {
    _scrapeSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _primeCatalogAndStart() async {
    try {
      final ScrapeCatalog catalog = await widget.streamService.fetchCatalog();
      if (!mounted) {
        return;
      }

      if (catalog.sources.isNotEmpty) {
        _mergeSources(catalog.sources);
      }

      for (final ScrapeSourceDefinition embed in catalog.embeds) {
        _embedNameByScraperId[embed.id] = embed.name;
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
    }

    _startStreamScrape();
  }

  void _startStreamScrape() {
    _scrapeSubscription?.cancel();
    _scrapeSubscription = widget.streamService
        .scrapeStream(
          widget.mediaItem,
          season: widget.season,
          episode: widget.episode,
        )
        .listen(
      _handleEvent,
      onError: _handleError,
      onDone: () {
        if (!_hasSuccess() && mounted) {
          setState(() {
            _isLoading = false;
            _allFailure = true;
            _failureMessage ??= 'No sources found';
          });
        }
      },
    );
  }

  void _handleEvent(ScrapeEvent event) {
    switch (event.type) {
      case 'init':
        _mergeSources(event.sources);
        break;
      case 'start':
        final String? sourceId = event.sourceId;
        if (sourceId != null) {
          _updateStatus(sourceId, ScrapeStatus.pending);
          _scrollToSource(sourceId);
        }
        _setLoading(false);
        break;
      case 'update':
        final String? sourceId = event.sourceId;
        if (sourceId != null) {
          final ScrapeStatus status = _statusFromString(event.updateStatus);
          _updateStatus(sourceId, status);
          if (status == ScrapeStatus.pending) {
            _scrollToSource(sourceId);
          }
        }
        _setLoading(false);
        break;
      case 'embeds':
        _addEmbeds(event.sourceId, event.embeds);
        _setLoading(false);
        break;
      case 'done':
        _handleDone(event);
        break;
      case 'error':
        _handleFailure(event.errorMessage ?? 'Scraping failed.');
        break;
      default:
        break;
    }
  }

  void _handleDone(ScrapeEvent event) {
    _setLoading(false);

    final StreamResult? result = event.result;
    if (event.ok && result != null) {
      _updateStatus(result.sourceId, ScrapeStatus.success);
      if (result.embedId != null) {
        _updateStatus(result.embedId!, ScrapeStatus.success);
      }
      _navigateToPlayer(result);
      return;
    }

    _handleFailure(event.errorMessage ?? 'No sources found');
  }

  void _handleError(Object error, [StackTrace? stackTrace]) {
    if (!mounted) {
      return;
    }

    final String message = error is TimeoutException
        ? error.message ?? 'Scrape timed out.'
        : '$error';
    _handleFailure(message);
  }

  void _handleFailure(String message) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
      _failureMessage = message;
      if (!_hasSuccess()) {
        _allFailure = true;
        for (final String sourceId in _sourceOrder) {
          if (_statuses[sourceId] == ScrapeStatus.pending ||
              _statuses[sourceId] == ScrapeStatus.waiting) {
            _statuses[sourceId] = ScrapeStatus.failure;
          }
        }
      }
    });
  }

  void _mergeSources(List<ScrapeSourceDefinition> sources) {
    if (!mounted) {
      return;
    }

    setState(() {
      for (final ScrapeSourceDefinition source in sources) {
        if (!_nodes.containsKey(source.id)) {
          _nodes[source.id] = _ScrapeNode(
            id: source.id,
            name: source.name,
          );
          _sourceOrder.add(source.id);
        } else if (_nodes[source.id]!.name.isEmpty && source.name.isNotEmpty) {
          _nodes[source.id] = _nodes[source.id]!.copyWith(name: source.name);
        }

        _statuses.putIfAbsent(source.id, () => ScrapeStatus.waiting);
      }

      _isLoading = false;
    });
  }

  void _addEmbeds(String? sourceId, List<ScrapeSourceDefinition> embeds) {
    if (!mounted || sourceId == null || !_nodes.containsKey(sourceId)) {
      return;
    }

    setState(() {
      final _ScrapeNode sourceNode = _nodes[sourceId]!;
      final List<String> children = List<String>.from(sourceNode.embedIds);

      for (final ScrapeSourceDefinition embed in embeds) {
        final String embedName = embed.name.isNotEmpty
            ? embed.name
            : _embedNameByScraperId[embed.embedScraperId] ??
                embed.embedScraperId ??
                embed.id;

        _nodes.putIfAbsent(
          embed.id,
          () => _ScrapeNode(
            id: embed.id,
            name: embedName,
          ),
        );
        _statuses.putIfAbsent(embed.id, () => ScrapeStatus.waiting);
        if (!children.contains(embed.id)) {
          children.add(embed.id);
        }
      }

      _nodes[sourceId] = sourceNode.copyWith(embedIds: children);
    });
  }

  void _updateStatus(String id, ScrapeStatus status) {
    if (!mounted) {
      return;
    }

    setState(() {
      _statuses[id] = status;
      if (status == ScrapeStatus.pending) {
        _currentPendingSourceId = id;
      } else if (_currentPendingSourceId == id) {
        _currentPendingSourceId = null;
      }
    });
  }

  void _setLoading(bool value) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = value;
    });
  }

  bool _hasSuccess() {
    return _statuses.values.contains(ScrapeStatus.success);
  }

  void _scrollToSource(String sourceId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      final int index = _sourceOrder.indexOf(sourceId);
      if (index < 0) {
        return;
      }

      _scrollController.animateTo(
        index * 108,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _showManualPicker() async {
    if (_sourceOrder.isEmpty) {
      return;
    }

    final String? sourceId = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: ListView.builder(
            itemCount: _sourceOrder.length,
            itemBuilder: (BuildContext context, int index) {
              final String id = _sourceOrder[index];
              final _ScrapeNode? node = _nodes[id];
              if (node == null) {
                return const SizedBox.shrink();
              }

              return ListTile(
                minTileHeight: 48,
                title: Text(node.name),
                onTap: () => Navigator.of(context).pop(id),
              );
            },
          ),
        );
      },
    );

    if (sourceId == null || !mounted) {
      return;
    }

    await _retrySingleSource(sourceId);
  }

  Future<void> _retrySingleSource(String sourceId) async {
    setState(() {
      _allFailure = false;
      _failureMessage = null;
      _isLoading = true;
      _statuses[sourceId] = ScrapeStatus.pending;
      _currentPendingSourceId = sourceId;
    });

    _scrollToSource(sourceId);

    try {
      final StreamResult? result = await widget.streamService.scrapeSingleSource(
        widget.mediaItem,
        sourceId: sourceId,
        season: widget.season,
        episode: widget.episode,
      );

      if (!mounted) {
        return;
      }

      if (result == null) {
        setState(() {
          _isLoading = false;
          _statuses[sourceId] = ScrapeStatus.notfound;
          _allFailure = true;
          _failureMessage = 'No sources found';
        });
        return;
      }

      setState(() {
        _isLoading = false;
        _statuses[sourceId] = ScrapeStatus.success;
        if (result.embedId != null) {
          _statuses[result.embedId!] = ScrapeStatus.success;
        }
      });
      _navigateToPlayer(result);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _statuses[sourceId] = ScrapeStatus.failure;
        _allFailure = true;
        _failureMessage = '$error';
      });
    }
  }

  void _navigateToPlayer(StreamResult result) {
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => PlayerScreen(
          args: PlayerScreenArgs(
            mediaItem: widget.mediaItem,
            streamResult: result,
            season: widget.season,
            episode: widget.episode,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scraping ${widget.mediaItem.title}'),
      ),
      body: Column(
        children: <Widget>[
          if (_isLoading || _currentPendingSourceId != null)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _sourceOrder.isEmpty
                ? Center(
                    child: Text(
                      _isLoading ? 'Preparing sources...' : 'No sources found',
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _sourceOrder.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String sourceId = _sourceOrder[index];
                      final _ScrapeNode? source = _nodes[sourceId];
                      if (source == null) {
                        return const SizedBox.shrink();
                      }

                      return ScrapeSourceCard(
                        sourceName: source.name,
                        status: _statuses[sourceId] ?? ScrapeStatus.waiting,
                        embeds: source.embedIds
                            .map(
                              (String embedId) => ScrapeEmbedItem(
                                name: _nodes[embedId]?.name ?? embedId,
                                status: _statuses[embedId] ??
                                    ScrapeStatus.waiting,
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
          ),
          if (_allFailure)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    _failureMessage ?? 'No sources found',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _showManualPicker,
                    child: const Text('Try Manually'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

ScrapeStatus _statusFromString(String? value) {
  return switch (value) {
    'pending' => ScrapeStatus.pending,
    'success' => ScrapeStatus.success,
    'failure' => ScrapeStatus.failure,
    'notfound' => ScrapeStatus.notfound,
    _ => ScrapeStatus.waiting,
  };
}

class _ScrapeNode {
  const _ScrapeNode({
    required this.id,
    required this.name,
    this.embedIds = const <String>[],
  });

  final String id;
  final String name;
  final List<String> embedIds;

  _ScrapeNode copyWith({
    String? name,
    List<String>? embedIds,
  }) {
    return _ScrapeNode(
      id: id,
      name: name ?? this.name,
      embedIds: embedIds ?? this.embedIds,
    );
  }
}
