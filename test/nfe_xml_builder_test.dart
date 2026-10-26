import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

void main() {
  final accessKey = AccessKey.fromComponents(
    cUf: '11',
    issueDate: DateTime.utc(2026, 1, 1),
    cnpj: '04252011000110',
    model: 55,
    series: 1,
    number: 1,
    tpEmis: 1,
    cNf: '12345678',
  ).value;
  final accessKey65 = AccessKey.fromComponents(
    cUf: '11',
    issueDate: DateTime.utc(2026, 1, 1),
    cnpj: '04252011000110',
    model: 65,
    series: 1,
    number: 1,
    tpEmis: 1,
    cNf: '12345679',
  ).value;
  final contingencyKey = AccessKey.fromComponents(
    cUf: '11',
    issueDate: DateTime.utc(2026, 1, 1),
    cnpj: '04252011000110',
    model: 65,
    series: 1,
    number: 3,
    tpEmis: 9,
    cNf: '12345680',
  ).value;

  final issuer = const Party(
    name: 'Empresa de Teste',
    cnpj: '04252011000110',
    ie: '123456789',
    address: 'Rua Fiscal, 1',
    cityCode: '1100015',
    city: 'Alta Floresta D Oeste',
    state: 'RO',
    zipCode: '76954000',
  );

  test('gera XML com itens e total', () {
    final document = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      items: [
        NfeItem(
          number: 1,
          code: 'ABC',
          description: 'Produto de teste',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 2,
          unitPrice: 10,
        ),
      ],
    );

    final xml = NfeXmlBuilder().build(document);
    expect(xml, contains('<NFe'));
    expect(xml, contains('<xProd>Produto de teste</xProd>'));
    expect(xml, contains('<enderEmit>'));
    expect(xml, contains('<modFrete>9</modFrete>'));
    expect(xml, contains('<cEANTrib>SEM GTIN</cEANTrib>'));
    expect(xml, contains('<qTrib>2.0000</qTrib>'));
    expect(xml, contains('<indTot>1</indTot>'));
    expect(xml, contains('<cNF>12345678</cNF>'));
    expect(xml, contains('<cDV>${accessKey.substring(43)}</cDV>'));
    expect(xml, contains('<dhEmi>2026-01-01T00:00:00+00:00</dhEmi>'));
    expect(xml, contains('<vICMSDeson>0.00</vICMSDeson>'));
    expect(xml, contains('<vFCPSTRet>0.00</vFCPSTRet>'));
    expect(xml, contains('<vNF>20.00</vNF>'));
    expect(xml, isNot(contains('<CPF/>')));
    expect(NfeXmlValidator().validate(xml).isValid, isTrue);
  });

  test('emite data de saída ou entrada quando informada', () {
    final document = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1, 10),
      departureDate: DateTime.utc(2026, 1, 1, 12, 30),
      environment: 2,
      model: 55,
      issuer: issuer,
      items: [
        NfeItem(
          number: 1,
          code: 'A',
          description: 'Produto',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 1,
        ),
      ],
    );

    final xml = NfeXmlBuilder().build(document);
    expect(xml, contains('<dhSaiEnt>2026-01-01T12:30:00+00:00</dhSaiEnt>'));
  });

  test('emite tipos oficiais de nota de débito e crédito', () {
    const item = NfeItem(
      number: 1,
      code: 'A',
      description: 'Produto',
      ncm: '12345678',
      cfop: '5102',
      unit: 'UN',
      quantity: 1,
      unitPrice: 1,
    );
    final debit = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      purpose: 6,
      debitNoteType: '01',
      items: const [item],
    );
    final credit = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      purpose: 5,
      creditNoteType: '02',
      items: const [item],
    );
    final invalidDebit = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      purpose: 6,
      debitNoteType: '09',
      items: const [item],
    );

    expect(
      NfeXmlBuilder().build(debit),
      contains('<tpNFDebito>01</tpNFDebito>'),
    );
    expect(
      NfeXmlBuilder().build(credit),
      contains('<tpNFCredito>02</tpNFCredito>'),
    );
    expect(
      () => NfeXmlBuilder().build(invalidDebit),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'INVALID_DEBIT_NOTE_TYPE',
        ),
      ),
    );
  });

  test('emite previsão de entrega e município fiscal de IBS/CBS', () {
    final document = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1, 10),
      deliveryForecast: DateTime.utc(2026, 1, 5),
      environment: 2,
      model: 55,
      issuer: issuer,
      documentType: 1,
      destinationType: 1,
      municipalityCode: '1100015',
      ibsMunicipalityCode: '3550308',
      items: const [
        NfeItem(
          number: 1,
          code: 'A',
          description: 'Produto',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 1,
        ),
      ],
    );

    final xml = NfeXmlBuilder().build(document);
    expect(xml, contains('<dPrevEntrega>2026-01-05</dPrevEntrega>'));
    expect(xml, contains('<cMunFGIBS>3550308</cMunFGIBS>'));
  });

  test('rejeita município fiscal de IBS/CBS inválido', () {
    final document = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      ibsMunicipalityCode: '123',
      items: const [
        NfeItem(
          number: 1,
          code: 'A',
          description: 'Produto',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 1,
        ),
      ],
    );

    expect(
      () => NfeXmlBuilder().build(document),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'INVALID_IBS_MUNICIPALITY_CODE',
        ),
      ),
    );
  });

  test('rejeita código numérico igual ao número do documento', () {
    expect(
      () => AccessKey.fromComponents(
        cUf: '11',
        issueDate: DateTime.utc(2026, 1, 1),
        cnpj: '04252011000110',
        model: 55,
        series: 1,
        number: 123,
        tpEmis: 1,
        cNf: '00000123',
      ),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'INVALID_ACCESS_KEY_NUMERIC_CODE',
        ),
      ),
    );
  });

  test('mantém chave e dhEmi coerentes ao normalizar data com offset', () {
    final issueDate = DateTime.parse('2026-02-01T00:30:00-03:00');
    final document = NfeDocument.fromComponents(
      cUf: '11',
      cnpj: '04252011000110',
      cNf: '12345678',
      number: 8,
      series: 1,
      issueDate: issueDate,
      environment: 2,
      model: 55,
      issuer: issuer,
      items: const [
        NfeItem(
          number: 1,
          code: 'A',
          description: 'Produto',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 1,
        ),
      ],
    );

    final xml = NfeXmlBuilder().build(document);

    expect(document.accessKey.substring(2, 6), '2602');
    expect(xml, contains('<dhEmi>2026-02-01T03:30:00+00:00</dhEmi>'));
    expect(xml, contains('<cDV>${document.accessKey.substring(43)}</cDV>'));
  });

  test('emite metadados comerciais opcionais do produto', () {
    final document = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      items: [
        NfeItem(
          number: 1,
          code: 'ABC',
          description: 'Produto de teste',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 10,
          barcode: 'BARRA-001',
          taxableBarcode: 'BARRA-002',
          nve: const ['123456'],
          cest: '1234567',
          scaleIndicator: 'N',
          manufacturerCnpj: '04252011000110',
          recopiNumber: '12345678901234567890',
          benefitCode: 'RO123456',
          presumedCredits: [
            PresumedCredit(code: 'CRED1234', rate: 1.25, value: 0.13),
          ],
          zfmCreditType: '2',
          extipi: '001',
          orderNumber: 'PED-1',
          orderItem: 1,
          fciNumber: '01234567-89AB-CDEF-0123-456789ABCDEF',
          additionalInformation: 'Informação do item',
          importDeclarations: [
            ImportDeclaration(
              number: 'DI123',
              registrationDate: DateTime.utc(2026, 1, 1),
              customsLocation: 'Porto de Santos',
              customsState: 'SP',
              clearanceDate: DateTime.utc(2026, 1, 2),
              transportMode: 7,
              intermediaryType: 1,
              exporterCode: 'EXP001',
              additions: const [
                ImportAddition(
                  number: 1,
                  sequence: 1,
                  manufacturerCode: 'FAB001',
                  discount: 0.5,
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
                  receivedInvoiceKey: accessKey,
                  exportedQuantity: 1,
                ),
              ],
            ),
          ],
          traceability: [
            ProductTraceability(
              batchNumber: 'LOTE-1',
              quantity: 1,
              manufacturedAt: DateTime.utc(2025, 12, 1),
              expiresAt: DateTime.utc(2027, 12, 1),
              aggregatedCode: '12345',
            ),
          ],
          medication: const MedicationInfo(
            anvisaProductCode: '12345678901',
            exemptionReason: null,
            maximumConsumerPrice: 12.5,
          ),
        ),
        NfeItem(
          number: 2,
          code: 'FUEL',
          description: 'Combustível de teste',
          ncm: '12345678',
          cfop: '5102',
          unit: 'L',
          quantity: 1,
          unitPrice: 10,
          fuel: const FuelInfo(
            anpProductCode: '123456789',
            anpDescription: 'Combustível de teste',
            consumptionState: 'RO',
            biofuelPercentage: 12.5,
            origins: [
              FuelOrigin(imported: false, originState: '11', percentage: 87.5),
            ],
            cide: FuelCide(quantityBase: 1, rate: 0.1, value: 0.1),
            gauge: FuelGauge(
              nozzle: 1,
              pump: 2,
              tank: 3,
              initialReading: 100,
              finalReading: 101,
            ),
          ),
        ),
      ],
    );

    final xml = NfeXmlBuilder().build(document);
    expect(xml, contains('<NVE>123456</NVE>'));
    expect(xml, contains('<nFCI>01234567-89AB-CDEF-0123-456789ABCDEF</nFCI>'));
    expect(xml, contains('<CEST>1234567</CEST>'));
    expect(xml, contains('<cBenef>RO123456</cBenef>'));
    expect(xml, contains('<cBarra>BARRA-001</cBarra>'));
    expect(xml, contains('<cBarraTrib>BARRA-002</cBarraTrib>'));
    expect(xml, contains('<indEscala>N</indEscala>'));
    expect(xml, contains('<CNPJFab>04252011000110</CNPJFab>'));
    expect(xml, contains('<nRECOPI>12345678901234567890</nRECOPI>'));
    expect(xml, contains('<cCredPresumido>CRED1234</cCredPresumido>'));
    expect(xml, contains('<pCredPresumido>1.2500</pCredPresumido>'));
    expect(xml, contains('<tpCredPresIBSZFM>2</tpCredPresIBSZFM>'));
    expect(xml, contains('<EXTIPI>001</EXTIPI>'));
    expect(xml, contains('<xPed>PED-1</xPed>'));
    expect(xml, contains('<nItemPed>1</nItemPed>'));
    expect(xml, contains('<infAdProd>Informação do item</infAdProd>'));
    expect(xml, contains('<nDI>DI123</nDI>'));
    expect(xml, contains('<dDI>2026-01-01</dDI>'));
    expect(xml, contains('<adi>'));
    expect(xml, contains('<cFabricante>FAB001</cFabricante>'));
    expect(xml, contains('<detExport>'));
    expect(xml, contains('<exportInd>'));
    expect(xml, contains('<qExport>1.0000</qExport>'));
    expect(xml, contains('<rastro>'));
    expect(xml, contains('<nLote>LOTE-1</nLote>'));
    expect(xml, contains('<qLote>1.000</qLote>'));
    expect(xml, contains('<med>'));
    expect(xml, contains('<cProdANVISA>12345678901</cProdANVISA>'));
    expect(xml, contains('<comb>'));
    expect(xml, contains('<cProdANP>123456789</cProdANP>'));
    expect(xml, contains('<CIDE>'));
    expect(xml, contains('<encerrante>'));
    expect(xml, contains('<pBio>12.5000</pBio>'));
    expect(xml, contains('<origComb>'));
    expect(xml, contains('<indImport>0</indImport>'));
    expect(xml, contains('<cUFOrig>11</cUFOrig>'));
  });

  test('expõe tags de endereço compatíveis com Make do NFePHP', () {
    const party = Party(
      name: 'Participante',
      cnpj: '04252011000110',
      address: 'Rua Fiscal',
      addressNumber: '10',
      addressComplement: 'Sala 2',
      phone: '69999999999',
    );
    final make = Make();
    expect(make.tagenderEmit(party).name.local, 'enderEmit');
    expect(
      make.tagenderEmit(party).getElement('xCpl')?.children.single.value,
      'Sala 2',
    );
    expect(make.tagenderDest(party).name.local, 'enderDest');
  });

  test('emite campos de produto PL_010f para bem usado e NFF', () {
    final document = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      items: [
        NfeItem(
          number: 1,
          code: 'NFF-1',
          description: 'Produto NFF',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 10,
          usedMovableAsset: true,
          nffProduct: const NffProductInfo(
            fiscalProductCode: '12345678901234',
            operationCode: '123',
          ),
          embeddedProduct: const EmbeddedProductInfo(
            description: 'CAIXA',
            quantity: 12,
            unit: 'UN',
          ),
        ),
      ],
    );

    final xml = NfeXmlBuilder().build(document);
    expect(xml, contains('<indBemMovelUsado>1</indBemMovelUsado>'));
    expect(xml, contains('<cProdFisco>12345678901234</cProdFisco>'));
    expect(xml, contains('<cOperNFF>123</cOperNFF>'));
    expect(xml, contains('<qVolEmb>12.000</qVolEmb>'));
  });

  test('rejeita informações NFF fora dos limites do PL_010f', () {
    final document = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      items: [
        NfeItem(
          number: 1,
          code: 'NFF-1',
          description: 'Produto NFF',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 10,
          nffProduct: const NffProductInfo(
            fiscalProductCode: '123',
            operationCode: '123456',
          ),
        ),
      ],
    );

    expect(
      () => NfeXmlBuilder().build(document),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'INVALID_NFF_PRODUCT_INFO',
        ),
      ),
    );
  });

  test('fábrica do documento calcula a chave a partir dos componentes', () {
    final document = NfeDocument.fromComponents(
      cUf: '11',
      cnpj: '04252011000110',
      cNf: '12345678',
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      items: [
        NfeItem(
          number: 1,
          code: 'ABC',
          description: 'Produto',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 5,
        ),
      ],
    );

    expect(document.accessKey, accessKey);
    expect(NfeXmlBuilder().build(document), contains('<cNF>12345678</cNF>'));
  });

  test('calcula chave e valida emitente identificado por CPF', () {
    const cpf = '52998224725';
    final document = NfeDocument.fromComponents(
      cUf: '11',
      cnpj: cpf,
      cNf: '12345678',
      number: 2,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: const Party(name: 'Emitente CPF', cpf: cpf),
      items: const [
        NfeItem(
          number: 1,
          code: 'CPF-1',
          description: 'Produto do emitente CPF',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 5,
        ),
      ],
    );

    expect(document.accessKey.substring(6, 20), '000$cpf');
    expect(NfeXmlBuilder().build(document), contains('<CPF>$cpf</CPF>'));
  });

  test('emite veículo novo e armamentos em grupos especiais do produto', () {
    final document = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      items: [
        NfeItem(
          number: 1,
          code: 'CARRO',
          description: 'Veículo novo',
          ncm: '87032100',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 50000,
          newVehicle: const NewVehicleInfo(
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
          code: 'ARMA',
          description: 'Armamento',
          ncm: '93020000',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 1000,
          weapons: const [
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

    final xml = NfeXmlBuilder().build(document);
    expect(xml, contains('<veicProd>'));
    expect(xml, contains('<chassi>9BWZZZ377VT004251</chassi>'));
    expect(xml, contains('<arma>'));
    expect(xml, contains('<nCano>CAN123</nCano>'));
  });

  test('rejeita mais de um grupo especial no mesmo item', () {
    final document = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      items: [
        NfeItem(
          number: 1,
          code: 'CONFLITO',
          description: 'Produto inválido',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 1,
          medication: const MedicationInfo(
            anvisaProductCode: '12345678901',
            maximumConsumerPrice: 1,
          ),
          fuel: const FuelInfo(
            anpProductCode: '123456789',
            anpDescription: 'Combustível',
            consumptionState: 'RO',
          ),
        ),
      ],
    );

    expect(
      () => NfeXmlBuilder().build(document),
      throwsA(
        isA<FiscalValidationException>().having(
          (exception) => exception.code,
          'code',
          'CONFLICTING_PRODUCT_SPECIAL_GROUPS',
        ),
      ),
    );
  });

  test('emite exportação, compra e aquisição de cana na ordem do leiaute', () {
    final document = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      exportInfo: const ExportInfo(
        departureState: 'RO',
        exportLocation: 'Porto Velho',
        dispatchLocation: 'Aduana',
      ),
      purchaseInfo: const PurchaseInfo(
        commitmentNote: 'NE-1',
        order: 'PED-1',
        contract: 'CONT-1',
      ),
      sugarcane: const SugarcaneInfo(
        harvest: '2026/27',
        reference: '01/2026',
        dailySupplies: [SugarcaneDailySupply(day: 1, quantity: 100)],
        monthTotal: 100,
        previousTotal: 10,
        generalTotal: 110,
        deductions: [SugarcaneDeduction(description: 'Taxa', value: 1)],
        supplyValue: 100,
        totalDeductions: 1,
        netSupplyValue: 99,
      ),
      items: [
        NfeItem(
          number: 1,
          code: 'CANA',
          description: 'Cana-de-açúcar',
          ncm: '12129300',
          cfop: '1101',
          unit: 'KG',
          quantity: 1,
          unitPrice: 100,
        ),
      ],
    );

    final xml = NfeXmlBuilder().build(document);
    expect(xml, contains('<exporta>'));
    expect(xml, contains('<compra>'));
    expect(xml, contains('<cana>'));
    expect(xml, contains('dia="1"'));
    expect(xml.indexOf('<exporta>'), lessThan(xml.indexOf('<compra>')));
    expect(xml.indexOf('<compra>'), lessThan(xml.indexOf('<cana>')));
  });

  test('fábrica deriva tpEmis 9 para contingência NFC-e', () {
    final document = NfeDocument.fromComponents(
      cUf: '11',
      cnpj: '04252011000110',
      cNf: '12345680',
      number: 3,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 65,
      issuer: issuer,
      contingency: Contingency(
        mode: ContingencyMode.offlineNfce,
        activatedAt: DateTime.utc(2026, 1, 1),
        reason: 'Indisponibilidade temporária do autorizador',
      ),
      items: const [
        NfeItem(
          number: 1,
          code: 'ABC',
          description: 'Produto offline',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 5,
        ),
      ],
    );

    expect(AccessKey.emissionTypeOf(document.accessKey), 9);
    final xml = NfeXmlBuilder().build(document);
    expect(xml, contains('<tpEmis>9</tpEmis>'));
    expect(NfeXmlValidator().validate(xml).isValid, isTrue);
  });

  test('totaliza rateios de frete, seguro, desconto e despesas', () {
    final document = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      items: const [
        NfeItem(
          number: 1,
          code: 'ABC',
          description: 'Produto com rateios',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 100,
          freight: 2,
          insurance: 1,
          discount: 3,
          other: 4,
          importDuty: 5,
        ),
      ],
    );

    final xml = NfeXmlBuilder().build(document);
    expect(xml, contains('<vProd>100.00</vProd>'));
    expect(xml, contains('<vFrete>2.00</vFrete>'));
    expect(xml, contains('<vSeg>1.00</vSeg>'));
    expect(xml, contains('<vDesc>3.00</vDesc>'));
    expect(xml, contains('<vII>5.00</vII>'));
    expect(xml, contains('<vOutro>4.00</vOutro>'));
    expect(xml, contains('<vNF>109.00</vNF>'));
  });

  test('rejeita chave inválida', () {
    final document = NfeDocument(
      accessKey: '1',
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026),
      environment: 2,
      model: 65,
      issuer: issuer,
      items: [
        NfeItem(
          number: 1,
          code: 'STRICT-001',
          description: 'Produto estrito',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 10,
        ),
      ],
    );

    expect(
      () => NfeXmlBuilder().build(document),
      throwsA(isA<FiscalValidationException>()),
    );
  });

  test('rejeita documento cujo modelo diverge da chave', () {
    final document = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 65,
      issuer: issuer,
      items: const [
        NfeItem(
          number: 1,
          code: 'ABC',
          description: 'Produto',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 5,
        ),
      ],
    );

    expect(
      () => NfeXmlBuilder().build(document),
      throwsA(isA<FiscalValidationException>()),
    );
  });

  test('rejeita número divergente da chave de acesso', () {
    final document = NfeDocument(
      accessKey: accessKey,
      number: 2,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      items: const [
        NfeItem(
          number: 1,
          code: 'ABC',
          description: 'Produto',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 5,
        ),
      ],
    );

    expect(
      () => NfeXmlBuilder().build(document),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'ACCESS_KEY_NUMBER_MISMATCH',
        ),
      ),
    );
  });

  test('rejeita contingência offline em NF-e modelo 55', () {
    final document = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      contingency: Contingency(
        mode: ContingencyMode.offlineNfce,
        activatedAt: DateTime.utc(2026, 1, 1),
        reason: 'Indisponibilidade temporária do autorizador',
      ),
      items: const [
        NfeItem(
          number: 1,
          code: 'ABC',
          description: 'Produto',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 5,
        ),
      ],
    );

    expect(
      () => NfeXmlBuilder().build(document),
      throwsA(isA<FiscalValidationException>()),
    );
  });

  test('rejeita FS/SVC em NFC-e modelo 65', () {
    final document = NfeDocument(
      accessKey: AccessKey.fromComponents(
        cUf: '11',
        issueDate: DateTime.utc(2026, 1, 1),
        cnpj: '04252011000110',
        model: 65,
        series: 1,
        number: 1,
        tpEmis: 6,
        cNf: '12345678',
      ).value,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 65,
      issuer: issuer,
      contingency: Contingency(
        mode: ContingencyMode.svcAn,
        activatedAt: DateTime.utc(2026, 1, 1),
        reason: 'Indisponibilidade temporária do autorizador',
      ),
      items: const [
        NfeItem(
          number: 1,
          code: 'ABC',
          description: 'Produto',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 5,
        ),
      ],
    );

    expect(
      () => NfeXmlBuilder().build(document),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'NFCE_CONTINGENCY_MODE_MISMATCH',
        ),
      ),
    );
  });

  test('calcula e valida o dígito da chave de acesso', () {
    expect(accessKey, hasLength(44));
    expect(AccessKey.isValid(accessKey), isTrue);
    expect(AccessKey.isValid('${accessKey.substring(0, 43)}0'), isFalse);
  });

  test('fachada Make delega a montagem do XML', () {
    final document = NfeDocument(
      accessKey: accessKey65,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 65,
      issuer: issuer,
      payments: const [Payment(type: '01', value: 5)],
      items: const [
        NfeItem(
          number: 1,
          code: 'ABC',
          description: 'Produto',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 5,
        ),
      ],
    );

    expect(Make().montaNFe(document), contains('<mod>65</mod>'));
    expect(Make().montaNFe(document), contains('<tPag>01</tPag>'));
  });

  test('Make expõe grupos tipados compatíveis com tagide e tagprod', () {
    const item = NfeItem(
      number: 1,
      code: 'ABC',
      description: 'Produto',
      ncm: '12345678',
      cfop: '5102',
      unit: 'UN',
      quantity: 1,
      unitPrice: 5,
      icms: IcmsTax(cst: '00', base: 5, rate: 18, value: 0.9),
      icmsPart: IcmsPartTax(
        cst: '10',
        base: 5,
        rate: 18,
        value: 0.9,
        stBase: 6,
        stRate: 18,
        stValue: 1.08,
        operationRate: 100,
        destinationState: 'SP',
      ),
      icmsUfDestination: IcmsUfDestinationTax(
        base: 5,
        destinationRate: 18,
        interstateRate: 12,
        partitionRate: 100,
        destinationValue: 0.3,
        originValue: 0,
      ),
      importTax: ImportTax(base: 10, customsExpenses: 1, value: 2, iof: 0.1),
      pisSt: PisStTax(base: 5, rate: 1.65, value: 0.08),
      cofinsSt: CofinsStTax(base: 5, rate: 7.6, value: 0.38),
      ipiDevolution: IpiDevolution(percentage: 50, value: 0.5),
    );
    final make = Make();
    final document = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      taxRetention: const TaxRetention(
        pis: 0.1,
        cofins: 0.2,
        csll: 0.3,
        irrfBase: 5,
        irrf: 0.4,
        socialSecurityBase: 5,
        socialSecurity: 0.5,
      ),
      withdrawal: const NfeLocation(
        cnpj: '04252011000110',
        street: 'Rua da Retirada',
        number: '10',
        neighborhood: 'Centro',
        municipalityCode: '1100015',
        municipality: 'Porto Velho',
        state: 'RO',
      ),
      delivery: const NfeLocation(
        cpf: '52998224725',
        street: 'Rua da Entrega',
        number: '20',
        neighborhood: 'Centro',
        municipalityCode: '1100015',
        municipality: 'Porto Velho',
        state: 'RO',
      ),
      additionalInfo: const AdditionalInfo(
        complementary: 'Complemento',
        contributorObservations: [
          AdditionalObservation(field: 'pedido', text: 'PED-1'),
        ],
        fiscalObservations: [
          AdditionalObservation(field: 'fisco', text: 'FISCAL-1'),
        ],
        referencedProcesses: [
          ReferencedProcess(number: 'PROC-1', indicator: '0'),
        ],
        authorizedXml: [AuthorizedXmlDownload(cnpj: '04252011000110')],
      ),
      items: const [item],
    );
    final ide = make.tagide(document);

    expect(ide.localName, 'ide');
    expect(make.tagICMSTot(document).localName, 'ICMSTot');
    expect(
      make.tagnFCI('01234567-89AB-CDEF-0123-456789ABCDEF').localName,
      'nFCI',
    );
    expect(
      make.tagdetPag(const Payment(type: '01', value: 5)).localName,
      'detPag',
    );
    expect(
      make
          .tagfat(const BillingInfo(invoiceNumber: 'F1', originalValue: 5))
          .localName,
      'fat',
    );
    expect(
      make
          .tagdup(
            InvoiceInstallment(
              number: 'D1',
              dueDate: DateTime.utc(2026, 2, 1),
              value: 5,
            ),
          )
          .localName,
      'dup',
    );
    final serviceDocument = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      items: [
        NfeItem(
          number: 1,
          code: 'SERV',
          description: 'Serviço',
          ncm: '12345678',
          cfop: '5933',
          unit: 'UN',
          quantity: 1,
          unitPrice: 5,
          serviceTax: ServiceTax(
            base: 5,
            rate: 2,
            value: 0.1,
            municipalityCode: '1100015',
            serviceListCode: '01.01',
            competenceDate: DateTime.utc(2026, 1, 1),
          ),
        ),
      ],
    );
    expect(make.tagISSQNTot(serviceDocument).localName, 'ISSQNtot');
    expect(
      make.tagrefNFe(ReferencedDocument.nfe(accessKey65)).localName,
      'NFref',
    );
    expect(
      make.tagrefNFeSig(const ReferencedDocument.nfeSig('SIG-1')).localName,
      'NFref',
    );
    expect(
      make
          .tagrefCTe(
            const ReferencedDocument.cte(
              '51121006145774000197570010000000131004100705',
            ),
          )
          .localName,
      'NFref',
    );
    expect(
      make
          .tagrefNF(
            const ReferencedDocument.legacy(
              cUf: '11',
              yearMonth: '2601',
              cnpj: '04252011000110',
              model: 1,
              series: 1,
              number: 1,
            ),
          )
          .localName,
      'NFref',
    );
    expect(
      make
          .tagrefNFP(
            const ReferencedDocument.nfp(
              cUf: '11',
              yearMonth: '2601',
              cpf: '52998224725',
              producerIe: 'ISENTO',
              model: 4,
              series: 1,
              number: 1,
            ),
          )
          .localName,
      'NFref',
    );
    final ecfReference = make.tagrefECF(
      const ReferencedDocument.ecf(ecfModel: '2B', ecfNumber: 1, cooNumber: 2),
    );
    expect(ecfReference.localName, 'NFref');
    expect(
      ecfReference
          .findAllElements('refECF')
          .single
          .getElement('mod')!
          .innerText,
      '2B',
    );
    expect(ecfReference.findAllElements('nECF').single.innerText, '001');
    expect(ecfReference.findAllElements('nCOO').single.innerText, '000002');
    final infNfe = make.taginfNFe(
      NfeDocument(
        accessKey: accessKey,
        number: 1,
        series: 1,
        issueDate: DateTime.utc(2026, 1, 1),
        environment: 2,
        model: 55,
        issuer: issuer,
        items: const [item],
      ),
    );
    expect(infNfe.localName, 'infNFe');
    expect(infNfe.getAttribute('Id'), 'NFe$accessKey');
    expect(infNfe.getAttribute('versao'), '4.00');
    expect(infNfe.childElements, isEmpty);
    expect(make.tagemit(issuer).localName, 'emit');
    expect(make.tagdest(issuer).localName, 'dest');
    expect(make.monta(document), contains('<NFe'));
    expect(make.getXML(document), contains('<NFe'));
    expect(make.getChave(document), document.accessKey);
    expect(make.getModelo(document), document.model);
    expect(make.tagdet(item).localName, 'det');
    expect(make.tagretirada(document.withdrawal!).localName, 'retirada');
    expect(make.tagentrega(document.delivery!).localName, 'entrega');
    expect(make.tagprod(item).localName, 'prod');
    expect(
      make
          .tagRECOPI(
            const NfeItem(
              number: 1,
              code: 'RECOPI',
              description: 'Produto',
              ncm: '12345678',
              cfop: '5102',
              unit: 'UN',
              quantity: 1,
              unitPrice: 1,
              recopiNumber: '12345678901234567890',
            ),
          )
          .innerText,
      '12345678901234567890',
    );
    final configuredMake = Make()..setOnlyAscii();
    expect(configuredMake.build(document), contains('<mod>55</mod>'));
    expect(configuredMake.getErrors(), isEmpty);
    expect(make.tagimposto(item).localName, 'imposto');
    expect(make.tagimposto(item).findAllElements('ICMSPart'), hasLength(1));
    expect(make.tagimposto(item).findAllElements('ICMSUFDest'), hasLength(1));
    expect(make.tagimposto(item).findAllElements('II'), hasLength(1));
    expect(make.tagimposto(item).findAllElements('PISST'), hasLength(1));
    expect(make.tagimposto(item).findAllElements('COFINSST'), hasLength(1));
    expect(make.tagdet(item).findAllElements('impostoDevol'), hasLength(1));
    expect(make.tagICMS(item.icms!).localName, 'ICMS');
    expect(
      make
          .tagimpostoDevol(const IpiDevolution(percentage: 50, value: 0.5))
          .localName,
      'impostoDevol',
    );
    expect(make.tagretTrib(const TaxRetention(pis: 0.1)).localName, 'retTrib');
    expect(
      make
          .tagICMSST(
            const IcmsStTax(
              base: 5,
              rate: 18,
              value: 0.9,
              stBase: 6,
              stRate: 18,
              stValue: 1.08,
            ),
          )
          .localName,
      'ICMS',
    );
    expect(
      make
          .tagICMSPart(
            const IcmsPartTax(
              cst: '10',
              base: 5,
              rate: 18,
              value: 0.9,
              stBase: 6,
              stRate: 18,
              stValue: 1.08,
              operationRate: 100,
              destinationState: 'SP',
            ),
          )
          .localName,
      'ICMS',
    );
    expect(
      make
          .tagICMSUFDest(
            const IcmsUfDestinationTax(
              base: 5,
              destinationRate: 18,
              interstateRate: 12,
              partitionRate: 100,
              destinationValue: 0.3,
              originValue: 0,
            ),
          )
          .localName,
      'ICMSUFDest',
    );
    expect(
      make
          .tagICMSSN(
            const IcmsSimplesTax(
              csosn: '101',
              creditRate: 1,
              creditValue: 0.05,
            ),
          )
          .localName,
      'ICMS',
    );
    expect(
      make
          .tagICMSMono(
            const IcmsMonophaseTax(
              cst: '02',
              quantity: 1,
              rate: 1,
              value: 0.01,
            ),
          )
          .localName,
      'ICMS',
    );
    expect(
      make
          .tagIPI(
            const IpiTax(
              enquadramento: '999',
              cst: '50',
              base: 5,
              rate: 5,
              value: 0.25,
            ),
          )
          .localName,
      'IPI',
    );
    expect(
      make
          .tagII(
            const ImportTax(base: 10, customsExpenses: 1, value: 2, iof: 0.1),
          )
          .localName,
      'II',
    );
    expect(
      make
          .tagPIS(const PisTax(cst: '01', base: 5, rate: 1, value: 0.05))
          .localName,
      'PIS',
    );
    expect(
      make
          .tagCOFINS(const CofinsTax(cst: '01', base: 5, rate: 1, value: 0.05))
          .localName,
      'COFINS',
    );
    expect(
      make.tagPISST(const PisStTax(base: 5, rate: 1.65, value: 0.08)).localName,
      'PISST',
    );
    expect(
      make
          .tagCOFINSST(const CofinsStTax(base: 5, rate: 7.6, value: 0.38))
          .localName,
      'COFINSST',
    );
    expect(
      make
          .tagISSQN(
            ServiceTax(
              base: 5,
              rate: 2,
              value: 0.1,
              municipalityCode: '1100015',
              serviceListCode: '01.01',
              competenceDate: DateTime.utc(2026, 1, 1),
            ),
          )
          .localName,
      'ISSQN',
    );
    expect(
      make
          .tagRastro(
            ProductTraceability(
              batchNumber: 'LOTE-1',
              quantity: 1,
              manufacturedAt: DateTime.utc(2026, 1, 1),
              expiresAt: DateTime.utc(2027, 1, 1),
            ),
          )
          .localName,
      'rastro',
    );
    expect(
      make
          .tagmed(
            const MedicationInfo(
              anvisaProductCode: '12345678901',
              maximumConsumerPrice: 10,
            ),
          )
          .localName,
      'med',
    );
    expect(
      make
          .tagcomb(
            const FuelInfo(
              anpProductCode: '123456789',
              anpDescription: 'Combustível',
              consumptionState: 'RO',
            ),
          )
          .localName,
      'comb',
    );
    expect(
      make
          .tagencerrante(
            const FuelGauge(
              nozzle: 1,
              tank: 2,
              initialReading: 10,
              finalReading: 12,
            ),
          )
          .localName,
      'encerrante',
    );
    expect(make.tagtotal(document).localName, 'total');
    expect(make.tagpag(document).localName, 'pag');
    expect(make.tagtransp(document).localName, 'transp');
    expect(
      make
          .tagtransporta(
            const TransportInfo(
              carrier: '04252011000110',
              carrierName: 'Transportadora',
            ),
          )
          .localName,
      'transporta',
    );
    expect(
      make
          .tagretTransp(
            const TransportTaxRetention(
              serviceValue: 10,
              taxBase: 10,
              rate: 12,
              taxValue: 1.2,
              cfop: '5353',
              municipalityCode: '1100015',
            ),
          )
          .localName,
      'retTransp',
    );
    expect(make.taglacres('LACRE-1').localName, 'lacres');
    expect(
      make
          .tagveicTransp(const TransportVehicle(plate: 'ABC1D23', state: 'RO'))
          .localName,
      'veicTransp',
    );
    expect(
      make.tagreboque(const TransportVehicle(plate: 'DEF2E34')).localName,
      'reboque',
    );
    expect(
      make.tagvol(const TransportVolume(quantity: 1, kind: 'CAIXA')).localName,
      'vol',
    );
    expect(make.taginfAdic(document).localName, 'infAdic');
    expect(make.taginfAdic(document).findAllElements('obsCont'), hasLength(1));
    expect(make.taginfAdic(document).findAllElements('obsFisco'), hasLength(1));
    expect(make.taginfAdic(document).findAllElements('procRef'), hasLength(1));
    expect(
      make.tagautXML(const AuthorizedXmlDownload(cpf: '52998224725')).localName,
      'autXML',
    );
    expect(
      make
          .tagcobr(const BillingInfo(invoiceNumber: '1', originalValue: 1))
          .localName,
      'cobr',
    );
    expect(
      make
          .taginfRespTec(
            const TechnicalResponsible(
              cnpj: '04252011000110',
              contact: 'Contato',
              email: 'contato@example.test',
              phone: '69999999999',
            ),
          )
          .localName,
      'infRespTec',
    );
    expect(
      make
          .tagexporta(
            const ExportInfo(
              departureState: 'RO',
              exportLocation: 'Porto Velho',
            ),
          )
          .localName,
      'exporta',
    );
    expect(
      make.tagcompra(const PurchaseInfo(order: 'PED-1')).localName,
      'compra',
    );
    expect(
      make
          .tagcana(
            const SugarcaneInfo(
              harvest: '2026',
              reference: '01/2026',
              dailySupplies: [],
              monthTotal: 1,
              previousTotal: 0,
              generalTotal: 1,
              supplyValue: 1,
              totalDeductions: 0,
              netSupplyValue: 1,
            ),
          )
          .localName,
      'cana',
    );
    expect(
      make.tagforDia(const SugarcaneDailySupply(day: 1, quantity: 2)).localName,
      'forDia',
    );
    expect(
      make
          .tagdeduc(const SugarcaneDeduction(description: 'Taxa', value: 1))
          .localName,
      'deduc',
    );
    expect(
      make
          .taginfNFeSupl(
            const NfceXmlSupplement(
              qrCode: 'https://example.test/qrcode',
              keyUrl: 'https://example.test/key',
            ),
          )
          .localName,
      'infNFeSupl',
    );

    const addition = ImportAddition(
      number: 1,
      sequence: 2,
      manufacturerCode: 'FAB-01',
      discount: 1.25,
      drawbackNumber: 'DRAW-1',
    );
    final declaration = ImportDeclaration(
      number: 'DI-1',
      registrationDate: DateTime.utc(2024, 1, 2),
      customsLocation: 'Santos',
      customsState: 'SP',
      clearanceDate: DateTime.utc(2024, 1, 3),
      transportMode: 1,
      intermediaryType: 1,
      exporterCode: 'EXP-1',
      additions: const [addition],
    );
    const individual = IndividualExport(
      registrationNumber: 'RE-1',
      receivedInvoiceKey: '35123456789012345678550010000000011000000010',
      exportedQuantity: 2.5,
    );
    expect(make.tagNVE('NVE-1').localName, 'NVE');
    expect(make.tagCEST('1234567').localName, 'CEST');
    expect(make.taginfAdProd('obs').localName, 'infAdProd');
    expect(make.tagDI(declaration).findAllElements('adi'), hasLength(1));
    expect(make.tagadi(addition).findElements('nAdicao').single.innerText, '1');
    expect(
      make
          .tagdetExport(const ExportDetail(individualExports: [individual]))
          .findAllElements('exportInd'),
      hasLength(1),
    );
    expect(make.tagdetExportInd(individual).localName, 'exportInd');
  });

  test('valida combinações incompletas de PISST e COFINSST', () {
    final builder = NfeXmlBuilder();

    expect(
      () => builder.tagPISST(const PisStTax(quantity: 1, value: 0.1)),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'INVALID_PISST',
        ),
      ),
    );
    expect(
      () => builder.tagPISST(const PisStTax(rate: 1.65, value: 0.1)),
      throwsA(isA<FiscalValidationException>()),
    );
    expect(
      () => builder.tagCOFINSST(const CofinsStTax(quantity: 1, value: 0.1)),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'INVALID_COFINSST',
        ),
      ),
    );
    expect(
      () => builder.tagCOFINSST(const CofinsStTax(base: 5, value: 0.1)),
      throwsA(isA<FiscalValidationException>()),
    );
  });

  test('Tools valida CNPJ e formata valores', () {
    expect(Tools.isValidCnpj('04.252.011/0001-10'), isTrue);
    expect(Tools.isValidCnpj('04.252.011/0001-11'), isFalse);
    expect(Tools.isValidCpf('529.982.247-25'), isTrue);
    expect(Tools.isValidCpf('529.982.247-26'), isFalse);
    expect(Tools.formatDecimal(12.5), '12.50');
    expect(Tools.onlyDigits('04.252.011/0001-10'), '04252011000110');
  });

  test('valida GTIN com Mod-10', () {
    expect(Gtin.isValid('7894900011517'), isTrue);
    expect(Gtin.isValid('7894900011516'), isFalse);
    expect(Gtin.isValid('x7894900011517'), isFalse);
    expect(Gtin.isValid('7894900011517-'), isFalse);
    expect(
      () => Gtin.assertValid('1234567890123'),
      throwsA(isA<FiscalValidationException>()),
    );
  });

  test('rejeita item com classificação ou quantidade inválida', () {
    final document = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      items: const [
        NfeItem(
          number: 1,
          code: 'ABC',
          description: 'Produto',
          ncm: '123',
          cfop: '5102',
          unit: 'UN',
          quantity: 0,
          unitPrice: 5,
        ),
      ],
    );

    expect(
      () => NfeXmlBuilder().build(document),
      throwsA(isA<FiscalValidationException>()),
    );
  });

  test('emite informações adicionais opcionais', () {
    final document = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      additionalInfo: const AdditionalInfo(
        complementary: 'Pedido <interno> 123',
        taxAuthority: 'Informação fiscal',
      ),
      items: const [
        NfeItem(
          number: 1,
          code: 'ABC',
          description: 'Produto',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 5,
        ),
      ],
    );

    final xml = NfeXmlBuilder().build(document);
    expect(xml, contains('<infAdic>'));
    expect(xml, contains('<infCpl>Pedido &lt;interno> 123</infCpl>'));
    expect(xml, contains('<infAdFisco>Informação fiscal</infAdFisco>'));
  });

  test('rejeita FCI fora do formato GUID oficial', () {
    final document = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      items: const [
        NfeItem(
          number: 1,
          code: 'ABC',
          description: 'Produto',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 5,
          fciNumber: '01234567-89ab-cdef-0123-456789abcdef',
        ),
      ],
    );

    expect(
      () => NfeXmlBuilder().build(document),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'INVALID_FCI_NUMBER',
        ),
      ),
    );
  });

  test('validador estrutural rejeita XML sem grupo obrigatório', () {
    final result = NfeXmlValidator().validate('<NFe><infNFe/></NFe>');
    expect(result.isValid, isFalse);
    expect(result.errors, contains('A versão de infNFe deve ser 4.00.'));
    expect(result.errors, contains('O grupo ide é obrigatório.'));
  });

  test('rejeita pagamentos que não fecham o total', () {
    final document = NfeDocument(
      accessKey: accessKey65,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 65,
      issuer: issuer,
      payments: const [Payment(type: '01', value: 1)],
      items: const [
        NfeItem(
          number: 1,
          code: 'ABC',
          description: 'Produto',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 5,
        ),
      ],
    );

    expect(
      () => NfeXmlBuilder().build(document),
      throwsA(isA<FiscalValidationException>()),
    );
  });

  test('emite pagamento eletrônico e troco', () {
    final document = NfeDocument(
      accessKey: accessKey65,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 65,
      issuer: issuer,
      changeValue: 2,
      payments: const [
        Payment(
          type: '03',
          value: 7,
          integration: 1,
          brand: '01',
          authorization: 'AUTH-1',
        ),
      ],
      items: const [
        NfeItem(
          number: 1,
          code: 'ABC',
          description: 'Produto',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 5,
        ),
      ],
    );

    final xml = NfeXmlBuilder().build(document);
    expect(xml, contains('<card>'));
    expect(xml, contains('<tpIntegra>1</tpIntegra>'));
    expect(xml, contains('<tBand>01</tBand>'));
    expect(xml, contains('<cAut>AUTH-1</cAut>'));
    expect(xml, contains('<vTroco>2.00</vTroco>'));
  });

  test('gera grupos tributários básicos e totaliza impostos', () {
    final document = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      items: const [
        NfeItem(
          number: 1,
          code: 'ABC',
          description: 'Produto tributado',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 100,
          icms: IcmsTax(cst: '00', base: 100, rate: 18, value: 18),
          pis: PisTax(cst: '01', base: 100, rate: 1.65, value: 1.65),
          cofins: CofinsTax(cst: '01', base: 100, rate: 7.6, value: 7.6),
        ),
      ],
    );

    final xml = NfeXmlBuilder().build(document);
    expect(xml, contains('<ICMS00>'));
    expect(xml, contains('<vICMS>18.00</vICMS>'));
    expect(xml, contains('<PISAliq>'));
    expect(xml, contains('<COFINSAliq>'));
    expect(xml, contains('<vCOFINS>7.60</vCOFINS>'));
    expect(xml, contains('<vBC>100.00</vBC>'));
  });

  test('emite IPI tributado e totaliza vIPI', () {
    final document = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      items: const [
        NfeItem(
          number: 1,
          code: 'ABC',
          description: 'Produto com IPI',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 100,
          ipi: IpiTax(
            enquadramento: '999',
            cst: '50',
            base: 100,
            rate: 5,
            value: 5,
          ),
          icms: IcmsTax(cst: '00', base: 100, rate: 18, value: 18),
        ),
      ],
    );

    final xml = NfeXmlBuilder().build(document);
    expect(xml, contains('<IPITrib>'));
    expect(xml, contains('<cEnq>999</cEnq>'));
    expect(xml, contains('<vIPI>5.00</vIPI>'));
  });

  test('emite IPI não tributado como IPINT', () {
    final document = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      items: const [
        NfeItem(
          number: 1,
          code: 'IPI-NT',
          description: 'Produto sem IPI',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 10,
          ipi: IpiTax(
            enquadramento: '999',
            cst: '51',
            base: 0,
            rate: 0,
            value: 0,
          ),
          icms: IcmsTax(cst: '40', base: 0, rate: 0, value: 0),
        ),
      ],
    );

    final xml = NfeXmlBuilder().build(document);
    expect(xml, contains('<IPINT>'));
    expect(xml, contains('<CST>51</CST>'));
    expect(xml, isNot(contains('<IPITrib>')));
  });

  test('emite variantes de ICMS normal conforme o CST', () {
    final document = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      items: const [
        NfeItem(
          number: 1,
          code: 'ICMS20',
          description: 'Redução de base',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 100,
          icms: IcmsTax(
            cst: '20',
            base: 90,
            rate: 18,
            value: 16.2,
            reduction: 10,
            desonerationValue: 1,
            desonerationReason: 9,
            deductDesoneration: true,
          ),
        ),
        NfeItem(
          number: 2,
          code: 'ICMS40',
          description: 'Isento',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 10,
          icms: IcmsTax(cst: '40', base: 0, rate: 0, value: 0),
        ),
        NfeItem(
          number: 3,
          code: 'ICMS51',
          description: 'Diferimento',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 10,
          icms: IcmsTax(
            cst: '51',
            base: 10,
            rate: 18,
            value: 1.8,
            operationValue: 1.8,
            differenceRate: 0,
            benefitReductionCode: 'RBC12345',
            differenceValue: 0,
          ),
        ),
        NfeItem(
          number: 4,
          code: 'ICMS60',
          description: 'ST retido',
          ncm: '12345678',
          cfop: '5405',
          unit: 'UN',
          quantity: 1,
          unitPrice: 10,
          icms: IcmsTax(
            cst: '60',
            base: 0,
            rate: 0,
            value: 0,
            retainedBase: 10,
            retainedRate: 18,
            retainedValue: 1.8,
            substitutedValue: 0.5,
            retainedFcpBase: 10,
            retainedFcpRate: 2,
            retainedFcpValue: 0.2,
            effectiveReduction: 5,
            effectiveBase: 9.5,
            effectiveRate: 17,
            effectiveValue: 1.62,
          ),
        ),
        NfeItem(
          number: 5,
          code: 'ICMS90',
          description: 'Outras',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 10,
          icms: IcmsTax(cst: '90', base: 10, rate: 18, value: 1.8),
        ),
      ],
    );

    final xml = NfeXmlBuilder().build(document);
    expect(xml, contains('<ICMS20>'));
    expect(xml, contains('<ICMS40>'));
    expect(xml, contains('<ICMS51>'));
    expect(xml, contains('<ICMS60>'));
    expect(xml, contains('<ICMS90>'));
    expect(xml, contains('<pRedBC>10.00</pRedBC>'));
    expect(xml, contains('<indDeduzDeson>1</indDeduzDeson>'));
    expect(xml, contains('<cBenefRBC>RBC12345</cBenefRBC>'));
    expect(xml, contains('<vICMSSTRet>1.80</vICMSSTRet>'));
    expect(xml, contains('<vICMSSubstituto>0.50</vICMSSubstituto>'));
    expect(xml, contains('<vFCPSTRet>0.20</vFCPSTRet>'));
    expect(xml, contains('<vICMSEfet>1.62</vICMSEfet>'));
  });

  test('emite grupos de ICMS do Simples Nacional por CSOSN', () {
    final document = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      items: const [
        NfeItem(
          number: 1,
          code: 'SN101',
          description: 'Credito SN',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 10,
          icmsSimples: IcmsSimplesTax(
            csosn: '101',
            creditRate: 2,
            creditValue: 0.2,
          ),
        ),
        NfeItem(
          number: 2,
          code: 'SN102',
          description: 'Sem credito SN',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 10,
          icmsSimples: IcmsSimplesTax(csosn: '102'),
        ),
        NfeItem(
          number: 3,
          code: 'SN201',
          description: 'Credito e ST',
          ncm: '12345678',
          cfop: '5401',
          unit: 'UN',
          quantity: 1,
          unitPrice: 10,
          icmsSimples: IcmsSimplesTax(
            csosn: '201',
            creditRate: 2,
            creditValue: 0.2,
            stBase: 12,
            stRate: 18,
            stValue: 2.16,
          ),
        ),
        NfeItem(
          number: 4,
          code: 'SN202',
          description: 'ST sem credito',
          ncm: '12345678',
          cfop: '5401',
          unit: 'UN',
          quantity: 1,
          unitPrice: 10,
          icmsSimples: IcmsSimplesTax(
            csosn: '202',
            stBase: 12,
            stRate: 18,
            stValue: 2.16,
          ),
        ),
        NfeItem(
          number: 5,
          code: 'SN500',
          description: 'ST anterior',
          ncm: '12345678',
          cfop: '5405',
          unit: 'UN',
          quantity: 1,
          unitPrice: 10,
          icmsSimples: IcmsSimplesTax(
            csosn: '500',
            retainedBase: 10,
            retainedRate: 18,
            retainedValue: 1.8,
          ),
        ),
        NfeItem(
          number: 6,
          code: 'SN900',
          description: 'Outros SN',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 10,
          icmsSimples: IcmsSimplesTax(
            csosn: '900',
            base: 10,
            rate: 18,
            value: 1.8,
          ),
        ),
      ],
    );

    final xml = NfeXmlBuilder().build(document);
    expect(xml, contains('<ICMSSN101>'));
    expect(xml, contains('<ICMSSN102>'));
    expect(xml, contains('<ICMSSN201>'));
    expect(xml, contains('<ICMSSN202>'));
    expect(xml, contains('<ICMSSN500>'));
    expect(xml, contains('<ICMSSN900>'));
    expect(xml, contains('<vCredICMSSN>0.20</vCredICMSSN>'));
    expect(xml, contains('<vBCSTRet>10.00</vBCSTRet>'));
    expect(xml, contains('<vST>4.32</vST>'));
    expect(xml, contains('<vNF>64.32</vNF>'));
  });

  test('emite grupos de ICMS monofásico', () {
    final document = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      items: const [
        NfeItem(
          number: 1,
          code: 'MONO02',
          description: 'Monofasico proprio',
          ncm: '12345678',
          cfop: '5656',
          unit: 'L',
          quantity: 1,
          unitPrice: 10,
          icmsMonophase: IcmsMonophaseTax(
            cst: '02',
            quantity: 10,
            rate: 0.5,
            value: 5,
          ),
        ),
        NfeItem(
          number: 2,
          code: 'MONO15',
          description: 'Monofasico retencao',
          ncm: '12345678',
          cfop: '5656',
          unit: 'L',
          quantity: 1,
          unitPrice: 10,
          icmsMonophase: IcmsMonophaseTax(
            cst: '15',
            quantity: 10,
            rate: 0.5,
            value: 5,
            retainedQuantity: 2,
            retainedRate: 0.2,
            retainedValue: 0.4,
          ),
        ),
        NfeItem(
          number: 3,
          code: 'MONO53',
          description: 'Monofasico diferido',
          ncm: '12345678',
          cfop: '5656',
          unit: 'L',
          quantity: 1,
          unitPrice: 10,
          icmsMonophase: IcmsMonophaseTax(
            cst: '53',
            quantity: 5,
            rate: 0.4,
            operationValue: 2,
            differenceRate: 10,
            differenceValue: 0.2,
            value: 1.8,
          ),
        ),
        NfeItem(
          number: 4,
          code: 'MONO61',
          description: 'Monofasico retido',
          ncm: '12345678',
          cfop: '5656',
          unit: 'L',
          quantity: 1,
          unitPrice: 10,
          icmsMonophase: IcmsMonophaseTax(
            cst: '61',
            retainedQuantity: 3,
            retainedRate: 0.3,
            retainedValue: 0.9,
          ),
        ),
      ],
    );

    final xml = NfeXmlBuilder().build(document);
    expect(xml, contains('<ICMS02>'));
    expect(xml, contains('<ICMS15>'));
    expect(xml, contains('<ICMS53>'));
    expect(xml, contains('<ICMS61>'));
    expect(xml, contains('<vICMSMono>11.80</vICMSMono>'));
    expect(xml, contains('<vICMSMonoRet>0.90</vICMSMonoRet>'));
  });

  test('emite FCP e ICMS-ST e totaliza os grupos próprios', () {
    final document = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      items: const [
        NfeItem(
          number: 1,
          code: 'ABC',
          description: 'Produto com substituição tributária',
          ncm: '12345678',
          cfop: '5405',
          unit: 'UN',
          quantity: 1,
          unitPrice: 100,
          icmsSt: IcmsStTax(
            base: 100,
            rate: 18,
            value: 18,
            stBase: 120,
            stRate: 18,
            stValue: 3.6,
            fcpBase: 100,
            fcpRate: 2,
            fcpValue: 2,
            fcpStBase: 120,
            fcpStRate: 2,
            fcpStValue: 2.4,
          ),
          icmsStRetained: IcmsStRetainedTax(
            origin: 0,
            cst: '60',
            retainedBase: 100,
            retainedValue: 18,
            destinationBase: 100,
            destinationValue: 18,
            retainedFcpBase: 100,
            retainedFcpRate: 2,
            retainedFcpValue: 1.2,
          ),
        ),
      ],
    );

    final xml = NfeXmlBuilder().build(document);
    expect(xml, contains('<ICMS10>'));
    expect(xml, contains('<vBCST>120.00</vBCST>'));
    expect(xml, contains('<vICMSST>3.60</vICMSST>'));
    expect(xml, contains('<vFCP>2.00</vFCP>'));
    expect(xml, contains('<vFCPST>2.40</vFCPST>'));
    expect(xml, contains('<vFCPSTRet>1.20</vFCPSTRet>'));
    expect(xml, contains('<vBCST>120.00</vBCST>'));
  });

  test('emite ICMS70 com redução e desonerações próprias da ST', () {
    final document = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      items: [
        NfeItem(
          number: 1,
          code: 'ICMS70',
          description: 'Produto com ICMS70',
          ncm: '12345678',
          cfop: '5405',
          unit: 'UN',
          quantity: 1,
          unitPrice: 100,
          icmsSt: const IcmsStTax(
            cst: '70',
            base: 90,
            rate: 18,
            value: 16.2,
            stBase: 120,
            stRate: 18,
            stValue: 5.4,
            ownReduction: 10,
            ownDesonerationValue: 1,
            ownDesonerationReason: 9,
            deductDesoneration: true,
            stDesonerationValue: 0.5,
            stDesonerationReason: 9,
          ),
        ),
      ],
    );

    final xml = NfeXmlBuilder().build(document);
    expect(xml, contains('<ICMS70>'));
    expect(xml, contains('<pRedBC>10.0000</pRedBC>'));
    expect(xml, contains('<vICMSDeson>1.00</vICMSDeson>'));
    expect(xml, contains('<indDeduzDeson>1</indDeduzDeson>'));
    expect(xml, contains('<vICMSSTDeson>0.50</vICMSSTDeson>'));
  });

  test('emite desonerações própria e ST no ICMS90', () {
    final document = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      items: [
        NfeItem(
          number: 1,
          code: 'ICMS90-ST',
          description: 'Produto com ICMS90',
          ncm: '12345678',
          cfop: '5405',
          unit: 'UN',
          quantity: 1,
          unitPrice: 100,
          icmsSt: const IcmsStTax(
            cst: '90',
            base: 90,
            rate: 18,
            value: 16.2,
            stBase: 120,
            stRate: 18,
            stValue: 5.4,
            ownDesonerationValue: 1,
            ownDesonerationReason: 9,
            deductDesoneration: false,
            stDesonerationValue: 0.5,
            stDesonerationReason: 9,
          ),
        ),
      ],
    );

    final xml = NfeXmlBuilder().build(document);
    expect(xml, contains('<ICMS90>'));
    expect(xml, contains('<vICMSDeson>1.00</vICMSDeson>'));
    expect(xml, contains('<indDeduzDeson>0</indDeduzDeson>'));
    expect(xml, contains('<vICMSSTDeson>0.50</vICMSSTDeson>'));
  });

  test('emite diferimento de FCP no ICMS51 na ordem oficial', () {
    final document = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      items: [
        NfeItem(
          number: 1,
          code: 'FCP-DIF',
          description: 'Produto com FCP diferido',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 10,
          icms: const IcmsTax(
            cst: '51',
            base: 10,
            rate: 18,
            value: 1.8,
            fcpBase: 10,
            fcpRate: 2,
            fcpValue: 0.2,
            fcpDifferenceRate: 50,
            fcpDifferenceValue: 0.1,
            fcpEffectiveValue: 0.1,
          ),
        ),
      ],
    );

    final xml = NfeXmlBuilder().build(document);
    expect(xml, contains('<pFCP>2.00</pFCP>'));
    expect(xml, contains('<vFCP>0.20</vFCP>'));
    expect(xml, contains('<pFCPDif>50.00</pFCPDif>'));
    expect(xml, contains('<vFCPDif>0.10</vFCPDif>'));
    expect(xml, contains('<vFCPEfet>0.10</vFCPEfet>'));
  });

  test('gera campos de contingência com justificativa', () {
    final document = NfeDocument(
      accessKey: contingencyKey,
      number: 3,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 65,
      issuer: issuer,
      contingency: Contingency(
        mode: ContingencyMode.offlineNfce,
        activatedAt: DateTime.utc(2026, 1, 1, 12),
        reason: 'Indisponibilidade temporária do serviço SEFAZ',
      ),
      items: const [
        NfeItem(
          number: 1,
          code: 'ABC',
          description: 'Produto',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 5,
        ),
      ],
    );

    final xml = NfeXmlBuilder().build(document);
    expect(xml, contains('<tpEmis>9</tpEmis>'));
    expect(
      xml,
      contains('<xJust>Indisponibilidade temporária do serviço SEFAZ</xJust>'),
    );
  });

  test('gera grupos IBS/CBS e Imposto Seletivo com totalizadores', () {
    final document = NfeDocument(
      accessKey: accessKey65,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 65,
      issuer: issuer,
      items: const [
        NfeItem(
          number: 1,
          code: 'ABC',
          description: 'Produto',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 100,
          ibsCbs: IbsCbsTax(
            cst: '000',
            classificationCode: '000001',
            base: 100,
            ibsUfRate: 0.1,
            ibsMunicipalRate: 0.2,
            cbsRate: 0.9,
            donation: true,
          ),
          selectiveTax: SelectiveTax(
            cst: '000',
            classificationCode: '000001',
            base: 100,
            rate: 1.5,
          ),
        ),
      ],
    );

    final xml = NfeXmlBuilder().build(document);
    expect(xml, contains('<IBSCBS>'));
    expect(xml.indexOf('<IS>'), lessThan(xml.indexOf('<IBSCBS>')));
    expect(xml, contains('<vIBSUF>0.10</vIBSUF>'));
    expect(xml, contains('<vIBSMun>0.20</vIBSMun>'));
    expect(xml, contains('<vCBS>0.90</vCBS>'));
    expect(xml, contains('<ISTot>'));
    expect(xml, contains('<IBSCBSTot>'));
    expect(xml, contains('<vNF>100.00</vNF>'));
    expect(xml, contains('<vNFTot>102.70</vNFTot>'));
  });

  test('emite Imposto Seletivo com alíquota ad rem e quantidade', () {
    final document = NfeDocument(
      accessKey: accessKey65,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 65,
      issuer: issuer,
      items: const [
        NfeItem(
          number: 1,
          code: 'COMB',
          description: 'Combustível',
          ncm: '27101259',
          cfop: '5656',
          unit: 'L',
          quantity: 10,
          unitPrice: 10,
          selectiveTax: SelectiveTax(
            cst: '000',
            classificationCode: '000001',
            base: 0,
            rate: 0,
            adRemRate: 0.25,
            unit: 'L',
            quantity: 10,
          ),
        ),
      ],
    );

    final xml = NfeXmlBuilder().build(document);
    expect(xml, contains('<adRemIS>0.2500</adRemIS>'));
    expect(xml, contains('<uTrib>L</uTrib>'));
    expect(xml, contains('<qTrib>10.0000</qTrib>'));
    expect(xml, contains('<vIS>2.50</vIS>'));
  });

  test('emite IBS/CBS monofásicos ad rem padrão', () {
    final document = NfeDocument(
      accessKey: accessKey65,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 65,
      issuer: issuer,
      items: const [
        NfeItem(
          number: 1,
          code: 'COMB',
          description: 'Combustível monofásico',
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
            ibsRetainedQuantity: 2,
            ibsRetainedRate: 0.05,
            ibsRetainedValue: 0.10,
            ibsPreviouslyRetainedValue: 0.20,
            cbsRetainedQuantity: 2,
            cbsRetainedRate: 0.06,
            cbsRetainedValue: 0.12,
            cbsPreviouslyRetainedValue: 0.22,
            ibsBiofuelQuantity: 0.5,
            ibsBiofuelDifference: 0.03,
            cbsBiofuelQuantity: 0.5,
            cbsBiofuelDifference: 0.01,
          ),
        ),
      ],
    );

    final xml = NfeXmlBuilder().build(document);
    expect(xml, contains('<gIBSCBSMono>'));
    expect(xml, contains('<gIBSMonoAdRem>'));
    expect(xml, contains('<adRemIBS>0.1000</adRemIBS>'));
    expect(xml, contains('<vIBSMono>1.00</vIBSMono>'));
    expect(xml, contains('<vIBSMonoReten>0.10</vIBSMonoReten>'));
    expect(xml, contains('<vIBSMonoRet>0.20</vIBSMonoRet>'));
    expect(xml, contains('<gCBSMonoAdRem>'));
    expect(xml, contains('<adRemCBS>0.2000</adRemCBS>'));
    expect(xml, contains('<vCBSMono>2.00</vCBSMono>'));
    expect(xml, contains('<vCBSMonoReten>0.12</vCBSMonoReten>'));
    expect(xml, contains('<vCBSMonoRet>0.22</vCBSMonoRet>'));
    expect(xml, contains('<qBCBioComb>0.5000</qBCBioComb>'));
    expect(xml, contains('<vIBSDiferenca>0.03</vIBSDiferenca>'));
    expect(xml, contains('<vCBSDiferenca>0.01</vCBSDiferenca>'));
    expect(xml, contains('<vTotIBSMonoItem>1.00</vTotIBSMonoItem>'));
    expect(xml, contains('<vTotCBSMonoItem>2.00</vTotCBSMonoItem>'));
    expect(xml, contains('<gMono>'));
  });

  test('emite IBS/CBS monofásicos ad valorem padrão', () {
    final document = NfeDocument(
      accessKey: accessKey65,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 65,
      issuer: issuer,
      items: const [
        NfeItem(
          number: 1,
          code: 'BIO',
          description: 'Produto monofásico ad valorem',
          ncm: '27101259',
          cfop: '5656',
          unit: 'UN',
          quantity: 1,
          unitPrice: 100,
          ibsCbsMonophase: IbsCbsMonophaseTax(
            cst: '620',
            classificationCode: '000001',
            ibsAdValoremBase: 100,
            ibsAdValoremUfRate: 1,
            ibsAdValoremUfValue: 1,
            ibsAdValoremMunicipalRate: 0.5,
            ibsAdValoremMunicipalValue: 0.5,
            ibsAdValoremValue: 1.5,
            cbsAdValoremBase: 100,
            cbsAdValoremRate: 0.5,
            cbsAdValoremValue: 0.5,
          ),
        ),
      ],
    );

    final xml = NfeXmlBuilder().build(document);
    expect(xml, contains('<gIBSMonoAdValorem>'));
    expect(xml, contains('<pAliqMonoUF>1.0000</pAliqMonoUF>'));
    expect(xml, contains('<vIBSMono>1.50</vIBSMono>'));
    expect(xml, contains('<gCBSMonoAdValorem>'));
    expect(xml, contains('<pAliqMonoCBS>0.5000</pAliqMonoCBS>'));
    expect(xml, contains('<vCBSMono>0.50</vCBSMono>'));
  });

  test('emite diferimento, devolução e redução do IBS/CBS', () {
    final document = NfeDocument(
      accessKey: accessKey65,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 65,
      issuer: issuer,
      items: const [
        NfeItem(
          number: 1,
          code: 'ABC',
          description: 'Produto',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 100,
          ibsCbs: IbsCbsTax(
            cst: '000',
            classificationCode: '000001',
            base: 100,
            ibsUfRate: 0.1,
            ibsMunicipalRate: 0.2,
            cbsRate: 0.9,
            donation: true,
            ibsUfDeferral: ReformDeferral(rate: 10, value: 0.01),
            ibsUfRefund: ReformRefund(rate: 5, value: 0.02),
            ibsMunicipalDeferral: ReformDeferral(rate: 8, value: 0.04),
            ibsMunicipalRefund: ReformRefund(rate: 4, value: 0.05),
            ibsMunicipalReduction: ReformReduction(
              rate: 20,
              effectiveRate: 0.16,
            ),
            cbsDeferral: ReformDeferral(rate: 15, value: 0.03),
            cbsRefund: ReformRefund(rate: 3, value: 0.06),
            creditReversal: ReformCreditReversal(
              ibsValue: 0.08,
              cbsValue: 0.09,
            ),
            operationCredit: ReformOperationCredit(
              base: 100,
              code: '01',
              ibs: ReformPresumedCredit(rate: 1, value: 0.07),
              cbs: ReformPresumedCredit(rate: 2, value: 0.08),
            ),
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
          ),
          presumedCredits: [
            PresumedCredit(code: 'CRED1234', rate: 1, value: 0.07),
          ],
        ),
      ],
    );

    final xml = NfeXmlBuilder().build(document);
    expect(xml, contains('<pDif>10.0000</pDif>'));
    expect(xml, contains('<vDif>0.01</vDif>'));
    expect(xml, contains('<pDevTrib>5.0000</pDevTrib>'));
    expect(xml, contains('<vDevTrib>0.02</vDevTrib>'));
    expect(xml, contains('<pRedAliq>20.0000</pRedAliq>'));
    expect(xml, contains('<pAliqEfet>0.1600</pAliqEfet>'));
    expect(xml, contains('<vDif>0.04</vDif>'));
    expect(xml, contains('<vDevTrib>0.05</vDevTrib>'));
    expect(xml, contains('<vDif>0.03</vDif>'));
    expect(xml, contains('<vDevTrib>0.06</vDevTrib>'));
    expect(xml, contains('<vCredPres>0.07</vCredPres>'));
    expect(xml, contains('<vCredPres>0.08</vCredPres>'));
    expect(xml, contains('<gCredPresOper>'));
    expect(xml, contains('<indDoacao>1</indDoacao>'));
    expect(xml, contains('<gEstornoCred>'));
    expect(xml, contains('<gTribRegular>'));
    expect(xml, contains('<CSTReg>000</CSTReg>'));
    expect(xml, contains('<vTribRegIBSUF>1.00</vTribRegIBSUF>'));
    expect(xml, contains('<gTribCompraGov>'));
    expect(xml, contains('<vTribIBSUF>1.00</vTribIBSUF>'));
    expect(xml, contains('<vIBSEstCred>0.08</vIBSEstCred>'));
    expect(xml, contains('<vCBSEstCred>0.09</vCBSEstCred>'));
  });

  test('totaliza ICMS desonerado nos grupos próprios', () {
    final document = NfeDocument(
      accessKey: accessKey65,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 65,
      issuer: issuer,
      items: const [
        NfeItem(
          number: 1,
          code: 'ABC',
          description: 'Produto',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 100,
          icms: IcmsTax(
            cst: '40',
            base: 0,
            rate: 0,
            value: 0,
            desonerationValue: 2.5,
            desonerationReason: 7,
          ),
        ),
      ],
    );

    final xml = NfeXmlBuilder().build(document);
    expect(xml, contains('<vICMSDeson>2.50</vICMSDeson>'));
  });

  test('rejeita crédito RTC com código ou valores inválidos', () {
    final document = NfeDocument(
      accessKey: accessKey65,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 65,
      issuer: issuer,
      items: const [
        NfeItem(
          number: 1,
          code: 'ABC',
          description: 'Produto',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 100,
          ibsCbs: IbsCbsTax(
            cst: '000',
            classificationCode: '000001',
            base: 100,
            ibsUfRate: 0,
            ibsMunicipalRate: 0,
            cbsRate: 0,
            operationCredit: ReformOperationCredit(
              base: 100,
              code: 'ABC',
              ibs: ReformPresumedCredit(rate: 1, value: 1),
            ),
          ),
        ),
      ],
    );

    expect(
      () => NfeXmlBuilder().build(document),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'INVALID_IBS_CBS_CREDIT',
        ),
      ),
    );
  });

  test('emite crédito presumido IBS da ZFM na posição RTC', () {
    final document = NfeDocument(
      accessKey: accessKey65,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 65,
      issuer: issuer,
      items: [
        NfeItem(
          number: 1,
          code: 'ABC',
          description: 'Produto',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 100,
          ibsCbs: IbsCbsTax(
            cst: '000',
            classificationCode: '000001',
            base: 100,
            ibsUfRate: 0,
            ibsMunicipalRate: 0,
            cbsRate: 0,
            zfmCredit: ReformZfmCredit(
              competence: DateTime.utc(2026, 1),
              type: '2',
              value: 0.55,
            ),
          ),
        ),
      ],
    );

    final xml = NfeXmlBuilder().build(document);
    expect(xml, contains('<gCredPresIBSZFM>'));
    expect(xml, contains('<competApur>2026-01</competApur>'));
    expect(xml, contains('<vCredPresIBSZFM>0.55</vCredPresIBSZFM>'));
    expect(xml, contains('<vCredPres>0.55</vCredPres>'));
  });

  test('rejeita bases e alíquotas inválidas da reforma tributária', () {
    final ibsDocument = NfeDocument(
      accessKey: accessKey65,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 65,
      issuer: issuer,
      items: const [
        NfeItem(
          number: 1,
          code: 'ABC',
          description: 'Produto',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 100,
          ibsCbs: IbsCbsTax(
            cst: '000',
            classificationCode: '000001',
            base: 100,
            ibsUfRate: 101,
            ibsMunicipalRate: 0,
            cbsRate: 0,
          ),
        ),
      ],
    );
    expect(
      () => NfeXmlBuilder().build(ibsDocument),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'INVALID_IBS_CBS_CLASSIFICATION',
        ),
      ),
    );

    final selectiveDocument = NfeDocument(
      accessKey: accessKey65,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 65,
      issuer: issuer,
      items: const [
        NfeItem(
          number: 1,
          code: 'ABC',
          description: 'Produto',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 100,
          selectiveTax: SelectiveTax(
            cst: '000',
            classificationCode: '000001',
            base: 100,
            rate: 101,
          ),
        ),
      ],
    );
    expect(
      () => NfeXmlBuilder().build(selectiveDocument),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'INVALID_SELECTIVE_CLASSIFICATION',
        ),
      ),
    );
  });

  test(
    'buildStrict exige campos fiscais mínimos e monta documento completo',
    () {
      final document = NfeDocument(
        accessKey: accessKey,
        number: 1,
        series: 1,
        issueDate: DateTime.utc(2026, 1, 1),
        environment: 2,
        model: 55,
        operationNature: 'Venda de mercadoria',
        documentType: 1,
        destinationType: 1,
        printFormat: 1,
        purpose: 1,
        finalConsumer: 0,
        presenceIndicator: 1,
        processCode: '0',
        applicationVersion: '1.0.0',
        issuer: const Party(
          name: 'Empresa Completa',
          cnpj: '04252011000110',
          address: 'Rua Fiscal',
          addressNumber: '1',
          neighborhood: 'Centro',
          cityCode: '1100015',
          city: 'Alta Floresta D Oeste',
          state: 'RO',
          zipCode: '76954000',
        ),
        items: const [
          NfeItem(
            number: 1,
            code: 'STRICT-001',
            description: 'Produto estrito',
            ncm: '12345678',
            cfop: '5102',
            unit: 'UN',
            quantity: 1,
            unitPrice: 10,
          ),
        ],
      );

      final xml = const NfeXmlBuilder().buildStrict(document);
      expect(xml, contains('<natOp>Venda de mercadoria</natOp>'));
      expect(xml, contains('<tpNF>1</tpNF>'));
      expect(xml, contains('<cMunFG>1100015</cMunFG>'));
    },
  );

  test('buildStrict rejeita documento sem identificação obrigatória', () {
    final document = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      items: const [],
    );

    expect(
      () => const NfeXmlBuilder().buildStrict(document),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'STRICT_OPERATION_NATURE_REQUIRED',
        ),
      ),
    );
  });

  test('emite grupos PISNT e COFINSOutr conforme o CST', () {
    final document = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      items: const [
        NfeItem(
          number: 1,
          code: 'ABC',
          description: 'Produto não tributado',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 100,
          pis: PisTax.nonTaxed(cst: '04'),
          cofins: CofinsTax(cst: '99', base: 100, rate: 1, value: 1),
        ),
      ],
    );

    final xml = NfeXmlBuilder().build(document);
    expect(xml, contains('<PISNT>'));
    expect(xml, contains('<COFINSOutr>'));
    expect(xml, contains('<pCOFINS>1.0000</pCOFINS>'));
  });

  test('emite PISQtde e COFINSQtde no CST 03', () {
    final document = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      items: const [
        NfeItem(
          number: 1,
          code: 'COMB-03',
          description: 'Produto por quantidade',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 2,
          unitPrice: 10,
          pis: PisTax(cst: '03', quantity: 2, unitRate: 0.5, value: 1),
          cofins: CofinsTax(cst: '03', quantity: 2, unitRate: 1, value: 2),
        ),
      ],
    );

    final xml = NfeXmlBuilder().build(document);
    expect(xml, contains('<PISQtde>'));
    expect(xml, contains('<COFINSQtde>'));
    expect(xml, contains('<qBCProd>2.0000</qBCProd>'));
    expect(xml, contains('<vAliqProd>0.5000</vAliqProd>'));
  });

  test('emite ISSQN e totalizador de serviço', () {
    final document = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      items: [
        NfeItem(
          number: 1,
          code: 'SERV-01',
          description: 'Serviço de manutenção',
          ncm: '00000000',
          cfop: '5933',
          unit: 'UN',
          quantity: 1,
          unitPrice: 200,
          serviceTax: ServiceTax(
            base: 200,
            rate: 5,
            value: 10,
            municipalityCode: '1100015',
            serviceListCode: '01.01',
            serviceCode: '0101',
            incidenceMunicipalityCode: '1100015',
            competenceDate: DateTime(2026, 1, 1),
          ),
        ),
      ],
    );

    final xml = NfeXmlBuilder().build(document);
    expect(xml, contains('<ISSQN>'));
    expect(xml, contains('<cListServ>01.01</cListServ>'));
    expect(xml, contains('<vISSQN>10.00</vISSQN>'));
    expect(xml, contains('<ISSQNtot>'));
    expect(xml, contains('<vServ>200.00</vServ>'));
    expect(xml, contains('<vISS>10.00</vISS>'));
  });

  test('emite total ISSQN declarado e rejeita valores inválidos', () {
    final document = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      serviceTotal: ServiceTotal(
        serviceValue: 100,
        taxBase: 80,
        taxValue: 5,
        pis: 1,
        cofins: 2,
        competenceDate: DateTime.utc(2026, 1, 1),
        taxRegime: 1,
      ),
      items: const [
        NfeItem(
          number: 1,
          code: 'SERV-02',
          description: 'Serviço declarado',
          ncm: '00000000',
          cfop: '5933',
          unit: 'UN',
          quantity: 1,
          unitPrice: 100,
        ),
      ],
    );

    final xml = NfeXmlBuilder().build(document);
    expect(xml, contains('<ISSQNtot>'));
    expect(xml, contains('<cRegTrib>1</cRegTrib>'));
    expect(
      () => NfeXmlBuilder().build(
        NfeDocument(
          accessKey: accessKey,
          number: 1,
          series: 1,
          issueDate: DateTime.utc(2026, 1, 1),
          environment: 2,
          model: 55,
          issuer: issuer,
          serviceTotal: ServiceTotal(
            serviceValue: -1,
            taxBase: 0,
            taxValue: 0,
            competenceDate: DateTime.utc(2026, 1, 1),
          ),
          items: const [
            NfeItem(
              number: 1,
              code: 'SERV-02',
              description: 'Serviço declarado',
              ncm: '00000000',
              cfop: '5933',
              unit: 'UN',
              quantity: 1,
              unitPrice: 100,
            ),
          ],
        ),
      ),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'INVALID_SERVICE_TOTAL',
        ),
      ),
    );
  });

  test('emite transportador e veículo quando informados', () {
    final document = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
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
      items: const [
        NfeItem(
          number: 1,
          code: 'ABC',
          description: 'Produto',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 5,
        ),
      ],
    );

    final xml = NfeXmlBuilder().build(document);
    expect(xml, contains('<modFrete>0</modFrete>'));
    expect(xml, contains('<CNPJ>04252011000110</CNPJ>'));
    expect(xml, contains('<placa>ABC1D23</placa>'));
    expect(xml, contains('<xNome>Transportadora Fiscal</xNome>'));
    expect(xml, contains('<retTransp>'));
    expect(xml, contains('<vICMSRet>12.00</vICMSRet>'));
    expect(xml, contains('<RNTC>RNTC123</RNTC>'));
    expect(xml, contains('<reboque>'));
    expect(xml, contains('<vol>'));
    expect(xml, contains('<nLacre>LACRE1</nLacre>'));
  });

  test('normaliza transportador formatado e placa', () {
    final document = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      transport: const TransportInfo(
        freightMode: 0,
        carrier: '04.252.011/0001-10',
        vehiclePlate: 'abc1d23',
        vehicleState: 'ro',
      ),
      items: const [
        NfeItem(
          number: 1,
          code: 'ABC',
          description: 'Produto',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 5,
        ),
      ],
    );

    final xml = NfeXmlBuilder().build(document);
    expect(xml, contains('<CNPJ>04252011000110</CNPJ>'));
    expect(xml, contains('<placa>ABC1D23</placa>'));
    expect(xml, contains('<UF>RO</UF>'));
  });

  test('rejeita transportador inválido', () {
    final document = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      transport: const TransportInfo(carrier: '123'),
      items: const [
        NfeItem(
          number: 1,
          code: 'ABC',
          description: 'Produto',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 5,
        ),
      ],
    );

    expect(
      () => NfeXmlBuilder().build(document),
      throwsA(isA<FiscalValidationException>()),
    );
  });

  test('emite medidas tributáveis distintas das comerciais', () {
    final document = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      items: const [
        NfeItem(
          number: 1,
          code: 'ABC',
          description: 'Produto',
          ncm: '12345678',
          cfop: '5102',
          unit: 'CX',
          quantity: 1,
          unitPrice: 5,
          eanTrib: '7894900011517',
          tribUnit: 'UN',
          tribQuantity: 12,
          tribUnitPrice: 0.416666,
          includeInTotal: false,
        ),
      ],
    );

    final xml = NfeXmlBuilder().build(document);
    expect(xml, contains('<cEANTrib>7894900011517</cEANTrib>'));
    expect(xml, contains('<uTrib>UN</uTrib>'));
    expect(xml, contains('<qTrib>12.0000</qTrib>'));
    expect(xml, contains('<indTot>0</indTot>'));
  });

  test('exclui item com indTot=0 dos totalizadores fiscais', () {
    final document = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      items: const [
        NfeItem(
          number: 1,
          code: 'INCLUIDO',
          description: 'Incluído',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 10,
        ),
        NfeItem(
          number: 2,
          code: 'FORA',
          description: 'Fora do total',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 90,
          includeInTotal: false,
        ),
      ],
    );

    final xml = NfeXmlBuilder().build(document);
    expect(xml, contains('<vProd>10.00</vProd>'));
    expect(xml, contains('<vNF>10.00</vNF>'));
  });

  test('emite indicadores do ide quando informados', () {
    final document = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      recipient: const Party(
        name: 'Destinatário de Teste',
        cnpj: '04252011000110',
        address: 'Rua Destino',
        addressNumber: '10',
        addressComplement: 'Sala 2',
        neighborhood: 'Centro',
        cityCode: '1100015',
        city: 'Alta Floresta D Oeste',
        state: 'RO',
        zipCode: '76954000',
        phone: '69999999999',
        email: 'destinatario@example.com',
        recipientIeIndicator: 9,
        municipalRegistration: '12345',
      ),
      operationNature: 'Venda de mercadoria',
      documentType: 1,
      destinationType: 1,
      printFormat: 1,
      purpose: 1,
      finalConsumer: 0,
      presenceIndicator: 1,
      intermediaryIndicator: 1,
      intermediary: const IntermediaryInfo(
        cnpj: '04252011000110',
        identifier: 'PEDIDO-MARKETPLACE-1',
      ),
      operationLocationCode: '110001',
      advancePaymentReferences: [accessKey65],
      governmentPurchase: GovernmentPurchase(
        governmentEntityType: 2,
        reductionPercentage: 10,
        operationType: 3,
        previousDocumentReferences: [accessKey65],
      ),
      items: const [
        NfeItem(
          number: 1,
          code: 'ABC',
          description: 'Produto',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 5,
        ),
      ],
    );

    final xml = NfeXmlBuilder().build(document);
    expect(xml, contains('<natOp>Venda de mercadoria</natOp>'));
    expect(xml, contains('<tpNF>1</tpNF>'));
    expect(xml, contains('<idDest>1</idDest>'));
    expect(xml, contains('<tpImp>1</tpImp>'));
    expect(xml, contains('<finNFe>1</finNFe>'));
    expect(xml, contains('<indFinal>0</indFinal>'));
    expect(xml, contains('<indPres>1</indPres>'));
    expect(xml, contains('<indIntermed>1</indIntermed>'));
    expect(xml, contains('<infIntermed>'));
    expect(xml, contains('<idCadIntTran>PEDIDO-MARKETPLACE-1</idCadIntTran>'));
    expect(xml, contains('<cIndOp>110001</cIndOp>'));
    expect(xml, contains('<gPagAntecipado>'));
    expect(xml, contains('<refNFe>$accessKey65</refNFe>'));
    expect(xml, contains('<gCompraGov>'));
    expect(xml, contains('<tpEnteGov>2</tpEnteGov>'));
    expect(xml, contains('<pRedutor>10.0000</pRedutor>'));
    expect(xml, contains('<tpOperGov>3</tpOperGov>'));
    expect(xml, contains('<refDFeAnt>$accessKey65</refDFeAnt>'));
    expect(xml, contains('<xCpl>Sala 2</xCpl>'));
    expect(xml, contains('<fone>69999999999</fone>'));
    expect(xml, contains('<indIEDest>9</indIEDest>'));
    expect(xml, contains('<email>destinatario@example.com</email>'));
  });

  test('valida a dependência entre indIntermed e infIntermed', () {
    final document = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      intermediaryIndicator: 1,
      items: const [
        NfeItem(
          number: 1,
          code: 'ABC',
          description: 'Produto',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 5,
        ),
      ],
    );
    expect(
      () => NfeXmlBuilder().build(document),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'INVALID_INTERMEDIARY_DATA',
        ),
      ),
    );
    final group = NfeXmlBuilder().taginfIntermed(
      const IntermediaryInfo(
        cnpj: '04252011000110',
        identifier: 'MARKETPLACE-1',
      ),
    );
    expect(group.localName, 'infIntermed');
  });

  test('valida referências de pagamento antecipado', () {
    final document = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      advancePaymentReferences: const ['1'],
      items: const [
        NfeItem(
          number: 1,
          code: 'ABC',
          description: 'Produto',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 5,
        ),
      ],
    );
    expect(
      () => NfeXmlBuilder().build(document),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'INVALID_ADVANCE_PAYMENT_REFERENCES',
        ),
      ),
    );
    expect(
      NfeXmlBuilder().taggPagAntecipado(accessKey65).localName,
      'gPagAntecipado',
    );
    expect(
      NfeXmlBuilder()
          .taggCompraGov(
            GovernmentPurchase(
              governmentEntityType: 1,
              reductionPercentage: 0,
              operationType: 1,
            ),
          )
          .localName,
      'gCompraGov',
    );
  });

  test('rejeita referência governamental proibida pela operação', () {
    final document = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      governmentPurchase: GovernmentPurchase(
        governmentEntityType: 1,
        reductionPercentage: 0,
        operationType: 1,
        previousDocumentReferences: [accessKey65],
      ),
      items: const [
        NfeItem(
          number: 1,
          code: 'ABC',
          description: 'Produto',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 5,
        ),
      ],
    );
    expect(
      () => NfeXmlBuilder().build(document),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'INVALID_GOVERNMENT_PURCHASE',
        ),
      ),
    );
  });

  test('emite suplemento QR Code somente para NFC-e', () {
    final document = NfeDocument(
      accessKey: accessKey65,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 65,
      issuer: issuer,
      nfceSupplement: const NfceXmlSupplement(
        qrCode: 'https://fazenda.example/qrcode?p=payload',
        keyUrl: 'https://fazenda.example/consulta',
      ),
      items: const [
        NfeItem(
          number: 1,
          code: 'ABC',
          description: 'Produto',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 5,
        ),
      ],
    );

    final xml = NfeXmlBuilder().build(document);
    expect(xml, contains('<infNFeSupl>'));
    expect(xml, contains('<qrCode>https://fazenda.example/qrcode'));
    expect(
      xml,
      contains('<urlChave>https://fazenda.example/consulta</urlChave>'),
    );
  });

  test('rejeita suplemento QR Code em NF-e modelo 55', () {
    final document = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      nfceSupplement: const NfceXmlSupplement(
        qrCode: 'payload',
        keyUrl: 'https://fazenda.example/consulta',
      ),
      items: const [
        NfeItem(
          number: 1,
          code: 'ABC',
          description: 'Produto',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 5,
        ),
      ],
    );

    expect(
      () => NfeXmlBuilder().build(document),
      throwsA(isA<FiscalValidationException>()),
    );
  });

  test('emite referências, cobrança e responsável técnico', () {
    final document = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      references: [
        ReferencedDocument.nfe(accessKey65),
        const ReferencedDocument.cte(
          '51121006145774000197570010000000131004100705',
        ),
        const ReferencedDocument.nfp(
          cUf: '11',
          yearMonth: '2601',
          cpf: '52998224725',
          producerIe: 'ISENTO',
          model: 4,
          series: 1,
          number: 2,
        ),
      ],
      billing: BillingInfo(
        invoiceNumber: 'FAT-1',
        originalValue: 5,
        installments: [
          InvoiceInstallment(
            number: '001',
            dueDate: DateTime.utc(2026, 2, 1),
            value: 5,
          ),
        ],
      ),
      technicalResponsible: const TechnicalResponsible(
        cnpj: '04252011000110',
        contact: 'Suporte Fiscal',
        email: 'suporte@example.com',
        phone: '6933334444',
      ),
      items: const [
        NfeItem(
          number: 1,
          code: 'ABC',
          description: 'Produto',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 5,
        ),
      ],
    );

    final xml = NfeXmlBuilder().build(document);
    expect(xml, contains('<refNFe>$accessKey65</refNFe>'));
    expect(
      xml,
      contains('<refCTe>51121006145774000197570010000000131004100705</refCTe>'),
    );
    expect(xml, contains('<refNFP>'));
    expect(xml, contains('<CPF>52998224725</CPF>'));
    expect(xml, contains('<nFat>FAT-1</nFat>'));
    expect(xml, contains('<dVenc>2026-02-01</dVenc>'));
    expect(xml, contains('<infRespTec>'));
  });

  test('rejeita duplicatas que não fecham a fatura', () {
    final document = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      billing: BillingInfo(
        invoiceNumber: 'FAT-1',
        originalValue: 5,
        installments: [
          InvoiceInstallment(
            number: '001',
            dueDate: DateTime.utc(2026, 2, 1),
            value: 4,
          ),
        ],
      ),
      items: const [
        NfeItem(
          number: 1,
          code: 'ABC',
          description: 'Produto',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 5,
        ),
      ],
    );

    expect(
      () => NfeXmlBuilder().build(document),
      throwsA(isA<FiscalValidationException>()),
    );
  });

  test('rejeita números de item duplicados', () {
    final document = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      items: const [
        NfeItem(
          number: 1,
          code: 'A',
          description: 'Produto A',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 5,
        ),
        NfeItem(
          number: 1,
          code: 'B',
          description: 'Produto B',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 5,
        ),
      ],
    );

    expect(
      () => NfeXmlBuilder().build(document),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'INVALID_ITEM_IDENTIFICATION',
        ),
      ),
    );
  });

  test('rejeita valores não finitos no item', () {
    final document = NfeDocument(
      accessKey: accessKey,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: issuer,
      items: const [
        NfeItem(
          number: 1,
          code: 'A',
          description: 'Produto',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: double.nan,
          unitPrice: 5,
        ),
      ],
    );

    expect(
      () => NfeXmlBuilder().build(document),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'INVALID_ITEM_VALUE',
        ),
      ),
    );
  });
}
