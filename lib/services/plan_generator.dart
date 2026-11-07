import '../data/games.dart';
import '../data/helpers.dart';
import '../models/event_details.dart';

enum StepKind { welcome, game, moment, food, wrap, free }

class TimelineStep {
  const TimelineStep({required this.start, required this.minutes, required this.title, required this.subtitle, required this.kind, this.game});

  /// Minutes after midnight.
  final int start;
  final int minutes;
  final String title;
  final String subtitle;
  final StepKind kind;
  final Game? game;
}

class PlanTask {
  const PlanTask(this.id, this.label, this.daysBefore);
  final String id;
  final String label;
  final int daysBefore;
}

class BudgetLine {
  const BudgetLine(this.label, this.share);
  final String label;

  /// Fraction of the total budget, 0..1.
  final double share;
}

class Plan {
  const Plan({required this.timeline, required this.backupGames, required this.tasks, required this.helpers, required this.budget, required this.gamesMinutes});

  final List<TimelineStep> timeline;

  /// Games the user added that don't fit in the time available.
  final List<Game> backupGames;
  final List<PlanTask> tasks;
  final List<String> helpers;
  final List<BudgetLine> budget;

  /// Minutes the timeline sets aside for games.
  final int gamesMinutes;

  List<Game> get plannedGames => [for (final s in timeline) if (s.game != null) s.game!];
}

class _Moment {
  const _Moment(this.title, this.subtitle, this.minutes, {this.first = false});
  final String title;
  final String subtitle;
  final int minutes;

  /// Happens right after guests arrive (a pooja), not after the games.
  final bool first;
}

/// Turns an event into a timeline, games, checklist, helpers and budget split.
class PlanGenerator {
  static const _budgetSplit = [
    BudgetLine('Food', 0.40),
    BudgetLine('Decor', 0.20),
    BudgetLine('Photography', 0.15),
    BudgetLine('Cake & sweets', 0.08),
    BudgetLine('Return gifts', 0.07),
    BudgetLine('Games & extras', 0.10),
  ];

  static _Moment _momentFor(EventDetails e) => switch (e.occasion) {
        'Birthday' => _Moment('Cake cutting', 'Song, candles and the cake moment. Photographer on standby.', 20),
        'Housewarming' => _Moment('House tour + toast', 'Show guests around, then a welcome toast for the new home.', 20),
        'Baby shower' => _Moment('Blessings + gifts', 'Elders bless the parents-to-be; open a few gifts.', 30),
        'Pooja' => _Moment('Pooja with panthulu', 'Prayers first, then prasadam for everyone.', 45, first: true),
        'Anniversary' => _Moment('Cake + couple toast', 'A few words from family, then the cake.', 20),
        _ => _Moment('Group photo + toast', 'Everyone in one photo before the food.', 15),
      };

  static int welcomeMinutes(EventDetails e) => e.hours * 60 >= 150 ? 30 : 15;
  static int foodMinutes(EventDetails e) => e.hours * 60 >= 150 ? 45 : 30;
  static const wrapMinutes = 20;

  /// Minutes left for games after welcome, the key moment, food and goodbyes.
  static int gamesBudget(EventDetails e) {
    final left = e.hours * 60 - welcomeMinutes(e) - foodMinutes(e) - wrapMinutes - _momentFor(e).minutes;
    return left < 0 ? 0 : left;
  }

  static bool _fitsAudience(Game g, Audience a) => switch (a) {
        Audience.kids => g.kids,
        Audience.adults => g.adults,
        Audience.everyone => g.kids && g.adults,
      };

  static bool _fitsPlace(Game g, EventDetails e) => e.indoor ? g.indoor : g.outdoor;

  /// Every game that could work for this event, best fit first.
  static List<Game> rankedGames(EventDetails e) {
    final target = e.energy + 1;
    final indexed = <(int, Game)>[
      for (var i = 0; i < gameCatalog.length; i++) (i, gameCatalog[i]),
    ].where((p) {
      final g = p.$2;
      final audienceOk = _fitsAudience(g, e.audience) || (e.audience == Audience.kids && g.adults && g.energy <= 2);
      return audienceOk && _fitsPlace(g, e) && g.minPlayers <= e.guests;
    }).toList();

    int score(Game g) {
      var s = 10 - (g.energy - target).abs() * 3;
      if (g.occasions.contains(e.occasion)) s += 5;
      if (_fitsAudience(g, e.audience)) s += 4;
      return s;
    }

    indexed.sort((a, b) {
      final byScore = score(b.$2).compareTo(score(a.$2));
      return byScore != 0 ? byScore : a.$1.compareTo(b.$1);
    });
    return [for (final p in indexed) p.$2];
  }

