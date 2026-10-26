import 'dart:convert';
import 'dart:io';

import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

void main() {
  test(
    'coordena assinatura, digest e QR Code de contingência offline',
    () async {
      final pfx = base64Decode(
        File(
          'test/fixtures/synthetic_a1.p12.b64',
        ).readAsStringSync().replaceAll(RegExp(r'\s'), ''),
      );
      final identity = PfxIdentity.fromPfx(
        bytes: pfx,
        password: 'test-password',
      );
      final issueDate = DateTime.utc(2026, 1, 1, 12);
      final key = AccessKey.fromComponents(
        cUf: '11',
        issueDate: issueDate,
        cnpj: '04252011000110',
        model: 65,
        series: 1,
        number: 8,
        tpEmis: 9,
        cNf: '12345678',
      ).value;
      final result =
          await NfceOfflineEmissionService(
            signer: XmlSignatureService.fromPfx(identity),
          ).prepare(
            document: NfeDocument(
              accessKey: key,
              number: 8,
              series: 1,
              issueDate: issueDate,
              environment: 2,
              model: 65,
              issuer: const Party(
                name: 'Empresa Offline',
                cnpj: '04252011000110',
                ie: '123456789',
                address: 'Rua Fiscal',
                addressNumber: '1',
                neighborhood: 'Centro',
                cityCode: '1100015',
                city: 'Alta Floresta D Oeste',
                state: 'RO',
                zipCode: '76954000',
                crt: '1',
              ),
              operationNature: 'Venda de mercadoria',
              documentType: 1,
              destinationType: 1,
              municipalityCode: '1100015',
              printFormat: 4,
              finalConsumer: 1,
              presenceIndicator: 1,
              purpose: 1,
              processCode: '0',
              applicationVersion: 'FlutterFiscalLIB 1.0',
              contingency: Contingency(
                mode: ContingencyMode.offlineNfce,
                activatedAt: issueDate,
                reason: 'Indisponibilidade temporária da SEFAZ',
              ),
              items: const [
                NfeItem(
                  number: 1,
                  code: 'OFF-1',
                  description: 'Produto offline',
                  ncm: '12345678',
                  cfop: '5102',
                  unit: 'UN',
                  quantity: 1,
                  unitPrice: 12,
                ),
              ],
            ),
            cscId: 1,
            csc: 'CSC-DE-TESTE',
            baseUrl: 'https://nfce.example.test/qrcode',
          );

      final document = XmlDocument.parse(result.signedXml);
      final children = document.rootElement.children
          .whereType<XmlElement>()
          .toList();
      expect(children.map((element) => element.localName), [
        'infNFe',
        'infNFeSupl',
        'Signature',
      ]);
      expect(result.signedXml, contains('<tpEmis>9</tpEmis>'));
      expect(result.signedXml, contains('<infNFeSupl>'));
      expect(result.signedXml, contains(result.qrCode.url));
      expect(
        XmlSignatureService.fromPfx(identity).verifyDigest(result.signedXml),
        isTrue,
      );
    },
  );

  test('integra QR Code 3.00 no serviço de emissão offline', () async {
    final pfx = base64Decode(
      File(
        'test/fixtures/synthetic_a1.p12.b64',
      ).readAsStringSync().replaceAll(RegExp(r'\s'), ''),
    );
    final identity = PfxIdentity.fromPfx(bytes: pfx, password: 'test-password');
    final signer = XmlSignatureService.fromPfx(identity);
    final issueDate = DateTime.utc(2026, 1, 2, 12);
    final key = AccessKey.fromComponents(
      cUf: '11',
      issueDate: issueDate,
      cnpj: '04252011000110',
      model: 65,
      series: 1,
      number: 9,
      tpEmis: 9,
      cNf: '12345679',
    ).value;
    final result = await NfceOfflineEmissionService(signer: signer).prepare(
      document: NfeDocument(
        accessKey: key,
        number: 9,
        series: 1,
        issueDate: issueDate,
        environment: 2,
        model: 65,
        issuer: const Party(
          name: 'Empresa Offline',
          cnpj: '04252011000110',
          ie: '123456789',
          address: 'Rua Fiscal',
          addressNumber: '1',
          neighborhood: 'Centro',
          cityCode: '1100015',
          city: 'Alta Floresta D Oeste',
          state: 'RO',
          zipCode: '76954000',
          crt: '1',
        ),
        recipient: const Party(name: 'Consumidor', cpf: '52998224725'),
        operationNature: 'Venda de mercadoria',
        documentType: 1,
        destinationType: 1,
        municipalityCode: '1100015',
        printFormat: 4,
        finalConsumer: 1,
        presenceIndicator: 1,
        purpose: 1,
        processCode: '0',
        applicationVersion: 'FlutterFiscalLIB 1.0',
        contingency: Contingency(
          mode: ContingencyMode.offlineNfce,
          activatedAt: issueDate,
          reason: 'Indisponibilidade temporária da SEFAZ',
        ),
        items: const [
          NfeItem(
            number: 1,
            code: 'OFF-3',
            description: 'Produto offline v3',
            ncm: '12345678',
            cfop: '5102',
            unit: 'UN',
            quantity: 1,
            unitPrice: 12,
          ),
        ],
      ),
      baseUrl: 'https://nfce.example.test/qrcode',
      qrCodeVersion: 3,
    );

    expect(result.qrCode.data.split('|').sublist(0, 7), [
      key,
      '3',
      '2',
      '02',
      '12.00',
      '2',
      '52998224725',
    ]);
    expect(result.qrCode.data.split('|'), hasLength(8));
    expect(result.signedXml, contains('<infNFeSupl>'));
  });
}
