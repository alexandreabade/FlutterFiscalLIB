import 'dart:typed_data';

import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';
import 'package:pointycastle/pointycastle.dart';
import 'package:test/test.dart';

AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> _keyPair() {
  final random = SecureRandom('Fortuna')
    ..seed(
      KeyParameter(Uint8List.fromList(List<int>.generate(32, (i) => i + 2))),
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
  test('assina e verifica bytes com RSA SHA-256', () async {
    final random = SecureRandom('Fortuna')
      ..seed(
        KeyParameter(Uint8List.fromList(List<int>.generate(32, (i) => i + 1))),
      );
    final generator = KeyGenerator('RSA')
      ..init(
        ParametersWithRandom(
          RSAKeyGeneratorParameters(BigInt.from(65537), 1024, 12),
          random,
        ),
      );
    final pair = generator.generateKeyPair();
    final privateKey = pair.privateKey as RSAPrivateKey;
    final publicKey = pair.publicKey as RSAPublicKey;
    final provider = RsaSha256SignatureProvider(privateKey);
    final verifier = RsaSha256SignatureVerifier(publicKey);
    final data = Uint8List.fromList('signed-info'.codeUnits);

    final signature = await provider.sign(data);

    expect(signature, isNotEmpty);
    expect(verifier.verify(data, signature), isTrue);
    expect(
      verifier.verify(Uint8List.fromList('other'.codeUnits), signature),
      isFalse,
    );
  });

  test('rejeita Base64 inválido sem lançar exceção', () {
    final keyPair = _keyPair();
    final publicKey = keyPair.publicKey;
    expect(
      RsaSha256SignatureVerifier(publicKey).verify([1, 2, 3], '%%%'),
      isFalse,
    );
    expect(
      RsaSha1SignatureVerifier(publicKey).verify([1, 2, 3], '%%%'),
      isFalse,
    );
  });

  test('anexa assinatura enveloped ao XML', () async {
    final random = SecureRandom('Fortuna')
      ..seed(
        KeyParameter(Uint8List.fromList(List<int>.generate(32, (i) => i + 3))),
      );
    final generator = KeyGenerator('RSA')
      ..init(
        ParametersWithRandom(
          RSAKeyGeneratorParameters(BigInt.from(65537), 1024, 12),
          random,
        ),
      );
    final pair = generator.generateKeyPair();
    final service = XmlSignatureService(
      RsaSha256SignatureProvider(pair.privateKey as RSAPrivateKey),
    );

    final signed = await service.sign(
      '<NFe><infNFe Id="NFe123" versao="4.00"><ide/></infNFe></NFe>',
    );

    expect(signed, contains('<Signature'));
    expect(signed, contains('<DigestValue>'));
    expect(signed, contains('<SignatureValue>'));
  });
}
