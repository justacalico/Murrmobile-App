import 'package:flutter/foundation.dart';

const logNetwork = bool.fromEnvironment('LOG_NETWORK');

void netLog(String message) {
  if (logNetwork) debugPrint(message);
}
