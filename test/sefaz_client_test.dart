import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';
import 'package:test/test.dart';
import 'dart:convert';
import 'dart:io';

class _FakeTransport implements SefazTransport {
  SefazRequest? request;
  SefazResponse response = const SefazResponse(
    statusCode: 200,
    body: '<retorno/>',
  );

  @override
  Future<SefazResponse> post(SefazRequest request) async {
    this.request = request;
    return response;
  }
}

class _SlowTransport implements SefazTransport {
  @override
  Future<SefazResponse> post(SefazRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return const SefazResponse(statusCode: 200, body: '<retorno/>');
  }
}

class _NetworkErrorTransport implements SefazTransport {
  _NetworkErrorTransport(this.error);

  final IOException error;

  @override
  Future<SefazResponse> post(SefazRequest request) => Future.error(error);
}

class _SequenceTransport implements SefazTransport {
  _SequenceTransport(this.responses);

  final List<SefazResponse> responses;
  var attempts = 0;

  @override
  Future<SefazResponse> post(SefazRequest request) async {
    final index = attempts++;
    return responses[index < responses.length ? index : responses.length - 1];
  }
}

void main() {
  test('envia XML dentro de envelope SOAP', () async {
    final transport = _FakeTransport();
    final client = SefazClient(
      endpoint: Uri.parse('https://sefaz.example.test/nfe'),
      soapAction: 'http://www.portalfiscal.inf.br/nfe/ws/NFeAutorizacao4',
      transport: transport,
    );

    final response = await client.sendXml('<nfeDadosMsg><NFe/></nfeDadosMsg>');

    expect(response.isSuccessful, isTrue);
    expect(transport.request!.url.host, 'sefaz.example.test');
    expect(transport.request!.body, contains('<soap12:Envelope'));
    expect(transport.request!.body, contains('<nfeDadosMsg>'));
    expect(transport.request!.action, contains('NFeAutorizacao4'));
  });

  test('rejeita XML malformado antes de chamar o transporte', () async {
    final transport = _FakeTransport();
    final client = SefazClient(
      endpoint: Uri.parse('https://sefaz.example.test/nfe'),
      transport: transport,
    );

    expect(
      () => client.sendXml('<nfeDadosMsg><NFe></nfeDadosMsg>'),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'INVALID_SEFAZ_XML',
        ),
      ),
    );
    expect(transport.request, isNull);
  });

  test('permite SOAP 1.1 para serviços legados', () async {
    final transport = _FakeTransport();
    final client = SefazClient(
      endpoint: Uri.parse('https://sefaz.example.test/nfe'),
      transport: transport,
      soapVersion: SefazSoapVersion.soap11,
    );

    await client.sendXml('<nfeDadosMsg/>');

    expect(transport.request!.soapVersion, SefazSoapVersion.soap11);
    expect(transport.request!.body, contains('<soap11:Envelope'));
    expect(
      transport.request!.body,
      contains('http://schemas.xmlsoap.org/soap/envelope/'),
    );
  });

  test('rejeita endpoint sem HTTPS', () {
    expect(
      () => SefazClient(endpoint: Uri.parse('http://sefaz.example.test')),
      throwsA(isA<FiscalValidationException>()),
    );
  });

  test('cria cliente a partir da configuração UF/ambiente/modelo', () async {
    final transport = _FakeTransport();
    final client = SefazClient.fromConfig(
      SefazClientConfig(
        endpoint: Uri.parse('https://sefaz.example.test/nfe'),
        uf: '11',
        environment: 2,
        model: 55,
        serviceVersion: '4.00',
      ),
      transport: transport,
    );

    await client.sefazStatusServico(cUf: '11', environment: 2);
    expect(transport.request!.url.scheme, 'https');
  });

  test('propaga a versão configurada aos envelopes NF-e', () async {
    final transport = _FakeTransport();
    final client = SefazClient.fromConfig(
      SefazClientConfig(
        endpoint: Uri.parse('https://sefaz.example.test/nfe'),
        uf: '11',
        environment: 2,
        model: 55,
        serviceVersion: '4.10',
      ),
      transport: transport,
    );

    await client.sefazStatusServico(cUf: '11', environment: 2);
    expect(transport.request!.body, contains('versao="4.10"'));
  });

  test('monta o corpo oficial v4 na consulta de status', () async {
    final transport = _FakeTransport();
    final client = SefazClient(
      endpoint: Uri.parse('https://sefaz.example.test/nfe'),
      transport: transport,
    );

    await client.sefazStatusServico(cUf: '11', environment: 2);

    expect(
      transport.request!.body,
      contains(
        '<nfeDadosMsg xmlns="http://www.portalfiscal.inf.br/nfe/wsdl/NFeStatusServico4">',
      ),
    );
    expect(transport.request!.body, contains('<cUF>11</cUF>'));
    expect(transport.request!.body, isNot(contains('<soap12:Header>')));
    expect(transport.request!.body, isNot(contains('> <')));
  });

  test(
    'roteia operações para endpoints específicos quando configurados',
    () async {
      final transport = _FakeTransport();
      final client = SefazClient.fromConfig(
        SefazClientConfig(
          endpoint: Uri.parse('https://sefaz.example.test/default'),
          uf: '11',
          environment: 2,
          model: 55,
          serviceEndpoints: {
            SefazOperation.status: Uri.parse(
              'https://sefaz.example.test/status',
            ),
            SefazOperation.event: Uri.parse('https://sefaz.example.test/event'),
          },
        ),
        transport: transport,
      );

      await client.sefazStatusServico(cUf: '11', environment: 2);
      expect(transport.request!.url.path, '/status');

      await client.sefazEnviaEvento('<envEvento><evento/></envEvento>');
      expect(transport.request!.url.path, '/event');

      await client.sefazConsultaRecibo('123456789012345', environment: 2);
      expect(transport.request!.url.path, '/default');
    },
  );

  test('roteia SOAPAction por operação com fallback global', () async {
    final transport = _FakeTransport();
    final client = SefazClient(
      endpoint: Uri.parse('https://sefaz.example.test/default'),
      soapAction: 'global-action',
      serviceActions: {SefazOperation.status: 'status-action'},
      transport: transport,
    );

    await client.sefazStatusServico(cUf: '11', environment: 2);
    expect(transport.request!.action, 'status-action');

    await client.sefazConsultaRecibo('123456789012345', environment: 2);
    expect(transport.request!.action, 'global-action');
  });

  test('congela mapas de endpoints e ações após criar o cliente', () {
    final actions = <SefazOperation, String>{
      SefazOperation.status: 'status-action',
    };
    final endpoints = <SefazOperation, Uri>{
      SefazOperation.status: Uri.parse('https://sefaz.example.test/status'),
    };
    final client = SefazClient(
      endpoint: Uri.parse('https://sefaz.example.test/default'),
      serviceActions: actions,
      serviceEndpoints: endpoints,
      transport: _FakeTransport(),
    );

    actions[SefazOperation.event] = 'event-action';
    endpoints[SefazOperation.event] = Uri.parse(
      'https://sefaz.example.test/event',
    );
    expect(client.serviceActions, hasLength(1));
    expect(client.serviceEndpoints, hasLength(1));
    expect(
      () => client.serviceActions[SefazOperation.status] = 'changed',
      throwsUnsupportedError,
    );
  });

  test('congela códigos de retry após criar a política', () {
    final codes = <int>{503};
    final policy = SefazRetryPolicy(maxAttempts: 2);
    final configured = SefazRetryPolicy(
      maxAttempts: 2,
      retryableStatusCodes: codes,
    );

    codes.add(504);
    expect(configured.retryableStatusCodes, {503});
    expect(
      () => configured.retryableStatusCodes.add(500),
      throwsUnsupportedError,
    );
    expect(policy.shouldRetry(503, 0), isTrue);
  });

  test('repete somente status HTTP configurado', () async {
    final transport = _SequenceTransport([
      const SefazResponse(statusCode: 503, body: '<temporario/>'),
      const SefazResponse(statusCode: 200, body: '<ok/>'),
    ]);
    final client = SefazClient(
      endpoint: Uri.parse('https://sefaz.example.test/nfe'),
      transport: transport,
      retryPolicy: SefazRetryPolicy(maxAttempts: 2),
    );

    final response = await client.sendXml('<nfeDadosMsg/>');
    expect(response.statusCode, 200);
    expect(transport.attempts, 2);
  });

  test('converte timeout em estado fiscal desconhecido', () async {
    final client = SefazClient(
      endpoint: Uri.parse('https://sefaz.example.test/nfe'),
      transport: _SlowTransport(),
      timeout: const Duration(milliseconds: 1),
    );

    expect(
      () => client.sendXml('<nfeDadosMsg/>'),
      throwsA(
        isA<FiscalException>().having(
          (error) => error.code,
          'code',
          'SEFAZ_TIMEOUT',
        ),
      ),
    );
  });

  test('converte falhas de rede em exceção fiscal desconhecida', () async {
    final client = SefazClient(
      endpoint: Uri.parse('https://sefaz.example.test/nfe'),
      transport: _NetworkErrorTransport(
        const SocketException('Falha de resolução DNS'),
      ),
    );

    expect(
      () => client.sendXml('<nfeDadosMsg/>'),
      throwsA(
        isA<FiscalException>().having(
          (error) => error.code,
          'code',
          'SEFAZ_NETWORK_ERROR',
        ),
      ),
    );
  });

  test('converte erro HTTP em exceção fiscal', () async {
    final transport = _FakeTransport()
      ..response = const SefazResponse(statusCode: 500, body: '<fault/>');
    final client = SefazClient(
      endpoint: Uri.parse('https://sefaz.example.test/nfe'),
      transport: transport,
    );

    expect(
      () => client.sendXml('<nfeDadosMsg/>'),
      throwsA(isA<FiscalException>()),
    );
  });

  test('preserva a mensagem de SOAP Fault em erro HTTP', () async {
    final transport = _FakeTransport()
      ..response = const SefazResponse(
        statusCode: 500,
        body:
            '''<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope">
          <soap:Body><soap:Fault><soap:Reason>
            <soap:Text>Serviço temporariamente indisponível</soap:Text>
          </soap:Reason></soap:Fault></soap:Body>
        </soap:Envelope>''',
      );
    final client = SefazClient(
      endpoint: Uri.parse('https://sefaz.example.test/nfe'),
      transport: transport,
      retryPolicy: SefazRetryPolicy(maxAttempts: 1),
    );

    expect(
      () => client.sendXml('<nfeDadosMsg/>'),
      throwsA(
        isA<FiscalException>()
            .having((error) => error.code, 'code', 'SEFAZ_SOAP_FAULT')
            .having(
              (error) => error.message,
              'message',
              contains('Serviço temporariamente indisponível'),
            ),
      ),
    );
  });

  test('monta consulta de chave com operação compatível', () async {
    final transport = _FakeTransport();
    final client = SefazClient(
      endpoint: Uri.parse('https://sefaz.example.test/nfe'),
      transport: transport,
    );
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

    await client.sefazConsultaChave(key, environment: 2);

    expect(transport.request!.body, contains('<consSitNFe'));
    expect(transport.request!.body, contains('<chNFe>$key</chNFe>'));
  });

  test('expõe consulta de protocolo pela chave', () async {
    final transport = _FakeTransport();
    final client = SefazClient(
      endpoint: Uri.parse('https://sefaz.example.test/nfe'),
      transport: transport,
    );
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

    await client.sefazConsultaProtocolo(key, environment: 2);

    expect(transport.request!.body, contains('<consSitNFe'));
    expect(transport.request!.body, contains('<chNFe>$key</chNFe>'));
  });

  test('monta distribuição de DF-e por último NSU', () async {
    final transport = _FakeTransport();
    final client = SefazClient(
      endpoint: Uri.parse('https://sefaz.example.test/nfe'),
      transport: transport,
    );

    await client.sefazDistribuicaoDFe(
      cUfAutor: '11',
      environment: 2,
      actorTaxId: '04252011000110',
      lastNsu: '000000000000123',
    );

    final body = transport.request!.body;
    expect(body, contains('<distDFeInt'));
    expect(body, contains('<cUFAutor>11</cUFAutor>'));
    expect(body, contains('<CNPJ>04252011000110</CNPJ>'));
    expect(body, contains('<distNSU><ultNSU>000000000000123</ultNSU>'));
  });

  test('monta consulta cadastral por CNPJ e roteia endpoint', () async {
    final transport = _FakeTransport();
    final client = SefazClient(
      endpoint: Uri.parse('https://sefaz.example.test/default'),
      serviceEndpoints: {
        SefazOperation.registration: Uri.parse(
          'https://sefaz.example.test/cadastro',
        ),
      },
      transport: transport,
    );

    await client.sefazConsultaCadastro(
      uf: 'ro',
      environment: 2,
      cnpj: '04252011000110',
    );

    expect(transport.request!.url.path, '/cadastro');
    expect(transport.request!.body, contains('<consCad'));
    expect(transport.request!.body, contains('<UF>RO</UF>'));
    expect(transport.request!.body, contains('<xServ>CONS-CAD</xServ>'));
  });

  test('monta consulta de GTIN e download de NF-e', () async {
    final transport = _FakeTransport();
    final client = SefazClient(
      endpoint: Uri.parse('https://sefaz.example.test/default'),
      serviceEndpoints: {
        SefazOperation.gtin: Uri.parse('https://sefaz.example.test/gtin'),
        SefazOperation.download: Uri.parse(
          'https://sefaz.example.test/download',
        ),
      },
      transport: transport,
    );
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

    await client.sefazConsultaGtin('7894900011517');
    expect(transport.request!.url.path, '/gtin');
    expect(transport.request!.body, contains('<consGTIN'));
    expect(transport.request!.body, contains('<GTIN>7894900011517</GTIN>'));

    await client.sefazDownloadNFe(
      environment: 2,
      recipientCnpj: '04252011000110',
      accessKeys: [key],
    );
    expect(transport.request!.url.path, '/download');
    expect(transport.request!.body, contains('<downloadNFe'));
    expect(transport.request!.body, contains('<xServ>DOWNLOAD NFE</xServ>'));
    expect(transport.request!.body, contains('<chNFe>$key</chNFe>'));
  });

  test('rejeita GTIN e download fora das regras do leiaute', () {
    final client = SefazClient(
      endpoint: Uri.parse('https://sefaz.example.test/nfe'),
      transport: _FakeTransport(),
    );

    expect(
      () => client.sefazConsultaGtin('7894900011516'),
      throwsA(isA<FiscalValidationException>()),
    );
    expect(
      () => client.sefazDownloadNFe(
        environment: 2,
        recipientCnpj: '04252011000110',
        accessKeys: const [],
      ),
      throwsA(isA<FiscalValidationException>()),
    );
  });

  test('rejeita distribuição sem filtro ou com NSU inválido', () {
    final client = SefazClient(
      endpoint: Uri.parse('https://sefaz.example.test/nfe'),
      transport: _FakeTransport(),
    );

    expect(
      () => client.sefazDistribuicaoDFe(
        cUfAutor: '11',
        environment: 2,
        actorTaxId: '04252011000110',
      ),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'INVALID_DFE_QUERY_FILTER',
        ),
      ),
    );
    expect(
      () => client.sefazDistribuicaoDFe(
        cUfAutor: '11',
        environment: 2,
        actorTaxId: '04252011000110',
        lastNsu: '123',
      ),
      throwsA(isA<FiscalValidationException>()),
    );
  });

  test('monta lote síncrono e valida identificador', () async {
    final transport = _FakeTransport();
    final client = SefazClient(
      endpoint: Uri.parse('https://sefaz.example.test/nfe'),
      transport: transport,
    );

    await client.sefazEnviaLote('123', '<NFe><infNFe/></NFe>');

    expect(transport.request!.body, contains('<enviNFe'));
    expect(transport.request!.body, contains('<nfeDadosMsg'));
    expect(transport.request!.body, contains('<idLote>123</idLote>'));
    expect(transport.request!.body, contains('<indSinc>1</indSinc>'));
  });

  test('compacta lote no formato nfeDadosMsgZip quando solicitado', () async {
    final transport = _FakeTransport();
    final client = SefazClient(
      endpoint: Uri.parse('https://sefaz.example.test/nfe'),
      transport: transport,
    );

    await client.sefazEnviaLote('123', '<NFe><infNFe/></NFe>', compress: true);

    final body = transport.request!.body;
    expect(body, contains('<nfeDadosMsgZip'));
    final encoded = RegExp(
      r'<nfeDadosMsgZip[^>]*>([^<]+)</nfeDadosMsgZip>',
    ).firstMatch(body)!.group(1)!;
    expect(utf8.decode(gzip.decode(base64Decode(encoded))), contains('<NFe>'));
  });

  test('monta consulta de status do serviço', () async {
    final transport = _FakeTransport();
    final client = SefazClient(
      endpoint: Uri.parse('https://sefaz.example.test/status'),
      transport: transport,
    );

    await client.sefazStatusServico(cUf: '11', environment: 2);

    expect(transport.request!.body, contains('<consStatServ'));
    expect(transport.request!.body, contains('<cUF>11</cUF>'));
    expect(transport.request!.body, contains('<xServ>STATUS</xServ>'));
  });

  test('monta consulta de recibo assíncrono', () async {
    final transport = _FakeTransport();
    final client = SefazClient(
      endpoint: Uri.parse('https://sefaz.example.test/recibo'),
      transport: transport,
    );

    await client.sefazConsultaRecibo('123456789012345', environment: 1);

    expect(transport.request!.body, contains('<consReciNFe'));
    expect(transport.request!.body, contains('<nRec>123456789012345</nRec>'));
  });

  test('envia evento e inutilização com raízes validadas', () async {
    final transport = _FakeTransport();
    final client = SefazClient(
      endpoint: Uri.parse('https://sefaz.example.test/evento'),
      transport: transport,
    );

    await client.sefazEnviaEvento('<envEvento><evento/></envEvento>');
    expect(transport.request!.body, contains('<envEvento>'));

    await client.sefazInutilizacao('<inutNFe><infInut/></inutNFe>');
    expect(transport.request!.body, contains('<inutNFe>'));
  });

  test('rejeita XML de operação com raiz incorreta', () {
    final client = SefazClient(
      endpoint: Uri.parse('https://sefaz.example.test/evento'),
      transport: _FakeTransport(),
    );

    expect(
      () => client.sefazEnviaEvento('<NFe/>'),
      throwsA(isA<FiscalValidationException>()),
    );
    expect(
      () => client.sefazInutilizacao('<envEvento/>'),
      throwsA(isA<FiscalValidationException>()),
    );
  });

  test('rejeita UF e recibo fora do formato fiscal', () {
    final client = SefazClient(
      endpoint: Uri.parse('https://sefaz.example.test/nfe'),
      transport: _FakeTransport(),
    );
    expect(
      () => client.sefazStatusServico(cUf: 'RO', environment: 1),
      throwsA(isA<FiscalValidationException>()),
    );
    expect(
      () => client.sefazConsultaRecibo('123', environment: 1),
      throwsA(isA<FiscalValidationException>()),
    );
  });

  test('preserva o modelo fiscal e rejeita modelo SEFAZ inválido', () {
    final client = SefazClient(
      endpoint: Uri.parse('https://sefaz.example.test/nfce'),
      model: 65,
      transport: _FakeTransport(),
    );
    expect(client.model, 65);
    expect(
      () => SefazClient(
        endpoint: Uri.parse('https://sefaz.example.test/invalido'),
        model: 99,
        transport: _FakeTransport(),
      ),
      throwsA(isA<FiscalValidationException>()),
    );
  });
}
