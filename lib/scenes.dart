import 'package:flutter/painting.dart';

/// Warm light that "breathes" over the background plate (screen blend).
class SunGlow {
  const SunGlow({required this.x, required this.y, required this.radius, required this.color, required this.alpha});

  /// Position as a fraction of the background image.
  final double x, y;

  /// Radius as a fraction of the larger window side.
  final double radius;
  final Color color;
  final double alpha;
}

/// One view of the app. Every view is built from the same parts —
/// background plate + tree cut-out + falling-particle sprite — and placed with
/// the same rules, so all views feel like one set.
///
/// To add a new view: drop its images into assets/, then add a [SceneDef]
/// to [kScenes]. Nothing else needs to change.
class SceneDef {
  const SceneDef({
    required this.id,
    required this.name,
    required this.vn,
    required this.accent,
    required this.particleLabel,
    required this.background,
    required this.tree,
    required this.sprite,
    required this.treeHeight,
    required this.baseY,
    required this.canopyEnd,
    required this.rate,
    required this.sway,
    required this.particleSize,
    required this.fallSpeed,
    required this.landTop,
    required this.shadow,
    this.baseX = 0.5,
    this.glow,
    this.snow = false,
    this.lights = false,
  });

  final String id;
  final String name;

  /// Vietnamese name shown under the English one.
  final String vn;
  final Color accent;

  /// Label for the density slider ("Petals" / "Snow").
  final String particleLabel;

  final String background, tree, sprite;

  /// Tree height as a fraction of the window height.
  final double treeHeight;

  /// Where the tree's base sits, as fractions of the window.
  final double baseX, baseY;

  /// Petals only spawn from the top [canopyEnd] part of the tree image.
  final double canopyEnd;

  /// Particles per second at 100% density.
  final double rate;

  /// How far the crown sways, as a fraction of tree height.
  final double sway;

  /// Particle size and fall speed as fractions of window height.
  final double particleSize, fallSpeed;

  /// Particles land between this fraction of the height and the bottom.
  final double landTop;
  final Color shadow;
  final SunGlow? glow;

  /// Snow falls from the sky instead of from the tree.
  final bool snow;

  /// Draw twinkling fairy lights + star glow (uses tree_xmas_lights.json).
  final bool lights;
}

const kScenes = <SceneDef>[
  SceneDef(
    id: 'sakura',
    name: 'Cherry Blossom',
    vn: 'Hoa anh đào',
    accent: Color(0xFFE2557F),
    particleLabel: 'Petals',
    background: 'assets/backgrounds/bg_sakura.jpg',
    tree: 'assets/trees/tree_sakura.png',
    sprite: 'assets/sprites/petal_sakura.png',
    treeHeight: 0.80,
    baseY: 0.95,
    canopyEnd: 0.62,
    rate: 16,
    sway: 0.010,
    particleSize: 0.020,
    fallSpeed: 0.10,
    landTop: 0.84,
    shadow: Color(0x591E2D14),
    glow: SunGlow(x: 0.08, y: 0.12, radius: 0.9, color: Color(0xFFFFDCAA), alpha: 0.35),
  ),
  SceneDef(
    id: 'mai',
    name: 'Yellow Apricot',
    vn: 'Hoa mai vàng',
    accent: Color(0xFFD99100),
    particleLabel: 'Petals',
    background: 'assets/backgrounds/bg_mai.jpg',
    tree: 'assets/trees/tree_mai.png',
    sprite: 'assets/sprites/petal_mai.png',
    treeHeight: 0.80,
    baseY: 0.96,
    canopyEnd: 0.58,
    rate: 9,
    sway: 0.012,
    particleSize: 0.017,
    fallSpeed: 0.11,
    landTop: 0.86,
    shadow: Color(0x663C230A),
    glow: SunGlow(x: 0.63, y: 0.47, radius: 0.8, color: Color(0xFFFFD696), alpha: 0.45),
  ),
  SceneDef(
    id: 'xmas',
    name: 'Christmas Tree',
    vn: 'Cây thông Noel',
    accent: Color(0xFF2E8B57),
    particleLabel: 'Snow',
    background: 'assets/backgrounds/bg_xmas.jpg',
    tree: 'assets/trees/tree_xmas.png',
    sprite: 'assets/sprites/snowflake.png',
    treeHeight: 0.82,
    baseY: 0.95,
    canopyEnd: 1.0,
    rate: 70,
    sway: 0.004,
    particleSize: 0.022,
    fallSpeed: 0.07,
    landTop: 0.84,
    shadow: Color(0x73050A23),
    snow: true,
    lights: true,
  ),
];

SceneDef? sceneById(String id) {
  for (final s in kScenes) {
    if (s.id == id) return s;
  }
  return null;
}
