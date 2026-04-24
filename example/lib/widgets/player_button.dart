import 'package:flutter/material.dart';

/// A filled (play/pause) or tonal (prev/next) action button.
/// - All buttons: expand on press with spring release (width animation).
class PlayerActionButton extends StatefulWidget {
  final VoidCallback? onTap;
  final IconData icon;
  final bool isFilled;
  final double? normalWidth;
  final double? pressedWidth;
  final bool squeezed; // true = shrunken by play/pause press
  final void Function(bool)? onPressChanged;
  final ColorScheme colorScheme;

  const PlayerActionButton({
    super.key,
    this.onTap,
    required this.icon,
    required this.isFilled,
    required this.normalWidth,
    required this.pressedWidth,
    this.squeezed = false,
    this.onPressChanged,
    required this.colorScheme,
  });

  @override
  State<PlayerActionButton> createState() => _PlayerActionButtonState();
}

class _PlayerActionButtonState extends State<PlayerActionButton> {
  bool _hovered = false;
  bool _pressed = false;

  void _setPressed(bool v) {
    if (v) {
      Future.microtask(() {
        widget.onPressChanged?.call(true);
        if (mounted) setState(() => _pressed = true);
      });
    } else {
      Future.microtask(() {
        widget.onPressChanged?.call(false);
        if (mounted) setState(() => _pressed = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.colorScheme;
    final bg = widget.isFilled ? cs.primary : cs.secondaryContainer;
    final fg = widget.isFilled ? cs.onPrimary : cs.onSecondaryContainer;
    final radius = _hovered ? 16.0 : 32.0;
    final isExpanded = widget.normalWidth == null;

    final isEnabled = widget.onTap != null;
    final button = MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = isEnabled),
      onExit: (_) => setState(() => _hovered = false),
      child: Listener(
        onPointerDown: isEnabled ? (_) => _setPressed(true) : null,
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: isEnabled ? 1.0 : 0.5,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(radius),
              ),
              child: Center(
                child: Icon(widget.icon, color: fg, size: 28),
              ),
            ),
          ),
        ),
      ),
    );

    if (isExpanded) return button;

    final nw = widget.normalWidth ?? 0.0;
    final pw = widget.pressedWidth ?? 0.0;

    final targetW = _pressed
        ? pw
        : widget.squeezed
            ? nw - 10
            : nw;
    final dur = (_pressed || widget.squeezed)
        ? const Duration(milliseconds: 80)
        : const Duration(milliseconds: 600);
    final crv = (_pressed || widget.squeezed) ? Curves.easeOut : Curves.elasticOut;

    return TweenAnimationBuilder<double>(
      tween: Tween(end: targetW),
      duration: dur,
      curve: crv,
      builder: (context, w, child) => SizedBox(width: w, child: child),
      child: button,
    );
  }
}

/// A toggle button (repeat / shuffle) with outlined idle state and tonal
/// active state. Width spring-animates on press.
class PlayerToggleButton extends StatefulWidget {
  final bool isOn;
  final bool enabled;
  final VoidCallback onTap;
  final IconData icon;
  final double normalWidth;
  final double pressedWidth;
  final ColorScheme colorScheme;

  const PlayerToggleButton({
    super.key,
    required this.isOn,
    required this.enabled,
    required this.onTap,
    required this.icon,
    required this.normalWidth,
    required this.pressedWidth,
    required this.colorScheme,
  });

  @override
  State<PlayerToggleButton> createState() => _PlayerToggleButtonState();
}

class _PlayerToggleButtonState extends State<PlayerToggleButton> {
  bool _hovered = false;
  bool _pressed = false;

  void _setPressed(bool v) {
    if (v) {
      Future.microtask(() {
        if (mounted) setState(() => _pressed = true);
      });
    } else {
      Future.microtask(() {
        if (mounted) setState(() => _pressed = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.colorScheme;
    final isOn = widget.isOn && widget.enabled;
    final radius = _hovered ? 16.0 : 32.0;

    final bg = isOn ? cs.secondaryContainer : Colors.transparent;
    final fg = isOn
        ? cs.secondary
        : (widget.enabled ? cs.onSurfaceVariant : cs.onSurface.withValues(alpha: 0.38));
    final border = isOn
        ? BorderSide.none
        : BorderSide(
            color: cs.outline.withValues(alpha: widget.enabled ? 0.5 : 0.2),
            width: 1.5,
          );

    final content = MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (widget.enabled) setState(() => _hovered = true);
      },
      onExit: (_) => setState(() => _hovered = false),
      child: Listener(
        onPointerDown: widget.enabled ? (_) => _setPressed(true) : null,
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        child: GestureDetector(
          onTap: widget.enabled ? widget.onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(radius),
              border: Border.fromBorderSide(border),
            ),
            child: Center(
              child: Icon(widget.icon, color: fg, size: 22),
            ),
          ),
        ),
      ),
    );

    return TweenAnimationBuilder<double>(
      tween: Tween(
        end: _pressed ? widget.pressedWidth : widget.normalWidth,
      ),
      duration: _pressed ? const Duration(milliseconds: 80) : const Duration(milliseconds: 600),
      curve: _pressed ? Curves.easeOut : Curves.elasticOut,
      builder: (context, w, child) => SizedBox(width: w, child: child),
      child: content,
    );
  }
}
