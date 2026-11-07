import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../assets_loader.dart';
import '../scenes.dart';
import 'world.dart';

/// Draws one frame of the world: background plate, warm glow, tree (bent by
/// the wind), fairy lights, particles, vignette.
class ScenePainter extends CustomPainter {
  ScenePainter(this.world) : super(repaint: world);

  final World world;

  SceneAssets get assets => world.assets;

  @override
  void paint(Canvas canvas, Size size) {
    world.ensureLayout(size);
    if (world.size.isEmpty) return;
    final s = world.settings;
    final sc = world.scene;

    if (!s.transparent) drawBackground(canvas, size, sc, assets, world.t, s.zoom, s.panY);
    _particles(canvas, world.landed, landed: true, near: false);
    _tree(canvas, sc, world.tree, world.bend, shadow: !s.transparent);
    if (sc.lights) _lights(canvas);
    _particles(canvas, world.parts, landed: false, near: false);
    if (!s.transparent) _vignette(canvas, size);
    _particles(canvas, world.parts, landed: false, near: true);

    // Cross-fade from the previous scene after switching views.
    final old = world.fadeFrom;
    if (old != null && world.fadeAlpha > 0) {
      canvas.saveLayer(Offset.zero & size, Paint()..color = Color.fromRGBO(0, 0, 0, world.fadeAlpha.clamp(0.0, 1.0).toDouble()));
      if (!s.transparent) drawBackground(canvas, size, old, assets, world.t, s.zoom, s.panY);
      final layout = TreeLayout.of(old, assets.image(old.tree), size, s.zoom, s.panY);
      _tree(canvas, old, layout, (_) => 0.0, shadow: !s.transparent);
      canvas.restore();
    }
  }

