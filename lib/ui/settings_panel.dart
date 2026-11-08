import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../assets_loader.dart';
import '../build_info.dart';
import '../desktop.dart';
import '../engine/scene_painter.dart';
import '../i18n.dart';
import '../scenes.dart';
import '../settings.dart';
import 'controls.dart';

class SettingsPanel extends StatefulWidget {
  const SettingsPanel({
    super.key,
    required this.settings,
    required this.assets,
    required this.windowSize,
    required this.onClose,
    required this.onScene,
    required this.onPopOut,
    required this.onTransparent,
    required this.onAlwaysOnTop,
    required this.onLaunchAtLogin,
    required this.onLock,
    required this.onResize,
  });

  final AppSettings settings;
  final SceneAssets assets;
  final Size windowSize;
  final VoidCallback onClose;
  final ValueChanged<String> onScene;
  final ValueChanged<String> onPopOut;
  final ValueChanged<bool> onTransparent;
  final ValueChanged<bool> onAlwaysOnTop;
  final ValueChanged<bool> onLaunchAtLogin;
  final ValueChanged<bool> onLock;

  /// Resize the window to an exact size (logical pixels).
  final void Function(double w, double h) onResize;

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  final _w = TextEditingController();
  final _h = TextEditingController();

  @override
  void initState() {
    super.initState();
    _syncFields();
  }

  @override
  void didUpdateWidget(covariant SettingsPanel old) {
    super.didUpdateWidget(old);
    if (old.windowSize != widget.windowSize && !_editing) _syncFields();
  }

  bool get _editing => _focusW.hasFocus || _focusH.hasFocus;
  final _focusW = FocusNode(), _focusH = FocusNode();

  void _syncFields() {
    _w.text = widget.windowSize.width.round().toString();
    _h.text = widget.windowSize.height.round().toString();
  }

  @override
  void dispose() {
    _w.dispose();
    _h.dispose();
    _focusW.dispose();
    _focusH.dispose();
    super.dispose();
  }

  AppSettings get s => widget.settings;

  void _applyCustom() {
    final w = double.tryParse(_w.text.trim());
    final h = double.tryParse(_h.text.trim());
    if (w == null || h == null) return;
    FocusScope.of(context).unfocus();
    widget.onResize(w, h);
  }