  /// Picks games that fill the games time. For kids parties, adds one
  /// icebreaker for the parents.
  static List<String> suggestGameIds(EventDetails e) {
    final budget = gamesBudget(e);
    final ranked = rankedGames(e);
    final picked = <Game>[];
    var used = 0;

    void tryAdd(Game g) {
      if (picked.contains(g) || used + g.minutes > budget) return;
      picked.add(g);
      used += g.minutes;
    }

    if (e.audience == Audience.kids) {
      final icebreaker = ranked.where((g) => !g.kids && g.adults);
      if (icebreaker.isNotEmpty) tryAdd(icebreaker.first);
    }
    for (final g in ranked) {
      if (e.audience == Audience.kids && !g.kids) continue;
      tryAdd(g);
    }
    return [for (final g in picked) g.id];
  }

  static Plan build(EventDetails e) {
    final moment = _momentFor(e);
    final steps = <TimelineStep>[];
    var t = e.startMinutes;

    void add(int minutes, String title, String subtitle, StepKind kind, [Game? game]) {
      steps.add(TimelineStep(start: t, minutes: minutes, title: title, subtitle: subtitle, kind: kind, game: game));
      t += minutes;
    }

    add(welcomeMinutes(e), e.indoor ? 'Welcome + photo corner' : 'Welcome + outdoor photo spot',
        'Greet guests, snacks and drinks, a backdrop for family photos.', StepKind.welcome);

    if (moment.first) add(moment.minutes, moment.title, moment.subtitle, StepKind.moment);

    final budget = gamesBudget(e);
    final games = [for (final id in e.gameIds) gameById(id)].whereType<Game>().toList();
    final backup = <Game>[];
    var used = 0;
    for (final g in games) {
      if (used + g.minutes <= budget) {
        add(g.minutes, g.name, '${g.audienceLabel} · ${g.minutes} min${g.needs.isEmpty ? '' : ' · ${g.needs.first}'}', StepKind.game, g);
        used += g.minutes;
      } else {
        backup.add(g);
      }
    }
    final free = budget - used;
    if (free >= 10) {
      add(free, games.isEmpty ? 'Games time' : 'Free play + photos', games.isEmpty ? 'Add games from the Games tab to fill this.' : 'Let everyone mingle; pull a backup game if energy drops.', StepKind.free);
    } else {
      t += free;
    }

    if (!moment.first) add(moment.minutes, moment.title, moment.subtitle, StepKind.moment);
    add(foodMinutes(e), 'Food', e.audience == Audience.kids ? 'Kids eat first, then the buffet for everyone.' : 'Buffet or served meal.', StepKind.food);
    add(wrapMinutes, e.audience == Audience.kids ? 'Return gifts + goodbyes' : 'Thank-yous + goodbyes',
        'Hand out return gifts and thank everyone for coming.', StepKind.wrap);

    return Plan(
      timeline: steps,
      backupGames: backup,
      tasks: _tasks(e, games),
      helpers: helpersByOccasion[e.occasion] ?? helpersByOccasion['Get-together']!,
      budget: _budgetSplit,
      gamesMinutes: budget,
    );
  }

  static List<PlanTask> _tasks(EventDetails e, List<Game> games) {
    final helpers = helpersByOccasion[e.occasion] ?? const <String>[];
    final tasks = <PlanTask>[
      const PlanTask('invites', 'Send invites', 28),
      for (final h in helpers) PlanTask('book_$h', 'Book ${_singular(h)}', h == 'Cleaners & maids' ? 7 : 21),
      const PlanTask('menu', 'Finalize the menu', 14),
      if (e.audience == Audience.kids) const PlanTask('gifts', 'Buy return gifts', 7),
      const PlanTask('rsvp', 'Confirm head count', 5),
    ];
    final needs = <String>{for (final g in games) ...g.needs};
    if (needs.isNotEmpty) {
      tasks.add(PlanTask('supplies', 'Game supplies: ${needs.take(4).join(', ')}${needs.length > 4 ? '…' : ''}', 3));
    }
    if (!e.indoor) tasks.add(const PlanTask('weather', 'Check the weather + backup shade', 2));
    tasks.sort((a, b) => b.daysBefore.compareTo(a.daysBefore));
    return tasks;
  }

  static String _singular(String h) => switch (h) {
        'Photographers' => 'photographer',
        'Decorators' => 'decorator',
        'Cake makers' => 'cake',
        'Cleaners & maids' => 'cleaning help',
        'Panthulu' => 'panthulu',
        'Caterers' => 'caterer',
        'Makeup' => 'makeup artist',
        'Singers' => 'singer',
        'Anchors / MC' => 'anchor / MC',
        'Rentals' => 'chairs, tables + rentals',
        _ => h.toLowerCase(),
      };
}

/// "4:30" style clock for minutes after midnight.
String clock(int minutes) {
  final h = (minutes ~/ 60) % 24;
  final m = minutes % 60;
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:${m.toString().padLeft(2, '0')}';
}

String clockAmPm(int minutes) => '${clock(minutes)} ${((minutes ~/ 60) % 24) < 12 ? 'AM' : 'PM'}';
