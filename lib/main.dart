import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'assets_loader.dart';
import 'desktop.dart';
import 'scenes.dart';
import 'settings.dart';
import 'ui/home_page.dart';

/// Screen Widget — animated painted trees for the desktop.
///
/// A pop-out window ("Open in new window") is a second copy of this app,
/// started with SCREEN_WIDGET_SOLO=1 and SCREEN_WIDGET_SCENE=<id>.
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  final env = Platform.environment;
  final solo = env['SCREEN_WIDGET_SOLO'] == '1' || args.contains('--solo');
  String? sceneArg = env['SCREEN_WIDGET_SCENE'];
  for (final a in args) {
    if (a.startsWith('--scene=')) sceneArg = a.substring('--scene='.length);
  }

  final settings = await AppSettings.load(solo: solo);
  if (sceneArg != null && sceneById(sceneArg) != null) settings.scene = sceneArg;

  final assets = await SceneAssets.load();

  // Window size: the saved crop size, or a default.
  final hasCrop = settings.viewWidth > 0 && settings.viewHeight > 0 && !solo;
  final size = hasCrop
      ? Size(math.max(settings.viewWidth, kMinWindow.width), math.max(settings.viewHeight, kMinWindow.height))
      : (solo ? const Size(520, 680) : const Size(960, 660));

  final options = WindowOptions(
    size: size,
    minimumSize: kMinWindow,
    center: true,
    title: 'Screen Widget',
    backgroundColor: Colors.transparent,
    titleBarStyle: TitleBarStyle.hidden,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await Desktop.applyAll(settings);
    if (solo) {
      // Nudge pop-out windows so they don't sit exactly on top of the main one.
      final pos = await windowManager.getPosition();
      final r = math.Random();
      await windowManager.setPosition(pos + Offset(60 + r.nextDouble() * 120, 40 + r.nextDouble() * 80));
    }
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(ScreenWidgetApp(settings: settings, assets: assets));
}

class ScreenWidgetApp extends StatelessWidget {
  const ScreenWidgetApp({super.key, required this.settings, required this.assets});
  final AppSettings settings;
  final SceneAssets assets;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final accent = (sceneById(settings.scene) ?? kScenes.first).accent;
        return MaterialApp(
          title: 'Screen Widget',
          debugShowCheckedModeBanner: false,
          color: Colors.transparent,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: accent, primary: accent),
            scaffoldBackgroundColor: Colors.transparent,
            canvasColor: Colors.transparent,
          ),
          home: Scaffold(
            backgroundColor: Colors.transparent,
            body: HomePage(settings: settings, assets: assets),
          ),
        );
      },
    );
  }
}
