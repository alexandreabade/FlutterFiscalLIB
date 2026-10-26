import 'dart:convert';
import 'dart:io';

import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';

/// Gera NF-e com `veicProd` e `arma` em itens distintos.
/// A validação XSD é executada pelo `xmllint` no CI.
Future<void> main(List<String> arguments) async {
  final outputIndex = arguments.indexOf('--out');
  if (outputIndex < 0 || outputIndex + 1 >= arguments.length) {
    stderr.writeln(
      'Uso: dart run tool/validate_product_specials.dart --out arquivo.xml',
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
    number: 16,
    tpEmis: 1,
    cNf: '12345678',
  );
  final document = NfeDocument(
    accessKey: key.value,
    number: 16,
    series: 1,
    issueDate: issueDate,
    environment: 2,
    model: 55,
    operationNature: 'Venda de produtos especiais',
    documentType: 1,
    destinationType: 1,
    printFormat: 1,
    purpose: 1,
    finalConsumer: 0,
    presenceIndicator: 0,
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
      crt: '3',
    ),
    payments: const [Payment(type: '01', value: 51000)],
    items: const [
      NfeItem(
        number: 1,
        code: 'CARRO-001',
        description: 'Veículo novo de fixture',
        ncm: '87032100',
        cfop: '5102',
        unit: 'UN',
        quantity: 1,
        unitPrice: 50000,
        icms: IcmsTax(cst: '00', base: 50000, rate: 18, value: 9000),
        newVehicle: NewVehicleInfo(
          operationType: 1,
          chassis: '9BWZZZ377VT004251',
          colorCode: '001',
          colorDescription: 'BRANCA',
          power: '100',
          engineCapacity: '1600',
          netWeight: '1000',
          grossWeight: '1400',
          serialNumber: 'ABC123',
          fuelType: '01',
          engineNumber: 'MTR123',
          maxTractionCapacity: '2.0000',
          wheelbase: '2500',
          modelYear: 2026,
          manufactureYear: 2026,
          paintType: 'S',
          vehicleType: 6,
          vehicleSpecies: 1,
          vinStatus: 'N',
          vehicleCondition: 1,
          brandModelCode: 123456,
          denatranColorCode: 4,
          seatingCapacity: 5,
          restrictionType: 0,
        ),
      ),
      NfeItem(
        number: 2,
        code: 'ARMA-001',
        description: 'Armamento de fixture',
        ncm: '93020000',
        cfop: '5102',
        unit: 'UN',
        quantity: 1,
        unitPrice: 1000,
        icms: IcmsTax(cst: '00', base: 1000, rate: 18, value: 180),
        weapons: [
          WeaponInfo(
            type: 0,
            serialNumber: 'SER123',
            barrelNumber: 'CAN123',
            description: 'Pistola calibre 9mm',
          ),
        ],
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
