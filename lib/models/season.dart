import 'package:pstream_android/models/episode.dart';

class Season {
  const Season({
    required this.id,
    required this.number,
    required this.title,
    this.episodes = const <Episode>[],
  });

  final String id;
  final int number;
  final String title;
  final List<Episode> episodes;

  factory Season.fromTmdb(Map<String, dynamic> json) {
    final int number = _parseInt(json['season_number'] ?? json['number']);
    final String title =
        ((json['name'] ?? json['title']) as String?)?.trim() ?? '';

    return Season(
      id: '${json['id'] ?? ''}',
      number: number,
      title: title.isEmpty ? 'Season $number' : title,
      episodes: ((json['episodes'] as List?) ?? const <dynamic>[])
          .map((dynamic episode) => Episode.fromTmdb(_asMap(episode)))
          .toList(),
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse('$value') ?? 0;
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    return Map<String, dynamic>.from(
      value as Map? ?? const <String, dynamic>{},
    );
  }
}
