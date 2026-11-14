import 'package:flutter/material.dart';

import '../data/games.dart';
import '../data/party_stories.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/gallery.dart';
import 'setup_screen.dart';
import '../state/app_state.dart';
import '../widgets/locked.dart';

const _gold = Color(0xFFF5B400);

/// Says plainly that these are examples.
class _SampleNote extends StatelessWidget {
  const _SampleNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SampleTag(),
        const SizedBox(width: 6),
        Expanded(child: Text('Example stories to show what a Hoopla party looks like.', style: body(11, color: HC.muted))),
      ],
    );
  }
}

Widget _stars(int n, {double size = 14}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [for (var i = 1; i <= 5; i++) Icon(i <= n ? Icons.star_rounded : Icons.star_outline_rounded, size: size, color: i <= n ? _gold : HC.muted)],
    );

// ============================================================ sections

/// "🎉 Celebrated with Hoopla": swipeable story cards, with "See all".
class PartyStoriesSection extends StatelessWidget {
  const PartyStoriesSection({super.key});

  @override
  Widget build(BuildContext context) {
    if (!showSampleStories) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('🎉 Celebrated with Hoopla', style: display(20))),
            TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PartyStoriesScreen())),
              child: const Text('See all 20'),
            ),
          ],
        ),
        const _SampleNote(),
        const SizedBox(height: 10),
        SizedBox(
          height: 250,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: partyStories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => SizedBox(width: 220, child: _StoryCard(story: partyStories[i])),
          ),
        ),
      ],
    );
  }
}

/// "💬 What hosts say": swipeable review cards.
class HostReviewsSection extends StatelessWidget {
  const HostReviewsSection({super.key});

  @override
  Widget build(BuildContext context) {
    if (!showSampleStories) return const SizedBox.shrink();
    final count = partyStories.length;
    final avg = partyStories.fold<int>(0, (a, s) => a + s.stars) / count;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('💬 What hosts say', style: display(20)),
        const SizedBox(height: 4),
        Row(
          children: [
            _stars(avg.round(), size: 16),
            const SizedBox(width: 6),
            Text('${avg.toStringAsFixed(1)} from $count sample reviews', style: body(12, color: HC.muted)),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: count,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final s = partyStories[i];
              return SizedBox(
                width: 280,
                child: CardBox(
                  onTap: () => _openStory(context, s),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _stars(s.stars),
                          const Spacer(),
                          Text(s.emoji, style: const TextStyle(fontSize: 18)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Text('"${s.review}"', maxLines: 5, overflow: TextOverflow.ellipsis, style: body(13)),
                      ),
                      const SizedBox(height: 8),
                      Text('${s.host} · ${s.title}', maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, color: HC.muted, weight: FontWeight.w600)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

void _openStory(BuildContext context, PartyStory s) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PartyStoryScreen(story: s)));

class _StoryCard extends StatelessWidget {
  const _StoryCard({required this.story});
  final PartyStory story;

  @override
  Widget build(BuildContext context) {
    final s = story;
    return Material(
      color: HC.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: HC.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openStory(context, s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 140,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GalleryImage(s.cover, radius: 0),
                  Positioned(
                    left: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(10)),
                      child: Text('${s.emoji} ${s.occasion}', style: body(11, weight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(15, weight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('${s.city} · ${s.guests} guests', style: body(12, color: HC.muted)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _stars(s.stars, size: 13),
                      const SizedBox(width: 6),
                      Text('${s.gameIds.length} games', style: body(11, color: HC.muted)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================ all stories

class PartyStoriesScreen extends StatefulWidget {
  const PartyStoriesScreen({super.key});

  @override
  State<PartyStoriesScreen> createState() => _PartyStoriesScreenState();
}

class _PartyStoriesScreenState extends State<PartyStoriesScreen> {
  String? filter;

  @override
  Widget build(BuildContext context) {
    final kinds = {for (final s in partyStories) s.occasion}.toList();
    final list = [for (final s in partyStories) if (filter == null || s.occasion == filter) s];
    final width = MediaQuery.of(context).size.width;
    final columns = width > 1000 ? 4 : (width > 700 ? 3 : 2);
    return Scaffold(
      appBar: AppBar(title: const Text('Celebrated with Hoopla')),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SampleNote(),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Pill(label: 'All', small: true, selected: filter == null, onTap: () => setState(() => filter = null)),
                      for (final k in kinds) Pill(label: k, small: true, selected: filter == k, onTap: () => setState(() => filter = k)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: 250,
              ),
              delegate: SliverChildBuilderDelegate((context, i) => _StoryCard(story: list[i]), childCount: list.length),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================ one story

class PartyStoryScreen extends StatelessWidget {
  const PartyStoryScreen({super.key, required this.story});
  final PartyStory story;

  @override
  Widget build(BuildContext context) {
    final s = story;
    final games = [for (final id in s.gameIds) ...gameCatalog.where((g) => g.id == id)];
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 280,
            backgroundColor: HC.ink,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(s.title, style: display(18, color: Colors.white)),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  GalleryImage(s.cover, radius: 0),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0xCC17142B)]),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _SampleNote(),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final t in ['${s.emoji} ${s.occasion}', s.city, s.month, '${s.guests} guests', s.indoor ? 'Indoor' : 'Outdoor'])
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(color: HC.track, borderRadius: BorderRadius.circular(20)),
                              child: Text(t, style: body(12, weight: FontWeight.w600)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // The host's review.
                      CardBox(
                        color: HC.lime,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _stars(s.stars, size: 18),
                            const SizedBox(height: 8),
                            Text('"${s.review}"', style: body(15, weight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            Text('— ${s.host}, host', style: body(13, weight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Text('⭐', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Best moment: ${s.highlight}', style: body(14, weight: FontWeight.w600))),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Text('📸 Photos', style: display(18)),
                      const SizedBox(height: 10),
                      PhotoGrid(photos: s.photos),
                      const SizedBox(height: 22),
                      Text('🎲 Games they played', style: display(18)),
                      const SizedBox(height: 10),
                      for (final g in games)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: CardBox(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text(g.name, style: body(15, weight: FontWeight.w700))),
                                    Text('${g.minutes} min', style: body(12, color: HC.muted)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(g.howTo, style: body(13, color: HC.muted)),
                                const SizedBox(height: 6),
                                TextButton.icon(
                                  style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                                  onPressed: () => openLink(context, g.videoSearch),
                                  icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
                                  label: const Text('Watch how to play'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 14),
                      Text('🤝 Helpers they booked', style: display(18)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final h in s.helpers)
                            Chip(
                              avatar: const Icon(Icons.storefront_outlined, size: 16, color: HC.violet),
                              label: Text(h),
                              backgroundColor: HC.card,
                              side: const BorderSide(color: HC.line),
                            ),
                        ],
                      ),
                      const SizedBox(height: 26),
                      SizedBox(
                        height: 54,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: HC.violet, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                          onPressed: () {
                            final state = AppScope.of(context);
                            if (!state.canAddEvent) {
                              openUnlock(context, Access.member);
                              return;
                            }
                            Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SetupScreen(preset: s)));
                          },
                          icon: const Icon(Icons.auto_awesome_rounded, color: HC.lime),
                          label: Text('Plan a party like this', style: display(17, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
