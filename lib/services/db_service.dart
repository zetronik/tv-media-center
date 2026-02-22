import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';

import '../models/movie.dart';
import '../models/torrent.dart';

class DbService {
  DbService._privateConstructor();
  static final DbService instance = DbService._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    await init();
    return _database!;
  }

  Future<void> init() async {
    final databasesPath = await getDatabasesPath();
    final dbPath = join(databasesPath, 'movies.db');

    final dbFile = File(dbPath);
    if (!await dbFile.exists()) {
      await _downloadAndExtractDb(dbPath);
    }

    _database = await openDatabase(dbPath);
  }

  Future<void> _downloadAndExtractDb(String dbPath) async {
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8000/movies.zip'),
      );

      if (response.statusCode == 200) {
        final archive = ZipDecoder().decodeBytes(response.bodyBytes);

        for (final file in archive) {
          if (file.isFile && file.name.endsWith('.db')) {
            final data = file.content as List<int>;
            File(dbPath)
              ..createSync(recursive: true)
              ..writeAsBytesSync(data);
            break;
          }
        }
      } else {
        throw Exception('Failed to download database: \${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error downloading/extracting DB: \$e');
    }
  }

  Future<List<Movie>> getMovies({
    int limit = 20,
    int offset = 0,
    String category = 'movies',
    List<int> favoriteIds = const [],
  }) async {
    final db = await database;
    String? whereString;
    List<dynamic>? whereArguments;

    if (category == 'cartoons') {
      whereString = "genres LIKE '%мультфильм%' OR genres LIKE '%анимация%'";
    } else if (category == 'series') {
      whereString = "genres LIKE '%сериал%'";
    } else if (category == 'favorites') {
      if (favoriteIds.isEmpty)
        return []; // Если избранных нет, сразу возвращаем пустоту
      whereString = "id IN (${favoriteIds.join(',')})";
      whereArguments = null;
    } else {
      whereString =
          "genres NOT LIKE '%сериал%' AND genres NOT LIKE '%мультфильм%' AND genres NOT LIKE '%анимация%'";
    }

    final maps = await db.query(
      'movies',
      where: whereString,
      whereArgs: whereArguments,
      limit: limit,
      offset: offset,
    );

    return maps.map((map) => Movie.fromMap(map)).toList();
  }

  Future<List<Torrent>> getTorrentsForMovie(int movieId) async {
    final db = await database;
    final maps = await db.query(
      'torrents',
      where: 'movie_id = ?',
      whereArgs: [movieId],
      orderBy: 'seeds DESC', // Сортируем по сидам
    );
    return maps.map((map) => Torrent.fromMap(map)).toList();
  }
}
