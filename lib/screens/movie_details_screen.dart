import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../models/torrent.dart';
import '../services/db_service.dart';
import 'package:provider/provider.dart';
import '../providers/favorites_provider.dart';

class MovieDetailsScreen extends StatefulWidget {
  final Movie movie;

  const MovieDetailsScreen({super.key, required this.movie});

  @override
  State<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen> {
  late Future<List<Torrent>> _torrentsFuture;

  @override
  void initState() {
    super.initState();
    _torrentsFuture = DbService.instance.getTorrentsForMovie(widget.movie.id);
  }

  @override
  Widget build(BuildContext context) {
    final String fullImageUrl =
        widget.movie.posterUrl.isNotEmpty &&
            widget.movie.posterUrl.startsWith('/')
        ? 'https://image.tmdb.org/t/p/w500\${widget.movie.posterUrl}'
        : widget.movie.posterUrl;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.movie.title),
          backgroundColor: Colors.transparent,
          elevation: 0,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Информация'),
              Tab(text: 'Торренты'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Вкладка Информация
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 300,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: fullImageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[800],
                          height: 450,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[900],
                          height: 450,
                          child: const Icon(
                            Icons.error,
                            color: Colors.white,
                            size: 50,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.movie.title,
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.movie.originalTitle,
                            style: const TextStyle(
                              fontSize: 20,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 28,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.movie.rating.toStringAsFixed(1),
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
                                widget.movie.releaseDate.length >= 4
                                    ? widget.movie.releaseDate.substring(0, 4)
                                    : widget.movie.releaseDate,
                                style: const TextStyle(
                                  fontSize: 20,
                                  color: Colors.grey,
                                ),
                              ),
                              const Spacer(),
                              Consumer<FavoritesProvider>(
                                builder: (context, provider, child) {
                                  final isFav = provider.isFavorite(
                                    widget.movie.id,
                                  );
                                  return IconButton(
                                    icon: Icon(
                                      isFav
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: isFav ? Colors.red : Colors.grey,
                                      size: 32,
                                    ),
                                    onPressed: () {
                                      provider.toggleFavorite(widget.movie.id);
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          if (widget.movie.countries.isNotEmpty)
                            _buildMetaText('Страна:', widget.movie.countries),
                          if (widget.movie.genres.isNotEmpty)
                            _buildMetaText('Жанр:', widget.movie.genres),
                          if (widget.movie.directors.isNotEmpty)
                            _buildMetaText('Режиссер:', widget.movie.directors),
                          if (widget.movie.actors.isNotEmpty)
                            _buildMetaText('В ролях:', widget.movie.actors),
                          const SizedBox(height: 24),
                          const Text(
                            'Описание',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Focus позволяет пульту зацепиться за текст и прокрутить SingleChildScrollView вниз
                          Focus(
                            child: Builder(
                              builder: (context) {
                                final isFocused = Focus.of(context).hasFocus;
                                return Container(
                                  padding: isFocused
                                      ? const EdgeInsets.all(8)
                                      : EdgeInsets.zero,
                                  decoration: BoxDecoration(
                                    color: isFocused
                                        ? Colors.grey[800]
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    widget.movie.overview,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      height: 1.5,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Вкладка Торренты
            FutureBuilder<List<Torrent>>(
              future: _torrentsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: \${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      'Торренты не найдены',
                      style: TextStyle(fontSize: 24),
                    ),
                  );
                }

                final torrents = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.all(24.0),
                  itemCount: torrents.length,
                  itemBuilder: (context, index) {
                    return TorrentCard(torrent: torrents[index]);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaText(String label, String value) {
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

class TorrentCard extends StatefulWidget {
  final Torrent torrent;

  const TorrentCard({super.key, required this.torrent});

  @override
  State<TorrentCard> createState() => _TorrentCardState();
}

class _TorrentCardState extends State<TorrentCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final sizeText = widget.torrent.sizeGb > 0
        ? '${widget.torrent.sizeGb.toStringAsFixed(2)} ГБ'
        : 'Размер неизвестен';

    return InkWell(
      onFocusChange: (hasFocus) => setState(() => _isFocused = hasFocus),
      onTap: () {
        // TODO: Open magnet link
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isFocused ? Colors.grey[800] : Colors.grey[900],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _isFocused ? Colors.white : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.torrent.topicTitle.isNotEmpty
                        ? widget.torrent.topicTitle
                        : 'Без названия',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _isFocused ? Colors.white : Colors.grey[300],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildChip(Icons.sd_storage, sizeText),
                      _buildChip(Icons.hd, widget.torrent.quality),
                      _buildChip(Icons.video_file, widget.torrent.fileFormat),
                      _buildChip(Icons.language, widget.torrent.translation),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Правая часть (1/5 ширины) - Text.rich исключает RenderFlex ошибки
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        const WidgetSpan(
                          child: Icon(
                            Icons.arrow_upward,
                            color: Colors.green,
                            size: 18,
                          ),
                          alignment: PlaceholderAlignment.middle,
                        ),
                        TextSpan(
                          text: ' ${widget.torrent.seeds}',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Text.rich(
                    TextSpan(
                      children: [
                        const WidgetSpan(
                          child: Icon(
                            Icons.arrow_downward,
                            color: Colors.red,
                            size: 18,
                          ),
                          alignment: PlaceholderAlignment.middle,
                        ),
                        TextSpan(
                          text: ' ${widget.torrent.leeches}',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(IconData icon, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    String clean = text.replaceAll(RegExp(r'\r|\n'), ' ').trim();
    final lower = clean.toLowerCase();
    if (lower.contains('скриншот') ||
        lower.startsWith('информация') ||
        lower.contains('релиз от'))
      return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[400]),
          const SizedBox(width: 6),
          Flexible(
            // ВАЖНО: Flexible не даст чипу разорвать экран
            child: Text(
              clean,
              style: TextStyle(color: Colors.grey[300], fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
