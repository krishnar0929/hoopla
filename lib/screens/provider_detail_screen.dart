import 'package:flutter/material.dart';

import '../models/provider_profile.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/gallery.dart';
import '../widgets/reviews.dart';

/// A provider's full listing: photos of their work, about, prices and contact.
class ProviderDetailScreen extends StatelessWidget {
  const ProviderDetailScreen({super.key, required this.provider, required this.quote});

  final ProviderProfile provider;

  /// Ready-made message with the customer's event details.
  final String quote;

  @override
  Widget build(BuildContext context) {
    final p = provider;
    final digits = p.phoneDigits;
    final hasPhone = digits.isNotEmpty;
    VoidCallback? contact(VoidCallback action) {
      if (p.isSample) return () => toast(context, sampleContactNote);
      return hasPhone ? action : null;
    }

    return Scaffold(
      appBar: AppBar(title: Text(p.serviceType)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: [
              if (p.isSample)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: HC.track, borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    children: [
                      const Text('👀', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'This is a sample listing, so you can see how Hoopla works. Real providers near you will look just like this.',
                          style: body(13),
                        ),
                      ),
                    ],
                  ),
                ),
              if (p.photos.isNotEmpty)
                GestureDetector(
                  onTap: () => openPhotoViewer(context, p.photos, 0),
                  child: AspectRatio(aspectRatio: 4 / 3, child: GalleryImage(p.photos.first, radius: 18)),
                ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Flexible(child: Text(p.businessName, style: display(26))),
                  if (p.verified) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.verified_rounded, color: HC.violet, semanticLabel: 'Verified'),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              RatingBadge(providerUid: p.uid),
              const SizedBox(height: 4),
              Text([p.city, if (p.priceRange.isNotEmpty) p.priceRange].join(' · '), style: body(14, color: HC.muted)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Action(icon: Icons.call_outlined, label: 'Call', onTap: contact(() => openLink(context, Uri(scheme: 'tel', path: digits)))),
                  _Action(
                    icon: Icons.chat_outlined,
                    label: 'WhatsApp',
                    onTap: contact(() => openLink(context, Uri.https('wa.me', '/$digits', {'text': quote}))),
                  ),
                  _Action(
                    icon: Icons.request_quote_outlined,
                    label: 'Get quote',
                    dark: true,
                    onTap: contact(() => openLink(context, Uri(scheme: 'sms', path: digits, queryParameters: {'body': quote}))),
                  ),
                ],
              ),
              if (p.hasSocial) ...[
                const SizedBox(height: 20),
                const SectionLabel('Find them on'),
                SocialLinks(provider: p),
              ],
              if (p.about.isNotEmpty) ...[
                const SizedBox(height: 20),
                const SectionLabel('About'),
                Text(p.about, style: body(15)),
              ],
              const SizedBox(height: 20),
              SectionLabel('Their work${p.photos.isEmpty ? '' : ' · ${p.photos.length} photos'}'),
              if (p.photos.isEmpty)
                Text(
                  p.instagramUrl != null ? 'See their work on Instagram.' : 'No photos yet. Ask them to share recent work on WhatsApp.',
                  style: body(14, color: HC.muted),
                )
              else
                PhotoGrid(photos: p.photos),
              if (p.instagramUrl != null && p.photos.isNotEmpty) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => openLink(context, p.instagramUrl!),
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: Text('More on Instagram @${p.instagram}'),
                  ),
                ),
              ],
              if (p.featured.isNotEmpty) ...[
                const SizedBox(height: 20),
                const SectionLabel('Featured reels & videos'),
                FeaturedPosts(links: p.featured),
              ],
              const SizedBox(height: 20),
              const SectionLabel('Ratings & reviews'),
              ReviewsSection(provider: p),
            ],
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap, this.dark = false});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    return dark
        ? FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: HC.ink, shape: shape, minimumSize: const Size(0, 44)),
            onPressed: onTap,
            icon: Icon(icon, size: 18),
            label: Text(label),
          )
        : OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: HC.ink,
              side: const BorderSide(color: HC.line),
              shape: shape,
              minimumSize: const Size(0, 44),
            ),
            onPressed: onTap,
            icon: Icon(icon, size: 18),
            label: Text(label),
          );
  }
}
