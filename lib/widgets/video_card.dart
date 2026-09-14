import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/media.dart';

class VideoCard extends StatelessWidget {
  final Media media;
  final VoidCallback onTap;
  final String? heroTag;

  const VideoCard({
    super.key,
    required this.media,
    required this.onTap,
    this.heroTag,
  });

  static const double thumbnailAspectRatio = 16 / 10;

  static int gridColumnCount(double width) {
    if (width >= 1600) return 5;
    if (width >= 900) return 4;
    if (width >= 600) return 3;
    return 2;
  }

  // Cell height must match the thumbnail plus the info block or the card
  // gets dead space at the bottom. Width is the space the cells share,
  // after any grid padding.
  static double gridAspectRatio(
    BuildContext context, {
    required double width,
    required int columns,
    double spacing = 16,
  }) {
    assert(columns > 0);
    final cellWidth = math.max(
      (width - spacing * (columns - 1)) / columns,
      1.0,
    );
    final scale = MediaQuery.textScalerOf(context).scale(1.0);
    // Padding and gaps fixed, text rows scale, rows keep icon minimums.
    final infoHeight = 19 +
        16.9 * scale +
        math.max(18, 16.2 * scale) +
        math.max(12, 14.9 * scale);
    final height = cellWidth / thumbnailAspectRatio + infoHeight;
    return cellWidth / height;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mutedColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: thumbnailAspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: heroTag ?? 'video-thumb-${media.shortCode}',
                      child: CachedNetworkImage(
                        imageUrl: media.thumbnailUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: colorScheme.surfaceContainerHighest,
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: mutedColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      media.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        height: 1.3,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (media.user.avatarUrl != null)
                          ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: media.user.avatarUrl!,
                              width: 18,
                              height: 18,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                color: colorScheme.surfaceContainerHighest,
                              ),
                              errorWidget: (_, __, ___) => Icon(
                                Icons.person,
                                size: 16,
                                color: mutedColor,
                              ),
                            ),
                          )
                        else
                          Icon(
                            Icons.person,
                            size: 16,
                            color: mutedColor,
                          ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            media.user.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: mutedColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          size: 12,
                          color: mutedColor,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            _formatCount(media.viewsCount),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: mutedColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          Icons.thumb_up_outlined,
                          size: 12,
                          color: mutedColor,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            _formatCount(media.likesCount),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: mutedColor,
                              fontWeight: FontWeight.w500,
                            ),
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
    );
  }

  static String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return '$count';
  }
}
