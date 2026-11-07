import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../assets_loader.dart';
import '../desktop.dart';
import '../engine/scene_painter.dart';
import '../engine/world.dart';
import '../scenes.dart';
import '../settings.dart';
import 'settings_panel.dart';
import 'title_bar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.settings, required this.assets});
  final AppSettings settings;
  final SceneAssets assets;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late final World _world = World(widget.settings, widget.assets);
  late final Ticker _ticker;
  final _focus = FocusNode();
  Duration _last = Duration.zero;

  bool _panelOpen = false;
  bool _hover = false;
  String? _toast;
  Timer? _toastTimer;

  double _fpsAcc = 0;
  int _fpsFrames = 0;
  String _fpsText = '';

  AppSettings get s => widget.settings;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    s.addListener(_onSettings);
  }

  @override
  void dispose() {
    _ticker.dispose();
    s.removeListener(_onSettings);
    _toastTimer?.cancel();
    _focus.dispose();
    _world.dispose();
    super.dispose();
  }

  void _onSettings() => setState(() {});

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _world.step(dt);
    _world.frame();
    if (s.showFps) {
      _fpsAcc += dt;
      _fpsFrames++;
      if (_fpsAcc > 0.5) {
        setState(() => _fpsText = '${(_fpsFrames / _fpsAcc).round()} fps · ${_world.parts.length + _world.landed.length} particles');
        _fpsAcc = 0;
        _fpsFrames = 0;
      }
    }
  }

  // ---------------- actions ----------------

  void _setPanel(bool open) => setState(() => _panelOpen = open);

  void _showToast(String msg) {
    _toastTimer?.cancel();
    setState(() => _toast = msg);
    _toastTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  void _setScene(String id) {
    if (id == s.scene) return;
    _world.setScene(id);
    s.update((x) => x.scene = id);
  }

  Future<void> _popOut(String id) async {
    final ok = await Desktop.openSceneWindow(id);
    _showToast(ok ? 'Opened “${sceneById(id)!.name}” in a new window' : 'Could not open a new window');
  }

  Future<void> _setTransparent(bool v) async {
    s.update((x) => x.transparent = v);
    _world.clearLanded();
    await Desktop.setTransparent(v);
    _showToast(v ? 'Transparent background — only the tree and its animation' : 'Scene background on');
  }

  Future<void> _setAlwaysOnTop(bool v) async {
    s.update((x) => x.alwaysOnTop = v);
    await Desktop.setAlwaysOnTop(v);
  }

  Future<void> _setLaunchAtLogin(bool v) async {
    final ok = await Desktop.setLaunchAtLogin(v);
    if (ok) {
      s.update((x) => x.launchAtLogin = v);
    } else {
      _showToast('Could not change launch at login');
    }
  }

  Future<void> _resize(double w, double h) async {
    s.update((x) {
      x.viewWidth = w;
      x.viewHeight = h;
    });
    await Desktop.resizeTo(w, h);
    _showToast('View cropped to ${w.round()} × ${h.round()}');
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    // Don't steal keys from the size text fields.
    final primary = FocusManager.instance.primaryFocus;
    if (primary != null && primary != _focus && primary.context?.findAncestorWidgetOfExactType<EditableText>() != null) {
      return KeyEventResult.ignored;
    }
    final k = e.logicalKey;
    final digits = [LogicalKeyboardKey.digit1, LogicalKeyboardKey.digit2, LogicalKeyboardKey.digit3, LogicalKeyboardKey.digit4, LogicalKeyboardKey.digit5];
    final i = digits.indexOf(k);
    if (i >= 0 && i < kScenes.length) {
      _setScene(kScenes[i].id);
    } else if (k == LogicalKeyboardKey.keyT) {
      _setTransparent(!s.transparent);
    } else if (k == LogicalKeyboardKey.comma) {
      _setPanel(!_panelOpen);
    } else if (k == LogicalKeyboardKey.keyN) {
      _popOut(s.scene);
    } else if (k == LogicalKeyboardKey.escape) {
      _setPanel(false);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  // ---------------- build ----------------

  @override
  Widget build(BuildContext context) {
    final sc = sceneById(s.scene) ?? kScenes.first;
    final transparent = s.transparent;
    const panelW = 320.0;

    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: LayoutBuilder(builder: (context, box) {
          final size = box.biggest;
          Widget body = Stack(children: [
            // Scene — drag anywhere to move the window, right-click for settings.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  _focus.requestFocus();
                  if (_panelOpen) _setPanel(false);
                },
                onSecondaryTap: () => _setPanel(true),
                onPanStart: (_) => windowManager.startDragging(),
                child: RepaintBoundary(child: CustomPaint(painter: ScenePainter(_world), size: Size.infinite)),
              ),
            ),

            // Title bar (fades out in transparent mode until hovered).
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: transparent && !_hover && !_panelOpen ? 0 : 1,
                duration: const Duration(milliseconds: 250),
                child: SceneTitleBar(
                  title: 'Screen Widget',
                  subtitle: sc.name,
                  transparent: transparent,
                  panelOpen: _panelOpen,
                  onSettings: () => _setPanel(!_panelOpen),
                  onPopOut: () => _popOut(s.scene),
                  onTransparent: () => _setTransparent(!transparent),
                ),
              ),
            ),

            // Settings panel slides in from the right.
            AnimatedPositioned(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              top: SceneTitleBar.height,
              bottom: 0,
              width: panelW,
              right: _panelOpen ? 0 : -panelW - 20,
              child: IgnorePointer(
                ignoring: !_panelOpen,
                child: SettingsPanel(
                  settings: s,
                  assets: widget.assets,
                  windowSize: size,
                  onClose: () => _setPanel(false),
                  onScene: _setScene,
                  onPopOut: _popOut,
                  onTransparent: _setTransparent,
                  onAlwaysOnTop: _setAlwaysOnTop,
                  onLaunchAtLogin: _setLaunchAtLogin,
                  onResize: _resize,
                ),
              ),
            ),

            if (s.showFps && _fpsText.isNotEmpty)
              Positioned(
                left: 12,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0x59000000), borderRadius: BorderRadius.circular(6)),
                  child: Text(_fpsText, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ),

            if (_toast != null)
              Positioned(
                top: SceneTitleBar.height + 10,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xDB191E2D), borderRadius: BorderRadius.circular(9)),
                    child: Text(_toast!, style: const TextStyle(color: Colors.white, fontSize: 12.5)),
                  ),
                ),
              ),

            // Faint outline on hover so the transparent window can be found.
            if (transparent)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _hover ? 1 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x8CFFFFFF), width: 1.5),
                      ),
                    ),
                  ),
                ),
              ),
          ]);

          // Normal mode: rounded window. Transparent mode: nothing but the tree.
          if (!transparent) {
            body = ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ColoredBox(color: const Color(0xFF0B0F1E), child: body),
            );
          }
          return body;
        }),
      ),
    );
  }
}
