import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'assets_loader.dart';
import 'desktop.dart';
import 'i18n.dart';
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
  String? windowId = env['SCREEN_WIDGET_WINDOW'];
  for (final a in args) {
    if (a.startsWith('--scene=')) sceneArg = a.substring('--scene='.length);
    if (a.startsWith('--window=')) windowId = a.substring('--window='.length);
  }

  // Settings and images load at the same time.
  final results = await Future.wait<Object?>([
    AppSettings.load(solo: solo, windowId: windowId),
    SceneAssets.load(),
  ]);
  final settings = results[0] as AppSettings?;
  if (settings == null) exit(0); // this pop-out is already open
  final assets = results[1] as SceneAssets;
  setLanguage(settings.language);
  if (sceneArg != null && sceneById(sceneArg) != null) settings.update((x) => x.scene = sceneArg!);

  // Where the window goes: where it was last time (if that screen is still
  // there), otherwise centred at the saved crop size or a default size.
  final saved = settings.windowBounds;
  final restore = saved != null && await Desktop.isOnScreen(saved) ? saved : null;
  final hasCrop = settings.viewWidth > 0 && settings.viewHeight > 0;
  final size = restore?.size ??
      (hasCrop
          ? Size(math.max(settings.viewWidth, kMinWindow.width), math.max(settings.viewHeight, kMinWindow.height))
          : (solo ? const Size(520, 680) : const Size(960, 660)));

  final options = WindowOptions(
    size: size,
    minimumSize: kMinWindow,
    center: restore == null,
    title: 'Screen Widget',
    backgroundColor: Colors.transparent,
    titleBarStyle: TitleBarStyle.hidden,
  );

  // 1. Set up the still-hidden window: size, position, frame, transparency.
  await windowManager.waitUntilReadyToShow(options, () async {
    try {
      await Desktop.applyAll(settings);
      if (restore != null) {
        await windowManager.setBounds(restore);
      } else if (solo) {
        // Nudge new pop-out windows so they don't sit exactly on top of the main one.
        final pos = await windowManager.getPosition();
        final r = math.Random();
        await windowManager.setPosition(pos + Offset(60 + r.nextDouble() * 120, 40 + r.nextDouble() * 80));
      }
    } catch (_) {
      // A window style that fails to apply must never stop the app from showing.
    }
  });

  // 2. Build the UI.
  runApp(ScreenWidgetApp(settings: settings, assets: assets));

  // 3. Show the window only once the first frame is actually on screen, so it
  //    never appears empty. The timeout makes sure it always shows.
  await WidgetsBinding.instance.waitUntilFirstFrameRasterized
      .timeout(const Duration(seconds: 3), onTimeout: () {});
  await _showWindow();

  if (!solo) {
    // "Launch at login": trust what the OS really has (the installer can turn
    // it on), and re-register so it points at this copy of the app.
    final atLogin = await Desktop.isLaunchAtLoginEnabled();
    if (atLogin != null) {
      if (atLogin) await Desktop.setLaunchAtLogin(true);
      if (atLogin != settings.launchAtLogin) settings.update((x) => x.launchAtLogin = atLogin);
    }
    // Reopen the pop-out windows that were open last time.
    await Desktop.restorePopouts();
  }
}

Future<void> _showWindow() async {
  await windowManager.show();
  await windowManager.focus();
  if (Platform.isWindows) {
    // A frameless/transparent window on Windows can stay blank until it is
    // resized. A 1px resize and back makes Flutter repaint it straight away.
    final s = await windowManager.getSize();
    await windowManager.setSize(Size(s.width + 1, s.height));
    await windowManager.setSize(s);
  }
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
        setLanguage(settings.language);
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
