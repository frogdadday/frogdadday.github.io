import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void mockStorage() {
  // Existing workflows exercise the already-approved saving path.
  String? raw = '{"localSavingAllowed":true}';
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('cosmic_spinner/storage'), (
        call,
      ) async {
        if (call.method == 'read') return raw;
        if (call.method == 'write') {
          raw = call.arguments as String;
          return null;
        }
        throw MissingPluginException();
      });
}
