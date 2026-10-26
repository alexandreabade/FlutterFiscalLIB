import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_fiscal_lib_flutter_example/xsd_platform_validator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mapeia o resultado do canal XSD Android', () async {
    const channel = MethodChannel('test/flutter_fiscal_lib/xsd/android');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'validate');
          expect(call.arguments, {'schema': 'schema', 'xml': '<NFe/>'});
          return {'exitCode': 0, 'stdout': 'valid', 'stderr': ''};
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final result = await const AndroidXsdContentValidator(
      channel: channel,
    ).call(schema: 'schema', xml: '<NFe/>');

    expect(result.isValid, isTrue);
    expect(result.stdout, 'valid');
  });

  test('mapeia uma rejeição do canal XSD iOS', () async {
    const channel = MethodChannel('test/flutter_fiscal_lib/xsd/ios');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          return {'exitCode': 1, 'stdout': '', 'stderr': 'elemento inválido'};
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final result = await const IosXsdContentValidator(
      channel: channel,
    ).call(schema: 'schema', xml: '<NFe/>');

    expect(result.isValid, isFalse);
    expect(result.stderr, 'elemento inválido');
  });

  test('encaminha recursos de include/import no Android e iOS', () async {
    const androidChannel = MethodChannel(
      'test/flutter_fiscal_lib/xsd/android-bundle',
    );
    const iosChannel = MethodChannel('test/flutter_fiscal_lib/xsd/ios-bundle');
    Future<Object?> handler(MethodCall call) async {
      expect(call.method, 'validateBundle');
      expect(call.arguments, {
        'schema': 'schema',
        'xml': '<NFe/>',
        'resources': {'included.xsd': 'included'},
      });
      return {'exitCode': 0, 'stdout': 'valid', 'stderr': ''};
    }

    for (final channel in [androidChannel, iosChannel]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, handler);
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
    }

    final androidResult =
        await const AndroidXsdContentValidator(
          channel: androidChannel,
        ).callBundle(
          schema: 'schema',
          xml: '<NFe/>',
          resources: const {'included.xsd': 'included'},
        );
    final iosResult = await const IosXsdContentValidator(channel: iosChannel)
        .callBundle(
          schema: 'schema',
          xml: '<NFe/>',
          resources: const {'included.xsd': 'included'},
        );

    expect(androidResult.isValid, isTrue);
    expect(iosResult.isValid, isTrue);
  });
}
