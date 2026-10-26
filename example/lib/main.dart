import 'dart:io';

import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';

void main() {
  final issueDate = DateTime.utc(2026, 1, 1, 12);
  final issuer = const Party(
    name: 'Empresa de Demonstração',
    cnpj: '04252011000110',
    ie: '123456789',
    address: 'Rua Fiscal, 1',
    cityCode: '1100015',
    city: 'Alta Floresta D Oeste',
    state: 'RO',
    zipCode: '76954000',
    addressNumber: '1',
    neighborhood: 'Centro',
    crt: '1',
  );
  final document = NfeDocument(
    accessKey: AccessKey.fromComponents(
      cUf: '11',
      issueDate: issueDate,
      cnpj: issuer.cnpj!,
      model: 65,
      series: 1,
      number: 1,
      tpEmis: 1,
      cNf: '12345678',
    ).value,
    number: 1,
    series: 1,
    issueDate: issueDate,
    environment: 2,
    model: 65,
    issuer: issuer,
    operationNature: 'Venda de mercadoria',
    documentType: 1,
    destinationType: 1,
    printFormat: 4,
    purpose: 1,
    finalConsumer: 1,
    presenceIndicator: 1,
    processCode: '0',
    applicationVersion: '0.1.0',
    payments: const [Payment(type: '01', value: 10)],
    items: const [
      NfeItem(
        number: 1,
        code: 'DEMO-001',
        description: 'Produto de demonstração',
        ncm: '12345678',
        cfop: '5102',
        unit: 'UN',
        quantity: 1,
        unitPrice: 10,
        icms: IcmsTax(cst: '00', base: 10, rate: 18, value: 1.8),
      ),
    ],
  );
  stdout.writeln(Make().montaNFe(document));
}
