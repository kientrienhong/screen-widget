import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import 'config_store.dart';
import 'settings.dart';
import 'win_run_key.dart';

/// Size presets for "Size & crop".
class SizePreset {
  const SizePreset(this.label, this.width, this.height);
  final String label;
  final double width, height;
}

const kSizePresets = <SizePreset>[
  SizePreset('Widget', 320, 400),
  SizePreset('Portrait', 420, 640),
  SizePreset('Square', 520, 520),
  SizePreset('Landscape', 800, 500),
  SizePreset('Wide', 1100, 620),
];

const kMinWindow = Size(240, 240);

/// Native window behaviour. All calls are safe to make repeatedly.
class Desktop {
  static const appName = 'ScreenWidget';
  static const _bundleId = 'com.harley.screenwidget';

  static Future<void> applyAll(AppSettings s) async {
    await setAlwaysOnTop(s.alwaysOnTop);
    await setTransparent(s.transparent);
  }

  static Future<void> setAlwaysOnTop(bool v) => windowManager.setAlwaysOnTop(v);

  /// Click-through: when true, the window ignores the mouse and clicks reach
  /// the apps behind it. Keyboard and the global unlock shortcut still work.
  static Future<void> setClickThrough(bool v) async {
    if (v && Platform.isWindows) {
      // window_manager makes the window click-through by giving it the
      // WS_EX_LAYERED style, and Windows doesn't draw a layered window until
      // its opacity is set. Without this the window turns invisible (still in
      // the taskbar) the moment it's locked, and at start-up if it was closed
      // while locked. setOpacity(1) sets that opacity: fully visible. It runs
      // first, so the window is never layered without an opacity, not even
      // for one frame.
      await windowManager.setOpacity(1.0);
    }
    await windowManager.setIgnoreMouseEvents(v);
  }

  /// Label for the global lock/unlock shortcut.
  static String get lockShortcutLabel => Platform.isMacOS ? '⌃⌥L' : 'Ctrl+Alt+L';

  /// The window background is always clear; in normal mode the painter fills
  /// it with the scene, in transparent mode only the tree is drawn so the
  /// real desktop shows through.
  static Future<void> setTransparent(bool v) async {
    await windowManager.setBackgroundColor(Colors.transparent);
    if (Platform.isMacOS) {
      if (v) {
        await windowManager.setTitleBarStyle(TitleBarStyle.hidden, windowButtonVisibility: false);
        await _setMacClearMode(true); // borderless: no frame edge, corners or shadow
      } else {
        await _setMacClearMode(false);
        await windowManager.setTitleBarStyle(TitleBarStyle.hidden, windowButtonVisibility: true);
        await windowManager.setHasShadow(true);
      }
    } else if (Platform.isWindows) {
      if (v) {
        await windowManager.setAsFrameless(); // no border or shadow
        await windowManager.setHasShadow(false);
      } else {
        await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
        await windowManager.setHasShadow(true);
      }
    }
  }

  static const _macWindow = MethodChannel('screen_widget/window');

  static Future<void> _setMacClearMode(bool on) async {
    try {
      await _macWindow.invokeMethod('setClearMode', on);
    } on MissingPluginException {
      // Older runner without the channel: fall back to just hiding the shadow.
      await windowManager.setHasShadow(!on);
    }
  }

  /// Resize the window to exactly [w] × [h] (logical pixels), keeping it on screen.
  static Future<void> resizeTo(double w, double h) async {
    final size = Size(math.max(w, kMinWindow.width), math.max(h, kMinWindow.height));
    final wasMax = await windowManager.isMaximized();
    if (wasMax) await windowManager.unmaximize();
    final pos = await windowManager.getPosition();
    final old = await windowManager.getSize();
    await windowManager.setSize(size);
    // Keep the window's centre where it was.
    await windowManager.setPosition(Offset(
      math.max(0.0, pos.dx + (old.width - size.width) / 2),
      math.max(0.0, pos.dy + (old.height - size.height) / 2),
    ));
  }

  /// Opens a view in its own window by starting a second copy of the app.
  /// The scene and the window's id go through environment variables, which
  /// works the same on macOS and Windows.
  static Future<bool> openSceneWindow(String sceneId) =>
      _startPopout(ConfigStore.newPopoutId(), sceneId: sceneId);

  /// Reopens the pop-out windows that were open when the app last ran
  /// (skipping any that are still open).
  static Future<void> restorePopouts() async {
    for (final id in ConfigStore.savedPopoutIds()) {
      if (!ConfigStore.isPopoutRunning(id)) await _startPopout(id);
    }
  }

  static Future<bool> _startPopout(String id, {String? sceneId}) async {
    try {
      await Process.start(
        Platform.resolvedExecutable,
        const [],
        environment: {
          'SCREEN_WIDGET_SOLO': '1',
          'SCREEN_WIDGET_WINDOW': id,
          if (sceneId != null) 'SCREEN_WIDGET_SCENE': sceneId,
        },
        mode: ProcessStartMode.detached,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// True if a good part of [r] (the title-bar area) is on a connected screen,
  /// so a saved position isn't restored onto a monitor that's gone.
  static Future<bool> isOnScreen(Rect r) async {
    try {
      final grab = Rect.fromLTWH(r.left + 20, r.top, math.max(40.0, r.width - 40), 40);
      for (final d in await screenRetriever.getAllDisplays()) {
        final pos = d.visiblePosition ?? Offset.zero;
        final size = d.visibleSize ?? d.size;
        final area = (pos & size).intersect(grab);
        if (area.width >= 40 && area.height >= 20) return true;
      }
    } catch (_) {}
    return false;
  }

  /// Whether "Launch at login" is really on in the OS, or null if unknown.
  static Future<bool?> isLaunchAtLoginEnabled() async {
    try {
      if (Platform.isWindows) return WinRunKey.has(appName);
      if (Platform.isMacOS) {
        final home = Platform.environment['HOME'];
        if (home == null) return null;
        return File('$home/Library/LaunchAgents/$_bundleId.plist').exists();
      }
    } catch (_) {}
    return null;
  }

  /// Start the app when the user logs in.
  /// Windows: HKCU Run key. macOS: a LaunchAgent in ~/Library/LaunchAgents.
  static Future<bool> setLaunchAtLogin(bool enable) async {
    final exe = Platform.resolvedExecutable;
    try {
      if (Platform.isWindows) {
        return enable ? WinRunKey.set(appName, '"$exe"') : WinRunKey.remove(appName);
      }
      if (Platform.isMacOS) {
        final home = Platform.environment['HOME'];
        if (home == null) return false;
        final file = File('$home/Library/LaunchAgents/$_bundleId.plist');
        if (!enable) {
          if (await file.exists()) await file.delete();
          return true;
        }
        await file.parent.create(recursive: true);
        await file.writeAsString('''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$_bundleId</string>
  <key>ProgramArguments</key><array><string>$exe</string></array>
  <key>RunAtLoad</key><true/>
</dict>
</plist>
''');
        return true;
      }
    } catch (_) {}
    return false;
  }
}
