import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../providers/movie_provider.dart';
import '../providers/favorites_provider.dart';
import 'package:flutter/services.dart'; // Added import
import '../widgets/movie_card.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  String _appVersion = '';

  Future<void> _initAppVersion() async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = 'v${info.version} (build ${info.buildNumber})';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _initAppVersion();
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
    final result = await provider.initDbAndLoad();

    // Если result > 0, значит все прошло успешно (1 = скачалось, 2 = обновлять не нужно)
    if (mounted && result > 0) {
      String title = result == 2
          ? 'Обновления отсутствуют'
          : 'Обновление завершено';
      String content = result == 2
          ? 'У вас установлена самая актуальная версия базы данных.\nВсего фильмов: ${provider.dbStats?["total"] ?? 0}'
          : 'База данных успешно обновлена.\nВсего фильмов: ${provider.dbStats?["total"] ?? 0}';

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF222222),
          title: Text(title, style: const TextStyle(color: Colors.white)),
          content: Text(content, style: const TextStyle(color: Colors.grey)),
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

  void _showYearFilterDialog(BuildContext context, MovieProvider provider) {
    int? exactYear = provider.filterYearExact;
    int? startYear = provider.filterYearStart;
    int? endYear = provider.filterYearEnd;
    bool isRange = startYear != null || endYear != null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF222222),
            title: const Text(
              'Фильтр по году',
              style: TextStyle(color: Colors.white),
            ),
            content: SizedBox(
              width: 400,
              child: Builder(
                builder: (context) {
                  Widget buildTvTextField(
                    String label,
                    String? initialValue,
                    Function(String) onChanged,
                  ) {
                    return Focus(
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent) {
                          if (event.logicalKey ==
                              LogicalKeyboardKey.arrowDown) {
                            FocusManager.instance.primaryFocus?.nextFocus();
                            return KeyEventResult.handled;
                          } else if (event.logicalKey ==
                              LogicalKeyboardKey.arrowUp) {
                            FocusManager.instance.primaryFocus?.previousFocus();
                            return KeyEventResult.handled;
                          }
                        }
                        return KeyEventResult.ignored;
                      },
                      child: TextField(
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: label,
                          labelStyle: const TextStyle(color: Colors.grey),
                        ),
                        onChanged: onChanged,
                        controller: TextEditingController(
                          text: initialValue ?? '',
                        ),
                      ),
                    );
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SwitchListTile(
                        title: const Text(
                          'Выбрать период',
                          style: TextStyle(color: Colors.white),
                        ),
                        value: isRange,
                        activeColor: Colors.red,
                        onChanged: (val) {
                          setDialogState(() {
                            isRange = val;
                            if (val)
                              exactYear = null;
                            else {
                              startYear = null;
                              endYear = null;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      if (!isRange)
                        buildTvTextField(
                          'Точный год (например, 2023)',
                          exactYear?.toString(),
                          (val) => exactYear = int.tryParse(val),
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: buildTvTextField(
                                'От',
                                startYear?.toString(),
                                (val) => startYear = int.tryParse(val),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: buildTvTextField(
                                'До',
                                endYear?.toString(),
                                (val) => endYear = int.tryParse(val),
                              ),
                            ),
                          ],
                        ),
                    ],
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  provider.setYearFilter(null, null, null);
                  Navigator.pop(context);
                },
                child: const Text(
                  'Сбросить',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: () {
                  provider.setYearFilter(exactYear, startYear, endYear);
                  Navigator.pop(context);
                },
                child: const Text(
                  'Применить',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showGenreFilterDialog(BuildContext context, MovieProvider provider) {
    List<String> selectedGenres = List.from(provider.filterGenres);
    bool exclude = provider.filterExcludeGenres;
    final List<String> allGenres = [
      'боевик',
      'комедия',
      'драма',
      'фантастика',
      'триллер',
      'ужасы',
      'мелодрама',
      'детектив',
      'приключения',
      'фэнтези',
      'криминал',
      'семейный',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF222222),
            title: const Text(
              'Фильтр по жанрам',
              style: TextStyle(color: Colors.white),
            ),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: Text(
                      exclude ? 'Исключить выбранные' : 'Содержат выбранные',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    value: exclude,
                    activeColor: Colors.red,
                    onChanged: (val) => setDialogState(() => exclude = val),
                  ),
                  const Divider(color: Colors.grey),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: allGenres.length,
                      itemBuilder: (context, index) {
                        final genre = allGenres[index];
                        return CheckboxListTile(
                          title: Text(
                            genre,
                            style: const TextStyle(color: Colors.white),
                          ),
                          value: selectedGenres.contains(genre),
                          activeColor: Colors.red,
                          checkColor: Colors.white,
                          onChanged: (bool? checked) {
                            setDialogState(() {
                              if (checked == true)
                                selectedGenres.add(genre);
                              else
                                selectedGenres.remove(genre);
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  provider.setGenreFilter([], false);
                  Navigator.pop(context);
                },
                child: const Text(
                  'Сбросить',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: () {
                  provider.setGenreFilter(selectedGenres, exclude);
                  Navigator.pop(context);
                },
                child: const Text(
                  'Применить',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTvLayout = MediaQuery.of(context).size.height < 600;

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
                constraints: const BoxConstraints(minWidth: 180, maxWidth: 260),
                width: MediaQuery.of(context).size.width * 0.18,
                color: Colors.black87,
                child: Consumer2<MovieProvider, FavoritesProvider>(
                  builder: (context, movieProvider, favProvider, child) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: EdgeInsets.all(isTvLayout ? 16.0 : 24.0),
                          child: Text(
                            'TV Media',
                            style: TextStyle(
                              fontSize: isTvLayout ? 20 : 24,
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
                        SizedBox(height: isTvLayout ? 10 : 30),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
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
                                        builder: (context) =>
                                            const SearchScreen(),
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
                              ],
                            ),
                          ),
                        ),
                        if (_appVersion.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Text(
                              _appVersion,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
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

                    return Column(
                      children: [
                        Container(
                          height: isTvLayout ? 40 : 60,
                          color: Colors.black45,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(width: 16),
                              // 1. Чекбокс для торрентов
                              InkWell(
                                onTap: () => provider.toggleTorrentFilter(),
                                focusColor: Colors.white24,
                                borderRadius: BorderRadius.circular(4),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0,
                                    vertical: 4.0,
                                  ),
                                  child: Row(
                                    children: [
                                      Checkbox(
                                        value: provider.filterOnlyTorrents,
                                        onChanged: (val) =>
                                            provider.toggleTorrentFilter(),
                                        activeColor: Colors.red,
                                      ),
                                      Text(
                                        'Только с торрентами',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: isTvLayout ? 14 : 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // 2. Кнопка вызова диалога годов
                              _FilterButton(
                                title:
                                    'Год: ' +
                                    (provider.filterYearExact != null
                                        ? '${provider.filterYearExact}'
                                        : (provider.filterYearStart != null
                                              ? '${provider.filterYearStart}-${provider.filterYearEnd}'
                                              : 'Все')),
                                isActive:
                                    provider.filterYearExact != null ||
                                    provider.filterYearStart != null,
                                isTvLayout: isTvLayout,
                                onTap: () =>
                                    _showYearFilterDialog(context, provider),
                              ),
                              const SizedBox(width: 8),
                              // 3. Кнопка вызова диалога жанров
                              _FilterButton(
                                title:
                                    'Жанры: ' +
                                    (provider.filterGenres.isEmpty
                                        ? 'Все'
                                        : (provider.filterExcludeGenres
                                              ? 'Исключая (${provider.filterGenres.length})'
                                              : 'Включая (${provider.filterGenres.length})')),
                                isActive: provider.filterGenres.isNotEmpty,
                                isTvLayout: isTvLayout,
                                onTap: () =>
                                    _showGenreFilterDialog(context, provider),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: GridView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16.0),
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent:
                                      130, // Уменьшенный размер для TV
                                  childAspectRatio: 0.67,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                ),
                            itemCount:
                                provider.movies.length +
                                (provider.isLoading ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == provider.movies.length) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              return MovieCard(movie: provider.movies[index]);
                            },
                          ),
                        ),
                      ],
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
    // Если высота экрана меньше 600, считаем, что это TV-интерфейс
    final isTvLayout = MediaQuery.of(context).size.height < 600;
    final double vPadding = isTvLayout ? 8.0 : 16.0;
    final double hPadding = isTvLayout ? 16.0 : 24.0;
    final double fontSize = isTvLayout ? 14.0 : 18.0;

    return InkWell(
      onFocusChange: (hasFocus) => setState(() => _isFocused = hasFocus),
      onTap: widget.onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: vPadding, horizontal: hPadding),
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
            fontSize: fontSize,
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

class _FilterButton extends StatefulWidget {
  final String title;
  final bool isActive;
  final bool isTvLayout;
  final VoidCallback onTap;
  const _FilterButton({
    super.key,
    required this.title,
    required this.isActive,
    required this.isTvLayout,
    required this.onTap,
  });
  @override
  State<_FilterButton> createState() => _FilterButtonState();
}

class _FilterButtonState extends State<_FilterButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onFocusChange: (hasFocus) => setState(() => _isFocused = hasFocus),
      onTap: widget.onTap,
      // Добавляем скругление для эффекта нажатия (ripple), чтобы он не вылезал за края
      borderRadius: BorderRadius.circular(20),
      child: Container(
        // Жестко задаем высоту кнопки (32 для планшета, 28 для ТВ)
        height: widget.isTvLayout ? 28 : 32,
        padding: EdgeInsets.symmetric(horizontal: widget.isTvLayout ? 12 : 16),
        // Используем встроенное выравнивание контейнера вместо виджета Center
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _isFocused
              ? Colors.white24
              : (widget.isActive
                    ? Colors.red.withOpacity(0.3)
                    : Colors.transparent),
          border: Border.all(
            color: _isFocused
                ? Colors.white
                : (widget.isActive ? Colors.red : Colors.grey[800]!),
            width: _isFocused ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        // Убрали Center, оставили только Text
        child: Text(
          widget.title,
          style: TextStyle(
            color: Colors.white,
            fontSize: widget.isTvLayout ? 12 : 14,
          ),
        ),
      ),
    );
  }
}
