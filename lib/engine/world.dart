import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../assets_loader.dart';
import '../scenes.dart';
import '../settings.dart';

/// Where the tree sits on screen for one scene at one window size.
class TreeLayout {
  const TreeLayout(this.x, this.y, this.width, this.height);
  final double x, y, width, height;

  static TreeLayout of(SceneDef sc, ui.Image img, ui.Size size, double zoom, double panY) {
    final w = size.width, h = size.height;
    var th = h * sc.treeHeight * zoom;
    var tw = th * img.width / img.height;
    final maxW = w * 0.92 * zoom;
    if (tw > maxW) {
      tw = maxW;
      th = tw * img.height / img.width;
    }
    final baseY = h * (sc.baseY + panY);
    return TreeLayout(w * sc.baseX - tw / 2, baseY - th, tw, th);
  }
}

class Particle {
  Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.rot,
    required this.spin,
    required this.flip,
    required this.flipSpeed,
    required this.terminal,
    required this.freq,
    required this.phase,
    required this.flutter,
    required this.landY,
    required this.alpha,
    required this.near,
    required this.flake,
  });

  double x, y, vx = 0, vy = 0;
  final double size, spin, flipSpeed, terminal, freq, phase, flutter, landY, alpha;
  double rot, flip;

  /// Large, blurred, close-to-camera particle.
  final bool near;

  /// Drawn with the sprite (petal / snowflake) instead of a soft dot.
  final bool flake;

  /// Seconds left once it has landed.
  double life = 0;
}

/// The simulation: wind, tree sway, falling particles. Notifies its painter
/// once per frame. Port of the HTML preview engine, same numbers.
class World extends ChangeNotifier {
  World(this.settings, this.assets) : scene = sceneById(settings.scene) ?? kScenes.first;

  final AppSettings settings;
  final SceneAssets assets;
  final _r = math.Random();

  SceneDef scene;
  ui.Size size = ui.Size.zero;
  late TreeLayout tree;

  double t = 0;
  double wind = 0;
  List<Particle> parts = [];
  List<Particle> landed = [];
  double _acc = 0;

  /// Previous scene, faded out over ~0.5 s after a switch.
  SceneDef? fadeFrom;
  double fadeAlpha = 0;

  double _zoom = 1, _panY = 0;

  void setScene(String id, {bool fade = true}) {
    final next = sceneById(id);
    if (next == null || next.id == scene.id) return;
    if (fade && !size.isEmpty) {
      fadeFrom = scene;
      fadeAlpha = 1;
    }
    scene = next;
    _relayout(reset: true, warm: 5);
  }

  /// Called by the painter with the canvas size; re-lays out when the window
  /// or the crop framing changes.
  void ensureLayout(ui.Size s) {
    if (s.isEmpty) return;
    if (s != size || settings.zoom != _zoom || settings.panY != _panY) {
      final resized = s != size;
      size = s;
      _relayout(reset: resized, warm: resized ? 4 : 0);
    }
  }

  void _relayout({required bool reset, required double warm}) {
    if (size.isEmpty) return;
    _zoom = settings.zoom;
    _panY = settings.panY;
    tree = TreeLayout.of(scene, assets.image(scene.tree), size, _zoom, _panY);
    if (reset) {
      parts = [];
      landed = [];
      _acc = 0;
      for (var i = 0; i < warm * 10; i++) {
        step(0.1, prewarm: true);
      }
    }
  }

  /// Notify the painter (called once per frame by the ticker).
  void frame() => notifyListeners();

  double _windEff(double t) {
    final gust = 0.5 + 0.5 * math.sin(t * 0.37) * math.sin(t * 0.13 + 1.7);
    return (settings.wind / 100) * (0.55 + 0.9 * gust) + math.sin(t * 0.8) * 0.04;
  }

