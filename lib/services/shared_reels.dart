import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/event_details.dart';

/// Reels people send to Hoopla from Instagram's share menu ("Share to… → Hoopla").
///
/// iPhone: the HooplaShare extension saves them in the shared App Group.
/// Android: MainActivity receives the share. Both hand them over on this channel.
class SharedReels {
  static const _channel = MethodChannel('hoopla/share');

  /// Takes every reel shared since the last call (each one is returned once).
  static Future<List<SavedLink>> take({DateTime? now}) async {
    if (kIsWeb) return const [];
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('takeSharedReels') ?? const [];
      final links = <SavedLink>[];
      for (final item in raw) {
        if (item is! Map) continue;
        final url = firstLink('${item['url'] ?? ''}');
        if (url == null) continue;
        final title = '${item['title'] ?? ''}'.trim();
        links.add(SavedLink(title: title.isEmpty ? defaultTitle(url, now: now) : title, url: url));
      }
      return links;
    } on MissingPluginException {
      return const [];
    } catch (e) {
      debugPrint('Could not read shared reels: $e');
      return const [];
    }
  }
}

/// The first web link in a piece of text (Instagram often shares "caption + link").
String? firstLink(String text) {
  final m = RegExp(r'https?://[^\s<>"]+').firstMatch(text);
  if (m == null) return null;
  return m.group(0)!.replaceAll(RegExp(r'[.,;:!?)\]]+$'), '');
}

/// True for links that are short videos people save game ideas from.
bool isReelLink(String url) => reelSource(url) != null;

/// "Instagram reel", "TikTok", "YouTube Short", "Facebook reel", or null.
String? reelSource(String url) {
  final u = url.toLowerCase();
  if (u.contains('instagram.com/')) return 'Instagram reel';
  if (u.contains('tiktok.com/')) return 'TikTok';
  if (u.contains('youtube.com/shorts') || u.contains('youtu.be/') || u.contains('youtube.com/watch')) return 'YouTube Short';
  if (u.contains('facebook.com/') || u.contains('fb.watch/')) return 'Facebook reel';
  return null;
}

/// Name used when the person doesn't type one: "Instagram reel · Nov 12".
String defaultTitle(String url, {DateTime? now}) {
  final source = reelSource(url) ?? 'Saved video';
  return '$source · ${DateFormat('MMM d').format(now ?? DateTime.now())}';
}
