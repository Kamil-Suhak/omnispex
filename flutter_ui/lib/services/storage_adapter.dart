export 'storage_adapter_stub.dart'
    if (dart.library.io) 'storage_adapter_native.dart'
    if (dart.library.js_interop) 'storage_adapter_web.dart';

