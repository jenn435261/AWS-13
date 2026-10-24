import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../l10n/labels.dart';
import '../../models/mesh_message.dart';
import '../../models/network.dart';
import '../../models/role.dart';
import '../../models/social.dart';
import '../../router.dart';
import '../../state/app_scope.dart';
import '../../ui/surfaces.dart';
import '../../ui/theme.dart';
import '../../ui/visuals.dart';
import '../shell/bottom_actions.dart';

/// The route a message would take right now, in plain words.
String routeLabel(AppLocalizations l, NetworkStatus n) => n.internet
    ? l.routeInternet
    : n.node
        ? l.routeLocal
        : n.lora
            ? l.routeMesh
            : l.routeQueued;

/// The direct chat with [contact], if there is one.
Channel? directChannelFor(Contact contact, List<Channel> channels) => channels
    .where((c) =>
        c.type == ChannelType.direct &&
        (c.id == 'dm-${contact.name.toLowerCase()}' ||
            c.name.toLowerCase() == contact.name.toLowerCase()))
    .firstOrNull;

/// The channels this phone's user may read. Restricted channels need staff
/// authorization: this hides them, and the network must also refuse to
/// deliver them.
List<Channel> readableChannels(AppScope scope) {
  final staff = scope.auth.role.atLeast(Role.manager);
  return [
    for (final c in scope.repository.channels.value)
      if (c.type != ChannelType.restricted || staff) c,
  ];
}

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
        final channels = readableChannels(scope);
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
            bottomNavigationBar: BottomActions(
              main: MainButton(
                label: l.navNewMessage,
                icon: Icons.edit_outlined,
                onPressed: () => context.push(newMessagePath),
              ),
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
      onTap: () => context.push(networkPath),
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
    final padding = EdgeInsets.only(bottom: bottomClearance(context));

    if (loading) {
      return Skeletonizer(
        child: ListView(
          padding: padding,
          children: [
            // Stand-in rows, drawn as grey bars while loading.
            for (var i = 0; i < 4; i++)
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.groups_outlined)),
                title: Text(l.channelCommunity),
                subtitle: Text(l.noChannels),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: channel.type == ChannelType.direct
          ? Avatar(name: channel.name, size: 48)
          : IconTile(icon: channelIcon(channel.type), color: channelHue(channel.type), size: 48),
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
      onTap: () => context.push(chatPath(channel.id)),
    );
  }
}

/// Starts a conversation: pick a person or a channel, and its chat opens in
/// place of this screen, so Back returns to the list.
class NewMessageScreen extends StatelessWidget {
  const NewMessageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final repo = scope.repository;
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.navNewMessage)),
      body: ListenableBuilder(
        listenable: Listenable.merge([repo.channels, repo.contacts, scope.auth]),
        builder: (context, _) {
          final channels = readableChannels(scope);
          // People are the contacts there is a direct chat with.
          final people = [
            for (final contact in repo.contacts.value)
              if (contact.kind == ContactKind.person)
                if (directChannelFor(contact, channels) case final channel?)
                  (contact, channel),
          ]..sort((a, b) => a.$1.name.compareTo(b.$1.name));
          final groups = [
            for (final c in channels)
              if (c.type != ChannelType.direct && !c.readOnly) c,
          ];
          void open(Channel channel) => context.pushReplacement(chatPath(channel.id));

          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              GroupHeader(l.tabPeople),
              if (people.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Text(l.navNoDirectChats),
                )
              else
                GroupCard(children: [
                  for (final (contact, channel) in people)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      leading: Avatar(name: contact.name, size: 44),
                      title: Text(contact.name),
                      subtitle: Text(l.contactSource(contact)),
                      onTap: () => open(channel),
                    ),
                ]),
              GroupHeader(l.navChannels),
              GroupCard(children: [
                for (final channel in groups)
                  GroupTile(
                    icon: channelIcon(channel.type),
                    hue: channelHue(channel.type),
                    title: channel.type == ChannelType.mission ? channel.name : '# ${channel.name}',
                    subtitle: l.channelType(channel.type),
                    onTap: () => open(channel),
                  ),
              ]),
            ],
          );
        },
      ),
    );
  }
}
