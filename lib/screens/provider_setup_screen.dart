import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/helpers.dart';
import '../models/provider_profile.dart';
import '../services/account_service.dart';
import '../services/gallery_service.dart';
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
    super.dispose();
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
                const SizedBox(height: 18),
                const SectionLabel('Instagram'),
                TextField(
                  controller: instaCtrl,
                  autocorrect: false,
                  decoration: const InputDecoration(prefixText: '@ ', hintText: 'yourbusiness (customers can open your full gallery)'),
                ),
                const SizedBox(height: 18),
                const SectionLabel('Website (optional)'),
                TextField(
                  controller: webCtrl,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(hintText: 'e.g. lensandlaughter.com'),
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
