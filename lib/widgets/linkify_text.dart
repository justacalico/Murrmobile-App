import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../utils/launcher.dart';

class LinkifyText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextStyle? linkStyle;
  final TextAlign? textAlign;

  const LinkifyText({
    super.key,
    required this.text,
    this.style,
    this.linkStyle,
    this.textAlign,
  });

  static final _urlRegex = RegExp(
    r'(https?://[^\s<>"{}|\\^`\[\]]+)',
    caseSensitive: false,
  );

  @override
  State<LinkifyText> createState() => _LinkifyTextState();
}

class _LinkifyTextState extends State<LinkifyText> {
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final defaultStyle = widget.style ??
        TextStyle(
          fontSize: 14,
          color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey,
        );
    final defaultLinkStyle = widget.linkStyle ??
        defaultStyle.copyWith(
          color: Theme.of(context).colorScheme.primary,
          decoration: TextDecoration.underline,
        );

    final spans = <TextSpan>[];
    var lastIndex = 0;

    for (final match in LinkifyText._urlRegex.allMatches(widget.text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: widget.text.substring(lastIndex, match.start)));
      }
      var url = match.group(0)!;
      var end = match.end;
      while (url.isNotEmpty &&
          '.,!?;:\'")]'.contains(url[url.length - 1])) {
        url = url.substring(0, url.length - 1);
        end--;
      }
      if (url.isEmpty) {
        continue;
      }
      if (end < match.end) {
        spans.add(TextSpan(
          text: widget.text.substring(lastIndex, match.start),
        ));
      }
      final linkUrl = url;
      final recognizer = TapGestureRecognizer()
        ..onTap = () => launchExternal(context, linkUrl);
      _recognizers.add(recognizer);
      spans.add(TextSpan(
        text: linkUrl,
        style: defaultLinkStyle,
        recognizer: recognizer,
      ));
      lastIndex = end;
    }

    if (lastIndex < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(lastIndex)));
    }

    return RichText(
      textAlign: widget.textAlign ?? TextAlign.start,
      text: TextSpan(style: defaultStyle, children: spans),
    );
  }
}
