import 'dart:convert';
import 'dart:io';

import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';

/// Gera um item monofásico da NT 2025.002 para validação externa no XSD.
Future<void> main(List<String> arguments) async {
  final outputIndex = arguments.indexOf('--out');
  if (outputIndex < 0 || outputIndex + 1 >= arguments.length) {
    stderr.writeln(
      'Uso: dart run tool/validate_monophase_example.dart --out arquivo.xml',
    );
    exitCode = 64;
    return;
  }
  final issueDate = DateTime.utc(2026, 1, 1, 12);
  final key = AccessKey.fromComponents(
    cUf: '11',
    issueDate: issueDate,
    cnpj: '04252011000110',
    model: 55,
    series: 1,
    number: 18,
    tpEmis: 1,
    cNf: '12345678',
  );
  final document = NfeDocument(
    accessKey: key.value,
    number: 18,
    series: 1,
    issueDate: issueDate,
    environment: 2,
    model: 55,
    documentType: 1,
    destinationType: 1,
    printFormat: 1,
    purpose: 1,
    finalConsumer: 0,
    presenceIndicator: 0,
    processCode: '0',
    applicationVersion: '0.1.0',
    operationNature: 'Venda monofásica',
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
      crt: '3',
    ),
    payments: const [Payment(type: '01', value: 100)],
    items: const [
      NfeItem(
        number: 1,
        code: 'MONO-001',
        description: 'Produto monofásico',
        ncm: '27101259',
        cfop: '5656',
        unit: 'L',
        quantity: 10,
        unitPrice: 10,
        ibsCbsMonophase: IbsCbsMonophaseTax(
          cst: '620',
          classificationCode: '000001',
          quantity: 10,
          ibsRate: 0.10,
          ibsValue: 1,
          cbsRate: 0.20,
          cbsValue: 2,
          ibsBiofuelQuantity: 0.5,
          ibsBiofuelDifference: 0.03,
          cbsBiofuelQuantity: 0.5,
          cbsBiofuelDifference: 0.01,
        ),
      ),
    ],
  );
  final pfxBase64 = File(
    'test/fixtures/synthetic_a1.p12.b64',
  ).readAsStringSync().replaceAll(RegExp(r'\s'), '');
  final signed = await NfeEmissionService(
    signer: XmlSignatureService.fromPfx(
      PfxIdentity.fromPfx(
        bytes: base64Decode(pfxBase64),
        password: 'test-password',
      ),
    ),
  ).buildAndSign(document);
  File(arguments[outputIndex + 1]).writeAsStringSync(signed);
}
