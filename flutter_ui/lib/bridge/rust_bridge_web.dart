import 'dart:js_interop';

@JS('omnispexWasmReadyPromise')
external JSPromise<JSBoolean>? get _wasmReadyPromise;

@JS('omnispexRustCall')
external JSString _omnispexRustCall(JSString op, JSString payload);

bool _webReady = false;

bool get isPlatformRustBridgeReady => _webReady;

Future<void> initPlatformRustBridge() async {
  final promise = _wasmReadyPromise;
  if (promise != null) {
    await promise.toDart;
    _webReady = true;
  }
}

String invokePlatformRustRpc(String op, String payload) {
  final res = _omnispexRustCall(op.toJS, payload.toJS);
  return res.toDart;
}
