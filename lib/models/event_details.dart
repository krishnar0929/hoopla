/// Who the event is mainly for. Drives which games get suggested.
enum Audience { kids, adults, everyone }

extension AudienceLabel on Audience {
  String get label => switch (this) {
        Audience.kids => 'Kids + parents',
        Audience.adults => 'Adults',
        Audience.everyone => 'All ages',
      };
}

const occasions = ['Birthday', 'Housewarming', 'Baby shower', 'Pooja', 'Anniversary', 'Get-together'];

/// How lively the party should be: 0 Calm, 1 Lively, 2 Loud, 3 Wild.
const energyLevels = ['Calm', 'Lively', 'Loud', 'Wild'];

/// A helper the user saved from the Nearby tab (photographer, panthulu, ...).
class ShortlistVendor {
  ShortlistVendor({required this.id, required this.category, required this.name, this.phone = '', this.note = ''});

  final String id;
  final String category;
  final String name;
  final String phone;
  final String note;

  Map<String, dynamic> toMap() => {'id': id, 'category': category, 'name': name, 'phone': phone, 'note': note};

  factory ShortlistVendor.fromMap(Map<String, dynamic> m) => ShortlistVendor(
        id: m['id'] as String? ?? '',
        category: m['category'] as String? ?? '',
        name: m['name'] as String? ?? '',
        phone: m['phone'] as String? ?? '',
        note: m['note'] as String? ?? '',
      );
}

/// A game reel the user saved (for example from Instagram) to play later.
class SavedLink {
  SavedLink({required this.title, required this.url});

  final String title;
  final String url;

  Map<String, dynamic> toMap() => {'title': title, 'url': url};

  factory SavedLink.fromMap(Map<String, dynamic> m) =>
      SavedLink(title: m['title'] as String? ?? 'Saved game', url: m['url'] as String? ?? '');
}

/// Everything the user told us about their event, plus their choices.
class EventDetails {
  EventDetails({
    required this.id,
    required this.occasion,
    required this.title,
    required this.date,
    required this.startMinutes,
    required this.hours,
    required this.indoor,
    required this.guests,
    required this.audience,
    required this.energy,
    List<String>? gameIds,
    List<String>? doneTasks,
    List<ShortlistVendor>? shortlist,
    List<SavedLink>? savedLinks,
    this.budget,
    DateTime? updatedAt,
  })  : gameIds = gameIds ?? [],
        doneTasks = doneTasks ?? [],
        shortlist = shortlist ?? [],
        savedLinks = savedLinks ?? [],
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String occasion;
  String title;
  DateTime date;

  /// Start time as minutes after midnight (16:00 = 960).
  int startMinutes;
  int hours;
  bool indoor;
  int guests;
  Audience audience;
  int energy;

  /// Games the user has in their plan, in play order.
  List<String> gameIds;
  List<String> doneTasks;
  List<ShortlistVendor> shortlist;
  List<SavedLink> savedLinks;
  double? budget;
  DateTime updatedAt;

  static String newId() => DateTime.now().microsecondsSinceEpoch.toString();

  int get daysToGo {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    return day.difference(today).inDays;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'occasion': occasion,
        'title': title,
        'date': DateTime(date.year, date.month, date.day).toIso8601String(),
        'startMinutes': startMinutes,
        'hours': hours,
        'indoor': indoor,
        'guests': guests,
        'audience': audience.name,
        'energy': energy,
        'gameIds': gameIds,
        'doneTasks': doneTasks,
        'shortlist': shortlist.map((v) => v.toMap()).toList(),
        'savedLinks': savedLinks.map((l) => l.toMap()).toList(),
        'budget': budget,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory EventDetails.fromMap(Map<String, dynamic> m) {
    List<Map<String, dynamic>> maps(Object? v) =>
        (v as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return EventDetails(
      id: m['id'] as String? ?? newId(),
      occasion: m['occasion'] as String? ?? occasions.first,
      title: m['title'] as String? ?? '',
      date: DateTime.tryParse(m['date'] as String? ?? '') ?? DateTime.now(),
      startMinutes: (m['startMinutes'] as num?)?.toInt() ?? 16 * 60,
      hours: (m['hours'] as num?)?.toInt() ?? 3,
      indoor: m['indoor'] as bool? ?? true,
      guests: (m['guests'] as num?)?.toInt() ?? 30,
      audience: Audience.values.firstWhere((a) => a.name == m['audience'], orElse: () => Audience.kids),
      energy: (m['energy'] as num?)?.toInt() ?? 1,
      gameIds: List<String>.from(m['gameIds'] as List? ?? const []),
      doneTasks: List<String>.from(m['doneTasks'] as List? ?? const []),
      shortlist: maps(m['shortlist']).map(ShortlistVendor.fromMap).toList(),
      savedLinks: maps(m['savedLinks']).map(SavedLink.fromMap).toList(),
      budget: (m['budget'] as num?)?.toDouble(),
      updatedAt: DateTime.tryParse(m['updatedAt'] as String? ?? '')?.toLocal(),
    );
  }
}
