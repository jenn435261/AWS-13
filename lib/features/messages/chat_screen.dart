import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/mesh_repository.dart';
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

  /// Message id -> translation, while the translation is showing.
  final _translated = <String, String>{};

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

  Future<void> _toggleTranslation(MeshMessage m) async {
    if (_translated.containsKey(m.id)) {
      setState(() => _translated.remove(m.id));
      return;
    }
    final scope = AppScope.of(context);
    final l = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    try {
      final text = await scope.repository.translate(m.text, toLanguage: language);
      if (mounted) setState(() => _translated[m.id] = text);
    } on NeedsInternet {
      scope.feedback.toast(l.translationFailed, icon: Icons.cloud_off_outlined);
    } catch (_) {
      scope.feedback.toast(l.translationFailed, icon: Icons.translate);
    }
  }

  /// Tap-and-hold on a message: copy it, or translate it.
  Future<void> _showMessageActions(MeshMessage m) {
    Haptics.tick();
    final scope = AppScope.of(context);
    final l = AppLocalizations.of(context);
    final showing = _translated.containsKey(m.id);

    Widget action(BuildContext sheet, IconData icon, String label, VoidCallback run) =>
        ListTile(
          leading: Icon(icon),
          title: Text(label),
          onTap: () {
            Navigator.pop(sheet);
            run();
          },
        );

    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            action(sheet, Icons.translate, showing ? l.showOriginal : l.translateMessage,
                () => _toggleTranslation(m)),
            action(sheet, Icons.copy, l.copyText, () {
              Clipboard.setData(ClipboardData(text: _translated[m.id] ?? m.text));
              scope.feedback.toast(l.copiedToast);
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
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
                  style: TextStyle(color: c.onSurfaceVariant),
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
                          return _Bubble(
                            message: m,
                            mine: m.senderId == myId,
                            text: _translated[m.id] ?? m.text,
                            onLongPress: () => _showMessageActions(m),
                          );
                        },
                      ),
              ),
              const Divider(height: 1),
              if (channel.readOnly)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16 + helpButtonClearance),
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
  const _Bubble({
    required this.message,
    required this.mine,
    required this.text,
    required this.onLongPress,
  });

  final MeshMessage message;
  final bool mine;

  /// The message, or its translation while one is showing.
  final String text;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final meta = text.bodyMedium?.copyWith(color: colors.onSurfaceVariant);

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: BoxDecoration(
          color: mine ? colors.primaryContainer : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine)
              Text(message.senderName, style: text.titleSmall?.copyWith(color: colors.primary)),
            Text(this.text, style: text.bodyLarge),
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
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8 + helpButtonClearance),
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
