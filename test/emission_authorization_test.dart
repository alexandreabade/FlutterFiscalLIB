import 'dart:convert';
import 'dart:io';

import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';
import 'package:test/test.dart';

class _AuthorizationTransport implements SefazTransport {
  SefazRequest? request;

  @override
  Future<SefazResponse> post(SefazRequest request) async {
    this.request = request;
    return const SefazResponse(
      statusCode: 200,
      body:
          '<retEnviNFe><cStat>100</cStat><xMotivo>Autorizado</xMotivo>'
          '<protNFe><infProt><chNFe>351234</chNFe>'
          '<nProt>123456789012345</nProt></infProt></protNFe></retEnviNFe>',
    );
  }
}

class _AsyncAuthorizationTransport implements SefazTransport {
  final requests = <SefazRequest>[];

  @override
  Future<SefazResponse> post(SefazRequest request) async {
    requests.add(request);
    if (request.body.contains('<consReciNFe')) {
      return const SefazResponse(
        statusCode: 200,
        body:
            '<retConsReciNFe><cStat>104</cStat><xMotivo>Lote processado</xMotivo>'
            '<protNFe><infProt><cStat>100</cStat><xMotivo>Autorizado</xMotivo>'
            '<chNFe>351234</chNFe><nProt>123456789012345</nProt>'
            '</infProt></protNFe></retConsReciNFe>',
      );
    }
    return const SefazResponse(
      statusCode: 200,
      body:
          '<retEnviNFe><cStat>103</cStat><xMotivo>Lote recebido</xMotivo>'
          '<infRec><nRec>123456789012345</nRec></infRec></retEnviNFe>',
    );
  }
}

class _PendingReceiptTransport implements SefazTransport {
  final requests = <SefazRequest>[];

  @override
  Future<SefazResponse> post(SefazRequest request) async {
    requests.add(request);
    if (request.body.contains('<consReciNFe')) {
      return const SefazResponse(
        statusCode: 200,
        body:
            '<retConsReciNFe><cStat>105</cStat>'
            '<xMotivo>Lote em processamento</xMotivo></retConsReciNFe>',
      );
    }
    return const SefazResponse(
      statusCode: 200,
      body:
          '<retEnviNFe><cStat>103</cStat><xMotivo>Lote recebido</xMotivo>'
          '<infRec><nRec>123456789012345</nRec></infRec></retEnviNFe>',
    );
  }
}

