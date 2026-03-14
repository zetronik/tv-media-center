import 'package:flutter/material.dart';
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
        ? 'https://image.tmdb.org/t/p/w500${widget.movie.posterUrl}'
        : widget.movie.posterUrl;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
            SingleChildScrollView(
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
                            ],
                          ),
                          const SizedBox(height: 24),
                          if (widget.movie.countries.isNotEmpty)
                            _buildMetaText('Страна:', widget.movie.countries),
                          if (widget.movie.genres.isNotEmpty)
                            _buildMetaText('Жанр:', widget.movie.genres),
                          if (widget.movie.directors.isNotEmpty)
                            _buildMetaText(
                              'Режиссер:',
                              widget.movie.directors,
                            ),
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
                          Text(
                            widget.movie.overview,
                            style: const TextStyle(
                              fontSize: 18,
                              height: 1.5,
                            ),
                          ),
                        ],
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
                  return Center(child: Text('Error: ${snapshot.error}'));
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

    return RepaintBoundary(
      child: AnimatedScale(
        scale: _isFocused ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: InkWell(
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          onFocusChange: (hasFocus) => setState(() => _isFocused = hasFocus),
          onTap: () async {
            if (widget.torrent.magnetLink.isEmpty) return;
            try {
              final intent = AndroidIntent(
                action: 'action_view',
                data: widget.torrent.magnetLink,
              );
              await intent.launch();
            } catch (e) {
              debugPrint('Ошибка при запуске плеера: $e');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Не удалось запустить Ace Stream'),
                  ),
                );
              }
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
              boxShadow: _isFocused
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: _isFocused
                              ? FontWeight.bold
                              : FontWeight.w600,
                          color: _isFocused ? Colors.white : Colors.grey[200],
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        child: Text(
                          widget.torrent.topicTitle.isNotEmpty
                              ? widget.torrent.topicTitle
                              : 'Без названия',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildChip(Icons.sd_storage_outlined, sizeText),
                          _buildChip(
                            Icons.hd_outlined,
                            widget.torrent.quality,
                          ),
                          _buildChip(
                            Icons.video_file_outlined,
                            widget.torrent.fileFormat,
                          ),
                          _buildChip(
                            Icons.language_outlined,
                            widget.torrent.translation,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Правая часть (сиды/личи)
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

  Widget _buildChip(IconData icon, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    final String clean = text.replaceAll(RegExp(r'\r|\n'), ' ').trim();
    final lower = clean.toLowerCase();
    if (lower.contains('скриншот') ||
        lower.startsWith('информация') ||
        lower.contains('релиз от')) {
      return const SizedBox.shrink();
    }

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
          Icon(icon, size: 14, color: Colors.grey[400]),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              clean,
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
