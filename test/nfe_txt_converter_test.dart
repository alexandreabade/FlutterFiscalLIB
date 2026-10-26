import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';
import 'package:test/test.dart';

String _record(List<String> values) => [...values, ''].join('|');

String _minimalTxt({String itemTotal = '10'}) => [
  _record(['NOTAFISCAL', '1']),
  _record(['A', '4.00', 'NFe123', '1']),
  _record([
    'B',
    '11',
    '12345678',
    'VENDA',
    '55',
    '1',
    '8',
    '2026-01-01T12:00:00-04:00',
    '',
    '1',
    '1',
    '1100015',
    '1',
    '1',
    '',
    '2',
    '1',
    '0',
    '1',
    '0',
    '0',
    '1',
    '',
    '',
  ]),
  _record(['C', 'Emitente', '', '', '', '', '', '']),
  _record(['C02', '04252011000110']),
  _record(['E', 'Destinatário', '', '', '', '', '']),
  _record(['E02', '11222333000181']),
  _record(['H', '1', 'Informação do item']),
  _record([
    'I',
    'SKU-1',
    'SEM GTIN',
    'Produto',
    '12345678',
    '',
    '',
    '5102',
    'UN',
    '2',
    '5',
    itemTotal,
    'SEM GTIN',
    'UN',
    '2',
    '5',
    '',
    '',
    '',
    '',
    '1',
    '',
    '',
    '',
  ]),
].join('\n');

