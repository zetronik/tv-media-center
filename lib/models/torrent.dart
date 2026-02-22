class Torrent {
  final int id;
  final int movieId;
  final String topicTitle;
  final double sizeGb;
  final String quality;
  final String fileFormat;
  final String translation;
  final String magnetLink;
  final int seeds;
  final int leeches;

  Torrent({
    required this.id,
    required this.movieId,
    required this.topicTitle,
    required this.sizeGb,
    required this.quality,
    required this.fileFormat,
    required this.translation,
    required this.magnetLink,
    required this.seeds,
    required this.leeches,
  });

  factory Torrent.fromMap(Map<String, dynamic> map) {
    double parseDouble(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String)
        return double.tryParse(val.replaceAll(RegExp(r'[^0-9\.]'), '')) ?? 0.0;
      return 0.0;
    }

    int parseInt(dynamic val) {
      if (val is num) return val.toInt();
      if (val is String)
        return int.tryParse(val.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      return 0;
    }

    return Torrent(
      id: parseInt(map['id']),
      movieId: parseInt(map['movie_id']),
      topicTitle: map['topic_title']?.toString() ?? '',
      sizeGb: parseDouble(map['size_gb']),
      quality: map['quality']?.toString() ?? '',
      fileFormat: map['file_format']?.toString() ?? '',
      translation: map['translation']?.toString() ?? '',
      magnetLink: map['magnet_link']?.toString() ?? '',
      seeds: parseInt(map['seeds']),
      leeches: parseInt(map['leeches']),
    );
  }
}
