import 'package:flutter/material.dart';

const kText = Color(0xFF1C2333);
const kMuted = Color(0xFF6B7385);
const kLine = Color(0x17141E32);

class PanelSection extends StatelessWidget {
  const PanelSection({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kLine))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(title.toUpperCase(),
                style: const TextStyle(fontSize: 11, letterSpacing: 0.8, fontWeight: FontWeight.w700, color: kMuted)),
          ),
          ...children,
        ],
      ),
    );
  }
}

class ToggleRow extends StatelessWidget {
  const ToggleRow({super.key, required this.label, this.hint, this.tag, required this.value, required this.onChanged, required this.accent});
  final String label;
  final String? hint, tag;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(label, style: const TextStyle(fontSize: 13, color: kText))),
                if (tag != null)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: const Color(0x12141E32), borderRadius: BorderRadius.circular(5)),
                    child: Text(tag!, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: kMuted)),
                  ),
              ]),
              if (hint != null)
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(hint!, style: const TextStyle(fontSize: 11, color: kMuted)),
                ),
            ]),
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: accent,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0x2E141E32),
            ),
          ),
        ]),
      ),
    );
  }
}

class SliderRow extends StatelessWidget {
  const SliderRow({
    super.key,
    required this.label,
    required this.valueText,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.accent,
    this.divisions,
  });
  final String label, valueText;
  final double value, min, max;
  final int? divisions;
  final ValueChanged<double> onChanged;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: kText))),
          Text(valueText, style: const TextStyle(fontSize: 13, color: kMuted, fontFeatures: [FontFeature.tabularFigures()])),
        ]),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            activeTrackColor: accent,
            inactiveTrackColor: const Color(0x24141E32),
            thumbColor: Colors.white,
            overlayColor: accent.withAlpha(30),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9, elevation: 2),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(value: value.clamp(min, max).toDouble(), min: min, max: max, divisions: divisions, onChanged: onChanged),
        ),
      ]),
    );
  }
}

/// Small pill button used for size presets.
class ChoicePill extends StatelessWidget {
  const ChoicePill({super.key, required this.label, this.sub, required this.selected, required this.onTap, required this.accent});
  final String label;
  final String? sub;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? accent : const Color(0x12141E32),
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : kText)),
            if (sub != null)
              Text(sub!, style: TextStyle(fontSize: 10, color: selected ? Colors.white70 : kMuted)),
          ]),
        ),
      ),
    );
  }
}

class AccentButton extends StatelessWidget {
  const AccentButton({super.key, required this.label, required this.icon, required this.onTap, required this.accent});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 8),
            Flexible(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white))),
          ]),
        ),
      ),
    );
  }
}
