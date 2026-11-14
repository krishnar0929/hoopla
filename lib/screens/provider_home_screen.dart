import 'package:flutter/material.dart';

import '../models/provider_profile.dart';
import '../services/account_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/gallery.dart';
import '../widgets/reviews.dart';
import 'account_sheet.dart';
import 'provider_setup_screen.dart';
import 'quotes_screens.dart';

/// Home for service providers: their listing and how customers reach them.
class ProviderHomeScreen extends StatelessWidget {
  const ProviderHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = state.provider!;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                Row(
                  children: [
                    Text('HOOPLA FOR BUSINESS', style: overline()),
                    const Spacer(),
                    IconButton(tooltip: 'Account', onPressed: () => showAccountSheet(context), icon: const Icon(Icons.person_outline_rounded)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(p.businessName, style: display(30)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Tag(p.serviceType),
                    _Tag(p.city),
                    _Tag(p.verified ? 'Verified' : 'Waiting for verification', color: p.verified ? HC.lime : HC.track),
                  ],
                ),
                const SizedBox(height: 18),
                const LeadSummaryCard(),
                const SizedBox(height: 12),
                CardBox(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your listing', style: display(18, weight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      _Line('Phone / WhatsApp', p.phone),
                      if (p.priceRange.isNotEmpty) _Line('Price range', p.priceRange),
                      if (p.about.isNotEmpty) _Line('About', p.about),
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          side: const BorderSide(color: HC.line),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ProviderSetupScreen(existing: p))),
                        icon: const Icon(Icons.edit_outlined, size: 18, color: HC.ink),
                        label: Text('Edit listing', style: body(14, weight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                CardBox(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text('Your work', style: display(18, weight: FontWeight.w600))),
                          Text('${p.photos.length}/${ProviderProfile.maxPhotos}', style: body(12, color: HC.muted)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (p.photos.isEmpty)
                        Text(
                          'Listings with photos get far more calls. Add photos of your best work so customers can see your style.',
                          style: body(13, color: HC.muted),
                        )
                      else
                        PhotoGrid(photos: p.photos),
                      if (p.hasSocial) ...[
                        const SizedBox(height: 12),
                        SocialLinks(provider: p),
                      ],
                      if (p.featured.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        FeaturedPosts(links: p.featured),
                      ],
                      const SizedBox(height: 6),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: HC.violet,
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ProviderSetupScreen(existing: p))),
                        icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                        label: Text(p.photos.isEmpty ? 'Add photos & social links' : 'Edit photos & links', style: body(14, color: Colors.white, weight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                CardBox(
                  color: HC.ink,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('How customers reach you', style: display(18, color: Colors.white, weight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text(
                        'People planning events who search for ${p.serviceType.toLowerCase()} see your listing and can call you, '
                        'WhatsApp you, or send a quote request with their date and guest count.',
                        style: body(14, color: HC.nightMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const _InfoCard(
                  icon: Icons.verified_outlined,
                  title: 'Verification',
                  text: 'We check each listing before adding the Verified badge. Verified providers are shown first.',
                ),
                const SizedBox(height: 12),
                Text('Ratings & reviews', style: display(18, weight: FontWeight.w600)),
                const SizedBox(height: 8),
                ReviewsSection(provider: p, ownListing: true),

                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => state.setRole(UserRole.customer),
                  child: const Text('Plan my own event'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, {this.color = HC.card});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10), border: Border.all(color: HC.line)),
        child: Text(text, style: body(12, weight: FontWeight.w600)),
      );
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: body(12, color: HC.muted)),
            Text(value, style: body(14, weight: FontWeight.w500)),
          ],
        ),
      );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => CardBox(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: HC.violet),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: body(15, weight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(text, style: body(13, color: HC.muted)),
                ],
              ),
            ),
          ],
        ),
      );
}
