import 'dart:io';

import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';

Future<void> main(List<String> args) async {
  final output = args.isEmpty ? 'output/pdf/danfe-a4-example.pdf' : args.first;
  final document = NfeDocument.fromComponents(
    cUf: '11',
    cnpj: '04252011000110',
    cNf: '12345678',
    number: 42,
    series: 1,
    issueDate: DateTime.utc(2026, 1, 15, 14, 30),
    environment: 2,
    model: 55,
    issuer: const Party(
      name: 'Empresa Fiscal de Demonstração',
      cnpj: '04252011000110',
      address: 'Rua de Exemplo',
      addressNumber: '100',
      neighborhood: 'Centro',
      city: 'Porto Velho',
      state: 'RO',
      zipCode: '76801000',
    ),
    recipient: const Party(
      name: 'Cliente de Demonstração',
      cpf: '12345678909',
      address: 'Avenida Fiscal',
      addressNumber: '200',
      city: 'Porto Velho',
      state: 'RO',
    ),
    operationNature: 'Venda de mercadoria',
    items: const [
      NfeItem(
        number: 1,
        code: 'DEMO-001',
        description: 'Produto fiscal de demonstração',
        ncm: '12345678',
        cfop: '5102',
        unit: 'UN',
        quantity: 2,
        unitPrice: 25,
      ),
      NfeItem(
        number: 2,
        code: 'DEMO-002',
        description: 'Segundo produto para validar quebra de linha',
        ncm: '87654321',
        cfop: '5102',
        unit: 'UN',
        quantity: 1,
        unitPrice: 40,
      ),
    ],
    additionalInfo: const AdditionalInfo(
      complementary: 'Documento de demonstração sem validade fiscal.',
    ),
  );
  final bytes = await DanfePdfRenderer().render(document);
  final file = File(output);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
  stdout.writeln('DANFE PDF escrito em ${file.path}');
}
