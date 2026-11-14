import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/helpers.dart';
import '../models/event_details.dart';
import '../models/provider_profile.dart';
import '../services/plan_generator.dart';
import '../services/search_log.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../data/sample_providers.dart';
import '../widgets/gallery.dart';
import '../widgets/reviews.dart';
import '../widgets/locked.dart';
import 'provider_detail_screen.dart';
import '../widgets/place_picker.dart';
import '../services/location_service.dart';
import '../services/budget_match.dart';
import '../services/quote_service.dart';
import 'quotes_screens.dart';

/// Find photographers, panthulu, decorators and more, and keep a shortlist.
class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key, this.initialCategory, this.standalone = false, this.startWithinBudget = false});

  /// Service to show first (e.g. from the Budget tab).
  final String? initialCategory;

  /// Opened as its own page (with a back button) instead of as a tab.
  final bool standalone;

  /// Start with "Within my budget" switched on.
  final bool startWithinBudget;

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  late String selected = widget.initialCategory ?? helperCategories.first.label;
  late bool withinBudget = widget.startWithinBudget;

  /// Where to search: the venue, the current location, or an address the user picked.
  Place? near;
  bool _nearSet = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_nearSet) return;
    _nearSet = true;
    near = AppScope.of(context).event?.venue;
    if (near == null) {
      LocationService.currentIfAllowed().then((p) {
        if (mounted && near == null && p != null) setState(() => near = p);
      });
    }
  }

  Future<void> _changeNear() async {
    final p = await pickPlace(context, title: 'Search near…', hint: 'Address, area or ZIP code');
    if (p != null && mounted) setState(() => near = p);
  }

  /// This service's share of the budget (null when no budget or not a budget line).
  double? _budgetFor(AppState state) {
    final total = state.event?.budget;
    if (total == null || total <= 0) return null;
    for (final line in state.plan.budget) {
      if (budgetServices[line.label] == selected) return total * line.share;
    }
    return null;
  }

  /// Budget filter, then nearest first (providers without a map position last).
  List<ProviderProfile> _arrange(List<ProviderProfile> list, AppState state) {
    final cap = withinBudget ? _budgetFor(state) : null;
    final e = state.event!;
    final kept = [for (final p in list) if (cap == null || fitsBudget(p, e, cap)) p];
    final n = near;
    if (n == null) return kept;
    double d(ProviderProfile p) => (p.lat == null || p.lng == null) ? double.infinity : milesBetween(n.lat, n.lng, p.lat!, p.lng!);
    kept.sort((a, b) => d(a).compareTo(d(b)));
    return kept;
  }

  double? _distance(ProviderProfile p) {
    final n = near;
    if (n == null || p.lat == null || p.lng == null) return null;
    return milesBetween(n.lat, n.lng, p.lat!, p.lng!);
  }
  String query = '';
  Timer? _searchPause;
  Future<List<ProviderProfile>>? _providers;
  String? _providersFor;

  /// Hoopla providers for the selected service, fetched once per category.
  Future<List<ProviderProfile>> _providersFuture(AppState state) {
    if (_providers == null || _providersFor != selected) {
      _providersFor = selected;
      _providers = state.accounts!.findProviders(selected);
    }
    return _providers!;
  }

  @override
  void dispose() {
    _searchPause?.cancel();
    super.dispose();
  }

  /// Logs the search once the person stops typing for a moment.
  void _onSearch(String v, {bool now = false}) {
    setState(() => query = v);
    _searchPause?.cancel();
    if (v.trim().length < 2) return;
    void send() => SearchLog.instance.log('nearby_search', query: v.trim(), filters: {'category': selected});
    if (now) {
      send();
    } else {
      _searchPause = Timer(const Duration(milliseconds: 1500), send);
    }
  }

  Future<void> _addVendor(String category) async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final note = TextEditingController();
    final saved = await showModalBottomSheet<bool>(
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
            Text('Add to shortlist', style: display(22)),
            const SizedBox(height: 4),
            Text(category, style: body(13, color: HC.muted)),
            const SizedBox(height: 16),
            TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 10),
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone (with country code)')),
            const SizedBox(height: 10),
            TextField(controller: note, decoration: const InputDecoration(labelText: 'Note (price, style, who referred)')),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: HC.violet, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: () => Navigator.of(ctx).pop(name.text.trim().isNotEmpty),
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
    if (saved == true && mounted) {
      await AppScope.of(context).update((e) => e.shortlist.add(ShortlistVendor(
            id: EventDetails.newId(),
            category: category,
            name: name.text.trim(),
            phone: phone.text.trim(),
            note: note.text.trim(),
          )));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (AppState.userPlansEnabled && !state.atLeast(Tier.pro)) {
      return const LockedPage(
        title: 'Find nearby professionals',
        message: 'Part of Pro (\$9.99/month): photographers, decorators, panthulu, cake makers and more for your event, all in one place.',
        points: [
          'Browse providers by service, with prices and verified badges',
          'Call or WhatsApp in one tap',
          'Send quote requests with your date and guest count filled in',
          'Keep a shortlist for every event',
        ],
      );
    }
    final e = state.event!;
    final category = helperCategories.firstWhere((c) => c.label == selected);
    final cats = helperCategories.where((c) => query.isEmpty || c.label.toLowerCase().contains(query.toLowerCase())).toList();
    final mine = e.shortlist.where((v) => v.category == selected).toList();

    final budgetCap = _budgetFor(state);
    final money = NumberFormat.simpleCurrency(decimalDigits: 0);
    final page = ListView(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + (widget.standalone ? 4 : 20), 20, 24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (widget.standalone)
              IconButton(tooltip: 'Back', onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back_rounded)),
            Expanded(child: Text('Find nearby', style: display(30))),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('For ${DateFormat('MMM d').format(e.date)} · ${clockAmPm(e.startMinutes)}', style: body(12, color: HC.muted)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Where to search.
        Material(
          color: HC.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: HC.line)),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _changeNear,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
              child: Row(
                children: [
                  const Icon(Icons.place_rounded, color: HC.violet, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: 'Near ', style: body(14, color: HC.muted)),
                        TextSpan(
                          text: near == null ? 'you (tap to set a location)' : (near == e.venue ? '${near!.label} · your venue' : near!.label),
                          style: body(14, weight: FontWeight.w600),
                        ),
                      ]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text('Change', style: body(13, color: HC.violet, weight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          onChanged: _onSearch,
          onSubmitted: (v) => _onSearch(v, now: true),
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search photographers, cakes, panthulu…'),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in cats)
              Pill(
                label: c.label,
                small: true,
                selectedColor: HC.violet,
                selected: c.label == selected,
                onTap: () {
                  setState(() => selected = c.label);
                  SearchLog.instance.log('nearby_category', query: query.trim().isEmpty ? null : query.trim(), filters: {'category': c.label});
                },
              ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: Text('$selected near you', style: display(18, weight: FontWeight.w600))),
            if (state.plan.helpers.contains(selected))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: HC.lime, borderRadius: BorderRadius.circular(8)),
                child: Text('In your plan', style: body(11, weight: FontWeight.w600)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        CardBox(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: HC.tiles[1], borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.map_outlined, color: HC.ink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Browse ${selected.toLowerCase()} on the map', style: body(14, weight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('See ratings, photos and hours, then add your favorites here.', style: body(12, color: HC.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46), side: const BorderSide(color: HC.line), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: () => openLink(context, category.mapsSearchNear(near?.address.isNotEmpty == true ? near!.address : near?.label)),
                icon: const Icon(Icons.open_in_new_rounded, size: 18, color: HC.ink),
                label: Text('Open map', style: body(14, weight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: HC.ink, minimumSize: const Size(0, 46), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: () => _addVendor(selected),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add one'),
              ),
            ),
          ],
        ),
        if (state.accounts != null) ...[
          const SizedBox(height: 20),
          if (budgetCap != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FilterChip(
                selected: withinBudget,
                showCheckmark: true,
                selectedColor: HC.lime,
                backgroundColor: HC.card,
                side: const BorderSide(color: HC.line),
                label: Text('Within my ${selected.toLowerCase()} budget (${money.format(budgetCap)})'),
                onSelected: (v) => setState(() => withinBudget = v),
              ),
            ),
          if (state.isSignedIn) const MyQuotesLink(),
          Text('ON HOOPLA', style: overline()),
          const SizedBox(height: 8),
          FutureBuilder<List<ProviderProfile>>(
            future: _providersFuture(state),
            builder: (ctx, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
                );
              }
              final all = snap.hasError ? const <ProviderProfile>[] : (snap.data ?? const <ProviderProfile>[]);
              final list = _arrange(all, state);
              final samples = showSampleProviders && all.length < 3
                  ? _arrange(sampleProvidersFor(selected).take(3 - all.length).toList(), state)
                  : const <ProviderProfile>[];
              if (withinBudget && list.isEmpty && samples.isEmpty && budgetCap != null) {
                return Text(
                  'No ${selected.toLowerCase()} on Hoopla fit ${money.format(budgetCap)} yet. Turn off the budget filter or raise the budget in your plan.',
                  style: body(13, color: HC.muted),
                );
              }
              if (list.isEmpty && samples.isEmpty) {
                return Text(
                  'No ${selected.toLowerCase()} have joined Hoopla yet. Use the map above meanwhile.',
                  style: body(13, color: HC.muted),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < list.length; i++) _ProviderCard(provider: list[i], tile: HC.tiles[i % HC.tiles.length], miles: _distance(list[i])),
                  if (samples.isNotEmpty) ...[
                    Padding(
                      padding: EdgeInsets.only(top: list.isEmpty ? 0 : 8, bottom: 8),
                      child: Text(
                        list.isEmpty
                            ? 'Sample listings: this is how ${selected.toLowerCase()} will look once they join Hoopla near you.'
                            : 'More sample listings, to show how Hoopla works:',
                        style: body(12, color: HC.muted),
                      ),
                    ),
                    for (var i = 0; i < samples.length; i++)
                      _ProviderCard(provider: samples[i], tile: HC.tiles[(i + 2) % HC.tiles.length], miles: _distance(samples[i])),
                  ],
                ],
              );
            },
          ),
        ],
        const SizedBox(height: 18),
        if (mine.isNotEmpty) ...[
          Text('Your shortlist', style: overline()),
          const SizedBox(height: 8),
          for (var i = 0; i < mine.length; i++) _VendorCard(vendor: mine[i], tile: HC.tiles[i % HC.tiles.length]),
        ] else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('No ${selected.toLowerCase()} saved yet. Find one on the map and add them here so calling, WhatsApp and quotes are one tap away.',
                style: body(13, color: HC.muted)),
          ),
      ],
    );
    return widget.standalone ? Scaffold(body: SafeArea(bottom: false, child: page)) : page;
  }
}

