import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config_store.dart';
import 'scenes.dart';

/// All user settings for one window. Saved to that window's own file (see
/// [ConfigStore]) and restored the next time it opens.
class AppSettings extends ChangeNotifier {
  AppSettings._(this._store, this.solo, this.windowId);

  /// Where older versions kept the settings (shared_preferences); read once to migrate.
  static const _legacyKey = 'screen_widget.settings.v1';

  final ConfigStore _store;
  Timer? _saveTimer;

  /// True for a window opened with "Open in new window". Each such window keeps
  /// its own settings, position and scene.
  final bool solo;

  /// Id of a pop-out window (null for the main window).
  final String? windowId;

  /// UI language: 'vi' (default) or 'en'.
  String language = 'vi';

  /// Last window position and size (logical pixels), restored at start-up.
  Rect? windowBounds;

  String scene = kScenes.first.id;
  double density = 55; // 0..100 %
  double wind = 20; // -100..100 %
  double speed = 100; // 25..200 %
  bool sway = true;
  bool accumulate = true;
  bool bokeh = true;
  bool transparent = false;
  bool alwaysOnTop = false;
  bool launchAtLogin = false;
  bool showFps = false;

  /// Lock = click-through: mouse clicks pass to the apps behind the window.
  bool locked = false;

  /// Size & crop. [viewWidth]/[viewHeight] = 0 means "whatever size the window is".
  double viewWidth = 0, viewHeight = 0;

  /// Framing inside the crop: zoom (0.6–2.0) and vertical shift (-0.3–0.3 of height).
  double zoom = 1.0;
  double panY = 0.0;

  /// Loads this window's settings. For a pop-out, returns null if that
  /// pop-out is already open in another process.
  static Future<AppSettings?> load({bool solo = false, String? windowId}) async {
    final store = solo ? ConfigStore.forPopout(windowId ?? ConfigStore.newPopoutId()) : ConfigStore.forMain();
    if (solo && !store.hold()) return null;
    final s = AppSettings._(store, solo, solo ? windowId : null);

    var data = store.read();
    if (data == null && solo) {
      // A new pop-out starts from the main window's settings (not its position or lock).
      data = ConfigStore.forMain().read()?..remove('window')..remove('locked');
    }
    data ??= await _readLegacy();
    if (data != null) {
      try {
        s._fromJson(data);
      } catch (_) {
        // Corrupt or old settings: keep defaults.
      }
    }
    if (sceneById(s.scene) == null) s.scene = kScenes.first.id;
    if (s.language != 'en') s.language = 'vi';
    s._writeNow(); // a new pop-out is listed straight away, so it's restored even after a crash
    return s;
  }

  static Future<Map<String, dynamic>?> _readLegacy() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_legacyKey);
      return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Change one or more values, repaint listeners and save.
  void update(void Function(AppSettings s) change) {
    change(this);
    notifyListeners();
    _save();
  }

  Map<String, dynamic> toJson() => {
        'scene': scene,
        'density': density,
        'wind': wind,
        'speed': speed,
        'sway': sway,
        'accumulate': accumulate,
        'bokeh': bokeh,
        'transparent': transparent,
        'alwaysOnTop': alwaysOnTop,
        'launchAtLogin': launchAtLogin,
        'showFps': showFps,
        'locked': locked,
        'viewWidth': viewWidth,
        'viewHeight': viewHeight,
        'zoom': zoom,
        'panY': panY,
        'language': language,
        if (windowBounds != null)
          'window': {
            'x': windowBounds!.left,
            'y': windowBounds!.top,
            'w': windowBounds!.width,
            'h': windowBounds!.height,
          },
      };

  void _fromJson(Map<String, dynamic> m) {
    scene = m['scene'] as String? ?? scene;
    density = (m['density'] as num?)?.toDouble() ?? density;
    wind = (m['wind'] as num?)?.toDouble() ?? wind;
    speed = (m['speed'] as num?)?.toDouble() ?? speed;
    sway = m['sway'] as bool? ?? sway;
    accumulate = m['accumulate'] as bool? ?? accumulate;
    bokeh = m['bokeh'] as bool? ?? bokeh;
    transparent = m['transparent'] as bool? ?? transparent;
    alwaysOnTop = m['alwaysOnTop'] as bool? ?? alwaysOnTop;
    launchAtLogin = m['launchAtLogin'] as bool? ?? launchAtLogin;
    showFps = m['showFps'] as bool? ?? showFps;
    locked = m['locked'] as bool? ?? locked;
    viewWidth = (m['viewWidth'] as num?)?.toDouble() ?? viewWidth;
    viewHeight = (m['viewHeight'] as num?)?.toDouble() ?? viewHeight;
    zoom = ((m['zoom'] as num?)?.toDouble() ?? zoom).clamp(0.6, 2.0).toDouble();
    panY = ((m['panY'] as num?)?.toDouble() ?? panY).clamp(-0.3, 0.3).toDouble();
    language = m['language'] as String? ?? language;
    final w = m['window'];
    if (w is Map) {
      final x = (w['x'] as num?)?.toDouble(), y = (w['y'] as num?)?.toDouble();
      final ww = (w['w'] as num?)?.toDouble(), hh = (w['h'] as num?)?.toDouble();
      if (x != null && y != null && ww != null && hh != null && ww > 0 && hh > 0) {
        windowBounds = Rect.fromLTWH(x, y, ww, hh);
      }
    }
  }

  /// Saves shortly after the last change (sliders fire many changes per second).
  void _save() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _writeNow);
  }

  void _writeNow() {
    _saveTimer?.cancel();
    _saveTimer = null;
    _store.write(toJson());
  }

  /// Remember where the window is; saved without repainting anything.
  void saveWindowBounds(Rect r) {
    if (r == windowBounds) return;
    windowBounds = r;
    _save();
  }

  /// Write any pending change now (call before the window closes).
  void flush() {
    if (_saveTimer != null) _writeNow();
  }

  /// Forget this pop-out completely (the user closed it on purpose).
  void forget() {
    _saveTimer?.cancel();
    _saveTimer = null;
    _store.delete();
  }
}
