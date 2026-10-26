bool get isPlatformRustBridgeReady => false;

Future<void> initPlatformRustBridge() async {
  throw UnsupportedError('Platform not supported');
}

String invokePlatformRustRpc(String op, String payload) {
  throw UnsupportedError('Platform not supported');
}
