import 'dart:io';
import 'package:flutter/foundation.dart';
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
    // Legacy support fallback, real logic moved to updateDatabase
    await updateDatabase();
  }

  Future<void> updateDatabase({
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
      onProgress?.call('Подключение к серверу...', 0.0);
      // Используем 10.0.2.2 для доступа к localhost хостовой машины из эмулятора Android
      final client = http.Client();
      try {
        final request = http.Request(
          'GET',
          Uri.parse('https://pub-5977a84384ea4066a1ca832afe9ad29d.r2.dev/movies.zip'),
        );
        // Запрещаем кэширование
        request.headers['Cache-Control'] =
            'no-cache, no-store, must-revalidate';
        // Убираем Connection: close, так как иногда это заставляет Werkzeug рвать сокет жестко.

        final response = await client.send(request);

        debugPrint(
          'updateDatabase: Ответ получен, statusCode = ${response.statusCode}',
        );

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
            debugPrint(
              'updateDatabase: Стрим прервался ($streamError). Получено: $receivedBytes / $expectedBytes',
            );
            // Если сервер оборвал соединение сразу после последнего байта (что часто бывает с Werkzeug),
            // но мы получили все ожидаемые байты (или хотя бы сколько-то, если размер неизвестен), продолжаем.
            if (expectedBytes > 0 && receivedBytes < expectedBytes) {
              throw Exception(
                'Архив недокачан: $receivedBytes из $expectedBytes',
              );
            }
          }

          debugPrint('updateDatabase: Распаковка базы данных...');
          onProgress?.call('Распаковка базы данных...', null);
          // Выполняем распаковку
          final archive = ZipDecoder().decodeBytes(bytes);
          debugPrint('updateDatabase: Архив распакован, ищем .db файл...');

          for (final file in archive) {
            if (file.isFile && file.name.endsWith('.db')) {
              debugPrint(
                'updateDatabase: Найден файл \${file.name}, сохраняем в \$dbPath',
              );

              // КРИТИЧНО: удаляем старую БД через API sqflite,
              // чтобы заодно удалились файлы -wal и -journal
              if (await databaseExists(dbPath)) {
                await deleteDatabase(dbPath);
              }

              final data = file.content as List<int>;
              File(dbPath)
                ..createSync(recursive: true)
                ..writeAsBytesSync(data);
              debugPrint('updateDatabase: Файл успешно сохранен!');
              break;
            }
          }

          onProgress?.call('Готово!', 1.0);
          debugPrint('updateDatabase: Успешно завершено.');
        } else {
          final err =
              'Ошибка сервера: \${response.statusCode} - \${response.reasonPhrase}';
          debugPrint('updateDatabase: \$err');
          throw Exception(err);
        }
      } finally {
        client.close();
      }
    } catch (e, stackTrace) {
      debugPrint('updateDatabase: Исключение: $e\\n$stackTrace');
      throw Exception('Ошибка скачивания БД: $e');
    }

    _database = await openDatabase(dbPath);
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

  Future<List<Movie>> searchMovies(String query) async {
    final db = await database;
    // Заменяем "ё" на "е" в строке поиска для удобства
    final normalizedQuery =
        "%${query.replaceAll('ё', 'е').replaceAll('Ё', 'Е')}%";

    final maps = await db.query(
      'movies',
      // Используем REPLACE(title, 'ё', 'е') чтобы в базе искать как по "е"
      where:
          "REPLACE(LOWER(title), 'ё', 'е') LIKE LOWER(?) OR REPLACE(LOWER(original_title), 'ё', 'е') LIKE LOWER(?)",
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
