import '../models/event_details.dart';
import '../models/provider_profile.dart';

/// A provider's price range, read from text like "$400–$900 per event",
/// "$15–$30 per plate" or "$25/hour".
class PriceRange {
  const PriceRange(this.min, this.max, this.unit);
  final double min;
  final double max;

  /// 'event', 'plate' (per guest) or 'hour'.
  final String unit;

  static PriceRange? parse(String text) {
    final t = text.toLowerCase();
    final nums = [
      for (final m in RegExp(r'\d[\d,]*(?:\.\d+)?').allMatches(t)) double.tryParse(m.group(0)!.replaceAll(',', '')),
    ].whereType<double>().toList();
    if (nums.isEmpty) return null;
    final unit = (t.contains('plate') || t.contains('per guest') || t.contains('per person') || t.contains('/person'))
        ? 'plate'
        : (t.contains('hour') || t.contains('/hr') || t.contains(' hr')) ? 'hour' : 'event';
    final lo = nums.first;
    final hi = nums.length > 1 ? nums[1] : nums.first;
    return PriceRange(lo < hi ? lo : hi, lo < hi ? hi : lo, unit);
  }

  /// What this would cost for the whole event (guests × per plate, hours × per hour).
  (double, double) estimate(EventDetails e) => switch (unit) {
        'plate' => (min * e.guests, max * e.guests),
        'hour' => (min * e.hours, max * e.hours),
        _ => (min, max),
      };
}

/// Budget lines (from the plan's suggested split) mapped to the service types in Nearby.
const budgetServices = <String, String>{
  'Food': 'Caterers',
  'Decor': 'Decorators',
  'Photography': 'Photographers',
  'Cake & sweets': 'Cake makers',
  'Games & extras': 'DJs',
};

/// True when the provider's starting price fits in [amount] for this event.
/// Providers without a readable price are kept (they may still fit).
bool fitsBudget(ProviderProfile p, EventDetails e, double amount) {
  final range = PriceRange.parse(p.priceRange);
  if (range == null) return true;
  return range.estimate(e).$1 <= amount;
}

/// "$400–$900" style text for an estimate, rounded.
String estimateLabel(ProviderProfile p, EventDetails e) {
  final range = PriceRange.parse(p.priceRange);
  if (range == null || range.unit == 'event') return '';
  final (lo, hi) = range.estimate(e);
  String money(double v) => '\$${v.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')}';
  return 'About ${money(lo)}–${money(hi)} for ${range.unit == 'plate' ? '${e.guests} guests' : '${e.hours} hours'}';
}