class _VendorCard extends StatelessWidget {
  const _VendorCard({required this.vendor, required this.tile});
  final ShortlistVendor vendor;
  final Color tile;

  @override
  Widget build(BuildContext context) {
    final digits = vendor.phone.replaceAll(RegExp(r'[^0-9]'), '');
    final hasPhone = digits.isNotEmpty;
    final state = AppScope.of(context);
    final e = state.event!;
    final quote = 'Hi ${vendor.name}, I\'m planning "${e.title}" on ${DateFormat('EEE, MMM d').format(e.date)} '
        'at ${clockAmPm(e.startMinutes)} for about ${e.guests} guests (${e.indoor ? 'indoor' : 'outdoor'}). '
        'Are you available, and could you share a quote?';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CardBox(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(color: tile, borderRadius: BorderRadius.circular(14)),
              alignment: Alignment.center,
              child: Text(vendor.name.isEmpty ? '?' : vendor.name[0].toUpperCase(), style: display(28)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(vendor.name, style: body(15, weight: FontWeight.w600))),
                      IconButton(
                        tooltip: 'Remove',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => state.update((ev) => ev.shortlist.removeWhere((v) => v.id == vendor.id)),
                        icon: const Icon(Icons.close_rounded, size: 18, color: HC.muted),
                      ),
                    ],
                  ),
                  if (vendor.note.isNotEmpty) Text(vendor.note, style: body(12, color: HC.muted)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _SmallButton(label: 'Call', onTap: hasPhone ? () => openLink(context, Uri(scheme: 'tel', path: digits)) : null),
                      _SmallButton(
                        label: 'WhatsApp',
                        onTap: hasPhone ? () => openLink(context, Uri.https('wa.me', '/$digits', {'text': quote})) : null,
                      ),
                      _SmallButton(
                        label: 'Get quote',
                        dark: true,
                        onTap: hasPhone
                            ? () => openLink(context, Uri(scheme: 'sms', path: digits, queryParameters: {'body': quote}))
                            : () => toast(context, 'Add a phone number to request a quote.'),
                      ),
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

class _SmallButton extends StatelessWidget {
  const _SmallButton({required this.label, required this.onTap, this.dark = false});
  final String label;
  final VoidCallback? onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: dark ? HC.ink : HC.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: dark ? BorderSide.none : const BorderSide(color: HC.line)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Center(
            widthFactor: 1,
            child: Text(label, style: body(12.5, weight: FontWeight.w600, color: dark ? Colors.white : (enabled ? HC.ink : HC.muted))),
          ),
        ),
      ),
    );
  }
}

