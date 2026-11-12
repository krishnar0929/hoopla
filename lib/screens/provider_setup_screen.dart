import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/helpers.dart';
import '../models/provider_profile.dart';
import '../services/account_service.dart';
import '../services/gallery_service.dart';
import '../services/shared_reels.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/gallery.dart';
import 'account_sheet.dart';

/// A provider creates or edits their public listing.
class ProviderSetupScreen extends StatefulWidget {
  const ProviderSetupScreen({super.key, this.existing});

  final ProviderProfile? existing;

  @override
  State<ProviderSetupScreen> createState() => _ProviderSetupScreenState();
}

class _ProviderSetupScreenState extends State<ProviderSetupScreen> {
  late final TextEditingController nameCtrl;
  late final TextEditingController cityCtrl;
  late final TextEditingController phoneCtrl;
  late final TextEditingController priceCtrl;
  late final TextEditingController aboutCtrl;
  late final TextEditingController instaCtrl;
  late final TextEditingController webCtrl;
  late final TextEditingController fbCtrl;
  late final TextEditingController ytCtrl;
  late final TextEditingController ttCtrl;
  late final TextEditingController reviewsCtrl;
  final featuredCtrl = TextEditingController();

  /// Links to their best reels and videos.
  late List<String> featured;
  late String serviceType;

  /// Work photos (download links). The first one is the cover.
  late List<String> photos;

