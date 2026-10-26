import 'dart:convert';
import 'dart:io';

import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';

/// Gera NF-e com DI, adição e exportação individual para validação XSD.
Future<void> main(List<String> arguments) async {
  final outputIndex = arguments.indexOf('--out');
  if (outputIndex < 0 || outputIndex + 1 >= arguments.length) {
    stderr.writeln(
      'Uso: dart run tool/validate_trade_example.dart --out arquivo.xml',
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
    intermediaryIndicator: 1,
    intermediary: const IntermediaryInfo(
      cnpj: '04252011000110',
      identifier: 'MARKETPLACE-TRADE-001',
    ),
    advancePaymentReferences: [key.value],
    governmentPurchase: GovernmentPurchase(
      governmentEntityType: 2,
      reductionPercentage: 10,
      operationType: 3,
      previousDocumentReferences: [key.value],
    ),
    operationLocationCode: '110001',
    processCode: '0',
    applicationVersion: '0.1.0',
    references: [
      const ReferencedDocument.cte(
        '51121006145774000197570010000000131004100705',
      ),
    ],
    exportInfo: const ExportInfo(
      departureState: 'RO',
      exportLocation: 'Porto Velho',
      dispatchLocation: 'Aduana',
    ),
    purchaseInfo: const PurchaseInfo(
      commitmentNote: 'NE-001',
      order: 'PED-001',
      contract: 'CONT-001',
    ),
    sugarcane: const SugarcaneInfo(
      harvest: '2026/27',
      reference: '01/2026',
      dailySupplies: [SugarcaneDailySupply(day: 1, quantity: 100)],
      monthTotal: 100,
      previousTotal: 10,
      generalTotal: 110,
      supplyValue: 100,
      totalDeductions: 0,
      netSupplyValue: 100,
    ),
    transport: const TransportInfo(
      freightMode: 0,
      carrier: '04252011000110',
      carrierName: 'Transportadora Fiscal',
      carrierIe: '123456789',
      carrierAddress: 'Rodovia BR-1, 100',
      carrierCity: 'Porto Velho',
      retention: TransportTaxRetention(
        serviceValue: 100,
        taxBase: 100,
        rate: 12,
        taxValue: 12,
        cfop: '5353',
        municipalityCode: '1100015',
      ),
      vehiclePlate: 'ABC1D23',
      vehicleState: 'RO',
      vehicleRegistration: 'RNTC123',
      trailers: [TransportVehicle(plate: 'DEF2E34', state: 'RO')],
      volumes: [
        TransportVolume(
          quantity: 2,
          kind: 'CAIXA',
          brand: 'MARCA',
          number: '1-2',
          seal: ['LACRE1'],
        ),
      ],
    ),
    issuer: const Party(
      name: 'Empresa de Comércio Exterior',
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
      fantasyName: 'Comércio Fiscal',
      addressComplement: 'Bloco A',
      phone: '6933334444',
      ieSubstitute: '123456789',
      municipalRegistration: '12345',
      cnae: '4711301',
      suframa: '12345678',
    ),
    payments: const [Payment(type: '01', value: 100)],
    items: [
      NfeItem(
        number: 1,
        code: 'IMPORT-001',
        description: 'Produto importado',
        ncm: '12345678',
        cfop: '3102',
        unit: 'UN',
        quantity: 1,
        unitPrice: 100,
        icms: const IcmsTax(cst: '00', base: 100, rate: 18, value: 18),
        importDeclarations: [
          ImportDeclaration(
            number: 'DI123456',
            registrationDate: issueDate,
            customsLocation: 'Porto de Santos',
            customsState: 'SP',
            clearanceDate: issueDate,
            transportMode: 7,
            intermediaryType: 1,
            exporterCode: 'EXP001',
            additions: const [
              ImportAddition(
                number: 1,
                sequence: 1,
                manufacturerCode: 'FAB001',
              ),
            ],
          ),
        ],
        exportDetails: [
          ExportDetail(
            drawbackNumber: 'DRAW123',
            individualExports: [
              IndividualExport(
                registrationNumber: '123456789',
                receivedInvoiceKey: key.value,
                exportedQuantity: 1,
              ),
            ],
          ),
        ],
        traceability: [
          ProductTraceability(
            batchNumber: 'LOTE-IMPORT',
            quantity: 1,
            manufacturedAt: DateTime.utc(2025, 12, 1),
            expiresAt: DateTime.utc(2027, 12, 1),
          ),
        ],
        fuel: const FuelInfo(
          anpProductCode: '123456789',
          anpDescription: 'Combustível de teste',
          consumptionState: 'RO',
          biofuelPercentage: 12.5,
          origins: [
            FuelOrigin(imported: false, originState: '11', percentage: 87.5),
            FuelOrigin(imported: true, originState: '35', percentage: 12.5),
          ],
          cide: FuelCide(quantityBase: 1, rate: 0.1, value: 0.1),
          gauge: FuelGauge(
            nozzle: 1,
            tank: 3,
            initialReading: 100,
            finalReading: 101,
          ),
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
