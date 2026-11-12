import '../models/event_details.dart';

/// What we could pick out of a sentence like
/// "My son's 1st birthday, about 40 people in our backyard, Saturday Dec 12 at 4pm".
/// Anything not mentioned stays null so the form keeps its current value.
class ParsedEvent {
  String? occasion;
  String? title;
  DateTime? date;
  int? startMinutes;
  int? hours;
  bool? indoor;
  int? guests;
  Audience? audience;
  int? energy;

  bool get isEmpty => occasion == null &&
      title == null &&
      date == null &&
      startMinutes == null &&
      hours == null &&
      indoor == null &&
      guests == null &&
      audience == null &&
      energy == null;
}

/// Reads a short description of an event with simple word matching.
/// No network or AI needed, so it is free and instant.
class EventParser {
  static ParsedEvent parse(String input, {DateTime? now}) {
    final today = _dateOnly(now ?? DateTime.now());
    final text = input.toLowerCase().replaceAll('’', "'");
    final p = ParsedEvent();

    p.occasion = _occasion(text);
    p.title = _title(input.replaceAll('’', "'"));
    p.guests = _guests(text);
    p.indoor = _indoor(text);
    p.audience = _audience(text, p.occasion);
    p.energy = _energy(text);
    p.date = _date(text, today);

    final range = _timeRange(text);
    if (range != null) {
      p.startMinutes = range.$1;
      p.hours = range.$2;
    } else {
      p.startMinutes = _singleTime(text);
    }
    p.hours ??= _hours(text);
    return p;
  }

