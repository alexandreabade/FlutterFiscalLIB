import 'dart:convert';
import 'dart:io';

import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';

/// Gera uma NF-e assinada com IBS/CBS e Imposto Seletivo para validação XSD.
Future<void> main(List<String> arguments) async {
  final outputIndex = arguments.indexOf('--out');
  if (outputIndex < 0 || outputIndex + 1 >= arguments.length) {
    stderr.writeln(
      'Uso: dart run tool/validate_reform_example.dart --out arquivo.xml',
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
    deliveryForecast: DateTime.utc(2026, 1, 5),
    environment: 2,
    model: 55,
    operationNature: 'Venda com reforma tributária',
    documentType: 1,
    destinationType: 1,
    municipalityCode: '1100015',
    ibsMunicipalityCode: '3550308',
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
    payments: const [Payment(type: '01', value: 100)],
    items: [
      NfeItem(
        number: 1,
        code: 'RTC-001',
        description: 'Produto com IBS CBS e IS',
        ncm: '12345678',
        cfop: '5102',
        unit: 'UN',
        quantity: 1,
        unitPrice: 100,
        barcode: 'BARRA-001',
        taxableBarcode: 'BARRA-002',
        cest: '1234567',
        scaleIndicator: 'N',
        manufacturerCnpj: '04252011000110',
        recopiNumber: '12345678901234567890',
        fciNumber: '01234567-89AB-CDEF-0123-456789ABCDEF',
        usedMovableAsset: true,
        nffProduct: NffProductInfo(
          fiscalProductCode: '12345678901234',
          operationCode: '123',
        ),
        embeddedProduct: EmbeddedProductInfo(
          description: 'CAIXA',
          quantity: 12,
          unit: 'UN',
        ),
        icms: IcmsTax(cst: '00', base: 100, rate: 18, value: 18),
        ibsCbs: IbsCbsTax(
          cst: '000',
          classificationCode: '000001',
          base: 100,
          ibsUfRate: 1,
          ibsMunicipalRate: 0.5,
          cbsRate: 0.5,
          ibsUfDeferral: ReformDeferral(rate: 10, value: 0.1),
          ibsMunicipalReduction: ReformReduction(rate: 20, effectiveRate: 0.4),
          cbsRefund: ReformRefund(rate: 5, value: 0.02),
          creditReversal: ReformCreditReversal(ibsValue: 0.08, cbsValue: 0.09),
          regularTax: ReformRegularTax(
            cst: '000',
            classificationCode: '000001',
            ibsUfRate: 1,
            ibsUfValue: 1,
            ibsMunicipalRate: 0.5,
            ibsMunicipalValue: 0.5,
            cbsRate: 0.5,
            cbsValue: 0.5,
          ),
          governmentTax: ReformGovernmentTax(
            ibsUfRate: 1,
            ibsUfValue: 1,
            ibsMunicipalRate: 0.5,
            ibsMunicipalValue: 0.5,
            cbsRate: 0.5,
            cbsValue: 0.5,
          ),
          zfmCredit: ReformZfmCredit(
            competence: DateTime.utc(2026, 1),
            type: '2',
            value: 0.55,
          ),
        ),
        presumedCredits: [
          PresumedCredit(code: 'CRED1234', rate: 1.25, value: 0.13),
        ],
        zfmCreditType: '2',
        selectiveTax: SelectiveTax(
          cst: '000',
          classificationCode: '000001',
          base: 100,
          rate: 0.1,
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
