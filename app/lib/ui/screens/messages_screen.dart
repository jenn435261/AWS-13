import 'package:flutter/material.dart';

import '../../l10n/strings.dart';

/// Messages: Direct / Community / Mission (swipeable tabs). Connection state is
/// surfaced per spec §61. Conversation UI is intentionally minimal.
class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.t('nav_messages')),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: l.t('direct')),
              Tab(text: l.t('community')),
              Tab(text: l.t('mission')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _notConnected(context, l),
            _notConnected(context, l),
            _notConnected(context, l),
          ],
        ),
      ),
    );
  }

  /// Honest empty state: there is no conversation transport yet (needs prekey
  /// publication, a durable Signal store and sync), so we say so rather than
  /// show invented chats.
  Widget _notConnected(BuildContext context, L10n l) {
    final outline = Theme.of(context).colorScheme.outline;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline_rounded, size: 48, color: outline),
            const SizedBox(height: 12),
            Text(l.t('msg_not_connected'),
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Roboto', fontSize: 18, color: outline)),
            const SizedBox(height: 6),
            Text(l.t('msg_not_connected_hint'),
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Roboto', fontSize: 16, color: outline)),
          ],
        ),
      ),
    );
  }
}
