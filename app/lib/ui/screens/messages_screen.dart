import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/providers.dart';
import '../../identity/identity_card.dart';
import '../../l10n/strings.dart';
import '../../messaging/message_flow.dart';
import '../../messaging/message_payload.dart';
import '../../messaging/messaging_providers.dart';
import '../../messaging/messaging_service.dart';
import '../../messaging/photo_prep.dart';
import '../../messaging/recorded_bytes.dart';
import '../../messaging/voice_note.dart';
import '../components/toast.dart';
import '../components/translate_panel.dart';

/// Messages: Direct / Community / Mission (swipeable tabs).
///
/// The Direct tab is now wired end to end over the FEAT-002 sync client and the
/// durable Signal store: it lists contacts that have at least one message
/// (newest first), opens a real conversation view with delivery states, and the
/// composer sends encrypted text, photos and voice notes. Community and Mission
/// remain honest about their unwired state.
class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  @override
  void initState() {
    super.initState();
    // Native reads recorded audio from a file; web fetches the blob URL.
    VoiceRecorder.bytesReader = readRecordedBytes;
  }

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
            const _DirectTab(),
            _notConnected(context, l, 'community_not_wired'),
            _notConnected(context, l, 'mission_not_wired'),
          ],
        ),
      ),
    );
  }

  /// Honest empty state for the tabs that are not wired yet.
  Widget _notConnected(BuildContext context, L10n l, String hintKey) {
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
            Text(l.t(hintKey),
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Roboto', fontSize: 16, color: outline)),
          ],
        ),
      ),
    );
  }
}

/// The Direct tab: a list of conversations (contacts with >=1 message).
class _DirectTab extends ConsumerWidget {
  const _DirectTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    ref.watch(messagesRevisionProvider); // reload after sends/syncs
    final svcAsync = ref.watch(messagingServiceProvider);
    final contactsAsync = ref.watch(contactsProvider);

    return svcAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _empty(context, l, Icons.error_outline_rounded,
          l.t('msg_not_connected'), l.t('msg_not_connected_hint')),
      data: (svc) => contactsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _empty(context, l, Icons.people_outline,
            l.t('no_contacts'), l.t('no_contacts_hint')),
        data: (contacts) {
          if (contacts.isEmpty) {
            return _empty(context, l, Icons.people_outline,
                l.t('no_contacts'), l.t('no_contacts_hint'));
          }
          return FutureBuilder<List<_ChatEntry>>(
            future: _buildChatList(svc, contacts),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final chats = snap.data!;
              final withMessages =
                  chats.where((c) => c.lastMessage != null).toList()
                    ..sort((a, b) => b.lastLamport.compareTo(a.lastLamport));
              // Contacts with no messages yet are still tappable to start one.
              final rest = chats.where((c) => c.lastMessage == null).toList();
              final ordered = [...withMessages, ...rest];
              return ListView.separated(
                itemCount: ordered.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) => _chatTile(context, ref, ordered[i]),
              );
            },
          );
        },
      ),
    );
  }

  Future<List<_ChatEntry>> _buildChatList(
      MessagingService svc, List<IdentityCard> contacts) async {
    final out = <_ChatEntry>[];
    for (final c in contacts) {
      final msgs = await svc.conversation(c.signingPublicKey);
      out.add(_ChatEntry(
        contact: c,
        lastMessage: msgs.isEmpty ? null : msgs.last,
        lastLamport: msgs.isEmpty ? -1 : msgs.last.lamport,
      ));
    }
    return out;
  }

  Widget _chatTile(BuildContext context, WidgetRef ref, _ChatEntry e) {
    final l = L10n.of(context);
    final preview = e.lastMessage == null
        ? l.t('no_messages_yet')
        : _previewOf(e.lastMessage!, l);
    return ListTile(
      leading: CircleAvatar(child: Text(_initial(e.contact.displayName))),
      title: Text(e.contact.displayName,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      subtitle: Text(preview,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16)),
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ConversationScreen(contact: e.contact),
      )),
    );
  }

  static String _previewOf(DirectMessage m, L10n l) {
    if (m.payload.attachments.isNotEmpty) {
      final a = m.payload.attachments.first;
      if (a.isImage) return '📷 ${l.t('photo')}';
      if (a.isAudio) return '🎤 ${l.t('voice_note')}';
    }
    return m.payload.text.isEmpty ? l.t('no_messages_yet') : m.payload.text;
  }

  static String _initial(String name) =>
      name.isEmpty ? '?' : name.characters.first.toUpperCase();

  Widget _empty(
      BuildContext context, L10n l, IconData icon, String title, String hint) {
    final outline = Theme.of(context).colorScheme.outline;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: outline),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: outline)),
            const SizedBox(height: 6),
            Text(hint,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: outline)),
          ],
        ),
      ),
    );
  }
}