void main() {
  test('assina, envia e normaliza autorização SEFAZ', () async {
    final pfx = base64Decode(
      File(
        'test/fixtures/synthetic_a1.p12.b64',
      ).readAsStringSync().replaceAll(RegExp(r'\s'), ''),
    );
    final identity = PfxIdentity.fromPfx(bytes: pfx, password: 'test-password');
    final issueDate = DateTime.utc(2026, 1, 1, 12);
    final key = AccessKey.fromComponents(
      cUf: '11',
      issueDate: issueDate,
      cnpj: '04252011000110',
      model: 55,
      series: 1,
      number: 13,
      tpEmis: 1,
      cNf: '12345678',
    ).value;
    final document = NfeDocument(
      accessKey: key,
      number: 13,
      series: 1,
      issueDate: issueDate,
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
        name: 'Empresa de Teste',
        cnpj: '04252011000110',
        ie: '123456789',
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
          code: 'ABC',
          description: 'Produto',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 5,
          icms: IcmsTax(cst: '00', base: 5, rate: 18, value: 0.9),
        ),
      ],
    );
    final transport = _AuthorizationTransport();
    final client = SefazClient(
      endpoint: Uri.parse('https://sefaz.example.test/autorizacao'),
      transport: transport,
    );
    final result = await NfeEmissionService(
      signer: XmlSignatureService.fromPfx(identity),
    ).authorize(document, client: client);

    expect(result.isAuthorized, isTrue);
    expect(result.protocol, '123456789012345');
    expect(transport.request!.body, contains('<Signature '));
    expect(transport.request!.body, contains('<enviNFe'));
  });

  test('não envia NFC-e offline pelo fluxo de autorização online', () async {
    final document = NfeDocument.fromComponents(
      cUf: '11',
      cnpj: '04252011000110',
      cNf: '12345680',
      number: 3,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 65,
      issuer: const Party(
        name: 'Empresa de Teste',
        cnpj: '04252011000110',
        ie: '123456789',
        address: 'Rua Fiscal',
        addressNumber: '1',
        neighborhood: 'Centro',
        cityCode: '1100015',
        city: 'Alta Floresta D Oeste',
        state: 'RO',
        zipCode: '76954000',
      ),
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
      () => NfeEmissionService().authorize(
        document,
        client: SefazClient(
          endpoint: Uri.parse('https://sefaz.example.test/autorizacao'),
          transport: _AuthorizationTransport(),
        ),
      ),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'OFFLINE_DOCUMENT_REQUIRES_QUEUE',
        ),
      ),
    );
  });

  test('consulta recibo assíncrono sem reenviar o lote', () async {
    final issueDate = DateTime.utc(2026, 1, 1, 12);
    final document = NfeDocument(
      accessKey: AccessKey.fromComponents(
        cUf: '11',
        issueDate: issueDate,
        cnpj: '04252011000110',
        model: 55,
        series: 1,
        number: 14,
        tpEmis: 1,
        cNf: '12345678',
      ).value,
      number: 14,
      series: 1,
      issueDate: issueDate,
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
        name: 'Empresa de Teste',
        cnpj: '04252011000110',
        ie: '123456789',
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
          code: 'ABC',
          description: 'Produto',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 5,
          icms: IcmsTax(cst: '00', base: 5, rate: 18, value: 0.9),
        ),
      ],
    );
    final transport = _AsyncAuthorizationTransport();
    final result =
        await NfeEmissionService(
          signer: XmlSignatureService.fromPfx(
            PfxIdentity.fromPfx(
              bytes: base64Decode(
                File(
                  'test/fixtures/synthetic_a1.p12.b64',
                ).readAsStringSync().replaceAll(RegExp(r'\s'), ''),
              ),
              password: 'test-password',
            ),
          ),
        ).authorizeAndAwait(
          document,
          client: SefazClient(
            endpoint: Uri.parse('https://sefaz.example.test/autorizacao'),
            transport: transport,
          ),
          maxReceiptAttempts: 2,
          receiptPollInterval: Duration.zero,
        );

    expect(result.isAuthorized, isTrue);
    expect(result.protocol, '123456789012345');
    expect(transport.requests, hasLength(2));
    expect(transport.requests.first.body, contains('<indSinc>0</indSinc>'));
    expect(transport.requests[1].body, contains('<consReciNFe'));
  });

  test('devolve recibo pendente ao atingir o limite sem reenviar', () async {
    final issueDate = DateTime.utc(2026, 1, 1, 12);
    final document = NfeDocument(
      accessKey: AccessKey.fromComponents(
        cUf: '11',
        issueDate: issueDate,
        cnpj: '04252011000110',
        model: 55,
        series: 1,
        number: 15,
        tpEmis: 1,
        cNf: '12345678',
      ).value,
      number: 15,
      series: 1,
      issueDate: issueDate,
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
        name: 'Empresa de Teste',
        cnpj: '04252011000110',
        ie: '123456789',
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
          code: 'ABC',
          description: 'Produto',
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 5,
          icms: IcmsTax(cst: '00', base: 5, rate: 18, value: 0.9),
        ),
      ],
    );
    final transport = _PendingReceiptTransport();
    final result =
        await NfeEmissionService(
          signer: XmlSignatureService.fromPfx(
            PfxIdentity.fromPfx(
              bytes: base64Decode(
                File(
                  'test/fixtures/synthetic_a1.p12.b64',
                ).readAsStringSync().replaceAll(RegExp(r'\s'), ''),
              ),
              password: 'test-password',
            ),
          ),
        ).authorizeAndAwait(
          document,
          client: SefazClient(
            endpoint: Uri.parse('https://sefaz.example.test/autorizacao'),
            transport: transport,
          ),
          maxReceiptAttempts: 2,
          receiptPollInterval: Duration.zero,
        );

    expect(result.statusCode, 105);
    expect(result.isReceiptPending, isTrue);
    expect(result.receipt, '123456789012345');
    expect(result.accessKey, document.accessKey);
    expect(transport.requests, hasLength(3));
    expect(
      transport.requests.where((request) => request.body.contains('<enviNFe')),
      hasLength(1),
    );
  });

  test('rejeita documento com modelo diferente do cliente SEFAZ', () async {
    final document = NfeDocument.fromComponents(
      cUf: '11',
      cnpj: '04252011000110',
      cNf: '12345681',
      number: 4,
      series: 1,
      issueDate: DateTime.utc(2026, 1, 1),
      environment: 2,
      model: 65,
      issuer: const Party(name: 'Empresa de Teste', cnpj: '04252011000110'),
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
      () => NfeEmissionService().authorize(
        document,
        client: SefazClient(
          endpoint: Uri.parse('https://sefaz.example.test/nfe'),
          transport: _AuthorizationTransport(),
          model: 55,
        ),
      ),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'DOCUMENT_MODEL_MISMATCH',
        ),
      ),
    );
  });
}
