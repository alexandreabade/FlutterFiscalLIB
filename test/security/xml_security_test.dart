import 'dart:convert';
import 'dart:io';

import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';
import 'package:pointycastle/pointycastle.dart';
import 'package:test/test.dart';

class _NoopSigner implements XmlSignatureProvider {
  @override
  Future<String> sign(List<int> signedInfo) async => 'signature';
}

void main() {
  test('cliente SEFAZ não aceita endpoint HTTP', () {
    expect(
      () => SefazClient(endpoint: Uri.parse('http://localhost')),
      throwsA(isA<FiscalValidationException>()),
    );
  });

  test('identidade PFX válida pode ser usada para assinatura', () {
    final encoded = File(
      'test/fixtures/synthetic_a1.p12.b64',
    ).readAsStringSync().replaceAll(RegExp(r'\s'), '');
    final identity = PfxIdentity.fromPfx(
      bytes: base64Decode(encoded),
      password: 'test-password',
    );

    expect(() => XmlSignatureService.fromPfx(identity), returnsNormally);
  });

  test('assinador rejeita XML malformado', () async {
    expect(
      () => XmlSignatureService(_NoopSigner()).sign('<NFe>'),
      throwsA(isA<Exception>()),
    );
  });

  test('assinador rejeita documento sem Id', () async {
    expect(
      () => XmlSignatureService(_NoopSigner()).sign('<NFe><infNFe/></NFe>'),
      throwsA(isA<FiscalValidationException>()),
    );
  });

  test('assinador rejeita segunda assinatura', () async {
    const xml = '<NFe><infNFe Id="NFe1"/><Signature/></NFe>';
    expect(
      () => XmlSignatureService(_NoopSigner()).sign(xml),
      throwsA(isA<FiscalValidationException>()),
    );
  });

  test('provedor não recebe material além dos bytes SignedInfo', () async {
    final received = <int>[];
    final provider = _CapturingSigner(received);
    await XmlSignatureService(provider).sign('<NFe><infNFe Id="NFe1"/></NFe>');
    expect(received, isNotEmpty);
    expect(received, isNot(contains('private')));
  });

  test('detecta alteração no infNFe pelo digest', () async {
    const source =
        '<NFe><infNFe Id="NFe1"><xNome>Original</xNome></infNFe></NFe>';
    final service = XmlSignatureService(_CapturingSigner(<int>[]));
    final signed = await service.sign(source);

    expect(service.verifyDigest(signed), isTrue);
    expect(
      service.verifyDigest(signed.replaceFirst('Original', 'Alterado')),
      isFalse,
    );
  });

  test('rejeita algoritmo XMLDSig desconhecido no digest', () async {
    const source =
        '<NFe><infNFe Id="NFe1"><xNome>Original</xNome></infNFe></NFe>';
    final service = XmlSignatureService(_CapturingSigner(<int>[]));
    final signed = await service.sign(source);
    final unknown = signed.replaceFirst(
      'http://www.w3.org/2001/04/xmlenc#sha256',
      'urn:algoritmo-desconhecido',
    );

    expect(service.verifyDigest(unknown), isFalse);
  });

  test('rejeita duas assinaturas diretas para evitar wrapping', () async {
    final service = XmlSignatureService(_CapturingSigner(<int>[]));
    final signed = await service.sign('<NFe><infNFe Id="NFe1"/></NFe>');
    expect(
      service.verifySignature(
        signed.replaceFirst('</NFe>', '<Signature/></NFe>'),
        RsaSha256SignatureVerifier(RSAPublicKey(BigInt.zero, BigInt.one)),
      ),
      isFalse,
    );
  });

  test(
    'verifyDigest rejeita referência URI que não aponta para infNFe',
    () async {
      final service = XmlSignatureService(_CapturingSigner(<int>[]));
      final signed = await service.sign('<NFe><infNFe Id="NFe1"/></NFe>');
      final wrappedReference = signed.replaceFirst(
        'URI="#NFe1"',
        'URI="#other"',
      );

      expect(service.verifyDigest(wrappedReference), isFalse);
    },
  );
}

class _CapturingSigner implements XmlSignatureProvider {
  _CapturingSigner(this.received);

  final List<int> received;

  @override
  Future<String> sign(List<int> signedInfo) async {
    received
      ..clear()
      ..addAll(signedInfo);
    return base64Signature;
  }

  static const base64Signature = 'c2lnbmF0dXJl';
}