  // ---------- helpers ----------

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Calendar days, safe across daylight-saving changes.
  static DateTime _plusDays(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

  static bool _hasAny(String text, List<String> words) {
    for (final w in words) {
      if (RegExp(r'\b' + RegExp.escape(w) + r'\b').hasMatch(text)) return true;
    }
    return false;
  }

  static const _occasionWords = <String, List<String>>{
    'Baby shower': ['baby shower', 'seemantham', 'seemantam', 'godh bharai', 'godhbharai', 'valaikappu', 'gender reveal'],
    'Housewarming': ['housewarming', 'house warming', 'griha pravesh', 'grihapravesh', 'gruhapravesam', 'gruha pravesam', 'new home', 'new house'],
    'Anniversary': ['anniversary'],
    'Birthday': ['birthday', 'bday', 'b-day', 'turns', 'turning'],
    'Pooja': ['pooja', 'puja', 'vratham', 'vratam', 'homam', 'satyanarayana', 'havan'],
    'Get-together': ['get-together', 'get together', 'gettogether', 'potluck', 'reunion', 'hangout', 'game night', 'friends', 'dinner party'],
  };

  static String? _occasion(String text) {
    for (final entry in _occasionWords.entries) {
      if (_hasAny(text, entry.value)) return entry.key;
    }
    return null;
  }

  /// "Aarav's 5th birthday" or "my son's first birthday".
  static String? _title(String original) {
    const what = r'(birthday|bday|anniversary|baby shower|housewarming)';
    const nth = r"((?:\d{1,2}(?:st|nd|rd|th)|first|second|third)\s+)?";
    final named = RegExp(r"\b([A-Z][a-zA-Z]+(?:\s*(?:&|and)\s*[A-Z][a-zA-Z]+)?)'s\s+" + nth + what, caseSensitive: true)
        .firstMatch(original);
    final family = RegExp(
      r"\bmy\s+(son|daughter|wife|husband|mom|mother|dad|father|parents|grandma|grandpa|grandmother|grandfather|friend|brother|sister|baby|kid|boy|girl)'s\s+" +
          nth +
          what,
      caseSensitive: false,
    ).firstMatch(original);
    final m = named ?? family;
    if (m == null) return null;
    var t = m.group(0)!.replaceAll(RegExp(r'\bb-?day\b', caseSensitive: false), 'birthday');
    t = t[0].toUpperCase() + t.substring(1);
    return t;
  }

  static int? _guests(String text) {
    final re = RegExp(
      r'\b(\d{1,4})\s*\+?\s*(people|persons|person|guests|guest|members|adults|kids|children|ppl|pax|folks|families|family members|attendees)\b',
    );
    var total = 0;
    for (final m in re.allMatches(text)) {
      final n = int.parse(m.group(1)!);
      total += m.group(2) == 'families' ? n * 3 : n;
    }
    if (total == 0) {
      final m = RegExp(r'\b(?:guests|people|headcount)\s*[:\-]?\s*(\d{1,4})\b').firstMatch(text);
      if (m != null) total = int.parse(m.group(1)!);
    }
    if (total == 0) return null;
    return total.clamp(2, 1000).toInt();
  }

  static const _outdoorWords = [
    'outdoor', 'outdoors', 'outside', 'backyard', 'back yard', 'garden', 'park', 'terrace', 'rooftop',
    'lawn', 'beach', 'poolside', 'pool', 'farmhouse', 'farm house', 'open air', 'patio',
  ];
  static const _indoorWords = [
    'indoor', 'indoors', 'inside', 'home', 'house', 'apartment', 'flat', 'hall', 'banquet', 'restaurant',
    'living room', 'basement', 'community hall', 'temple',
  ];

  static bool? _indoor(String text) {
    if (_hasAny(text, _outdoorWords)) return false;
    if (_hasAny(text, _indoorWords)) return true;
    return null;
  }

  static Audience? _audience(String text, String? occasion) {
    final age = RegExp(r'\b(\d{1,2})(?:st|nd|rd|th)\s+(?:birthday|bday)\b').firstMatch(text) ??
        RegExp(r'\bturn(?:s|ing)\s+(\d{1,2})\b').firstMatch(text);
    if (age != null) {
      final n = int.parse(age.group(1)!);
      if (n <= 12) return Audience.kids;
      if (n >= 18) return Audience.adults;
      return Audience.everyone;
    }
    final kidWords = [
      'kid', 'kids', 'children', 'child', 'toddler', 'toddlers', 'son', 'daughter', 'little ones',
      'first birthday', if (occasion != 'Baby shower') ...['baby', 'babies'],
    ];
    if (_hasAny(text, kidWords)) return Audience.kids;
    if (_hasAny(text, ['adults', 'adults only', 'colleagues', 'office', 'coworkers', 'co-workers', 'work friends', 'couples', 'team'])) {
      return Audience.adults;
    }
    if (_hasAny(text, ['family', 'families', 'all ages', 'everyone', 'grandparents', 'relatives'])) {
      return Audience.everyone;
    }
    if (occasion == 'Baby shower') return Audience.adults;
    return null;
  }

  static int? _energy(String text) {
    if (_hasAny(text, ['wild', 'crazy', 'epic', 'mayhem', 'rocking', 'blast'])) return 3;
    if (_hasAny(text, ['loud', 'dance', 'dancing', 'dj', 'music'])) return 2;
    if (_hasAny(text, ['fun', 'lively', 'games'])) return 1;
    if (_hasAny(text, ['calm', 'quiet', 'simple', 'small', 'intimate', 'low key', 'low-key', 'chill', 'relaxed'])) return 0;
    return null;
  }

  // ---------- dates ----------

  static const _months = <String, int>{
    'january': 1, 'jan': 1, 'february': 2, 'feb': 2, 'march': 3, 'mar': 3, 'april': 4, 'apr': 4,
    'may': 5, 'june': 6, 'jun': 6, 'july': 7, 'jul': 7, 'august': 8, 'aug': 8, 'september': 9,
    'sept': 9, 'sep': 9, 'october': 10, 'oct': 10, 'november': 11, 'nov': 11, 'december': 12, 'dec': 12,
  };

  static const _weekdays = <String, int>{
    'monday': 1, 'mon': 1, 'tuesday': 2, 'tues': 2, 'tue': 2, 'wednesday': 3, 'thursday': 4,
    'thurs': 4, 'thur': 4, 'thu': 4, 'friday': 5, 'fri': 5, 'saturday': 6, 'sat': 6, 'sunday': 7,
  };

  static DateTime? _date(String text, DateTime today) {
    final monthNames = _months.keys.join('|');
    final monthFirst = RegExp('\\b($monthNames)\\.?\\s+(\\d{1,2})(?:st|nd|rd|th)?\\b').firstMatch(text);
    final dayFirst = RegExp('\\b(\\d{1,2})(?:st|nd|rd|th)?\\s+(?:of\\s+)?($monthNames)\\b').firstMatch(text);
    int? month;
    int? day;
    if (monthFirst != null) {
      month = _months[monthFirst.group(1)!];
      day = int.parse(monthFirst.group(2)!);
    } else if (dayFirst != null) {
      day = int.parse(dayFirst.group(1)!);
      month = _months[dayFirst.group(2)!];
    }
    if (month != null && day != null) {
      final daysInMonth = DateTime(today.year, month + 1, 0).day;
      if (day < 1 || day > daysInMonth) return null;
      var d = DateTime(today.year, month, day);
      if (d.isBefore(today)) d = DateTime(today.year + 1, month, day);
      return d;
    }

    if (_hasAny(text, ['day after tomorrow'])) return _plusDays(today, 2);
    if (_hasAny(text, ['tomorrow'])) return _plusDays(today, 1);
    if (_hasAny(text, ['today', 'tonight'])) return today;

    final weekday = RegExp('\\b(${_weekdays.keys.join('|')})\\b').firstMatch(text);
    if (weekday != null) {
      var diff = (_weekdays[weekday.group(1)!]! - today.weekday) % 7;
      if (diff == 0) diff = 7;
      return _plusDays(today, diff);
    }
    if (_hasAny(text, ['this weekend', 'weekend'])) {
      final diff = (DateTime.saturday - today.weekday) % 7;
      return _plusDays(today, diff);
    }
    if (_hasAny(text, ['next week'])) return _plusDays(today, 7);
    return null;
  }

  // ---------- times ----------

  static int? _toMinutes(int hour, int minute, String? ampm) {
    if (minute < 0 || minute > 59) return null;
    if (ampm == null) {
      if (hour < 0 || hour > 23) return null;
      return hour * 60 + minute;
    }
    if (hour < 1 || hour > 12) return null;
    final h = hour % 12 + (ampm == 'pm' ? 12 : 0);
    return h * 60 + minute;
  }

  /// "4-7pm", "4pm to 7pm", "11 to 2pm" → (start minutes, hours).
  static (int, int)? _timeRange(String text) {
    final m = RegExp(
      r'\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\s*(?:-|–|to|till|until)\s*(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b',
    ).firstMatch(text);
    if (m == null) return null;
    final sh = int.parse(m.group(1)!);
    final sm = int.parse(m.group(2) ?? '0');
    final eh = int.parse(m.group(4)!);
    final em = int.parse(m.group(5) ?? '0');
    final end = _toMinutes(eh, em, m.group(6));
    if (end == null) return null;
    int? start;
    final startAmPm = m.group(3);
    if (startAmPm != null) {
      start = _toMinutes(sh, sm, startAmPm);
    } else {
      // "4-7pm": same half of the day as the end, unless that would start after it ("11 to 2pm").
      final same = _toMinutes(sh, sm, m.group(6));
      final other = _toMinutes(sh, sm, m.group(6) == 'pm' ? 'am' : 'pm');
      start = (same != null && same < end) ? same : other;
    }
    if (start == null || end <= start) return null;
    final hours = ((end - start) / 60).round().clamp(2, 5).toInt();
    return (start, hours);
  }

  static int? _singleTime(String text) {
    final m = RegExp(r'\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b').firstMatch(text);
    if (m != null) {
      return _toMinutes(int.parse(m.group(1)!), int.parse(m.group(2) ?? '0'), m.group(3));
    }
    final at = RegExp(
      r'\bat\s+(\d{1,2})(?::(\d{2}))?\b(?!\s*(?:st|nd|rd|th|people|guests|kids|adults|jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec))',
    ).firstMatch(text);
    if (at != null) {
      final h = int.parse(at.group(1)!);
      final min = int.parse(at.group(2) ?? '0');
      if (h >= 1 && h <= 8) return _toMinutes(h, min, 'pm');
      if (h >= 9 && h <= 11) return _toMinutes(h, min, 'am');
      if (h == 12) return _toMinutes(12, min, 'pm');
      return _toMinutes(h, min, null);
    }
    if (_hasAny(text, ['morning', 'breakfast', 'brunch'])) return 10 * 60;
    if (_hasAny(text, ['noon', 'lunch'])) return 12 * 60;
    if (_hasAny(text, ['afternoon'])) return 15 * 60;
    if (_hasAny(text, ['evening'])) return 18 * 60;
    if (_hasAny(text, ['dinner', 'night'])) return 19 * 60;
    return null;
  }

  static int? _hours(String text) {
    if (_hasAny(text, ['all day', 'full day', 'whole day'])) return 5;
    if (_hasAny(text, ['half day', 'half a day'])) return 4;
    final m = RegExp(r'\b(\d{1,2}(?:\.\d)?)\s*(?:hours|hour|hrs|hr)\b').firstMatch(text);
    if (m == null) return null;
    return double.parse(m.group(1)!).round().clamp(2, 5).toInt();
  }
}
