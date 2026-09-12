import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/media.dart';
import '../models/playlist.dart';
import '../models/user.dart';
import '../services/murrtube_api.dart';
import '../utils/page_transitions.dart';
import '../widgets/video_card.dart';
import 'video_detail_page.dart';
import 'profile_page.dart';

class PlaylistPage extends StatefulWidget {
  final String userSlug;
  final String playlistSlug;

  const PlaylistPage({
    super.key,
    required this.userSlug,
    required this.playlistSlug,
  });

  @override
  State<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  Playlist? _playlist;
  List<Media> _media = [];
  User? _user;
  bool _loading = true;
  bool _hasMore = true;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await MurrtubeApi.getPlaylist(
        widget.userSlug,
        widget.playlistSlug,
      );
      setState(() {
        _playlist = result.playlist;
        _media = result.media;
        _user = result.user;
        _hasMore = result.pagination.next != null;
        _currentPage = result.pagination.page;
        _loading = false;
      });
    } catch (e) {
      debugPrint('PlaylistPage load error: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loading) return;
    try {
      final nextPage = _currentPage + 1;
      final result = await MurrtubeApi.getPlaylist(
        widget.userSlug,
        widget.playlistSlug,
        page: nextPage,
      );
      setState(() {
        _media.addAll(result.media);
        _hasMore = result.pagination.next != null;
        _currentPage = result.pagination.page;
      });
    } catch (e) {
      debugPrint('PlaylistPage loadMore error: $e');
    }
  }

  int _crossAxisCount(double width) {
    if (width >= 1600) return 5;
    if (width >= 1200) return 4;
    if (width >= 900) return 4;
    if (width >= 600) return 3;
    return 2;
  }

  double _cardAspectRatio(double width) {
    if (width < 600) return 10 / 13;
    if (width < 900) return 10 / 12;
    return 10 / 11;
  }

  String _formatCount(int? n) {
    if (n == null) return '0';
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mutedColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    if (_loading && _playlist == null) {
      return Scaffold(
        body: Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colorScheme.primary,
            ),
          ),
        ),
      );
    }

    final playlist = _playlist;
    if (playlist == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.playlist_remove, size: 48, color: mutedColor),
              const SizedBox(height: 12),
              Text(
                'Playlist not found',
                style: TextStyle(color: mutedColor, fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.arrow_back_ios_new,
                              size: 16,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.playlist_play,
                            size: 40,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                playlist.name,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${playlist.visibility} · ${_formatCount(playlist.itemsCount)} items',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: mutedColor,
                                ),
                              ),
                              if (playlist.description != null && playlist.description!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  playlist.description!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: mutedColor,
                                    height: 1.4,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_user != null) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: GestureDetector(
                        onTap: () {
                          pushPage(
                            context,
                            builder: (_) => ProfilePage(slug: _user!.slug),
                          );
                        },
                        child: Row(
                          children: [
                            ClipOval(
                              child: _user!.avatarUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: _user!.avatarUrl!,
                                      width: 32,
                                      height: 32,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => Container(
                                        width: 32,
                                        height: 32,
                                        color: colorScheme.surfaceContainerHighest,
                                        child: Icon(Icons.person,
                                            size: 16, color: mutedColor),
                                      ),
                                    )
                                  : Container(
                                      width: 32,
                                      height: 32,
                                      color: colorScheme.surfaceContainerHighest,
                                      child: Icon(Icons.person, size: 16, color: mutedColor),
                                    ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _user!.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          if (_media.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam_off, size: 48, color: mutedColor),
                    const SizedBox(height: 12),
                    Text(
                      'No videos in this playlist',
                      style: TextStyle(color: mutedColor, fontSize: 15),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) {
                  final cols = _crossAxisCount(constraints.crossAxisExtent);
                  return SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      childAspectRatio: _cardAspectRatio(constraints.crossAxisExtent),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index >= _media.length) {
                          if (_hasMore) {
                            _loadMore();
                          }
                          return Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.primary,
                              ),
                            ),
                          );
                        }
                        final media = _media[index];
                        return VideoCard(
                          media: media,
                          heroTag: 'video-thumb-${media.shortCode}',
                          onTap: () {
                            pushPage(
                              context,
                              builder: (_) => VideoDetailPage(
                                shortCode: media.shortCode,
                                heroTag: 'video-thumb-${media.shortCode}',
                              ),
                            );
                          },
                        );
                      },
                      childCount: _media.length + (_hasMore ? 1 : 0),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
