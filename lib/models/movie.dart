class Movie {
  final int id;
  final String title;
  final String originalTitle;
  final String overview;
  final double rating;
  final String releaseDate;
  final String posterUrl;
  final String countries;
  final String genres;
  final String directors;
  final String actors;

  Movie({
    required this.id,
    required this.title,
    required this.originalTitle,
    required this.overview,
    required this.rating,
    required this.releaseDate,
    required this.posterUrl,
    this.countries = '',
    this.genres = '',
    this.directors = '',
    this.actors = '',
  });

  factory Movie.fromMap(Map<String, dynamic> map) {
    return Movie(
      id: map['id'] as int,
      title: map['title'] as String? ?? '',
      originalTitle:
          map['original_title'] as String? ??
          map['originalTitle'] as String? ??
          '',
      overview: map['overview'] as String? ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      releaseDate:
          map['release_date'] as String? ?? map['releaseDate'] as String? ?? '',
      posterUrl:
          map['poster_url'] as String? ?? map['posterUrl'] as String? ?? '',
      countries: (map['countries'] ?? map['country'] ?? '').toString(),
      genres: (map['genres'] ?? map['genre'] ?? '').toString(),
      directors: (map['directors'] ?? map['director'] ?? '').toString(),
      actors: (map['actors'] ?? map['actor'] ?? '').toString(),
    );
  }
}
