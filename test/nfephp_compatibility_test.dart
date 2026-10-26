import 'dart:io';

import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

void main() {
  test('mantém os campos de tagide equivalentes ao NFePHP v5.0.100', () {
    final expected = XmlDocument.parse(
      File('test/fixtures/nfephp_v5_0_100_tagide.xml').readAsStringSync(),
    ).rootElement;
    final key = AccessKey.fromComponents(
      cUf: '50',
      issueDate: DateTime.utc(2026, 1, 1),
      cnpj: '04252011000110',
      model: 55,
      series: 1,
      number: 1,
      tpEmis: 1,
      cNf: '80070008',
    ).value;
    final document = NfeDocument(
      accessKey: key,
      number: 1,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 55,
      operationNature: 'VENDA',
      documentType: 1,
      destinationType: 1,
      municipalityCode: '5002704',
      printFormat: 1,
      purpose: 1,
      finalConsumer: 0,
      presenceIndicator: 1,
      processCode: '0',
      applicationVersion: '5.0',
      issuer: const Party(name: 'Empresa de Fixture', cnpj: '04252011000110'),
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
    final ide = XmlDocument.parse(
      NfeXmlBuilder().build(document),
    ).rootElement.getElement('infNFe')!.getElement('ide')!;

    const fields = [
      'cUF',
      'cNF',
      'natOp',
      'mod',
      'serie',
      'nNF',
      'tpNF',
      'idDest',
      'cMunFG',
      'tpImp',
      'tpEmis',
      'tpAmb',
      'finNFe',
      'indFinal',
      'indPres',
      'procEmi',
      'verProc',
    ];
    for (final field in fields) {
      expect(
        ide.getElement(field)?.innerText,
        expected.getElement(field)?.innerText,
        reason: field,
      );
    }
    // O cDV é calculado pela chave atual e não deve ser copiado cegamente da
    // fixture histórica do NFePHP.
    expect(ide.getElement('cDV')?.innerText, key.substring(43));
  });
}