void main() {
  test('converte TXT 4.00 básico para XML fiscal', () {
    final xml = NfeTxtConverter().parse(_minimalTxt()).single;

    expect(xml, contains('<natOp>VENDA</natOp>'));
    expect(xml, contains('<CNPJ>04252011000110</CNPJ>'));
    expect(xml, contains('<xProd>Produto</xProd>'));
    expect(xml, contains('<infAdProd>Informação do item</infAdProd>'));
    expect(xml, contains('<qCom>2.0000</qCom>'));
  });

  test('converte a base histórica TXT SEBRAE do NFePHP', () {
    final rows = _minimalTxt().split('\n');
    rows[1] = _record(['A', '4.00', 'NFe123']);
    final header = rows[2].split('|')..removeAt(19);
    rows[2] = header.join('|');
    final product = rows[8].split('|')..removeAt(5);
    rows[8] = product.join('|');
    rows.add(_record(['YA01', '0', '03', '10.00']));
    rows.add(_record(['YA04', '1', '04252011000110', '01', 'AUTH-1']));

    final xml = NfeTxtConverter(
      layout: NfeTxtLayout.sebrae400(),
    ).parse(rows.join('\n')).single;

    expect(xml, contains('<tPag>03</tPag>'));
    expect(xml, contains('<vPag>10.00</vPag>'));
    expect(xml, contains('<tpIntegra>1</tpIntegra>'));
    expect(xml, contains('<CNPJ>04252011000110</CNPJ>'));
    expect(xml, contains('<cAut>AUTH-1</cAut>'));
  });

  test('converte dhSaiEnt do cabeçalho TXT', () {
    final txt = _minimalTxt().replaceFirst(
      '|2026-01-01T12:00:00-04:00||1|',
      '|2026-01-01T12:00:00-04:00|2026-01-01T13:00:00-04:00|1|',
    );

    final xml = NfeTxtConverter().parse(txt).single;
    expect(xml, contains('<dhSaiEnt>2026-01-01T17:00:00+00:00</dhSaiEnt>'));
  });

  test('converte indicador e cadastro do intermediador no TXT', () {
    final txt =
        '${_minimalTxt().replaceFirst('|2|1|0|1|0|0|1|||', '|2|1|0|1|1|0|1|||')}\n${_record(['YB', '04252011000110', 'MARKET-1'])}';

    final xml = NfeTxtConverter().parse(txt).single;
    expect(xml, contains('<indIntermed>1</indIntermed>'));
    expect(xml, contains('<procEmi>0</procEmi>'));
    expect(xml, contains('<verProc>1</verProc>'));
    expect(xml, contains('<infIntermed>'));
    expect(xml, contains('<idCadIntTran>MARKET-1</idCadIntTran>'));
  });

  test('aceita cabeçalho B legado sem indIntermed', () {
    final txt = _minimalTxt().replaceFirst(
      '|2|1|0|1|0|0|1|||',
      '|2|1|0|1|0|1|||',
    );

    final xml = NfeTxtConverter().parse(txt).single;

    expect(xml, contains('<procEmi>0</procEmi>'));
    expect(xml, contains('<verProc>1</verProc>'));
    expect(xml, isNot(contains('<indIntermed>')));
  });

  test('converte emitente CPF do registro C02A e preenche a chave', () {
    final txt = _minimalTxt()
        .replaceFirst('C02|04252011000110|', 'C02A|52998224725|')
        .replaceFirst('C02A|52998224725|', 'C02A|52998224725|');

    final xml = NfeTxtConverter().parse(txt).single;

    expect(xml, contains('<CPF>52998224725</CPF>'));
    expect(xml, contains('00052998224725'));
  });

  test('converte autorizações autXML e RECOPI dos registros GA/LB', () {
    final txt = [
      _minimalTxt(),
      _record(['GA']),
      _record(['GA02', '04252011000110']),
      _record(['GA03', '12345678909']),
      _record(['LB', '12345678901234567890']),
    ].join('\n');

    final xml = NfeTxtConverter().parse(txt).single;

    expect(xml, contains('<autXML>'));
    expect(xml, contains('<CNPJ>04252011000110</CNPJ>'));
    expect(xml, contains('<CPF>12345678909</CPF>'));
    expect(xml, contains('<nRECOPI>12345678901234567890</nRECOPI>'));
  });

  test('converte exportação, compra e aquisição de cana dos grupos Z', () {
    final txt = [
      _minimalTxt(),
      _record(['ZA', 'RO', 'Porto de Santos', 'Armazém 1']),
      _record(['ZB', 'EMP-1', 'PED-2', 'CONT-3']),
      _record(['ZC', '2026', '01/2026', '10', '20', '30', '40', '5', '35']),
      _record(['ZC04', '1', '2.5']),
      _record(['ZC10', 'Frete', '5']),
    ].join('\n');

    final xml = NfeTxtConverter().parse(txt).single;

    expect(xml, contains('<exporta>'));
    expect(xml, contains('<UFSaidaPais>RO</UFSaidaPais>'));
    expect(xml, contains('<compra>'));
    expect(xml, contains('<xNEmp>EMP-1</xNEmp>'));
    expect(xml, contains('<cana>'));
    expect(xml, contains('<forDia dia="1">'));
    expect(xml, contains('<deduc>'));
    expect(xml, contains('<vLiqFor>35.00</vLiqFor>'));
  });

  test('converte responsável técnico e suplemento QR Code da NFC-e', () {
    final technicalXml = NfeTxtConverter()
        .parse(
          [
            _minimalTxt(),
            _record([
              'ZD',
              '04252011000110',
              'Suporte Fiscal',
              'suporte@example.com',
              '69999999999',
              'HASH-CSRT',
              '01',
            ]),
          ].join('\n'),
        )
        .single;
    final nfceXml = NfeTxtConverter()
        .parse(
          [
            _minimalTxt().replaceFirst('|55|', '|65|'),
            _record(['ZX01', 'https://qr.example/abc', 'https://nfe.example']),
          ].join('\n'),
        )
        .single;

    expect(technicalXml, contains('<infRespTec>'));
    expect(technicalXml, contains('<idCSRT>01</idCSRT>'));
    expect(technicalXml, contains('<hashCSRT>HASH-CSRT</hashCSRT>'));
    expect(nfceXml, contains('<infNFeSupl>'));
    expect(nfceXml, contains('<qrCode>https://qr.example/abc</qrCode>'));
    expect(nfceXml, contains('<urlChave>https://nfe.example</urlChave>'));
  });

  test('converte NVE, CEST e escala do produto no TXT', () {
    final txt = [
      _minimalTxt(),
      _record(['I05A', 'NVE123']),
      _record(['I05C', '1234567', 'N', '04252011000110']),
    ].join('\n');

    final xml = NfeTxtConverter().parse(txt).single;

    expect(xml, contains('<NVE>NVE123</NVE>'));
    expect(xml, contains('<CEST>1234567</CEST>'));
    expect(xml, contains('<indEscala>N</indEscala>'));
    expect(xml, contains('<CNPJFab>04252011000110</CNPJFab>'));
  });

  test('converte o valor aproximado de tributos do registro M', () {
    final xml = NfeTxtConverter()
        .parse('${_minimalTxt()}\n${_record(['M', '2.35'])}')
        .single;

    expect(xml, contains('<vTotTrib>2.35</vTotTrib>'));
  });

  test('converte medicamento do registro K', () {
    final txt = [
      _minimalTxt(),
      _record(['K', '1234567890123', '19.90', 'Motivo de isenção']),
    ].join('\n');

    final xml = NfeTxtConverter().parse(txt).single;

    expect(xml, contains('<cProdANVISA>1234567890123</cProdANVISA>'));
    expect(xml, contains('<vPMC>19.90</vPMC>'));
    expect(xml, contains('<xMotivoIsencao>Motivo de isenção</xMotivoIsencao>'));
  });

  test('converte combustível, CIDE e encerrante dos registros LA', () {
    final txt = [
      _minimalTxt(),
      _record([
        'LA',
        '123456789',
        'Gasolina C',
        '70',
        '10',
        '20',
        '5',
        'COD',
        '30',
        'RO',
      ]),
      _record(['LA07', '2', '0.10', '0.20']),
      _record(['LA11', '3', '2', '4', '100.123', '110.456']),
    ].join('\n');

    final xml = NfeTxtConverter().parse(txt).single;

    expect(xml, contains('<cProdANP>123456789</cProdANP>'));
    expect(xml, contains('<UFCons>RO</UFCons>'));
    expect(xml, contains('<qBCProd>2.0000</qBCProd>'));
    expect(xml, contains('<nBico>3</nBico>'));
    expect(xml, contains('<vEncFin>110.456</vEncFin>'));
  });

  test('converte rastreabilidade de lote do registro I80', () {
    final txt = [
      _minimalTxt(),
      _record(['I80', 'LOTE-42', '1.5', '2026-01-02', '2027-01-02', 'AG-1']),
    ].join('\n');

    final xml = NfeTxtConverter().parse(txt).single;

    expect(xml, contains('<rastro>'));
    expect(xml, contains('<nLote>LOTE-42</nLote>'));
    expect(xml, contains('<qLote>1.500</qLote>'));
    expect(xml, contains('<cAgreg>AG-1</cAgreg>'));
  });

  test('converte declaração e adição de importação dos registros I18/I25', () {
    final txt = [
      _minimalTxt(),
      _record([
        'I18',
        'DI-2026-001',
        '2026-01-03',
        'Porto de Santos',
        'SP',
        '2026-01-04',
        '1',
        '10.00',
        '1',
        '04252011000110',
        'SP',
        'EXP-01',
      ]),
      _record(['I25', '1', '1', 'FAB-01', '2.50', 'DRAW-1']),
    ].join('\n');

    final xml = NfeTxtConverter().parse(txt).single;

    expect(xml, contains('<DI>'));
    expect(xml, contains('<nDI>DI-2026-001</nDI>'));
    expect(xml, contains('<adi>'));
    expect(xml, contains('<cFabricante>FAB-01</cFabricante>'));
    expect(xml, contains('<nDraw>DRAW-1</nDraw>'));
  });

  test('converte exportação individual dos registros I50/I52', () {
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
    final txt = [
      _minimalTxt(),
      _record(['I50', 'DRAW-2']),
      _record(['I52', '123456789', key, '1.25']),
    ].join('\n');

    final xml = NfeTxtConverter().parse(txt).single;

    expect(xml, contains('<detExport>'));
    expect(xml, contains('<nDraw>DRAW-2</nDraw>'));
    expect(xml, contains('<nRE>123456789</nRE>'));
    expect(xml, contains('<qExport>1.2500</qExport>'));
  });

  test('converte veículo novo do registro JA', () {
    final txt = [
      _minimalTxt(),
      _record([
        'JA',
        '1',
        '9BWZZZ377VT004251',
        '001',
        'Azul',
        '100',
        '2000',
        '1200',
        '1500',
        'SER-1',
        '1',
        'MOT-1',
        '2500',
        '2600',
        '2026',
        '2025',
        'S',
        '6',
        '1',
        'N',
        '1',
        '1234',
        '5',
        '5',
        '0',
      ]),
    ].join('\n');

    final xml = NfeTxtConverter().parse(txt).single;

    expect(xml, contains('<veicProd>'));
    expect(xml, contains('<chassi>9BWZZZ377VT004251</chassi>'));
    expect(xml, contains('<anoMod>2026</anoMod>'));
  });

  test('converte armamento do registro L', () {
    final txt = [
      _minimalTxt(),
      _record(['L', '0', 'SER-ARM', 'CANO-1', 'Pistola']),
    ].join('\n');

    final xml = NfeTxtConverter().parse(txt).single;

    expect(xml, contains('<arma>'));
    expect(xml, contains('<nSerie>SER-ARM</nSerie>'));
    expect(xml, contains('<descr>Pistola</descr>'));
  });

  test('converte partilha ICMS da UF de destino do registro NA', () {
    final txt = [
      _minimalTxt(),
      _record([
        'NA',
        '10',
        '10',
        '1',
        '18',
        '12',
        '100',
        '0.10',
        '1.80',
        '0.90',
      ]),
    ].join('\n');

    final xml = NfeTxtConverter().parse(txt).single;

    expect(xml, contains('<ICMSUFDest>'));
    expect(xml, contains('<vBCUFDest>10.00</vBCUFDest>'));
    expect(xml, contains('<vICMSUFDest>1.80</vICMSUFDest>'));
    expect(xml, contains('<vICMSUFRemet>0.90</vICMSUFRemet>'));
  });

  test('converte IPI devolvido do registro UA', () {
    final txt = [
      _minimalTxt(),
      _record(['UA', '50', '0.50']),
    ].join('\n');

    final xml = NfeTxtConverter().parse(txt).single;

    expect(xml, contains('<impostoDevol>'));
    expect(xml, contains('<pDevol>50.00</pDevol>'));
    expect(xml, contains('<vIPIDevol>0.50</vIPIDevol>'));
  });

  test('converte troco do registro Y', () {
    final txt = [
      _minimalTxt(),
      _record(['YA', '0', '03', '12', '', '', '', '', 'Vale-alimentação']),
      _record(['Y', '2']),
    ].join('\n');

    final xml = NfeTxtConverter().parse(txt).single;

    expect(xml, contains('<vPag>12.00</vPag>'));
    expect(xml, contains('<xPag>Vale-alimentação</xPag>'));
    expect(xml, contains('<vTroco>2.00</vTroco>'));
  });

  test('converte retenções federais do registro W23', () {
    final txt = [
      _minimalTxt(),
      _record(['W23', '0.10', '0.20', '0.30', '10', '0.40', '20', '0.50']),
    ].join('\n');

    final xml = NfeTxtConverter().parse(txt).single;

    expect(xml, contains('<retTrib>'));
    expect(xml, contains('<vRetPIS>0.10</vRetPIS>'));
    expect(xml, contains('<vBCIRRF>10.00</vBCIRRF>'));
    expect(xml, contains('<vRetPrev>0.50</vRetPrev>'));
  });

  test('converte locais de retirada e entrega do TXT', () {
    final txt = [
      _minimalTxt(),
      _record([
        'F',
        'Rua Retirada',
        '10',
        '',
        'Centro',
        '1100015',
        'Porto Velho',
        'RO',
        '76801000',
        '1058',
        'Brasil',
        '69999999999',
        '',
        '123456789',
      ]),
      _record(['F02', '04252011000110']),
      _record([
        'G',
        'Rua Entrega',
        '20',
        '',
        'Industrial',
        '1100015',
        'Porto Velho',
        'RO',
        '76802000',
        '1058',
        'Brasil',
        '69988888888',
        '',
        '987654321',
      ]),
      _record(['F02B', 'Local de retirada']),
      _record(['G02A', '52998224725']),
      _record(['G02B', 'Local de entrega']),
      _record(['N']),
      _record(['Q']),
      _record(['S']),
    ].join('\n');

    final xml = NfeTxtConverter().parse(txt).single;

    expect(xml, contains('<retirada>'));
    expect(xml, contains('<xLgr>Rua Retirada</xLgr>'));
    expect(xml, contains('<CNPJ>04252011000110</CNPJ>'));
    expect(xml, contains('<xNome>Local de retirada</xNome>'));
    expect(xml, contains('<entrega>'));
    expect(xml, contains('<CPF>52998224725</CPF>'));
    expect(xml, contains('<xNome>Local de entrega</xNome>'));
  });

  test('converte documentos referenciados do grupo BA', () {
    final txt = [
      _minimalTxt(),
      _record(['BA']),
      _record(['BA02', '11012604252011000110550010000000011123456784']),
      _record(['BA03', '11', '2601', '04252011000110', '1', '1', '8']),
      _record(['BA10', '11', '2601', '123456789', '4', '2', '9']),
      _record(['BA14', '52998224725']),
      _record(['BA19', '11012604252011000110550010000000011123456784']),
      _record(['BA20', '2D', '001', '000123']),
    ].join('\n');

    final xml = NfeTxtConverter().parse(txt).single;

    expect(
      xml,
      contains('<refNFe>11012604252011000110550010000000011123456784</refNFe>'),
    );
    expect(xml, contains('<refNF>'));
    expect(xml, contains('<refNFP>'));
    expect(xml, contains('<CPF>52998224725</CPF>'));
    expect(
      xml,
      contains('<refCTe>11012604252011000110550010000000011123456784</refCTe>'),
    );
    expect(xml, contains('<refECF>'));
  });

  test('aceita o marcador oficial B19 para referência de CT-e', () {
    final txt = [
      _minimalTxt(),
      _record(['B19', '11012604252011000110550010000000011123456784']),
    ].join('\n');

    final xml = NfeTxtConverter().parse(txt).single;

    expect(
      xml,
      contains('<refCTe>11012604252011000110550010000000011123456784</refCTe>'),
    );
  });

  test('converte destinatário estrangeiro do registro E03A', () {
    final txt =
        '${_minimalTxt().replaceFirst('E02|11222333000181|\n', '')}\n'
        '${_record(['E03A', 'FOREIGN-123'])}';

    final xml = NfeTxtConverter().parse(txt).single;

    expect(xml, contains('<idEstrangeiro>FOREIGN-123</idEstrangeiro>'));
  });

  test('rejeita registro validado mas ainda não mapeado pelo conversor', () {
    final layout = NfeTxtLayout({
      ...NfeTxtLayout.local400().structure,
      'ZZ': 'ZZ|xTeste|',
    });
    expect(
      () => NfeTxtConverter(
        layout: layout,
      ).parse('${_minimalTxt()}\n${_record(['ZZ', 'teste'])}'),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'UNSUPPORTED_NFE_TXT_RECORD',
        ),
      ),
    );
  });

  test('converte emissão avulsa do registro D para avulsa', () {
    final txt = [
      _minimalTxt(),
      _record([
        'D',
        '04252011000110',
        'Órgão Fiscal',
        'MAT-1',
        'Agente Fiscal',
        '69999999999',
        'RO',
        'DAR-1',
        '2026-01-01',
        '10',
        'Repartição 1',
        '2026-01-02',
      ]),
    ].join('\n');

    final xml = NfeTxtConverter().parse(txt).single;

    expect(xml, contains('<avulsa>'));
    expect(xml, contains('<xOrgao>Órgão Fiscal</xOrgao>'));
    expect(xml, contains('<nDAR>DAR-1</nDAR>'));
    expect(xml, contains('<vDAR>10.00</vDAR>'));
    expect(xml, contains('<dPag>2026-01-02</dPag>'));
  });

  test('rejeita vProd divergente do cálculo decimal do item', () {
    expect(
      () => NfeTxtConverter().parse(_minimalTxt(itemTotal: '11')),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'NFE_TXT_ITEM_TOTAL_MISMATCH',
        ),
      ),
    );
  });

  test('converte ICMS, PIS e COFINS normais por item', () {
    final txt = [
      _minimalTxt(),
      _record(['N02', '0', '00', '3', '10', '18', '1.80', '', '']),
      _record(['Q02', '01', '10', '1.65', '0.17']),
      _record(['S02', '01', '10', '7.60', '0.76']),
    ].join('\n');

    final xml = NfeTxtConverter().parse(txt).single;

    expect(xml, contains('<ICMS00>'));
    expect(xml, contains('<vICMS>1.80</vICMS>'));
    expect(xml, contains('<PISAliq>'));
    expect(xml, contains('<vPIS>0.17</vPIS>'));
    expect(xml, contains('<COFINSAliq>'));
    expect(xml, contains('<vCOFINS>0.76</vCOFINS>'));
  });

  test('converte PISOutr e COFINSOutr por base e quantidade', () {
    final baseTxt = [
      _minimalTxt(),
      _record(['Q05', '49', '0.17']),
      _record(['Q07', '10', '1.65']),
      _record(['S05', '49', '0.76']),
      _record(['S07', '10', '7.60']),
    ].join('\n');
    final quantityTxt = [
      _minimalTxt(),
      _record(['Q05', '49', '0.17']),
      _record(['Q10', '2', '0.085']),
      _record(['S05', '49', '0.76']),
      _record(['S09', '2', '0.38']),
    ].join('\n');

    final baseXml = NfeTxtConverter().parse(baseTxt).single;
    final quantityXml = NfeTxtConverter().parse(quantityTxt).single;

    expect(baseXml, contains('<PISOutr>'));
    expect(baseXml, contains('<pPIS>1.6500</pPIS>'));
    expect(baseXml, contains('<COFINSOutr>'));
    expect(baseXml, contains('<pCOFINS>7.6000</pCOFINS>'));
    expect(quantityXml, contains('<qBCProd>2.0000</qBCProd>'));
    expect(quantityXml, contains('<vAliqProd>0.0850</vAliqProd>'));
  });

  test('converte ICMS com substituição tributária', () {
    final txt = [
      _minimalTxt(),
      _record([
        'N03',
        '0',
        '10',
        '3',
        '10',
        '18',
        '1.80',
        '10',
        '1',
        '0.10',
        '4',
        '30',
        '0',
        '10',
        '18',
        '1.80',
        '10',
        '1',
        '0.10',
      ]),
    ].join('\n');

    final xml = NfeTxtConverter().parse(txt).single;

    expect(xml, contains('<ICMS10>'));
    expect(xml, contains('<vBCST>10.00</vBCST>'));
    expect(xml, contains('<vICMSST>1.80</vICMSST>'));
  });

  test('converte ICMS10 com pBCOp e UFST do registro N10A', () {
    final txt = [
      _minimalTxt(),
      _record([
        'N10A',
        '0',
        '10',
        '3',
        '10',
        '5',
        '18',
        '1.80',
        '4',
        '30',
        '5',
        '10',
        '18',
        '1.80',
        '12',
        'RO',
      ]),
    ].join('\n');

    final xml = NfeTxtConverter().parse(txt).single;

    expect(xml, contains('<ICMS10>'));
    expect(xml, contains('<pBCOp>12.0000</pBCOp>'));
    expect(xml, contains('<UFST>RO</UFST>'));
  });

  test('converte ICMSST sem operação própria do registro N05', () {
    final txt = [
      _minimalTxt(),
      _record([
        'N05',
        '0',
        '60',
        '4',
        '30',
        '5',
        '10',
        '18',
        '1.80',
        '10',
        '2',
        '0.20',
        '1',
        '3',
      ]),
    ].join('\n');

    final xml = NfeTxtConverter().parse(txt).single;

    expect(xml, contains('<ICMSST>'));
    expect(xml, contains('<vBCST>10.00</vBCST>'));
    expect(xml, contains('<vICMSDeson>1.00</vICMSDeson>'));
    expect(xml, contains('<motDesICMS>3</motDesICMS>'));
  });

  test('converte ICMS-ST retido e efetivo do registro N10B', () {
    final txt = [
      _minimalTxt(),
      _record([
        'N10B',
        '0',
        '60',
        '10',
        '1.80',
        '12',
        '2',
        '5',
        '1',
        '0.05',
        '18',
        '0.50',
        '3',
        '10',
        '18',
        '1.80',
      ]),
    ].join('\n');

    final xml = NfeTxtConverter().parse(txt).single;

    expect(xml, contains('<ICMSST>'));
    expect(xml, contains('<vBCSTRet>10.00</vBCSTRet>'));
    expect(xml, contains('<vBCSTDest>12.00</vBCSTDest>'));
    expect(xml, contains('<vICMSSubstituto>0.50</vICMSSubstituto>'));
    expect(xml, contains('<vICMSEfet>1.80</vICMSEfet>'));
  });

  test('converte ICMS com redução de base e desoneração', () {
    final reduced = [
      _minimalTxt(),
      _record([
        'N04',
        '0',
        '20',
        '3',
        '10',
        '50',
        '18',
        '0.90',
        '10',
        '1',
        '0.10',
        '',
        '',
      ]),
    ].join('\n');
    final exempt = [
      _minimalTxt(),
      _record(['N06', '0', '40', '1', '7']),
    ].join('\n');

    expect(NfeTxtConverter().parse(reduced).single, contains('<ICMS20>'));
    expect(
      NfeTxtConverter().parse(reduced).single,
      contains('<pRedBC>10.00</pRedBC>'),
    );
    expect(NfeTxtConverter().parse(exempt).single, contains('<ICMS40>'));
    expect(
      NfeTxtConverter().parse(exempt).single,
      contains('<motDesICMS>7</motDesICMS>'),
    );
  });

  test('converte ICMS90 com ST e redução própria do TXT', () {
    final txt = [
      _minimalTxt(),
      _record([
        'N09',
        '0',
        '90',
        '3',
        '10',
        '50',
        '18',
        '9',
        '10',
        '1',
        '0.10',
        '4',
        '30',
        '5',
        '10',
        '18',
        '1.80',
        '9',
        '1',
        '0.09',
        '',
        '',
      ]),
    ].join('\n');

    final xml = NfeTxtConverter().parse(txt).single;

    expect(xml, contains('<ICMS90>'));
    expect(xml, contains('<CST>90</CST>'));
    expect(xml, contains('<pRedBC>10.0000</pRedBC>'));
    expect(xml, contains('<pRedBCST>5.0000</pRedBCST>'));
  });

  test('converte ICMS do Simples Nacional com crédito e ST', () {
    final credit = [
      _minimalTxt(),
      _record(['N10C', '0', '101', '2', '0.20']),
    ].join('\n');
    final st = [
      _minimalTxt(),
      _record([
        'N10E',
        '0',
        '201',
        '4',
        '30',
        '5',
        '10',
        '18',
        '1.80',
        '10',
        '1',
        '0.10',
        '2',
        '0.20',
      ]),
    ].join('\n');

    expect(NfeTxtConverter().parse(credit).single, contains('<ICMSSN101>'));
    expect(
      NfeTxtConverter().parse(credit).single,
      contains('<pCredSN>2.00</pCredSN>'),
    );
    expect(NfeTxtConverter().parse(st).single, contains('<ICMSSN201>'));
    expect(
      NfeTxtConverter().parse(st).single,
      contains('<vBCST>10.00</vBCST>'),
    );
  });

  test('converte ICMS500 com FCP e ICMS efetivo retidos', () {
    final txt = [
      _minimalTxt(),
      _record([
        'N10G',
        '0',
        '500',
        '10',
        '18',
        '1.80',
        '10',
        '1',
        '0.10',
        '5',
        '9.50',
        '12',
        '1.14',
        '0.50',
      ]),
    ].join('\n');

    final xml = NfeTxtConverter().parse(txt).single;

    expect(xml, contains('<ICMSSN500>'));
    expect(xml, contains('<vBCFCPSTRet>10.00</vBCFCPSTRet>'));
    expect(xml, contains('<pRedBCEfet>5.00</pRedBCEfet>'));
    expect(xml, contains('<vICMSSubstituto>0.50</vICMSSubstituto>'));
  });

  test(
    'converte pagamentos, cobrança, transporte e informações adicionais',
    () {
      final txt = [
        _minimalTxt(),
        _record(['X', '0']),
        _record([
          'X03',
          'Transportadora',
          '123',
          'Rua da Carga',
          'Porto Velho',
          'RO',
        ]),
        _record(['X04', '04252011000110']),
        _record(['X18', 'ABC1D23', 'RO', '12345678']),
        _record(['X26', '2', 'CAIXA', 'Marca', '01', '20', '18']),
        _record(['X33', 'LACRE-1']),
        _record(['Y02', 'FAT-1', '10', '0', '10']),
        _record(['Y07', '001', '2026-02-01', '10']),
        _record(['YA', '0', '01', '10', '', '', '', '', 'Dinheiro']),
        _record(['Z', 'Informação fiscal', 'Informação complementar']),
        _record(['Z04', 'pedido', 'PED-1']),
        _record(['Z07', 'fisco', 'FISCAL-1']),
        _record(['Z10', 'PROC-1', '0']),
      ].join('\n');

      final xml = NfeTxtConverter().parse(txt).single;

      expect(xml, contains('<modFrete>0</modFrete>'));
      expect(xml, contains('<xNome>Transportadora</xNome>'));
      expect(xml, contains('<qVol>2</qVol>'));
      expect(xml, contains('<nFat>FAT-1</nFat>'));
      expect(xml, contains('<nDup>001</nDup>'));
      expect(xml, contains('<tPag>01</tPag>'));
      expect(xml, contains('<infAdFisco>Informação fiscal</infAdFisco>'));
      expect(xml, contains('<infCpl>Informação complementar</infCpl>'));
      expect(xml, contains('<nProc>PROC-1</nProc>'));
    },
  );

  test('converte reboque, vagão e balsa dos registros X22/X25', () {
    final converter = NfeTxtConverter();
    final trailerXml = converter
        .parse(
          [
            _minimalTxt(),
            _record(['X', '0']),
            _record(['X22', 'XYZ9A87', 'RO', '87654321']),
          ].join('\n'),
        )
        .single;
    final railcarXml = converter
        .parse(
          [
            _minimalTxt(),
            _record(['X', '0']),
            _record(['X25A', 'VAG-001']),
          ].join('\n'),
        )
        .single;
    final bargeXml = converter
        .parse(
          [
            _minimalTxt(),
            _record(['X', '0']),
            _record(['X25B', 'BALSA-001']),
          ].join('\n'),
        )
        .single;

    expect(trailerXml, contains('<reboque>'));
    expect(trailerXml, contains('<placa>XYZ9A87</placa>'));
    expect(trailerXml, contains('<RNTC>87654321</RNTC>'));
    expect(railcarXml, contains('<vagao>VAG-001</vagao>'));
    expect(bargeXml, contains('<balsa>BALSA-001</balsa>'));
  });

  test('converte IPI tributado por base e alíquota', () {
    final txt = [
      _minimalTxt(),
      _record(['O', '', '', '', '999']),
      _record(['O07', '50', '1.50']),
      _record(['O10', '10', '15']),
    ].join('\n');

    final xml = NfeTxtConverter().parse(txt).single;

    expect(xml, contains('<IPITrib>'));
    expect(xml, contains('<cEnq>999</cEnq>'));
    expect(xml, contains('<pIPI>15.0000</pIPI>'));
    expect(xml, contains('<vIPI>1.50</vIPI>'));
  });

  test('converte IPI tributado por quantidade do registro O11', () {
    final txt = [
      _minimalTxt(),
      _record(['O', '', '', '', '999']),
      _record(['O07', '50', '1.50']),
      _record(['O11', '2', '0.75']),
    ].join('\n');

    final xml = NfeTxtConverter().parse(txt).single;

    expect(xml, contains('<IPITrib>'));
    expect(xml, contains('<qUnid>2.0000</qUnid>'));
    expect(xml, contains('<vUnid>0.7500</vUnid>'));
    expect(xml, contains('<vIPI>1.50</vIPI>'));
  });

  test('confere o vNF declarado no total TXT', () {
    final totals = List<String>.filled(23, '0');
    totals[8] = '10';
    totals[19] = '9';
    expect(
      () => NfeTxtConverter().parse(
        [
          _minimalTxt(),
          _record(['W02', ...totals]),
        ].join('\n'),
      ),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'NFE_TXT_TOTAL_MISMATCH',
        ),
      ),
    );
  });

  test('converte importação, PIS-ST e COFINS-ST', () {
    final txt = [
      _minimalTxt(),
      _record(['P', '100', '2', '10', '0']),
      _record(['R', '1.00']),
      _record(['R02', '10', '1']),
      _record(['T', '2.00']),
      _record(['T02', '10', '2']),
    ].join('\n');

    final xml = NfeTxtConverter().parse(txt).single;

    expect(xml, contains('<II>'));
    expect(xml, contains('<vII>10.00</vII>'));
    expect(xml, contains('<PISST>'));
    expect(xml, contains('<vPIS>1.00</vPIS>'));
    expect(xml, contains('<COFINSST>'));
    expect(xml, contains('<vCOFINS>2.00</vCOFINS>'));
  });

  test('converte ISSQN com competência derivada de dhEmi', () {
    final txt = [
      _minimalTxt(),
      _record([
        'U',
        '10',
        '5',
        '0.50',
        '1100015',
        '01.01',
        '0',
        '0',
        '0',
        '0',
        '0',
        '1',
        'SERV-1',
        '1100015',
        '1058',
        'PROC-1',
        '1',
      ]),
    ].join('\n');

    final xml = NfeTxtConverter().parse(txt).single;

    expect(xml, contains('<ISSQN>'));
    expect(xml, contains('<cListServ>01.01</cListServ>'));
    expect(xml, contains('<vISSQN>0.50</vISSQN>'));
  });

  test('converte total de ISSQN declarado no registro W17', () {
    final txt = [
      _minimalTxt(),
      _record([
        'U',
        '80',
        '5',
        '5',
        '1100015',
        '01.01',
        '0',
        '0',
        '0',
        '0',
        '0',
        '1',
        'SERV-2',
        '1100015',
        '1058',
        'PROC-2',
        '1',
      ]),
      _record([
        'W17',
        '100',
        '80',
        '5',
        '1',
        '2',
        '2026-01-01',
        '3',
        '4',
        '5',
        '6',
        '0.50',
        '1',
      ]),
    ].join('\n');

    final xml = NfeTxtConverter().parse(txt).single;

    expect(xml, contains('<ISSQNtot>'));
    expect(xml, contains('<vServ>100.00</vServ>'));
    expect(xml, contains('<vBC>80.00</vBC>'));
    expect(xml, contains('<vISS>5.00</vISS>'));
    expect(xml, contains('<vPIS>1.00</vPIS>'));
    expect(xml, contains('<vCOFINS>2.00</vCOFINS>'));
    expect(xml, contains('<dCompet>2026-01-01</dCompet>'));
    expect(xml, contains('<cRegTrib>1</cRegTrib>'));
  });
}
