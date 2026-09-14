import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/media.dart';
import '../models/user.dart';
import '../models/tag.dart';
import '../services/murrtube_api.dart';
import '../utils/page_transitions.dart';
import '../widgets/video_card.dart';
import 'video_detail_page.dart';
import 'profile_page.dart';

class SearchPage extends StatefulWidget {
  final String? initialQuery;

  const SearchPage({super.key, this.initialQuery});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  List<Media> _media = [];
  List<User> _users = [];
  List<Tag> _tagMatches = [];
  bool _loading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String? _lastQuery;

  List<({String name, String category, int count})> _suggestedTags = [];
  List<({String slug, String name, String? avatarUrl})> _suggestedUsers = [];
  bool _suggestionsLoading = false;
  Timer? _suggestionDebounce;

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _loading = true;
      _lastQuery = query;
      _currentPage = 1;
      _hasMore = true;
      _suggestedTags = [];
      _suggestedUsers = [];
    });
    try {
      final result = await MurrtubeApi.search(query: query, page: _currentPage);
      setState(() {
        _media = result.media;
        _users = result.users;
        _tagMatches = result.tagMatches;
        _hasMore = result.pagination.next != null;
      });
    } catch (e) {
      debugPrint('SearchPage error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.length < 2) {
      setState(() {
        _suggestedTags = [];
        _suggestedUsers = [];
      });
      return;
    }
    setState(() => _suggestionsLoading = true);
    try {
      final result = await MurrtubeApi.searchSuggest(query);
      setState(() {
        _suggestedTags = result.tags;
        _suggestedUsers = result.users;
        _suggestionsLoading = false;
      });
    } catch (e) {
      debugPrint('SearchPage suggestions error: $e');
      setState(() => _suggestionsLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore || _lastQuery == null) return;
    setState(() => _loading = true);
    try {
      final nextPage = _currentPage + 1;
      final result = await MurrtubeApi.search(query: _lastQuery!, page: nextPage);
      setState(() {
        _media.addAll(result.media);
        _currentPage = nextPage;
        _hasMore = result.pagination.next != null;
      });
    } catch (e) {
      debugPrint('SearchPage loadMore error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _controller.text = widget.initialQuery!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _search();
      });
    }
  }

  @override
  void dispose() {
    _suggestionDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mutedColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  if (Navigator.canPop(context))
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.dividerColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Icon(
                          Icons.arrow_back,
                          size: 20,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.dividerColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: TextField(
                        controller: _controller,
                        style: TextStyle(color: colorScheme.onSurface),
                        decoration: InputDecoration(
                          hintText: 'Search videos, users, tags...',
                          hintStyle: TextStyle(color: mutedColor),
                          prefixIcon: Icon(
                            Icons.search,
                            color: mutedColor,
                          ),
                          suffixIcon: _controller.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    color: mutedColor,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    _controller.clear();
                                    setState(() {
                                      _media = [];
                                      _users = [];
                                      _tagMatches = [];
                                      _lastQuery = null;
                                      _hasMore = true;
                                      _currentPage = 1;
                                    });
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        onChanged: (text) {
                          _suggestionDebounce?.cancel();
                          _suggestionDebounce = Timer(const Duration(milliseconds: 300), () {
                            _fetchSuggestions(text.trim());
                          });
                        },
                        onSubmitted: (_) {
                          _suggestionDebounce?.cancel();
                          _search();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _search,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.search,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_loading)
            SliverFillRemaining(
              child: Center(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            )
          else if (_lastQuery == null) ...[
            if (_suggestedTags.isNotEmpty || _suggestedUsers.isNotEmpty || _suggestionsLoading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_suggestionsLoading)
                        Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.primary,
                            ),
                          ),
                        )
                      else ...[
                        if (_suggestedTags.isNotEmpty) ...[
                          Text(
                            'Tags',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: mutedColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _suggestedTags
                                .map((tag) => GestureDetector(
                                      onTap: () {
                                        _controller.text = tag.name;
                                        _search();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colorScheme.surface,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: theme.dividerColor.withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.local_offer_outlined,
                                              size: 14,
                                              color: colorScheme.primary,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              tag.name,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color: colorScheme.onSurface,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${tag.count}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: mutedColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ))
                                .toList(),
                          ),
                        ],
                        if (_suggestedUsers.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Users',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: mutedColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Column(
                            children: _suggestedUsers
                                .map((user) => GestureDetector(
                                      onTap: () {
                                        pushPage(
                                          context,
                                          builder: (_) => ProfilePage(slug: user.slug),
                                        );
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: colorScheme.surface,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: theme.dividerColor.withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            ClipOval(
                                              child: user.avatarUrl != null
                                                  ? CachedNetworkImage(
                                                      imageUrl: user.avatarUrl!,
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
                                            const SizedBox(width: 10),
                                            Text(
                                              user.name,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                                color: colorScheme.onSurface,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ))
                                .toList(),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              )
            else
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.search,
                        size: 48,
                        color: mutedColor,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Type to search',
                        style: TextStyle(
                          color: mutedColor,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ]
          else ...[
            if (_tagMatches.isNotEmpty) ...[
              _SectionHeader(title: 'Tags (${_tagMatches.length})'),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _tagMatches
                        .map((tag) => _TagChip(
                              tag: tag,
                              onTap: () {
                                _controller.text = tag.name;
                                _search();
                              },
                            ))
                        .toList(),
                  ),
                ),
              ),
            ],
            if (_users.isNotEmpty) ...[
              _SectionHeader(title: 'Users (${_users.length})'),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _UserTile(user: _users[index]),
                    childCount: _users.length,
                  ),
                ),
              ),
            ],
            if (_media.isNotEmpty) ...[
              _SectionHeader(title: 'Videos (${_media.length})'),
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final cols = VideoCard.gridColumnCount(constraints.crossAxisExtent);
                    return SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        childAspectRatio: VideoCard.gridAspectRatio(
                          context,
                          width: constraints.crossAxisExtent,
                          columns: cols,
                          spacing: 16,
                        ),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index >= _media.length) {
                            if (_hasMore) {
                              WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
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
            if (_media.isEmpty &&
                _users.isEmpty &&
                _tagMatches.isEmpty &&
                _lastQuery != null)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    'No results found',
                    style: TextStyle(color: mutedColor),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final Tag tag;
  final VoidCallback onTap;

  const _TagChip({required this.tag, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mutedColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.dividerColor.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_offer_outlined,
              size: 14,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              tag.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${tag.count}',
              style: TextStyle(
                fontSize: 12,
                color: mutedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final User user;

  const _UserTile({required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mutedColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    return GestureDetector(
      onTap: () {
        pushPage(
          context,
          builder: (_) => ProfilePage(slug: user.slug),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.dividerColor.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            ClipOval(
              child: user.avatarUrl != null
                ? CachedNetworkImage(
                    imageUrl: user.avatarUrl!,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: colorScheme.surfaceContainerHighest,
                    ),
                    errorWidget: (_, __, ___) => Icon(
                      Icons.person,
                      color: mutedColor,
                    ),
                  )
                : Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.person,
                      color: mutedColor,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (user.slug.isNotEmpty)
                  Text(
                    '@${user.slug}',
                    style: TextStyle(
                      fontSize: 12,
                      color: mutedColor,
                    ),
                  ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: mutedColor,
            size: 20,
          ),
        ],
      ),
    ),
    );
  }
}
