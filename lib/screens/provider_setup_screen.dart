import 'package:flutter/material.dart';

import '../data/helpers.dart';
import '../models/provider_profile.dart';
import '../services/account_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
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
  late String serviceType;
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
    serviceType = p?.serviceType ?? helperCategories.first.label;
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    cityCtrl.dispose();
    phoneCtrl.dispose();
    priceCtrl.dispose();
    aboutCtrl.dispose();
    super.dispose();
  }

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
      ));
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
                const SizedBox(height: 8),
                Text('Photos of your work are coming soon.', style: body(12, color: HC.muted)),
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
