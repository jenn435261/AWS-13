import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../l10n/strings.dart';

/// Camera QR scanner. Pops with the scanned text, or with [manualEntry] when
/// the camera is unavailable (denied permission, no camera, insecure origin)
/// and the user chooses to type the code instead.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  /// Sentinel result meaning "open the manual entry dialog instead".
  static const String manualEntry = '\u0000manual';

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.t('scan_qr'))),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_done) return;
              for (final b in capture.barcodes) {
                final v = b.rawValue;
                if (v != null && v.isNotEmpty) {
                  _done = true;
                  Navigator.of(context).pop(v);
                  return;
                }
              }
            },
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
                        style: const TextStyle(
                            fontFamily: 'Roboto', fontSize: 16)),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.keyboard_rounded),
                      label: Text(l.t('manual_entry')),
                      onPressed: () =>
                          Navigator.of(context).pop(QrScanScreen.manualEntry),
                    ),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(l.t('scan_hint'),
                    style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 16,
                        color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
