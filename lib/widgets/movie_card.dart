import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../screens/movie_details_screen.dart';
import 'package:marquee/marquee.dart';

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
    final String fullImageUrl =
        widget.movie.posterUrl.isNotEmpty &&
            widget.movie.posterUrl.startsWith('/')
        ? 'https://image.tmdb.org/t/p/w500\${widget.movie.posterUrl}'
        : widget.movie.posterUrl;

    return RepaintBoundary(
      child: InkWell(
        focusColor: Colors.transparent,
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        onFocusChange: (hasFocus) {
          setState(() {
            _isFocused = hasFocus;
          });
        },
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MovieDetailsScreen(movie: widget.movie),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF222222), // Слегка светлее фона приложения
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isFocused ? Colors.white : Colors.transparent,
              width: 3,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CachedNetworkImage(
                        imageUrl: fullImageUrl,
                        imageBuilder: (context, imageProvider) => Container(
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(5),
                            ),
                            image: DecorationImage(
                              image: imageProvider,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        placeholder: (context, url) => Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(5),
                            ),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(5),
                            ),
                          ),
                          child: const Icon(
                            Icons.error,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
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
                            color: Colors.black87.withOpacity(0.8),
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
                  child: Text(
                    widget.movie.title,
                    style: TextStyle(
                      color: _isFocused ? Colors.white : Colors.white70,
                      fontSize: 13,
                      fontWeight: _isFocused
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
