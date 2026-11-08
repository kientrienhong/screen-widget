import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import '../assets_loader.dart';
import '../desktop.dart';
import '../engine/scene_painter.dart';
import '../engine/world.dart';
import '../i18n.dart';
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

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin, WindowListener {
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

  // ---- Lock (click-through) ----
  // While locked the window ignores the mouse. To unlock: the global shortcut,
  // or rest the cursor on the top-right corner until the Unlock button appears.
  HotKey? _lockKey;
  Timer? _lockPoll;
  bool _pollBusy = false;
  bool _cursorInside = false;
  bool _unlockArmed = false;
  double _armProgress = 0;
  static const _armSeconds = 0.6;
  static const _pollMs = 150;

  AppSettings get s => widget.settings;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    s.addListener(_onSettings);
    _registerLockShortcut();
    windowManager.addListener(this);
    windowManager.setPreventClose(true); // so onWindowClose can save first
    if (s.locked) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _setLocked(true));
    }
  }

  // ---- Remember the window's place ----
  Timer? _boundsTimer;

  // "move"/"resize" also fire for changes the app makes itself (crop presets);
  // "moved"/"resized" fire when the user finishes dragging. Saving is debounced.
  @override
  void onWindowMove() => _queueSaveBounds();

  @override
  void onWindowMoved() => _queueSaveBounds();

  @override
  void onWindowResize() => _queueSaveBounds();

  @override
  void onWindowResized() => _queueSaveBounds();

  void _queueSaveBounds() {
    _boundsTimer?.cancel();
    _boundsTimer = Timer(const Duration(milliseconds: 300), _saveBounds);
  }

  Future<void> _saveBounds() async {
    try {
      // A minimised or maximised window has no useful "normal" position to restore.
      if (await windowManager.isMinimized() || await windowManager.isMaximized()) return;
      s.saveWindowBounds(await windowManager.getBounds());
    } catch (_) {}
  }

  /// Native close (red button, Alt+F4, Cmd+W): close-prevention sends it here.
  @override
  void onWindowClose() => _closeWindow();

  bool _closing = false;

  /// Save, then end this window's process. Every close goes through here, so
  /// it works the same for normal, borderless and transparent windows.
  Future<void> _closeWindow() async {
    if (_closing) return;
    _closing = true;
    try {
      _boundsTimer?.cancel();
      await _saveBounds().timeout(const Duration(seconds: 1), onTimeout: () {});
      if (s.solo) {
        s.forget(); // closed on purpose: don't reopen this pop-out next time
      } else {
        s.flush();
      }
    } catch (_) {
      // Never let a failed save keep the window open.
    } finally {
      await windowManager.destroy();
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _boundsTimer?.cancel();
    _ticker.dispose();
    s.removeListener(_onSettings);
    _toastTimer?.cancel();
    _lockPoll?.cancel();
    final key = _lockKey;
    if (key != null) hotKeyManager.unregister(key);
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
    _showToast(ok ? tr('Opened “{0}” in a new window', [sceneName(sceneById(id)!)]) : tr('Could not open a new window'));
  }

  Future<void> _setTransparent(bool v) async {
    s.update((x) => x.transparent = v);
    _world.clearLanded();
    await Desktop.setTransparent(v);
    _showToast(v ? tr('Transparent background — only the tree and its animation') : tr('Scene background on'));
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
      _showToast(tr('Could not change launch at login'));
    }
  }

  Future<void> _registerLockShortcut() async {
    try {
      final key = HotKey(
        key: PhysicalKeyboardKey.keyL,
        modifiers: [HotKeyModifier.control, HotKeyModifier.alt],
        scope: HotKeyScope.system,
      );
      if (!s.solo) await hotKeyManager.unregisterAll(); // clean up after hot restart
      await hotKeyManager.register(key, keyDownHandler: (_) => _setLocked(!s.locked));
      _lockKey = key;
    } catch (_) {
      // Another Screen Widget window may own the shortcut already; hover-to-unlock still works.
    }
  }

  Future<void> _setLocked(bool v) async {
    if (v) _setPanel(false);
    if (s.locked != v) s.update((x) => x.locked = v);
    _unlockArmed = false;
    _armProgress = 0;
    _cursorInside = false;
    _lockPoll?.cancel();
    _lockPoll = null;
    await Desktop.setClickThrough(v);
    if (v) _lockPoll = Timer.periodic(const Duration(milliseconds: _pollMs), (_) => _pollCursor());
    _showToast(v
        ? tr('Locked — clicks go to the apps behind. Unlock: {0} or hover the top-right corner', [Desktop.lockShortcutLabel])
        : tr('Unlocked'));
  }

  /// While locked, watch the cursor (the window itself gets no mouse events):
  /// show the lock badge when the cursor is over the window, and after a short
  /// hover on the top-right corner turn mouse input back on so Unlock can be clicked.
  Future<void> _pollCursor() async {
    if (_pollBusy || !s.locked || !mounted) return;
    _pollBusy = true;
    try {
      final b = await windowManager.getBounds();
      final p = await screenRetriever.getCursorScreenPoint();
      final inside = b.contains(p);
      final zoneW = _unlockArmed ? 150.0 : 64.0;
      final over = Rect.fromLTWH(b.right - zoneW, b.top, zoneW, 64).contains(p);
      var armed = _unlockArmed;
      var progress = _armProgress;
      if (over) {
        progress = math.min(1.0, progress + _pollMs / 1000 / _armSeconds);
        if (progress >= 1 && !armed) {
          armed = true;
          await Desktop.setClickThrough(false);
        }
      } else {
        progress = 0;
        if (armed) {
          armed = false;
          await Desktop.setClickThrough(true);
        }
      }
      if (mounted && (inside != _cursorInside || armed != _unlockArmed || progress != _armProgress)) {
        setState(() {
          _cursorInside = inside;
          _unlockArmed = armed;
          _armProgress = progress;
        });
      }
    } catch (_) {
      // Ignore a missed poll; the next one retries.
    } finally {
      _pollBusy = false;
    }
  }

  Future<void> _resize(double w, double h) async {
    s.update((x) {
      x.viewWidth = w;
      x.viewHeight = h;
    });
    await Desktop.resizeTo(w, h);
    _queueSaveBounds();
    _showToast(tr('View cropped to {0} × {1}', [w.round(), h.round()]));
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
    } else if (k == LogicalKeyboardKey.keyL) {
      _setLocked(!s.locked);
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
                opacity: s.locked || (transparent && !_hover && !_panelOpen) ? 0 : 1,
                duration: const Duration(milliseconds: 250),
                child: SceneTitleBar(
                  title: 'Screen Widget',
                  subtitle: sceneName(sc),
                  transparent: transparent,
                  panelOpen: _panelOpen,
                  onLock: () => _setLocked(true),
                  onClose: _closeWindow,
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
                  onLock: _setLocked,
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

            // Lock badge: invisible until the cursor is over the window.
            if (s.locked)
              Positioned(
                top: 10,
                right: 10,
                child: AnimatedOpacity(
                  opacity: _unlockArmed ? 1 : (_cursorInside ? 0.6 : 0),
                  duration: const Duration(milliseconds: 200),
                  child: _unlockArmed
                      ? Material(
                          color: const Color(0xE6191E2D),
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            onTap: () => _setLocked(false),
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.lock_open, size: 16, color: Colors.white),
                                const SizedBox(width: 6),
                                Text(tr('Unlock'), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                              ]),
                            ),
                          ),
                        )
                      : SizedBox(
                          width: 40,
                          height: 40,
                          child: Stack(alignment: Alignment.center, children: [
                            SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(
                                value: _armProgress,
                                strokeWidth: 2.5,
                                color: Colors.white,
                                backgroundColor: const Color(0x33FFFFFF),
                              ),
                            ),
                            Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(color: Color(0x8C000000), shape: BoxShape.circle),
                              child: const Icon(Icons.lock, size: 16, color: Colors.white),
                            ),
                          ]),
                        ),
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
