class StreamResult {
  const StreamResult({
    required this.sourceId,
    required this.sourceName,
    required this.embedId,
    required this.embedName,
    required this.stream,
  });

  final String sourceId;
  final String sourceName;
  final String? embedId;
  final String? embedName;
  final StreamPlayback stream;

  factory StreamResult.fromJson(Map<String, dynamic> json) {
    return StreamResult(
      sourceId: '${json['sourceId'] ?? ''}',
      sourceName: '${json['sourceName'] ?? ''}',
      embedId: _parseNullableString(json['embedId']),
      embedName: _parseNullableString(json['embedName']),
      stream: StreamPlayback.fromJson(
        Map<String, dynamic>.from(json['stream'] as Map? ?? const {}),
      ),
    );
  }

  static String? _parseNullableString(dynamic value) {
    if (value == null) {
      return null;
    }

    final String parsed = '$value'.trim();
    return parsed.isEmpty ? null : parsed;
  }
}

class StreamPlayback {
  const StreamPlayback({
    required this.id,
    required this.type,
    required this.playlist,
    required this.playbackUrl,
    required this.playbackType,
    required this.selectedQuality,
    required this.qualities,
    required this.headers,
    required this.preferredHeaders,
    required this.captions,
    required this.flags,
  });

  final String? id;
  final String? type;
  final String? playlist;
  final String? playbackUrl;
  final String? playbackType;
  final String? selectedQuality;
  final Map<String, StreamQuality> qualities;
  final Map<String, String> headers;
  final Map<String, String> preferredHeaders;
  final List<StreamCaption> captions;
  final List<String> flags;

  factory StreamPlayback.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> qualitiesJson = Map<String, dynamic>.from(
      json['qualities'] as Map? ?? const {},
    );

    return StreamPlayback(
      id: _parseNullableString(json['id']),
      type: _parseNullableString(json['type']),
      playlist: _parseNullableString(json['playlist']),
      playbackUrl: _parseNullableString(json['playbackUrl']),
      playbackType: _parseNullableString(json['playbackType']),
      selectedQuality: _parseNullableString(json['selectedQuality']),
      qualities: qualitiesJson.map(
        (Object? key, Object? value) => MapEntry(
          '$key',
          StreamQuality.fromJson(
            Map<String, dynamic>.from(value as Map? ?? const {}),
          ),
        ),
      ),
      headers: _stringMap(json['headers']),
      preferredHeaders: _stringMap(json['preferredHeaders']),
      captions: ((json['captions'] as List?) ?? const <dynamic>[])
          .map(
            (dynamic item) => StreamCaption.fromJson(
              Map<String, dynamic>.from(item as Map? ?? const {}),
            ),
          )
          .toList(),
      flags: ((json['flags'] as List?) ?? const <dynamic>[])
          .map((dynamic item) => '$item')
          .toList(),
    );
  }

  static Map<String, String> _stringMap(dynamic value) {
    return (value as Map? ?? const {}).map(
      (Object? key, Object? item) => MapEntry('$key', '$item'),
    );
  }

  static String? _parseNullableString(dynamic value) {
    if (value == null) {
      return null;
    }

    final String parsed = '$value'.trim();
    return parsed.isEmpty ? null : parsed;
  }
}

class StreamQuality {
  const StreamQuality({required this.url, required this.type});

  final String? url;
  final String? type;

  factory StreamQuality.fromJson(Map<String, dynamic> json) {
    return StreamQuality(
      url: _parseNullableString(json['url']),
      type: _parseNullableString(json['type']),
    );
  }

  static String? _parseNullableString(dynamic value) {
    if (value == null) {
      return null;
    }

    final String parsed = '$value'.trim();
    return parsed.isEmpty ? null : parsed;
  }
}

class StreamCaption {
  const StreamCaption({
    required this.url,
    required this.language,
    required this.type,
    required this.label,
    required this.raw,
  });

  final String? url;
  final String? language;
  final String? type;
  final String? label;
  final Map<String, dynamic> raw;

  factory StreamCaption.fromJson(Map<String, dynamic> json) {
    return StreamCaption(
      url: _parseNullableString(json['url']),
      language: _parseNullableString(json['language']),
      type: _parseNullableString(json['type']),
      label: _parseNullableString(json['label']),
      raw: json,
    );
  }

  static String? _parseNullableString(dynamic value) {
    if (value == null) {
      return null;
    }

    final String parsed = '$value'.trim();
    return parsed.isEmpty ? null : parsed;
  }
}
