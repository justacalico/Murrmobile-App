import 'package:flutter/material.dart';

/// macOS-style window title bar: traffic light buttons on the left, a
/// centered window title, and a drag/double-click area behind it all.
class WindowTitleBar extends StatefulWidget {
  const WindowTitleBar({
    super.key,
    required this.title,
    this.isFocused = true,
    this.showControls = true,
    this.onDragStart,
    this.onMinimize,
    this.onToggleMaximize,
    this.onClose,
  });

  final String title;

  /// Whether the window is focused. Unfocused windows dim the title and
  /// turn the traffic lights grey, like on macOS.
  final bool isFocused;

  /// Whether to draw the in-app traffic light buttons. macOS keeps its
  /// native buttons over the hidden title bar, so they are skipped there.
  final bool showControls;

  final VoidCallback? onDragStart;
  final VoidCallback? onMinimize;
  final VoidCallback? onToggleMaximize;
  final VoidCallback? onClose;

  @override
  State<WindowTitleBar> createState() => _WindowTitleBarState();
}

class _WindowTitleBarState extends State<WindowTitleBar> {
  bool _hoveringControls = false;
  DateTime? _lastTap;

  // DoubleTapGestureRecognizer would hold single taps of the traffic light
  // buttons in the gesture arena until the timeout expires, making them feel
  // laggy. Counting taps by hand keeps them instant; taps on the buttons are
  // claimed by their own recognizer and never reach here.
  void _handleTap() {
    final now = DateTime.now();
    final last = _lastTap;
    if (last != null &&
        now.difference(last) < const Duration(milliseconds: 350)) {
      _lastTap = null;
      widget.onToggleMaximize?.call();
    } else {
      _lastTap = now;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleColor = widget.isFocused
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurface.withValues(alpha: 0.4);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: widget.onDragStart == null
          ? null
          : (_) => widget.onDragStart!(),
      onTap: widget.onToggleMaximize == null ? null : _handleTap,
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            bottom: BorderSide(color: theme.dividerColor, width: 0.5),
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: titleColor,
                ),
              ),
            ),
            if (widget.showControls)
              Positioned(
                left: 16,
                top: 0,
                bottom: 0,
                child: MouseRegion(
                  onEnter: (_) => setState(() => _hoveringControls = true),
                  onExit: (_) => setState(() => _hoveringControls = false),
                  child: Row(
                    children: [
                      _TrafficLight(
                        key: const ValueKey('window-close'),
                        color: const Color(0xFFFF5F57),
                        icon: Icons.close,
                        label: 'Close window',
                        showIcon: _hoveringControls,
                        isFocused: widget.isFocused,
                        onPressed: widget.onClose,
                      ),
                      _TrafficLight(
                        key: const ValueKey('window-minimize'),
                        color: const Color(0xFFFEBC2E),
                        icon: Icons.remove,
                        label: 'Minimize window',
                        showIcon: _hoveringControls,
                        isFocused: widget.isFocused,
                        onPressed: widget.onMinimize,
                      ),
                      _TrafficLight(
                        key: const ValueKey('window-maximize'),
                        color: const Color(0xFF28C840),
                        icon: Icons.add,
                        label: 'Maximize window',
                        showIcon: _hoveringControls,
                        isFocused: widget.isFocused,
                        onPressed: widget.onToggleMaximize,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TrafficLight extends StatelessWidget {
  const _TrafficLight({
    super.key,
    required this.color,
    required this.icon,
    required this.label,
    required this.showIcon,
    required this.isFocused,
    this.onPressed,
  });

  final Color color;
  final IconData icon;
  final String label;
  final bool showIcon;
  final bool isFocused;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onPressed,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: SizedBox(
            width: 20,
            height: 36,
            child: Center(
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isFocused ? color : const Color(0xFF6E6E6E),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black26, width: 0.5),
                ),
                child: showIcon && isFocused
                    ? Icon(icon, size: 9, color: Colors.black54)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
