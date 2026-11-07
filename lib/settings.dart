import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'scenes.dart';

/// All user settings, persisted with shared_preferences.
class AppSettings extends ChangeNotifier {
  AppSettings._(this._prefs, this.solo);

  static const _key = 'screen_widget.settings.v1';

  final SharedPreferences _prefs;

  /// True for a window opened with "Open in new window". Such windows show
  /// their own scene and never overwrite the main window's scene choice.
  final bool solo;

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

  /// Size & crop. [viewWidth]/[viewHeight] = 0 means "whatever size the window is".
  double viewWidth = 0, viewHeight = 0;

  /// Framing inside the crop: zoom (0.6–2.0) and vertical shift (-0.3–0.3 of height).
  double zoom = 1.0;
  double panY = 0.0;

  static Future<AppSettings> load({bool solo = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final s = AppSettings._(prefs, solo);
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        s._fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // Corrupt or old settings: keep defaults.
      }
    }
    if (sceneById(s.scene) == null) s.scene = kScenes.first.id;
    return s;
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
        'viewWidth': viewWidth,
        'viewHeight': viewHeight,
        'zoom': zoom,
        'panY': panY,
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
    viewWidth = (m['viewWidth'] as num?)?.toDouble() ?? viewWidth;
    viewHeight = (m['viewHeight'] as num?)?.toDouble() ?? viewHeight;
    zoom = ((m['zoom'] as num?)?.toDouble() ?? zoom).clamp(0.6, 2.0).toDouble();
    panY = ((m['panY'] as num?)?.toDouble() ?? panY).clamp(-0.3, 0.3).toDouble();
  }

  void _save() {
    final m = toJson();
    if (solo) {
      // Keep the main window's scene; a pop-out window only shows its own.
      final raw = _prefs.getString(_key);
      if (raw != null) {
        try {
          m['scene'] = (jsonDecode(raw) as Map<String, dynamic>)['scene'];
        } catch (_) {}
      }
    }
    _prefs.setString(_key, jsonEncode(m));
  }
}