class _ChatEntry {
  _ChatEntry(
      {required this.contact, required this.lastMessage, required this.lastLamport});
  final IdentityCard contact;
  final DirectMessage? lastMessage;
  final int lastLamport;
}

/// A 1:1 conversation with [contact]: message history with delivery states and
/// a composer for text, photos and voice notes.
class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({required this.contact, super.key});
  final IdentityCard contact;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _text = TextEditingController();
  final _picker = ImagePicker();
  final _recorder = VoiceRecorder();
  final _player = VoicePlayer();
  bool _recording = false;
  bool _sending = false;
  List<DirectMessage> _messages = const [];

  @override
  void dispose() {
    _text.dispose();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final svcAsync = ref.watch(messagingServiceProvider);
    ref.watch(messagesRevisionProvider);

    return Scaffold(
      appBar: AppBar(title: Text(widget.contact.displayName)),
      body: svcAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l.t('msg_not_connected'))),
        data: (svc) => Column(
          children: [
            Expanded(
              child: FutureBuilder<List<DirectMessage>>(
                future: svc.conversation(widget.contact.signingPublicKey),
                builder: (context, snap) {
                  if (snap.hasData) _messages = snap.data!;
                  if (_messages.isEmpty) {
                    return Center(
                      child: Text(l.t('no_messages_yet'),
                          style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.outline)),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) =>
                        _bubble(context, ref, svc, l, _messages[i]),
                  );
                },
              ),
            ),
            _composer(context, l, svc),
          ],
        ),
      ),
    );
  }

  Widget _bubble(BuildContext context, WidgetRef ref, MessagingService svc,
      L10n l, DirectMessage m) {
    final align = m.fromMe ? Alignment.centerRight : Alignment.centerLeft;
    final color = m.fromMe
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final att = m.payload.attachments.isEmpty ? null : m.payload.attachments.first;

    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (att != null && att.isImage)
              _photoBubble(svc, l, att),
            if (att != null && att.isAudio)
              _audioBubble(svc, l, att),
            if (m.payload.text.isNotEmpty)
              Text(m.payload.text, style: const TextStyle(fontSize: 16)),
            // Translate incoming messages (original stays visible). We offer it
            // only on messages from others — translating one's own text adds no
            // value.
            if (!m.fromMe && m.payload.text.isNotEmpty)
              TranslatePanel(text: m.payload.text, compact: true),
            if (m.fromMe)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_deliveryLabel(l, m.deliveryState),
                    style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.outline)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _photoBubble(MessagingService svc, L10n l, Attachment att) {
    if (att.thumbnail != null && att.thumbnail!.isNotEmpty) {
      return GestureDetector(
        onTap: () => _openPhoto(svc, att),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(att.thumbnail!, width: 160, fit: BoxFit.cover),
          ),
        ),
      );
    }
    return TextButton.icon(
      onPressed: () => _openPhoto(svc, att),
      icon: const Icon(Icons.photo),
      label: Text(l.t('photo'), style: const TextStyle(fontSize: 16)),
    );
  }

  Widget _audioBubble(MessagingService svc, L10n l, Attachment att) {
    final secs = (att.durationMs / 1000).round();
    return TextButton.icon(
      onPressed: () async {
        try {
          final bytes = await svc.fetchAttachment(att);
          await _player.playBytes(bytes, mime: att.mime);
        } catch (_) {
          if (mounted) Toast.show(context, l.t('attachment_failed'));
        }
      },
      icon: const Icon(Icons.play_arrow),
      label: Text('${l.t('voice_note')} ${secs}s',
          style: const TextStyle(fontSize: 16)),
    );
  }

  Future<void> _openPhoto(MessagingService svc, Attachment att) async {
    try {
      final bytes = await svc.fetchAttachment(att);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          child: InteractiveViewer(child: Image.memory(bytes)),
        ),
      );
    } catch (_) {
      if (mounted) Toast.show(context, L10n.of(context).t('attachment_failed'));
    }
  }

  Widget _composer(BuildContext context, L10n l, MessagingService svc) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Row(
          children: [
            IconButton(
              tooltip: l.t('attach_photo'),
              icon: const Icon(Icons.photo_camera_outlined),
              onPressed: _sending ? null : () => _sendPhoto(svc, l),
            ),
            GestureDetector(
              onLongPressStart: (_) => _startRecording(svc, l),
              onLongPressEnd: (_) => _stopRecording(svc, l),
              child: IconButton(
                tooltip: l.t('hold_to_record'),
                icon: Icon(_recording ? Icons.mic : Icons.mic_none_outlined,
                    color: _recording
                        ? Theme.of(context).colorScheme.error
                        : null),
                onPressed: () {
                  Toast.show(context, l.t('hold_to_record'));
                },
              ),
            ),
            Expanded(
              child: TextField(
                controller: _text,
                minLines: 1,
                maxLines: 4,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  hintText: l.t('type_a_message'),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton.filled(
              tooltip: l.t('send'),
              icon: const Icon(Icons.send),
              onPressed: _sending ? null : () => _sendText(svc, l),
            ),
          ],
        ),
      ),
    );
  }

  String _deliveryLabel(L10n l, DeliveryState s) {
    switch (s) {
      case DeliveryState.queued:
        return l.t('queued');
      case DeliveryState.propagating:
        return l.t('propagating');
      case DeliveryState.delivered:
        return l.t('delivered');
      case DeliveryState.read:
        return l.t('read');
    }
  }

  Future<void> _sendText(MessagingService svc, L10n l) async {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final id = await svc.send(
        widget.contact.signingPublicKey,
        MessagePayload(kind: 'text', text: text),
      );
      if (id == null) {
        if (mounted) Toast.show(context, l.t('cannot_start_chat'));
        return;
      }
      _text.clear();
      _afterSend();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendPhoto(MessagingService svc, L10n l) async {
    XFile? picked;
    try {
      picked = await _picker.pickImage(
          source: ImageSource.gallery, requestFullMetadata: false);
    } catch (_) {
      if (mounted) Toast.show(context, l.t('camera_unavailable'));
      return;
    }
    if (picked == null) return;
    setState(() => _sending = true);
    try {
      final raw = await picked.readAsBytes();
      final prepared = preparePhoto(Uint8List.fromList(raw));
      if (prepared == null) {
        if (mounted) Toast.show(context, l.t('attachment_failed'));
        return;
      }
      final att = await svc.uploadAttachment(
        bytes: prepared.jpeg,
        mime: 'image/jpeg',
        thumbnail: prepared.thumbnail,
        width: prepared.width,
        height: prepared.height,
      );
      final id = await svc.send(widget.contact.signingPublicKey,
          MessagePayload(kind: 'photo', text: _text.text.trim(), attachments: [att]));
      if (id == null) {
        if (mounted) Toast.show(context, l.t('cannot_start_chat'));
        return;
      }
      _text.clear();
      _afterSend();
    } catch (_) {
      if (mounted) Toast.show(context, l.t('attachment_failed'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _startRecording(MessagingService svc, L10n l) async {
    final ok = await _recorder.start();
    if (!ok) {
      if (mounted) Toast.show(context, l.t('mic_unavailable'));
      return;
    }
    if (mounted) setState(() => _recording = true);
  }

  Future<void> _stopRecording(MessagingService svc, L10n l) async {
    if (!_recording) return;
    setState(() {
      _recording = false;
      _sending = true;
    });
    try {
      final clip = await _recorder.stop();
      if (clip == null || clip.bytes.isEmpty) {
        if (mounted) Toast.show(context, l.t('mic_unavailable'));
        return;
      }
      final att = await svc.uploadAttachment(
        bytes: clip.bytes,
        mime: clip.mime,
        durationMs: clip.duration.inMilliseconds,
      );
      final id = await svc.send(widget.contact.signingPublicKey,
          MessagePayload(kind: 'audio', attachments: [att]));
      if (id == null) {
        if (mounted) Toast.show(context, l.t('cannot_start_chat'));
        return;
      }
      _afterSend();
    } catch (_) {
      if (mounted) Toast.show(context, l.t('attachment_failed'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _afterSend() {
    // Trigger a sync (SyncLifecycleObserver listens to worldRevision) and
    // reload the conversation.
    bumpWorld(ref);
    ref.read(messagesRevisionProvider.notifier).state++;
  }
}
