/// A party game with what it needs and who it suits.
class Game {
  const Game({
    required this.id,
    required this.name,
    required this.howTo,
    required this.kids,
    required this.adults,
    required this.indoor,
    required this.outdoor,
    required this.minPlayers,
    required this.minutes,
    required this.energy,
    this.needs = const [],
    this.occasions = const [],
  });

  final String id;
  final String name;
  final String howTo;
  final bool kids;
  final bool adults;
  final bool indoor;
  final bool outdoor;
  final int minPlayers;
  final int minutes;

  /// 1 calm … 4 wild.
  final int energy;
  final List<String> needs;

  /// Occasions this game is an especially good fit for.
  final List<String> occasions;

  String get audienceLabel => kids && adults ? 'All ages' : (kids ? 'Kids' : 'Adults');

  String get placeLabel => indoor && outdoor ? 'Indoor or outdoor' : (indoor ? 'Indoor' : 'Outdoor');

  /// Opens YouTube search results for a how-to video of this game.
  Uri get videoSearch =>
      Uri.https('www.youtube.com', '/results', {'search_query': '$name party game how to play'});
}

const gameCatalog = <Game>[
  Game(
    id: 'balloon_stomp',
    name: 'Balloon stomp',
    howTo: 'Tie a balloon to each player\'s ankle. Pop other balloons by stomping and protect your own. Last balloon standing wins.',
    kids: true, adults: false, indoor: true, outdoor: true, minPlayers: 6, minutes: 10, energy: 3,
    needs: ['Balloons', 'String'],
  ),
  Game(
    id: 'freeze_dance',
    name: 'Freeze dance',
    howTo: 'Play music and everyone dances. When the music stops, freeze. Anyone who moves sits out until one dancer is left.',
    kids: true, adults: false, indoor: true, outdoor: true, minPlayers: 4, minutes: 10, energy: 3,
    needs: ['Speaker', 'Playlist'],
  ),
  Game(
    id: 'bubble_chase',
    name: 'Bubble chase',
    howTo: 'Blow lots of bubbles and let the little ones chase and pop them. Perfect for toddlers.',
    kids: true, adults: false, indoor: true, outdoor: true, minPlayers: 2, minutes: 10, energy: 2,
    needs: ['Bubble wands or a bubble machine'],
    occasions: ['Birthday'],
  ),
  Game(
    id: 'pass_the_parcel',
    name: 'Pass the parcel',
    howTo: 'Wrap a prize in many layers with a small treat in each. Pass it around while music plays; when it stops, the holder unwraps one layer.',
    kids: true, adults: true, indoor: true, outdoor: false, minPlayers: 6, minutes: 15, energy: 2,
    needs: ['Wrapped parcel', 'Small treats', 'Music'],
    occasions: ['Birthday'],
  ),
  Game(
    id: 'musical_chairs',
    name: 'Musical chairs',
    howTo: 'Set out one chair fewer than players. Walk around while music plays; when it stops, grab a seat. Remove a chair each round.',
    kids: true, adults: true, indoor: true, outdoor: true, minPlayers: 6, minutes: 15, energy: 3,
    needs: ['Chairs', 'Music'],
  ),
  Game(
    id: 'hot_potato',
    name: 'Hot potato',
    howTo: 'Sit in a circle and pass a soft ball quickly while music plays. Whoever holds it when the music stops is out.',
    kids: true, adults: false, indoor: true, outdoor: true, minPlayers: 6, minutes: 10, energy: 2,
    needs: ['Soft ball', 'Music'],
  ),
  Game(
    id: 'treasure_hunt',
    name: 'Treasure hunt',
    howTo: 'Hide small prizes with picture or rhyme clues that lead from one spot to the next. Teams race to the treasure.',
    kids: true, adults: false, indoor: true, outdoor: true, minPlayers: 4, minutes: 20, energy: 3,
    needs: ['Clue cards', 'Small prizes'],
  ),
  Game(
    id: 'lemon_spoon',
    name: 'Lemon and spoon race',
    howTo: 'Hold a spoon in your mouth with a lemon on it and race to the finish line. Drop it and you start again.',
    kids: true, adults: true, indoor: false, outdoor: true, minPlayers: 4, minutes: 10, energy: 3,
    needs: ['Spoons', 'Lemons'],
  ),
  Game(
    id: 'sack_race',
    name: 'Sack race',
    howTo: 'Players step into sacks and hop to the finish line. First one across wins.',
    kids: true, adults: true, indoor: false, outdoor: true, minPlayers: 4, minutes: 10, energy: 4,
    needs: ['Sacks or pillowcases'],
  ),
  Game(
    id: 'tug_of_war',
    name: 'Tug of war',
    howTo: 'Two teams pull a rope from opposite ends. The team that drags the middle marker over their line wins.',
    kids: true, adults: true, indoor: false, outdoor: true, minPlayers: 10, minutes: 10, energy: 4,
    needs: ['Long rope', 'Ribbon for the middle'],
  ),
  Game(
    id: 'guess_the_baby',
    name: 'Guess the baby photo',
    howTo: 'Collect baby photos of guests ahead of time and pin them up with numbers. Guests write down who is who; most correct wins.',
    kids: false, adults: true, indoor: true, outdoor: false, minPlayers: 6, minutes: 15, energy: 1,
    needs: ['Printed baby photos', 'Answer sheets', 'Pens'],
    occasions: ['Birthday', 'Baby shower'],
  ),
  Game(
    id: 'diaper_relay',
    name: 'Diaper relay (dads only)',
    howTo: 'Teams race to put a diaper on a doll, one player at a time. Fastest team wins. Expect a lot of laughing.',
    kids: false, adults: true, indoor: true, outdoor: true, minPlayers: 6, minutes: 10, energy: 4,
    needs: ['Dolls', 'Diapers'],
    occasions: ['Baby shower', 'Birthday'],
  ),
  Game(
    id: 'baby_food_guess',
    name: 'Guess the baby food',
    howTo: 'Remove labels from baby food jars and number them. Guests taste or smell and guess the flavor.',
    kids: false, adults: true, indoor: true, outdoor: false, minPlayers: 4, minutes: 10, energy: 1,
    needs: ['Baby food jars', 'Spoons', 'Answer sheets'],
    occasions: ['Baby shower'],
  ),
  Game(
    id: 'dumb_charades',
    name: 'Dumb charades',
    howTo: 'Teams take turns acting out a movie name without speaking. Their team guesses before the timer runs out.',
    kids: true, adults: true, indoor: true, outdoor: false, minPlayers: 6, minutes: 20, energy: 2,
    needs: ['Movie name chits', 'Timer'],
    occasions: ['Get-together', 'Housewarming', 'Anniversary'],
  ),
  Game(
    id: 'antakshari',
    name: 'Antakshari',
    howTo: 'Two teams sing songs in turn. Each song must start with the last letter of the previous song.',
    kids: true, adults: true, indoor: true, outdoor: true, minPlayers: 6, minutes: 20, energy: 2,
    occasions: ['Get-together', 'Housewarming', 'Pooja'],
  ),
  Game(
    id: 'tambola',
    name: 'Tambola (Housie)',
    howTo: 'Everyone gets a ticket. Call out numbers one by one; players mark them. Prizes for early five, lines, and full house.',
    kids: true, adults: true, indoor: true, outdoor: false, minPlayers: 6, minutes: 30, energy: 1,
    needs: ['Tambola tickets', 'Number board', 'Small prizes'],
    occasions: ['Pooja', 'Housewarming', 'Get-together'],
  ),
  Game(
    id: 'cup_stack',
    name: 'Cup stack race',
    howTo: 'Each player stacks plastic cups into a pyramid and back down. Fastest time wins. Great in teams.',
    kids: true, adults: true, indoor: true, outdoor: false, minPlayers: 4, minutes: 10, energy: 2,
    needs: ['Plastic cups', 'Timer'],
  ),
  Game(
    id: 'couple_quiz',
    name: 'Couple quiz (Mr and Mrs)',
    howTo: 'The couple sits back to back holding each other\'s shoe. Ask questions like "Who cooks better?"; they raise the shoe of their answer.',
    kids: false, adults: true, indoor: true, outdoor: true, minPlayers: 2, minutes: 15, energy: 1,
    needs: ['Question list'],
    occasions: ['Anniversary'],
  ),
  Game(
    id: 'who_am_i',
    name: 'Who am I?',
    howTo: 'Stick a famous name on each player\'s forehead. They ask yes-or-no questions to figure out who they are.',
    kids: false, adults: true, indoor: true, outdoor: false, minPlayers: 6, minutes: 15, energy: 2,
    needs: ['Sticky notes', 'Markers'],
    occasions: ['Get-together'],
  ),
  Game(
    id: 'balloon_dares',
    name: 'Balloon pop dares',
    howTo: 'Put a funny dare inside each balloon. Players pop one and have to do the dare.',
    kids: false, adults: true, indoor: true, outdoor: true, minPlayers: 6, minutes: 15, energy: 3,
    needs: ['Balloons', 'Dare chits'],
    occasions: ['Get-together', 'Anniversary', 'Birthday'],
  ),
];

Game? gameById(String id) {
  for (final g in gameCatalog) {
    if (g.id == id) return g;
  }
  return null;
}
