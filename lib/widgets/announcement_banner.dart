import 'package:flutter/material.dart';
import '../models/announcement.dart';
import '../utils/launcher.dart';
import 'linkify_text.dart';

class AnnouncementBanner extends StatelessWidget {
  final Announcement announcement;
  final VoidCallback? onDismiss;

  const AnnouncementBanner({
    super.key,
    required this.announcement,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mutedColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withValues(alpha: 0.15),
            colorScheme.secondary.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  announcement.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              if (onDismiss != null)
                Semantics(
                  button: true,
                  label: 'Dismiss announcement',
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: onDismiss,
                    tooltip: 'Dismiss',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          LinkifyText(
            text: announcement.body,
            style: TextStyle(
              fontSize: 13,
              color: mutedColor,
              height: 1.45,
            ),
          ),
          if (announcement.ctaUrl != null && announcement.ctaLabel != null) ...[
            const SizedBox(height: 12),
            Semantics(
              button: true,
              label: announcement.ctaLabel,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => launchExternal(context, announcement.ctaUrl!),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          announcement.ctaLabel!,
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.open_in_new,
                          size: 14,
                          color: colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
