import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';
import 'package:test/test.dart';

void main() {
  const parser = SefazResponseParser();

  test('normaliza autorização síncrona com protocolo', () {
    final result = parser.parse('''
      <retEnviNFe xmlns="http://www.portalfiscal.inf.br/nfe">
        <cStat>100</cStat><xMotivo>Autorizado o uso da NF-e</xMotivo>
        <protNFe><infProt><chNFe>12345678901234567890123456789012345678901234</chNFe>
        <nProt>111222333444555</nProt></infProt></protNFe>
      </retEnviNFe>
    ''');

    expect(result.isAuthorized, isTrue);
    expect(result.isRejected, isFalse);
    expect(result.statusCode, 100);
    expect(result.reason, 'Autorizado o uso da NF-e');
    expect(result.protocol, '111222333444555');
  });

  test('identifica rejeição e recibo assíncrono', () {
    final result = parser.parse('''
      <retEnviNFe><cStat>103</cStat><xMotivo>Lote recebido</xMotivo>
      <infRec><nRec>123456789012345</nRec></infRec></retEnviNFe>
    ''');

    expect(result.isAuthorized, isFalse);
    expect(result.isRejected, isFalse);
    expect(result.isUnknown, isTrue);
    expect(result.receipt, '123456789012345');
  });

  test('classifica rejeição fiscal 5xx como rejeitada', () {
    final result = parser.parse(
      '<retEnviNFe><cStat>539</cStat><xMotivo>Rejeição</xMotivo></retEnviNFe>',
    );

    expect(result.isRejected, isTrue);
    expect(result.isUnknown, isFalse);
  });

  test('prioriza cStat do protocolo dentro de lote processado', () {
    final result = parser.parse('''
      <retEnviNFe><cStat>104</cStat><xMotivo>Lote processado</xMotivo>
      <protNFe><infProt><cStat>100</cStat><xMotivo>Autorizado</xMotivo>
      <chNFe>12345678901234567890123456789012345678901234</chNFe>
      <nProt>111222333444555</nProt></infProt></protNFe></retEnviNFe>
    ''');

    expect(result.isAuthorized, isTrue);
    expect(result.statusCode, 100);
    expect(result.reason, 'Autorizado');
    expect(result.protocol, '111222333444555');
  });

  test('prioriza rejeição do protocolo dentro de lote processado', () {
    final result = parser.parse('''
      <retEnviNFe><cStat>104</cStat><xMotivo>Lote processado</xMotivo>
      <protNFe><infProt><cStat>539</cStat><xMotivo>Rejeição fiscal</xMotivo>
      </infProt></protNFe></retEnviNFe>
    ''');

    expect(result.isRejected, isTrue);
    expect(result.statusCode, 539);
    expect(result.reason, 'Rejeição fiscal');
  });

  test('preserva todos os protocolos de um lote misto', () {
    final result = parser.parse('''
      <retEnviNFe><cStat>104</cStat><xMotivo>Lote processado</xMotivo>
        <protNFe><infProt><cStat>100</cStat><xMotivo>Autorizada</xMotivo>
          <chNFe>11111111111111111111111111111111111111111111</chNFe>
          <nProt>111111111111111</nProt></infProt></protNFe>
        <protNFe><infProt><cStat>539</cStat><xMotivo>Rejeitada</xMotivo>
          <chNFe>22222222222222222222222222222222222222222222</chNFe>
        </infProt></protNFe>
      </retEnviNFe>
    ''');

    expect(result.protocols, hasLength(2));
    expect(result.protocols[0].statusCode, 100);
    expect(result.protocols[0].accessKey, startsWith('1111'));
    expect(result.protocols[1].statusCode, 539);
    expect(result.protocols[1].reason, 'Rejeitada');
    expect(result.statusCode, 100);
    expect(result.accessKey, startsWith('1111'));
  });

  test('reconhece sucesso de evento e inutilização', () {
    final event = parser.parse(
      '<retEvento><infEvento><cStat>135</cStat><xMotivo>Evento registrado</xMotivo></infEvento></retEvento>',
    );
    final inutilization = parser.parse(
      '<retInutNFe><infInut><cStat>102</cStat><xMotivo>Inutilização homologada</xMotivo></infInut></retInutNFe>',
    );

    expect(event.isEventAuthorized, isTrue);
    expect(event.isAccepted, isTrue);
    expect(event.isUnknown, isFalse);
    expect(inutilization.isInutilizationAuthorized, isTrue);
    expect(inutilization.isAccepted, isTrue);
  });

  test('rejeita XML sem cStat', () {
    expect(
      () => parser.parse('<retEnviNFe><xMotivo>erro</xMotivo></retEnviNFe>'),
      throwsA(isA<FiscalValidationException>()),
    );
  });

  test('classifica Fault SOAP como falha fiscal explícita', () {
    expect(
      () => parser.parse('''
        <soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope">
          <soap:Body><soap:Fault>
            <soap:Code><soap:Value>soap:Sender</soap:Value></soap:Code>
            <soap:Reason><soap:Text xml:lang="pt-BR">Mensagem inválida</soap:Text>
            </soap:Reason>
          </soap:Fault></soap:Body>
        </soap:Envelope>
      ''').toString(),
      throwsA(
        isA<FiscalException>()
            .having((error) => error.code, 'code', 'SEFAZ_SOAP_FAULT')
            .having(
              (error) => error.message,
              'message',
              contains('Mensagem inválida'),
            ),
      ),
    );
  });
}
