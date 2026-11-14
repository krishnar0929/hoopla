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

// ============================================================ start-page link

/// A small link on the start page: "⭐ 4.8 · Reviews & party stories ›".
class StoriesLink extends StatelessWidget {
  const StoriesLink({super.key});

  @override
  Widget build(BuildContext context) {
    if (!showSampleStories) return const SizedBox.shrink();
    final avg = partyStories.fold<int>(0, (a, s) => a + s.stars) / partyStories.length;
    void open(int tab) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PartyStoriesScreen(initialTab: tab)));
    return Material(
      color: HC.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: HC.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => open(0),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                height: 40,
                child: Stack(
                  children: [
                    for (var i = 0; i < 3; i++)
                      Positioned(
                        left: i * 12.0,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                          child: ClipOval(child: GalleryImage(partyStories[i].cover, radius: 0)),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('See how others celebrated', style: body(14, weight: FontWeight.w700)),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 15, color: _gold),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            '${avg.toStringAsFixed(1)} · ${partyStories.length} party stories & reviews (samples)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: body(12, color: HC.muted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: () => open(1), child: const Text('Reviews')),
              const Icon(Icons.chevron_right_rounded, color: HC.muted),
            ],
          ),
        ),
      ),
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

// ============================================================ stories + reviews

/// Two tabs: Party stories (grid with occasion filters) and Reviews.
class PartyStoriesScreen extends StatefulWidget {
  const PartyStoriesScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<PartyStoriesScreen> createState() => _PartyStoriesScreenState();
}

class _PartyStoriesScreenState extends State<PartyStoriesScreen> {
  String? filter;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Celebrated with Hoopla'),
          bottom: TabBar(
            labelColor: HC.ink,
            unselectedLabelColor: HC.muted,
            indicatorColor: HC.violet,
            indicatorWeight: 3,
            labelStyle: body(15, weight: FontWeight.w700),
            tabs: const [Tab(text: '🎉  Party stories'), Tab(text: '💬  Reviews')],
          ),
        ),
        body: TabBarView(children: [_storiesTab(context), _reviewsTab(context)]),
      ),
    );
  }

  Widget _storiesTab(BuildContext context) {
    final kinds = {for (final s in partyStories) s.occasion}.toList();
    final list = [for (final s in partyStories) if (filter == null || s.occasion == filter) s];
    final width = MediaQuery.of(context).size.width;
    final columns = width > 1000 ? 4 : (width > 700 ? 3 : 2);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
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
    );
  }

  Widget _reviewsTab(BuildContext context) {
    final count = partyStories.length;
    final avg = partyStories.fold<int>(0, (a, s) => a + s.stars) / count;
    final byStars = {for (var n = 5; n >= 1; n--) n: partyStories.where((s) => s.stars == n).length};
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          children: [
            const _SampleNote(),
            const SizedBox(height: 12),
            CardBox(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Column(
                    children: [
                      Text(avg.toStringAsFixed(1), style: display(40)),
                      _stars(avg.round(), size: 16),
                      const SizedBox(height: 2),
                      Text('$count reviews', style: body(12, color: HC.muted)),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      children: [
                        for (final e in byStars.entries)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                SizedBox(width: 14, child: Text('${e.key}', style: body(12, color: HC.muted))),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: e.value / count,
                                      minHeight: 8,
                                      backgroundColor: HC.track,
                                      color: _gold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            for (final s in partyStories)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: CardBox(
                  onTap: () => _openStory(context, s),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SizedBox(width: 40, height: 40, child: ClipOval(child: GalleryImage(s.cover, radius: 0))),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.host, style: body(14, weight: FontWeight.w700)),
                                Text('${s.title} · ${s.month}', maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, color: HC.muted)),
                              ],
                            ),
                          ),
                          _stars(s.stars),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(s.review, style: body(14)),
                    ],
                  ),
                ),
              ),
          ],
        ),
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
