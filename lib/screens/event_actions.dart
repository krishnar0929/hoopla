import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/event_details.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'setup_screen.dart';
import 'upgrade_screen.dart';

const _danger = Color(0xFFB42318);

/// "Start new event". Free plans keep one event, so offer to replace it or upgrade.
Future<void> startNewEvent(BuildContext context) async {
  final state = AppScope.of(context);
  final nav = Navigator.of(context);
  if (state.canAddEvent) {
    await nav.push(MaterialPageRoute<void>(builder: (_) => const SetupScreen()));
    return;
  }
  final current = state.event;
  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Free plan keeps one event'),
      content: Text(
        'Upgrade to plan several events at once, or replace "${current?.title ?? 'your event'}". '
        'It moves to My events → Cancelled and you can bring it back later.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, 'replace'), child: const Text('Replace it')),
        FilledButton(onPressed: () => Navigator.pop(ctx, 'upgrade'), child: const Text('See plans')),
      ],
    ),
  );
  if (choice == 'upgrade') {
    await nav.push(MaterialPageRoute<void>(builder: (_) => const UpgradeScreen()));
  } else if (choice == 'replace') {
    await nav.push(MaterialPageRoute<void>(builder: (_) => SetupScreen(replaceId: current?.id)));
  }
}

/// Asks first, then moves the event to Cancelled.
Future<void> confirmCancelEvent(BuildContext context, EventDetails e) async {
  final state = AppScope.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Cancel "${e.title}"?'),
      content: const Text('It moves to My events → Cancelled. You can restore it anytime.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep it')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _danger),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Cancel event'),
        ),
      ],
    ),
  );
  if (ok == true) await state.cancelEvent(e.id);
}

/// List of active and cancelled events; switch, restore, or start a new one.
void showMyEvents(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: HC.ground,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) {
      final state = AppScope.of(ctx);
      final active = state.activeEvents;
      final cancelled = state.cancelledEvents;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('My events', style: display(22)),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.55),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (active.isEmpty) Text('No active events.', style: body(14, color: HC.muted)),
                    for (final e in active)
                      _EventRow(
                        event: e,
                        current: e.id == state.event?.id,
                        onTap: () {
                          state.switchTo(e.id);
                          Navigator.pop(ctx);
                        },
                      ),
                    if (cancelled.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text('CANCELLED', style: overline()),
                      const SizedBox(height: 6),
                      for (final e in cancelled)
                        _EventRow(
                          event: e,
                          cancelled: true,
                          onRestore: () async {
                            if (!state.canAddEvent) {
                              Navigator.pop(ctx);
                              toast(context, 'Free plan keeps one event. Cancel the current one or upgrade to restore this.');
                              return;
                            }
                            await state.restoreEvent(e.id);
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: HC.line),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    startNewEvent(context);
                  },
                  icon: const Icon(Icons.add_rounded, color: HC.ink),
                  label: Text('Start new event', style: body(14, weight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, this.current = false, this.cancelled = false, this.onTap, this.onRestore});
  final EventDetails event;
  final bool current;
  final bool cancelled;
  final VoidCallback? onTap;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CardBox(
        radius: 14,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title, style: body(15, weight: FontWeight.w600, color: cancelled ? HC.muted : HC.ink)),
                  const SizedBox(height: 2),
                  Text('${event.occasion} · ${DateFormat('EEE, MMM d').format(event.date)}', style: body(12, color: HC.muted)),
                ],
              ),
            ),
            if (current) const Icon(Icons.check_circle_rounded, color: HC.violet),
            if (cancelled && onRestore != null) TextButton(onPressed: onRestore, child: const Text('Restore')),
          ],
        ),
      ),
    );
  }
}