  /// Background plate, cover-fitted, slowly drifting, plus the warm glow.
  /// Static so the settings thumbnails can reuse it.
  static void drawBackground(Canvas canvas, Size size, SceneDef sc, SceneAssets assets, double t, double zoom, double panY) {
    final img = assets.image(sc.background);
    final w = size.width, h = size.height;
    final scale = math.max(w / img.width, h / img.height) * 1.06 * math.max(1.0, zoom);
    final dw = img.width * scale, dh = img.height * scale;
    // Zoom around the tree base so the crop stays framed on the tree.
    final ax = w * sc.baseX, ay = h * (sc.baseY + panY);
    final ox = ax - dw * sc.baseX + math.sin(t * 0.05) * w * 0.012;
    var oy = ay - dh * sc.baseY + math.cos(t * 0.04) * h * 0.006;
    oy = oy.clamp(h - dh, 0.0).toDouble(); // never show an empty band
    final paint = Paint()..filterQuality = FilterQuality.medium;
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromLTWH(ox.clamp(w - dw, 0.0).toDouble(), oy, dw, dh),
      paint,
    );
    final g = sc.glow;
    if (g != null) {
      final c = Offset(ox + g.x * dw, oy + g.y * dh);
      final r = math.max(w, h) * g.radius * (0.96 + 0.04 * math.sin(t * 0.7));
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader = ui.Gradient.radial(c, r, [g.color.withAlpha((g.alpha * 255).round()), g.color.withAlpha(0)]),
      );
    }
  }

  /// The tree, drawn in horizontal strips shifted by [bend] so the crown
  /// sways while the base stays put.
  void _tree(Canvas canvas, SceneDef sc, TreeLayout l, double Function(double v) bend, {required bool shadow}) {
    final img = assets.image(sc.tree);
    final cx = l.x + l.width / 2, base = l.y + l.height;
    if (shadow) {
      canvas.save();
      canvas.translate(cx, base);
      canvas.scale(1, 0.12);
      final r = l.width * 0.45;
      canvas.drawCircle(Offset.zero, r, Paint()..shader = ui.Gradient.radial(Offset.zero, r, [sc.shadow, sc.shadow.withAlpha(0)]));
      canvas.restore();
    }
    const n = 48;
    final ih = img.height.toDouble(), iw = img.width.toDouble();
    final sh = ih / n, dh = l.height / n;
    final paint = Paint()..filterQuality = FilterQuality.medium;
    for (var i = 0; i < n; i++) {
      final v = (i + 0.5) / n;
      final off = bend(v);
      final srcTop = i * sh;
      final srcH = math.min(sh + 1, ih - srcTop);
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, srcTop, iw, srcH),
        Rect.fromLTWH(l.x + off, l.y + i * dh, l.width, dh * srcH / sh + 0.6),
        paint,
      );
    }
  }

  void _lights(Canvas canvas) {
    final t = world.t, l = world.tree, glow = assets.glowWarm;
    final src = Rect.fromLTWH(0, 0, glow.width.toDouble(), glow.height.toDouble());
    final s0 = l.height * 0.045;
    final paint = Paint()..blendMode = BlendMode.plus;
    final lights = assets.lights;
    for (var i = 0; i < lights.length; i++) {
      final p = lights[i];
      final on = 0.5 + 0.5 * math.sin(t * (1.3 + (i % 7) * 0.31) + i * 1.7);
      final x = l.x + p.dx * l.width + world.bend(p.dy), y = l.y + p.dy * l.height;
      final s = s0 * (0.6 + 0.6 * on);
      paint.color = Color.fromRGBO(255, 255, 255, (0.25 + 0.6 * on).clamp(0.0, 1.0).toDouble());
      canvas.drawImageRect(glow, src, Rect.fromCenter(center: Offset(x, y), width: s, height: s), paint);
    }
    // Star glow + slowly turning rays.
    final st = assets.star;
    final sp = Offset(l.x + st.dx * l.width + world.bend(st.dy), l.y + st.dy * l.height);
    final ss = l.height * 0.32 * (0.92 + 0.08 * math.sin(t * 2));
    paint.color = const Color.fromRGBO(255, 255, 255, 0.75);
    canvas.drawImageRect(assets.glowStar, src, Rect.fromCenter(center: sp, width: ss, height: ss), paint);
    canvas.save();
    canvas.translate(sp.dx, sp.dy);
    canvas.rotate(t * 0.2);
    final ray = Paint()
      ..blendMode = BlendMode.plus
      ..color = const Color.fromRGBO(255, 233, 168, 0.18);
    for (var i = 0; i < 8; i++) {
      canvas.rotate(math.pi / 4);
      final len = l.height * (i.isOdd ? 0.07 : 0.12), wd = l.height * 0.004;
      canvas.drawPath(Path()..moveTo(-wd, 0)..lineTo(0, -len)..lineTo(wd, 0)..close(), ray);
    }
    canvas.restore();
  }

  void _particles(Canvas canvas, List<Particle> list, {required bool landed, required bool near}) {
    final sc = world.scene;
    final sprite = assets.image(sc.sprite);
    final blurred = assets.blurred(sc.sprite);
    final dot = Paint();
    final paint = Paint()..filterQuality = FilterQuality.medium;
    for (final p in list) {
      if (!landed && p.near != near) continue;
      final double a = landed ? (p.life / 1.5).clamp(0.0, 1.0).toDouble() : 1.0;
      if (sc.snow && !p.flake) {
        dot.color = Color.fromRGBO(255, 255, 255, (a * p.alpha).clamp(0.0, 1.0).toDouble());
        canvas.drawCircle(Offset(p.x, p.y), p.size, dot);
        continue;
      }
      final img = p.near ? blurred : sprite;
      final k = p.near ? img.width / sprite.width : 1.0;
      final sx = landed || sc.snow ? 1.0 : math.cos(p.flip);
      final sy = landed ? 0.5 : 1.0;
      final double alpha = a * (p.near ? 0.8 : sc.snow ? math.min(1.0, p.alpha + 0.2) : 1.0);
      paint.color = Color.fromRGBO(255, 255, 255, alpha.clamp(0.0, 1.0).toDouble());
      final w = p.size * k;
      final h = w * img.height / img.width;
      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rot);
      canvas.scale(sx == 0 ? 0.001 : sx, sy);
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromCenter(center: Offset.zero, width: w, height: h),
        paint,
      );
      canvas.restore();
    }
  }

  void _vignette(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.48);
    final r = math.max(size.width, size.height) * 0.8;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(c, r, const [Color(0x00000000), Color(0x00000000), Color(0x610A0814)], const [0, 0.45, 1]),
    );
  }

  @override
  bool shouldRepaint(covariant ScenePainter old) => old.world != world;
}

/// Static preview used by the scene cards in the settings panel.
class ThumbPainter extends CustomPainter {
  ThumbPainter(this.scene, this.assets);
  final SceneDef scene;
  final SceneAssets assets;

  @override
  void paint(Canvas canvas, Size size) {
    ScenePainter.drawBackground(canvas, size, scene, assets, 0, 1, 0);
    final img = assets.image(scene.tree);
    final l = TreeLayout.of(scene, img, size, 1, 0);
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromLTWH(l.x, l.y, l.width, l.height),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(covariant ThumbPainter old) => old.scene != scene;
}
