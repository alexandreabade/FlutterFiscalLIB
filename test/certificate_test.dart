import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:pointycastle/pointycastle.dart';
import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';
import 'package:test/test.dart';

class _TestSigner implements XmlSignatureProvider {
  @override
  Future<String> sign(List<int> signedInfo) async => 'signature';
}

void main() {
  test('decodifica certificado PEM para DER/Base64', () {
    final payload = base64Encode([1, 2, 3, 4]);
    final certificate = Certificate.fromPem(
      '-----BEGIN CERTIFICATE-----\n$payload\n-----END CERTIFICATE-----',
    );

    expect(certificate.der, [1, 2, 3, 4]);
    expect(certificate.base64, payload);
  });

  test('rejeita PEM que não é certificado', () {
    expect(
      () => Certificate.fromPem(
        '-----BEGIN PRIVATE KEY-----abc-----END PRIVATE KEY-----',
      ),
      throwsA(isA<FiscalValidationException>()),
    );
  });

  test('extrai CNPJ e CPF pelos OIDs ICP-Brasil', () {
    const cnpjOid = [0x06, 0x05, 0x60, 0x4c, 0x01, 0x03, 0x03];
    const cpfOid = [0x06, 0x05, 0x60, 0x4c, 0x01, 0x03, 0x01];
    final certificate = Certificate(
      Uint8List.fromList([
        ...cnpjOid,
        0x0c,
        14,
        ...'04252011000110'.codeUnits,
        ...cpfOid,
        0x0c,
        19,
        ...'0101198001234567890'.codeUnits,
      ]),
    );

    expect(certificate.getCnpj(), '04252011000110');
    expect(certificate.getCpf(), '01234567890');
  });

  test('extrai certificado X.509 de PFX e valida a senha', () {
    final encoded = File(
      'test/fixtures/synthetic_a1.p12.b64',
    ).readAsStringSync().replaceAll(RegExp(r'\s'), '');
    final certificate = Certificate.fromPfx(
      bytes: base64Decode(encoded),
      password: 'test-password',
    );

    expect(certificate.der, isNotEmpty);
    expect(certificate.base64, isNotEmpty);
  });

  test('exporta PFX PKCS#12 e recupera a identidade em round-trip', () async {
    final encoded = File(
      'test/fixtures/synthetic_a1.p12.b64',
    ).readAsStringSync().replaceAll(RegExp(r'\s'), '');
    final original = PfxIdentity.fromPfx(
      bytes: base64Decode(encoded),
      password: 'test-password',
    );
    final exported = Certificate.writePfx(
      certificate: original.certificate,
      privateKeyInfoDer: original.privateKeyInfoDer,
      certificateChain: original.certificateChain.skip(1).toList(),
      password: 'round-trip-password',
      iterations: 2048,
    );
    final restored = PfxIdentity.fromPfx(
      bytes: exported,
      password: 'round-trip-password',
    );

    expect(restored.certificate.der, original.certificate.der);
    expect(restored.privateKeyInfoDer, original.privateKeyInfoDer);
    expect(await restored.sign('round-trip'), isNotEmpty);
    expect(
      () => PfxIdentity.fromPfx(bytes: exported, password: 'wrong-password'),
      throwsA(isA<FiscalValidationException>()),
    );
  });

  test('valida que o certificado e a chave privada do PFX correspondem', () {
    final encoded = File(
      'test/fixtures/synthetic_a1.p12.b64',
    ).readAsStringSync().replaceAll(RegExp(r'\s'), '');
    final identity = PfxIdentity.fromPfx(
      bytes: base64Decode(encoded),
      password: 'test-password',
    );

    final otherEncoded = File(
      'test/fixtures/mismatch_a1.p12.b64',
    ).readAsStringSync().replaceAll(RegExp(r'\s'), '');
    final otherIdentity = PfxIdentity.fromPfx(
      bytes: base64Decode(otherEncoded),
      password: 'mismatch-key',
    );
    final mismatched = Certificate.writePfx(
      certificate: identity.certificate,
      privateKeyInfoDer: otherIdentity.privateKeyInfoDer,
      password: 'mismatch-password',
    );

    expect(
      () =>
          PfxIdentity.fromPfx(bytes: mismatched, password: 'mismatch-password'),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'CERTIFICATE_PRIVATE_KEY_MISMATCH',
        ),
      ),
    );
  });

  test('rejeita PFX com iterações criptográficas fracas', () {
    final encoded = File(
      'test/fixtures/synthetic_a1.p12.b64',
    ).readAsStringSync().replaceAll(RegExp(r'\s'), '');
    final original = PfxIdentity.fromPfx(
      bytes: base64Decode(encoded),
      password: 'test-password',
    );

    expect(
      () => Certificate.writePfx(
        certificate: original.certificate,
        privateKeyInfoDer: original.privateKeyInfoDer,
        password: 'weak-iterations',
        iterations: 1,
      ),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'INVALID_PKCS12_ITERATIONS',
        ),
      ),
    );
  });

  test('mantém o ponto de entrada Certificate.readPfx()', () {
    final encoded = File(
      'test/fixtures/synthetic_a1.p12.b64',
    ).readAsStringSync().replaceAll(RegExp(r'\s'), '');
    final identity = Certificate.readPfx(
      base64Decode(encoded),
      'test-password',
    );

    expect(identity.certificate.der, isNotEmpty);
    expect(identity.getValidFrom(), isA<DateTime>());
    expect(identity.getICP(), isA<String>());
    expect(identity.getCSP(), isA<String>());
  });

  test('lê certificado e identidade PFX diretamente de arquivo', () async {
    final path = 'test/fixtures/synthetic_a1.p12';
    final encoded = File(
      'test/fixtures/synthetic_a1.p12.b64',
    ).readAsStringSync().replaceAll(RegExp(r'\s'), '');
    File(path).writeAsBytesSync(base64Decode(encoded));
    try {
      final certificate = await Certificate.fromPfxFile(
        path: path,
        password: 'test-password',
      );
      final identity = await PfxIdentity.fromPfxFile(
        path: path,
        password: 'test-password',
      );
      expect(certificate.der, isNotEmpty);
      expect(identity.privateKeyInfoDer, isNotEmpty);
    } finally {
      File(path).deleteSync();
    }
  });

  test('lê validade temporal do certificado X.509', () {
    final encoded = File(
      'test/fixtures/synthetic_a1.p12.b64',
    ).readAsStringSync().replaceAll(RegExp(r'\s'), '');
    final certificate = Certificate.fromPfx(
      bytes: base64Decode(encoded),
      password: 'test-password',
    );

    expect(certificate.notBefore, isA<DateTime>());
    expect(certificate.notAfter.isAfter(certificate.notBefore), isTrue);
    expect(
      certificate.isValidAt(certificate.notBefore.add(const Duration(days: 1))),
      isTrue,
    );
    expect(
      certificate.isValidAt(
        certificate.notAfter.add(const Duration(seconds: 1)),
      ),
      isFalse,
    );
    expect(certificate.getValidFrom(), certificate.notBefore);
    expect(certificate.getValidTo(), certificate.notAfter);
    expect(certificate.isExpired(), isFalse);
    expect(certificate.getCompanyName(), 'FlutterFiscalLIB Test');
    expect(certificate.getCnpj(), anyOf(isNull, isA<String>()));
    expect(certificate.getCpf(), anyOf(isNull, isA<String>()));
    expect(certificate.getICP(), isA<String>());
    expect(certificate.getCAurl(), isA<String>());
    expect(certificate.getCSP(), isA<String>());
    expect(certificate.pem, startsWith('-----BEGIN CERTIFICATE-----'));
    expect(certificate.toString(), certificate.pem);
  });

  test('rejeita senha incorreta no PFX', () {
    final encoded = File(
      'test/fixtures/synthetic_a1.p12.b64',
    ).readAsStringSync().replaceAll(RegExp(r'\s'), '');
    expect(
      () => Certificate.fromPfx(
        bytes: base64Decode(encoded),
        password: 'wrong-password',
      ),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'INVALID_PKCS12_PASSWORD',
        ),
      ),
    );
  });

  test('extrai identidade completa PFX sem persistir senha', () {
    final encoded = File(
      'test/fixtures/synthetic_a1.p12.b64',
    ).readAsStringSync().replaceAll(RegExp(r'\s'), '');
    final identity = PfxIdentity.fromPfx(
      bytes: base64Decode(encoded),
      password: 'test-password',
    );

    expect(identity.certificateChain, isNotEmpty);
    expect(identity.certificateChain.first.der, identity.certificate.der);
    expect(identity.certificate.der, isNotEmpty);
    expect(identity.privateKeyInfoDer, isNotEmpty);
    final signature = RsaSha256SignatureProvider(identity.rsaPrivateKey);
    expect(signature.sign([1, 2, 3]), completes);
  });

  test('assina e verifica texto com a identidade e o certificado', () async {
    final encoded = File(
      'test/fixtures/synthetic_a1.p12.b64',
    ).readAsStringSync().replaceAll(RegExp(r'\s'), '');
    final identity = PfxIdentity.fromPfx(
      bytes: base64Decode(encoded),
      password: 'test-password',
    );

    final signature = await identity.sign('conteúdo fiscal');

    expect(identity.verify('conteúdo fiscal', signature), isTrue);
    expect(identity.certificate.verify('conteúdo fiscal', signature), isTrue);
    expect(
      identity.certificate.verify('conteúdo alterado', signature),
      isFalse,
    );
  });

  test('verifica assinatura e cadeia X.509 do certificado PFX', () {
    final encoded = File(
      'test/fixtures/synthetic_a1.p12.b64',
    ).readAsStringSync().replaceAll(RegExp(r'\s'), '');
    final identity = PfxIdentity.fromPfx(
      bytes: base64Decode(encoded),
      password: 'test-password',
    );

    expect(identity.certificate.verifyIssuedBy(identity.certificate), isTrue);
    expect(identity.verifyCertificateChain(), isTrue);
    expect(
      identity.certificate.verifyIssuedBy(Certificate(Uint8List.fromList([1]))),
      isFalse,
    );
  });

  test('protege buffers DER e PKCS#8 com cópias defensivas', () {
    final encoded = File(
      'test/fixtures/synthetic_a1.p12.b64',
    ).readAsStringSync().replaceAll(RegExp(r'\s'), '');
    final identity = PfxIdentity.fromPfx(
      bytes: base64Decode(encoded),
      password: 'test-password',
    );
    final certificateBytes = identity.certificate.der;
    final privateKeyBytes = identity.privateKeyInfoDer;
    final certificateFirst = certificateBytes.first;
    final privateKeyFirst = privateKeyBytes.first;

    certificateBytes[0] ^= 0xff;
    privateKeyBytes[0] ^= 0xff;

    expect(identity.certificate.der.first, certificateFirst);
    expect(identity.privateKeyInfoDer.first, privateKeyFirst);
    expect(() => identity.rsaPrivateKey, returnsNormally);
  });

  test('identidade PFX assina XML e anexa o certificado', () async {
    final encoded = File(
      'test/fixtures/synthetic_a1.p12.b64',
    ).readAsStringSync().replaceAll(RegExp(r'\s'), '');
    final identity = PfxIdentity.fromPfx(
      bytes: base64Decode(encoded),
      password: 'test-password',
    );
    final signed = await XmlSignatureService.fromPfx(
      identity,
    ).sign('<NFe><infNFe Id="NFe123" versao="4.00"><ide/></infNFe></NFe>');

    expect(signed, contains('<X509Certificate>${identity.certificate.base64}'));
    expect(signed, contains('<SignatureValue>'));
  });

  test('identidade PFX verifica SignatureValue e rejeita wrapping', () async {
    final encoded = File(
      'test/fixtures/synthetic_a1.p12.b64',
    ).readAsStringSync().replaceAll(RegExp(r'\s'), '');
    final identity = PfxIdentity.fromPfx(
      bytes: base64Decode(encoded),
      password: 'test-password',
    );
    final service = XmlSignatureService.fromPfx(identity);
    const source = '<NFe><infNFe Id="NFe123"><ide/></infNFe></NFe>';
    final signed = await service.sign(source);
    final privateKey = identity.rsaPrivateKey;
    final verifier = RsaSha1SignatureVerifier(
      RSAPublicKey(privateKey.modulus!, privateKey.publicExponent!),
    );

    expect(service.verifySignature(signed, verifier), isTrue);
    expect(
      service.verifySignature(
        signed.replaceFirst('Id="NFe123"', 'Id="NFeOutro"'),
        verifier,
      ),
      isFalse,
    );
  });

  test('fachada de emissão monta e assina documento', () async {
    final encoded = File(
      'test/fixtures/synthetic_a1.p12.b64',
    ).readAsStringSync().replaceAll(RegExp(r'\s'), '');
    final identity = PfxIdentity.fromPfx(
      bytes: base64Decode(encoded),
      password: 'test-password',
    );
    final key = AccessKey.fromComponents(
      cUf: '11',
      issueDate: DateTime.utc(2026, 1, 1),
      cnpj: '04252011000110',
      model: 55,
      series: 1,
      number: 1,
      tpEmis: 1,
      cNf: '12345678',
    );
    final document = NfeDocument(
      accessKey: key.value,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      operationNature: 'Venda de mercadoria',
      documentType: 1,
      destinationType: 1,
      printFormat: 1,
      purpose: 1,
      finalConsumer: 0,
      presenceIndicator: 1,
      processCode: '0',
      applicationVersion: '1.0.0',
      issuer: const Party(
        name: 'Empresa de Teste',
        cnpj: '04252011000110',
        ie: '123456789',
        address: 'Rua Fiscal',
        addressNumber: '1',
        neighborhood: 'Centro',
        cityCode: '1100015',
        city: 'Alta Floresta D Oeste',
        state: 'RO',
        zipCode: '76954000',
      ),
      items: const [
        NfeItem(
          number: 1,
          code: 'ABC',
          description: 'Produto',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 5,
          icms: IcmsTax(cst: '00', base: 5, rate: 18, value: 0.9),
        ),
      ],
    );
    final signing = XmlSignatureService.fromPfx(identity);
    final emission = NfeEmissionService(signer: signing);
    final signed = await emission.buildAndSign(document);
    final privateKey = identity.rsaPrivateKey;

    expect(signed, contains('<SignatureValue>'));
    expect(
      emission.verifySigned(
        signed,
        RsaSha1SignatureVerifier(
          RSAPublicKey(privateKey.modulus!, privateKey.publicExponent!),
        ),
      ),
      isTrue,
    );
  });

  test('assina e verifica envEvento no infEvento', () async {
    final encoded = File(
      'test/fixtures/synthetic_a1.p12.b64',
    ).readAsStringSync().replaceAll(RegExp(r'\s'), '');
    final identity = PfxIdentity.fromPfx(
      bytes: base64Decode(encoded),
      password: 'test-password',
    );
    final source =
        '''<envEvento xmlns="http://www.portalfiscal.inf.br/nfe" versao="1.00">
  <idLote>1</idLote>
  <evento versao="1.00">
    <infEvento Id="ID11014041111111111111111111111111111111111111111111111111">
      <cOrgao>11</cOrgao><tpAmb>2</tpAmb><CNPJ>04252011000110</CNPJ>
      <chNFe>41111111111111111111111111111111111111111111111111</chNFe>
      <dhEvento>2026-01-01T12:00:00+00:00</dhEvento>
      <tpEvento>110140</tpEvento><nSeqEvento>1</nSeqEvento><verEvento>1.00</verEvento>
      <detEvento versao="1.00"><descEvento>EPEC</descEvento></detEvento>
    </infEvento>
  </evento>
</envEvento>''';
    final service = XmlSignatureService.fromPfx(identity);
    final signed = await service.signEvent(source);
    final privateKey = identity.rsaPrivateKey;
    expect(signed, contains('<evento'));
    expect(signed, contains('<Signature'));
    expect(
      service.verifyEventSignature(
        signed,
        RsaSha1SignatureVerifier(
          RSAPublicKey(privateKey.modulus!, privateKey.publicExponent!),
        ),
      ),
      isTrue,
    );
    expect(
      service.verifyEventSignature(
        signed.replaceFirst(
          '<descEvento>EPEC</descEvento>',
          '<descEvento>Alterado</descEvento>',
        ),
        RsaSha1SignatureVerifier(
          RSAPublicKey(privateKey.modulus!, privateKey.publicExponent!),
        ),
      ),
      isFalse,
    );
  });

  test('rejeita infEvento aninhado fora da posição fiscal', () async {
    final service = XmlSignatureService(_TestSigner());
    const source =
        '<envEvento><evento><wrapper><infEvento Id="ID1"/></wrapper></evento></envEvento>';

    expect(
      () => service.signEvent(source),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'INVALID_EVENT_XML_FOR_SIGNATURE',
        ),
      ),
    );
  });

  test('verificador de inutilização rejeita assinatura aninhada', () {
    final service = XmlSignatureService(_TestSigner());
    const malformed =
        '<inutNFe><wrapper><infInut Id="ID1"/><Signature/></wrapper></inutNFe>';

    expect(
      service.verifyInutilizationSignature(
        malformed,
        RsaSha256SignatureVerifier(RSAPublicKey(BigInt.zero, BigInt.one)),
      ),
      isFalse,
    );
  });

  test('cria transporte HTTPS com certificado cliente A1', () {
    final encoded = File(
      'test/fixtures/synthetic_a1.p12.b64',
    ).readAsStringSync().replaceAll(RegExp(r'\s'), '');
    final identity = PfxIdentity.fromPfx(
      bytes: base64Decode(encoded),
      password: 'test-password',
    );

    expect(IoSefazTransport.fromPfx(identity), isA<IoSefazTransport>());
  });
}
