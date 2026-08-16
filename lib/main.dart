import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/movie_provider.dart';
import 'providers/favorites_provider.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Дефолт — 100 МБ и 1000 объектов, что для Android TV с 1–2 ГБ ОЗУ много:
  // кэш успевает вытеснить постеры соседних рядов и провоцирует паузы GC.
  // Постеры декодируются под размер ячейки (см. _MoviePoster), поэтому 48 МБ
  // покрывают несколько экранов сетки с запасом.
  PaintingBinding.instance.imageCache
    ..maximumSizeBytes = 48 << 20
    ..maximumSize = 400;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProxyProvider<FavoritesProvider, MovieProvider>(
          create: (_) => MovieProvider(),
          update: (_, favProvider, movieProvider) =>
              movieProvider!..updateFavorites(favProvider.favoriteIds),
        ),
      ],
      child: MaterialApp(
        title: 'TV Media Center',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF141414),
          primarySwatch: Colors.red,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
