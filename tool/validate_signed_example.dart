import 'dart:convert';
import 'dart:io';

import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';

/// Gera uma NFC-e assinada usando somente o certificado sintético do fixture.
/// A validação XSD é executada pelo comando xmllint no CI, fora do núcleo Dart.
Future<void> main(List<String> arguments) async {
  final outputIndex = arguments.indexOf('--out');
  if (outputIndex < 0 || outputIndex + 1 >= arguments.length) {
    stderr.writeln(
      'Uso: dart run tool/validate_signed_example.dart --out arquivo.xml',
    );
    exitCode = 64;
    return;
  }

  final pfxBase64 = File(
    'test/fixtures/synthetic_a1.p12.b64',
  ).readAsStringSync().replaceAll(RegExp(r'\s'), '');
  final identity = PfxIdentity.fromPfx(
    bytes: base64Decode(pfxBase64),
    password: 'test-password',
  );
  final issueDate = DateTime.utc(2026, 1, 1, 12);
  final key = AccessKey.fromComponents(
    cUf: '11',
    issueDate: issueDate,
    cnpj: '04252011000110',
    model: 65,
    series: 1,
    number: 1,
    tpEmis: 1,
    cNf: '12345678',
  );
  final document = NfeDocument(
    accessKey: key.value,
    number: 1,
    series: 1,
    issueDate: issueDate,
    environment: 2,
    model: 65,
    operationNature: 'Venda de mercadoria',
    documentType: 1,
    destinationType: 1,
    printFormat: 4,
    purpose: 1,
    finalConsumer: 1,
    presenceIndicator: 1,
    processCode: '0',
    applicationVersion: '0.1.0',
    issuer: const Party(
      name: 'Empresa de Fixture',
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
    payments: const [Payment(type: '01', value: 10)],
    items: [
      NfeItem(
        number: 1,
        code: 'FIXTURE-001',
        description: 'Produto de fixture',
        ncm: '12345678',
        cfop: '5102',
        unit: 'UN',
        quantity: 1,
        unitPrice: 10,
        serviceTax: ServiceTax(
          base: 10,
          rate: 5,
          value: 0.5,
          municipalityCode: '1100015',
          serviceListCode: '01.01',
          serviceCode: '0101',
          incidenceMunicipalityCode: '1100015',
          competenceDate: issueDate,
        ),
      ),
    ],
  );
  final signed = await NfeEmissionService(
    signer: XmlSignatureService.fromPfx(identity),
  ).buildAndSign(document);
  File(arguments[outputIndex + 1]).writeAsStringSync(signed);
}