  /// Photos removed here; deleted from storage once the listing is saved.
  final List<String> removed = [];
  int uploading = 0;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    nameCtrl = TextEditingController(text: p?.businessName ?? '');
    cityCtrl = TextEditingController(text: p?.city ?? '');
    phoneCtrl = TextEditingController(text: p?.phone ?? '');
    priceCtrl = TextEditingController(text: p?.priceRange ?? '');
    aboutCtrl = TextEditingController(text: p?.about ?? '');
    instaCtrl = TextEditingController(text: p?.instagram ?? '');
    webCtrl = TextEditingController(text: p?.website ?? '');
    fbCtrl = TextEditingController(text: p?.facebook ?? '');
    ytCtrl = TextEditingController(text: p?.youtube ?? '');
    ttCtrl = TextEditingController(text: p?.tiktok ?? '');
    reviewsCtrl = TextEditingController(text: p?.reviewsLink ?? '');
    featured = List.of(p?.featured ?? const <String>[]);
    photos = List.of(p?.photos ?? const <String>[]);
    serviceType = p?.serviceType ?? helperCategories.first.label;
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    cityCtrl.dispose();
    phoneCtrl.dispose();
    priceCtrl.dispose();
    aboutCtrl.dispose();
    instaCtrl.dispose();
    webCtrl.dispose();
    fbCtrl.dispose();
    ytCtrl.dispose();
    ttCtrl.dispose();
    reviewsCtrl.dispose();
    featuredCtrl.dispose();
    super.dispose();
  }

  void _addFeatured() {
    final url = firstLink(featuredCtrl.text);
    if (url == null) {
      toast(context, 'Paste a link, e.g. from Instagram: Share → Copy link.');
      return;
    }
    if (featured.length >= ProviderProfile.maxFeatured) {
      toast(context, 'You can feature up to ${ProviderProfile.maxFeatured} posts.');
      return;
    }
    if (featured.contains(url)) {
      featuredCtrl.clear();
      return;
    }
    setState(() {
      featured.add(url);
      featuredCtrl.clear();
    });
  }

  Future<void> _addPhotos() async {
    final room = ProviderProfile.maxPhotos - photos.length - uploading;
    if (room <= 0) {
      toast(context, 'You can show up to ${ProviderProfile.maxPhotos} photos. Remove one to add another.');
      return;
    }
    List<XFile> files;
    try {
      files = await GalleryService.pick(limit: room);
    } catch (e) {
      if (mounted) toast(context, 'Could not open your photos. Check Hoopla\'s photo access in Settings.');
      return;
    }
    if (files.isEmpty || !mounted) return;
    setState(() => uploading += files.length);
    var failed = 0;
    String? reason;
    for (final f in files) {
      try {
        final url = await GalleryService.upload(f);
        if (mounted) setState(() => photos.add(url));
      } catch (e) {
        failed++;
        reason ??= '$e';
      } finally {
        if (mounted) setState(() => uploading--);
      }
    }
    if (failed > 0 && mounted) {
      toast(context, failed == files.length ? 'Upload failed: $reason' : '$failed photo${failed == 1 ? '' : 's'} didn\'t upload. Try again.');
    }
  }

  void _removePhoto(String url) => setState(() {
        photos.remove(url);
        removed.add(url);
      });

  void _makeCover(String url) => setState(() {
        photos.remove(url);
        photos.insert(0, url);
      });

  Future<void> _save() async {
    final state = AppScope.of(context);
    final uid = state.accounts?.user?.uid;
    if (uid == null || !state.isSignedIn) {
      setState(() => error = 'Please sign in again.');
      return;
    }
    if (nameCtrl.text.trim().isEmpty || cityCtrl.text.trim().isEmpty || phoneCtrl.text.replaceAll(RegExp(r'[^0-9]'), '').length < 7) {
      setState(() => error = 'Add your business name, city and a phone number.');
      return;
    }
    if (featuredCtrl.text.trim().isNotEmpty) _addFeatured();
    if (uploading > 0) {
      setState(() => error = 'Wait for your photos to finish uploading.');
      return;
    }
    final nav = Navigator.of(context);
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await state.saveProvider(ProviderProfile(
        uid: uid,
        businessName: nameCtrl.text.trim(),
        serviceType: serviceType,
        city: cityCtrl.text.trim(),
        phone: phoneCtrl.text.trim(),
        priceRange: priceCtrl.text.trim(),
        about: aboutCtrl.text.trim(),
        photos: photos,
        instagram: cleanInstagram(instaCtrl.text),
        website: webCtrl.text.trim(),
        facebook: fbCtrl.text.trim(),
        youtube: ytCtrl.text.trim(),
        tiktok: ttCtrl.text.trim(),
        reviewsLink: reviewsCtrl.text.trim(),
        featured: featured,
      ));
      for (final url in removed) {
        GalleryService.delete(url);
      }
      removed.clear();
      if (nav.canPop()) nav.pop();
    } catch (e) {
      if (mounted) setState(() => error = 'Could not save: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final editing = widget.existing != null;
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                Row(
                  children: [
                    if (canPop)
                      IconButton(tooltip: 'Back', onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back_rounded))
                    else
                      Text('HOOPLA FOR BUSINESS', style: overline()),
                    const Spacer(),
                    IconButton(tooltip: 'Account', onPressed: () => showAccountSheet(context), icon: const Icon(Icons.person_outline_rounded)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(editing ? 'Edit your listing' : 'Set up your listing', style: display(30)),
                const SizedBox(height: 6),
                Text('Customers planning events nearby will find you and reach you by call or WhatsApp.', style: body(14, color: HC.muted)),
                const SizedBox(height: 22),
                const SectionLabel('Business name'),
                TextField(controller: nameCtrl, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(hintText: 'e.g. Lens & Laughter Studio')),
                const SizedBox(height: 18),
                const SectionLabel('What do you offer?'),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in helperCategories)
                      Pill(
                        label: c.label,
                        small: true,
                        selectedColor: HC.violet,
                        selected: c.label == serviceType,
                        onTap: () => setState(() => serviceType = c.label),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                const SectionLabel('City or area'),
                TextField(controller: cityCtrl, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(hintText: 'e.g. Edison, NJ')),
                const SizedBox(height: 18),
                const SectionLabel('Phone / WhatsApp'),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(hintText: 'With country code, e.g. +1 732 555 0100'),
                ),
                const SizedBox(height: 18),
                const SectionLabel('Price range'),
                TextField(controller: priceCtrl, decoration: const InputDecoration(hintText: r'e.g. $300–$800 per event')),
                const SizedBox(height: 18),
                const SectionLabel('About your work'),
                TextField(
                  controller: aboutCtrl,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'Styles, languages, what\'s included, how far you travel'),
                ),
                const SizedBox(height: 22),
                const SectionLabel('Photos of your work'),
                Text(
                  'Your best work sells for you. Add up to ${ProviderProfile.maxPhotos} photos: setups, cakes, events you\'ve shot. '
                  'Long-press a photo to make it your cover.',
                  style: body(13, color: HC.muted),
                ),
                const SizedBox(height: 10),
                _GalleryEditor(
                  photos: photos,
                  uploading: uploading,
                  onAdd: _addPhotos,
                  onRemove: _removePhoto,
                  onCover: _makeCover,
                ),
                const SizedBox(height: 22),
                const SectionLabel('Your social media'),
                Text(
                  'Customers tap these to see more of your work and your reviews. Add a handle or paste a link. All optional.',
                  style: body(13, color: HC.muted),
                ),
                const SizedBox(height: 10),
                _SocialField(controller: instaCtrl, icon: Icons.camera_alt_outlined, label: 'Instagram', hint: '@yourbusiness'),
                _SocialField(controller: fbCtrl, icon: Icons.facebook_rounded, label: 'Facebook page', hint: 'Page name or link'),
                _SocialField(controller: ytCtrl, icon: Icons.smart_display_outlined, label: 'YouTube', hint: '@yourchannel'),
                _SocialField(controller: ttCtrl, icon: Icons.music_note_rounded, label: 'TikTok', hint: '@yourbusiness'),
                _SocialField(
                  controller: reviewsCtrl,
                  icon: Icons.reviews_outlined,
                  label: 'Your reviews elsewhere',
                  hint: 'Google, Yelp or WeddingWire reviews link',
                  url: true,
                ),
                _SocialField(controller: webCtrl, icon: Icons.language_rounded, label: 'Website', hint: 'e.g. lensandlaughter.com', url: true),
                const SizedBox(height: 14),
                const SectionLabel('Featured posts'),
                Text(
                  'Show off your best reels and videos. In Instagram, YouTube or TikTok tap Share → Copy link, then paste here.',
                  style: body(13, color: HC.muted),
                ),
                const SizedBox(height: 10),
                for (final link in featured)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: CardBox(
                      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                      child: Row(
                        children: [
                          const Icon(Icons.play_circle_outline_rounded, color: HC.violet, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${reelSource(link) ?? 'Post'} · ${Uri.tryParse(link)?.path ?? ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: body(13),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove',
                            onPressed: () => setState(() => featured.remove(link)),
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (featured.length < ProviderProfile.maxFeatured)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: featuredCtrl,
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          decoration: const InputDecoration(hintText: 'Paste a reel or video link'),
                          onSubmitted: (_) => _addFeatured(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        style: IconButton.styleFrom(backgroundColor: HC.violet),
                        tooltip: 'Add post',
                        onPressed: _addFeatured,
                        icon: const Icon(Icons.add_rounded, color: Colors.white),
                      ),
                    ],
                  ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: body(13, color: const Color(0xFFB42318), weight: FontWeight.w500)),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  height: 54,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: HC.violet, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    onPressed: saving ? null : _save,
                    child: Text(editing ? 'Save changes' : 'Publish my listing', style: display(17, color: Colors.white)),
                  ),
                ),
                if (!canPop) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => state.setRole(UserRole.customer),
                    child: const Text('Not a provider? Plan an event instead'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Grid of the provider's photos with an "Add photos" tile.
class _GalleryEditor extends StatelessWidget {
  const _GalleryEditor({required this.photos, required this.uploading, required this.onAdd, required this.onRemove, required this.onCover});
  final List<String> photos;
  final int uploading;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;
  final ValueChanged<String> onCover;

  @override
  Widget build(BuildContext context) {
    final full = photos.length + uploading >= ProviderProfile.maxPhotos;
    final tiles = <Widget>[
      for (var i = 0; i < photos.length; i++)
        GestureDetector(
          onTap: () => openPhotoViewer(context, photos, i),
          onLongPress: () => onCover(photos[i]),
          child: Stack(
            fit: StackFit.expand,
            children: [
              GalleryImage(photos[i], radius: 12),
              if (i == 0)
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: HC.lime, borderRadius: BorderRadius.circular(6)),
                    child: Text('Cover', style: body(11, weight: FontWeight.w700)),
                  ),
                ),
              Positioned(
                right: 4,
                top: 4,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => onRemove(photos[i]),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close_rounded, size: 16, color: Colors.white, semanticLabel: 'Remove photo'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      for (var i = 0; i < uploading; i++)
        Container(
          decoration: BoxDecoration(color: HC.track, borderRadius: BorderRadius.circular(12)),
          alignment: Alignment.center,
          child: const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
        ),
      if (!full)
        Material(
          color: HC.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: HC.violet, width: 1.5)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onAdd,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_photo_alternate_outlined, color: HC.violet, size: 28),
                const SizedBox(height: 4),
                Text('Add photos', style: body(12, color: HC.violet, weight: FontWeight.w600)),
              ],
            ),
          ),
        ),
    ];
    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: tiles,
    );
  }
}

class _SocialField extends StatelessWidget {
  const _SocialField({required this.controller, required this.icon, required this.label, required this.hint, this.url = false});
  final TextEditingController controller;
  final IconData icon;
  final String label;
  final String hint;
  final bool url;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: url ? TextInputType.url : TextInputType.text,
        autocorrect: false,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: HC.violet),
          labelText: label,
          hintText: hint,
        ),
      ),
    );
  }
}
