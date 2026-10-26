import 'dart:convert';
import 'dart:io';

import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';
import 'package:test/test.dart';

class _QrCodeVerifier implements XmlSignatureVerifier {
  _QrCodeVerifier(this.result);

  final bool result;
  List<int>? signedData;

  @override
  bool verify(List<int> data, String signatureBase64) {
    signedData = data;
    return result;
  }
}

NfeDocument _nfceDocument({
  required NfceXmlSupplement supplement,
  Contingency? contingency,
}) {
  return NfeDocument.fromComponents(
    cUf: '11',
    cnpj: '04252011000110',
    cNf: '12345678',
    number: 1,
    series: 1,
    issueDate: DateTime.utc(2026, 1, 1, 12),
    environment: 2,
    model: 65,
    issuer: const Party(name: 'Empresa de Teste', cnpj: '04252011000110'),
    items: const [
      NfeItem(
        number: 1,
        code: 'ABC',
        description: 'Produto de teste',
        ncm: '12345678',
        cfop: '5102',
        unit: 'UN',
        quantity: 1,
        unitPrice: 10,
      ),
    ],
    contingency: contingency,
    nfceSupplement: supplement,
  );
}

String _buildNfce({
  required NfceXmlSupplement supplement,
  Contingency? contingency,
}) {
  return NfeXmlBuilder().build(
    _nfceDocument(supplement: supplement, contingency: contingency),
  );
}

