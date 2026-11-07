import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';

/// Rounded chip that can be selected.
class Pill extends StatelessWidget {
  const Pill({super.key, required this.label, required this.selected, required this.onTap, this.selectedColor = HC.ink, this.small = false});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedColor;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? selectedColor : HC.card,
      shape: StadiumBorder(side: BorderSide(color: selected ? selectedColor : HC.line)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Container(
          height: small ? 34 : 40,
          padding: EdgeInsets.symmetric(horizontal: small ? 12 : 16),
          alignment: Alignment.center,
          child: Text(
            label,
            style: body(small ? 12.5 : 14, color: selected ? Colors.white : HC.ink, weight: selected ? FontWeight.w600 : FontWeight.w500),
          ),
        ),
      ),
    );
  }
}

/// White rounded card with a hairline border.
class CardBox extends StatelessWidget {
  const CardBox({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.color = HC.card, this.onTap, this.radius = 18});

  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: color == HC.card ? const BorderSide(color: HC.line) : BorderSide.none,
    );
    return Material(
      color: color,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

/// Two- or three-way switch, like Indoor / Outdoor.
class Segmented extends StatelessWidget {
  const Segmented({super.key, required this.options, required this.selected, required this.onChanged, this.height = 44});

  final List<String> options;
  final int selected;
  final ValueChanged<int> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: HC.track, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: height,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == selected ? HC.card : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: i == selected ? const [BoxShadow(color: Color(0x1417142B), blurRadius: 6, offset: Offset(0, 2))] : null,
                  ),
                  child: Semantics(
                    button: true,
                    selected: i == selected,
                    child: Text(options[i],
                        style: body(15, color: i == selected ? HC.ink : HC.muted, weight: i == selected ? FontWeight.w600 : FontWeight.w500)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text.toUpperCase(), style: overline()),
      );
}

/// Opens a link in the browser, maps, phone or WhatsApp.
Future<void> openLink(BuildContext context, Uri uri) async {
  var ok = false;
  try {
    ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't open that link on this device.")));
  }
}

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
