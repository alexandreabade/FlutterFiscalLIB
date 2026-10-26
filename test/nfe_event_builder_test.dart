import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';
import 'package:test/test.dart';

void main() {
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

  test('monta evento de cancelamento sem simular assinatura', () {
    final xml = NfeEventBuilder().cancelamento(
      accessKey: key,
      cOrgao: 11,
      environment: 2,
      issuerCnpj: '04.252.011/0001-10',
      protocol: '111111111111111',
      justification: 'Operação cancelada pelo contribuinte',
      eventDate: DateTime.utc(2026, 1, 1),
    );

    expect(xml, contains('<envEvento'));
    expect(
      xml,
      contains(
        'ID110111$key'
        '01',
      ),
    );
    expect(xml, contains('<tpEvento>110111</tpEvento>'));
    expect(xml, contains('<nProt>111111111111111</nProt>'));
  });

  test('monta cancelamento por substituição', () {
    final xml = NfeEventBuilder().cancelamentoPorSubstituicao(
      accessKey: key,
      cOrgao: 11,
      environment: 2,
      issuerCnpj: '04252011000110',
      protocol: '222222222222222',
      justification: 'Documento substituído por emissão correta',
      eventDate: DateTime.utc(2026, 1, 1),
    );

    expect(xml, contains('ID110112$key'));
    expect(xml, contains('<tpEvento>110112</tpEvento>'));
    expect(xml, contains('<nProt>222222222222222</nProt>'));
  });

  test('monta carta de correção', () {
    final xml = NfeEventBuilder().cartaCorrecao(
      accessKey: key,
      cOrgao: 11,
      environment: 2,
      issuerCnpj: '04252011000110',
      correction: 'Correção do endereço de entrega',
      eventDate: DateTime.utc(2026, 1, 1),
      sequence: 2,
    );

    expect(xml, contains('<tpEvento>110110</tpEvento>'));
    expect(xml, contains('<nSeqEvento>2</nSeqEvento>'));
    expect(
      xml,
      contains('<xCorrecao>Correção do endereço de entrega</xCorrecao>'),
    );
  });

  test('monta manifestação do destinatário com CNPJ', () {
    final xml = NfeEventBuilder().manifestacao(
      accessKey: key,
      cOrgao: 11,
      environment: 2,
      participantTaxId: '04252011000110',
      eventType: '210210',
      eventDate: DateTime.utc(2026, 1, 2),
    );

    expect(xml, contains('<tpEvento>210210</tpEvento>'));
    expect(xml, contains('<descEvento>Ciencia da Operacao</descEvento>'));
    expect(xml, contains('<CNPJ>04252011000110</CNPJ>'));
    expect(xml, isNot(contains('<xJust>')));
  });

  test('monta operação não realizada com CPF e justificativa', () {
    final xml = NfeEventBuilder().manifestacao(
      accessKey: key,
      cOrgao: 11,
      environment: 2,
      participantTaxId: '52998224725',
      eventType: '210240',
      justification: 'A mercadoria não foi recebida pelo destinatário.',
    );

    expect(xml, contains('<CPF>52998224725</CPF>'));
    expect(xml, contains('<tpEvento>210240</tpEvento>'));
    expect(
      xml,
      contains(
        '<xJust>A mercadoria não foi recebida pelo destinatário.</xJust>',
      ),
    );
  });

  test('monta comprovante de entrega com hash e localização', () {
    final xml = NfeEventBuilder().comprovanteEntrega(
      accessKey: key,
      cOrgao: 11,
      environment: 2,
      issuerCnpj: '04252011000110',
      applicationVersion: '1.0.0',
      deliveryDate: DateTime.utc(2026, 1, 2, 10),
      documentNumber: 'RG123456',
      recipientName: 'Pessoa Recebedora',
      hashComprovante: 'AAAAAAAAAAAAAAAAAAAAAAAAAAA=',
      latitude: '-8.761234',
      longitude: '-63.903456',
      hashDate: DateTime.utc(2026, 1, 2, 10, 1),
      eventDate: DateTime.utc(2026, 1, 2, 10, 2),
    );

    expect(xml, contains('<tpEvento>110130</tpEvento>'));
    expect(xml, contains('<dhEntrega>2026-01-02T10:00:00+00:00</dhEntrega>'));
    expect(
      xml,
      contains(
        '<hashComprovante>AAAAAAAAAAAAAAAAAAAAAAAAAAA=</hashComprovante>',
      ),
    );
    expect(xml, contains('<latGPS>-8.761234</latGPS>'));
  });

  test('monta evento de ator interessado com autorização de download', () {
    final xml = NfeEventBuilder().atorInteressado(
      accessKey: key,
      cOrgao: 11,
      environment: 2,
      authorTaxId: '04252011000110',
      authorStateCode: 11,
      authorType: '3',
      applicationVersion: 'FFLIB-0.1.0',
      authorizedTaxId: '04252011000110',
      authorizationType: '1',
      occurredAt: DateTime.utc(2026, 1, 2, 10),
    );

    expect(xml, contains('<tpEvento>110150</tpEvento>'));
    expect(xml, contains('<descEvento>Ator interessado na NF-e</descEvento>'));
    expect(xml, contains('<autXML>'));
    expect(xml, contains('<CNPJ>04252011000110</CNPJ>'));
    expect(xml, contains('<tpAutorizacao>1</tpAutorizacao>'));
    expect(xml, contains('<xCondUso>O emitente ou destinatário'));
  });

  test('rejeita ator interessado com identificador inválido', () {
    expect(
      () => NfeEventBuilder().atorInteressado(
        accessKey: key,
        cOrgao: 11,
        environment: 2,
        authorTaxId: '123',
        authorStateCode: 11,
        authorType: '3',
        applicationVersion: 'FFLIB-0.1.0',
        authorizedTaxId: '04252011000110',
      ),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'INVALID_INTERESTED_ACTOR_AUTHOR',
        ),
      ),
    );
  });

  test('rejeita comprovante de entrega sem hash válido', () {
    expect(
      () => NfeEventBuilder().comprovanteEntrega(
        accessKey: key,
        cOrgao: 11,
        environment: 2,
        issuerCnpj: '04252011000110',
        applicationVersion: '1.0.0',
        deliveryDate: DateTime.utc(2026, 1, 2),
        documentNumber: 'RG123456',
        recipientName: 'Pessoa Recebedora',
        hashComprovante: 'invalido',
      ),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'INVALID_DELIVERY_HASH',
        ),
      ),
    );
  });

  test('rejeita manifestação com justificativa indevida ou tipo inválido', () {
    expect(
      () => NfeEventBuilder().manifestacao(
        accessKey: key,
        cOrgao: 11,
        environment: 2,
        participantTaxId: '04252011000110',
        eventType: '210210',
        justification: 'não deveria existir',
      ),
      throwsA(isA<FiscalValidationException>()),
    );
    expect(
      () => NfeEventBuilder().manifestacao(
        accessKey: key,
        cOrgao: 11,
        environment: 2,
        participantTaxId: '04252011000110',
        eventType: '999999',
      ),
      throwsA(isA<FiscalValidationException>()),
    );
  });

  test('monta inutilização de faixa', () {
    final xml = NfeInutilizationBuilder().build(
      cUf: '11',
      environment: 2,
      issuerCnpj: '04252011000110',
      model: 55,
      series: 1,
      startNumber: 10,
      endNumber: 12,
      reason: 'Numeração não utilizada por falha operacional',
      year: DateTime.utc(2026),
    );

    expect(xml, contains('<inutNFe'));
    expect(xml, contains('<xServ>INUTILIZAR</xServ>'));
    expect(xml, contains('<nNFIni>10</nNFIni>'));
    expect(xml, contains('<nNFFin>12</nNFFin>'));
    expect(xml, contains('Id="ID11260425201100011055001000000010000000012"'));
  });

  test('monta EPEC com chave tpEmis 4 e destinatário', () {
    final epecKey = AccessKey.fromComponents(
      cUf: '11',
      issueDate: DateTime.utc(2026, 1, 1),
      cnpj: '04252011000110',
      model: 55,
      series: 1,
      number: 2,
      tpEmis: 4,
      cNf: '12345679',
    ).value;
    final xml = NfeEventBuilder().epec(
      accessKey: epecKey,
      cOrgao: 11,
      environment: 2,
      authorTaxId: '04252011000110',
      issuerIe: '123456789',
      applicationVersion: 'FFLIB-0.1.0',
      issueDate: DateTime.utc(2026, 1, 1),
      total: 25.5,
      icms: 4.59,
      destinationUf: 'RO',
      destinationTaxId: '52998224725',
      eventDate: DateTime.utc(2026, 1, 1),
    );

    expect(xml, contains('<tpEvento>110140</tpEvento>'));
    expect(xml, contains('<descEvento>EPEC</descEvento>'));
    expect(xml, contains('<tpAutor>1</tpAutor>'));
    expect(xml, contains('<vNF>25.50</vNF>'));
    expect(xml, contains('<dest>'));
    expect(xml, contains('<CPF>52998224725</CPF>'));
  });

  test('rejeita EPEC sem tpEmis 4', () {
    expect(
      () => NfeEventBuilder().epec(
        accessKey: key,
        cOrgao: 11,
        environment: 2,
        authorTaxId: '04252011000110',
        issuerIe: '123456789',
        applicationVersion: 'app',
        issueDate: DateTime.utc(2026, 1, 1),
        total: 1,
        icms: 0,
      ),
      throwsA(isA<FiscalValidationException>()),
    );
  });

  test('rejeita justificativas curtas e faixa invertida', () {
    expect(
      () => NfeEventBuilder().cancelamento(
        accessKey: key,
        cOrgao: 11,
        environment: 2,
        issuerCnpj: '04252011000110',
        protocol: '1',
        justification: 'curta',
      ),
      throwsA(isA<FiscalValidationException>()),
    );
    expect(
      () => NfeInutilizationBuilder().build(
        cUf: '11',
        environment: 2,
        issuerCnpj: '04252011000110',
        model: 55,
        series: 1,
        startNumber: 12,
        endNumber: 10,
        reason: 'Justificativa suficientemente longa',
      ),
      throwsA(isA<FiscalValidationException>()),
    );
  });

  test('monta insucesso na entrega e cancelamento', () {
    final xml = NfeEventBuilder().insucessoEntrega(
      accessKey: key,
      cOrgao: 11,
      environment: 2,
      issuerCnpj: '04252011000110',
      attemptDate: DateTime.utc(2026, 1, 2),
      reasonType: 4,
      attemptHash: 'hash',
      justification: 'Destinatário ausente no endereço informado',
      eventDate: DateTime.utc(2026, 1, 2),
    );
    expect(xml, contains('<tpEvento>110192</tpEvento>'));
    expect(xml, contains('<tpMotivo>4</tpMotivo>'));

    final cancellation = NfeEventBuilder().insucessoEntrega(
      accessKey: key,
      cOrgao: 11,
      environment: 2,
      issuerCnpj: '04252011000110',
      attemptDate: DateTime.utc(2026, 1, 2),
      reasonType: 1,
      attemptHash: 'hash',
      protocol: '123456789012345',
      cancel: true,
    );
    expect(cancellation, contains('<tpEvento>110193</tpEvento>'));
    expect(
      cancellation,
      contains('<nProtEvento>123456789012345</nProtEvento>'),
    );
  });

  test('monta conciliação financeira e cancelamento', () {
    final xml = NfeEventBuilder().conciliacaoFinanceira(
      accessKey: key,
      cOrgao: 11,
      environment: 2,
      issuerCnpj: '04252011000110',
      applicationVersion: 'app-1',
      payments: const [
        FinancialReconciliationPayment(paymentType: '03', value: 25.5),
      ],
    );
    expect(xml, contains('<tpEvento>110750</tpEvento>'));
    expect(xml, contains('<vPag>25.50</vPag>'));

    final cancellation = NfeEventBuilder().conciliacaoFinanceira(
      accessKey: key,
      cOrgao: 11,
      environment: 2,
      issuerCnpj: '04252011000110',
      applicationVersion: 'app-1',
      cancel: true,
      protocol: '123456789012345',
    );
    expect(cancellation, contains('<tpEvento>110751</tpEvento>'));
  });
}
