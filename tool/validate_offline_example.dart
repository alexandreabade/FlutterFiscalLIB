import 'dart:convert';
import 'dart:io';

import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';

/// Gera uma NFC-e offline assinada e com QR Code para validação XSD externa.
Future<void> main(List<String> arguments) async {
  final outputIndex = arguments.indexOf('--out');
  if (outputIndex < 0 || outputIndex + 1 >= arguments.length) {
    stderr.writeln(
      'Uso: dart run tool/validate_offline_example.dart --out arquivo.xml',
    );
    exitCode = 64;
    return;
  }
  final bytes = base64Decode(
    File(
      'test/fixtures/synthetic_a1.p12.b64',
    ).readAsStringSync().replaceAll(RegExp(r'\s'), ''),
  );
  final identity = PfxIdentity.fromPfx(bytes: bytes, password: 'test-password');
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
  final emission =
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
          contingency: Contingency(
            mode: ContingencyMode.offlineNfce,
            activatedAt: issueDate,
            reason: 'Indisponibilidade temporária da SEFAZ',
          ),
          operationNature: 'Venda',
          documentType: 1,
          destinationType: 1,
          municipalityCode: '1100015',
          printFormat: 4,
          finalConsumer: 1,
          presenceIndicator: 1,
          purpose: 1,
          processCode: '0',
          applicationVersion: 'FlutterFiscalLIB 1.0',
          payments: const [Payment(type: '01', value: 12)],
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
              icms: IcmsTax(cst: '00', base: 12, rate: 18, value: 2.16),
            ),
          ],
        ),
        cscId: 1,
        csc: 'CSC-DE-TESTE',
        baseUrl: 'https://nfce.example.test/qrcode',
      );
  File(arguments[outputIndex + 1]).writeAsStringSync(emission.signedXml);
}
