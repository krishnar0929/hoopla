import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/provider_profile.dart';
import '../screens/sign_in_screen.dart';
import '../services/review_service.dart';
import '../services/shared_reels.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'common.dart';

const _gold = Color(0xFFF5B400);

/// ★★★★☆ for a rating (halves round to the nearest star).
class StarRow extends StatelessWidget {
  const StarRow(this.value, {super.key, this.size = 16});
  final double value;
  final double size;

  @override
  Widget build(BuildContext context) {
    final full = value.round();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++) Icon(i <= full ? Icons.star_rounded : Icons.star_outline_rounded, size: size, color: i <= full ? _gold : HC.muted),
      ],
    );
  }
}

/// "★ 4.7 (12 reviews)" or "New on Hoopla" for a provider, loaded from the server.
class RatingBadge extends StatefulWidget {
  const RatingBadge({super.key, required this.providerUid});
  final String providerUid;

  @override
  State<RatingBadge> createState() => _RatingBadgeState();
}

class _RatingBadgeState extends State<RatingBadge> {
  late final Future<RatingSummary> future = ReviewService.summary(widget.providerUid).catchError((_) => RatingSummary.none);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RatingSummary>(
      future: future,
      builder: (context, snap) {
        final s = snap.data;
        if (s == null) return const SizedBox(height: 16);
        if (s.count == 0) return Text('New on Hoopla', style: body(12, color: HC.muted, weight: FontWeight.w500));
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, size: 16, color: _gold),
            const SizedBox(width: 2),
            Text(ratingLabel(s.average), style: body(13, weight: FontWeight.w700)),
            Text(' (${s.count} review${s.count == 1 ? '' : 's'})', style: body(12, color: HC.muted)),
          ],
        );
      },
    );
  }
}

/// Round buttons to the provider's Instagram, Facebook, YouTube, TikTok, reviews and website.
class SocialLinks extends StatelessWidget {
  const SocialLinks({super.key, required this.provider});
  final ProviderProfile provider;

  @override
  Widget build(BuildContext context) {
    final p = provider;
    final links = <(IconData, String, Uri?)>[
      (Icons.camera_alt_outlined, 'Instagram', p.instagramUrl),
      (Icons.facebook_rounded, 'Facebook', p.facebookUrl),
      (Icons.smart_display_outlined, 'YouTube', p.youtubeUrl),
      (Icons.music_note_rounded, 'TikTok', p.tiktokUrl),
      (Icons.reviews_outlined, 'Reviews', p.reviewsUrl),
      (Icons.language_rounded, 'Website', p.websiteUrl),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (icon, label, url) in links)
          if (url != null)
            ActionChip(
              avatar: Icon(icon, size: 18, color: HC.violet),
              label: Text(label),
              backgroundColor: HC.card,
              side: const BorderSide(color: HC.line),
              shape: const StadiumBorder(),
              onPressed: () => openLink(context, url),
            ),
      ],
    );
  }
}

/// The provider's best reels and videos, each opening in its app.
class FeaturedPosts extends StatelessWidget {
  const FeaturedPosts({super.key, required this.links});
  final List<String> links;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < links.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: CardBox(
              onTap: () => openLink(context, Uri.parse(links[i])),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: HC.tiles[i % HC.tiles.length], borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.play_arrow_rounded, color: HC.ink),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(reelSource(links[i]) ?? 'Post', style: body(14, weight: FontWeight.w600)),
                        Text(Uri.tryParse(links[i])?.host.replaceFirst('www.', '') ?? links[i],
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, color: HC.muted)),
                      ],
                    ),
                  ),
                  const Icon(Icons.open_in_new_rounded, size: 18, color: HC.muted),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Ratings & reviews on a provider's page: the average, every review, and
/// "Write a review" for customers. On their own listing a provider can reply.
class ReviewsSection extends StatefulWidget {
  const ReviewsSection({super.key, required this.provider, this.ownListing = false});
  final ProviderProfile provider;
  final bool ownListing;

