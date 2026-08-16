import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../models/torrent.dart';
import '../services/db_service.dart';
import 'package:provider/provider.dart';
import '../providers/favorites_provider.dart';
import 'package:android_intent_plus/android_intent.dart';

class MovieDetailsScreen extends StatefulWidget {
  final Movie movie;

  const MovieDetailsScreen({super.key, required this.movie});

  @override
  State<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      // Only fire on settled tab (not during animation)
      if (!_tabController.indexIsChanging && mounted) {
        setState(() => _activeIndex = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.movie.title),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Consumer<FavoritesProvider>(
              builder: (context, provider, child) {
                final isFav = provider.isFavorite(widget.movie.id);
                return IconButton(
                  icon: Icon(
                    isFav ? Icons.favorite : Icons.favorite_border,
                    color: isFav ? Colors.red : Colors.grey,
                    size: 28,
                  ),
                  onPressed: () => provider.toggleFavorite(widget.movie.id),
                );
              },
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Информация'),
            Tab(text: 'Торренты'),
          ],
        ),
      ),
      // IndexedStack keeps all children in the tree but only paints the active
      // one — no concurrent compositing, no slide animation, no flicker.
      body: IndexedStack(
        index: _activeIndex,
        children: [
          _InfoTab(movie: widget.movie),
          _TorrentsTab(movieId: widget.movie.id),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Information tab — kept alive so that switching tabs doesn't rebuild it
// ─────────────────────────────────────────────────────────────────────────────
class _InfoTab extends StatefulWidget {
  final Movie movie;

  const _InfoTab({required this.movie});

  @override
  State<_InfoTab> createState() => _InfoTabState();
}

class _InfoTabState extends State<_InfoTab> with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  /// Шаг прокрутки на одно нажатие. Прежние 50 px на экране телевизора — это
  /// десятки нажатий на страницу описания.
  static const double _step = 120.0;

  /// Прокрутка мгновенная, без animateTo. При удержании кнопки пульт шлёт
  /// повтор каждые ~30–50 мс, и каждая 100-мс анимация отменяла предыдущую —
  /// получался каскад незавершённых ScrollActivity и рваное движение.
  /// Возвращает false, если прокручивать некуда: тогда событие отдаётся
  /// системе и фокус уходит traversal'ом (вверх — на вкладки).
  bool _scrollBy(double delta) {
    if (!_scrollController.hasClients) return false;
    final position = _scrollController.position;
    final double target = (position.pixels + delta).clamp(
      0.0,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() < 0.5) return false;
    position.jumpTo(target);
    return true;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin

    final movie = widget.movie;
    final String fullImageUrl =
        movie.posterUrl.isNotEmpty && movie.posterUrl.startsWith('/')
        ? 'https://image.tmdb.org/t/p/w500${movie.posterUrl}'
        : movie.posterUrl;

    return Focus(
      // Без autofocus фокус после Navigator.push остаётся на scope, и первое
      // нажатие пульта уходит впустую на поиск цели — на ТВ это читается как
      // «экран не отвечает».
      autofocus: true,
      onKeyEvent: (node, event) {
        // KeyRepeatEvent обязателен. Раньше обрабатывался только KeyDownEvent,
        // а удержание кнопки на пульте генерирует именно repeat — то есть
        // страница не прокручивалась удержанием, приходилось жать многократно.
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }

        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          return _scrollBy(_step)
              ? KeyEventResult.handled
              : KeyEventResult.ignored;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          return _scrollBy(-_step)
              ? KeyEventResult.handled
              : KeyEventResult.ignored;
        }
        return KeyEventResult.ignored;
      },
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(24.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster — isolated in RepaintBoundary so tab animations don't
            // repaint the heavy image layer.
            RepaintBoundary(
              child: SizedBox(
                width: 300,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _MoviePoster(imageUrl: fullImageUrl),
                ),
              ),
            ),
            const SizedBox(width: 32),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie.title,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    movie.originalTitle,
                    style: const TextStyle(
                      fontSize: 20,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        movie.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 32),
                      const Icon(
                        Icons.calendar_today,
                        color: Colors.grey,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        movie.releaseDate.length >= 4
                            ? movie.releaseDate.substring(0, 4)
                            : movie.releaseDate,
                        style: const TextStyle(
                          fontSize: 20,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (movie.countries.isNotEmpty)
                    _MetaRow(label: 'Страна:', value: movie.countries),
                  if (movie.genres.isNotEmpty)
                    _MetaRow(label: 'Жанр:', value: movie.genres),
                  if (movie.directors.isNotEmpty)
                    _MetaRow(label: 'Режиссер:', value: movie.directors),
                  if (movie.actors.isNotEmpty)
                    _MetaRow(label: 'В ролях:', value: movie.actors),
                  const SizedBox(height: 24),
                  const Text(
                    'Описание',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    movie.overview,
                    style: const TextStyle(fontSize: 18, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Torrents tab — kept alive so switching tabs doesn't re-fetch data
// ─────────────────────────────────────────────────────────────────────────────
class _TorrentsTab extends StatefulWidget {
  final int movieId;

  const _TorrentsTab({required this.movieId});

  @override
  State<_TorrentsTab> createState() => _TorrentsTabState();
}

class _TorrentsTabState extends State<_TorrentsTab>
    with AutomaticKeepAliveClientMixin {
  late Future<List<Torrent>> _torrentsFuture;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _torrentsFuture = DbService.instance.getTorrentsForMovie(widget.movieId);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin

    return FutureBuilder<List<Torrent>>(
      future: _torrentsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text('Торренты не найдены', style: TextStyle(fontSize: 24)),
          );
        }

        final torrents = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(24.0),
          itemCount: torrents.length,
          itemBuilder: (context, index) {
            return TorrentCard(
              key: ValueKey(torrents[index].id),
              torrent: torrents[index],
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Poster image — extracted so CachedNetworkImage is never recreated by a
// parent rebuild; the widget identity is stable across builds.
// ─────────────────────────────────────────────────────────────────────────────
class _MoviePoster extends StatelessWidget {
  final String imageUrl;

  const _MoviePoster({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    // Постер показывается в колонке шириной 300 lp, а приходит 500x750.
    // Единственная картинка погоды не делает, но при переходах по фильмам
    // такие буферы копятся в ImageCache и вытесняют постеры сетки, которую
    // пользователь увидит сразу после «Назад».
    final int cacheWidth = (300 * MediaQuery.devicePixelRatioOf(context))
        .round();

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      memCacheWidth: cacheWidth,
      maxWidthDiskCache: cacheWidth,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: (context, url) => Container(
        color: Colors.grey[800],
        height: 450,
        child: const Center(child: CircularProgressIndicator()),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey[900],
        height: 450,
        child: const Icon(Icons.error, color: Colors.white, size: 50),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable meta-data row (label + value). Extracted from _buildMetaText()
// helper so Flutter can short-circuit equality checks on unchanged rows.
// ─────────────────────────────────────────────────────────────────────────────
class _MetaRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Torrent card
// ─────────────────────────────────────────────────────────────────────────────
class TorrentCard extends StatefulWidget {
  final Torrent torrent;

  const TorrentCard({super.key, required this.torrent});

  @override
  State<TorrentCard> createState() => _TorrentCardState();
}

class _ChipData {
  final IconData icon;
  final String text;

  const _ChipData(this.icon, this.text);
}

class _TorrentCardState extends State<TorrentCard> {
  bool _isFocused = false;

  late final String _title;
  late final List<_ChipData> _chips;

  static final RegExp _newlines = RegExp(r'\r|\n');

  /// Поля торрента приходят из внешней БД и в `translation` регулярно попадает
  /// не короткая метка, а кусок описания раздачи — на это намекают сами
  /// фильтры ниже. Раньше вся эта чистка (replaceAll + toLowerCase + contains)
  /// выполнялась внутри build, то есть на каждое перемещение фокуса по списку
  /// пережёвывались килобайты текста × 4 поля. Теперь — один раз за карточку.
  static String? _prepareChipText(String text) {
    if (text.isEmpty) return null;

    final String clean = text.replaceAll(_newlines, ' ').trim();
    if (clean.isEmpty) return null;

    final String lower = clean.toLowerCase();
    if (lower.contains('скриншот') ||
        lower.startsWith('информация') ||
        lower.contains('релиз от')) {
      return null;
    }
    return _truncate(clean, 80);
  }

  /// TextPainter раскладывает строку целиком и только потом обрезает по
  /// ellipsis, поэтому километровое значение стоит дорого даже в одну строку.
  static String _truncate(String value, int max) =>
      value.length <= max ? value : '${value.substring(0, max)}…';

  @override
  void initState() {
    super.initState();
    final torrent = widget.torrent;

    _title = _truncate(
      torrent.topicTitle.isNotEmpty ? torrent.topicTitle : 'Без названия',
      200,
    );

    final String sizeText = torrent.sizeGb > 0
        ? '${torrent.sizeGb.toStringAsFixed(2)} ГБ'
        : 'Размер неизвестен';

    final chips = <_ChipData>[];
    void add(IconData icon, String raw) {
      final String? text = _prepareChipText(raw);
      if (text != null) chips.add(_ChipData(icon, text));
    }

    add(Icons.sd_storage_outlined, sizeText);
    add(Icons.hd_outlined, torrent.quality);
    add(Icons.video_file_outlined, torrent.fileFormat);
    add(Icons.language_outlined, torrent.translation);
    _chips = chips;
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      // См. комментарий в MovieCard: без локального Material ink-эффекты
      // InkWell инвалидируют слой Material'а Scaffold целиком.
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          onFocusChange: (hasFocus) => setState(() => _isFocused = hasFocus),
          onTap: () async {
            if (widget.torrent.magnetLink.isEmpty) return;

            // Messenger берём до await: после него context может быть уже не в
            // дереве, а ScaffoldMessenger.of по нему искать нечего.
            final messenger = ScaffoldMessenger.of(context);
            try {
              final intent = AndroidIntent(
                action: 'action_view',
                data: widget.torrent.magnetLink,
              );
              // launchChooser, а не launch: он оборачивает интент в
              // Intent.createChooser, который показывает список обработчиков
              // даже когда одно из приложений уже назначено по умолчанию.
              // С launch() система молча отдавала ссылку дефолтному плееру.
              await intent.launchChooser('Открыть торрент через');
            } catch (e) {
              debugPrint('Ошибка при открытии торрент-ссылки: $e');
              messenger.showSnackBar(
                const SnackBar(
                  content: Text(
                    'Нет приложения, способного открыть торрент-ссылку',
                  ),
                ),
              );
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isFocused ? Colors.white : Colors.transparent,
                width: 2,
              ),
              // Тени убраны. Здесь они были хуже, чем в MovieCard: размытие
              // рисовалось не только в фокусе, а у КАЖДОЙ карточки постоянно
              // (blurRadius 4 в обычном состоянии, 10 в фокусе). Каждое такое
              // размытие — saveLayer, и на списке из полутора десятков
              // торрентов это постоянная нагрузка на GPU приставки.
              // Карточка (0xFF2A2A2A) и так контрастна фону (0xFF141414).
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // fontWeight намеренно постоянный. TextStyle.compareTo
                      // относит смену веса к RenderComparison.layout, то есть
                      // подсветка фокуса заставляла заново раскладывать текст
                      // (а с ним Column → Wrap → Row всей карточки). Меняется
                      // только цвет — это RenderComparison.paint, без layout.
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _isFocused ? Colors.white : Colors.grey[200],
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        child: Text(_title),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [for (final chip in _chips) _buildChip(chip)],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 60,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Icon(
                            Icons.arrow_upward,
                            color: Colors.greenAccent,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.torrent.seeds}',
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Icon(
                            Icons.arrow_downward,
                            color: Colors.redAccent,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.torrent.leeches}',
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChip(_ChipData chip) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(chip.icon, size: 14, color: Colors.grey[400]),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              chip.text,
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
