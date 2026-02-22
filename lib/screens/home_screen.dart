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
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    childAspectRatio: 0.67,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount:
                      provider.movies.length + (provider.isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == provider.movies.length) {
                      return const Center(child: CircularProgressIndicator());
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
