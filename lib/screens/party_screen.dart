import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../data/games.dart';
import '../models/event_details.dart';
import '../services/plan_generator.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/locked.dart';
import 'feedback_sheet.dart';

/// Party day mode: current game with a timer, scoreboard and what's next.
class PartyScreen extends StatefulWidget {
  const PartyScreen({super.key});

  @override
  State<PartyScreen> createState() => _PartyScreenState();
}

class _PartyScreenState extends State<PartyScreen> {
  static const _teamNames = [
    ('Team Laddoo', 'Team Jalebi'),
    ('Team Samosa', 'Team Pakoda'),
    ('Team Chai', 'Team Coffee'),
    ('Team Mango', 'Team Banana'),
    ('Team Dosa', 'Team Idli'),
  ];

  int gameIndex = 0;
  int? secondsLeft;
  bool running = false;
  Timer? timer;
  List<int> scores = [0, 0];
  int teamPair = 0;

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _toggle(Game g) {
    if (running) {
      timer?.cancel();
      setState(() => running = false);
      return;
    }
    secondsLeft ??= g.minutes * 60;
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        secondsLeft = max(0, (secondsLeft ?? 0) - 1);
        if (secondsLeft == 0) {
          timer?.cancel();
          running = false;
          HapticFeedback.heavyImpact();
          // A game just finished: a good moment to ask for a rating (once).
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) RatePrompt.afterHappyMoment(context);
          });
        }
      });
    });
    setState(() => running = true);
  }

  void _goTo(int index) {
    timer?.cancel();
    setState(() {
      gameIndex = index;
      secondsLeft = null;
      running = false;
    });
  }

  String _mmss(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (state.access != Access.premium) {
      return Container(
        color: HC.ink,
        child: const LockedPage(
          dark: true,
          title: 'Party day mode',
          message: 'Run the party from your phone while it happens.',
          points: [
            'The game that\'s on now, with a countdown timer',
            'Team scoreboard with a tap to add points',
            'What\'s up next, so cake and food happen on time',
            'Invite text, playlist and return gift ideas',
          ],
        ),
      );
    }
    final e = state.event!;
    final plan = state.plan;
    final games = [...plan.plannedGames, ...plan.backupGames];
    final current = games.isEmpty ? null : games[gameIndex.clamp(0, games.length - 1).toInt()];
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final upNext = plan.timeline.where((s) => s.kind != StepKind.game && s.start > nowMinutes).toList();
    final next = upNext.isNotEmpty ? upNext.first : plan.timeline.firstWhere((s) => s.kind == StepKind.moment, orElse: () => plan.timeline.last);
    final teams = _teamNames[teamPair];

    return Container(
      color: HC.ink,
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 18, 20, 24),
        children: [
          Row(
            children: [
              Container(width: 10, height: 10, decoration: const BoxDecoration(color: HC.coral, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text('PARTY IS LIVE', style: overline(color: const Color(0xFFFFB3A3))),
              const Spacer(),
              Text(DateFormat('h:mm a').format(now), style: body(13, color: HC.nightMuted)),
            ],
          ),
          const SizedBox(height: 14),
          if (current == null)
            CardBox(
              color: HC.violet,
              padding: const EdgeInsets.all(18),
              child: Text('Add games from the Games tab and they\'ll show up here, ready to play.', style: body(15, color: Colors.white)),
            )
          else
            CardBox(
              color: HC.violet,
              radius: 24,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Now playing · ${gameIndex + 1} of ${games.length}', style: body(12, color: const Color(0xFFE4DCFF))),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Previous game',
                        onPressed: gameIndex > 0 ? () => _goTo(gameIndex - 1) : null,
                        icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
                      ),
                      IconButton(
                        tooltip: 'Next game',
                        onPressed: gameIndex < games.length - 1 ? () => _goTo(gameIndex + 1) : null,
                        icon: const Icon(Icons.chevron_right_rounded, color: Colors.white),
                      ),
                    ],
                  ),
                  Text(current.name, style: display(28, color: Colors.white)),
                  const SizedBox(height: 6),
                  Text(current.howTo, style: body(13, color: const Color(0xFFEFEBFF))),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onLongPress: () => _goTo(gameIndex),
                          child: Text(_mmss(secondsLeft ?? current.minutes * 60), style: display(44, color: Colors.white)),
                        ),
                      ),
                      Material(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(16),
                        child: IconButton(
                          tooltip: 'Watch how to play',
                          onPressed: () => openLink(context, current.videoSearch),
                          icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: HC.lime,
                          foregroundColor: HC.ink,
                          minimumSize: const Size(96, 52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => _toggle(current),
                        child: Text(running ? 'Pause' : (secondsLeft == 0 ? 'Done!' : 'Start'), style: display(17)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(child: Text('Scoreboard', style: display(18, color: Colors.white, weight: FontWeight.w600))),
              OutlinedButton(
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0x33FFFFFF)), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () => setState(() {
                  teamPair = (teamPair + 1) % _teamNames.length;
                  scores = [0, 0];
                }),
                child: const Text('Shuffle teams'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < 2; i++) ...[
                if (i == 1) const SizedBox(width: 10),
                Expanded(
                  child: CardBox(
                    color: HC.nightCard,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(i == 0 ? teams.$1 : teams.$2, style: body(12, color: HC.nightMuted)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(child: Text('${scores[i]}', style: display(34, color: Colors.white))),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: i == 0 ? HC.coral : HC.lime,
                                foregroundColor: HC.ink,
                                minimumSize: const Size(48, 48),
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: () => setState(() => scores[i]++),
                              child: Text('+1', style: display(15)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x40FFFFFF)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Up next · ${clock(next.start)}', style: body(12, color: HC.nightMuted)),
                      Text(next.title, style: body(15, color: Colors.white, weight: FontWeight.w600)),
                    ],
                  ),
                ),
                Icon(Icons.schedule_rounded, color: HC.lime.withValues(alpha: 0.9)),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text('Also in Hoopla', style: display(18, color: Colors.white, weight: FontWeight.w600)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.25,
            children: [
              _Extra(label: 'Invite text', dot: HC.lime, onTap: () => _copy(context, _invite(e))),
              _Extra(
                label: 'Party playlist',
                dot: HC.coral,
                onTap: () => openLink(context, Uri.https('music.youtube.com', '/search', {'q': '${e.occasion} party songs'})),
              ),
              _Extra(label: 'Share plan', dot: HC.violet, onTap: () => _copy(context, _planText(state))),
              _Extra(label: 'Return gift ideas', dot: HC.lime, onTap: () => _giftIdeas(context, e.audience == Audience.kids)),
              _Extra(
                label: 'Weather',
                dot: HC.coral,
                onTap: () => openLink(context, Uri.https('www.google.com', '/search', {'q': 'weather ${DateFormat('MMMM d').format(e.date)}'})),
              ),
              _Extra(label: 'Guest photo album', dot: HC.violet, onTap: () => toast(context, 'Shared photo album is coming soon.')),
            ],
          ),
        ],
      ),
    );
  }

  static String _invite(EventDetails e) {
    return 'You\'re invited to ${e.title}!\n'
        '${DateFormat('EEEE, MMMM d').format(e.date)} · ${clockAmPm(e.startMinutes)}\n'
        'Please reply to let us know if you can make it.';
  }

  static String _planText(AppState state) {
    final e = state.event!;
    final lines = [
      '${e.title} — ${DateFormat('EEE, MMM d').format(e.date)}',
      for (final s in state.plan.timeline) '${clock(s.start)}  ${s.title}',
    ];
    return lines.join('\n');
  }

  static Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) toast(context, 'Copied — paste it in WhatsApp or your family group.');
  }

  static void _giftIdeas(BuildContext context, bool kids) {
    final ideas = kids
        ? ['Bubble wands', 'Mini coloring kits', 'Stickers + crayons', 'Small puzzles', 'Personalized cookies']
        : ['Mini plants', 'Sweet boxes', 'Scented candles', 'Coffee mugs', 'Photo magnets from the party'];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: HC.ground,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Return gift ideas', style: display(22)),
            const SizedBox(height: 12),
            for (final i in ideas)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [const Icon(Icons.card_giftcard_rounded, size: 18, color: HC.violet), const SizedBox(width: 10), Text(i, style: body(15))]),
              ),
          ],
        ),
      ),
    );
  }
}

class _Extra extends StatelessWidget {
  const _Extra({required this.label, required this.dot, required this.onTap});
  final String label;
  final Color dot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CardBox(
      color: HC.nightCard,
      radius: 16,
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(height: 8),
          Text(label, style: body(13, color: Colors.white, weight: FontWeight.w600)),
        ],
      ),
    );
  }
}
