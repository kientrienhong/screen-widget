import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'controls.dart';

/// Custom title bar drawn over the scene (the native one is hidden).
/// macOS keeps its native traffic lights on the left; Windows gets
/// minimise / maximise / close on the right. In transparent mode the native
/// macOS buttons are hidden, so small close / minimise buttons are drawn instead.
class SceneTitleBar extends StatelessWidget {
  const SceneTitleBar({
    super.key,
    required this.title,
    required this.subtitle,
    required this.transparent,
    required this.panelOpen,
    required this.onSettings,
    required this.onPopOut,
    required this.onTransparent,
    required this.onLock,
  });

  final String title, subtitle;
  final bool transparent, panelOpen;
  final VoidCallback onSettings, onPopOut, onTransparent, onLock;

  static const height = 40.0;

  @override
  Widget build(BuildContext context) {
    final mac = Platform.isMacOS;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => windowManager.startDragging(),
      onDoubleTap: () async {
        if (await windowManager.isMaximized()) {
          await windowManager.unmaximize();
        } else {
          await windowManager.maximize();
        }
      },
      child: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: height,
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x80FFFFFF), Color(0x4DFFFFFF)]),
              border: Border(bottom: BorderSide(color: Color(0x14000000), width: 0.5)),
            ),
            child: Row(children: [
              if (mac && !transparent) const SizedBox(width: 78), // native traffic lights
              if (mac && transparent) ...[
                const SizedBox(width: 12),
                _Dot(color: const Color(0xFFFF5F57), tooltip: 'Close', onTap: () => windowManager.close()),
                const SizedBox(width: 8),
                _Dot(color: const Color(0xFFFEBC2E), tooltip: 'Minimise', onTap: () => windowManager.minimize()),
                const SizedBox(width: 14),
              ],
              if (!mac) ...[
                const SizedBox(width: 12),
                Container(width: 16, height: 16, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(4))),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    TextSpan(text: '  —  $subtitle', style: const TextStyle(fontWeight: FontWeight.w400, color: kMuted)),
                  ]),
                  textAlign: mac ? TextAlign.center : TextAlign.start,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: kText),
                ),
              ),
              _IconBtn(icon: Icons.lock_outline, tooltip: 'Lock — clicks go to the apps behind (L)', onTap: onLock),
              _IconBtn(icon: Icons.layers_clear_outlined, tooltip: 'Transparent background (T)', on: transparent, onTap: onTransparent),
              _IconBtn(icon: Icons.open_in_new, tooltip: 'Open this view in a new window (N)', onTap: onPopOut),
              _IconBtn(icon: Icons.settings_outlined, tooltip: 'Settings (,)', on: panelOpen, onTap: onSettings),
              if (mac) const SizedBox(width: 8),
              if (!mac) ...[
                const SizedBox(width: 6),
                _CaptionBtn(icon: Icons.remove, onTap: () => windowManager.minimize()),
                _CaptionBtn(
                  icon: Icons.crop_square,
                  onTap: () async {
                    if (await windowManager.isMaximized()) {
                      await windowManager.unmaximize();
                    } else {
                      await windowManager.maximize();
                    }
                  },
                ),
                _CaptionBtn(icon: Icons.close, close: true, onTap: () => windowManager.close()),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.tooltip, required this.onTap, this.on = false});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool on;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: Material(
        color: on ? const Color(0x1A000000) : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7),
          child: SizedBox(width: 32, height: 28, child: Icon(icon, size: 17, color: const Color(0xC0141A28))),
        ),
      ),
    );
  }
}

class _CaptionBtn extends StatefulWidget {
  const _CaptionBtn({required this.icon, required this.onTap, this.close = false});
  final IconData icon;
  final VoidCallback onTap;
  final bool close;

  @override
  State<_CaptionBtn> createState() => _CaptionBtnState();
}

class _CaptionBtnState extends State<_CaptionBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 46,
          height: SceneTitleBar.height,
          color: _hover ? (widget.close ? const Color(0xFFE81123) : const Color(0x14000000)) : Colors.transparent,
          child: Icon(widget.icon, size: 16, color: _hover && widget.close ? Colors.white : const Color(0xC0141A28)),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.tooltip, required this.onTap});
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      ),
    );
  }
}
