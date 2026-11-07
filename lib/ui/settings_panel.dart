import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../assets_loader.dart';
import '../build_info.dart';
import '../desktop.dart';
import '../engine/scene_painter.dart';
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
                  const Expanded(child: Text('Settings', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kText))),
                  IconButton(icon: const Icon(Icons.close, size: 18), color: kMuted, onPressed: widget.onClose, tooltip: 'Close (Esc)'),
                ]),
              ),

              // ---- View ----
              PanelSection(title: 'View', children: [
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
                    const _MoreCard(),
                  ],
                ),
              ]),

              // ---- Background ----
              PanelSection(title: 'Background', children: [
                ToggleRow(
                  label: 'Transparent background',
                  hint: 'Show only the tree and its animation on your desktop',
                  value: s.transparent,
                  onChanged: widget.onTransparent,
                  accent: accent,
                ),
              ]),

              // ---- Size & crop ----
              PanelSection(title: 'Size & crop', children: [
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final p in kSizePresets)
                    ChoicePill(
                      label: p.label,
                      sub: '${p.width.round()}×${p.height.round()}',
                      selected: s.viewWidth == p.width && s.viewHeight == p.height,
                      onTap: () => widget.onResize(p.width, p.height),
                      accent: accent,
                    ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  _NumField(controller: _w, focus: _focusW, label: 'W', onSubmit: _applyCustom),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('×', style: TextStyle(color: kMuted))),
                  _NumField(controller: _h, focus: _focusH, label: 'H', onSubmit: _applyCustom),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _applyCustom,
                    style: TextButton.styleFrom(foregroundColor: accent, textStyle: const TextStyle(fontWeight: FontWeight.w600)),
                    child: const Text('Apply'),
                  ),
                ]),
                const SizedBox(height: 10),
                SliderRow(
                  label: 'Zoom',
                  valueText: '${(s.zoom * 100).round()}%',
                  value: s.zoom,
                  min: 0.6,
                  max: 2.0,
                  onChanged: (v) => s.update((x) => x.zoom = v),
                  accent: accent,
                ),
                SliderRow(
                  label: 'Move scene up / down',
                  valueText: s.panY == 0 ? 'Centre' : (s.panY > 0 ? '↓ ${(s.panY * 100).round()}' : '↑ ${(-s.panY * 100).round()}'),
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
                    child: const Text('Reset framing'),
                  ),
                ),
              ]),

              // ---- Motion ----
              PanelSection(title: 'Motion', children: [
                SliderRow(
                  label: sc.particleLabel,
                  valueText: '${s.density.round()}%',
                  value: s.density,
                  min: 0,
                  max: 100,
                  onChanged: (v) => s.update((x) => x.density = v),
                  accent: accent,
                ),
                SliderRow(
                  label: 'Wind',
                  valueText: s.wind.round() == 0 ? 'Calm' : '${s.wind < 0 ? '← ' : ''}${s.wind.abs().round()}%${s.wind > 0 ? ' →' : ''}',
                  value: s.wind,
                  min: -100,
                  max: 100,
                  onChanged: (v) => s.update((x) => x.wind = v),
                  accent: accent,
                ),
                SliderRow(
                  label: 'Animation speed',
                  valueText: '${(s.speed / 100).toStringAsFixed(2)}×',
                  value: s.speed,
                  min: 25,
                  max: 200,
                  divisions: 35,
                  onChanged: (v) => s.update((x) => x.speed = v),
                  accent: accent,
                ),
                ToggleRow(label: 'Tree sways in the wind', value: s.sway, onChanged: (v) => s.update((x) => x.sway = v), accent: accent),
                ToggleRow(label: 'Petals settle on the ground', value: s.accumulate, onChanged: (v) => s.update((x) => x.accumulate = v), accent: accent),
                ToggleRow(
                  label: 'Foreground depth blur',
                  hint: 'Large soft petals close to the camera',
                  value: s.bokeh,
                  onChanged: (v) => s.update((x) => x.bokeh = v),
                  accent: accent,
                ),
              ]),

              // ---- Window ----
              PanelSection(title: 'Window', children: [
                ToggleRow(
                  label: 'Lock (click-through)',
                  hint: 'Clicks go to the apps behind. Unlock: ${Desktop.lockShortcutLabel}, or hover the top-right corner',
                  value: s.locked,
                  onChanged: widget.onLock,
                  accent: accent,
                ),
                ToggleRow(label: 'Always on top', value: s.alwaysOnTop, onChanged: widget.onAlwaysOnTop, accent: accent),
                ToggleRow(label: 'Launch at login', value: s.launchAtLogin, onChanged: widget.onLaunchAtLogin, accent: accent),
                ToggleRow(label: 'Show FPS', value: s.showFps, onChanged: (v) => s.update((x) => x.showFps = v), accent: accent),
                const SizedBox(height: 8),
                AccentButton(
                  label: 'Open current view in new window',
                  icon: Icons.open_in_new,
                  onTap: () => widget.onPopOut(s.scene),
                  accent: accent,
                ),
              ]),

              const Padding(
                padding: EdgeInsets.fromLTRB(18, 12, 18, 20),
                child: Text(
                  'Shortcuts: 1 2 3 switch view · T transparent background · L lock · , settings · N new window · Esc close.\n'
                  'Right-click the scene to open settings. Drag anywhere to move the window.\n'
                  'Build $kBuildId',
                  style: TextStyle(fontSize: 11, color: kMuted, height: 1.6),
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
                child: Text(scene.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: kText)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(9, 1, 9, 0),
                child: Text(scene.vn, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: kMuted)),
              ),
            ]),
            Positioned(
              top: 5,
              right: 5,
              child: Tooltip(
                message: 'Open in new window',
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
  const _MoreCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x33141E32), width: 1.5),
      ),
      alignment: Alignment.center,
      child: const Text('+\nMore views\ncoming soon', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: kMuted, height: 1.4)),
    );
  }
}
