import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

/// Platform-aware page transitions that feel native.
///
/// - iOS / macOS: Cupertino slide-from-right
/// - Android: Custom fade + slide that feels more premium than default Material
/// - Web / other: Subtle fade
class AppPageRoute<T> extends PageRouteBuilder<T> {
  AppPageRoute({
    required WidgetBuilder builder,
    RouteSettings? settings,
    bool fullscreenDialog = false,
    bool maintainState = true,
  }) : super(
          settings: settings,
          fullscreenDialog: fullscreenDialog,
          maintainState: maintainState,
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionsBuilder: _transitionsBuilder(),
        );

  static RouteTransitionsBuilder _transitionsBuilder() {
    // coverage:ignore-start
    // Use Cupertino on Apple platforms for native feel.
    // Platform.isIOS/isMacOS read the real OS; tests always run elsewhere.
    if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
      return (context, animation, secondaryAnimation, child) {
        return CupertinoPageTransition(
          primaryRouteAnimation: animation,
          secondaryRouteAnimation: secondaryAnimation,
          linearTransition: false,
          child: child,
        );
      };
    }
    // coverage:ignore-end

    // Android / Linux / Windows / Web: modern shared-axis-like slide + fade
    return (context, animation, secondaryAnimation, child) {
      const begin = Offset(0.08, 0.0);
      const end = Offset.zero;
      final tween = Tween(begin: begin, end: end).chain(
        CurveTween(curve: Curves.easeOutCubic),
      );
      final fadeTween = Tween<double>(begin: 0.0, end: 1.0).chain(
        CurveTween(curve: Curves.easeOut),
      );

      return FadeTransition(
        opacity: animation.drive(fadeTween),
        child: SlideTransition(
          position: animation.drive(tween),
          child: child,
        ),
      );
    };
  }
}

/// Simpler helper to push a page with the app's custom transition.
Future<T?> pushPage<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool fullscreenDialog = false,
}) {
  return Navigator.of(context).push<T>(
    AppPageRoute<T>(
      builder: builder,
      fullscreenDialog: fullscreenDialog,
    ),
  );
}

/// Push and replace current page.
Future<T?> pushReplacementPage<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return Navigator.of(context).pushReplacement(
    AppPageRoute<T>(
      builder: builder,
    ),
  );
}

/// Push and remove all previous routes.
Future<T?> pushAndRemoveUntilPage<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  required RoutePredicate predicate,
}) {
  return Navigator.of(context).pushAndRemoveUntil(
    AppPageRoute<T>(builder: builder),
    predicate,
  );
}
