import 'package:resilience/packages/pack_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolvePackSource', () {
    test('prefers the node when it is reachable on the LAN', () async {
      final src = await resolvePackSource(
        nodeBaseUrl: 'http://192.168.1.50:8080',
        cloudBaseUrl: 'https://cloud.example',
        reachable: (url) async => url.startsWith('http://192.168'),
      );
      expect(src, PackSource.node);
      expect(src.label, 'Node');
    });

    test('falls back to the cloud when the node is unreachable', () async {
      final src = await resolvePackSource(
        nodeBaseUrl: 'http://192.168.1.50:8080',
        cloudBaseUrl: 'https://cloud.example',
        reachable: (_) async => false,
      );
      expect(src, PackSource.cloud);
      expect(src.label, 'Cloud');
    });

    test('uses the cloud when no node is saved', () async {
      final src = await resolvePackSource(
        nodeBaseUrl: null,
        cloudBaseUrl: 'https://cloud.example',
        reachable: (_) async => true,
      );
      expect(src, PackSource.cloud);
    });

    test('none when neither a reachable node nor a cloud is configured',
        () async {
      final src = await resolvePackSource(
        nodeBaseUrl: 'http://192.168.1.50:8080',
        cloudBaseUrl: '',
        reachable: (_) async => false,
      );
      expect(src, PackSource.none);
      expect(src.label, '');
    });
  });
}