  /// Horizontal bend of the tree at vertical fraction [v] (0 = top, 1 = base).
  double bend(double v) {
    final k = math.pow(1 - v, 1.8).toDouble();
    final amp = tree.height * scene.sway;
    final sw = settings.sway ? math.sin(t * 1.05) + 0.35 * math.sin(t * 2.3 + v * 3) : 0.0;
    return k * (amp * sw + wind * tree.height * 0.02);
  }

  Particle? _spawn() {
    final sc = scene, h = size.height, w = size.width, z = _zoom;
    double x, y;
    if (sc.snow) {
      x = (_r.nextDouble() * 1.3 - 0.15) * w;
      y = -20;
    } else if (_r.nextDouble() < 0.12) {
      x = (_r.nextDouble() * 1.2 - 0.1) * w;
      y = -20;
    } else {
      final pts = assets.canopy[sc.id]!;
      final p = pts[_r.nextInt(pts.length)];
      x = tree.x + p.dx * tree.width + bend(p.dy);
      y = tree.y + p.dy * tree.height;
    }
    final near = !sc.snow && settings.bokeh && _r.nextDouble() < (sc.id == 'mai' ? 0.04 : 0.08);
    final flake = near || (sc.snow ? _r.nextDouble() < 0.35 : true);
    final dot = sc.snow && !flake;
    final sz = h * sc.particleSize * z * (near ? 2.4 + _r.nextDouble() : 0.65 + _r.nextDouble() * 0.6) * (dot ? 0.35 : 1);
    return Particle(
      x: x,
      y: y,
      size: sz,
      rot: _r.nextDouble() * math.pi * 2,
      spin: (_r.nextDouble() - 0.5) * (sc.snow ? 0.8 : 3),
      flip: _r.nextDouble() * math.pi * 2,
      flipSpeed: sc.snow ? 0 : 2.5 + _r.nextDouble() * 3.5,
      terminal: h * sc.fallSpeed * z * (near ? 1.8 : 0.8 + _r.nextDouble() * 0.5) * (dot ? 0.8 : 1),
      freq: 0.8 + _r.nextDouble() * 1.3,
      phase: _r.nextDouble() * math.pi * 2,
      flutter: h * (0.03 + _r.nextDouble() * 0.04),
      landY: h * (sc.landTop + (1.02 - sc.landTop) * _r.nextDouble()),
      alpha: 0.6 + _r.nextDouble() * 0.4,
      near: near,
      flake: flake,
    );
  }

  void step(double dt, {bool prewarm = false}) {
    if (size.isEmpty) return;
    dt = math.min(dt, 0.1) * (prewarm ? 1 : settings.speed / 100);
    t += dt;
    wind = _windEff(t);
    final h = size.height, w = size.width;

    _acc += scene.rate * (settings.density / 100) * dt * (w / h > 1 ? 1 : 0.7);
    while (_acc >= 1) {
      _acc -= 1;
      final p = _spawn();
      if (p != null) parts.add(p);
    }

    final keep = <Particle>[];
    final damp = math.min(1.0, dt * 1.6), fall = math.min(1.0, dt * 1.4);
    for (final p in parts) {
      final tvx = wind * h * 0.16 * (p.near ? 1.6 : 1) + math.sin(t * p.freq + p.phase) * p.flutter;
      p.vx += (tvx - p.vx) * damp;
      p.vy += (p.terminal - p.vy) * fall;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.rot += p.spin * dt;
      p.flip += p.flipSpeed * dt;
      if (!p.near && p.y >= p.landY && !settings.transparent) {
        if (landed.length < 500) {
          p.life = settings.accumulate ? 6 + _r.nextDouble() * 8 : 0.5;
          landed.add(p);
        }
        continue;
      }
      if (p.y < h + 60 && p.x > -w * 0.3 && p.x < w * 1.3) keep.add(p);
    }
    parts = keep;
    landed.removeWhere((p) => (p.life -= dt) <= 0);

    if (fadeFrom != null) {
      fadeAlpha -= dt * 2;
      if (fadeAlpha <= 0) fadeFrom = null;
    }
  }

  /// Drop landed petals (e.g. when switching to transparent mode).
  void clearLanded() => landed = [];
}