  @override
  Widget build(BuildContext context) {
    final sc = sceneById(s.scene) ?? kScenes.first;
    final accent = sc.accent;
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 26, sigmaY: 26),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xC7F7F7FA),
            border: Border(left: BorderSide(color: Color(0x14000000))),
          ),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 10, 4),
                child: Row(children: [
                  Expanded(child: Text(tr('Settings'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kText))),
                  IconButton(icon: const Icon(Icons.close, size: 18), color: kMuted, onPressed: widget.onClose, tooltip: tr('Close (Esc)')),
                ]),
              ),

              // ---- Language ----
              PanelSection(title: isVietnamese ? 'Ngôn ngữ' : 'Language', children: [
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final e in kLanguages.entries)
                    ChoicePill(
                      label: e.value,
                      selected: s.language == e.key,
                      onTap: () => s.update((x) => x.language = e.key),
                      accent: accent,
                    ),
                ]),
              ]),

              // ---- View ----
              PanelSection(title: tr('View'), children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.98,
                  children: [
                    for (final scene in kScenes)
                      _SceneCard(
                        scene: scene,
                        assets: widget.assets,
                        selected: scene.id == s.scene,
                        onTap: () => widget.onScene(scene.id),
                        onPopOut: () => widget.onPopOut(scene.id),
                      ),
                    _MoreCard(key: ValueKey(s.language)), // the key makes it rebuild when the language changes
                  ],
                ),
              ]),

              // ---- Background ----
              PanelSection(title: tr('Background'), children: [
                ToggleRow(
                  label: tr('Transparent background'),
                  hint: tr('Show only the tree and its animation on your desktop'),
                  value: s.transparent,
                  onChanged: widget.onTransparent,
                  accent: accent,
                ),
              ]),

              // ---- Size & crop ----
              PanelSection(title: tr('Size & crop'), children: [
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final p in kSizePresets)
                    ChoicePill(
                      label: tr(p.label),
                      sub: '${p.width.round()}×${p.height.round()}',
                      selected: s.viewWidth == p.width && s.viewHeight == p.height,
                      onTap: () => widget.onResize(p.width, p.height),
                      accent: accent,
                    ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  _NumField(controller: _w, focus: _focusW, label: tr('W'), onSubmit: _applyCustom),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('×', style: TextStyle(color: kMuted))),
                  _NumField(controller: _h, focus: _focusH, label: tr('H'), onSubmit: _applyCustom),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _applyCustom,
                    style: TextButton.styleFrom(foregroundColor: accent, textStyle: const TextStyle(fontWeight: FontWeight.w600)),
                    child: Text(tr('Apply')),
                  ),
                ]),
                const SizedBox(height: 10),
                SliderRow(
                  label: tr('Zoom'),
                  valueText: '${(s.zoom * 100).round()}%',
                  value: s.zoom,
                  min: 0.6,
                  max: 2.0,
                  onChanged: (v) => s.update((x) => x.zoom = v),
                  accent: accent,
                ),
                SliderRow(
                  label: tr('Move scene up / down'),
                  valueText: s.panY == 0 ? tr('Centre') : (s.panY > 0 ? '↓ ${(s.panY * 100).round()}' : '↑ ${(-s.panY * 100).round()}'),
                  value: s.panY,
                  min: -0.3,
                  max: 0.3,
                  onChanged: (v) => s.update((x) => x.panY = (v.abs() < 0.015) ? 0.0 : v),
                  accent: accent,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => s.update((x) {
                      x.zoom = 1.0;
                      x.panY = 0.0;
                    }),
                    style: TextButton.styleFrom(foregroundColor: kMuted, padding: EdgeInsets.zero),
                    child: Text(tr('Reset framing')),
                  ),
                ),
              ]),

              // ---- Motion ----
              PanelSection(title: tr('Motion'), children: [
                SliderRow(
                  label: tr(sc.particleLabel),
                  valueText: '${s.density.round()}%',
                  value: s.density,
                  min: 0,
                  max: 100,
                  onChanged: (v) => s.update((x) => x.density = v),
                  accent: accent,
                ),
                SliderRow(
                  label: tr('Wind'),
                  valueText: s.wind.round() == 0 ? tr('Calm') : '${s.wind < 0 ? '← ' : ''}${s.wind.abs().round()}%${s.wind > 0 ? ' →' : ''}',
                  value: s.wind,
                  min: -100,
                  max: 100,
                  onChanged: (v) => s.update((x) => x.wind = v),
                  accent: accent,
                ),
                SliderRow(
                  label: tr('Animation speed'),
                  valueText: '${(s.speed / 100).toStringAsFixed(2)}×',
                  value: s.speed,
                  min: 25,
                  max: 200,
                  divisions: 35,
                  onChanged: (v) => s.update((x) => x.speed = v),
                  accent: accent,
                ),
                ToggleRow(label: tr('Tree sways in the wind'), value: s.sway, onChanged: (v) => s.update((x) => x.sway = v), accent: accent),
                ToggleRow(label: tr('Petals settle on the ground'), value: s.accumulate, onChanged: (v) => s.update((x) => x.accumulate = v), accent: accent),
                ToggleRow(
                  label: tr('Foreground depth blur'),
                  hint: tr('Large soft petals close to the camera'),
                  value: s.bokeh,
                  onChanged: (v) => s.update((x) => x.bokeh = v),
                  accent: accent,
                ),
              ]),

              // ---- Window ----
              PanelSection(title: tr('Window'), children: [
                ToggleRow(
                  label: tr('Lock (click-through)'),
                  hint: tr('Clicks go to the apps behind. Unlock: {0}, or hover the top-right corner', [Desktop.lockShortcutLabel]),
                  value: s.locked,
                  onChanged: widget.onLock,
                  accent: accent,
                ),
                ToggleRow(label: tr('Always on top'), value: s.alwaysOnTop, onChanged: widget.onAlwaysOnTop, accent: accent),
                ToggleRow(
                  label: tr('Launch at login'),
                  hint: tr('Open automatically when you sign in'),
                  value: s.launchAtLogin,
                  onChanged: widget.onLaunchAtLogin,
                  accent: accent,
                ),
                ToggleRow(label: tr('Show FPS'), value: s.showFps, onChanged: (v) => s.update((x) => x.showFps = v), accent: accent),
                const SizedBox(height: 8),
                AccentButton(
                  label: tr('Open current view in new window'),
                  icon: Icons.open_in_new,
                  onTap: () => widget.onPopOut(s.scene),
                  accent: accent,
                ),
              ]),

              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
                child: Text(
                  '${tr('Shortcuts: 1 2 3 switch view · T transparent background · L lock · , settings · N new window · Esc close.')}\n'
                  '${tr('Right-click the scene to open settings. Drag anywhere to move the window.')}\n'
                  '${tr('Your settings, window position and open windows are saved and restored automatically.')}\n'
                  '${tr('Build {0}', [kBuildId])}',
                  style: const TextStyle(fontSize: 11, color: kMuted, height: 1.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  const _NumField({required this.controller, required this.focus, required this.label, required this.onSubmit});
  final TextEditingController controller;
  final FocusNode focus;
  final String label;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 78,
      height: 34,
      child: TextField(
        controller: controller,
        focusNode: focus,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
        onSubmitted: (_) => onSubmit(),
        style: const TextStyle(fontSize: 13, color: kText),
        decoration: InputDecoration(
          isDense: true,
          prefixText: '$label ',
          prefixStyle: const TextStyle(fontSize: 11, color: kMuted),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kLine)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kLine)),
        ),
      ),
    );
  }
}

class _SceneCard extends StatelessWidget {
  const _SceneCard({required this.scene, required this.assets, required this.selected, required this.onTap, required this.onPopOut});
  final SceneDef scene;
  final SceneAssets assets;
  final bool selected;
  final VoidCallback onTap, onPopOut;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? scene.accent : const Color(0x0F000000), width: selected ? 2 : 1),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Stack(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              AspectRatio(aspectRatio: 16 / 10, child: CustomPaint(painter: ThumbPainter(scene, assets))),
              Padding(
                padding: const EdgeInsets.fromLTRB(9, 6, 9, 0),
                child: Text(sceneName(scene), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: kText)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(9, 1, 9, 0),
                child: Text(sceneOtherName(scene), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: kMuted)),
              ),
            ]),
            Positioned(
              top: 5,
              right: 5,
              child: Tooltip(
                message: tr('Open in new window'),
                child: Material(
                  color: const Color(0xD9FFFFFF),
                  borderRadius: BorderRadius.circular(7),
                  child: InkWell(
                    onTap: onPopOut,
                    borderRadius: BorderRadius.circular(7),
                    child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.open_in_new, size: 13, color: kText)),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _MoreCard extends StatelessWidget {
  const _MoreCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x33141E32), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(tr('+\nMore views\ncoming soon'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: kMuted, height: 1.4)),
    );
  }
}
