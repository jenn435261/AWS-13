/// Where the app finds the Resilience Node on the local network: the Node's
/// sync API, offline map packages and readiness bundles all live under it.
/// Set when building: `--dart-define=NODE_URL=http://192.168.4.1:8090`.
/// Port 8090 matches the Node's default `HTTP_ADDR`.
const nodeBaseUrl =
    String.fromEnvironment('NODE_URL', defaultValue: 'http://192.168.4.1:8090');
