import 'dart:convert';

import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';
import 'package:test/test.dart';

class _TestQrSignatureProvider implements XmlSignatureProvider {
  @override
  Future<String> sign(List<int> signedInfo) async => base64Encode(signedInfo);
}

void main() {
  final key = AccessKey.fromComponents(
    cUf: '11',
    issueDate: DateTime.utc(2017, 8, 2),
    cnpj: '04.252.011/0001-10',
    model: 65,
    series: 1,
    number: 1,
    tpEmis: 1,
    cNf: '12345678',
  ).value;

  test('gera QR Code online com hash SHA-1 e CSC', () {
    final qr = NfceQrCode.online(
      accessKey: key,
      environment: 1,
      cscId: 1,
      csc: 'CSC-DE-TESTE',
      baseUrl: 'https://nfce.example.test/qrcode',
    );

    expect(qr.data, hasLength(91));
    expect(qr.url, startsWith('https://nfce.example.test/qrcode?p='));
    expect(qr.data.split('|').length, 5);
  });

  test('gera QR Code 3.00 online sem CSC', () {
    final qr = NfceQrCode.onlineV3(
      accessKey: key,
      environment: 2,
      baseUrl: 'https://nfce.example.test/qrcode',
    );

    expect(qr.data, '$key|3|2');
    expect(qr.url, 'https://nfce.example.test/qrcode?p=$key|3|2');
  });

  test('gera QR Code 3.00 offline assinado com destinatário CPF', () async {
    final qr = await NfceQrCode.offlineV3(
      accessKey: key,
      environment: 1,
      issueDate: DateTime.utc(2017, 8, 2),
      total: 60.90,
      recipientTaxId: '52998224725',
      signatureProvider: _TestQrSignatureProvider(),
      baseUrl: 'https://nfce.example.test/qrcode',
    );

    final fields = qr.data.split('|');
    expect(fields.sublist(0, 7), [
      key,
      '3',
      '1',
      '02',
      '60.90',
      '2',
      '52998224725',
    ]);
    expect(fields, hasLength(8));
    expect(base64Decode(fields.last), isNotEmpty);
  });

  test(
    'QR Code 3.00 offline deixa destinatário não identificado vazio',
    () async {
      final qr = await NfceQrCode.offlineV3(
        accessKey: key,
        environment: 1,
        issueDate: DateTime.utc(2017, 8, 2),
        total: 1,
        signatureProvider: _TestQrSignatureProvider(),
        baseUrl: 'https://nfce.example.test/qrcode',
      );

      expect(qr.data.split('|').sublist(5, 7), ['', '']);
    },
  );

  test('gera QR Code offline conforme exemplo do manual', () {
    final qr = NfceQrCode.offline(
      accessKey: key,
      environment: 1,
      issueDate: DateTime.utc(2017, 8, 2),
      total: 60.90,
      digestValue: 'yzGYhUx1/XYYzksWB+fPR3Qc50c=',
      cscId: 1,
      csc: 'SEU-CODIGO-CSC-CONTRIBUINTE-36-CARACTERES----------------',
      baseUrl: 'https://nfce.example.test/qrcode',
    );

    expect(
      qr.data,
      startsWith(
        '$key|2|1|02|60.90|797a4759685578312f5859597a6b7357422b6650523351633530633d|1|',
      ),
    );
    expect(qr.data.split('|'), hasLength(8));
  });

  test('rejeita chave que não é NFC-e', () {
    expect(
      () => NfceQrCode.online(
        accessKey: AccessKey.fromComponents(
          cUf: '11',
          issueDate: DateTime.utc(2026, 1, 1),
          cnpj: '04.252.011/0001-10',
          model: 55,
          series: 1,
          number: 1,
          tpEmis: 1,
          cNf: '12345678',
        ).value,
        environment: 2,
        cscId: 1,
        csc: 'CSC',
        baseUrl: 'https://example.test/qrcode',
      ),
      throwsA(isA<FiscalValidationException>()),
    );
  });

  test('rejeita endpoint e DigestValue inválidos', () {
    expect(
      () => NfceQrCode.offline(
        accessKey: key,
        environment: 1,
        issueDate: DateTime.utc(2017, 8, 2),
        total: 1,
        digestValue: '',
        cscId: 1,
        csc: 'CSC',
        baseUrl: 'file:///tmp/qrcode',
      ),
      throwsA(isA<FiscalValidationException>()),
    );
  });

  test('injeta QR Code online antes da assinatura XMLDSig', () {
    final signed =
        '''<NFe xmlns="http://www.portalfiscal.inf.br/nfe">
      <infNFe Id="NFe$key" versao="4.00"><ide><mod>65</mod></ide></infNFe>
      <Signature><SignedInfo/></Signature>
    </NFe>''';
    final payload = NfceQrCode.online(
      accessKey: key,
      environment: 1,
      cscId: 1,
      csc: 'CSC-DE-TESTE',
      baseUrl: 'https://nfce.example.test/qrcode',
    );

    final xml = NfceQrCode.injectIntoXml(
      signedXml: signed,
      payload: payload,
      keyUrl: 'https://nfce.example.test/chave',
    );

    expect(xml.indexOf('<infNFeSupl>'), lessThan(xml.indexOf('<Signature>')));
    expect(xml, contains('<qrCode>${payload.url}</qrCode>'));
    expect(
      xml,
      contains('<urlChave>https://nfce.example.test/chave</urlChave>'),
    );
  });

  test('rejeita suplemento duplicado ou XML sem assinatura', () {
    final payload = NfceQrCode.online(
      accessKey: key,
      environment: 1,
      cscId: 1,
      csc: 'CSC-DE-TESTE',
      baseUrl: 'https://nfce.example.test/qrcode',
    );
    const unsigned = '<NFe><infNFe><ide><mod>65</mod></ide></infNFe></NFe>';
    expect(
      () => NfceQrCode.injectIntoXml(signedXml: unsigned, payload: payload),
      throwsA(isA<FiscalValidationException>()),
    );
  });
}
