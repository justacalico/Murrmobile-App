import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<bool> launchExternal(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    final uri = Uri.parse(url.trim());
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      messenger?.showSnackBar(
        const SnackBar(content: Text("Can't open that link")),
      );
      return false;
    }
    if (!await canLaunchUrl(uri)) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('No app available to open the link')),
      );
      return false;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && messenger != null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No app available to open the link')),
      );
    }
    return ok;
  } catch (_) {
    messenger?.showSnackBar(
      const SnackBar(content: Text("Can't open that link")),
    );
    return false;
  }
}
