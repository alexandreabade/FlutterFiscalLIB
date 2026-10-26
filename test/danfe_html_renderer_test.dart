import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';
import 'package:test/test.dart';

void main() {
  test('renderiza HTML e escapa conteúdo do item', () {
    final document = NfeDocument(
      accessKey: AccessKey.fromComponents(
        cUf: '11',
        issueDate: DateTime.utc(2026, 1, 1),
        cnpj: '04252011000110',
        model: 55,
        series: 1,
        number: 1,
        tpEmis: 1,
        cNf: '12345678',
      ).value,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: const Party(name: 'Empresa', cnpj: '04252011000110', crt: '3'),
      purchaseInfo: const PurchaseInfo(
        commitmentNote: 'NE-001',
        order: 'PED-001',
        contract: 'CTR-001',
      ),
      references: [
        ReferencedDocument.legacy(
          cUf: '11',
          yearMonth: '2601',
          cnpj: '04252011000110',
          model: 1,
          series: 2,
          number: 3,
        ),
      ],
      items: const [
        NfeItem(
          number: 1,
          code: 'X',
          ean: '7891234567895',
          description: '<script>alert(1)</script>',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 2,
          orderNumber: 'PED-1',
          orderItem: 7,
          tribUnit: 'CX',
          tribQuantity: 2,
          tribUnitPrice: 1.25,
          additionalInformation: 'Informação do lote',
          approximateTaxValue: 1.25,
          ibsCbs: IbsCbsTax(
            cst: '000',
            classificationCode: '000001',
            base: 2,
            ibsUfRate: 1,
            ibsMunicipalRate: 1,
            cbsRate: 1,
            regularTax: ReformRegularTax(
              cst: '000',
              classificationCode: '000001',
              ibsUfRate: 1,
              ibsUfValue: 0.01,
              ibsMunicipalRate: 1,
              ibsMunicipalValue: 0.01,
              cbsRate: 1,
              cbsValue: 0.02,
            ),
            governmentTax: ReformGovernmentTax(
              ibsUfRate: 1,
              ibsUfValue: 0.03,
              ibsMunicipalRate: 1,
              ibsMunicipalValue: 0.04,
              cbsRate: 1,
              cbsValue: 0.05,
            ),
            creditReversal: ReformCreditReversal(
              ibsValue: 0.06,
              cbsValue: 0.07,
            ),
            operationCredit: ReformOperationCredit(
              base: 2,
              code: '01',
              ibs: ReformPresumedCredit(rate: 1, value: 0.08),
              cbs: ReformPresumedCredit(rate: 1, value: 0.09),
            ),
          ),
          selectiveTax: SelectiveTax(
            cst: '000',
            classificationCode: 'IS0001',
            base: 2,
            rate: 1,
          ),
          icms: IcmsTax(cst: '00', base: 2, rate: 18, value: 0.36),
          icmsUfDestination: IcmsUfDestinationTax(
            base: 2,
            destinationRate: 18,
            interstateRate: 12,
            partitionRate: 100,
            destinationValue: 1,
            originValue: 0.5,
            fcpValue: 0.1,
          ),
          ipi: IpiTax(
            enquadramento: '999',
            cst: '50',
            base: 2,
            rate: 5,
            value: 0.10,
          ),
          pis: PisTax(cst: '01', base: 2, rate: 1.65, value: 0.03),
          cofins: CofinsTax(cst: '01', base: 2, rate: 7.6, value: 0.15),
        ),
      ],
    );

    final html = DanfeHtmlRenderer().render(document);
    expect(html, contains('<!doctype html>'));
    expect(html, contains('SEM VALOR FISCAL - AMBIENTE DE HOMOLOGAÇÃO'));
    expect(html, contains('CRT: 3'));
    expect(html, contains('DANFE - CONTINUAÇÃO'));
    expect(html, contains('Chave: ${document.accessKey}'));
    expect(html, contains('access-key-barcode'));
    expect(html, contains('<svg'));
    expect(html, contains('Informação do lote'));
    expect(html, contains('Trib.: 2.0000 CX x 1.25'));
    expect(html, contains('Tributos aproximados'));
    expect(html, contains('ICMS UF destino'));
    expect(html, contains('FCP UF destino'));
    expect(html, contains('<td class="number">1.25</td>'));
    expect(html, contains('<th>CST</th>'));
    expect(html, contains('<th>BC ICMS</th>'));
    expect(html, contains('<td>00</td>'));
    expect(html, contains('<td>0.36</td>'));
    expect(html, contains('&lt;script&gt;alert(1)&lt;/script&gt;'));
    expect(html, isNot(contains('<script>alert(1)</script>')));

    final canceledHtml = DanfeHtmlRenderer().render(
      document,
      options: const DanfeHtmlOptions(canceled: true),
    );
    expect(canceledHtml, contains('canceled-banner'));
    expect(canceledHtml, contains('DOCUMENTO CANCELADO'));

    final configuredHtml = DanfeHtmlRenderer().render(
      document,
      options: DanfeHtmlOptions(
        title: 'VIA CLIENTE',
        quantityDecimals: 2,
        unitPriceDecimals: 3,
        showTaxableUnit: false,
        generateAutomaticInfo: true,
        showPurchaseOrderItem: true,
        showItemTaxDetails: true,
        showItemAdditionalInfo: false,
        showItemTraceability: false,
        showInterstateTaxes: false,
        showPisCofins: true,
        showApproximateTaxes: false,
        epecProtocol: 'EPEC-123',
        epecDate: DateTime.utc(2026, 1, 2),
      ),
    );
    expect(configuredHtml, contains('<h1>VIA CLIENTE</h1>'));
    expect(configuredHtml, contains('<td>1.00</td>'));
    expect(configuredHtml, contains('<td>2.000</td>'));
    expect(configuredHtml, contains('EPEC-123'));
    expect(configuredHtml, contains('Pedido: PED-001'));
    expect(configuredHtml, contains('NF Ref.: série 2 número 3'));
    expect(configuredHtml, contains('ITEM 7'));
    expect(configuredHtml, contains('Tributos aprox.: R\$ 1.25'));
    expect(configuredHtml, isNot(contains('Informação do lote')));
    expect(configuredHtml, isNot(contains('ANVISA')));
    expect(configuredHtml, contains('Class. IBS/CBS: 000001'));
    expect(configuredHtml, contains('RTC IBS/CBS: BC 2.00'));
    expect(configuredHtml, contains('Tributação regular: CST 000'));
    expect(configuredHtml, contains('Compra governamental sem redutor'));
    expect(configuredHtml, contains('Estorno de crédito: IBS 0.06'));
    expect(configuredHtml, contains('Crédito presumido: base 2.00'));
    expect(configuredHtml, contains('Crédito presumido IBS'));
    expect(configuredHtml, contains('Estorno de crédito CBS'));
    expect(configuredHtml, contains('Class. IS: IS0001'));
    expect(
      configuredHtml,
      contains('<h2>Detalhamento IBS / CBS / IS por item</h2>'),
    );
    expect(configuredHtml, contains('IBS/CBS 000001'));
    expect(configuredHtml, contains('IBS UF 1.0000%'));
    expect(configuredHtml, contains('>PIS<'));
    expect(configuredHtml, isNot(contains('Tributos aproximados')));
    expect(configuredHtml, contains('Valor aproximado dos tributos: R\$ 1.25'));
    expect(configuredHtml, isNot(contains('Trib.: 2.00 CX x 1.250')));
  });

  test(
    'renderiza destinatário, classificação, totais, transporte e pagamentos',
    () {
      final document = NfeDocument(
        accessKey: '1' * 44,
        number: 2,
        series: 3,
        issueDate: DateTime.utc(2026, 1, 1),
        environment: 2,
        model: 55,
        authorization: NfeAuthorization(
          protocol: '123456789012345',
          authorizedAt: DateTime.utc(2026, 1, 1, 12, 34, 56),
        ),
        issuer: const Party(
          name: 'Emitente',
          cnpj: '04252011000110',
          fantasyName: 'Loja Emitente',
          ie: '110042490114',
          ieSubstitute: '110000000000',
          municipalRegistration: '1234567',
          cnae: '4711302',
          suframa: '123456789',
          address: 'Rua A',
          addressNumber: '10',
          addressComplement: 'Sala 1',
          neighborhood: 'Centro',
          city: 'Porto Velho',
          state: 'RO',
          phone: '69999999999',
          email: 'emitente@example.test',
        ),
        recipient: const Party(
          name: 'Destinatário',
          cnpj: '11222333000181',
          address: 'Rua B',
          city: 'Ariquemes',
          state: 'RO',
          ie: '123456789',
          phone: '69988888888',
          email: 'destinatario@example.test',
        ),
        items: const [
          NfeItem(
            number: 1,
            code: 'ABC',
            ean: '7891234567895',
            description: 'Produto',
            ncm: '12345678',
            cfop: '5102',
            unit: 'UN',
            quantity: 2,
            unitPrice: 10,
            freight: 1,
            insurance: 0.25,
            discount: 0.5,
            other: 0.75,
            importDuty: 0.3,
            orderNumber: 'PED-1',
            orderItem: 7,
          ),
        ],
        transport: const TransportInfo(
          freightMode: 0,
          carrier: '04252011000110',
          vehiclePlate: 'ABC1D23',
          vehicleState: 'RO',
          carrierName: 'Transportadora Teste',
          retention: TransportTaxRetention(
            serviceValue: 100,
            taxBase: 100,
            rate: 12,
            taxValue: 12,
            cfop: '5353',
            municipalityCode: '1100015',
          ),
          volumes: [
            TransportVolume(quantity: 2, kind: 'CAIXA', seal: ['L1']),
          ],
        ),
        billing: BillingInfo(
          invoiceNumber: 'FAT-1',
          originalValue: 20.5,
          installments: [
            InvoiceInstallment(
              number: '001',
              dueDate: DateTime.utc(2026, 2, 1),
              value: 20.5,
            ),
          ],
        ),
        additionalInfo: const AdditionalInfo(
          complementary: 'Informação complementar',
          taxAuthority: 'Informação do fisco',
        ),
        payments: const [Payment(type: '03', value: 20, description: 'Cartão')],
      );

      final html = DanfeHtmlRenderer().render(document);
      expect(html, contains('Destinatário'));
      expect(html, contains('12345678'));
      expect(html, contains('<td>Produtos</td><td class="number">20.00</td>'));
      expect(html, contains('<td>20.00</td>'));
      expect(html, contains('<td>Seguro</td><td class="number">0.25</td>'));
      expect(html, contains('<td>II</td><td class="number">0.30</td>'));
      expect(html, contains('<td>Outros</td><td class="number">0.75</td>'));
      expect(html, contains('<th>BC ICMS</th>'));
      expect(html, contains('<th>V. ICMS</th>'));
      expect(html, contains('ICMS-ST'));
      expect(html, contains('ABC1D23'));
      expect(html, contains('Cartão'));
      expect(html, contains('Total da nota: 21.80'));
      expect(html, contains('Protocolo de autorização'));
      expect(html, contains('123456789012345'));
      expect(html, contains('01/01/2026 12:34:56'));
      expect(html, contains('FAT-1'));
      expect(html, contains('01/02/2026'));
      expect(html, contains('Informação complementar'));
      expect(html, contains('<h2>Informações complementares</h2>'));
      expect(html, contains('<h2>Reservado ao fisco</h2>'));
      expect(html, contains('Informação do fisco'));
      expect(html, isNot(contains('Fisco: Informação do fisco')));
      expect(html, contains('ICMS retido: 12.00'));
      expect(html, contains('Lacres: L1'));
      expect(html, contains('Fantasia: Loja Emitente'));
      expect(html, contains('IEST: 110000000000'));
      expect(html, contains('IM: 1234567'));
      expect(html, contains('CNAE: 4711302'));
      expect(html, contains('SUFRAMA: 123456789'));
      expect(html, contains('E-mail: emitente@example.test'));
      expect(html, contains('E-mail: destinatario@example.test'));
      expect(html, contains('EAN: 7891234567895'));
      final detailedHtml = DanfeHtmlRenderer().render(
        document,
        options: const DanfeHtmlOptions(showPurchaseOrderItem: true),
      );
      expect(detailedHtml, contains('PED PED-1'));
      expect(detailedHtml, contains('ITEM 7'));
    },
  );

  test('exibe texto de fatura sem duplicatas quando configurado', () {
    final document = NfeDocument(
      accessKey: '3' * 44,
      number: 4,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: const Party(name: 'Empresa', cnpj: '04252011000110'),
      billing: const BillingInfo(invoiceNumber: 'FAT-2', originalValue: 10),
      payments: const [Payment(type: '01', value: 10, indicator: 0)],
      items: const [],
    );

    final html = DanfeHtmlRenderer().render(
      document,
      options: const DanfeHtmlOptions(showBillingText: true),
    );
    expect(html, contains('Pagamento à Vista'));
    expect(html, contains('Fatura: FAT-2'));
    expect(html, contains('Valor Líquido: 10.00'));
  });

  test('não soma item indTot=0 na seção de totais', () {
    final document = NfeDocument(
      accessKey: '2' * 44,
      number: 3,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: const Party(name: 'Empresa', cnpj: '04252011000110'),
      items: const [
        NfeItem(
          number: 1,
          code: 'A',
          description: 'Incluído',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 10,
        ),
        NfeItem(
          number: 2,
          code: 'B',
          description: 'Fora',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 90,
          includeInTotal: false,
        ),
      ],
    );

    final html = DanfeHtmlRenderer().render(document);
    expect(html, contains('<td class="number">10.00</td>'));
    expect(html, contains('Total da nota: 10.00'));
  });

  test('renderiza retirada e tributos da reforma no HTML', () {
    final document = NfeDocument(
      accessKey: '3' * 44,
      number: 4,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 1,
      model: 55,
      issuer: const Party(name: 'Empresa', cnpj: '04252011000110'),
      withdrawal: const NfeLocation(
        street: 'Rua Retirada',
        number: '10',
        neighborhood: 'Centro',
        municipalityCode: '1100205',
        municipality: 'Porto Velho',
        state: 'RO',
      ),
      items: const [
        NfeItem(
          number: 1,
          code: 'RTC',
          description: 'Produto RTC',
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
          ),
          selectiveTax: SelectiveTax(
            cst: '000',
            classificationCode: '000001',
            base: 100,
            rate: 0.3,
          ),
        ),
      ],
    );

    final html = DanfeHtmlRenderer().render(document);

    expect(html, contains('Retirada: Rua Retirada, 10'));
    expect(html, contains('IBS UF'));
    expect(html, contains('IBS município'));
    expect(html, contains('CBS'));
    expect(html, contains('Imposto seletivo'));
  });

  test('renderiza identificação da operação e contingência', () {
    final document = NfeDocument(
      accessKey: '4' * 44,
      number: 5,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 65,
      issuer: const Party(name: 'Empresa', cnpj: '04252011000110'),
      operationNature: 'Venda <varejo>',
      documentType: 1,
      destinationType: 1,
      purpose: 1,
      finalConsumer: 1,
      presenceIndicator: 1,
      processCode: '0',
      applicationVersion: 'FlutterFiscalLIB 1.0',
      contingency: Contingency(
        mode: ContingencyMode.offlineNfce,
        activatedAt: DateTime.utc(2026, 1, 1, 13, 14, 15),
        reason: 'Falha de comunicação com o autorizador',
      ),
      items: const [
        NfeItem(
          number: 1,
          code: 'A',
          description: 'Produto',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 10,
        ),
      ],
    );

    final html = DanfeHtmlRenderer().render(document);

    expect(html, contains('Identificação da operação'));
    expect(html, contains('Venda &lt;varejo&gt;'));
    expect(html, contains('CONTINGÊNCIA'));
    expect(html, contains('tpEmis 9'));
    expect(html, contains('01/01/2026 13:14:15'));
    expect(html, contains('FlutterFiscalLIB 1.0'));
  });

  test('embute QR Code SVG no DANFE HTML de NFC-e', () {
    final document = NfeDocument(
      accessKey: '3' * 44,
      number: 4,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 65,
      issuer: const Party(name: 'Empresa', cnpj: '04252011000110'),
      nfceSupplement: const NfceXmlSupplement(
        qrCode: 'https://sefaz.example.test/qrcode?p=payload',
        keyUrl: 'https://sefaz.example.test/chave',
      ),
      items: const [
        NfeItem(
          number: 1,
          code: 'A',
          description: 'Produto',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 10,
        ),
      ],
    );

    final html = DanfeHtmlRenderer().render(document);

    expect(html, contains('<svg'));
    expect(html, contains('QR Code NFC-e'));
    expect(html, contains('<path fill="#000"'));
  });

  test('renderiza CPF e bloco de emissão avulsa no HTML', () {
    final document = NfeDocument(
      accessKey: '8' * 44,
      number: 5,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: const Party(name: 'Emitente CPF', cpf: '52998224725'),
      items: const [],
      avulsa: const AvulsaInfo(
        cnpj: '04252011000110',
        agency: 'SEFAZ RO',
        registration: 'MAT-1',
        agent: 'Agente Fiscal',
        state: 'RO',
        fiscalOffice: 'Porto Velho',
        revenueDocumentNumber: 'DAR-10',
      ),
    );

    final html = DanfeHtmlRenderer().render(document);
    expect(html, contains('Emitente CPF - 52998224725'));
    expect(html, contains('Emissão avulsa'));
    expect(html, contains('DAR-10'));
  });

  test('inclui IBS e CBS monofásicos nos totais do DANFE', () {
    final document = NfeDocument(
      accessKey: '1' * 44,
      number: 3,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 1,
      model: 55,
      issuer: const Party(name: 'Emitente', cnpj: '04252011000110'),
      items: const [
        NfeItem(
          number: 1,
          code: 'MONO',
          description: 'Combustível',
          ncm: '27101259',
          cfop: '5656',
          unit: 'L',
          quantity: 10,
          unitPrice: 10,
          ibsCbsMonophase: IbsCbsMonophaseTax(
            cst: '620',
            classificationCode: '000001',
            quantity: 10,
            ibsRate: 0.1,
            ibsValue: 1,
            cbsRate: 0.2,
            cbsValue: 2,
          ),
        ),
      ],
    );

    final html = DanfeHtmlRenderer().render(document);
    expect(html, contains('IBS monofásico'));
    expect(html, contains('CBS monofásica'));
    expect(html, contains('>1.00</td>'));
    expect(html, contains('>2.00</td>'));
  });

  test('inclui FCP próprio e FCP-ST nos totais do DANFE', () {
    final document = NfeDocument(
      accessKey: '3' * 44,
      number: 5,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 1,
      model: 55,
      issuer: const Party(name: 'Emitente', cnpj: '04252011000110'),
      items: const [
        NfeItem(
          number: 1,
          code: 'FCP',
          description: 'Produto com FCP',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 10,
          icmsSt: IcmsStTax(
            base: 10,
            rate: 18,
            value: 1.8,
            stBase: 12,
            stRate: 18,
            stValue: 2.16,
            fcpValue: 0.1,
            fcpStValue: 0.2,
          ),
          icmsStRetained: IcmsStRetainedTax(
            origin: 0,
            cst: '60',
            retainedBase: 10,
            retainedValue: 1.8,
            destinationBase: 10,
            destinationValue: 1.8,
            retainedFcpValue: 0.3,
          ),
        ),
      ],
    );

    final html = DanfeHtmlRenderer().render(document);
    expect(html, contains('<td>FCP</td><td class="number">0.10</td>'));
    expect(html, contains('<td>FCP ST</td><td class="number">0.20</td>'));
    expect(
      html,
      contains('<td>FCP ST retido</td><td class="number">0.30</td>'),
    );
  });

  test('inclui ISSQN declarado e retenções federais nos totais', () {
    final document = NfeDocument(
      accessKey: '2' * 44,
      number: 4,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 1,
      model: 55,
      issuer: const Party(name: 'Prestador', cnpj: '04252011000110'),
      serviceTotal: ServiceTotal(
        serviceValue: 100,
        taxBase: 100,
        taxValue: 5,
        competenceDate: DateTime.utc(2026, 1, 1),
      ),
      taxRetention: const TaxRetention(
        pis: 1,
        cofins: 2,
        csll: 3,
        irrf: 4,
        socialSecurity: 5,
      ),
      items: const [],
    );

    final html = DanfeHtmlRenderer().render(document);
    expect(html, contains('ISSQN - Serviços'));
    expect(html, contains('ISSQN declarado'));
    expect(html, contains('>5.00</td>'));
    expect(html, contains('Retenções federais'));
    expect(html, contains('>15.00</td>'));
  });
}
