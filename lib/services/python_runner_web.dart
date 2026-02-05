import 'dart:async';
import 'dart:js_interop';

@JS('runPythonCode')
external JSPromise<JSString> _runPythonCode(String code, String csvManifestJson);

class PythonRunner {
  static Future<String> run(String code, {String? csvManifest}) async {
    final completer = Completer<String>();
    try {
      final jsResult = await _runPythonCode(code, csvManifest ?? '').toDart;
      final result = jsResult.toDart;
      if (!completer.isCompleted) {
        completer.complete(result);
      }
    } catch (error) {
      if (!completer.isCompleted) {
        completer.complete(error.toString());
      }
    }
    return completer.future;
  }
}
