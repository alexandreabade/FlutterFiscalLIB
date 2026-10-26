import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';
import 'package:flutter_fiscal_lib_flutter_example/main.dart';
import 'package:flutter_fiscal_lib_flutter_example/secure_secret_store.dart';
import 'package:pointycastle/pointycastle.dart';

AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> _keyPair() {
  final random = SecureRandom('Fortuna')
    ..seed(
      KeyParameter(Uint8List.fromList(List<int>.generate(32, (i) => i + 11))),
    );
  final generator = KeyGenerator('RSA')
    ..init(
      ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.from(65537), 1024, 12),
        random,
      ),
    );
  final pair = generator.generateKeyPair();
  return AsymmetricKeyPair(
    pair.publicKey as RSAPublicKey,
    pair.privateKey as RSAPrivateKey,
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('gera e persiste NFC-e offline no dispositivo', (tester) async {
    await tester.pumpWidget(const FiscalExampleApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final button = find.text('Gerar e persistir NFC-e offline');
    expect(button, findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(
      find.textContaining('Documentos pendentes no SQLite:'),
      findsOneWidget,
    );
    expect(find.textContaining('<NFe'), findsOneWidget);

    await tester.tap(find.text('Preparar PDF DANFE'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.textContaining('PDF DANFE preparado'), findsOneWidget);
  });

  testWidgets('entrega ESC/POS ao adaptador Bluetooth no runtime Flutter', (
    tester,
  ) async {
    Uint8List? received;
    final adapter = BluetoothFiscalOutputAdapter((bytes, _) {
      received = bytes;
    });
    final job = FiscalOutputJob(
      bytes: Uint8List.fromList([0x1b, 0x40, 0x0a]),
      format: FiscalOutputFormat.escPos,
      fileName: 'cupom.bin',
    );

    await adapter.send(job);
    expect(received, [0x1b, 0x40, 0x0a]);
    expect(job.content, [0x1b, 0x40, 0x0a]);
  });

  testWidgets('persiste segredo no cofre nativo no runtime Flutter', (
    tester,
  ) async {
    final store = const PlatformFiscalSecretStore();
    const key = 'integration-secret';
    final value = Uint8List.fromList([0x01, 0x02, 0x03, 0xff]);

    await store.write(key, value);
    expect(await store.read(key), value);
    await store.delete(key);
    expect(await store.read(key), isNull);
  });

  testWidgets('monta envelope XMLDSig no runtime Flutter', (tester) async {
    final pair = _keyPair();
    final service = XmlSignatureService(
      RsaSha1SignatureProvider(pair.privateKey),
    );
    final signed = await service.sign(
      '<NFe><infNFe Id="NFe123" versao="4.00"><ide/></infNFe></NFe>',
    );
    expect(signed, contains('<Signature'));
    expect(signed, contains('<DigestValue>'));
    expect(signed, contains('<SignatureValue>'));
    expect(
      service.verifySignature(signed, RsaSha1SignatureVerifier(pair.publicKey)),
      isTrue,
    );
  });
}
