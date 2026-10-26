import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';
import 'package:test/test.dart';

void main() {
  test('gera PDF A4 imprimível para DANFE', () async {
    final key = AccessKey.fromComponents(
      cUf: '11',
      issueDate: DateTime.utc(2026, 1, 1),
      cnpj: '04.252.011/0001-10',
      model: 55,
      series: 1,
      number: 1,
      tpEmis: 1,
      cNf: '12345678',
    ).value;
    final document = NfeDocument(
      accessKey: key,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: const Party(name: 'Empresa de Teste', cnpj: '04.252.011/0001-10'),
      purchaseInfo: const PurchaseInfo(order: 'PED-001'),
      billing: const BillingInfo(invoiceNumber: 'FAT-1', originalValue: 10),
      payments: const [Payment(type: '01', value: 10, indicator: 0)],
      items: [
        NfeItem(
          number: 1,
          code: 'ABC',
          description: 'Produto fiscal',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 10,
          tribUnit: 'CX',
          tribQuantity: 2,
          tribUnitPrice: 5,
          orderNumber: 'PED-1',
          orderItem: 7,
          approximateTaxValue: 1.5,
          icms: const IcmsTax(cst: '00', base: 10, rate: 18, value: 1.8),
          icmsUfDestination: const IcmsUfDestinationTax(
            base: 10,
            destinationRate: 18,
            interstateRate: 12,
            partitionRate: 100,
            destinationValue: 2,
            originValue: 1,
            fcpValue: 0.2,
          ),
          ipi: const IpiTax(
            enquadramento: '999',
            cst: '50',
            base: 10,
            rate: 5,
            value: 0.5,
          ),
          pis: const PisTax(cst: '01', base: 10, rate: 1.65, value: 0.17),
          cofins: const CofinsTax(cst: '01', base: 10, rate: 7.6, value: 0.76),
        ),
      ],
    );

    final bytes = await DanfePdfRenderer().render(document);
    final withoutStub = await DanfePdfRenderer().render(
      document,
      options: const DanfePdfOptions(showReceiptStub: false),
    );
    final canceled = await DanfePdfRenderer().render(
      document,
      options: const DanfePdfOptions(canceled: true),
    );
    final landscape = await DanfePdfRenderer().render(
      document,
      layout: DanfePdfLayout.a4Landscape,
    );
    final configured = await DanfePdfRenderer().render(
      document,
      options: DanfePdfOptions(
        showPisCofins: true,
        showApproximateTaxes: false,
        showItemAdditionalInfo: false,
        showTaxableUnit: false,
        generateAutomaticInfo: true,
        showBillingText: true,
        showPurchaseOrderItem: true,
        showItemTaxDetails: true,
        showInterstateTaxes: false,
        showRecipientEmail: false,
      ),
    );

    expect(bytes.take(5).toList(), [0x25, 0x50, 0x44, 0x46, 0x2D]);
    expect(bytes.length, greaterThan(1000));
    expect(bytes.length, greaterThan(withoutStub.length));
    expect(canceled.length, greaterThan(bytes.length));
    expect(landscape.take(5).toList(), [0x25, 0x50, 0x44, 0x46, 0x2D]);
    expect(landscape.length, greaterThan(1000));
    expect(configured.length, greaterThan(1000));
  });

  test('separa informações complementares do reservado ao fisco', () async {
    final document = NfeDocument(
      accessKey: '1' * 44,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: const Party(name: 'Empresa de Teste', cnpj: '04252011000110'),
      items: const [],
      additionalInfo: const AdditionalInfo(
        complementary: 'Informação complementar',
        taxAuthority: 'Informação do fisco',
      ),
    );

    final bytes = await DanfePdfRenderer().render(document);
    expect(bytes.take(5).toList(), [0x25, 0x50, 0x44, 0x46, 0x2D]);
    expect(bytes.length, greaterThan(1000));
  });

  test('aceita opções de apresentação compatíveis com o sped-da', () async {
    final document = NfeDocument(
      accessKey: '1' * 44,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: const Party(name: 'Empresa de Teste', cnpj: '04252011000110'),
      items: [
        const NfeItem(
          number: 1,
          code: 'A',
          description: 'Produto',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1.25,
          unitPrice: 1.2345,
        ),
      ],
      additionalInfo: const AdditionalInfo(
        contributorObservations: [
          AdditionalObservation(field: 'PED', text: 'não exibir'),
        ],
        fiscalObservations: [
          AdditionalObservation(field: 'FIS', text: 'exibir'),
        ],
      ),
    );
    final bytes = await DanfePdfRenderer().render(
      document,
      options: DanfePdfOptions(
        title: 'VIA CLIENTE',
        quantityDecimals: 2,
        unitPriceDecimals: 3,
        showContributorObservations: false,
        showFiscalObservations: true,
        useDashedItemSeparators: false,
        epecProtocol: 'EPEC-123',
        epecDate: DateTime.utc(2026, 1, 2),
      ),
    );
    expect(bytes.take(5).toList(), [0x25, 0x50, 0x44, 0x46, 0x2D]);
    expect(bytes.length, greaterThan(1000));
  });

  test('marca ambiente de homologação no DANFE', () async {
    final key = AccessKey.fromComponents(
      cUf: '11',
      issueDate: DateTime.utc(2026, 1, 1),
      cnpj: '04252011000110',
      model: 55,
      series: 1,
      number: 1,
      tpEmis: 1,
      cNf: '12345678',
    ).value;
    final document = NfeDocument(
      accessKey: key,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: const Party(name: 'Empresa de Teste', cnpj: '04252011000110'),
      items: const [
        NfeItem(
          number: 1,
          code: 'A1',
          description: 'Produto',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 5,
        ),
      ],
    );
    final bytes = await DanfePdfRenderer().render(
      document,
      options: const DanfePdfOptions(showReceiptStub: false),
    );
    expect(bytes, isNotEmpty);
  });

  test('destaca contingência no DANFE A4', () async {
    final document = NfeDocument(
      accessKey: '2' * 44,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1, 12),
      environment: 2,
      model: 55,
      issuer: const Party(name: 'Empresa de Teste', cnpj: '04252011000110'),
      items: const [],
      contingency: Contingency(
        mode: ContingencyMode.fsDa,
        activatedAt: DateTime.utc(2026, 1, 1, 12),
        reason: 'Indisponibilidade temporária do serviço autorizador',
      ),
    );
    final bytes = await DanfePdfRenderer().render(
      document,
      options: const DanfePdfOptions(showReceiptStub: false),
    );
    expect(bytes.take(5).toList(), [0x25, 0x50, 0x44, 0x46, 0x2D]);
    expect(bytes.length, greaterThan(1000));
  });

  test(
    'renderiza identificação fiscal completa de emitente e destinatário',
    () async {
      final key = AccessKey.fromComponents(
        cUf: '11',
        issueDate: DateTime.utc(2026, 1, 1),
        cnpj: '04252011000110',
        model: 55,
        series: 1,
        number: 2,
        tpEmis: 1,
        cNf: '12345678',
      ).value;
      final document = NfeDocument(
        accessKey: key,
        number: 2,
        series: 1,
        issueDate: DateTime.utc(2026, 1, 1),
        environment: 1,
        model: 55,
        issuer: const Party(
          name: 'Empresa Completa',
          fantasyName: 'Loja Completa',
          cnpj: '04252011000110',
          ie: '110042490114',
          ieSubstitute: '110000000000',
          municipalRegistration: '1234567',
          cnae: '4711302',
          suframa: '123456789',
          address: 'Rua Fiscal',
          addressNumber: '100',
          addressComplement: 'Sala 2',
          neighborhood: 'Centro',
          city: 'Porto Velho',
          state: 'RO',
          zipCode: '76801000',
          phone: '69999999999',
          email: 'emitente@example.test',
        ),
        recipient: const Party(
          name: 'Destinatário Completo',
          cnpj: '11222333000181',
          ie: '123456789',
          address: 'Avenida Destino',
          addressNumber: '200',
          addressComplement: 'Casa',
          neighborhood: 'Bairro',
          city: 'Ariquemes',
          state: 'RO',
          zipCode: '76870000',
          phone: '69988888888',
          email: 'destinatario@example.test',
        ),
        items: const [
          NfeItem(
            number: 1,
            code: 'A1',
            description: 'Produto',
            ncm: '12345678',
            cfop: '5102',
            unit: 'UN',
            quantity: 1,
            unitPrice: 5,
          ),
        ],
      );

      final bytes = await DanfePdfRenderer().render(document);
      expect(bytes.length, greaterThan(1000));
    },
  );

  test('mantém identificação nas páginas de continuação do DANFE A4', () async {
    final key = AccessKey.fromComponents(
      cUf: '11',
      issueDate: DateTime.utc(2026, 1, 1),
      cnpj: '04252011000110',
      model: 55,
      series: 1,
      number: 1,
      tpEmis: 1,
      cNf: '12345678',
    ).value;
    final document = NfeDocument(
      accessKey: key,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: const Party(name: 'Empresa de Teste', cnpj: '04252011000110'),
      items: [
        for (var number = 1; number <= 90; number++)
          NfeItem(
            number: number,
            code: 'ITEM-$number',
            description: 'Produto fiscal com descrição para paginação $number',
            ncm: '12345678',
            cfop: '5102',
            unit: 'UN',
            quantity: 1,
            unitPrice: 10,
          ),
      ],
    );

    final bytes = await DanfePdfRenderer().render(document);
    expect(bytes.length, greaterThan(10000));
  });

  test('renderiza locais fiscais e tributos da reforma no DANFE A4', () async {
    final key = AccessKey.fromComponents(
      cUf: '11',
      issueDate: DateTime.utc(2026, 1, 1),
      cnpj: '04252011000110',
      model: 55,
      series: 1,
      number: 3,
      tpEmis: 1,
      cNf: '12345678',
    ).value;
    final document = NfeDocument(
      accessKey: key,
      number: 3,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 1,
      model: 55,
      issuer: const Party(name: 'Empresa Fiscal', cnpj: '04252011000110'),
      withdrawal: const NfeLocation(
        name: 'Depósito de retirada',
        street: 'Rua da Retirada',
        number: '10',
        neighborhood: 'Centro',
        municipalityCode: '1100205',
        municipality: 'Porto Velho',
        state: 'RO',
      ),
      delivery: const NfeLocation(
        street: 'Avenida da Entrega',
        number: '20',
        neighborhood: 'Industrial',
        municipalityCode: '1100205',
        municipality: 'Porto Velho',
        state: 'RO',
      ),
      items: const [
        NfeItem(
          number: 1,
          code: 'RTC-001',
          description: 'Produto com IBS, CBS e IS',
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
            ibsMunicipalRate: 0.1,
            cbsRate: 0.9,
          ),
          selectiveTax: SelectiveTax(
            cst: '000',
            classificationCode: '000001',
            base: 100,
            rate: 0.2,
          ),
        ),
      ],
    );

    final bytes = await DanfePdfRenderer().render(document);

    expect(bytes.take(5).toList(), [0x25, 0x50, 0x44, 0x46, 0x2D]);
    expect(bytes.length, greaterThan(1000));
  });

  test(
    'renderiza quadro detalhado de ISSQN para serviços no DANFE A4',
    () async {
      final key = AccessKey.fromComponents(
        cUf: '11',
        issueDate: DateTime.utc(2026, 1, 1),
        cnpj: '04252011000110',
        model: 55,
        series: 1,
        number: 4,
        tpEmis: 1,
        cNf: '12345678',
      ).value;
      final base = NfeDocument(
        accessKey: key,
        number: 4,
        series: 1,
        issueDate: DateTime.utc(2026, 1, 1),
        environment: 1,
        model: 55,
        issuer: const Party(name: 'Prestadora Fiscal', cnpj: '04252011000110'),
        items: [
          NfeItem(
            number: 1,
            code: 'SERV-001',
            description: 'Serviço tributado pelo ISSQN',
            ncm: '12345678',
            cfop: '5933',
            unit: 'UN',
            quantity: 1,
            unitPrice: 100,
            serviceTax: ServiceTax(
              base: 100,
              rate: 2,
              value: 2,
              municipalityCode: '1100205',
              serviceListCode: '01.01',
              competenceDate: DateTime.utc(2026, 1, 1),
              retained: 1,
              serviceCode: 'SERV-01',
            ),
          ),
        ],
      );
      final servicePdf = await DanfePdfRenderer().render(base);

      expect(servicePdf.take(5).toList(), [0x25, 0x50, 0x44, 0x46, 0x2D]);
      expect(servicePdf.length, greaterThan(1000));
    },
  );

  test('gera QR Code no PDF de NFC-e quando há suplemento', () async {
    final key = AccessKey.fromComponents(
      cUf: '11',
      issueDate: DateTime.utc(2026, 1, 1),
      cnpj: '04252011000110',
      model: 65,
      series: 1,
      number: 1,
      tpEmis: 1,
      cNf: '12345678',
    ).value;
    final document = NfeDocument(
      accessKey: key,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 65,
      issuer: const Party(name: 'Empresa Teste', cnpj: '04252011000110'),
      nfceSupplement: const NfceXmlSupplement(
        qrCode: 'https://example.test/qrcode?p=x',
        keyUrl: 'https://example.test/chave',
      ),
      items: const [
        NfeItem(
          number: 1,
          code: 'A1',
          description: 'Produto',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 5,
        ),
      ],
    );

    final bytes = await DanfePdfRenderer().render(document);
    expect(bytes.take(5).toList(), [0x25, 0x50, 0x44, 0x46, 0x2D]);
  });

  test('gera DANFE NFC-e em bobina térmica de 80 mm', () async {
    final key = AccessKey.fromComponents(
      cUf: '11',
      issueDate: DateTime.utc(2026, 1, 1),
      cnpj: '04252011000110',
      model: 65,
      series: 1,
      number: 1,
      tpEmis: 1,
      cNf: '12345678',
    ).value;
    final document = NfeDocument(
      accessKey: key,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 65,
      issuer: const Party(name: 'Empresa Teste', cnpj: '04252011000110'),
      nfceSupplement: const NfceXmlSupplement(
        qrCode: 'https://example.test/qrcode?p=x',
        keyUrl: 'https://example.test/chave',
      ),
      items: const [
        NfeItem(
          number: 1,
          code: 'A1',
          description: 'Produto térmico',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 5,
        ),
      ],
    );

    final bytes = await DanfePdfRenderer().render(
      document,
      layout: DanfePdfLayout.nfceThermal80,
    );
    expect(bytes.take(5).toList(), [0x25, 0x50, 0x44, 0x46, 0x2D]);
    expect(bytes.length, greaterThan(1000));
  });

  test('rejeita layout térmico para NF-e modelo 55', () async {
    final key = AccessKey.fromComponents(
      cUf: '11',
      issueDate: DateTime.utc(2026, 1, 1),
      cnpj: '04252011000110',
      model: 55,
      series: 1,
      number: 1,
      tpEmis: 1,
      cNf: '12345678',
    ).value;
    final document = NfeDocument(
      accessKey: key,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: const Party(name: 'Empresa Teste', cnpj: '04252011000110'),
      items: const [
        NfeItem(
          number: 1,
          code: 'A1',
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
      () => DanfePdfRenderer().render(
        document,
        layout: DanfePdfLayout.nfceThermal80,
      ),
      throwsA(isA<FiscalValidationException>()),
    );
  });

  test('ajusta o comprimento térmico para muitos itens', () async {
    final key = AccessKey.fromComponents(
      cUf: '11',
      issueDate: DateTime.utc(2026, 1, 1),
      cnpj: '04252011000110',
      model: 65,
      series: 1,
      number: 1,
      tpEmis: 1,
      cNf: '12345678',
    ).value;
    final document = NfeDocument(
      accessKey: key,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 65,
      issuer: const Party(name: 'Empresa Teste', cnpj: '04252011000110'),
      items: List.generate(
        80,
        (index) => NfeItem(
          number: index + 1,
          code: 'ITEM-${index + 1}',
          description:
              'Produto com descrição extensa para validar a quebra de linha na bobina NFC-e',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 5,
        ),
      ),
    );

    final bytes = await DanfePdfRenderer().render(
      document,
      layout: DanfePdfLayout.nfceThermal80,
    );

    expect(bytes.take(5).toList(), [0x25, 0x50, 0x44, 0x46, 0x2D]);
    expect(bytes.length, greaterThan(1000));
  });

  test(
    'gera continuação A4 com rodapé de paginação para muitos itens',
    () async {
      final key = AccessKey.fromComponents(
        cUf: '11',
        issueDate: DateTime.utc(2026, 1, 1),
        cnpj: '04252011000110',
        model: 55,
        series: 1,
        number: 1,
        tpEmis: 1,
        cNf: '12345678',
      ).value;
      final document = NfeDocument(
        accessKey: key,
        number: 1,
        series: 1,
        issueDate: DateTime.utc(2026, 1, 1),
        environment: 2,
        model: 55,
        issuer: const Party(name: 'Empresa Teste', cnpj: '04252011000110'),
        items: List.generate(
          80,
          (index) => NfeItem(
            number: index + 1,
            code: 'ITEM-${index + 1}',
            description: 'Produto extenso para gerar páginas de continuação',
            ncm: '12345678',
            cfop: '5102',
            unit: 'UN',
            quantity: 1,
            unitPrice: 5,
          ),
        ),
      );

      final bytes = await DanfePdfRenderer().render(document);

      expect(bytes.take(5).toList(), [0x25, 0x50, 0x44, 0x46, 0x2D]);
      expect(bytes.length, greaterThan(5000));
    },
  );

  test('aplica opções de apresentação do DANFE NFC-e', () async {
    final document = NfeDocument(
      accessKey: '5' * 44,
      number: 2,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 65,
      issuer: const Party(name: 'Empresa Teste', cnpj: '04252011000110'),
      items: const [
        NfeItem(
          number: 1,
          code: 'A1',
          description: 'Produto',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 5,
        ),
      ],
    );
    const options = DanfePdfOptions(
      paperWidthMm: 58,
      marginMm: 2,
      printSummary: true,
      establishmentCopy: true,
      canceled: true,
      offlineDoublePrint: true,
      showItemTraceability: false,
      extraContent: 'Documento de demonstração',
    );

    final bytes = await DanfePdfRenderer().render(
      document,
      layout: DanfePdfLayout.nfceThermal80,
      options: options,
    );

    expect(bytes.take(5).toList(), [0x25, 0x50, 0x44, 0x46, 0x2D]);
    expect(bytes.length, greaterThan(1000));
  });

  test('gera segunda via do DANFE NFC-e offline quando configurada', () async {
    final document = NfeDocument(
      accessKey: '8' * 44,
      number: 9,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 65,
      issuer: const Party(name: 'Emitente offline', cnpj: '04252011000110'),
      contingency: Contingency(
        mode: ContingencyMode.offlineNfce,
        activatedAt: DateTime.utc(2026, 1, 1, 10),
        reason: 'Indisponibilidade temporária do serviço autorizador',
      ),
      items: const [],
    );
    final single = await DanfePdfRenderer().render(
      document,
      layout: DanfePdfLayout.nfceThermal80,
    );
    final doubleCopy = await DanfePdfRenderer().render(
      document,
      layout: DanfePdfLayout.nfceThermal80,
      options: const DanfePdfOptions(offlineDoublePrint: true),
    );

    expect(doubleCopy.length, greaterThan(single.length));
  });

  test('gera PDF com CPF e emissão avulsa', () async {
    final document = NfeDocument(
      accessKey: '7' * 44,
      number: 6,
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
      ),
    );

    final bytes = await DanfePdfRenderer().render(document);
    expect(bytes.take(5).toList(), [0x25, 0x50, 0x44, 0x46, 0x2D]);
    expect(bytes.length, greaterThan(1000));
  });

  test('aceita fonte TTF fornecida pela aplicação', () async {
    final document = NfeDocument(
      accessKey: '6' * 44,
      number: 7,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: const Party(name: 'Emitente São José', cnpj: '04252011000110'),
      items: const [],
    );

    // Cabeçalho mínimo de TrueType: a validação completa pertence ao pacote
    // PDF; este teste confirma que a opção é encaminhada sem mutar o buffer.
    final fontBytes = Uint8List.fromList([0, 1, 0, 0]);
    await expectLater(
      DanfePdfRenderer().render(
        document,
        options: DanfePdfOptions(fontBytes: fontBytes),
      ),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'INVALID_DANFE_FONT',
        ),
      ),
    );
  });

  test('renderiza logotipo e respeita margem A4 configurável', () async {
    final document = NfeDocument(
      accessKey: '7' * 44,
      number: 8,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: const Party(name: 'Emitente com logo', cnpj: '04252011000110'),
      items: const [],
    );
    final logo = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );

    final bytes = await DanfePdfRenderer().render(
      document,
      options: DanfePdfOptions(
        logoBytes: Uint8List.fromList(logo),
        a4MarginMm: 8,
      ),
    );
    expect(bytes.take(5).toList(), [0x25, 0x50, 0x44, 0x46, 0x2D]);
  });
}