/// A provider who joined Hoopla, with one-tap contact.
class _ProviderCard extends StatelessWidget {
  const _ProviderCard({required this.provider, required this.tile, this.miles});
  final ProviderProfile provider;
  final Color tile;

  /// Distance from where the customer is searching, when known.
  final double? miles;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final e = state.event!;
    final p = provider;
    final digits = p.phoneDigits;
    final hasPhone = digits.isNotEmpty;
    final quote = 'Hi ${p.businessName}, I found you on Hoopla. I\'m planning "${e.title}" on ${DateFormat('EEE, MMM d').format(e.date)} '
        'at ${clockAmPm(e.startMinutes)} for about ${e.guests} guests (${e.indoor ? 'indoor' : 'outdoor'}). '
        'Are you available, and could you share a quote?';
    final saved = e.shortlist.any((v) => v.id == p.uid);
    final details = [
      if (miles != null) distanceLabel(miles!) else p.city,
      if (miles != null) p.city,
      if (p.priceRange.isNotEmpty) p.priceRange,
    ].join(' · ');
    final estimate = estimateLabel(p, e);

    /// Real listings call/message; sample listings explain what they are.
    VoidCallback? contact(VoidCallback action) {
      if (p.isSample) return () => toast(context, sampleContactNote);
      return hasPhone ? action : null;
    }

