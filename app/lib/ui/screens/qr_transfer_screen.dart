import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/providers.dart';
import '../../l10n/strings.dart';
import '../../transport/qr_fountain.dart';
import '../../transport/qr_transfer.dart';
import '../components/toast.dart';

/// "Transfer by QR" (spec §6.1): move signed events phone-to-phone with no
/// radios at all, using an animated fountain-coded QR stream.
///
/// The sender tab animates coded frames via `qr_flutter` at ~10 fps; the
/// receiver tab scans continuously via `mobile_scanner`, shows "N/M frames"
/// progress, verifies the whole-payload SHA-256, and ingests each event through
/// `EventStore.apply` (which re-checks every signature + content hash).
///
/// Realistic throughput is a few KB/s — enough for identity cards and small
/// signed-event batches in seconds, NOT for map packs or media.
class QrTransferScreen extends ConsumerStatefulWidget {
  const QrTransferScreen({super.key});

  @override
  ConsumerState<QrTransferScreen> createState() => _QrTransferScreenState();
}

class _QrTransferScreenState extends ConsumerState<QrTransferScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.t('transfer_by_qr')),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: l.t('qr_send'), icon: const Icon(Icons.qr_code_2_rounded)),
            Tab(
                text: l.t('qr_receive'),
                icon: const Icon(Icons.qr_code_scanner_rounded)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _SenderTab(),
          _ReceiverTab(),
        ],
      ),
    );
  }
}

/// Animates coded frames of the local event store as QR codes.
class _SenderTab extends ConsumerStatefulWidget {
  const _SenderTab();

  @override
  ConsumerState<_SenderTab> createState() => _SenderTabState();
}

class _SenderTabState extends ConsumerState<_SenderTab> {
  /// ~10 fps — within the 8-15 fps target; slow enough for budget cameras.
  static const Duration _frameInterval = Duration(milliseconds: 100);

  QrFountainEncoder? _encoder;
  Timer? _timer;
  String _current = '';
  int _frameCount = 0;
  int _eventCount = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _prepare() async {
    try {
      final store = ref.read(eventStoreProvider);
      final events = await store.dao.allEvents();
      if (!mounted) return;
      if (events.isEmpty) {
        setState(() => _error = 'empty');
        return;
      }
      final payload = QrTransfer.encodePayload(events);
      final enc = QrFountainEncoder(payload);
      setState(() {
        _encoder = enc;
        _eventCount = events.length;
      });
      _timer = Timer.periodic(_frameInterval, (_) => _tick());
    } catch (_) {
      if (mounted) setState(() => _error = 'empty');
    }
  }

  void _tick() {
    final enc = _encoder;
    if (enc == null || !mounted) return;
    final frame = enc.next();
    setState(() {
      _current = frame.toQrString();
      _frameCount++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l.t('qr_nothing_to_send'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Roboto', fontSize: 16)),
        ),
      );
    }
    final enc = _encoder;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(l.t('qr_send_hint'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Roboto', fontSize: 16)),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: _current.isEmpty
                    ? const SizedBox(
                        width: 280,
                        height: 280,
                        child: Center(child: CircularProgressIndicator()))
                    : QrImageView(
                        data: _current,
                        size: 280,
                        // Error-correction level M balances density vs. camera
                        // read reliability; the fountain handles the rest.
                        errorCorrectionLevel: QrErrorCorrectLevel.M,
                        gapless: true,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${l.t('qr_events')}: $_eventCount · '
            '${enc == null ? 0 : enc.numBlocks} ${l.t('qr_blocks')} · '
            '$_frameCount ${l.t('qr_frames_sent')}',
            style: const TextStyle(fontFamily: 'Roboto', fontSize: 16),
          ),
        ],
      ),
    );
  }
}

/// Scans the animated stream, shows progress, verifies + ingests on completion.
class _ReceiverTab extends ConsumerStatefulWidget {
  const _ReceiverTab();

  @override
  ConsumerState<_ReceiverTab> createState() => _ReceiverTabState();
}

class _ReceiverTabState extends ConsumerState<_ReceiverTab> {
  final QrFountainDecoder _decoder = QrFountainDecoder();
  final MobileScannerController _controller = MobileScannerController();
  bool _done = false;
  int _recovered = 0;
  int? _total;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    bool advanced = false;
    for (final b in capture.barcodes) {
      final v = b.rawValue;
      if (v == null || v.isEmpty) continue;
      if (_decoder.addQrString(v)) advanced = true;
    }
    if (advanced && mounted) {
      setState(() {
        _recovered = _decoder.recovered;
        _total = _decoder.numBlocks;
      });
    }
    if (_decoder.isComplete && !_done) {
      _done = true;
      unawaited(_finish(_decoder.result!));
    }
  }

  Future<void> _finish(Uint8List payload) async {
    final l = L10n.of(context);
    await _controller.stop();
    final store = ref.read(eventStoreProvider);
    final result = await QrTransfer.ingest(store, payload);
    if (!mounted) return;
    final msg = l
        .t('qr_received_summary')
        .replaceFirst('{applied}', '${result.applied}')
        .replaceFirst('{invalid}', '${result.invalid}');
    Toast.show(context, msg);
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final progress = _total == null ? '0/?' : '$_recovered/$_total';
    return Stack(
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
          errorBuilder: (context, error, child) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.no_photography_outlined, size: 48),
                  const SizedBox(height: 12),
                  Text(l.t('camera_unavailable'),
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(fontFamily: 'Roboto', fontSize: 16)),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 24,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${l.t('qr_progress')}: $progress ${l.t('qr_frames')}',
                style: const TextStyle(
                    fontFamily: 'Roboto', fontSize: 16, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
