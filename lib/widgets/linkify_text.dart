import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
      final url = match.group(0)!;
      final recognizer = TapGestureRecognizer()
        ..onTap = () async {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        };
      _recognizers.add(recognizer);
      spans.add(TextSpan(
        text: url,
        style: defaultLinkStyle,
        recognizer: recognizer,
      ));
      lastIndex = match.end;
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
