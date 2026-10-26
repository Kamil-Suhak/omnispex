import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

typedef _CallJsonNative = Pointer<Utf8> Function(
  Pointer<Utf8> op,
  Pointer<Utf8> payload,
);
typedef _CallJsonDart = Pointer<Utf8> Function(
  Pointer<Utf8> op,
  Pointer<Utf8> payload,
);

typedef _FreeStringNative = Void Function(Pointer<Utf8> ptr);
typedef _FreeStringDart = void Function(Pointer<Utf8> ptr);

class _NativeBridgeBindings {
  final _CallJsonDart callJson;
  final _FreeStringDart freeString;

  _NativeBridgeBindings(DynamicLibrary dylib)
      : callJson = dylib
            .lookup<NativeFunction<_CallJsonNative>>('omnispex_call_json')
            .asFunction<_CallJsonDart>(),
        freeString = dylib
            .lookup<NativeFunction<_FreeStringNative>>('omnispex_free_string')
            .asFunction<_FreeStringDart>();
}

_NativeBridgeBindings? _bindings;

bool get isPlatformRustBridgeReady => _bindings != null;

DynamicLibrary _openNativeLibrary() {
  if (Platform.isAndroid || Platform.isLinux) {
    final candidates = <String>[
      'libomnispex_flutter.so',
      '../target/release/libomnispex_flutter.so',
      '../target/debug/libomnispex_flutter.so',
    ];
    for (final path in candidates) {
      try {
        return DynamicLibrary.open(path);
      } catch (_) {}
    }
    return DynamicLibrary.open('libomnispex_flutter.so');
  }

  if (Platform.isWindows) {
    final cwd = Directory.current.path;
    final candidates = <String>[
      'omnispex_flutter.dll',
      '$cwd/omnispex_flutter.dll',
      '$cwd/../target/release/omnispex_flutter.dll',
      '$cwd/../target/debug/omnispex_flutter.dll',
      '$cwd/target/release/omnispex_flutter.dll',
      '$cwd/target/debug/omnispex_flutter.dll',
    ];
    for (final path in candidates) {
      if (path.contains('/') || path.contains('\\')) {
        if (!File(path).existsSync()) continue;
      }
      try {
        return DynamicLibrary.open(path);
      } catch (_) {}
    }
    return DynamicLibrary.open('omnispex_flutter.dll');
  }

  if (Platform.isMacOS || Platform.isIOS) {
    return DynamicLibrary.process();
  }

  throw UnsupportedError('Unsupported native platform: ${Platform.operatingSystem}');
}

Future<void> initPlatformRustBridge() async {
  if (_bindings != null) return;
  final dylib = _openNativeLibrary();
  _bindings = _NativeBridgeBindings(dylib);
}

String invokePlatformRustRpc(String op, String payload) {
  if (_bindings == null) {
    final dylib = _openNativeLibrary();
    _bindings = _NativeBridgeBindings(dylib);
  }
  final b = _bindings!;
  final opPtr = op.toNativeUtf8();
  final payloadPtr = payload.toNativeUtf8();
  Pointer<Utf8> resPtr = nullptr;
  try {
    resPtr = b.callJson(opPtr, payloadPtr);
    if (resPtr == nullptr) {
      return '{"ok":false,"error":"null pointer from omnispex_call_json"}';
    }
    return resPtr.toDartString();
  } finally {
    calloc.free(opPtr);
    calloc.free(payloadPtr);
    if (resPtr != nullptr) {
      b.freeString(resPtr);
    }
  }
}
