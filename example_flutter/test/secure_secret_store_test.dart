import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_fiscal_lib_flutter_example/secure_secret_store.dart';

void main() {
  test('round-trip do store de segredo via MethodChannel', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('test/flutter_fiscal_lib/secret');
    final values = <String, String>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final key = (call.arguments as Map)['key'] as String;
          switch (call.method) {
            case 'read':
              return values[key];
            case 'write':
              values[key] = (call.arguments as Map)['value'] as String;
              return null;
            case 'delete':
              values.remove(key);
              return null;
            default:
              throw MissingPluginException();
          }
        });
    final store = PlatformFiscalSecretStore(channel: channel);
    final secret = Uint8List.fromList([1, 2, 3, 255]);

    await store.write('a1', secret);
    expect(await store.read('a1'), secret);
    await store.delete('a1');
    expect(await store.read('a1'), isNull);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
}
