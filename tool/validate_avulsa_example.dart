import 'dart:convert';
import 'dart:io';

import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';

/// Gera uma NF-e avulsa para validação contra o schema oficial.
Future<void> main(List<String> arguments) async {
  final outputIndex = arguments.indexOf('--out');
  if (outputIndex < 0 || outputIndex + 1 >= arguments.length) {
    stderr.writeln(
      'Uso: dart run tool/validate_avulsa_example.dart --out arquivo.xml',
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
    number: 17,
    tpEmis: 1,
    cNf: '12345678',
  );
  final document = NfeDocument(
    accessKey: key.value,
    number: 17,
    series: 1,
    issueDate: issueDate,
    environment: 2,
    model: 55,
    operationNature: 'Emissão avulsa',
    documentType: 1,
    destinationType: 1,
    printFormat: 1,
    purpose: 1,
    finalConsumer: 0,
    presenceIndicator: 0,
    intermediaryIndicator: 0,
    processCode: '0',
    applicationVersion: '0.1.0',
    issuer: const Party(
      name: 'Empresa Fiscal',
      cnpj: '04252011000110',
      ie: '123456789',
      address: 'Rua Fiscal',
      addressNumber: '1',
      neighborhood: 'Centro',
      cityCode: '1100015',
      city: 'Porto Velho',
      state: 'RO',
      zipCode: '76801000',
      crt: '3',
    ),
    avulsa: AvulsaInfo(
      cnpj: '04252011000110',
      agency: 'Órgão Fiscal',
      registration: 'MAT-1',
      agent: 'Agente Fiscal',
      phone: '69999999999',
      state: 'RO',
      revenueDocumentNumber: 'DAR-1',
      documentIssueDate: issueDate,
      revenueDocumentValue: 10,
      fiscalOffice: 'Repartição Fiscal',
      paymentDate: issueDate.add(const Duration(days: 1)),
    ),
    payments: const [Payment(type: '01', value: 10)],
    items: const [
      NfeItem(
        number: 1,
        code: 'AVULSA-001',
        description: 'Produto de fixture avulsa',
        ncm: '12345678',
        cfop: '5102',
        unit: 'UN',
        quantity: 1,
        unitPrice: 10,
        icms: IcmsTax(cst: '00', base: 10, rate: 0, value: 0),
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
