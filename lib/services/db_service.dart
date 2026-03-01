import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    // Legacy support fallback, real logic moved to updateDatabase
    await updateDatabase();
  }

  Future<int> updateDatabase({
    Function(String status, double? progress)? onProgress,
  }) async {
    final databasesPath = await getDatabasesPath();
    final dbPath = join(databasesPath, 'movies.db');

    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }

    try {
      debugPrint('updateDatabase: Подключение к серверу...');
      onProgress?.call('Проверка обновлений...', 0.0);

      final client = http.Client();
      try {
        // 1. Проверяем хеш MD5
        String remoteHash = '';
        try {
          final hashResponse = await client.get(
            Uri.parse(
              'https://pub-5977a84384ea4066a1ca832afe9ad29d.r2.dev/movies.md5',
            ),
          );
          if (hashResponse.statusCode == 200) {
            remoteHash = hashResponse.body.trim();
            final prefs = await SharedPreferences.getInstance();
            final localHash = prefs.getString('movies_db_hash');

            // Если хеши совпадают и файл базы реально существует на устройстве
            if (localHash == remoteHash && await databaseExists(dbPath)) {
              debugPrint('Обновление не требуется. Хеш: $localHash');
              onProgress?.call('Обновления отсутствуют', 1.0);
              _database = await openDatabase(dbPath);
              return 2; // Возвращаем статус "Нет обновлений"
            }
          }
        } catch (e) {
          debugPrint('Ошибка при проверке хеша: $e');
        }

        // 2. Скачиваем архив, если хеш отличается или базы нет
        final request = http.Request(
          'GET',
          Uri.parse(
            'https://pub-5977a84384ea4066a1ca832afe9ad29d.r2.dev/movies.zip',
          ),
        );
        request.headers['Cache-Control'] =
            'no-cache, no-store, must-revalidate';

        final response = await client.send(request);

        if (response.statusCode == 200) {
          final expectedBytes = response.contentLength ?? 0;
          int receivedBytes = 0;
          final List<int> bytes = [];

          try {
            await for (final chunk in response.stream) {
              bytes.addAll(chunk);
              receivedBytes += chunk.length;
              if (expectedBytes > 0) {
                onProgress?.call(
                  'Скачивание архива...',
                  receivedBytes / expectedBytes,
                );
              } else {
                onProgress?.call('Скачивание архива...', null);
              }
            }
          } catch (streamError) {
            if (expectedBytes > 0 && receivedBytes < expectedBytes) {
              throw Exception(
                'Архив недокачан: $receivedBytes из $expectedBytes',
              );
            }
          }

          onProgress?.call('Распаковка базы данных...', null);
          final archive = ZipDecoder().decodeBytes(bytes);

          for (final file in archive) {
            if (file.isFile && file.name.endsWith('.db')) {
              if (await databaseExists(dbPath)) {
                await deleteDatabase(dbPath);
              }

              final data = file.content as List<int>;
              File(dbPath)
                ..createSync(recursive: true)
                ..writeAsBytesSync(data);

              // КРИТИЧНО: Запоминаем новый хеш после успешной установки
              if (remoteHash.isNotEmpty) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('movies_db_hash', remoteHash);
              }
              break;
            }
          }

          onProgress?.call('Готово!', 1.0);
          _database = await openDatabase(dbPath);
          return 1; // Успешно обновлено
        } else {
          throw Exception('Ошибка сервера: ${response.statusCode}');
        }
      } finally {
        client.close();
      }
    } catch (e, stackTrace) {
      debugPrint('updateDatabase: Исключение: $e\n$stackTrace');
      throw Exception('Ошибка скачивания БД: $e');
    }
  }

  Future<List<Movie>> getMovies({
    int limit = 100,
    int offset = 0,
    String category = 'movies',
    List<int> favoriteIds = const [],
    bool onlyWithTorrents = false,
    int? yearExact,
    int? yearStart,
    int? yearEnd,
    List<String> genres = const [],
    bool excludeGenres = false,
  }) async {
    final db = await database;
    List<String> conditions = [];
    List<dynamic> args = [];

    if (category == 'cartoons') {
      conditions.add(
        "(genres LIKE '%мультфильм%' OR genres LIKE '%анимация%')",
      );
    } else if (category == 'series') {
      conditions.add("genres LIKE '%сериал%'");
    } else if (category == 'favorites') {
      if (favoriteIds.isEmpty) return [];
      conditions.add("id IN (${favoriteIds.join(',')})");
    } else {
      conditions.add(
        "genres NOT LIKE '%сериал%' AND genres NOT LIKE '%мультфильм%' AND genres NOT LIKE '%анимация%'",
      );
    }

    if (onlyWithTorrents) {
      conditions.add("id IN (SELECT DISTINCT movie_id FROM torrents)");
    }

    if (yearExact != null) {
      conditions.add("CAST(SUBSTR(release_date, 1, 4) AS INTEGER) = ?");
      args.add(yearExact);
    } else if (yearStart != null && yearEnd != null) {
      conditions.add(
        "CAST(SUBSTR(release_date, 1, 4) AS INTEGER) BETWEEN ? AND ?",
      );
      args.add(yearStart);
      args.add(yearEnd);
    }

    if (genres.isNotEmpty) {
      List<String> genreConds = [];
      for (var g in genres) {
        genreConds.add("genres ${excludeGenres ? 'NOT ' : ''}LIKE ?");
        args.add('%$g%');
      }
      conditions.add(
        "(" + genreConds.join(excludeGenres ? ' AND ' : ' OR ') + ")",
      );
    }

    final whereString = conditions.isEmpty ? null : conditions.join(' AND ');

    final maps = await db.query(
      'movies',
      where: whereString,
      whereArgs: args.isEmpty ? null : args,
      limit: limit,
      offset: offset,
    );

    return maps.map((map) => Movie.fromMap(map)).toList();
  }

  Future<List<Movie>> searchMovies(
    String query, {
    bool onlyWithTorrents = false,
  }) async {
    final db = await database;
    // Заменяем "ё" на "е" в строке поиска для удобства
    final normalizedQuery =
        "%${query.replaceAll('ё', 'е').replaceAll('Ё', 'Е')}%";

    final maps = await db.query(
      'movies',
      // Используем REPLACE(title, 'ё', 'е') чтобы в базе искать как по "е"
      where:
          "(REPLACE(LOWER(title), 'ё', 'е') LIKE LOWER(?) OR REPLACE(LOWER(original_title), 'ё', 'е') LIKE LOWER(?))" +
          (onlyWithTorrents
              ? " AND id IN (SELECT DISTINCT movie_id FROM torrents)"
              : ""),
      whereArgs: [normalizedQuery, normalizedQuery],
      limit: 50, // Ограничим выдачу
    );
    return maps.map((map) => Movie.fromMap(map)).toList();
  }

  Future<Map<String, int>> getDbStats() async {
    final db = await database;

    // Total movies
    final totalResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM movies',
    );
    int totalMovies = Sqflite.firstIntValue(totalResult) ?? 0;

    // Movies with torrents (distinct movie_id in torrents table)
    final withTorrentsResult = await db.rawQuery(
      'SELECT COUNT(DISTINCT movie_id) as count FROM torrents',
    );
    int moviesWithTorrents = Sqflite.firstIntValue(withTorrentsResult) ?? 0;

    return {
      'total': totalMovies,
      'with_torrents': moviesWithTorrents,
      'without_torrents': totalMovies - moviesWithTorrents,
    };
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
