import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import 'scenes.dart';

/// Every image the scenes need, decoded once at start-up.
class SceneAssets {
  SceneAssets._();

  final Map<String, ui.Image> _images = {};

  /// Pre-blurred sprites for the large "close to camera" petals.
  final Map<String, ui.Image> _blurred = {};

  /// Opaque points inside each tree's canopy (fractions of the tree image),
  /// used as spawn positions for falling petals.
  final Map<String, List<Offset>> canopy = {};

  late final ui.Image glowWarm;
  late final ui.Image glowStar;

  /// Fairy-light positions on the Christmas tree (fractions of the image).
  List<Offset> lights = const [];
  Offset star = const Offset(0.5, 0.04);

  ui.Image image(String path) => _images[path]!;
  ui.Image blurred(String path) => _blurred[path] ?? _images[path]!;

  static Future<SceneAssets> load() async {
    final a = SceneAssets._();
    final paths = <String>{};
    for (final s in kScenes) {
      paths..add(s.background)..add(s.tree)..add(s.sprite);
    }
    await Future.wait(paths.map((p) async => a._images[p] = await _decode(p)));

    for (final s in kScenes) {
      a._blurred[s.sprite] ??= await _blur(a._images[s.sprite]!, 6);
      if (!s.snow) a.canopy[s.id] = await _canopyPoints(a._images[s.tree]!, s.canopyEnd);
    }
    a.glowWarm = await _glow(const Color(0xFFFFC86E));
    a.glowStar = await _glow(const Color(0xFFFFE6A0));

    try {
      final json = jsonDecode(await rootBundle.loadString('assets/trees/tree_xmas_lights.json')) as Map<String, dynamic>;
      final all = (json['lights'] as List).map((e) => Offset((e[0] as num).toDouble(), (e[1] as num).toDouble())).toList();
      all.shuffle(math.Random(3));
      a.lights = all.take(170).toList();
      final st = json['star'] as List;
      a.star = Offset((st[0] as num).toDouble(), (st[1] as num).toDouble());
    } catch (_) {
      // Lights are decoration only; the tree still works without them.
    }
    return a;
  }

  static Future<ui.Image> _decode(String path) async {
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    return (await codec.getNextFrame()).image;
  }

  static Future<ui.Image> _glow(Color c) async {
    const s = 128.0;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        const Offset(s / 2, s / 2),
        s / 2,
        [const Color(0xFFFFFFF0), c.withAlpha(217), c.withAlpha(51), c.withAlpha(0)],
        [0, 0.15, 0.45, 1],
      );
    canvas.drawRect(const Rect.fromLTWH(0, 0, s, s), paint);
    return rec.endRecording().toImage(s.toInt(), s.toInt());
  }

  static Future<ui.Image> _blur(ui.Image img, double sigma) async {
    final pad = (sigma * 3).ceil();
    final rec = ui.PictureRecorder();
    Canvas(rec).drawImage(
      img,
      Offset(pad.toDouble(), pad.toDouble()),
      Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
    );
    return rec.endRecording().toImage(img.width + pad * 2, img.height + pad * 2);
  }

  static Future<List<Offset>> _canopyPoints(ui.Image img, double canopyEnd) async {
    final bytes = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bytes == null) return const [Offset(0.5, 0.3)];
    final w = img.width, h = img.height;
    final step = math.max(1, w ~/ 200);
    final pts = <Offset>[];
    for (var y = 0; y < h * canopyEnd; y += step) {
      for (var x = 0; x < w; x += step) {
        if (bytes.getUint8((y * w + x) * 4 + 3) > 200) pts.add(Offset(x / w, y / h));
      }
    }
    pts.shuffle();
    return pts.isEmpty ? const [Offset(0.5, 0.3)] : pts.take(800).toList();
  }
}
