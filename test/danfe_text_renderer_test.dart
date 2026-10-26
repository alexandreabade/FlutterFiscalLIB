import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';
import 'package:test/test.dart';

void main() {
  test('renderiza DANFE textual com emitente, item e total', () {
    final document = NfeDocument(
      accessKey: AccessKey.fromBase(
        '1100010012345678000199555001000000000110000',
      ).value,
      number: 10,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      issuer: const Party(
        name: 'Empresa Teste',
        fantasyName: 'Loja Teste',
        cnpj: '04252011000110',
        ie: '110042490114',
        address: 'Rua Fiscal',
        addressNumber: '10',
        neighborhood: 'Centro',
        city: 'Porto Velho',
        state: 'RO',
        phone: '69999999999',
        email: 'emitente@example.test',
      ),
      items: const [
        NfeItem(
          number: 1,
          code: 'A1',
          description: 'Produto',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 2,
          unitPrice: 7.5,
          freight: 1,
          discount: 0.5,
          additionalInformation: 'Lote demonstrativo',
          approximateTaxValue: 2.25,
        ),
      ],
    );

    final output = DanfeTextRenderer().render(document);
    expect(output, contains('DANFE - DOCUMENTO AUXILIAR DA NF-E'));
    expect(output, contains('SEM VALOR FISCAL - AMBIENTE DE HOMOLOGAÇÃO'));
    expect(output, contains('Produto'));
    expect(output, contains('Lote demonstrativo'));
    expect(output, contains('TRIBUTOS APROXIMADOS DO ITEM: 2.25'));
    expect(output, contains('| 7.50 | 15.00'));
    expect(output, contains('TOTAL DA NOTA: 15.50'));
    expect(output, contains('FANTASIA: Loja Teste'));
    expect(output, contains('IE EMITENTE: 110042490114'));
    expect(output, contains('E-MAIL EMITENTE: emitente@example.test'));
  });

  test('renderiza QR Code e URL no DANFE NFC-e', () {
    final document = NfeDocument(
      accessKey: AccessKey.fromComponents(
        cUf: '11',
        issueDate: DateTime.utc(2026, 1, 1),
        cnpj: '04252011000110',
        model: 65,
        series: 1,
        number: 1,
        tpEmis: 1,
        cNf: '12345678',
      ).value,
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

    final output = DanfeTextRenderer().render(document);
    expect(output, contains('QR CODE NFC-e: https://example.test/qrcode'));
    expect(output, contains('URL DA CHAVE: https://example.test/chave'));
  });

  test('renderiza consumidor, pagamentos detalhados e troco', () {
    final document = NfeDocument(
      accessKey: '7' * 44,
      number: 5,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 1,
      model: 65,
      issuer: const Party(name: 'Empresa', cnpj: '04252011000110'),
      recipient: const Party(
        name: 'Consumidor Final',
        cpf: '52998224725',
        city: 'Porto Velho',
        state: 'RO',
      ),
      payments: const [Payment(type: '03', value: 12, description: 'Cartão')],
      changeValue: 2,
      items: const [],
    );

    final output = DanfeTextRenderer().render(document);
    expect(output, contains('MUNICÍPIO DESTINATÁRIO: Porto Velho/RO'));
    expect(output, contains('03 - Cartão: 12.00'));
    expect(output, contains('TROCO: 2.00'));
  });

  test('renderiza locais fiscais e tributos da reforma no texto', () {
    final document = NfeDocument(
      accessKey: '8' * 44,
      number: 4,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 1,
      model: 55,
      issuer: const Party(name: 'Empresa', cnpj: '04252011000110'),
      delivery: const NfeLocation(
        street: 'Avenida Entrega',
        number: '20',
        neighborhood: 'Industrial',
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

    final output = DanfeTextRenderer().render(document);

    expect(output, contains('ENTREGA: Avenida Entrega, 20'));
    expect(output, contains('IBS UF: 0.10'));
    expect(output, contains('IBS MUNICIPAL: 0.20'));
    expect(output, contains('CBS: 0.90'));
    expect(output, contains('IMPOSTO SELETIVO: 0.30'));
  });

  test('preserva CPF e emissão avulsa na saída textual', () {
    final document = NfeDocument(
      accessKey: '9' * 44,
      number: 3,
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

    final output = DanfeTextRenderer().render(document);
    expect(output, contains('EMITENTE: Emitente CPF - 52998224725'));
    expect(output, contains('EMISSÃO AVULSA: Órgão SEFAZ RO'));
  });

  test('renderiza IBS e CBS monofásicos no item', () {
    final document = NfeDocument(
      accessKey: '7' * 44,
      number: 6,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 1,
      model: 55,
      issuer: const Party(name: 'Emitente', cnpj: '04252011000110'),
      items: const [
        NfeItem(
          number: 1,
          code: 'MONO',
          description: 'Produto monofásico',
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

    final output = DanfeTextRenderer().render(document);
    expect(output, contains('IBS MONOFÁSICO: 1.00'));
    expect(output, contains('CBS MONOFÁSICA: 2.00'));
  });

  test('renderiza ISSQN declarado e retenções federais', () {
    final document = NfeDocument(
      accessKey: '6' * 44,
      number: 7,
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

    final output = DanfeTextRenderer().render(document);
    expect(output, contains('ISSQN DECLARADO: 5.00'));
    expect(output, contains('RETENÇÕES FEDERAIS: 15.00'));
  });
}