  @override
  State<ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<ReviewsSection> {
  late Future<List<Review>> future;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<List<Review>> _load() => ReviewService.load(widget.provider.uid);

  void _refresh() => setState(() => future = _load());

  Future<void> _write(Review? existing) async {
    final state = AppScope.of(context);
    if (!state.isSignedIn) {
      final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const SignInScreen(reason: 'Sign in free to rate and review providers.')),
      );
      if (ok != true || !mounted) return;
    }
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: HC.ground,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ReviewSheet(provider: widget.provider, existing: existing, eventType: state.event?.occasion ?? ''),
    );
    if (saved == true && mounted) {
      toast(context, 'Thanks! Your review helps other party planners.');
      _refresh();
    }
  }

  Future<void> _reply(Review r) async {
    final ctrl = TextEditingController(text: r.reply);
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reply to ${r.name}'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          maxLength: 500,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Thank them, or answer kindly'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: HC.violet),
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Post reply'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (text == null || !mounted) return;
    try {
      await ReviewService.reply(providerUid: widget.provider.uid, reviewerUid: r.reviewerUid, text: text);
      _refresh();
    } catch (e) {
      if (mounted) toast(context, 'Could not post the reply: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final myUid = state.isSignedIn ? state.accounts?.user?.uid : null;
    return FutureBuilder<List<Review>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return Text('Reviews couldn\'t load right now. Please try again later.', style: body(13, color: HC.muted));
        }
        final reviews = snap.data ?? const <Review>[];
        Review? mine;
        for (final r in reviews) {
          if (r.reviewerUid == myUid) mine = r;
        }
        final avg = reviews.isEmpty ? 0.0 : reviews.fold<int>(0, (a, r) => a + r.stars) / reviews.length;
        final canWrite = !widget.ownListing && myUid != widget.provider.uid;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CardBox(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(reviews.isEmpty ? '–' : ratingLabel(avg), style: display(40)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StarRow(avg, size: 20),
                        const SizedBox(height: 2),
                        Text(
                          reviews.isEmpty ? 'No reviews yet' : '${reviews.length} review${reviews.length == 1 ? '' : 's'} on Hoopla',
                          style: body(13, color: HC.muted),
                        ),
                      ],
                    ),
                  ),
                  if (canWrite)
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: HC.violet,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _write(mine),
                      child: Text(mine == null ? 'Write a review' : 'Edit review'),
                    ),
                ],
              ),
            ),
            if (reviews.isEmpty && canWrite) ...[
              const SizedBox(height: 8),
              Text('Worked with them? Be the first to review.', style: body(13, color: HC.muted)),
            ],
            if (reviews.isEmpty && widget.ownListing) ...[
              const SizedBox(height: 8),
              Text(
                'Ask happy customers to find you in Hoopla and leave a review. Listings with reviews are trusted more.',
                style: body(13, color: HC.muted),
              ),
            ],
            const SizedBox(height: 8),
            for (final r in reviews)
              _ReviewTile(
                review: r,
                providerName: widget.provider.businessName,
                isMine: r.reviewerUid == myUid,
                onReply: widget.ownListing ? () => _reply(r) : null,
              ),
          ],
        );
      },
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review, required this.providerName, required this.isMine, this.onReply});
  final Review review;
  final String providerName;
  final bool isMine;
  final VoidCallback? onReply;

  @override
  Widget build(BuildContext context) {
    final r = review;
    final meta = [
      if (r.eventType.isNotEmpty) r.eventType,
      if (r.createdAt != null) DateFormat('MMM y').format(r.createdAt!),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: CardBox(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: HC.track,
                  child: Text(r.name.isEmpty ? '?' : r.name[0], style: body(14, weight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isMine ? '${r.name} (you)' : r.name, style: body(14, weight: FontWeight.w600)),
                      if (meta.isNotEmpty) Text(meta, style: body(12, color: HC.muted)),
                    ],
                  ),
                ),
                StarRow(r.stars.toDouble(), size: 15),
              ],
            ),
            if (r.comment.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(r.comment, style: body(14)),
            ],
            if (r.reply.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: HC.ground, borderRadius: BorderRadius.circular(10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reply from $providerName', style: body(12, color: HC.muted, weight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(r.reply, style: body(13)),
                  ],
                ),
              ),
            ],
            if (onReply != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: onReply, child: Text(r.reply.isEmpty ? 'Reply' : 'Edit reply')),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.provider, required this.existing, required this.eventType});
  final ProviderProfile provider;
  final Review? existing;
  final String eventType;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  late int stars = widget.existing?.stars ?? 0;
  late final ctrl = TextEditingController(text: widget.existing?.comment ?? '');
  bool busy = false;
  String? error;

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (stars == 0) {
      setState(() => error = 'Tap the stars to rate.');
      return;
    }
    final nav = Navigator.of(context);
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ReviewService.save(
        providerUid: widget.provider.uid,
        stars: stars,
        comment: ctrl.text.length > 1000 ? ctrl.text.substring(0, 1000) : ctrl.text,
        eventType: widget.existing?.eventType.isNotEmpty == true ? widget.existing!.eventType : widget.eventType,
      );
      nav.pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Could not save your review. $e';
        });
      }
    }
  }

  Future<void> _delete() async {
    final nav = Navigator.of(context);
    setState(() => busy = true);
    try {
      await ReviewService.delete(widget.provider.uid);
      nav.pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Could not delete: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const words = ['', 'Poor', 'Okay', 'Good', 'Great', 'Amazing!'];
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Review ${widget.provider.businessName}', style: display(22)),
              const SizedBox(height: 4),
              Text('Your first name and last initial are shown with your review.', style: body(13, color: HC.muted)),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      tooltip: '$i star${i == 1 ? '' : 's'}',
                      iconSize: 40,
                      onPressed: () => setState(() => stars = i),
                      icon: Icon(i <= stars ? Icons.star_rounded : Icons.star_outline_rounded, color: i <= stars ? _gold : HC.muted),
                    ),
                ],
              ),
              Text(words[stars], textAlign: TextAlign.center, style: body(14, weight: FontWeight.w600)),
              const SizedBox(height: 10),
              TextField(
                controller: ctrl,
                minLines: 3,
                maxLines: 6,
                maxLength: 1000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'How was their work? On time? Worth the price? Would you book again?'),
              ),
              if (error != null) Text(error!, style: body(13, color: const Color(0xFFB42318), weight: FontWeight.w500)),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: HC.violet,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: busy ? null : _save,
                  child: Text(widget.existing == null ? 'Post review' : 'Update review', style: display(16, color: Colors.white)),
                ),
              ),
              if (widget.existing != null)
                TextButton(
                  onPressed: busy ? null : _delete,
                  child: Text('Delete my review', style: body(14, color: const Color(0xFFB42318), weight: FontWeight.w600)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
