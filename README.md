# Screen Widget

Animated painted trees for your desktop (macOS and Windows), built with Flutter.

Views: **Cherry Blossom** (hoa anh đào), **Yellow Apricot** (hoa mai vàng) and **Christmas Tree** (cây thông Noel).

## Build & run (with progress)

One command does everything: checks your tools, sets up the project the first time, gets packages, checks the code, compiles and launches the app.

**macOS** (macOS 12 or newer, with Xcode and CocoaPods)

```bash
cd screen-widget
./tool/build_macos.sh              # debug build, then launch
./tool/build_macos.sh release      # release build, then show the .app in Finder
```

**Windows** (needs Visual Studio with "Desktop development with C++")

```powershell
cd screen-widget
powershell -ExecutionPolicy Bypass -File tool\build_windows.ps1            # debug build, then launch
powershell -ExecutionPolicy Bypass -File tool\build_windows.ps1 -Release   # release build, then open its folder
```

While it works you see each step with a spinner, elapsed time, the line the compiler is on, and an overall progress bar:

```
✓ [1/6] Checking tools     00:02
– [2/6] Project setup      already set up
✓ [3/6] Getting packages   00:04
✓ [4/6] Checking code      00:06
⠼ ███████████████░░░░░░░░░ [5/6] Compiling (debug)  01:12 ~64%  CompileSwift normal arm64 …
```

- The **~%** is an estimate based on how long the same step took last time. The first build shows elapsed time only.
- If a step fails, the script stops and prints the last lines of the error. The full output of every step is in `build/logs/`.
- Add `--skip-analyze` (macOS) or `-SkipAnalyze` (Windows) to skip the code check.
- For hot reload while editing, use `flutter run -d macos` / `flutter run -d windows`.

`tool/setup_macos.sh` and `tool/setup_windows.ps1` only do the one-time project setup. The build scripts call them automatically when needed.

## Using it

| Action | How |
| --- | --- |
| Switch view | Settings → View, or keys `1` `2` `3` |
| Transparent background (only the tree + animation) | Title-bar layers button, Settings → Background, or `T` |
| Crop to a size | Settings → Size & crop: pick a preset or type W × H and press Apply |
| Frame the crop | Settings → Size & crop → Zoom / Move scene up/down |
| Open a view in its own window | Pop-out button, the ↗ on a view card, or `N` |
| Lock (clicks go to the apps behind) | Title-bar lock button, Settings → Window, or `L` |
| Unlock | `⌃⌥L` (macOS) / `Ctrl+Alt+L` (Windows) from any app, or rest the cursor on the window's top-right corner until **Unlock** appears |
| Settings | Gear button, right-click the scene, or `,` |
| Move the window | Drag anywhere on the scene or title bar |

The crop size and framing are saved and restored at the next launch.

## Project layout

```
lib/
  main.dart              start-up, window options, pop-out window args
  scenes.dart            the list of views — add new views here
  settings.dart          saved settings (shared_preferences)
  desktop.dart           transparency, always-on-top, crop sizes, launch at login, new windows
  assets_loader.dart     decodes images, builds glow/blur sprites, canopy spawn points
  engine/world.dart      simulation: wind, tree sway, falling particles
  engine/scene_painter.dart  draws a frame (also the settings thumbnails)
  ui/                    title bar, settings panel, controls
assets/
  trees/        tree cut-outs (+ tree_xmas_lights.json: fairy-light positions)
  backgrounds/  background plates
  sprites/      petal_sakura, petal_mai, snowflake
tool/
  setup_macos.sh, setup_windows.ps1, native/macos/MainFlutterWindow.swift
```

## Adding a new view

1. Put a tree cut-out (transparent PNG) in `assets/trees/`, a background in `assets/backgrounds/` and a falling sprite in `assets/sprites/`.
2. Add a `SceneDef` to `kScenes` in `lib/scenes.dart`.

The settings panel, shortcuts and pop-out windows pick it up automatically.

## Notes

- **Transparent background:** the window itself is see-through (macOS: `MainFlutterWindow.swift`; Windows: `window_manager`), so the real desktop shows behind the tree.
- **Pop-out windows** start a second copy of the app with `SCREEN_WIDGET_SOLO=1` and `SCREEN_WIDGET_SCENE=<id>`. Because of this and the launch-at-login LaunchAgent, the macOS App Sandbox is turned off by the setup script.
- **Image resolution:** the bundled images are preview resolution (about 500–1000 px). For crisp results on large screens, replace them with the full-resolution originals from Magnific under the same file names.
