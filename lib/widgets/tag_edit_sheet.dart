import 'dart:async';
import 'package:flutter/material.dart';
import '../models/tag.dart';
import '../services/murrtube_api.dart';

class TagEditSheet extends StatefulWidget {
  final String shortCode;
  final List<Tag> initialTags;
  final void Function(List<Tag> tags)? onSaved;

  const TagEditSheet({
    super.key,
    required this.shortCode,
    required this.initialTags,
    this.onSaved,
  });

  @override
  State<TagEditSheet> createState() => _TagEditSheetState();
}

class _TagEditSheetState extends State<TagEditSheet> {
  late List<Tag> _tags;
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  int _suggestGen = 0;
  bool _suggesting = false;
  List<({String name, String category, int count})> _suggestions = [];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tags = List.from(widget.initialTags);
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged(String text) {
    _debounce?.cancel();
    final query = text.trim();
    final gen = ++_suggestGen;
    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
        _suggesting = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted || gen != _suggestGen) return;
      setState(() => _suggesting = true);
      try {
        final result = await MurrtubeApi.searchSuggest(query);
        if (!mounted || gen != _suggestGen) return;
        final currentNames = _tags.map((t) => t.name.toLowerCase()).toSet();
        setState(() {
          _suggestions = result.tags
              .where((s) => !currentNames.contains(s.name.toLowerCase()))
              .toList();
          _suggesting = false;
        });
      } catch (e) {
        if (!mounted || gen != _suggestGen) return;
        setState(() => _suggesting = false);
      }
    });
  }

  void _addTag(String name, {String category = 'general'}) {
    _debounce?.cancel();
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) return;
    if (!RegExp(r'^[a-z0-9_ -]{1,32}$').hasMatch(normalized)) {
      setState(() {
        _error =
            'Tags may use letters, numbers, spaces, dashes and underscores (max 32)';
      });
      return;
    }
    if (_tags.any((t) => t.name.toLowerCase() == normalized)) {
      setState(() => _error = '"$normalized" is already added');
      return;
    }
    setState(() {
      _error = null;
      _tags.add(Tag(name: normalized, category: category, count: 0));
      _suggestions = [];
      _controller.clear();
    });
    _focusNode.requestFocus();
  }

  void _removeTag(Tag tag) {
    setState(() {
      _tags.removeWhere((t) => t.name.toLowerCase() == tag.name.toLowerCase());
    });
  }

  Future<void> _save() async {
    final initialNames = widget.initialTags.map((t) => t.name.toLowerCase()).toSet();
    final currentNames = _tags.map((t) => t.name.toLowerCase()).toSet();

    final additions = currentNames.difference(initialNames).toList();
    final removals = initialNames.difference(currentNames).toList();

    if (additions.isEmpty && removals.isEmpty) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final updated = await MurrtubeApi.editTags(
        shortCode: widget.shortCode,
        additions: additions,
        removals: removals,
      );
      if (!mounted) return;
      widget.onSaved?.call(updated);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Failed to save tags: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Text(
                    'Edit Tags',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (_saving)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.primary,
                      ),
                    )
                  else
                    TextButton(
                      onPressed: _save,
                      child: const Text('Save'),
                    ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _error!,
                  style: TextStyle(color: colorScheme.error, fontSize: 13),
                ),
              ),
            // Current tags
            if (_tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _tags.map((tag) {
                    return Chip(
                      label: Text('#${tag.name}'),
                      labelStyle: TextStyle(
                        fontSize: 13,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      side: BorderSide(
                        color: theme.dividerColor.withValues(alpha: 0.3),
                      ),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: _saving ? null : () => _removeTag(tag),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    );
                  }).toList(),
                ),
              ),
            // Input
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: !_saving,
                textInputAction: TextInputAction.done,
                onChanged: _onTextChanged,
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    _addTag(value.trim());
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Add a tag...',
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  suffixIcon: _suggesting
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.primary,
                            ),
                          ),
                        )
                      : _controller.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => _addTag(_controller.text),
                            )
                          : null,
                ),
              ),
            ),
            // Suggestions
            if (_suggestions.isNotEmpty)
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    final s = _suggestions[index];
                    return ListTile(
                      dense: true,
                      title: Text(s.name),
                      subtitle: Text(
                        '${s.category}  \u2022  ${s.count}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                      onTap: () => _addTag(s.name, category: s.category),
                    );
                  },
                ),
              )
            else if (_controller.text.isNotEmpty &&
                !_suggesting &&
                _focusNode.hasFocus)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'Press enter or tap + to add "${_controller.text.trim()}"',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
