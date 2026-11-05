import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/notification.dart';
import '../services/murrtube_api.dart';
import '../utils/page_transitions.dart';
import 'package:url_launcher/url_launcher.dart';
import 'video_detail_page.dart';
import 'profile_page.dart';
import '../widgets/error_state.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<NotificationItem> _items = [];
  int _displayCap = 0;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await MurrtubeApi.getNotifications();
      setState(() {
        _items = result.items;
        _displayCap = result.displayCap;
        _loading = false;
      });
    } catch (e) {
      debugPrint('NotificationsPage error: $e');
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mutedColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    return Scaffold(
      body: _loading
          ? Center(
              child: SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary,
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.6,
                          child: _failed
                              ? ErrorState(
                                  icon: Icons.notifications_off_outlined,
                                  message: "Couldn't load notifications",
                                  onRetry: _load,
                                )
                              : Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.notifications_none,
                                        size: 48,
                                        color: mutedColor,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No notifications',
                                        style: TextStyle(color: mutedColor),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    )
                  : CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Activity',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                if (_items.any((i) => !i.read))
                                  GestureDetector(
                                    onTap: () {},
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        'Mark all read',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.all(20),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final item = _items[index];
                                return _NotificationCard(
                                  item: item,
                                  onTap: () {
                                    if (item.url == null) return;
                                    final videoMatch = RegExp(r'/v/([^/#]+)')
                                        .firstMatch(item.url!);
                                    if (videoMatch != null) {
                                      final fragmentMatch =
                                          RegExp(r'#(.+)').firstMatch(item.url!);
                                      pushPage(
                                        context,
                                        builder: (_) => VideoDetailPage(
                                          shortCode: videoMatch.group(1)!,
                                          commentId: fragmentMatch?.group(1),
                                        ),
                                      );
                                      return;
                                    }
                                    final userMatch =
                                        RegExp(r'^/?([A-Za-z0-9_-]+)/?')
                                            .firstMatch(item.url!);
                                    if (userMatch != null &&
                                        !item.url!.startsWith('http')) {
                                      pushPage(
                                        context,
                                        builder: (_) => ProfilePage(
                                          slug: userMatch.group(1)!,
                                        ),
                                      );
                                      return;
                                    }
                                    final uri = Uri.tryParse(item.url!);
                                    if (uri != null) {
                                      launchUrl(
                                        uri.hasScheme
                                            ? uri
                                            : Uri.parse(
                                                'https://murrtube.net${item.url}'),
                                        mode: LaunchMode.externalApplication,
                                      );
                                    }
                                  },
                                );
                              },
                              childCount: _items.length,
                            ),
                          ),
                        ),
                        if (_displayCap > 0 && _items.length >= _displayCap)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: Center(
                                child: Text(
                                  'Showing latest $_displayCap',
                                  style: TextStyle(color: mutedColor),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback? onTap;

  const _NotificationCard({required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mutedColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                item.actor?.avatarUrl != null
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: item.actor!.avatarUrl!,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Icon(
                            Icons.person,
                            size: 20,
                            color: mutedColor,
                          ),
                        ),
                      )
                    : Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: item.read
                              ? colorScheme.surfaceContainerHighest
                              : colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          item.read
                              ? Icons.notifications_none_outlined
                              : Icons.notifications_rounded,
                          color: item.read ? mutedColor : colorScheme.primary,
                          size: 20,
                        ),
                      ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          fontWeight: item.read
                              ? FontWeight.w500
                              : FontWeight.w700,
                          fontSize: 14,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.body,
                        style: TextStyle(
                          fontSize: 13,
                          color: mutedColor,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _timeAgo(item.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: mutedColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!item.read)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'now';
  }
}
