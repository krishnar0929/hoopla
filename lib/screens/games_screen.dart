import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/games.dart';
import '../models/event_details.dart';
import '../services/plan_generator.dart';
import '../services/search_log.dart';
import '../services/shared_reels.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/locked.dart';

/// Browse games with how-to videos, add them to the plan, and save reels.
class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  static const filters = ['For this party', 'Kids', 'Adults', 'Everyone', 'Indoor', 'Outdoor', 'Under 15 min'];
  String filter = filters.first;

  List<Game> _games(EventDetails e) => switch (filter) {
        'For this party' => PlanGenerator.rankedGames(e),
        'Kids' => gameCatalog.where((g) => g.kids).toList(),
        'Adults' => gameCatalog.where((g) => g.adults).toList(),
        'Everyone' => gameCatalog.where((g) => g.kids && g.adults).toList(),
        'Indoor' => gameCatalog.where((g) => g.indoor).toList(),
        'Outdoor' => gameCatalog.where((g) => g.outdoor).toList(),
        _ => gameCatalog.where((g) => g.minutes < 15).toList(),
      };

  /// Save a reel link. Free for everyone. Fills in a copied link automatically.
  Future<void> _saveReel() async {
    final url = TextEditingController();
    final title = TextEditingController();
    try {
      final copied = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
      final link = firstLink(copied);
      if (link != null && isReelLink(link)) url.text = link;
    } catch (_) {}
    if (!mounted) return;
    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: HC.ground,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Save a game reel', style: display(22)),
            const SizedBox(height: 4),
            Text(
              url.text.isEmpty
                  ? 'Paste a link from Instagram, TikTok or YouTube. It waits here for your next party.'
                  : 'We found the link you copied. Give it a name and save.',
              style: body(13, color: HC.muted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: url,
              autofocus: url.text.isEmpty,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: 'Reel or video link'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: title,
              autofocus: url.text.isNotEmpty,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Name it (optional, e.g. "Cup flip race")'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: HC.violet, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Save for my party'),
              ),
            ),
            if (!kIsWeb) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.bolt_rounded, size: 18, color: HC.violet),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Faster: in Instagram tap the share icon on a reel → Share to… → Hoopla. It saves in one tap.',
                      style: body(12, color: HC.muted),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
    if (!mounted || save != true) return;
    final link = firstLink(url.text.trim());
    if (link == null) {
      toast(context, 'That doesn\'t look like a link. In Instagram tap Share → Copy link, then try again.');
      return;
    }
    final name = title.text.trim().isEmpty ? defaultTitle(link) : title.text.trim();
    final added = await AppScope.of(context).addReels([SavedLink(title: name, url: link)]);
    if (mounted) toast(context, added == 0 ? 'Already saved.' : 'Saved "$name". It waits here for your party.');
  }

  /// Share a game on WhatsApp with a link back to Hoopla.
  void _shareGame(BuildContext ctx, Game g) {
    final text = 'Party game idea: ${g.name}\n${g.howTo}\n'
        '${g.needs.isEmpty ? '' : 'You need: ${g.needs.join(', ')}\n'}'
        '\nMore games and a ready-made party plan: https://hoopla-894ca.web.app';
    openLink(ctx, Uri.https('wa.me', '/', {'text': text}));
  }

  void _showGame(Game g) {
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
            Text(g.name, style: display(24)),
            const SizedBox(height: 6),
            Text('${g.audienceLabel} · ${g.placeLabel} · ${g.minutes} min · ${g.minPlayers}+ players', style: body(13, color: HC.muted)),
            const SizedBox(height: 14),
            Text(g.howTo, style: body(15)),
            if (g.needs.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('YOU NEED', style: overline()),
              const SizedBox(height: 4),
              Text(g.needs.join(' · '), style: body(14, weight: FontWeight.w500)),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(side: const BorderSide(color: HC.line), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: () => openLink(ctx, g.videoSearch),
                icon: const Icon(Icons.play_circle_outline_rounded, color: HC.ink),
                label: Text('Watch how to play', style: body(14, weight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1FAA59), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: () => _shareGame(ctx, g),
                icon: const Icon(Icons.chat_rounded, size: 20),
                label: const Text('Share on WhatsApp'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final e = state.event!;
    final allGames = _games(e);
    // Guests see 3 games; signing in (free) shows them all.
    final limited = state.limitedGuest && allGames.length > 3;
    final games = limited ? allGames.take(3).toList() : allGames;
    final width = MediaQuery.of(context).size.width;
    final columns = width > 900 ? 4 : (width > 600 ? 3 : 2);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 20, 20, 0),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Text('Games that get laughs', style: display(30)),
              const SizedBox(height: 4),
              Text('Picked for ${e.guests} guests · ${e.indoor ? 'indoor' : 'outdoor'} · ${e.audience.label.toLowerCase()}', style: body(13, color: HC.muted)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final f in filters)
                    Pill(
                      label: f,
                      small: true,
                      selected: f == filter,
                      onTap: () {
                        setState(() => filter = f);
                        SearchLog.instance.log('games_filter', filters: {'filter': f, 'guests': e.guests, 'indoor': e.indoor});
                      },
                    ),
                ],
              ),
              const SizedBox(height: 14),
              CardBox(
                color: HC.ink,
                onTap: _saveReel,
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: HC.coral, borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.ios_share_rounded, color: HC.ink),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Saw a funny game reel?', style: body(14, color: Colors.white, weight: FontWeight.w600)),
                          Text(
                            kIsWeb
                                ? 'Save it to Hoopla for free. It waits for your next party, so you never forget it.'
                                : 'Save it free. Tip: in Instagram tap Share → Hoopla to save in one tap.',
                            style: body(12, color: HC.nightMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (e.savedLinks.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text('YOUR SAVED REELS', style: overline()),
                const SizedBox(height: 8),
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: e.savedLinks.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (ctx, i) {
                      final l = e.savedLinks[i];
                      return InputChip(
                        label: Text(l.title),
                        avatar: const Icon(Icons.play_arrow_rounded, size: 18),
                        onPressed: () => openLink(ctx, Uri.parse(l.url)),
                        onDeleted: () => state.update((ev) => ev.savedLinks.removeAt(i)),
                        backgroundColor: HC.card,
                        side: const BorderSide(color: HC.line),
                        shape: const StadiumBorder(),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: 238,
            ),
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _GameCard(
                game: games[i],
                tile: HC.tiles[i % HC.tiles.length],
                added: e.gameIds.contains(games[i].id),
                onOpen: () => _showGame(games[i]),
                onToggle: () => state.update((ev) {
                  if (!ev.gameIds.remove(games[i].id)) ev.gameIds.add(games[i].id);
                }),
              ),
              childCount: games.length,
            ),
          ),
        ),
        if (limited)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            sliver: SliverToBoxAdapter(
              child: LockedCard(
                needs: Access.member,
                title: '${allGames.length - games.length} more games picked for your party',
                message: 'Sign in free to see every game, with how-to videos and what you need.',
              ),
            ),
          ),
      ],
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.game, required this.tile, required this.added, required this.onOpen, required this.onToggle});
  final Game game;
  final Color tile;
  final bool added;
  final VoidCallback onOpen;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return CardBox(
      padding: EdgeInsets.zero,
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 100,
            color: tile,
            child: Stack(
              children: [
                Center(
                  child: Material(
                    color: HC.ink.withValues(alpha: 0.85),
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Watch how to play',
                      onPressed: () => openLink(context, game.videoSearch),
                      icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(8)),
                    child: Text('${game.minutes} min', style: body(10, weight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(game.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: body(14, weight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('${game.audienceLabel} · ${game.minPlayers}+ players', style: body(11, color: HC.muted)),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: added
                        ? FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: HC.lime, foregroundColor: HC.ink, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                            onPressed: onToggle,
                            child: Text('In your plan', style: body(12, weight: FontWeight.w600)),
                          )
                        : OutlinedButton(
                            style: OutlinedButton.styleFrom(side: const BorderSide(color: HC.line), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                            onPressed: onToggle,
                            child: Text('Add to plan', style: body(12, weight: FontWeight.w600)),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
