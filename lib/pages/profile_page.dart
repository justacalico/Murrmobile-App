import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/media.dart';
import '../models/playlist.dart';
import '../models/user.dart';
import '../services/murrtube_api.dart';
import '../utils/page_transitions.dart';
import '../widgets/video_card.dart';
import 'video_detail_page.dart';
import 'playlist_page.dart';

class ProfilePage extends StatefulWidget {
  final String slug;
  final bool fromRoot;

  const ProfilePage({super.key, required this.slug, this.fromRoot = false});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  User? _user;
  List<Media> _media = [];
  List<Playlist> _playlists = [];
  bool _isSubscribed = false;
  bool _isBlocked = false;
  bool _isSelf = false;
  int? _subscribersCount;
  int? _subscriptionsCount;
  String? _bio;
  String? _telegramUrl;
  String? _gitlabUrl;
  String? _twitterUrl;
  String? _furaffinityUrl;
  String? _patreonUrl;
  String? _kofiUrl;
  String? _blueskyUrl;
  String? _onlyfansUrl;
  Map<String, int> _tabCounts = {};
  bool _loading = true;
  bool _hasMore = true;
  int _currentPage = 1;
  String _currentTab = 'videos';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final tabs = ['videos', 'likes', 'playlists'];
        final newTab = tabs[_tabController.index];
        if (newTab != _currentTab) {
          _currentTab = newTab;
          _currentPage = 1;
          _hasMore = true;
          _media = [];
          _load();
        }
      }
    });
    _load();
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slug != widget.slug) {
      _currentPage = 1;
      _hasMore = true;
      _media = [];
      _playlists = [];
      _load();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await MurrtubeApi.getUserProfile(
        widget.slug,
        tab: _currentTab,
      );
      setState(() {
        _user = result.user;
        if (_currentTab == 'playlists') {
          _playlists = result.playlists;
        } else {
          _media = result.media;
        }
        _isSubscribed = result.isSubscribed;
        _isBlocked = result.isBlocked;
        _isSelf = result.isSelf;
        _subscribersCount = result.subscribersCount;
        _subscriptionsCount = result.subscriptionsCount;
        _bio = result.bio;
        _telegramUrl = result.telegramUrl;
        _gitlabUrl = result.gitlabUrl;
        _twitterUrl = result.twitterUrl;
        _furaffinityUrl = result.furaffinityUrl;
        _patreonUrl = result.patreonUrl;
        _kofiUrl = result.kofiUrl;
        _blueskyUrl = result.blueskyUrl;
        _onlyfansUrl = result.onlyfansUrl;
        _tabCounts = result.tabCounts;
        _hasMore = result.pagination.next != null;
        _currentPage = result.pagination.page;
        _loading = false;
      });
    } catch (e) {
      debugPrint('ProfilePage load error: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loading) return;
    try {
      final nextPage = _currentPage + 1;
      final result = await MurrtubeApi.getUserProfile(
        widget.slug,
        tab: _currentTab,
        page: nextPage,
      );
      setState(() {
        if (_currentTab == 'playlists') {
          _playlists.addAll(result.playlists);
        } else {
          _media.addAll(result.media);
        }
        _hasMore = result.pagination.next != null;
        _currentPage = result.pagination.page;
      });
    } catch (e) {
      debugPrint('ProfilePage loadMore error: $e');
    }
  }

  Future<void> _toggleSubscribe() async {
    if (_user == null || _isSelf || !MurrtubeApi.isAuthenticated) return;
    final wasSubscribed = _isSubscribed;
    setState(() {
      _isSubscribed = !wasSubscribed;
      _subscribersCount = (_subscribersCount ?? 0) + (wasSubscribed ? -1 : 1);
    });
    try {
      if (wasSubscribed) {
        await MurrtubeApi.unsubscribeFromUser(_user!.slug);
      } else {
        await MurrtubeApi.subscribeToUser(_user!.slug);
      }
    } catch (e) {
      debugPrint('Toggle subscribe error: $e');
      setState(() {
        _isSubscribed = wasSubscribed;
        _subscribersCount = (_subscribersCount ?? 0) + (wasSubscribed ? 1 : -1);
      });
    }
  }

  Future<void> _toggleBlock() async {
    if (_user == null || _isSelf || !MurrtubeApi.isAuthenticated) return;
    final wasBlocked = _isBlocked;
    setState(() => _isBlocked = !wasBlocked);
    try {
      if (wasBlocked) {
        await MurrtubeApi.unblockUser(_user!.slug);
      } else {
        await MurrtubeApi.blockUser(_user!.slug);
      }
    } catch (e) {
      debugPrint('Toggle block error: $e');
      setState(() => _isBlocked = wasBlocked);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update block status')),
        );
      }
    }
  }

  String _formatCount(int? n) {
    if (n == null) return '0';
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  List<_SocialLinkData> get _socialLinks {
    final links = <_SocialLinkData>[];
    if (_gitlabUrl != null && _gitlabUrl!.isNotEmpty) {
      links.add(_SocialLinkData(
        icon: Icons.code,
        label: 'GitLab',
        url: _gitlabUrl!,
      ));
    }
    if (_twitterUrl != null && _twitterUrl!.isNotEmpty) {
      links.add(_SocialLinkData(
        icon: Icons.flutter_dash,
        label: 'X',
        url: _twitterUrl!,
      ));
    }
    if (_furaffinityUrl != null && _furaffinityUrl!.isNotEmpty) {
      links.add(_SocialLinkData(
        icon: Icons.pets,
        label: 'FurAffinity',
        url: _furaffinityUrl!,
      ));
    }
    if (_patreonUrl != null && _patreonUrl!.isNotEmpty) {
      links.add(_SocialLinkData(
        icon: Icons.favorite,
        label: 'Patreon',
        url: _patreonUrl!,
      ));
    }
    if (_kofiUrl != null && _kofiUrl!.isNotEmpty) {
      links.add(_SocialLinkData(
        icon: Icons.coffee,
        label: 'Ko-fi',
        url: _kofiUrl!,
      ));
    }
    if (_blueskyUrl != null && _blueskyUrl!.isNotEmpty) {
      links.add(_SocialLinkData(
        icon: Icons.cloud,
        label: 'Bluesky',
        url: _blueskyUrl!,
      ));
    }
    if (_onlyfansUrl != null && _onlyfansUrl!.isNotEmpty) {
      links.add(_SocialLinkData(
        icon: Icons.favorite_border,
        label: 'OnlyFans',
        url: _onlyfansUrl!,
      ));
    }
    return links;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mutedColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    if (_loading && _user == null) {
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

    final user = _user;
    if (user == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_off, size: 48, color: mutedColor),
              const SizedBox(height: 12),
              Text(
                'User not found',
                style: TextStyle(color: mutedColor, fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: _buildHeader(context, user, mutedColor, colorScheme),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    indicatorColor: colorScheme.primary,
                    labelColor: colorScheme.primary,
                    unselectedLabelColor: mutedColor,
                    tabs: [
                      Tab(text: 'Videos ${_tabBadge('videos')}'),
                      Tab(text: 'Likes ${_tabBadge('likes')}'),
                      Tab(text: 'Playlists ${_tabBadge('playlists')}'),
                    ],
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildVideosTab(context, colorScheme, mutedColor),
              _buildLikesTab(context, colorScheme, mutedColor),
              _buildPlaylistsTab(context, colorScheme, mutedColor),
            ],
          ),
        ),
      ),
    );
  }

  String _tabBadge(String key) {
    final count = _tabCounts[key];
    if (count == null || count == 0) return '';
    return _formatCount(count);
  }

  Widget _buildLikesTab(
    BuildContext context,
    ColorScheme colorScheme,
    Color mutedColor,
  ) {
    return _buildVideosTab(context, colorScheme, mutedColor);
  }

  Widget _buildHeader(
    BuildContext context,
    User user,
    Color mutedColor,
    ColorScheme colorScheme,
  ) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                if (!widget.fromRoot)
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
                if (!widget.fromRoot) const SizedBox(width: 12),
                const Spacer(),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ClipOval(
            child: user.avatarUrl != null
                ? CachedNetworkImage(
                    imageUrl: user.avatarUrl!,
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: colorScheme.surfaceContainerHighest,
                    ),
                    errorWidget: (_, __, ___) => Icon(
                      Icons.person,
                      size: 48,
                      color: mutedColor,
                    ),
                  )
                : Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(48),
                    ),
                    child: Icon(
                      Icons.person,
                      size: 48,
                      color: mutedColor,
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Text(
            user.name,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '@${user.slug}',
            style: TextStyle(
              fontSize: 14,
              color: mutedColor,
            ),
          ),
          if (_bio != null && _bio!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _bio!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: mutedColor,
                  height: 1.4,
                ),
              ),
            ),
          ],
          if (_socialLinks.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 14,
              children: _socialLinks.map((l) => _SocialLink(
                icon: l.icon,
                label: l.label,
                url: l.url,
                color: colorScheme.primary,
              )).toList(),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StatBadge(label: 'Videos', value: _formatCount(_media.length)),
              const SizedBox(width: 20),
              _StatBadge(
                label: 'Subscribers',
                value: _formatCount(_subscribersCount),
              ),
              const SizedBox(width: 20),
              _StatBadge(
                label: 'Following',
                value: _formatCount(_subscriptionsCount),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!_isSelf && MurrtubeApi.isAuthenticated)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _toggleSubscribe,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isSubscribed ? colorScheme.surface : colorScheme.primary,
                    foregroundColor: _isSubscribed
                        ? colorScheme.onSurface
                        : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: _isSubscribed
                          ? BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.3))
                          : BorderSide.none,
                    ),
                  ),
                  child: Text(
                    _isSubscribed ? 'Subscribed' : 'Subscribe',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          if (!_isSelf && MurrtubeApi.isAuthenticated) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _toggleBlock,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _isBlocked
                        ? colorScheme.onSurface
                        : colorScheme.error,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(
                      color: _isBlocked
                          ? Theme.of(context).dividerColor.withValues(alpha: 0.3)
                          : colorScheme.error,
                    ),
                  ),
                  child: Text(
                    _isBlocked ? 'Unblock' : 'Block',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
          if (_telegramUrl != null && _telegramUrl!.isNotEmpty) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {/* url_launcher */},
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.telegram, size: 16, color: colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Telegram',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildVideosTab(
    BuildContext context,
    ColorScheme colorScheme,
    Color mutedColor,
  ) {
    if (_media.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off, size: 48, color: mutedColor),
            const SizedBox(height: 12),
            Text(
              'No videos yet',
              style: TextStyle(color: mutedColor, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (scroll) {
        if (scroll.metrics.pixels >= scroll.metrics.maxScrollExtent * 0.8) {
          _loadMore();
        }
        return false;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cols = VideoCard.gridColumnCount(constraints.maxWidth - 32);
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              childAspectRatio: VideoCard.gridAspectRatio(
                context,
                width: constraints.maxWidth - 32,
                columns: cols,
                spacing: 12,
              ),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _media.length + (_hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= _media.length) {
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
          );
        },
      ),
    );
  }

  Widget _buildPlaylistsTab(
    BuildContext context,
    ColorScheme colorScheme,
    Color mutedColor,
  ) {
    if (_playlists.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.playlist_play, size: 48, color: mutedColor),
            const SizedBox(height: 12),
            Text(
              'No playlists yet',
              style: TextStyle(color: mutedColor, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _playlists.length,
      itemBuilder: (context, index) {
        final p = _playlists[index];
        return GestureDetector(
          onTap: () {
            if (_user == null) return;
            pushPage(
              context,
              builder: (_) => PlaylistPage(
                userSlug: _user!.slug,
                playlistSlug: p.slug,
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.playlist_play, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        '${p.visibility} · ${p.itemsCount} items',
                        style: TextStyle(
                          fontSize: 12,
                          color: mutedColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: mutedColor, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;

  const _StatBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: theme.textTheme.bodyMedium?.color ?? Colors.grey,
          ),
        ),
      ],
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }
}

class _SocialLinkData {
  final IconData icon;
  final String label;
  final String url;

  _SocialLinkData({required this.icon, required this.label, required this.url});
}

class _SocialLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final String url;
  final Color color;

  const _SocialLink({
    required this.icon,
    required this.label,
    required this.url,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {/* url_launcher */},
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
