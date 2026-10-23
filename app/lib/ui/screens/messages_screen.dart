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
            tabs: [
              Tab(text: l.t('direct')),
              Tab(text: l.t('community')),
              Tab(text: l.t('mission')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _channelList(context, l, const [
              ('Chris', 'Water at community center', 'delivered'),
              ('Shelter 18', 'We have 40 beds open', 'read'),
            ]),
            _channelList(context, l, const [
              ('# water', 'Tap to open channel', ''),
              ('# roads', 'Tap to open channel', ''),
            ]),
            _channelList(context, l, const [
              ('Mission 2193', 'Water, 20 cases', 'queued'),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _channelList(
      BuildContext context, L10n l, List<(String, String, String)> items) {
    if (items.isEmpty) {
      return Center(
        child: Text(l.t('type_a_message'),
            style: TextStyle(
                fontSize: 16, color: Theme.of(context).colorScheme.outline)),
      );
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, i) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final (name, preview, state) = items[i];
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person_rounded)),
          title: Text(name),
          subtitle: Text(preview),
          trailing: state.isEmpty ? null : _DeliveryIcon(state: state, l: l),
          onTap: () {},
        );
      },
    );
  }
}

class _DeliveryIcon extends StatelessWidget {
  final String state;
  final L10n l;
  const _DeliveryIcon({required this.state, required this.l});
  @override
  Widget build(BuildContext context) {
    final (IconData icon, String label) = switch (state) {
      'queued' => (Icons.schedule_rounded, l.t('queued')),
      'propagating' => (Icons.wifi_tethering_rounded, l.t('propagating')),
      'delivered' => (Icons.done_rounded, l.t('delivered')),
      'read' => (Icons.done_all_rounded, l.t('read')),
      _ => (Icons.circle, ''),
    };
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 20),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 16)),
    ]);
  }
}
