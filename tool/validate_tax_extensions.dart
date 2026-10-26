import 'dart:convert';
import 'dart:io';

import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';

/// Gera uma NF-e com grupos tributários adicionais e deixa a validação XSD
/// para o comando `xmllint` executado pelo CI.
Future<void> main(List<String> arguments) async {
  final outputIndex = arguments.indexOf('--out');
  if (outputIndex < 0 || outputIndex + 1 >= arguments.length) {
    stderr.writeln(
      'Uso: dart run tool/validate_tax_extensions.dart --out arquivo.xml',
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
    number: 15,
    tpEmis: 1,
    cNf: '12345678',
  );
  final document = NfeDocument(
    accessKey: key.value,
    number: 15,
    series: 1,
    issueDate: issueDate,
    environment: 2,
    model: 55,
    operationNature: 'Importação de mercadoria',
    documentType: 1,
    destinationType: 1,
    printFormat: 1,
    purpose: 1,
    finalConsumer: 0,
    presenceIndicator: 0,
    processCode: '0',
    applicationVersion: '0.1.0',
    issuer: const Party(
      name: 'Emitente Fiscal',
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
    taxRetention: const TaxRetention(
      pis: 0.10,
      cofins: 0.20,
      csll: 0.30,
      irrfBase: 5,
      irrf: 0.40,
      socialSecurityBase: 5,
      socialSecurity: 0.50,
    ),
    payments: const [Payment(type: '01', value: 12)],
    items: const [
      NfeItem(
        number: 1,
        code: 'IMPORTADO',
        description: 'Produto com tributos adicionais',
        ncm: '12345678',
        cfop: '3102',
        unit: 'UN',
        quantity: 1,
        unitPrice: 10,
        icms: IcmsTax(cst: '00', base: 10, rate: 18, value: 1.8),
        icmsUfDestination: IcmsUfDestinationTax(
          base: 10,
          destinationRate: 18,
          interstateRate: 12,
          partitionRate: 100,
          destinationValue: 0.6,
          originValue: 0,
        ),
        ipi: IpiTax(
          enquadramento: '999',
          cst: '51',
          base: 0,
          rate: 0,
          value: 0,
        ),
        importTax: ImportTax(base: 10, customsExpenses: 1, value: 2, iof: 0.1),
        pisSt: PisStTax(base: 10, rate: 1.65, value: 0.17),
        cofinsSt: CofinsStTax(base: 10, rate: 7.6, value: 0.76),
        ipiDevolution: IpiDevolution(percentage: 50, value: 0.5),
        selectiveTax: SelectiveTax(
          cst: '000',
          classificationCode: '000001',
          base: 0,
          rate: 0,
        ),
        ibsCbs: IbsCbsTax(
          cst: '000',
          classificationCode: '000001',
          base: 0,
          ibsUfRate: 0,
          ibsMunicipalRate: 0,
          cbsRate: 0,
        ),
      ),
    ],
  );
  final pfxBase64 = File(
    'test/fixtures/synthetic_a1.p12.b64',
  ).readAsStringSync().replaceAll(RegExp(r'\s'), '');
  final identity = PfxIdentity.fromPfx(
    bytes: base64Decode(pfxBase64),
    password: 'test-password',
  );
  final signed = await NfeEmissionService(
    signer: XmlSignatureService.fromPfx(identity),
  ).buildAndSign(document);
  await File(arguments[outputIndex + 1]).writeAsString(signed);
}
