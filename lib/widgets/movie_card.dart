import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../screens/movie_details_screen.dart';

class MovieCard extends StatefulWidget {
  final Movie movie;

  const MovieCard({super.key, required this.movie});

  @override
  State<MovieCard> createState() => _MovieCardState();
}

class _MovieCardState extends State<MovieCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      // Локальный Material обязателен. InkWell рисует свои ink-эффекты не у
      // себя, а в ближайшем Material — без этой обёртки им оказывался Material
      // самого Scaffold. InkWell создаёт InkHighlight даже когда все цвета
      // прозрачные (см. InkResponse.updateHighlight), а тот анимирует альфу
      // ~200 мс и на каждом кадре дёргает markNeedsPaint() на Material.
      // То есть каждое перемещение фокуса по сетке инвалидировало слой на весь
      // экран — выше RepaintBoundary карточек, так что они не помогали.
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          onFocusChange: (hasFocus) {
            setState(() => _isFocused = hasFocus);
          },
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MovieDetailsScreen(movie: widget.movie),
              ),
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: const Color(0xFF222222),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _isFocused ? Colors.white : Colors.transparent,
                width: 3,
              ),
              // Тень с blurRadius убрана намеренно: размытие требует saveLayer и
              // пересчитывается на каждом кадре 200-мс анимации фокуса, что на
              // GPU ТВ-приставки заметно дороже самой карточки. Белой рамки в
              // 3 px на экране телевизора достаточно. Вернуть — добавить сюда
              // boxShadow обратно.
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child: _MoviePoster(movie: widget.movie)),
                      if (widget.movie.rating > 0)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black87.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  widget.movie.rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 8.0,
                  ),
                  child: SizedBox(
                    height: 20,
                    // Вес шрифта постоянный: TextStyle.compareTo относит его
                    // смену к RenderComparison.layout, поэтому подсветка
                    // фокуса вызывала повторную раскладку текста на каждой
                    // карточке, по которой пробегает фокус. Цвет — paint-only.
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        color: _isFocused ? Colors.white : Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      child: Text(widget.movie.title),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Isolated widget so focus/border changes don't cause image repaints.
class _MoviePoster extends StatelessWidget {
  final Movie movie;

  const _MoviePoster({required this.movie});

  @override
  Widget build(BuildContext context) {
    final String fullImageUrl =
        movie.posterUrl.isNotEmpty && movie.posterUrl.startsWith('/')
        ? 'https://image.tmdb.org/t/p/w500${movie.posterUrl}'
        : movie.posterUrl;

    final double dpr = MediaQuery.devicePixelRatioOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Постер приходит в 500x750 и без memCacheWidth занимает в памяти
        // ~1.5 МБ. При лимите ImageCache в 100 МБ кэш переполняется уже на
        // ~66 карточках (страница грузит 100), после чего постеры вытесняются
        // и декодируются заново — на ТВ это видно как повторное появление
        // заглушки при скролле. Декодируем ровно под размер ячейки.
        final int? cacheWidth = constraints.hasBoundedWidth
            ? (constraints.maxWidth * dpr).round()
            : null;

        return CachedNetworkImage(
          imageUrl: fullImageUrl,
          memCacheWidth: cacheWidth,
          maxWidthDiskCache: cacheWidth,
          // Кроссфейд на 500 мс при быстрой прокрутке пультом читается как
          // моргание — показываем картинку сразу.
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          placeholderFadeInDuration: Duration.zero,
          imageBuilder: (context, imageProvider) => Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(5),
              ),
              image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
            ),
          ),
          // Статичная заглушка вместо CircularProgressIndicator: спиннер тикает
          // каждый кадр, а на экране их одновременно десятки.
          placeholder: (context, url) => const _PosterStub(),
          errorWidget: (context, url, error) =>
              const _PosterStub(icon: Icons.image_not_supported_outlined),
        );
      },
    );
  }
}

class _PosterStub extends StatelessWidget {
  final IconData icon;

  const _PosterStub({this.icon = Icons.movie_outlined});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFF2A2A2A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
      ),
      child: Center(child: Icon(icon, color: Colors.white24, size: 32)),
    );
  }
}
