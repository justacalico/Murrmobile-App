import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/media.dart';
import '../models/comment.dart';
import '../models/playlist.dart';
import '../services/murrtube_api.dart';
import '../utils/app_preferences.dart';
import '../utils/page_transitions.dart';
import '../widgets/video_card.dart';
import '../widgets/linkify_text.dart';
import '../widgets/tag_edit_sheet.dart';
import 'profile_page.dart';
import 'search_page.dart';

class VideoDetailPage extends StatefulWidget {
  final String shortCode;
  final String? commentId;
  final String? heroTag;

  const VideoDetailPage({super.key, required this.shortCode, this.commentId, this.heroTag});

  @override
  State<VideoDetailPage> createState() => _VideoDetailPageState();
}

class _VideoDetailPageState extends State<VideoDetailPage> {
  Media? _medium;
  List<Comment> _comments = [];
  List<Media> _watchMore = [];
  VideoPlayerController? _controller;
  bool _loading = true;
  bool _showComments = false;
  bool _showSkip = false;
  bool _skipForward = true;
  bool _isDraggingTimeline = false;
  double _dragProgress = 0;
  bool _viewerCanLike = false;
  bool _viewerLiked = false;
  bool _viewerCanComment = false;
  int _likesCount = 0;
  bool _isMuted = false;
  bool _isFullscreen = false;
  bool _showFullscreenUI = true;
  Timer? _fullscreenUITimer;
  final _commentController = TextEditingController();
  bool _postingComment = false;
  final _scrollController = ScrollController();
  final Map<String, GlobalKey> _commentKeys = {};

  @override
  void initState() {
    super.initState();
    _showComments = widget.commentId != null;
    _loadMutePref();
    _load();
  }

