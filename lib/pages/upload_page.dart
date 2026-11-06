import 'package:flutter/material.dart';
import '../services/murrtube_api.dart';
import '../widgets/error_state.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  Map<String, dynamic>? _props;
  bool _loading = true;
  bool _failed = false;
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _visibility = 'public';

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final props = await MurrtubeApi.getUpload();
      setState(() {
        _props = props;
        _loading = false;
      });
    } catch (e) {
      debugPrint('UploadPage error: $e');
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
    final rawVisibilities = _props?['visibilities'] as List<dynamic>? ?? [];
    final visibilities = rawVisibilities.map((v) {
      if (v is String) return {'value': v, 'label': v[0].toUpperCase() + v.substring(1)};
      if (v is Map) return Map<String, dynamic>.from(v);
      return {'value': v.toString(), 'label': v.toString()};
    }).toList();
    final rawPopularTags = _props?['popular_tags'] as List<dynamic>? ?? [];
    final popularTags = rawPopularTags.map((t) {
      if (t is String) return {'name': t};
      if (t is Map) return Map<String, dynamic>.from(t);
      return {'name': t.toString()};
    }).toList();

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
          : _failed
              ? ErrorState(
                  icon: Icons.cloud_off_outlined,
                  message: "Couldn't load upload form",
                  onRetry: _load,
                )
              : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Upload',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 24),
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Title'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _titleController,
                        style: TextStyle(color: colorScheme.onSurface),
                        decoration: InputDecoration(
                          hintText: 'Enter video title...',
                          hintStyle: TextStyle(color: mutedColor),
                          filled: true,
                          fillColor: colorScheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          counterStyle: TextStyle(color: mutedColor),
                        ),
                        maxLength: _props?['max_title_length'] ?? 100,
                      ),
                      const SizedBox(height: 20),
                      _buildLabel('Description'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _descController,
                        style: TextStyle(color: colorScheme.onSurface),
                        decoration: InputDecoration(
                          hintText: 'Describe your video...',
                          hintStyle: TextStyle(color: mutedColor),
                          filled: true,
                          fillColor: colorScheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        maxLines: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (visibilities.isNotEmpty) ...[
                  _buildLabel('Visibility'),
                  const SizedBox(height: 10),
                  _buildCard(
                    child: Column(
                      children: visibilities.map((v) {
                        final value = v['value'] as String;
                        final isSelected = _visibility == value;
                        return InkWell(
                          onTap: () => setState(() => _visibility = value),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: visibilities.last != v
                                ? BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: theme.dividerColor
                                            .withValues(alpha: 0.3),
                                      ),
                                    ),
                                  )
                                : null,
                            child: Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? colorScheme.primary
                                          : theme.dividerColor,
                                      width: 2,
                                    ),
                                  ),
                                  child: isSelected
                                      ? Container(
                                          margin: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: colorScheme.primary,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 14),
                                Text(
                                  v['label'] ?? value,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: colorScheme.onSurface,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                if (popularTags.isNotEmpty) ...[
                  _buildLabel('Popular Tags'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: popularTags
                        .map((t) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: theme.dividerColor.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                t['name'] ?? '',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      debugPrint('Upload flow not implemented');
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.upload_file, size: 20),
                        SizedBox(width: 8),
                        Text('Select Video File'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCard({required Widget child}) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.3),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey,
        letterSpacing: 0.5,
      ),
    );
  }
}
