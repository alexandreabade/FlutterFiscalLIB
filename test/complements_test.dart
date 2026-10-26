import 'dart:io';

import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';
import 'package:xml/xml.dart';
import 'package:test/test.dart';

void main() {
  const key = '11012604252011000110550010000000011123456784';
  const request =
      '''<NFe xmlns="http://www.portalfiscal.inf.br/nfe">
  <infNFe Id="NFe$key" versao="4.00">
    <Signature><SignedInfo><DigestValue>digest-1</DigestValue></SignedInfo></Signature>
  </infNFe>
</NFe>''';
  const response =
      '''<protNFe xmlns="http://www.portalfiscal.inf.br/nfe" versao="4.00">
  <infProt>
    <tpAmb>2</tpAmb><verAplic>TESTE</verAplic><chNFe>$key</chNFe>
    <dhRecbto>2026-01-01T12:00:00Z</dhRecbto><nProt>123</nProt>
    <digVal>digest-1</digVal><cStat>100</cStat><xMotivo>Autorizado</xMotivo>
  </infProt>
</protNFe>''';

  test('junta NF-e e protocolo autorizado em nfeProc', () {
    final result = Complements.toAuthorize(request, response);

    expect(result, contains('<nfeProc'));
    expect(result, contains('<NFe'));
    expect(result, contains('<protNFe'));
    expect(result, contains('<cStat>100</cStat>'));
  });

  test('produz a mesma estrutura normalizada da fixture NFePHP', () {
    final result = XmlDocument.parse(
      Complements.toAuthorize(request, response),
    );
    final expected = XmlDocument.parse(
      File('test/fixtures/nfephp_v5_0_100_nfe_proc.xml').readAsStringSync(),
    );
    final actualRoot = result.rootElement;
    final expectedRoot = expected.rootElement;
    expect(actualRoot.localName, expectedRoot.localName);
    expect(
      actualRoot.getAttribute('versao'),
      expectedRoot.getAttribute('versao'),
    );
    expect(actualRoot.findAllElements('NFe').length, 1);
    expect(actualRoot.findAllElements('protNFe').length, 1);
    expect(
      actualRoot.findAllElements('chNFe').single.innerText,
      expectedRoot.findAllElements('chNFe').single.innerText,
    );
    expect(
      actualRoot.findAllElements('nProt').single.innerText,
      expectedRoot.findAllElements('nProt').single.innerText,
    );
  });

  test('rejeita protocolo com chave divergente', () {
    expect(
      () => Complements.toAuthorize(
        request,
        response.replaceFirst(key, '${key.substring(0, 43)}0'),
      ),
      throwsA(isA<FiscalValidationException>()),
    );
  });

  test('registra cancelamento no protocolo como o NFePHP', () {
    final authorized = Complements.toAuthorize(request, response);
    final cancellation =
        '''<retEnvEvento xmlns="http://www.portalfiscal.inf.br/nfe">
  <retEvento versao="1.00"><infEvento>
    <tpEvento>110111</tpEvento><chNFe>$key</chNFe>
    <cStat>135</cStat><nProt>456</nProt><xMotivo>Evento registrado e vinculado</xMotivo>
  </infEvento></retEvento>
</retEnvEvento>''';

    final result = Complements.cancelRegister(authorized, cancellation);

    expect(result, contains('<cStat>101</cStat>'));
    expect(result, contains('<nProt>456</nProt>'));
    expect(result, contains('Cancelamento de NF-e homologado'));
    expect(result, isNot(contains('<retEvento')));
  });

  test('cria envelope nfeProcB2B como o Complements.b2bTag do NFePHP', () {
    final authorized = Complements.toAuthorize(request, response);
    final result = Complements.b2bTag(
      authorized,
      '<documento><NFeB2BFin><numero>123</numero></NFeB2BFin></documento>',
    );
    expect(result, contains('<nfeProcB2B>'));
    expect(result, contains('<nfeProc'));
    expect(result, contains('<NFeB2BFin>'));
    expect(result, contains('<numero>123</numero>'));
  });

  test('rejeita B2B sem a tag solicitada', () {
    final authorized = Complements.toAuthorize(request, response);
    expect(
      () => Complements.b2bTag(authorized, '<documento/>'),
      throwsA(isA<FiscalValidationException>()),
    );
  });

  test('protocoliza evento fiscal como procEventoNFe', () {
    const event =
        '''<envEvento xmlns="http://www.portalfiscal.inf.br/nfe" versao="1.00">
  <idLote>7</idLote><evento versao="1.00"><infEvento><tpEvento>110110</tpEvento></infEvento></evento>
</envEvento>''';
    const response =
        '''<retEnvEvento xmlns="http://www.portalfiscal.inf.br/nfe" versao="1.00">
  <idLote>7</idLote><retEvento versao="1.00"><infEvento><tpEvento>110110</tpEvento><cStat>135</cStat><xMotivo>Evento registrado</xMotivo></infEvento></retEvento>
</retEnvEvento>''';
    final result = Complements.toAuthorize(event, response);
    expect(result, contains('<procEventoNFe'));
    expect(result, contains('<evento'));
    expect(result, contains('<retEvento'));
  });

  test('protocoliza inutilização autorizada como procInutNFe', () {
    const request =
        '''<inutNFe xmlns="http://www.portalfiscal.inf.br/nfe" versao="4.00">
  <infInut><tpAmb>2</tpAmb><cUF>11</cUF><ano>26</ano><CNPJ>04252011000110</CNPJ><mod>55</mod><serie>1</serie><nNFIni>1</nNFIni><nNFFin>2</nNFFin><xJust>Numeração reservada para teste fiscal</xJust></infInut>
</inutNFe>''';
    const response =
        '''<retInutNFe xmlns="http://www.portalfiscal.inf.br/nfe" versao="4.00">
  <infInut><tpAmb>2</tpAmb><cUF>11</cUF><ano>26</ano><CNPJ>04252011000110</CNPJ><mod>55</mod><serie>1</serie><nNFIni>1</nNFIni><nNFFin>2</nNFFin><cStat>102</cStat><xMotivo>Inutilização homologada</xMotivo></infInut>
</retInutNFe>''';
    final result = Complements.toAuthorize(request, response);
    expect(result, contains('<procInutNFe'));
    expect(result, contains('<inutNFe'));
    expect(result, contains('<retInutNFe'));
  });
}
