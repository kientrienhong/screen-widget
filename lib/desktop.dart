import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'settings.dart';

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

  /// The window background is always clear; in normal mode the painter fills
  /// it with the scene, in transparent mode only the tree is drawn so the
  /// real desktop shows through.
  static Future<void> setTransparent(bool v) async {
    await windowManager.setBackgroundColor(Colors.transparent);
    await windowManager.setHasShadow(!v);
    if (Platform.isMacOS) {
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden, windowButtonVisibility: !v);
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
  /// The scene is passed through environment variables, which works the same
  /// on macOS and Windows.
  static Future<bool> openSceneWindow(String sceneId) async {
    try {
      await Process.start(
        Platform.resolvedExecutable,
        const [],
        environment: {'SCREEN_WIDGET_SOLO': '1', 'SCREEN_WIDGET_SCENE': sceneId},
        mode: ProcessStartMode.detached,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Start the app when the user logs in.
  /// Windows: HKCU Run key. macOS: a LaunchAgent in ~/Library/LaunchAgents.
  static Future<bool> setLaunchAtLogin(bool enable) async {
    final exe = Platform.resolvedExecutable;
    try {
      if (Platform.isWindows) {
        const key = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
        final r = enable
            ? await Process.run('reg', ['add', key, '/v', appName, '/t', 'REG_SZ', '/d', '"$exe"', '/f'])
            : await Process.run('reg', ['delete', key, '/v', appName, '/f']);
        return r.exitCode == 0 || !enable;
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
