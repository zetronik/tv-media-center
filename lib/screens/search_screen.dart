import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../models/movie.dart';
import '../services/db_service.dart';
import '../widgets/movie_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  List<Movie> _results = [];
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _onlyWithTorrents = false;
  Timer? _debounce;
  late final FocusNode _searchFocusNode;
  String _kbdLayout = 'RU';

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode = FocusNode(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          // Открываем клавиатуру по нажатию ОК/Enter на пульте
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.gameButtonA) {
            SystemChannels.textInput.invokeMethod('TextInput.show');
            return KeyEventResult.handled;
          }
          // Принудительно отдаем фокус вниз по нажатию стрелки Вниз
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            node.unfocus();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
    );
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onTvKeyPressed(String key) {
    _searchController.text += key;
    setState(() {});
    _onSearchChanged();
  }

  void _onActionKey(String action) {
    String currentText = _searchController.text;
    if (action == 'BACKSPACE') {
      if (currentText.isNotEmpty) {
        _searchController.text = currentText.substring(
          0,
          currentText.length - 1,
        );
      }
    } else if (action == 'CLEAR') {
      _searchController.text = '';
    } else if (action == 'SPACE') {
      _searchController.text += ' ';
    } else if (action == 'LANG') {
      if (_kbdLayout == 'RU')
        _kbdLayout = 'EN';
      else if (_kbdLayout == 'EN')
        _kbdLayout = '123';
      else
        _kbdLayout = 'RU';
    }
    setState(() {});
    _onSearchChanged();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      final query = _searchController.text.trim();
      if (query.length >= 3) {
        _performSearch(query);
      } else if (query.isEmpty) {
        if (mounted) setState(() => _results = []);
      }
    });
  }

  Widget _buildTvKeyboard() {
    final ruKeys = [
      'А',
      'Б',
      'В',
      'Г',
      'Д',
      'Е',
      'Ё',
      'Ж',
      'З',
      'И',
      'Й',
      'К',
      'Л',
      'М',
      'Н',
      'О',
      'П',
      'Р',
      'С',
      'Т',
      'У',
      'Ф',
      'Х',
      'Ц',
      'Ч',
      'Ш',
      'Щ',
      'Ъ',
      'Ы',
      'Ь',
      'Э',
      'Ю',
      'Я',
    ];
    final enKeys = [
      'A',
      'B',
      'C',
      'D',
      'E',
      'F',
      'G',
      'H',
      'I',
      'J',
      'K',
      'L',
      'M',
      'N',
      'O',
      'P',
      'Q',
      'R',
      'S',
      'T',
      'U',
      'V',
      'W',
      'X',
      'Y',
      'Z',
    ];
    final numKeys = [
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
      '0',
      '-',
      '_',
      '+',
      '=',
      '@',
      '#',
      '\$',
      '%',
      '&',
      '*',
      '!',
      '?',
      ':',
      ';',
      '/',
      '\\',
    ];

    List<String> keys = _kbdLayout == 'RU'
        ? ruKeys
        : (_kbdLayout == 'EN' ? enKeys : numKeys);

    return Container(
      width: 260,
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Поле с текстом поиска
          Container(
            padding: const EdgeInsets.only(bottom: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white24)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _searchController.text.isEmpty
                        ? 'Поиск...'
                        : _searchController.text,
                    style: TextStyle(
                      fontSize: 18,
                      color: _searchController.text.isEmpty
                          ? Colors.grey
                          : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_speechToText.isListening)
                  const Icon(Icons.mic, color: Colors.red, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Блок функциональных кнопок (Верхний ряд)
          GridView.count(
            crossAxisCount: 6,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
            shrinkWrap: true,
            childAspectRatio: 1.0,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _TvKey(text: _kbdLayout, onTap: () => _onActionKey('LANG')),
              _TvKey(icon: Icons.space_bar, onTap: () => _onActionKey('SPACE')),
              _TvKey(
                icon: Icons.backspace_outlined,
                onTap: () => _onActionKey('BACKSPACE'),
              ),
              _TvKey(
                icon: Icons.delete_sweep,
                onTap: () => _onActionKey('CLEAR'),
              ),
              _TvKey(
                icon: _speechToText.isListening ? Icons.mic : Icons.mic_none,
                activeColor: _speechToText.isListening
                    ? Colors.red
                    : Colors.white,
                onTap: _speechToText.isNotListening
                    ? _startListening
                    : _speechToText.stop,
              ),
              _TvKey(
                icon: Icons.filter_alt,
                activeColor: _onlyWithTorrents ? Colors.red : Colors.white,
                onTap: () {
                  setState(() => _onlyWithTorrents = !_onlyWithTorrents);
                  if (_searchController.text.trim().length >= 3)
                    _performSearch(_searchController.text.trim());
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Сетка букв
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: keys.length,
              itemBuilder: (context, index) {
                return _TvKey(
                  text: keys[index],
                  onTap: () => _onTvKeyPressed(keys[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final results = await DbService.instance.searchMovies(
        query,
        onlyWithTorrents: _onlyWithTorrents,
      );
      if (mounted) {
        setState(() {
          _results = results;
        });
      }
    } catch (e) {
      debugPrint('Error searching movies: \$e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _startListening() async {
    await _speechToText.listen(onResult: _onSpeechResult);
    setState(() {});
  }

  void _onSpeechResult(result) {
    setState(() {
      _searchController.text = result.recognizedWords;
    });
    if (result.finalResult && result.recognizedWords.trim().length >= 3) {
      _performSearch(result.recognizedWords.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTvLayout = MediaQuery.of(context).size.height < 600;

    final resultsGrid = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _results.isEmpty
        ? const Center(
            child: Text(
              'Введите название фильма',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          )
        : GridView.builder(
            addRepaintBoundaries: false,
            cacheExtent: 1000,
            padding: const EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              top: 16.0,
              bottom: 40.0,
            ),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 130, // Уменьшенный размер для TV
              childAspectRatio: 0.67,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: _results.length,
            itemBuilder: (context, index) {
              return MovieCard(
                key: ValueKey(_results[index].id),
                movie: _results[index],
              );
            },
          );

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: isTvLayout
          ? null
          : AppBar(
              title: const Text('Поиск'),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
      body: isTvLayout
          ? Row(
              children: [
                _buildTvKeyboard(),
                Expanded(child: resultsGrid),
              ],
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          _speechToText.isListening
                              ? Icons.mic
                              : Icons.mic_none,
                          color: _speechToText.isListening
                              ? Colors.red
                              : Colors.grey,
                        ),
                        onPressed: _speechToText.isNotListening
                            ? _startListening
                            : _speechToText.stop,
                        iconSize: 32,
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          Icons.filter_alt,
                          color: _onlyWithTorrents ? Colors.red : Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _onlyWithTorrents = !_onlyWithTorrents;
                          });
                          if (_searchController.text.trim().length >= 3) {
                            _performSearch(_searchController.text.trim());
                          }
                        },
                        tooltip: 'Только с торрентами',
                        iconSize: 32,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          textInputAction: TextInputAction.search,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText:
                                'Введите название фильма (мин. 3 символа)',
                            hintStyle: TextStyle(color: Colors.grey),
                            prefixIcon: Icon(Icons.search, color: Colors.grey),
                            filled: true,
                            fillColor: Colors.black54,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(8.0),
                              ),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (val) => _onSearchChanged(),
                          onSubmitted: (query) {
                            _searchFocusNode
                                .unfocus(); // Снимаем фокус после ввода
                            if (query.trim().length >= 3) {
                              _performSearch(query.trim());
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: resultsGrid),
                Container(
                  height: 4,
                  color: const Color(0xFF141414), // Цвет фона для обрезки
                ),
              ],
            ),
    );
  }
}

class _TvKey extends StatefulWidget {
  final String? text;
  final IconData? icon;
  final Color? activeColor;
  final VoidCallback onTap;
  const _TvKey({
    super.key,
    this.text,
    this.icon,
    this.activeColor,
    required this.onTap,
  });
  @override
  State<_TvKey> createState() => _TvKeyState();
}

class _TvKeyState extends State<_TvKey> {
  bool _isFocused = false;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onFocusChange: (val) => setState(() => _isFocused = val),
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _isFocused ? Colors.white : Colors.white12,
          borderRadius: BorderRadius.circular(4),
        ),
        child: widget.icon != null
            ? Icon(
                widget.icon,
                size: 16,
                color: _isFocused
                    ? Colors.black
                    : (widget.activeColor ?? Colors.white),
              )
            : Text(
                widget.text ?? '',
                style: TextStyle(
                  color: _isFocused ? Colors.black : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