void main() {
  test('fixture XML mínimo passa na validação estrutural', () {
    final xml = File('test/fixtures/nfe_minimal.xml').readAsStringSync();
    final result = NfeXmlValidator().validate(xml);

    expect(result.isValid, isTrue, reason: result.errors.join('; '));
  });

  test('fixture XML alterado perde validade da chave', () {
    final xml = File('test/fixtures/nfe_minimal.xml')
        .readAsStringSync()
        .replaceFirst(
          'NFe11012604252011000110550010000000011123456784',
          'NFe1',
        );

    final result = NfeXmlValidator().validate(xml);

    expect(result.isValid, isFalse);
    expect(
      result.errors,
      contains('O Id não contém uma chave de acesso válida.'),
    );
  });

  test('rejeita ide incoerente com a chave de acesso', () {
    final xml = File(
      'test/fixtures/nfe_minimal.xml',
    ).readAsStringSync().replaceFirst('<nNF>1</nNF>', '<nNF>2</nNF>');

    final result = NfeXmlValidator().validate(xml);

    expect(result.isValid, isFalse);
    expect(
      result.errors,
      contains('O campo nNF do ide não corresponde à chave de acesso.'),
    );
  });

  test('rejeita emitente com documento inválido', () {
    final xml = File('test/fixtures/nfe_minimal.xml')
        .readAsStringSync()
        .replaceFirst(
          '<CNPJ>04252011000110</CNPJ>',
          '<CNPJ>04252011000111</CNPJ>',
        );

    final result = NfeXmlValidator().validate(xml);

    expect(result.isValid, isFalse);
    expect(result.errors, contains('O CNPJ do emitente é inválido.'));
  });

  test('valida destinatário quando o grupo dest está presente', () {
    final xml = File('test/fixtures/nfe_minimal.xml')
        .readAsStringSync()
        .replaceFirst(
          '</emit>',
          '''</emit><dest><CNPJ>04252011000111</CNPJ><xNome>Cliente</xNome></dest>''',
        );

    final result = NfeXmlValidator().validate(xml);

    expect(result.isValid, isFalse);
    expect(result.errors, contains('O CNPJ do destinatário é inválido.'));
  });

  test('rejeita participante com CNPJ e CPF simultâneos', () {
    final xml = File('test/fixtures/nfe_minimal.xml')
        .readAsStringSync()
        .replaceFirst(
          '<CNPJ>04252011000110</CNPJ>',
          '<CNPJ>04252011000110</CNPJ><CPF>52998224725</CPF>',
        );

    final result = NfeXmlValidator().validate(xml);

    expect(result.isValid, isFalse);
    expect(
      result.errors,
      contains('O emitente deve informar exatamente um CNPJ ou CPF.'),
    );
  });

  test('rejeita contingência offline incompleta e em modelo 55', () {
    final xml = File('test/fixtures/nfe_minimal.xml')
        .readAsStringSync()
        .replaceFirst('<tpEmis>1</tpEmis>', '<tpEmis>9</tpEmis>');

    final result = NfeXmlValidator().validate(xml);

    expect(result.isValid, isFalse);
    expect(
      result.errors,
      contains(
        'A contingência offline tpEmis=9 é exclusiva da NFC-e modelo 65.',
      ),
    );
    expect(result.errors, contains('O campo dhCont é obrigatório.'));
    expect(result.errors, contains('O campo xJust é obrigatório.'));
  });

  test('rejeita FS ou SVC em NFC-e modelo 65', () {
    final xml = File('test/fixtures/nfe_minimal.xml')
        .readAsStringSync()
        .replaceFirst('<mod>55</mod>', '<mod>65</mod>')
        .replaceFirst('<tpEmis>1</tpEmis>', '<tpEmis>6</tpEmis>');

    final result = NfeXmlValidator().validate(xml);

    expect(result.isValid, isFalse);
    expect(
      result.errors,
      contains('A NFC-e modelo 65 aceita somente tpEmis=1 ou tpEmis=9.'),
    );
  });

  test('rejeita totalizador de produtos divergente dos itens', () {
    final xml = File('test/fixtures/nfe_minimal.xml')
        .readAsStringSync()
        .replaceFirst('<vProd>10.00</vProd>', '<vProd>11.00</vProd>');

    final result = NfeXmlValidator().validate(xml);

    expect(result.isValid, isFalse);
    expect(
      result.errors,
      contains('O total vProd não corresponde à soma dos itens.'),
    );
  });

  test('aceita vNF com frete e desconto nos totalizadores', () {
    final xml = File('test/fixtures/nfe_minimal.xml')
        .readAsStringSync()
        .replaceFirst(
          '<vProd>10.00</vProd>\n        <vPIS>',
          '<vProd>10.00</vProd><vFrete>1.00</vFrete><vDesc>0.50</vDesc>\n        <vPIS>',
        )
        .replaceFirst('<vNF>10.00</vNF>', '<vNF>10.50</vNF>');

    final result = NfeXmlValidator().validate(xml);

    expect(result.isValid, isTrue, reason: result.errors.join('; '));
  });

  test('rejeita vNF divergente dos totalizadores monetários', () {
    final xml = File('test/fixtures/nfe_minimal.xml')
        .readAsStringSync()
        .replaceFirst(
          '<vProd>10.00</vProd>\n        <vPIS>',
          '<vProd>10.00</vProd><vFrete>1.00</vFrete><vDesc>0.50</vDesc>\n        <vPIS>',
        )
        .replaceFirst('<vNF>10.00</vNF>', '<vNF>10.00</vNF>');

    final result = NfeXmlValidator().validate(xml);

    expect(result.isValid, isFalse);
    expect(
      result.errors,
      contains(
        'O total vNF não corresponde aos totalizadores monetários do documento.',
      ),
    );
  });

  test('rejeita totalizador monetário com formato inválido', () {
    final xml = File(
      'test/fixtures/nfe_minimal.xml',
    ).readAsStringSync().replaceFirst('<vNF>10.00</vNF>', '<vNF>dez</vNF>');

    final result = NfeXmlValidator().validate(xml);

    expect(result.isValid, isFalse);
    expect(
      result.errors,
      contains('O totalizador vNF deve ser decimal positivo.'),
    );
  });

  test('considera troco ao validar a soma dos pagamentos', () {
    final xml = File('test/fixtures/nfe_minimal.xml')
        .readAsStringSync()
        .replaceFirst(
          '</total>',
          '''</total>
    <pag><detPag><tPag>03</tPag><vPag>12.00</vPag></detPag><vTroco>2.00</vTroco></pag>''',
        );

    final result = NfeXmlValidator().validate(xml);

    expect(result.isValid, isTrue, reason: result.errors.join('; '));
  });

  test('rejeita indTot e troco com valores inválidos', () {
    final xml = File('test/fixtures/nfe_minimal.xml')
        .readAsStringSync()
        .replaceFirst(
          '<vProd>10.00</vProd>',
          '<vProd>10.00</vProd><indTot>2</indTot>',
        )
        .replaceFirst(
          '</total>',
          '''</total>
    <pag><detPag><tPag>03</tPag><vPag>10.00</vPag></detPag><vTroco>abc</vTroco></pag>''',
        );

    final result = NfeXmlValidator().validate(xml);

    expect(result.isValid, isFalse);
    expect(
      result.errors,
      contains('O campo indTot do produto deve ser 0 ou 1.'),
    );
    expect(
      result.errors,
      contains('O pagamento vTroco deve ser decimal positivo.'),
    );
  });

  test('rejeita pagamento que não fecha após o troco', () {
    final xml = File('test/fixtures/nfe_minimal.xml')
        .readAsStringSync()
        .replaceFirst(
          '</total>',
          '''</total>
    <pag><detPag><tPag>03</tPag><vPag>11.00</vPag></detPag><vTroco>2.00</vTroco></pag>''',
        );

    final result = NfeXmlValidator().validate(xml);

    expect(result.isValid, isFalse);
    expect(
      result.errors,
      contains('A soma dos pagamentos não corresponde ao vNF.'),
    );
  });

  test('respeita indTot=0 ao validar a soma dos itens', () {
    final xml = File('test/fixtures/nfe_minimal.xml')
        .readAsStringSync()
        .replaceFirst(
          '</det>',
          '''</det>
    <det nItem="2"><prod><cProd>B</cProd><xProd>Fora</xProd><NCM>12345678</NCM><CFOP>5102</CFOP><uCom>UN</uCom><qCom>1.0000</qCom><vUnCom>90.0000000000</vUnCom><vProd>90.00</vProd><indTot>0</indTot></prod></det>''',
        );

    final result = NfeXmlValidator().validate(xml);

    expect(result.isValid, isTrue, reason: result.errors.join('; '));
  });

  test('valida envelope estrutural da assinatura', () {
    final fixture = File('test/fixtures/nfe_minimal.xml').readAsStringSync();
    final id = RegExp(r'Id="([^"]+)"').firstMatch(fixture)!.group(1)!;
    final signed = fixture.replaceFirst(
      '</NFe>',
      '<Signature><SignedInfo><Reference URI="#$id"><DigestValue>digest</DigestValue></Reference></SignedInfo><SignatureValue>value</SignatureValue></Signature></NFe>',
    );

    expect(
      NfeXmlValidator().validate(signed, requireSignature: true).isValid,
      isFalse,
    );
    expect(
      NfeXmlValidator().validate(signed, requireSignature: true).errors,
      contains(
        'A validação de assinatura exige um verificador criptográfico explícito.',
      ),
    );
    expect(
      NfeXmlValidator().validate(fixture, requireSignature: true).errors,
      contains('O XML assinado deve possuir uma assinatura direta.'),
    );
    final nested = fixture.replaceFirst(
      '</infNFe>',
      '<Signature><SignedInfo/></Signature></infNFe>',
    );
    expect(NfeXmlValidator().validate(nested).isValid, isFalse);
    expect(
      () => NfeXmlValidator().assertValid(fixture, requireSignature: true),
      throwsA(isA<FiscalValidationException>()),
    );
  });

  test(
    'permite verificação criptográfica opcional da assinatura XMLDSig',
    () async {
      final xml = File('test/fixtures/nfe_minimal.xml').readAsStringSync();
      final encoded = File(
        'test/fixtures/synthetic_a1.p12.b64',
      ).readAsStringSync().replaceAll(RegExp(r'\s'), '');
      final identity = PfxIdentity.fromPfx(
        bytes: base64Decode(encoded),
        password: 'test-password',
      );
      final service = XmlSignatureService.fromPfx(identity);
      final signed = await service.sign(xml);
      final verifier = RsaSha1SignatureVerifier(
        identity.certificate.rsaPublicKey,
      );

      final result = NfeXmlValidator().validate(
        signed,
        requireSignature: true,
        signatureVerifier: (value) => service.verifySignature(value, verifier),
      );
      expect(result.isValid, isTrue, reason: result.errors.join('; '));
      final tampered = NfeXmlValidator().validate(
        signed.replaceFirst('<vProd>10.00</vProd>', '<vProd>11.00</vProd>'),
        requireSignature: true,
        signatureVerifier: (value) => service.verifySignature(value, verifier),
      );
      expect(tampered.isValid, isFalse);
      expect(
        tampered.errors,
        contains('A assinatura XMLDSig não foi verificada criptograficamente.'),
      );
    },
  );

  test('valida QR Code NFC-e online 2.00 e 3.00', () {
    final document = _nfceDocument(
      supplement: NfceXmlSupplement(
        qrCode: NfceQrCode.online(
          accessKey: AccessKey.fromComponents(
            cUf: '11',
            issueDate: DateTime.utc(2026, 1, 1, 12),
            cnpj: '04252011000110',
            model: 65,
            series: 1,
            number: 1,
            tpEmis: 1,
            cNf: '12345678',
          ).value,
          environment: 2,
          cscId: 1,
          csc: 'CSC-DE-TESTE',
          baseUrl: 'https://nfce.example.test/qrcode',
        ).url,
        keyUrl: 'https://nfce.example.test/chave',
      ),
    );
    final key = document.accessKey;
    final onlineV3 = NfceQrCode.onlineV3(
      accessKey: key,
      environment: 2,
      baseUrl: 'https://nfce.example.test/qrcode',
    );
    final v3Xml = _buildNfce(
      supplement: NfceXmlSupplement(
        qrCode: onlineV3.url,
        keyUrl: 'https://nfce.example.test/chave',
      ),
    );
    final v3Result = NfeXmlValidator().validate(v3Xml);
    expect(v3Result.isValid, isTrue, reason: v3Result.errors.join('; '));

    final v2Result = NfeXmlValidator().validate(
      NfeXmlBuilder().build(document),
    );
    expect(v2Result.isValid, isTrue, reason: v2Result.errors.join('; '));
  });

  test('valida QR Code NFC-e 2.00 offline e rejeita ambiente divergente', () {
    final contingency = Contingency(
      mode: ContingencyMode.offlineNfce,
      activatedAt: DateTime.utc(2026, 1, 1, 12),
      reason: 'Indisponibilidade temporária do serviço autorizador',
    );
    final key = AccessKey.fromComponents(
      cUf: '11',
      issueDate: DateTime.utc(2026, 1, 1, 12),
      cnpj: '04252011000110',
      model: 65,
      series: 1,
      number: 1,
      tpEmis: 9,
      cNf: '12345678',
    ).value;
    final payload = NfceQrCode.offline(
      accessKey: key,
      environment: 2,
      issueDate: DateTime.utc(2026, 1, 1, 12),
      total: 10,
      digestValue: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAA',
      cscId: 1,
      csc: 'CSC-DE-TESTE',
      baseUrl: 'https://nfce.example.test/qrcode',
    );
    final xml = _buildNfce(
      supplement: NfceXmlSupplement(
        qrCode: payload.url,
        keyUrl: 'https://nfce.example.test/chave',
      ),
      contingency: contingency,
    );
    final result = NfeXmlValidator().validate(xml);
    expect(result.isValid, isTrue, reason: result.errors.join('; '));

    final divergent = xml.replaceFirst('<tpAmb>2</tpAmb>', '<tpAmb>1</tpAmb>');
    final divergentResult = NfeXmlValidator().validate(divergent);
    expect(divergentResult.isValid, isFalse);
    expect(
      divergentResult.errors,
      contains('O tpAmb do qrCode não corresponde ao ide.'),
    );
  });

  test('rejeita qrCode e urlChave duplicados no suplemento NFC-e', () {
    final key = AccessKey.fromComponents(
      cUf: '11',
      issueDate: DateTime.utc(2026, 1, 1, 12),
      cnpj: '04252011000110',
      model: 65,
      series: 1,
      number: 1,
      tpEmis: 1,
      cNf: '12345678',
    ).value;
    final payload = NfceQrCode.onlineV3(
      accessKey: key,
      environment: 2,
      baseUrl: 'https://nfce.example.test/qrcode',
    );
    final xml =
        _buildNfce(
          supplement: NfceXmlSupplement(
            qrCode: payload.url,
            keyUrl: 'https://nfce.example.test/chave',
          ),
        ).replaceFirst(
          '</infNFeSupl>',
          '<qrCode>${payload.url}</qrCode><urlChave>https://nfce.example.test/chave</urlChave></infNFeSupl>',
        );
    final result = NfeXmlValidator().validate(xml);
    expect(result.isValid, isFalse);
    expect(
      result.errors,
      contains('O grupo infNFeSupl não pode possuir qrCode duplicado.'),
    );
    expect(
      result.errors,
      contains('O grupo infNFeSupl não pode possuir urlChave duplicado.'),
    );
  });

  test('verifica opcionalmente a assinatura do QR Code 3.00 offline', () async {
    final contingency = Contingency(
      mode: ContingencyMode.offlineNfce,
      activatedAt: DateTime.utc(2026, 1, 1, 12),
      reason: 'Indisponibilidade temporária do serviço autorizador',
    );
    final key = AccessKey.fromComponents(
      cUf: '11',
      issueDate: DateTime.utc(2026, 1, 1, 12),
      cnpj: '04252011000110',
      model: 65,
      series: 1,
      number: 1,
      tpEmis: 9,
      cNf: '12345678',
    ).value;
    final encoded = File(
      'test/fixtures/synthetic_a1.p12.b64',
    ).readAsStringSync().replaceAll(RegExp(r'\s'), '');
    final identity = PfxIdentity.fromPfx(
      bytes: base64Decode(encoded),
      password: 'test-password',
    );
    final payload = await NfceQrCode.offlineV3(
      accessKey: key,
      environment: 2,
      issueDate: DateTime.utc(2026, 1, 1, 12),
      total: 10,
      signatureProvider: RsaSha1SignatureProvider(identity.rsaPrivateKey),
      baseUrl: 'https://nfce.example.test/qrcode',
    );
    final xml = _buildNfce(
      supplement: NfceXmlSupplement(
        qrCode: payload.url,
        keyUrl: 'https://nfce.example.test/chave',
      ),
      contingency: contingency,
    );
    final verifier = RsaSha1SignatureVerifier(
      identity.certificate.rsaPublicKey,
    );
    final valid = NfeXmlValidator().validate(
      xml,
      qrCodeSignatureVerifier: verifier,
    );
    expect(valid.isValid, isTrue, reason: valid.errors.join('; '));

    final invalidVerifier = _QrCodeVerifier(false);
    final invalid = NfeXmlValidator().validate(
      xml,
      qrCodeSignatureVerifier: invalidVerifier,
    );
    expect(invalid.isValid, isFalse);
    expect(
      invalid.errors,
      contains(
        'A assinatura do qrCode 3.00 não foi verificada criptograficamente.',
      ),
    );
  });
}
