import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/movie_provider.dart';
import '../providers/favorites_provider.dart';
import '../widgets/movie_card.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        context.read<MovieProvider>().loadMoreMovies();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performStartupUpdate();
    });
  }

  Future<void> _performStartupUpdate() async {
    final provider = context.read<MovieProvider>();
    final success = await provider.initDbAndLoad();

    if (mounted && success) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF222222),
          title: const Text(
            'Обновление завершено',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'База данных успешно обновлена.\nВсего фильмов: ${provider.dbStats?["total"] ?? 0}',
            style: const TextStyle(color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildMenuButton(
    String title,
    String category,
    MovieProvider provider,
    FavoritesProvider favProvider,
  ) {
    return _MenuButton(
      title: title,
      isActive: provider.currentCategory == category,
      onTap: () {
        provider.setCategory(category);
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MovieProvider>(
      builder: (context, provider, child) {
        if (provider.isUpdatingDb) {
          return Scaffold(
            backgroundColor: const Color(0xFF141414),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.red),
                  const SizedBox(height: 24),
                  Text(
                    provider.updateStatus,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  if (provider.updateProgress != null) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 300,
                      child: LinearProgressIndicator(
                        value: provider.updateProgress,
                        color: Colors.red,
                        backgroundColor: Colors.white24,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              Container(
                width: 220,
                color: Colors.black87,
                child: Consumer2<MovieProvider, FavoritesProvider>(
                  builder: (context, movieProvider, favProvider, child) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Text(
                            'TV Media',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (movieProvider.dbStats != null)
                          Builder(
                            builder: (context) {
                              final stats = movieProvider.dbStats!;
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24.0,
                                  vertical: 8.0,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'БД: ${stats['total']} шт.',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'С торрентами: ${stats['with_torrents']}',
                                      style: const TextStyle(
                                        color: Colors.greenAccent,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Без торрентов: ${stats['without_torrents']}',
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 16),
                        _MenuButton(
                          title: 'Обновить БД',
                          isActive: false,
                          onTap: () {
                            _performStartupUpdate();
                          },
                        ),
                        _MenuButton(
                          title: 'Поиск',
                          isActive: false,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SearchScreen(),
                              ),
                            );
                          },
                        ),
                        _buildMenuButton(
                          'Фильмы',
                          'movies',
                          movieProvider,
                          favProvider,
                        ),
                        _buildMenuButton(
                          'Мультфильмы',
                          'cartoons',
                          movieProvider,
                          favProvider,
                        ),
                        _buildMenuButton(
                          'Сериалы',
                          'series',
                          movieProvider,
                          favProvider,
                        ),
                        _buildMenuButton(
                          'Избранное',
                          'favorites',
                          movieProvider,
                          favProvider,
                        ),
                        const Spacer(),
                      ],
                    );
                  },
                ),
              ),
              Expanded(
                child: Consumer<MovieProvider>(
                  builder: (context, provider, child) {
                    if (provider.isLoading && provider.movies.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (provider.movies.isEmpty) {
                      return const Center(
                        child: Text(
                          'Нет контента.',
                          style: TextStyle(fontSize: 18),
                        ),
                      );
                    }

                    return GridView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16.0),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            childAspectRatio: 0.67,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                      itemCount:
                          provider.movies.length + (provider.isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == provider.movies.length) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        return MovieCard(movie: provider.movies[index]);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MenuButton extends StatefulWidget {
  final String title;
  final bool isActive;
  final VoidCallback onTap;

  const _MenuButton({
    required this.title,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onFocusChange: (hasFocus) => setState(() => _isFocused = hasFocus),
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          color: widget.isActive
              ? Colors.red.withOpacity(0.8)
              : (_isFocused ? Colors.white12 : Colors.transparent),
          border: Border(
            left: BorderSide(
              color: widget.isActive ? Colors.white : Colors.transparent,
              width: 4,
            ),
          ),
        ),
        child: Text(
          widget.title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: widget.isActive ? FontWeight.bold : FontWeight.normal,
            color: widget.isActive || _isFocused
                ? Colors.white
                : Colors.grey[400],
          ),
        ),
      ),
    );
  }
}