    void openDetails() => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => ProviderDetailScreen(provider: p, quote: quote)),
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CardBox(
        padding: const EdgeInsets.all(10),
        onTap: openDetails,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (p.photos.length > 1) ...[
              SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: p.photos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, i) => GestureDetector(
                    onTap: () => openPhotoViewer(context, p.photos, i),
                    child: SizedBox(width: 92, child: GalleryImage(p.photos[i], radius: 12)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 76,
              height: 76,
              child: p.photos.isNotEmpty
                  ? GalleryImage(p.photos.first, radius: 14)
                  : Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: tile, borderRadius: BorderRadius.circular(14)),
                      child: Text(p.businessName.isEmpty ? '?' : p.businessName[0].toUpperCase(), style: display(28)),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(p.businessName, style: body(15, weight: FontWeight.w600))),
                      if (p.isSample) ...[
                        const SizedBox(width: 6),
                        const SampleTag(),
                      ],
                      if (p.verified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_rounded, size: 16, color: HC.violet, semanticLabel: 'Verified'),
                      ],
                    ],
                  ),
                  RatingBadge(providerUid: p.uid),
                  if (details.isNotEmpty) Text(details, style: body(12, color: HC.muted)),
                  if (estimate.isNotEmpty) Text(estimate, style: body(12, color: HC.violet, weight: FontWeight.w600)),
                  if (p.about.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(p.about, maxLines: 2, overflow: TextOverflow.ellipsis, style: body(12, color: HC.muted)),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _SmallButton(label: 'Call', onTap: contact(() {
                    QuoteService.logTap(p, 'call');
                    openLink(context, Uri(scheme: 'tel', path: digits));
                  })),
                      _SmallButton(
                        label: 'WhatsApp',
                        onTap: contact(() {
                    QuoteService.logTap(p, 'whatsapp');
                    openLink(context, Uri.https('wa.me', '/$digits', {'text': quote}));
                  }),
                      ),
                      _SmallButton(
                        label: 'Get quote',
                        dark: true,
                        onTap: () => requestQuote(context, p),
                      ),
                      if (!p.isSample)
                        _SmallButton(
                        label: saved ? 'Saved' : 'Save',
                        onTap: saved
                            ? null
                            : () => state.update((ev) => ev.shortlist.add(ShortlistVendor(
                                  id: p.uid,
                                  category: p.serviceType,
                                  name: p.businessName,
                                  phone: p.phone,
                                  note: p.priceRange,
                                ))),
                      ),
                      _SmallButton(label: p.photos.isEmpty ? 'Details' : 'See work', onTap: openDetails),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
          ],
        ),
      ),
    );
  }
}
