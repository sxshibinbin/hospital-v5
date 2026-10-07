import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum AppMessageTone { info, success, warning, error }

final class AppMessage {
  const AppMessage._();

  static OverlayEntry? _currentEntry;

  static void showInfo(BuildContext context, String message) {
    _show(context, message, AppMessageTone.info);
  }

  static void showSuccess(BuildContext context, String message) {
    _show(context, message, AppMessageTone.success);
  }

  static void showWarning(BuildContext context, String message) {
    _show(context, message, AppMessageTone.warning);
  }

  static void showError(BuildContext context, String message) {
    _show(context, message, AppMessageTone.error);
  }

  static void _show(BuildContext context, String message, AppMessageTone tone) {
    final overlayState = Overlay.maybeOf(context, rootOverlay: true);
    if (overlayState == null) {
      return;
    }

    _currentEntry?.remove();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) {
        final topInset = MediaQuery.paddingOf(overlayContext).top + 12;
        return Positioned(
          top: topInset,
          left: 20,
          right: 20,
          child: _AppMessageOverlay(
            message: message,
            tone: tone,
            onDismissed: () {
              if (identical(_currentEntry, entry)) {
                _currentEntry = null;
              }
              entry.remove();
            },
          ),
        );
      },
    );

    _currentEntry = entry;
    overlayState.insert(entry);
  }
}

class _AppMessageOverlay extends StatefulWidget {
  const _AppMessageOverlay({
    required this.message,
    required this.tone,
    required this.onDismissed,
  });

  final String message;
  final AppMessageTone tone;
  final VoidCallback onDismissed;

  @override
  State<_AppMessageOverlay> createState() => _AppMessageOverlayState();
}

class _AppMessageOverlayState extends State<_AppMessageOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    reverseDuration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  late final Animation<Offset> _offset =
      Tween<Offset>(begin: const Offset(0, -0.08), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ),
      );

  Timer? _dismissTimer;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    unawaited(_controller.forward());
    _dismissTimer = Timer(const Duration(milliseconds: 2600), _dismiss);
  }

  Future<void> _dismiss() async {
    if (_isDismissing) {
      return;
    }

    _isDismissing = true;
    _dismissTimer?.cancel();
    await _controller.reverse();
    widget.onDismissed();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _offset,
        child: GestureDetector(
          onTap: _dismiss,
          behavior: HitTestBehavior.opaque,
          child: _AppMessageCard(message: widget.message, tone: widget.tone),
        ),
      ),
    );
  }
}

class _AppMessageCard extends StatelessWidget {
  const _AppMessageCard({required this.message, required this.tone});

  final String message;
  final AppMessageTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = tone.colors;

    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors.backgroundGradient,
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: colors.borderColor),
          boxShadow: const [
            BoxShadow(
              color: Color(0x180F0A36),
              blurRadius: 28,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors.iconGradient,
                  ),
                ),
                child: Icon(colors.icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.primaryDarkColor,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.close_rounded,
                color: AppTheme.primaryDarkColor.withValues(alpha: 0.46),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension on AppMessageTone {
  _AppMessageToneColors get colors {
    switch (this) {
      case AppMessageTone.info:
        return const _AppMessageToneColors(
          icon: Icons.info_rounded,
          backgroundGradient: [Color(0xFFFFFFFF), Color(0xFFF4F1FF)],
          iconGradient: [Color(0xFFCBBEFF), AppTheme.primaryColor],
          borderColor: Color(0xFFE0D9FF),
        );
      case AppMessageTone.success:
        return const _AppMessageToneColors(
          icon: Icons.check_rounded,
          backgroundGradient: [Color(0xFFFFFFFF), Color(0xFFF1FFF8)],
          iconGradient: [Color(0xFF73DEAA), Color(0xFF22A06B)],
          borderColor: Color(0xFFD2F3E3),
        );
      case AppMessageTone.warning:
        return const _AppMessageToneColors(
          icon: Icons.priority_high_rounded,
          backgroundGradient: [Color(0xFFFFFFFF), Color(0xFFFFF6EB)],
          iconGradient: [Color(0xFFFFCC80), Color(0xFFFF9F43)],
          borderColor: Color(0xFFFFE3BF),
        );
      case AppMessageTone.error:
        return const _AppMessageToneColors(
          icon: Icons.close_rounded,
          backgroundGradient: [Color(0xFFFFFFFF), Color(0xFFFFF0F4)],
          iconGradient: [Color(0xFFFF9BB0), Color(0xFFE5486D)],
          borderColor: Color(0xFFFFD1DC),
        );
    }
  }
}

class _AppMessageToneColors {
  const _AppMessageToneColors({
    required this.icon,
    required this.backgroundGradient,
    required this.iconGradient,
    required this.borderColor,
  });

  final IconData icon;
  final List<Color> backgroundGradient;
  final List<Color> iconGradient;
  final Color borderColor;
}
