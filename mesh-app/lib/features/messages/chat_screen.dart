import 'package:flutter/material.dart';

import '../../l10n/labels.dart';
import '../../models/mesh_message.dart';
import '../../models/social.dart';
import '../../state/app_scope.dart';
import '../../state/drafts.dart';
import '../../ui/feedback.dart';
import '../../ui/theme.dart';
import '../../ui/visuals.dart';
import '../../utils/format.dart';
import 'messages_screen.dart';

/// One conversation. A message with no route stays queued on the phone and
/// moves on when any route appears (Spec sections 16 and 17).
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.channelId});

  final String channelId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    Haptics.success();
    final scope = AppScope.of(context);
    scope.repository.sendMessage(widget.channelId, text, from: scope.auth.me);
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final repo = scope.repository;
    final l = AppLocalizations.of(context);
    final c = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: Listenable.merge([repo.channels, repo.messages, repo.network]),
      builder: (context, _) {
        final channel =
            repo.channels.value.where((ch) => ch.id == widget.channelId).firstOrNull;
        if (channel == null) {
          return Scaffold(appBar: AppBar(), body: Center(child: Text(l.noChannels)));
        }
        final messages = [
          for (final m in repo.messages.value)
            if (m.channelId == channel.id) m,
        ];
        final myId = repo.identity.resilienceId;
        final title = channel.type == ChannelType.direct || channel.type == ChannelType.mission
            ? channel.name
            : '# ${channel.name}';

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title),
                Text(
                  l.channelType(channel.type),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: c.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: messages.isEmpty
                    ? Center(child: Text(l.noMessages))
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(12),
                        itemCount: messages.length,
                        itemBuilder: (context, i) {
                          final m = messages[messages.length - 1 - i];
                          return _Bubble(message: m, mine: m.senderId == myId);
                        },
                      ),
              ),
              const Divider(height: 1),
              if (channel.readOnly)
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, bottomClearance(context)),
                  child: Row(
                    children: [
                      Icon(Icons.campaign_outlined, color: c.primary),
                      const SizedBox(width: 12),
                      Expanded(child: Text(l.readOnlyChannel)),
                    ],
                  ),
                )
              else
                _Composer(
                  controller: _controller,
                  onSend: _send,
                  route: routeLabel(l, repo.network.value),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine});

  final MeshMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    // My messages sit on the brand color; white text in light mode, the
    // dark ink in dark mode, both above 4.5:1.
    final ink = mine ? (dark ? colors.onPrimary : Colors.white) : colors.onSurface;
    final meta = text.bodyMedium?.copyWith(
      color: mine ? ink.withValues(alpha: 0.9) : colors.onSurfaceVariant,
    );
    const round = Radius.circular(22);
    const tail = Radius.circular(6);

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        decoration: BoxDecoration(
          color: mine ? colors.primary : colors.surfaceContainerLowest,
          border: mine ? null : Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.only(
            topLeft: round,
            topRight: round,
            bottomLeft: mine ? round : tail,
            bottomRight: mine ? tail : round,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine)
              Text(message.senderName, style: text.titleSmall?.copyWith(color: colors.primary)),
            Text(message.text, style: text.bodyLarge?.copyWith(color: ink)),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(clockTime(message.timestamp), style: meta),
                if (mine) ...[
                  const SizedBox(width: 6),
                  Icon(deliveryIcon(message.status), size: 18, color: meta?.color),
                  const SizedBox(width: 4),
                  Text(l.delivery(message.status), style: meta),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.onSend,
    required this.route,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final String route;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(8, 8, 8, bottomClearance(context) - 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: Text(l.sendsOver(route), style: TextStyle(color: c.onSurfaceVariant)),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: maxNoteLength,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: l.messageHint,
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: onSend,
                tooltip: l.send,
                iconSize: 26,
                style: IconButton.styleFrom(minimumSize: const Size(52, 52)),
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