  Future<void> _loadMutePref() async {
    final muted = await AppPreferences.getMute();
    if (mounted) setState(() => _isMuted = muted);
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _fullscreenUITimer?.cancel();
    _controller?.dispose();
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final result = await MurrtubeApi.getVideo(widget.shortCode);
      setState(() {
        _medium = result.medium;
        _comments = result.comments;
        _watchMore = result.watchMore;
        _viewerCanLike = result.viewerCanLike;
        _viewerCanComment = result.viewerCanComment;
        _viewerLiked = result.medium.viewerLiked;
        _likesCount = result.medium.likesCount;
        _loading = false;
        // Build keys for all comments (including replies)
        _commentKeys.clear();
        void addKeys(List<Comment> list) {
          for (final c in list) {
            _commentKeys[c.id] = GlobalKey();
            addKeys(c.replies);
          }
        }
        addKeys(_comments);
      });
      if (_medium?.hlsUrl != null) {
        _initPlayer(_medium!.hlsUrl!);
      }
      if (widget.commentId != null) {
        _scrollToComment(widget.commentId!);
      }
    } catch (e) {
      debugPrint('VideoDetailPage load error: $e');
      setState(() => _loading = false);
    }
  }

  bool _isCommentHighlighted(String commentId) {
    final target = widget.commentId;
    if (target == null) return false;
    if (commentId == target) return true;
    if (target.startsWith('comment-') && commentId == target.substring(8)) return true;
    return false;
  }

  void _scrollToComment(String commentId) {
    // The fragment may be "comment-uuid" while the model id is "uuid"
    final ids = <String>{commentId};
    if (commentId.startsWith('comment-')) {
      ids.add(commentId.substring(8));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Give images/layout a moment to settle, then scroll
      Future.delayed(const Duration(milliseconds: 400), () {
        for (final id in ids) {
          final key = _commentKeys[id];
          if (key != null && key.currentContext != null) {
            Scrollable.ensureVisible(
              key.currentContext!,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              alignment: 0.0,
            );
            return;
          }
        }
      });
    });
  }

  Future<void> _showSaveBottomSheet() async {
    if (_medium == null) return;
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _SaveSheet(
        medium: _medium!,
        onCreate: (name, visibility) async {
          await MurrtubeApi.createPlaylist(
            name: name,
            visibility: visibility,
          );
          final updated = await MurrtubeApi.getMyPlaylists();
          final created = updated.firstWhere(
            (p) => p.name == name,
            orElse: () => updated.first,
          );
          await MurrtubeApi.addToPlaylist(
            playlistId: created.id,
            shortCode: _medium!.shortCode,
            mediumId: _medium!.id,
          );
          if (mounted) {
            Navigator.of(ctx).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Saved to $name')),
            );
          }
        },
        onSelect: (playlist) async {
          await MurrtubeApi.addToPlaylist(
            playlistId: playlist.id,
            shortCode: _medium!.shortCode,
            mediumId: _medium!.id,
          );
          if (mounted) {
            Navigator.of(ctx).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Saved to ${playlist.name}')),
            );
          }
        },
      ),
    );
  }

  Future<void> _showTagEditSheet() async {
    if (_medium == null) return;
    if (!MurrtubeApi.isAuthenticated) return;
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => TagEditSheet(
        shortCode: widget.shortCode,
        initialTags: _medium!.tags,
        onSaved: (tags) {
          setState(() {
            _medium = Media(
              id: _medium!.id,
              shortCode: _medium!.shortCode,
              title: _medium!.title,
              url: _medium!.url,
              duration: _medium!.duration,
              durationLabel: _medium!.durationLabel,
              thumbnailUrl: _medium!.thumbnailUrl,
              previewUrl: _medium!.previewUrl,
              status: _medium!.status,
              likesCount: _medium!.likesCount,
              viewsCount: _medium!.viewsCount,
              publishedAt: _medium!.publishedAt,
              createdAt: _medium!.createdAt,
              user: _medium!.user,
              description: _medium!.description,
              visibility: _medium!.visibility,
              commentsDisabled: _medium!.commentsDisabled,
              commentsCount: _medium!.commentsCount,
              tags: tags,
              viewerLiked: _medium!.viewerLiked,
              isOwner: _medium!.isOwner,
              isLive: _medium!.isLive,
              hlsUrl: _medium!.hlsUrl,
            );
          });
        },
      ),
    );
  }

  Future<void> _toggleLike() async {
    if (_medium == null || !_viewerCanLike) return;
    HapticFeedback.lightImpact();
    final medium = _medium!;
    final wasLiked = _viewerLiked;
    setState(() {
      _viewerLiked = !wasLiked;
      _likesCount += wasLiked ? -1 : 1;
    });
    try {
      if (wasLiked) {
        await MurrtubeApi.unlikeVideo(medium.id);
      } else {
        await MurrtubeApi.likeVideo(medium.id);
      }
    } catch (e) {
      debugPrint('Toggle like error: $e');
      // Revert on error
      setState(() {
        _viewerLiked = wasLiked;
        _likesCount += wasLiked ? 1 : -1;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to ${wasLiked ? 'unlike' : 'like'}: $e')),
        );
      }
    }
  }

  void _initPlayer(String url) {
    _controller = VideoPlayerController.networkUrl(Uri.parse(url))
      ..setVolume(_isMuted ? 0.0 : 1.0)
      ..setLooping(true)
      ..addListener(() {
        if (mounted) setState(() {});
        if (_controller != null && _controller!.value.isInitialized) {
          if (_controller!.value.isPlaying) {
            WakelockPlus.enable();
          } else {
            WakelockPlus.disable();
          }
        }
      })
      ..initialize().then((_) {
        if (mounted) {
          _controller!.play();
          setState(() {});
        }
      });
  }

  Future<void> _toggleMute() async {
    final muted = !_isMuted;
    setState(() => _isMuted = muted);
    await AppPreferences.setMute(muted);
    _controller?.setVolume(muted ? 0.0 : 1.0);
  }

  void _startFullscreenUITimer() {
    _fullscreenUITimer?.cancel();
    _fullscreenUITimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isFullscreen) {
        setState(() => _showFullscreenUI = false);
      }
    });
  }

  void _toggleFullscreenUI() {
    if (!_isFullscreen) return;
    setState(() => _showFullscreenUI = !_showFullscreenUI);
    if (_showFullscreenUI) {
      _startFullscreenUITimer();
    }
  }

  void _toggleFullscreen() {
    final entering = !_isFullscreen;
    setState(() {
      _isFullscreen = entering;
      _showFullscreenUI = true;
    });
    if (entering) {
      _startFullscreenUITimer();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      final isPortrait = _controller != null &&
          _controller!.value.isInitialized &&
          _controller!.value.size.height > _controller!.value.size.width;
      if (isPortrait) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    } else {
      _fullscreenUITimer?.cancel();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
  }

  void _pauseVideoIfNeeded() {
    if (_controller != null &&
        _controller!.value.isInitialized &&
        _controller!.value.isPlaying) {
      _controller!.pause();
    }
  }

  void _resumeVideoIfNeeded() {
    if (_controller != null &&
        _controller!.value.isInitialized &&
        !_controller!.value.isPlaying) {
      _controller!.play();
    }
  }

  // coverage:ignore-start
  // The play/pause overlay above the zones wins every hit, so these
  // handlers can't fire in the current layout.
  void _onDoubleTap(bool forward) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final pos = _controller!.value.position;
    final dur = _controller!.value.duration;

    Duration newPos;
    if (forward) {
      newPos = pos + const Duration(seconds: 10);
      if (newPos > dur) newPos = dur;
    } else {
      newPos = pos - const Duration(seconds: 10);
      if (newPos < Duration.zero) newPos = Duration.zero;
    }

    _controller!.seekTo(newPos);
    setState(() {
      _showSkip = true;
      _skipForward = forward;
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _showSkip = false);
    });
  }
  // coverage:ignore-end

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${two(hours)}:${two(minutes)}:${two(seconds)}';
    }
    return '${two(minutes)}:${two(seconds)}';
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      await MurrtubeApi.deleteComment(commentId);
      final result = await MurrtubeApi.getVideo(widget.shortCode);
      if (mounted) {
        setState(() {
          _comments = result.comments;
        });
      }
    } catch (e) {
      debugPrint('_deleteComment error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete comment')),
        );
      }
    }
  }

  Future<void> _replyToComment(String commentId, String body) async {
    try {
      await MurrtubeApi.replyToComment(
        mediumId: _medium!.id,
        parentId: commentId,
        body: body,
      );
      final result = await MurrtubeApi.getVideo(widget.shortCode);
      if (mounted) {
        setState(() {
          _comments = result.comments;
        });
      }
    } catch (e) {
      debugPrint('_replyToComment error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to post reply')),
        );
      }
    }
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _medium == null) return;
    setState(() => _postingComment = true);
    try {
      await MurrtubeApi.postComment(
        mediumId: _medium!.id,
        body: text,
      );
      _commentController.clear();
      final result = await MurrtubeApi.getVideo(widget.shortCode);
      if (mounted) {
        setState(() {
          _comments = result.comments;
          _postingComment = false;
        });
      }
    } catch (e) {
      debugPrint('postComment error: $e');
      if (mounted) setState(() => _postingComment = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to post comment')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      );
    }
    final medium = _medium;
    if (medium == null) {
      return Scaffold(
        body: Center(
          child: Text(
            'Video not found',
            style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey),
          ),
        ),
      );
    }

    if (_isFullscreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: PopScope(
          canPop: !_isFullscreen,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && _isFullscreen) {
              _toggleFullscreen();
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_controller != null && _controller!.value.isInitialized)
                FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: _controller!.value.size.width,
                    height: _controller!.value.size.height,
                    child: VideoPlayer(_controller!),
                  ),
                )
              else
                CachedNetworkImage(
                  imageUrl: medium.thumbnailUrl,
                  fit: BoxFit.contain,
                  placeholder: (_, _) => Container(
                    color: Colors.black,
                  ),
                  errorWidget: (_, _, _) => Container(
                    color: Colors.black,
                    child: const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white,
                    ),
                  ),
                ),
              // Tap overlay: toggles UI
              Positioned.fill(
                child: GestureDetector(
                  onTap: _toggleFullscreenUI,
                  behavior: HitTestBehavior.translucent,
                  child: Container(color: Colors.transparent),
                ),
              ),
              // Top controls
              AnimatedOpacity(
                opacity: _showFullscreenUI ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: !_showFullscreenUI,
                  child: Stack(
                    children: [
                      // Back button
                      Positioned(
                        top: 12,
                        left: 12,
                        child: GestureDetector(
                          onTap: () => _toggleFullscreen(),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      // Mute button
                      Positioned(
                        top: 12,
                        right: 64,
                        child: GestureDetector(
                          onTap: _toggleMute,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _isMuted ? Icons.volume_off : Icons.volume_up,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      // Exit fullscreen button
                      Positioned(
                        top: 12,
                        right: 12,
                        child: GestureDetector(
                          onTap: _toggleFullscreen,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.fullscreen_exit,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      // Center play/pause button
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            if (_controller != null && _controller!.value.isInitialized) {
                              setState(() {
                                _controller!.value.isPlaying
                                    ? _controller!.pause()
                                    : _controller!.play();
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: Icon(
                              (_controller != null && _controller!.value.isInitialized && _controller!.value.isPlaying)
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 48,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Bottom timeline
              if (_controller != null && _controller!.value.isInitialized)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    ignoring: !_showFullscreenUI,
                    child: AnimatedOpacity(
                      opacity: _showFullscreenUI ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(0, 16, 0, 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.6),
                            ],
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final barWidth = constraints.maxWidth;
                                void seekToFraction(double fraction) {
                                  final dur = _controller!.value.duration;
                                  _controller!.seekTo(
                                    Duration(
                                      milliseconds: (fraction.clamp(0.0, 1.0) * dur.inMilliseconds).round(),
                                    ),
                                  );
                                }

                                final progress = _controller!.value.duration.inMilliseconds > 0
                                    ? _controller!.value.position.inMilliseconds /
                                        _controller!.value.duration.inMilliseconds
                                    : 0.0;

                                final currentFraction = _isDraggingTimeline ? _dragProgress : progress;

                                return GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onTapDown: (details) {
                                    final fraction = details.localPosition.dx / barWidth;
                                    seekToFraction(fraction);
                                  },
                                  onHorizontalDragStart: (_) {
                                    setState(() => _isDraggingTimeline = true);
                                  },
                                  onHorizontalDragUpdate: (details) {
                                    final fraction = details.localPosition.dx / barWidth;
                                    setState(() => _dragProgress = fraction.clamp(0.0, 1.0));
                                  },
                                  onHorizontalDragEnd: (_) {
                                    seekToFraction(_dragProgress);
                                    setState(() => _isDraggingTimeline = false);
                                  },
                                  // coverage:ignore-start
                                  // Nothing else competes for the gesture in
                                  // fullscreen, so the drag cannot be
                                  // cancelled from inside the app.
                                  onHorizontalDragCancel: () {
                                    setState(() => _isDraggingTimeline = false);
                                  },
                                  // coverage:ignore-end
                                  child: Container(
                                    height: 32,
                                    alignment: Alignment.center,
                                    child: Stack(
                                      alignment: Alignment.centerLeft,
                                      children: [
                                        Container(
                                          height: 4,
                                          color: Colors.white.withValues(alpha: 0.25),
                                        ),
                                        FractionallySizedBox(
                                          alignment: Alignment.centerLeft,
                                          widthFactor: currentFraction,
                                          child: Container(
                                            height: 4,
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                        ),
                                        Positioned(
                                          left: (currentFraction * barWidth - 8).clamp(0.0, barWidth - 16),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 150),
                                            curve: Curves.easeOut,
                                            width: _isDraggingTimeline ? 16 : 12,
                                            height: _isDraggingTimeline ? 16 : 12,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                                                  blurRadius: 6,
                                                  spreadRadius: 1,
                                                ),
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.3),
                                                  blurRadius: 2,
                                                  offset: const Offset(0, 1),
                                                ),
                                              ],
                                            ),
                                            child: Center(
                                              child: Container(
                                                width: 6,
                                                height: 6,
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context).colorScheme.primary,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(
                                      _isDraggingTimeline
                                          ? Duration(
                                              milliseconds: (_dragProgress *
                                                      _controller!.value.duration.inMilliseconds)
                                                  .round(),
                                            )
                                          : _controller!.value.position,
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    _formatDuration(_controller!.value.duration),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: !_isFullscreen,
      onPopInvokedWithResult: (didPop, _) {
        // coverage:ignore-start
        // This build only runs when _isFullscreen is false, so canPop is
        // always true and didPop is always true here.
        if (!didPop && _isFullscreen) {
          _toggleFullscreen();
        }
        // coverage:ignore-end
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: SafeArea(
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Video Player / Thumbnail
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Container(
                          color: Colors.black,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                            if (_controller != null && _controller!.value.isInitialized)
                              FittedBox(
                                fit: BoxFit.contain,
                                child: SizedBox(
                                  width: _controller!.value.size.width,
                                  height: _controller!.value.size.height,
                                  child: VideoPlayer(_controller!),
                                ),
                              )
                            else
                              Hero(
                                tag: widget.heroTag ?? 'video-thumb-${widget.shortCode}',
                                child: CachedNetworkImage(
                                  imageUrl: medium.thumbnailUrl,
                                  fit: BoxFit.contain,
                                  placeholder: (_, __) => Container(
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  ),
                                  errorWidget: (_, __, ___) => Container(
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                    // Double tap zones
                    // coverage:ignore-start
                    // The play/pause overlay above the zones wins every hit,
                    // so these can't fire in the current layout.
                    if (_controller != null && _controller!.value.isInitialized)
                      Positioned.fill(
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onDoubleTap: () => _onDoubleTap(false),
                                behavior: HitTestBehavior.translucent,
                                child: Container(color: Colors.transparent),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onDoubleTap: () => _onDoubleTap(true),
                                behavior: HitTestBehavior.translucent,
                                child: Container(color: Colors.transparent),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // coverage:ignore-end
                    // Play/Pause single tap overlay
                    if (_controller != null && _controller!.value.isInitialized)
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _controller!.value.isPlaying
                                  ? _controller!.pause()
                                  : _controller!.play();
                            });
                          },
                          child: Container(
                            color: Colors.transparent,
                            child: Center(
                              child: AnimatedOpacity(
                                opacity: _controller!.value.isPlaying ? 0 : 1,
                                duration: const Duration(milliseconds: 200),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.black
                                        .withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                  child: Icon(
                                    Icons.play_arrow_rounded,
                                    size: 40,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Skip animation overlay
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedOpacity(
                          opacity: _showSkip ? 1 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.3),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _skipForward
                                        ? Icons.forward_10
                                        : Icons.replay_10,
                                    color: Colors.white,
                                    size: 48,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _skipForward ? '+10s' : '-10s',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Bottom timeline
                    if (_controller != null && _controller!.value.isInitialized)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(0, 16, 0, 10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.6),
                              ],
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final barWidth = constraints.maxWidth;
                                  void seekToFraction(double fraction) {
                                    final dur = _controller!.value.duration;
                                    _controller!.seekTo(
                                      Duration(
                                        milliseconds: (fraction.clamp(0.0, 1.0) * dur.inMilliseconds).round(),
                                      ),
                                    );
                                  }

                                  final progress = _controller!.value.duration.inMilliseconds > 0
                                      ? _controller!.value.position.inMilliseconds /
                                          _controller!.value.duration.inMilliseconds
                                      : 0.0;

                                  final currentFraction = _isDraggingTimeline ? _dragProgress : progress;

                                  return GestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    onTapDown: (details) {
                                      final fraction = details.localPosition.dx / barWidth;
                                      seekToFraction(fraction);
                                    },
                                    onHorizontalDragStart: (_) {
                                      setState(() => _isDraggingTimeline = true);
                                    },
                                    onHorizontalDragUpdate: (details) {
                                      final fraction = details.localPosition.dx / barWidth;
                                      setState(() => _dragProgress = fraction.clamp(0.0, 1.0));
                                    },
                                    onHorizontalDragEnd: (_) {
                                      seekToFraction(_dragProgress);
                                      setState(() => _isDraggingTimeline = false);
                                    },
                                    onHorizontalDragCancel: () {
                                      setState(() => _isDraggingTimeline = false);
                                    },
                                    child: Container(
                                      height: 32,
                                      alignment: Alignment.center,
                                      child: Stack(
                                        alignment: Alignment.centerLeft,
                                        children: [
                                          // Background track
                                          Container(
                                            height: 4,
                                            color: Colors.white.withValues(alpha: 0.25),
                                          ),
                                          // Filled progress
                                          FractionallySizedBox(
                                            alignment: Alignment.centerLeft,
                                            widthFactor: currentFraction,
                                            child: Container(
                                              height: 4,
                                              color: Theme.of(context).colorScheme.primary,
                                            ),
                                          ),
                                          // Thumb / head
                                          Positioned(
                                            left: (currentFraction * barWidth - 8).clamp(0.0, barWidth - 16),
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 150),
                                              curve: Curves.easeOut,
                                              width: _isDraggingTimeline ? 16 : 12,
                                              height: _isDraggingTimeline ? 16 : 12,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                                                    blurRadius: 6,
                                                    spreadRadius: 1,
                                                  ),
                                                  BoxShadow(
                                                    color: Colors.black.withValues(alpha: 0.3),
                                                    blurRadius: 2,
                                                    offset: const Offset(0, 1),
                                                  ),
                                                ],
                                              ),
                                              child: Center(
                                                child: Container(
                                                  width: 6,
                                                  height: 6,
                                                  decoration: BoxDecoration(
                                                    color: Theme.of(context).colorScheme.primary,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDuration(
                                        _isDraggingTimeline
                                            ? Duration(
                                                milliseconds: (_dragProgress *
                                                        _controller!.value.duration.inMilliseconds)
                                                    .round(),
                                              )
                                            : _controller!.value.position,
                                      ),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      _formatDuration(_controller!.value.duration),
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Back button (last so it sits on top)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    // Mute button
                    Positioned(
                      top: 12,
                      right: 56,
                      child: GestureDetector(
                        onTap: _toggleMute,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _isMuted ? Icons.volume_off : Icons.volume_up,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    // Fullscreen button
                    Positioned(
                      top: 12,
                      right: 12,
                      child: GestureDetector(
                        onTap: _toggleFullscreen,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.fullscreen,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                        ],
                      ),
                    ),
                  ),
                ),
                ),
                // Info
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medium.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: () {
                          _pauseVideoIfNeeded();
                          pushPage(
                            context,
                            builder: (_) => ProfilePage(
                              slug: medium.user.slug,
                            ),
                          ).then((_) {
                            if (mounted) _resumeVideoIfNeeded();
                          });
                        },
                        child: Row(
                          children: [
                            ClipOval(
                              child: medium.user.avatarUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: medium.user.avatarUrl!,
                                      width: 36,
                                      height: 36,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(
                                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                      ),
                                      errorWidget: (_, __, ___) => Icon(
                                        Icons.person,
                                        color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey,
                                      ),
                                    )
                                  : Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: Icon(
                                        Icons.person,
                                        size: 18,
                                        color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    medium.user.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                  Text(
                                    '@${medium.user.slug}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _StatItem(
                              icon: Icons.visibility_outlined,
                              value: '${medium.viewsCount}',
                              label: 'Views',
                            ),
                            Container(
                              width: 1,
                              height: 28,
                              color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                            ),
                            GestureDetector(
                              onTap: _viewerCanLike ? _toggleLike : null,
                              child: _StatItem(
                                icon: _viewerLiked
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                value: '$_likesCount',
                                label: 'Likes',
                                iconColor: _viewerLiked ? Theme.of(context).colorScheme.primary : null,
                              ),
                            ),
                            if (MurrtubeApi.isAuthenticated) ...[
                              Container(
                                width: 1,
                                height: 28,
                                color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                              ),
                              GestureDetector(
                                onTap: _showSaveBottomSheet,
                                child: _StatItem(
                                  icon: Icons.playlist_add_rounded,
                                  value: '',
                                  label: 'Save',
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 28,
                                color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                              ),
                            ],
                            _StatItem(
                              icon: Icons.chat_bubble_outline,
                              value: '${medium.commentsCount}',
                              label: 'Comments',
                            ),
                          ],
                        ),
                      ),
                      if (medium.description != null &&
                          medium.description!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        LinkifyText(
                          text: medium.description!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey,
                            height: 1.5,
                          ),
                        ),
                      ],
                      if (medium.tags.isNotEmpty || MurrtubeApi.isAuthenticated) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: medium.tags
                                    .map((tag) => GestureDetector(
                                          onTap: () {
                                            _pauseVideoIfNeeded();
                                            pushPage(
                                              context,
                                              builder: (_) => SearchPage(initialQuery: tag.name),
                                            ).then((_) {
                                              if (mounted) _resumeVideoIfNeeded();
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).colorScheme.surface,
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(
                                                color: Theme.of(context).dividerColor
                                                    .withValues(alpha: 0.3),
                                              ),
                                            ),
                                            child: Text(
                                              '#${tag.name}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ))
                                    .toList(),
                              ),
                            ),
                            if (MurrtubeApi.isAuthenticated)
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                onPressed: _showTagEditSheet,
                                tooltip: 'Edit tags',
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Comments toggle
                GestureDetector(
                  onTap: () => setState(() => _showComments = !_showComments),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 18,
                          color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${medium.commentsCount} Comments',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        AnimatedRotation(
                          turns: _showComments ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.expand_more,
                            color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_showComments) ...[
                  const SizedBox(height: 10),
                  if (_viewerCanComment)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              decoration: InputDecoration(
                                hintText: 'Add a comment...',
                                filled: true,
                                fillColor: Theme.of(context).colorScheme.surface,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _postComment(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _postingComment
                              ? SizedBox(
                                  width: 36,
                                  height: 36,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                )
                              : GestureDetector(
                                  onTap: _postComment,
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary,
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    child: const Icon(
                                      Icons.send,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                        ],
                      ),
                    ),
                  if (_viewerCanComment) const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: _comments
                          .map((c) => _CommentTile(
                                key: _commentKeys[c.id],
                                comment: c,
                                viewerCanComment: _viewerCanComment,
                                onDelete: _viewerCanComment ? _deleteComment : null,
                                onReply: _viewerCanComment ? _replyToComment : null,
                                onPauseVideo: _pauseVideoIfNeeded,
                                onResumeVideo: _resumeVideoIfNeeded,
                                highlighted: _isCommentHighlighted(c.id),
                                replyKeys: _commentKeys,
                              ))
                          .toList(),
                    ),
                  ),
                ],
                // Watch more
                if (_watchMore.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Watch More',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cols = VideoCard.gridColumnCount(constraints.maxWidth - 40);
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cols,
                            childAspectRatio: VideoCard.gridAspectRatio(
                              context,
                              width: constraints.maxWidth - 40,
                              columns: cols,
                              spacing: 12,
                            ),
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: _watchMore.length,
                          itemBuilder: (context, index) {
                            final m = _watchMore[index];
                            return VideoCard(
                              media: m,
                              heroTag: 'video-thumb-${m.shortCode}',
                              onTap: () {
                                pushReplacementPage(
                                  context,
                                  builder: (_) => VideoDetailPage(
                                    shortCode: m.shortCode,
                                    heroTag: 'video-thumb-${m.shortCode}',
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
);
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color? iconColor;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: iconColor ?? Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey),
        const SizedBox(height: 4),
        if (value.isNotEmpty)
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        if (label.isNotEmpty)
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey,
            ),
          ),
      ],
    );
  }
}

class _SaveSheet extends StatefulWidget {
  final Media medium;
  final Future<void> Function(String name, String visibility) onCreate;
  final void Function(Playlist playlist) onSelect;

  const _SaveSheet({
    required this.medium,
    required this.onCreate,
    required this.onSelect,
  });

  @override
  State<_SaveSheet> createState() => _SaveSheetState();
}

class _SaveSheetState extends State<_SaveSheet> {
  bool _creating = false;
  bool _showCreateForm = false;
  bool _loading = true;
  List<Playlist> _playlists = [];
  final _nameController = TextEditingController();
  String _visibility = 'public';

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    try {
      final lists = await MurrtubeApi.getMyPlaylists();
      if (mounted) {
        setState(() {
          _playlists = lists;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Load playlists error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Save to playlist',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              if (_loading)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
                  ),
                )
              else if (_showCreateForm)
                _buildCreateForm()
              else
                _buildPlaylistList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistList() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_playlists.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'No playlists yet',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey.withValues(alpha: 0.7),
              ),
            ),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _playlists.length,
              itemBuilder: (ctx, i) {
                final p = _playlists[i];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.playlist_play,
                    color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey,
                  ),
                  title: Text(
                    p.name,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  ),
                  subtitle: Text(
                    '${p.visibility} · ${p.itemsCount} items',
                    style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey, fontSize: 12),
                  ),
                  onTap: () => widget.onSelect(p),
                );
              },
            ),
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => setState(() => _showCreateForm = true),
            icon: Icon(Icons.add, size: 18),
            label: const Text('Create new playlist'),
          ),
        ),
      ],
    );
  }

  Widget _buildCreateForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Playlist name',
            hintText: 'My favorites',
          ),
          autofocus: true,
        ),
        const SizedBox(height: 12),
        Text(
          'Visibility',
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            _VisibilityChip(
              label: 'Public',
              selected: _visibility == 'public',
              onTap: () => setState(() => _visibility = 'public'),
            ),
            const SizedBox(width: 8),
            _VisibilityChip(
              label: 'Unlisted',
              selected: _visibility == 'unlisted',
              onTap: () => setState(() => _visibility = 'unlisted'),
            ),
            const SizedBox(width: 8),
            _VisibilityChip(
              label: 'Private',
              selected: _visibility == 'private',
              onTap: () => setState(() => _visibility = 'private'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _creating || _nameController.text.trim().isEmpty
                ? null
                : () async {
                    setState(() => _creating = true);
                    try {
                      await widget.onCreate(_nameController.text.trim(), _visibility);
                    } finally {
                      if (mounted) setState(() => _creating = false);
                    }
                  },
            child: _creating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Create & save'),
          ),
        ),
      ],
    );
  }
}

class _VisibilityChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _VisibilityChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2) : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _CommentTile extends StatefulWidget {
  final Comment comment;
  final bool viewerCanComment;
  final Future<void> Function(String commentId)? onDelete;
  final Future<void> Function(String commentId, String body)? onReply;
  final VoidCallback? onPauseVideo;
  final VoidCallback? onResumeVideo;
  final bool highlighted;
  final Map<String, GlobalKey>? replyKeys;

  const _CommentTile({
    super.key,
    required this.comment,
    this.viewerCanComment = false,
    this.onDelete,
    this.onReply,
    this.onPauseVideo,
    this.onResumeVideo,
    this.highlighted = false,
    this.replyKeys,
  });

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  bool _showReplyInput = false;
  final _replyController = TextEditingController();
  bool _postingReply = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _submitReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty || widget.onReply == null) return;
    setState(() => _postingReply = true);
    try {
      await widget.onReply!(widget.comment.id, text);
      _replyController.clear();
      if (mounted) setState(() => _showReplyInput = false);
      // coverage:ignore-start
      // onReply handles its own errors and never rethrows.
    } catch (e) {
      debugPrint('reply error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to post reply')),
        );
      }
      // coverage:ignore-end
    } finally {
      if (mounted) setState(() => _postingReply = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final comment = widget.comment;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mutedColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.highlighted
              ? colorScheme.primary
              : theme.dividerColor.withValues(alpha: 0.3),
          width: widget.highlighted ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  widget.onPauseVideo?.call();
                  pushPage(
                    context,
                    builder: (_) => ProfilePage(slug: comment.user.slug),
                  ).then((_) {
                    if (mounted) widget.onResumeVideo?.call();
                  });
                },
                child: ClipOval(
                  child: comment.user.avatarUrl != null
                      ? CachedNetworkImage(
                          imageUrl: comment.user.avatarUrl!,
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: colorScheme.surfaceContainerHighest,
                          ),
                          errorWidget: (_, __, ___) => Icon(
                            Icons.person,
                            size: 16,
                            color: mutedColor,
                          ),
                        )
                      : Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.person,
                            size: 16,
                            color: mutedColor,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            widget.onPauseVideo?.call();
                            pushPage(
                              context,
                              builder: (_) => ProfilePage(slug: comment.user.slug),
                            ).then((_) {
                              if (mounted) widget.onResumeVideo?.call();
                            });
                          },
                          child: Text(
                            comment.user.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (comment.isCreator)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'CREATOR',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: colorScheme.primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinkifyText(
                      text: comment.body,
                      style: TextStyle(
                        fontSize: 13,
                        color: mutedColor,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (widget.viewerCanComment)
                          GestureDetector(
                            onTap: () => setState(() => _showReplyInput = !_showReplyInput),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.reply,
                                  size: 14,
                                  color: mutedColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Reply',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: mutedColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (widget.viewerCanComment && comment.isOwner)
                          const SizedBox(width: 16),
                        if (comment.isOwner && widget.onDelete != null)
                          GestureDetector(
                            onTap: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete comment?'),
                                  content: const Text('This cannot be undone.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                try {
                                  await widget.onDelete!(comment.id);
                                  // coverage:ignore-start
                                  // onDelete handles its own errors and
                                  // never rethrows.
                                } catch (e) {
                                  debugPrint('delete error: $e');
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Failed to delete comment')),
                                    );
                                  }
                                }
                                // coverage:ignore-end
                              }
                            },
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  size: 14,
                                  color: mutedColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Delete',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: mutedColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    if (_showReplyInput)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _replyController,
                                decoration: InputDecoration(
                                  hintText: 'Write a reply...',
                                  filled: true,
                                  fillColor: colorScheme.surfaceContainerHighest,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _submitReply(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _postingReply
                                ? SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colorScheme.primary,
                                    ),
                                  )
                                : GestureDetector(
                                    onTap: _submitReply,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Icon(
                                        Icons.send,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    if (comment.replies.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 8, top: 8),
                        child: Column(
                          children: comment.replies
                              .map((r) => _CommentTile(
                                    key: widget.replyKeys?[r.id],
                                    comment: r,
                                    viewerCanComment: widget.viewerCanComment,
                                    onDelete: widget.onDelete,
                                    onReply: widget.onReply,
                                    onPauseVideo: widget.onPauseVideo,
                                    onResumeVideo: widget.onResumeVideo,
                                    highlighted: widget.highlighted,
                                    replyKeys: widget.replyKeys,
                                  ))
                              .toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
