import 'dart:async';

import 'package:flutter/material.dart';

import '../services/location_service.dart';
import '../theme.dart';

/// Pick a place: "Use my current location" or search an address, venue or city.
/// Returns null when closed without picking.
Future<Place?> pickPlace(BuildContext context, {String title = 'Where\'s the party?', String hint = 'Venue name, address or city'}) {
  return showModalBottomSheet<Place>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: HC.ground,
    constraints: const BoxConstraints(maxWidth: 600),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => _PlaceSheet(title: title, hint: hint),
  );
}

class _PlaceSheet extends StatefulWidget {
  const _PlaceSheet({required this.title, required this.hint});
  final String title;
  final String hint;

  @override
  State<_PlaceSheet> createState() => _PlaceSheetState();
}

class _PlaceSheetState extends State<_PlaceSheet> {
  final ctrl = TextEditingController();
  Timer? _pause;
  List<Place> results = const [];
  bool searching = false;
  bool locating = false;
  String? error;
  int _query = 0;

  @override
  void dispose() {
    _pause?.cancel();
    ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _pause?.cancel();
    _pause = Timer(const Duration(milliseconds: 700), () => _search(v));
  }

  Future<void> _search(String v) async {
    final id = ++_query;
    if (v.trim().length < 3) {
      setState(() => results = const []);
      return;
    }
    setState(() {
      searching = true;
      error = null;
    });
    try {
      final found = await LocationService.search(v);
      if (!mounted || id != _query) return;
      setState(() {
        results = found;
        if (found.isEmpty) error = 'No matches. Try adding the city or ZIP code.';
      });
    } catch (e) {
      if (mounted && id == _query) setState(() => error = 'Couldn\'t search right now. Check your connection.');
    } finally {
      if (mounted && id == _query) setState(() => searching = false);
    }
  }

  Future<void> _current() async {
    setState(() {
      locating = true;
      error = null;
    });
    try {
      final p = await LocationService.current();
      if (mounted) Navigator.pop(context, p);
    } catch (e) {
      if (mounted) {
        setState(() {
          locating = false;
          error = e is StateError ? e.message : 'Couldn\'t find your location. Type an address instead.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: display(24)),
          const SizedBox(height: 14),
          Material(
            color: HC.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: HC.line)),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: locating ? null : _current,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: HC.violet.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                      child: locating
                          ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2.4))
                          : const Icon(Icons.my_location_rounded, color: HC.violet),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(locating ? 'Finding you…' : 'Use my current location', style: body(15, weight: FontWeight.w600)),
                          Text('Good when the party is at home', style: body(12, color: HC.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            autofocus: false,
            textInputAction: TextInputAction.search,
            onChanged: _onChanged,
            onSubmitted: _search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: widget.hint,
              suffixIcon: searching ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))) : null,
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(error!, style: body(13, color: const Color(0xFFB42318), weight: FontWeight.w500)),
            ),
          const SizedBox(height: 6),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final p in results)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: const Icon(Icons.place_outlined, color: HC.violet),
                    title: Text(p.address.isNotEmpty ? p.address : p.label, maxLines: 2, overflow: TextOverflow.ellipsis, style: body(14, weight: FontWeight.w600)),
                    subtitle: Text(p.label, style: body(12, color: HC.muted)),
                    onTap: () => Navigator.pop(context, p),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text('Addresses © OpenStreetMap contributors', textAlign: TextAlign.center, style: body(11, color: HC.muted)),
        ],
      ),
    );
  }
}
