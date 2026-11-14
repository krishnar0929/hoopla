import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/event_details.dart';
import '../services/weather_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'place_picker.dart';

/// Weather at the venue on party day, with one line of advice.
class WeatherCard extends StatefulWidget {
  const WeatherCard({super.key, required this.event});
  final EventDetails event;

  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard> {
  Future<EventWeather?>? future;
  String? _key;

  String _keyFor(EventDetails e) => '${e.id}|${e.date}|${e.startMinutes}|${e.hours}|${e.venue?.lat},${e.venue?.lng}';

  void _load() {
    final e = widget.event;
    final v = e.venue;
    _key = _keyFor(e);
    future = v == null ? null : WeatherService.forEvent(e, v);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(WeatherCard old) {
    super.didUpdateWidget(old);
    if (_keyFor(widget.event) != _key) _load();
  }

  Future<void> _pickVenue() async {
    final state = AppScope.of(context);
    final p = await pickPlace(context);
    if (p != null) await state.update((e) => e.venue = p);
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    final v = e.venue;
    final today = DateUtils.dateOnly(DateTime.now());
    if (DateUtils.dateOnly(e.date).isBefore(today)) return const SizedBox.shrink();

    if (v == null) {
      return _Shell(
        onTap: _pickVenue,
        leading: '📍',
        title: 'Add your venue',
        subtitle: 'See the weather forecast for party day and find helpers near it.',
        trailing: const Icon(Icons.chevron_right_rounded, color: HC.muted),
      );
    }
    return FutureBuilder<EventWeather?>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return _Shell(leading: '🌤️', title: 'Checking the weather in ${v.label}…', subtitle: '', onTap: _pickVenue);
        }
        final w = snap.data;
        if (snap.hasError) {
          return _Shell(leading: '🌤️', title: 'Weather for ${v.label}', subtitle: 'Couldn\'t load the forecast right now.', onTap: _pickVenue);
        }
        if (w == null) {
          final from = forecastFrom(e.date);
          return _Shell(
            leading: '🗓️',
            title: 'Weather in ${v.label}',
            subtitle: 'The forecast shows up here from ${DateFormat('MMM d').format(from)}, 16 days before the party.',
            onTap: _pickVenue,
          );
        }
        return _Shell(
          onTap: _pickVenue,
          leading: w.emoji,
          title: '${w.summary} · ${w.high.round()}° / ${w.low.round()}${w.unit}',
          subtitle: '${v.label} · ${w.rainChance}% chance of rain during the party\n${w.advice(indoor: e.indoor)}',
          highlight: w.rainChance >= 40 && !e.indoor,
        );
      },
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({required this.leading, required this.title, required this.subtitle, this.onTap, this.trailing, this.highlight = false});
  final String leading;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlight ? const Color(0xFFFFF1EC) : HC.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: highlight ? HC.coral : HC.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Text(leading, style: const TextStyle(fontSize: 30)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: body(15, weight: FontWeight.w600)),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(subtitle, style: body(12, color: HC.muted)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
