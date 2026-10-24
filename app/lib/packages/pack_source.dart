import 'package:http/http.dart' as http;

/// Where a region pack is fetched from. The app prefers a Resilience node on
/// the local network (fast, works without internet) and falls back to the
/// cloud, always SHOWING which is in use so the UI is honest.
enum PackSource { node, cloud, none }

extension PackSourceLabel on PackSource {
  /// The user-facing label shown on the offline downloads screen.
  String get label => switch (this) {
        PackSource.node => 'Node',
        PackSource.cloud => 'Cloud',
        PackSource.none => '',
      };
}

/// A reachability probe seam so the source resolver is testable without a real
/// network. Returns true when the base URL answers a health check.
typedef Reachable = Future<bool> Function(String baseUrl);

/// Chooses the preferred source: the node when it is reachable on the LAN,
/// otherwise the cloud when a cloud base URL is configured, otherwise none.
/// Pure given the [reachable] probe, so the preference logic is unit-testable.
Future<PackSource> resolvePackSource({
  String? nodeBaseUrl,
  String? cloudBaseUrl,
  required Reachable reachable,
}) async {
  final node = (nodeBaseUrl ?? '').trim();
  if (node.isNotEmpty && await reachable(node)) {
    return PackSource.node;
  }
  final cloud = (cloudBaseUrl ?? '').trim();
  if (cloud.isNotEmpty) {
    return PackSource.cloud;
  }
  return PackSource.none;
}

/// The default reachability probe: a short GET to the node's catalog endpoint.
/// A node answering its catalog is reachable on the LAN.
Future<bool> defaultNodeReachable(String baseUrl) async {
  final base = baseUrl.replaceAll(RegExp(r'/+$'), '');
  try {
    final r = await http
        .get(Uri.parse('$base/node/v1/packages'))
        .timeout(const Duration(seconds: 3));
    return r.statusCode == 200;
  } catch (_) {
    return false;
  }
}
