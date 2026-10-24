import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../l10n/labels.dart';
import '../../models/mesh_message.dart';
import '../../models/network.dart';
import '../../models/role.dart';
import '../../models/social.dart';
import '../../state/app_scope.dart';
import '../../ui/theme.dart';
import '../../ui/visuals.dart';

/// The route a message would take right now, in plain words.
String routeLabel(AppLocalizations l, NetworkStatus n) => n.internet
    ? l.routeInternet
    : n.node
        ? l.routeLocal
        : n.lora
            ? l.routeMesh
            : l.routeQueued;

/// Conversations as three swipeable tabs: Direct, Community, Mission.
class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final repo = scope.repository;
    final l = AppLocalizations.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([
        repo.channels,
        repo.messages,
        repo.network,
        repo.loading,
        scope.auth,
      ]),
      builder: (context, _) {
        // Restricted channels need staff authorization. This hides them;
        // the network must also refuse to deliver them.
        final staff = scope.auth.role.atLeast(Role.manager);
        final channels = [
          for (final c in repo.channels.value)
            if (c.type != ChannelType.restricted || staff) c,
        ];
        List<Channel> of(Set<ChannelType> types) => [
              for (final c in channels)
                if (types.contains(c.type)) c,
            ];

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: Text(l.navMessages),
              bottom: TabBar(
                tabs: [
                  Tab(text: l.tabDirect),
                  Tab(text: l.tabCommunity),
                  Tab(text: l.tabMission),
                ],
              ),
            ),
            body: Column(
              children: [
                _RouteLine(network: repo.network.value),
                Expanded(
                  child: TabBarView(
                    children: [
                      _ChannelList(
                        channels: of({ChannelType.direct}),
                        messages: repo.messages.value,
                        loading: repo.loading.value,
                      ),
                      _ChannelList(
                        channels: of({
                          ChannelType.public,
                          ChannelType.community,
                          ChannelType.restricted,
                        }),
                        messages: repo.messages.value,
                        loading: repo.loading.value,
                      ),
                      _ChannelList(
                        channels: of({ChannelType.mission}),
                        messages: repo.messages.value,
                        loading: repo.loading.value,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({required this.network});

  final NetworkStatus network;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = Theme.of(context).colorScheme;
    final queued = !(network.internet || network.node || network.lora);

    return InkWell(
      onTap: () => context.go('/more/network'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            Icon(
              network.internet
                  ? Icons.cloud_done_outlined
                  : queued
                      ? Icons.schedule
                      : Icons.cell_tower,
              color: c.primary,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(l.sendsOver(routeLabel(l, network)))),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _ChannelList extends StatelessWidget {
  const _ChannelList({
    required this.channels,
    required this.messages,
    required this.loading,
  });

  final List<Channel> channels;
  final List<MeshMessage> messages;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    const padding = EdgeInsets.only(bottom: helpButtonClearance + 16);

    if (loading) {
      return Skeletonizer(
        child: ListView(
          padding: padding,
          children: [
            for (var i = 0; i < 4; i++)
              const ListTile(
                leading: CircleAvatar(child: Icon(Icons.groups_outlined)),
                title: Text('neighborhood'),
                subtitle: Text('Checking on the seniors on our block.'),
              ),
          ],
        ),
      );
    }
    if (channels.isEmpty) return Center(child: Text(l.noChannels));

    return ListView(
      padding: padding,
      children: [
        for (final channel in channels)
          _ChannelTile(
            channel: channel,
            last: messages.where((m) => m.channelId == channel.id).lastOrNull,
          ),
      ],
    );
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({required this.channel, required this.last});

  final Channel channel;
  final MeshMessage? last;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = Theme.of(context).colorScheme;
    final named = channel.type == ChannelType.direct || channel.type == ChannelType.mission
        ? channel.name
        : '# ${channel.name}';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: channel.type == ChannelType.restricted
            ? c.tertiaryContainer
            : c.secondaryContainer,
        child: Icon(channelIcon(channel.type)),
      ),
      title: Text(named),
      // The time sits under the preview, not at the end of the row, so long
      // translations ("5 min ang nakalipas") never squeeze the title.
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            last == null ? l.channelType(channel.type) : '${last!.senderName}: ${last!.text}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (last != null)
            Text(l.timeAgo(last!.timestamp), style: TextStyle(color: c.outline)),
        ],
      ),
      onTap: () => context.go('/messages/${channel.id}'),
    );
  }
}
