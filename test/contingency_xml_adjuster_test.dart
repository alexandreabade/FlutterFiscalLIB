import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

void main() {
  test('ajusta XML legado, recalcula chave e remove assinatura', () {
    const xml = '''<NFe xmlns="http://www.portalfiscal.inf.br/nfe">
      <infNFe Id="NFe51000000000000000000000000000000000000000000" versao="4.00">
        <ide>
          <cUF>51</cUF><cNF>12345678</cNF><natOp>Venda</natOp>
          <mod>55</mod><serie>1</serie><nNF>42</nNF>
          <dhEmi>2026-02-10T12:00:00-04:00</dhEmi><tpEmis>1</tpEmis><cDV>0</cDV>
        </ide>
        <emit><CNPJ>12345678000195</CNPJ></emit>
      </infNFe>
      <Signature><SignedInfo>assinatura antiga</SignedInfo></Signature>
    </NFe>''';
    final adjusted = ContingencyXmlAdjuster.adjust(
      xml: xml,
      contingency: Contingency(
        mode: ContingencyMode.fsDa,
        activatedAt: DateTime.parse('2026-02-10T13:15:20-04:00'),
        reason: 'Indisponibilidade temporária do serviço autorizador',
      ),
    );
    final parsed = XmlDocument.parse(adjusted);
    XmlElement element(String name) => parsed.descendants
        .whereType<XmlElement>()
        .firstWhere((e) => e.localName == name);
    expect(adjusted, isNot(contains('Signature')));
    expect(element('tpEmis').innerText, '5');
    expect(element('dhCont').innerText, '2026-02-10T17:15:20+00:00');
    final id = element('infNFe').getAttribute('Id')!;
    expect(id, startsWith('NFe512602'));
    expect(id.length, 47);
    expect(element('cDV').innerText, id.substring(46));
  });

  test('rejeita XML sem dados para recalcular a chave', () {
    expect(
      () => ContingencyXmlAdjuster.adjust(
        xml: '<NFe/>',
        contingency: Contingency(
          mode: ContingencyMode.svcAn,
          activatedAt: DateTime.utc(2026, 2, 10),
          reason: 'Indisponibilidade temporária do serviço autorizador',
        ),
      ),
      throwsA(isA<FiscalValidationException>()),
    );
  });

  test('recalcula contingência para emitente identificado por CPF', () {
    const xml = '''<NFe xmlns="http://www.portalfiscal.inf.br/nfe">
      <infNFe Id="NFe11000000000000000000000000000000000000000000" versao="4.00">
        <ide>
          <cUF>11</cUF><cNF>12345678</cNF><natOp>Venda</natOp>
          <mod>55</mod><serie>1</serie><nNF>42</nNF>
          <dhEmi>2026-02-10T12:00:00-04:00</dhEmi><tpEmis>1</tpEmis><cDV>0</cDV>
        </ide>
        <emit><CPF>52998224725</CPF></emit>
      </infNFe>
    </NFe>''';
    final adjusted = ContingencyXmlAdjuster.adjust(
      xml: xml,
      contingency: Contingency(
        mode: ContingencyMode.svcAn,
        activatedAt: DateTime.parse('2026-02-10T13:15:20-04:00'),
        reason: 'Indisponibilidade temporária do serviço autorizador',
      ),
    );

    final parsed = XmlDocument.parse(adjusted);
    final id = parsed.descendants
        .whereType<XmlElement>()
        .firstWhere((element) => element.localName == 'infNFe')
        .getAttribute('Id');
    expect(id, isNotNull);
    expect(id, startsWith('NFe112602'));
    expect(id, hasLength(47));
  });

  test('não aplica SVC a NFC-e no ajustador', () {
    const xml = '''<NFe xmlns="http://www.portalfiscal.inf.br/nfe">
      <infNFe Id="NFe11000000000000000000000000000000000000000000" versao="4.00">
        <ide><cUF>11</cUF><cNF>12345678</cNF><mod>65</mod><serie>1</serie><nNF>1</nNF>
        <dhEmi>2026-02-10T12:00:00-04:00</dhEmi><tpEmis>1</tpEmis><cDV>0</cDV></ide>
        <emit><CNPJ>04252011000110</CNPJ></emit>
      </infNFe>
    </NFe>''';
    expect(
      () => ContingencyXmlAdjuster.adjust(
        xml: xml,
        contingency: Contingency(
          mode: ContingencyMode.svcAn,
          activatedAt: DateTime.parse('2026-02-10T13:15:20-04:00'),
          reason: 'Indisponibilidade temporária do serviço autorizador',
        ),
      ),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'NFCE_CONTINGENCY_MODE_MISMATCH',
        ),
      ),
    );
  });
}
