import 'package:flutter/material.dart';

class AppToast {
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();
  static OverlayEntry? _currentEntry;

  static const _successBackground = Color(0xFFDCFCE7);
  static const _successForeground = Color(0xFF166534);
  static const _successBorder = Color(0xFF86EFAC);
  static const _errorBackground = Color(0xFFFEE2E2);
  static const _errorForeground = Color(0xFF991B1B);
  static const _errorBorder = Color(0xFFFCA5A5);
  static const _infoBackground = Color(0xFFDBEAFE);
  static const _infoForeground = Color(0xFF1E40AF);
  static const _infoBorder = Color(0xFF93C5FD);

  static void success(BuildContext context, String message) {
    _show(
      context,
      message,
      icon: Icons.check_circle_outline,
      backgroundColor: _successBackground,
      foregroundColor: _successForeground,
      borderColor: _successBorder,
    );
  }

  static void error(BuildContext context, Object message) {
    _show(
      context,
      message.toString(),
      icon: Icons.error_outline,
      backgroundColor: _errorBackground,
      foregroundColor: _errorForeground,
      borderColor: _errorBorder,
    );
  }

  static void info(BuildContext context, String message) {
    _show(
      context,
      message,
      icon: Icons.info_outline,
      backgroundColor: _infoBackground,
      foregroundColor: _infoForeground,
      borderColor: _infoBorder,
    );
  }

  static void _show(
    BuildContext context,
    String message, {
    required IconData icon,
    required Color backgroundColor,
    required Color foregroundColor,
    required Color borderColor,
  }) {
    final rootContext = messengerKey.currentContext ?? context;
    final overlay = Overlay.maybeOf(rootContext, rootOverlay: true) ??
        Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    if (_currentEntry?.mounted ?? false) {
      _currentEntry?.remove();
    }
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) {
        final media = MediaQuery.of(context);
        final top = media.padding.top + 10;
        return Positioned(
          top: top,
          right: 10,
          left: media.size.width < 360 ? 48 : null,
          child: Align(
            alignment: Alignment.topRight,
            child: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 330),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A111827),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: foregroundColor, size: 22),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: foregroundColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    _currentEntry = entry;
    overlay.insert(entry);
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (_currentEntry == entry && entry.mounted) {
        entry.remove();
        _currentEntry = null;
      }
    });
  }
}
