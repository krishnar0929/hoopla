import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../models/event_details.dart';
import 'location_service.dart';

/// Weather for the party, from Open-Meteo (free, no API key).
/// Forecasts go up to 16 days ahead.
class EventWeather {
  const EventWeather({
    required this.code,
    required this.high,
    required this.low,
    required this.rainChance,
    required this.partyTemp,
    required this.fahrenheit,
  });

  /// WMO weather code for the day.
  final int code;
  final double high;
  final double low;

  /// Highest chance of rain (0–100) during the party hours.
  final int rainChance;

  /// Temperature around the start of the party.
  final double partyTemp;
  final bool fahrenheit;

  String get unit => fahrenheit ? '°F' : '°C';
  String get emoji => weatherEmoji(code);
  String get summary => weatherText(code);

  /// One line of advice for the plan.
  String advice({required bool indoor}) => weatherAdvice(code: code, rainChance: rainChance, temp: partyTemp, fahrenheit: fahrenheit, indoor: indoor);
}

const forecastDays = 16;

/// The day the forecast for [date] becomes available.
DateTime forecastFrom(DateTime date) => DateTime(date.year, date.month, date.day).subtract(const Duration(days: forecastDays - 1));

String weatherEmoji(int code) {
  if (code == 0) return '☀️';
  if (code <= 2) return '🌤️';
  if (code == 3) return '☁️';
  if (code == 45 || code == 48) return '🌫️';
  if (code >= 95) return '⛈️';
  if ((code >= 71 && code <= 77) || code == 85 || code == 86) return '❄️';
  if (code >= 51) return '🌧️';
  return '🌤️';
}

String weatherText(int code) {
  if (code == 0) return 'Clear and sunny';
  if (code <= 2) return 'Mostly sunny';
  if (code == 3) return 'Cloudy';
  if (code == 45 || code == 48) return 'Foggy';
  if (code >= 51 && code <= 57) return 'Drizzle';
  if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82)) return 'Rain';
  if ((code >= 71 && code <= 77) || code == 85 || code == 86) return 'Snow';
  if (code >= 95) return 'Thunderstorms';
  return 'Mixed';
}

String weatherAdvice({required int code, required int rainChance, required double temp, required bool fahrenheit, required bool indoor}) {
  final f = fahrenheit ? temp : temp * 9 / 5 + 32;
  final stormy = code >= 95;
  final wet = rainChance >= 40 || (code >= 51 && code <= 82);
  if (!indoor) {
    if (stormy) return 'Storms are likely. Book a tent or move the games indoors.';
    if (wet) return '$rainChance% chance of rain. Have a tent or an indoor backup ready.';
    if (f >= 88) return 'Hot day. Plan shade, cold water and water games.';
    if (f <= 50) return 'Chilly outside. Patio heaters, blankets and warm drinks help.';
    return 'Great weather for outdoor games!';
  }
  if (stormy || wet) return 'Rain expected. Keep a spot for umbrellas and wet shoes at the door.';
  if (f >= 88) return 'Hot day. Keep the AC on and drinks cold.';
  if (f <= 32) return 'Freezing out. Remind guests about icy roads and parking.';
  return 'Nice day for it. Guests will arrive happy.';
}

class WeatherService {
  WeatherService._();

  /// Null when the date is past or more than 16 days away.
  static Future<EventWeather?> forEvent(EventDetails e, Place venue, {DateTime? now}) async {
    final today = DateTime((now ?? DateTime.now()).year, (now ?? DateTime.now()).month, (now ?? DateTime.now()).day);
    final day = DateTime(e.date.year, e.date.month, e.date.day);
    if (day.isBefore(today) || day.difference(today).inDays >= forecastDays) return null;
    final ymd = DateFormat('yyyy-MM-dd').format(day);
    final f = venue.usesFahrenheit;
    final res = await http.get(Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': venue.lat.toStringAsFixed(4),
      'longitude': venue.lng.toStringAsFixed(4),
      'daily': 'weather_code,temperature_2m_max,temperature_2m_min',
      'hourly': 'temperature_2m,precipitation_probability',
      'temperature_unit': f ? 'fahrenheit' : 'celsius',
      'timezone': 'auto',
      'start_date': ymd,
      'end_date': ymd,
    })).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) throw StateError('Weather is unavailable right now.');
    return parseWeather(jsonDecode(res.body) as Map<String, dynamic>, e, fahrenheit: f);
  }
}

/// Reads Open-Meteo's answer for one day.
EventWeather? parseWeather(Map<String, dynamic> json, EventDetails e, {required bool fahrenheit}) {
  final daily = json['daily'] as Map<String, dynamic>?;
  final hourly = json['hourly'] as Map<String, dynamic>?;
  if (daily == null || (daily['weather_code'] as List?)?.isEmpty != false) return null;
  num first(String key) => ((daily[key] as List).first as num?) ?? 0;

  final startHour = e.startMinutes ~/ 60;
  final endHour = (startHour + e.hours).clamp(startHour + 1, 24);
  var rain = 0;
  double? temp;
  if (hourly != null) {
    final temps = (hourly['temperature_2m'] as List?) ?? const [];
    final rains = (hourly['precipitation_probability'] as List?) ?? const [];
    for (var h = startHour; h < endHour && h < rains.length; h++) {
      final r = (rains[h] as num?)?.round() ?? 0;
      if (r > rain) rain = r;
    }
    if (startHour < temps.length) temp = (temps[startHour] as num?)?.toDouble();
  }
  return EventWeather(
    code: first('weather_code').toInt(),
    high: first('temperature_2m_max').toDouble(),
    low: first('temperature_2m_min').toDouble(),
    rainChance: rain,
    partyTemp: temp ?? first('temperature_2m_max').toDouble(),
    fahrenheit: fahrenheit,
  );
}
