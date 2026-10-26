import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:xml/xml.dart';

import '../exceptions/fiscal_exception.dart';
import '../models/access_key.dart';
import '../crypto/certificate.dart';
import '../validation/gtin.dart';

/// Requisição SOAP enviada ao serviço da SEFAZ.
class SefazRequest {
  /// Cria uma requisição SOAP.
  const SefazRequest({
    required this.url,
    required this.body,
    this.action,
    this.soapVersion = SefazSoapVersion.soap12,
  });

  /// Endpoint configurado pelo consumidor.
  final Uri url;

  /// Envelope SOAP completo.
  final String body;

  /// SOAPAction opcional do serviço.
  final String? action;

  /// Versão SOAP usada para formar o envelope e o `Content-Type`.
  final SefazSoapVersion soapVersion;
}

/// Resposta HTTP recebida da SEFAZ.
class SefazResponse {
  /// Cria uma resposta do transporte.
  const SefazResponse({
    required this.statusCode,
    required this.body,
    this.headers = const {},
  });

  /// Status HTTP.
  final int statusCode;

  /// Corpo XML retornado.
  final String body;

  /// Cabeçalhos relevantes.
  final Map<String, String> headers;

  /// Indica resposta HTTP bem-sucedida.
  bool get isSuccessful => statusCode >= 200 && statusCode < 300;
}

/// Transporte abstrato para permitir testes sem rede.
abstract interface class SefazTransport {
  /// Envia uma requisição SOAP.
  Future<SefazResponse> post(SefazRequest request);
}

/// Operações SOAP que podem ser publicadas em endpoints distintos pela UF.
enum SefazOperation {
  /// Operação não classificada, usada por [SefazClient.sendXml].
  generic,

  /// Consulta de disponibilidade do serviço.
  status,

  /// Envio de lote para autorização.
  authorization,

  /// Consulta de situação por chave.
  query,

  /// Consulta de recibo de lote assíncrono.
  receipt,

  /// Envio de eventos fiscais.
  event,

  /// Pedido de inutilização.
  inutilization,

  /// Distribuição de documentos fiscais eletrônicos.
  distribution,

  /// Consulta cadastral do contribuinte.
  registration,

  /// Consulta pública do Cadastro Centralizado de GTIN.
  gtin,

  /// Pedido de download de NF-e.
  download,
}

/// Versões de envelope SOAP aceitas pelos serviços estaduais.
enum SefazSoapVersion {
  /// SOAP 1.1 (`text/xml`).
  soap11,

  /// SOAP 1.2 (`application/soap+xml`).
  soap12,
}

/// Transporte HTTPS baseado no `dart:io`.
class IoSefazTransport implements SefazTransport {
  /// Cria o transporte com um cliente opcional.
  IoSefazTransport({HttpClient? client}) : _client = client ?? HttpClient();

  /// Cria transporte HTTPS com certificado cliente A1 em memória.
  ///
  /// A validação padrão da cadeia do servidor permanece ativa. O material
  /// privado é entregue diretamente ao `SecurityContext` e não é persistido
  /// pelo transporte.
  IoSefazTransport.fromPfx(PfxIdentity identity)
    : _client = _clientFromPfx(identity);

  final HttpClient _client;

  static HttpClient _clientFromPfx(PfxIdentity identity) {
    if (!identity.certificate.isValidAt()) {
      throw const FiscalValidationException(
        'O certificado A1 está fora do período de validade.',
        code: 'EXPIRED_CERTIFICATE',
      );
    }
    return HttpClient(context: _securityContext(identity));
  }

  static SecurityContext _securityContext(PfxIdentity identity) {
    final context = SecurityContext(withTrustedRoots: true);
    context.useCertificateChainBytes(_pemChain(identity.certificateChain));
    context.usePrivateKeyBytes(_pem('PRIVATE KEY', identity.privateKeyInfoDer));
    return context;
  }

  static Uint8List _pemChain(List<Certificate> certificates) {
    final pem = certificates
        .map((certificate) => utf8.decode(_pem('CERTIFICATE', certificate.der)))
        .join();
    return Uint8List.fromList(utf8.encode(pem));
  }

  static Uint8List _pem(String label, Uint8List der) {
    final encoded = base64Encode(der);
    final lines = <String>[];
    for (var start = 0; start < encoded.length; start += 64) {
      final end = start + 64 < encoded.length ? start + 64 : encoded.length;
      lines.add(encoded.substring(start, end));
    }
    return Uint8List.fromList(
      utf8.encode(
        '-----BEGIN $label-----\n${lines.join('\n')}\n-----END $label-----\n',
      ),
    );
  }

  @override
  Future<SefazResponse> post(SefazRequest request) async {
    if (request.url.scheme != 'https') {
      throw const FiscalValidationException(
        'O endpoint da SEFAZ deve usar HTTPS.',
        code: 'INSECURE_SEFAZ_ENDPOINT',
      );
    }
    final httpRequest = await _client.postUrl(request.url);
    httpRequest.headers.contentType =
        request.soapVersion == SefazSoapVersion.soap12
        ? ContentType('application', 'soap+xml', charset: 'utf-8')
        : ContentType('text', 'xml', charset: 'utf-8');
    if (request.action != null) {
      httpRequest.headers.set('SOAPAction', request.action!);
    }
    httpRequest.write(request.body);
    final response = await httpRequest.close();
    final body = await utf8.decoder.bind(response).join();
    final headers = <String, String>{};
    response.headers.forEach((name, values) {
      headers[name] = values.join(', ');
    });
    return SefazResponse(
      statusCode: response.statusCode,
      body: body,
      headers: headers,
    );
  }
}

/// Configuração explícita de um serviço SEFAZ.
///
/// Para configuração manual, [endpoint] deve ser fornecido pela aplicação a
/// partir da configuração oficial vigente. Para cadastro automático, use a
/// classe `SefazEndpointCatalog`, que carrega o catálogo incorporado por UF,
/// modelo e ambiente.
class SefazClientConfig {
  /// Cria uma configuração validada para o serviço fiscal.
  SefazClientConfig({
    required this.endpoint,
    required this.uf,
    required this.environment,
    required this.model,
    this.serviceVersion = '4.00',
    this.soapVersion = SefazSoapVersion.soap12,
    this.soapAction,
    Map<SefazOperation, String> serviceActions = const {},
    Map<SefazOperation, Uri> serviceEndpoints = const {},
    this.timeout = const Duration(seconds: 30),
    SefazRetryPolicy? retryPolicy,
    this.certificate,
  }) : retryPolicy = retryPolicy ?? SefazRetryPolicy(),
       serviceActions = Map.unmodifiable(serviceActions),
       serviceEndpoints = Map.unmodifiable(serviceEndpoints) {
    if (endpoint.scheme != 'https') {
      throw const FiscalValidationException(
        'O endpoint da SEFAZ deve usar HTTPS.',
        code: 'INSECURE_SEFAZ_ENDPOINT',
      );
    }
    if (!RegExp(r'^\d{2}$').hasMatch(uf)) {
      throw const FiscalValidationException(
        'A UF da SEFAZ deve ser informada com dois dígitos.',
        code: 'INVALID_SEFAZ_UF',
      );
    }
    if (environment != 1 && environment != 2) {
      throw const FiscalValidationException(
        'O ambiente da SEFAZ deve ser 1 ou 2.',
        code: 'INVALID_SEFAZ_ENVIRONMENT',
      );
    }
    if (model != 55 && model != 65) {
      throw const FiscalValidationException(
        'O modelo da SEFAZ deve ser 55 ou 65.',
        code: 'INVALID_SEFAZ_MODEL',
      );
    }
    if (serviceVersion.trim().isEmpty || timeout <= Duration.zero) {
      throw const FiscalValidationException(
        'Versão do serviço e timeout da SEFAZ são obrigatórios.',
        code: 'INVALID_SEFAZ_CONFIGURATION',
      );
    }
    for (final endpoint in serviceEndpoints.values) {
      if (endpoint.scheme != 'https') {
        throw const FiscalValidationException(
          'Todos os endpoints da SEFAZ devem usar HTTPS.',
          code: 'INSECURE_SEFAZ_ENDPOINT',
        );
      }
    }
  }

  /// Endpoint publicado pela UF para a operação escolhida.
  final Uri endpoint;

  /// Código IBGE da UF em dois dígitos.
  final String uf;

  /// Ambiente: 1 produção ou 2 homologação.
  final int environment;

  /// Modelo fiscal: 55 NF-e ou 65 NFC-e.
  final int model;

  /// Versão do leiaute/serviço SOAP.
  final String serviceVersion;

  /// Versão SOAP exigida pelo serviço da UF.
  final SefazSoapVersion soapVersion;

  /// SOAPAction específica, quando o serviço exigir.
  final String? soapAction;

  /// Ações SOAP alternativas por operação; as ausentes usam [soapAction].
  final Map<SefazOperation, String> serviceActions;

  /// Endpoints alternativos por operação; os ausentes usam [endpoint].
  final Map<SefazOperation, Uri> serviceEndpoints;

  /// Limite de espera por resposta.
  final Duration timeout;

  /// Política opt-in para respostas HTTP transitórias.
  final SefazRetryPolicy retryPolicy;

  /// Identidade A1 opcional para autenticação TLS mútua.
  final PfxIdentity? certificate;
}

/// Política de repetição segura para respostas HTTP selecionadas.
///
/// O padrão faz uma única tentativa. Timeouts nunca são repetidos pelo
/// cliente, pois a SEFAZ pode ter processado a requisição antes da perda da
/// resposta; nesse caso o documento permanece em estado desconhecido e deve
/// ser consultado.
class SefazRetryPolicy {
  /// Cria uma política com [maxAttempts] tentativas totais.
  SefazRetryPolicy({
    this.maxAttempts = 1,
    this.delay = Duration.zero,
    Set<int> retryableStatusCodes = const {408, 429, 500, 502, 503, 504},
  }) : retryableStatusCodes = Set.unmodifiable(retryableStatusCodes),
       assert(maxAttempts > 0);

  /// Número total de tentativas, incluindo a primeira.
  final int maxAttempts;

  /// Intervalo entre tentativas.
  final Duration delay;

  /// Status HTTP que podem ser repetidos.
  final Set<int> retryableStatusCodes;

  /// Indica se a resposta pode ser repetida após [attempt] (zero-based).
  bool shouldRetry(int statusCode, int attempt) =>
      attempt + 1 < maxAttempts && retryableStatusCodes.contains(statusCode);
}

/// Cliente SOAP para serviços da SEFAZ.
class SefazClient {
  /// Cria um cliente para um endpoint explicitamente configurado.
  SefazClient({
    required Uri endpoint,
    SefazTransport? transport,
    this.model = 55,
    this.serviceVersion = '4.00',
    this.soapVersion = SefazSoapVersion.soap12,
    this.soapAction,
    Map<SefazOperation, String> serviceActions = const {},
    Map<SefazOperation, Uri> serviceEndpoints = const {},
    this.timeout = const Duration(seconds: 30),
    SefazRetryPolicy? retryPolicy,
  }) : endpoint = endpoint,
       retryPolicy = retryPolicy ?? SefazRetryPolicy(),
       serviceActions = Map.unmodifiable(serviceActions),
       serviceEndpoints = Map.unmodifiable(serviceEndpoints),
       _transport = transport ?? IoSefazTransport() {
    if (endpoint.scheme != 'https') {
      throw const FiscalValidationException(
        'O endpoint da SEFAZ deve usar HTTPS.',
        code: 'INSECURE_SEFAZ_ENDPOINT',
      );
    }
    if (timeout <= Duration.zero) {
      throw const FiscalValidationException(
        'O timeout da SEFAZ deve ser positivo.',
        code: 'INVALID_SEFAZ_TIMEOUT',
      );
    }
    if (model != 55 && model != 65) {
      throw const FiscalValidationException(
        'O modelo da SEFAZ deve ser 55 ou 65.',
        code: 'INVALID_SEFAZ_MODEL',
      );
    }
    if (serviceVersion.trim().isEmpty) {
      throw const FiscalValidationException(
        'A versão do serviço SEFAZ não pode ser vazia.',
        code: 'INVALID_SEFAZ_SERVICE_VERSION',
      );
    }
    if (this.retryPolicy.delay < Duration.zero) {
      throw const FiscalValidationException(
        'O intervalo da política de repetição deve ser não negativo.',
        code: 'INVALID_SEFAZ_RETRY_DELAY',
      );
    }
    for (final serviceEndpoint in serviceEndpoints.values) {
      if (serviceEndpoint.scheme != 'https') {
        throw const FiscalValidationException(
          'Todos os endpoints da SEFAZ devem usar HTTPS.',
          code: 'INSECURE_SEFAZ_ENDPOINT',
        );
      }
    }
  }

  /// Cria um cliente a partir da configuração fiscal e, quando fornecida,
  /// instala a identidade A1 no transporte HTTPS.
  factory SefazClient.fromConfig(
    SefazClientConfig config, {
    SefazTransport? transport,
  }) {
    final configuredTransport =
        transport ??
        (config.certificate == null
            ? null
            : IoSefazTransport.fromPfx(config.certificate!));
    return SefazClient(
      endpoint: config.endpoint,
      transport: configuredTransport,
      model: config.model,
      serviceVersion: config.serviceVersion,
      soapVersion: config.soapVersion,
      soapAction: config.soapAction,
      serviceActions: config.serviceActions,
      serviceEndpoints: config.serviceEndpoints,
      timeout: config.timeout,
      retryPolicy: config.retryPolicy,
    );
  }

  /// Endpoint do serviço.
  final Uri endpoint;

  /// Modelo fiscal associado ao cliente: 55 (NF-e) ou 65 (NFC-e).
  final int model;

  /// Versão usada nos envelopes NF-e, por padrão `4.00`.
  final String serviceVersion;

  /// Versão SOAP usada no envelope e no cabeçalho HTTP.
  final SefazSoapVersion soapVersion;

  /// SOAPAction usado pela operação.
  final String? soapAction;

  /// Ações SOAP por operação, com [soapAction] como fallback.
  final Map<SefazOperation, String> serviceActions;

  /// Endpoints alternativos por operação, quando a UF os exigir.
  final Map<SefazOperation, Uri> serviceEndpoints;

  /// Tempo máximo para obter uma resposta HTTP da SEFAZ.
  final Duration timeout;

  /// Política de repetição HTTP; por padrão não repete requisições.
  final SefazRetryPolicy retryPolicy;

  final SefazTransport _transport;

  /// Envia um XML dentro do envelope SOAP configurado.
  Future<SefazResponse> sendXml(
    String xml, {
    SefazOperation operation = SefazOperation.generic,
    bool compress = false,
    bool wrapInNfeDadosMsg = false,
  }) async {
    if (xml.trim().isEmpty) {
      throw const FiscalValidationException(
        'O XML da operação SEFAZ não pode ser vazio.',
        code: 'EMPTY_SEFAZ_XML',
      );
    }
    try {
      XmlDocument.parse(xml);
    } on XmlException catch (error) {
      throw FiscalValidationException(
        'O XML da operação SEFAZ é inválido e não será transmitido.',
        code: 'INVALID_SEFAZ_XML',
        cause: error,
      );
    }
    final bodyXml = compress
        ? '<nfeDadosMsgZip xmlns="http://www.portalfiscal.inf.br/nfe">'
              '${base64Encode(gzip.encode(utf8.encode(xml)))}</nfeDadosMsgZip>'
        : wrapInNfeDadosMsg
        ? '<nfeDadosMsg xmlns="http://www.portalfiscal.inf.br/nfe">'
              '$xml</nfeDadosMsg>'
        : xml;
    final envelope = soapVersion == SefazSoapVersion.soap12
        ? '''<?xml version="1.0" encoding="UTF-8"?>
<soap12:Envelope xmlns:soap12="http://www.w3.org/2003/05/soap-envelope">
  <soap12:Body>
    $bodyXml
  </soap12:Body>
</soap12:Envelope>'''
        : '''<?xml version="1.0" encoding="UTF-8"?>
<soap11:Envelope xmlns:soap11="http://schemas.xmlsoap.org/soap/envelope/">
  <soap11:Body>
    $bodyXml
  </soap11:Body>
</soap11:Envelope>''';
    var attempt = 0;
    while (true) {
      late final SefazResponse response;
      try {
        response = await _transport
            .post(
              SefazRequest(
                url: serviceEndpoints[operation] ?? endpoint,
                body: envelope,
                action: serviceActions[operation] ?? soapAction,
                soapVersion: soapVersion,
              ),
            )
            .timeout(timeout);
      } on TimeoutException catch (error) {
        throw FiscalException(
          'A SEFAZ não respondeu dentro do timeout configurado; o estado fiscal '
          'do documento permanece desconhecido e deve ser consultado antes de '
          'qualquer reenvio.',
          code: 'SEFAZ_TIMEOUT',
          cause: error,
        );
      } on IOException catch (error) {
        throw FiscalException(
          'Falha de rede ao comunicar com a SEFAZ; o estado fiscal do '
          'documento permanece desconhecido e deve ser consultado antes de '
          'qualquer reenvio.',
          code: 'SEFAZ_NETWORK_ERROR',
          cause: error,
        );
      }
      if (response.isSuccessful) return response;
      if (retryPolicy.shouldRetry(response.statusCode, attempt)) {
        attempt++;
        if (retryPolicy.delay > Duration.zero) {
          await Future<void>.delayed(retryPolicy.delay);
        }
        continue;
      }
      final soapFault = _soapFaultMessage(response.body);
      if (soapFault != null) {
        throw FiscalException(
          'A SEFAZ retornou uma falha SOAP: $soapFault',
          code: 'SEFAZ_SOAP_FAULT',
        );
      }
      throw FiscalException(
        'A SEFAZ retornou HTTP ${response.statusCode}.',
        code: 'SEFAZ_HTTP_ERROR',
      );
    }
  }

  /// Consulta a situação de uma NF-e por chave de acesso.
  Future<SefazResponse> sefazConsultaChave(
    String accessKey, {
    required int environment,
  }) {
    if (!AccessKey.isValid(accessKey)) {
      throw const FiscalValidationException(
        'A chave de acesso da consulta é inválida.',
        code: 'INVALID_QUERY_ACCESS_KEY',
      );
    }
    if (environment != 1 && environment != 2) {
      throw const FiscalValidationException(
        'O ambiente da consulta deve ser 1 ou 2.',
        code: 'INVALID_QUERY_ENVIRONMENT',
      );
    }
    return sendXml(
      '''<consSitNFe xmlns="http://www.portalfiscal.inf.br/nfe" versao="$serviceVersion">
  <tpAmb>$environment</tpAmb>
  <xServ>CONSULTAR</xServ>
  <chNFe>$accessKey</chNFe>
  </consSitNFe>''',
      operation: SefazOperation.query,
      wrapInNfeDadosMsg: true,
    );
  }

  /// Consulta protocolo/situação de uma NF-e por chave.
  ///
  /// O serviço fiscal retorna o protocolo dentro da resposta de situação;
  /// este nome explicita a operação para consumidores que trabalham por
  /// protocolo, mantendo a mesma mensagem `consSitNFe` oficial.
  Future<SefazResponse> sefazConsultaProtocolo(
    String accessKey, {
    required int environment,
  }) => sefazConsultaChave(accessKey, environment: environment);

  /// Consulta o status do serviço da UF configurada.
  Future<SefazResponse> sefazStatusServico({
    required String cUf,
    required int environment,
  }) {
    if (!RegExp(r'^\d{2}$').hasMatch(cUf)) {
      throw const FiscalValidationException(
        'O código da UF deve conter dois dígitos.',
        code: 'INVALID_STATUS_UF',
      );
    }
    if (environment != 1 && environment != 2) {
      throw const FiscalValidationException(
        'O ambiente do status deve ser 1 ou 2.',
        code: 'INVALID_STATUS_ENVIRONMENT',
      );
    }
    return sendXml(
      '''<consStatServ xmlns="http://www.portalfiscal.inf.br/nfe" versao="$serviceVersion">
  <tpAmb>$environment</tpAmb>
  <cUF>$cUf</cUF>
  <xServ>STATUS</xServ>
  </consStatServ>''',
      operation: SefazOperation.status,
      wrapInNfeDadosMsg: true,
    );
  }

  /// Consulta o resultado de um lote assíncrono pelo recibo retornado.
  Future<SefazResponse> sefazConsultaRecibo(
    String receipt, {
    required int environment,
  }) {
    if (!RegExp(r'^\d{15}$').hasMatch(receipt)) {
      throw const FiscalValidationException(
        'O recibo deve conter 15 dígitos.',
        code: 'INVALID_RECEIPT',
      );
    }
    if (environment != 1 && environment != 2) {
      throw const FiscalValidationException(
        'O ambiente da consulta do recibo deve ser 1 ou 2.',
        code: 'INVALID_RECEIPT_ENVIRONMENT',
      );
    }
    return sendXml(
      '''<consReciNFe xmlns="http://www.portalfiscal.inf.br/nfe" versao="$serviceVersion">
  <tpAmb>$environment</tpAmb>
  <nRec>$receipt</nRec>
  </consReciNFe>''',
      operation: SefazOperation.receipt,
      wrapInNfeDadosMsg: true,
    );
  }

  /// Consulta documentos disponíveis no ambiente nacional (`distDFeInt`).
  ///
  /// A consulta pode ser feita por último NSU, NSU específico ou chave de
  /// acesso. Os parâmetros são mutuamente exclusivos; quando nenhum deles é
  /// informado, a SEFAZ interpreta a operação como distribuição a partir do
  /// último NSU informado pelo ambiente, o que não é permitido pelo leiaute.
  Future<SefazResponse> sefazDistribuicaoDFe({
    required String cUfAutor,
    required int environment,
    required String actorTaxId,
    String? lastNsu,
    String? nsu,
    String? accessKey,
  }) {
    if (!RegExp(r'^\d{2}$').hasMatch(cUfAutor)) {
      throw const FiscalValidationException(
        'O código da UF autora deve conter dois dígitos.',
        code: 'INVALID_DFE_AUTHOR_UF',
      );
    }
    _validateEnvironment(environment, 'INVALID_DFE_ENVIRONMENT');
    final taxId = actorTaxId.replaceAll(RegExp(r'\D'), '');
    final taxTag = switch (taxId.length) {
      11 when _isValidCpf(taxId) => 'CPF',
      14 when _isValidCnpj(taxId) => 'CNPJ',
      _ => throw const FiscalValidationException(
        'O CPF/CNPJ do autor da distribuição é inválido.',
        code: 'INVALID_DFE_AUTHOR_TAX_ID',
      ),
    };
    final filters = [
      lastNsu,
      nsu,
      accessKey,
    ].where((value) => value != null).length;
    if (filters != 1) {
      throw const FiscalValidationException(
        'Informe exatamente um filtro: último NSU, NSU ou chave de acesso.',
        code: 'INVALID_DFE_QUERY_FILTER',
      );
    }
    final query = switch ((lastNsu, nsu, accessKey)) {
      (final value?, null, null) => _dfeQuery(
        'distNSU',
        'ultNSU',
        _validateNsu(value, 'INVALID_DFE_LAST_NSU'),
      ),
      (null, final value?, null) => _dfeQuery(
        'consNSU',
        'NSU',
        _validateNsu(value, 'INVALID_DFE_NSU'),
      ),
      (null, null, final value?) => _dfeKeyQuery(value),
      _ => throw StateError('Filtro de distribuição inconsistente.'),
    };
    return sendXml(
      '''<distDFeInt xmlns="http://www.portalfiscal.inf.br/nfe" versao="1.01">
  <tpAmb>$environment</tpAmb>
  <cUFAutor>$cUfAutor</cUFAutor>
  <$taxTag>$taxId</$taxTag>
  $query
</distDFeInt>''',
      operation: SefazOperation.distribution,
      wrapInNfeDadosMsg: true,
    );
  }

  /// Consulta o cadastro de um contribuinte (`consCad`).
  Future<SefazResponse> sefazConsultaCadastro({
    required String uf,
    required int environment,
    String? cnpj,
    String? cpf,
    String? ie,
  }) {
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(uf.trim().toUpperCase())) {
      throw const FiscalValidationException(
        'A UF da consulta cadastral deve possuir duas letras.',
        code: 'INVALID_REGISTRATION_UF',
      );
    }
    _validateEnvironment(environment, 'INVALID_REGISTRATION_ENVIRONMENT');
    final identifiers = [
      cnpj,
      cpf,
      ie,
    ].where((value) => value != null && value.trim().isNotEmpty).length;
    if (identifiers != 1) {
      throw const FiscalValidationException(
        'Informe exatamente um identificador cadastral.',
        code: 'INVALID_REGISTRATION_IDENTIFIER',
      );
    }
    final taxId = cnpj?.replaceAll(RegExp(r'\D'), '');
    final cpfId = cpf?.replaceAll(RegExp(r'\D'), '');
    final ieValue = ie?.trim();
    if (taxId != null && !_isValidCnpj(taxId)) {
      throw const FiscalValidationException(
        'O CNPJ da consulta cadastral é inválido.',
        code: 'INVALID_REGISTRATION_CNPJ',
      );
    }
    if (cpfId != null && !_isValidCpf(cpfId)) {
      throw const FiscalValidationException(
        'O CPF da consulta cadastral é inválido.',
        code: 'INVALID_REGISTRATION_CPF',
      );
    }
    if (ieValue != null &&
        !RegExp(r'^[0-9A-Za-z./-]{2,20}$').hasMatch(ieValue)) {
      throw const FiscalValidationException(
        'A inscrição estadual da consulta cadastral é inválida.',
        code: 'INVALID_REGISTRATION_IE',
      );
    }
    final identifier = taxId != null
        ? '<CNPJ>$taxId</CNPJ>'
        : cpfId != null
        ? '<CPF>$cpfId</CPF>'
        : '<IE>$ieValue</IE>';
    return sendXml(
      '''<consCad xmlns="http://www.portalfiscal.inf.br/nfe" versao="2.00">
  <tpAmb>$environment</tpAmb>
  <xServ>CONS-CAD</xServ>
  <UF>${uf.trim().toUpperCase()}</UF>
  $identifier
</consCad>''',
      operation: SefazOperation.registration,
      wrapInNfeDadosMsg: true,
    );
  }

  /// Consulta o Cadastro Centralizado de GTIN (`consGTIN`).
  Future<SefazResponse> sefazConsultaGtin(String gtin) {
    final normalized = gtin.replaceAll(RegExp(r'\D'), '');
    Gtin.assertValid(normalized);
    return sendXml(
      '''<consGTIN xmlns="http://www.portalfiscal.inf.br/nfe" versao="1.00">
  <GTIN>$normalized</GTIN>
</consGTIN>''',
      operation: SefazOperation.gtin,
      wrapInNfeDadosMsg: true,
    );
  }

  /// Solicita o download de uma ou mais NF-e (`downloadNFe`).
  ///
  /// A SEFAZ permite no máximo dez chaves por requisição. O CNPJ informado
  /// deve ser o do destinatário habilitado para a operação.
  Future<SefazResponse> sefazDownloadNFe({
    required int environment,
    required String recipientCnpj,
    required List<String> accessKeys,
  }) {
    _validateEnvironment(environment, 'INVALID_DOWNLOAD_ENVIRONMENT');
    final cnpj = recipientCnpj.replaceAll(RegExp(r'\D'), '');
    if (!_isValidCnpj(cnpj)) {
      throw const FiscalValidationException(
        'O CNPJ do destinatário do download é inválido.',
        code: 'INVALID_DOWNLOAD_CNPJ',
      );
    }
    if (accessKeys.isEmpty || accessKeys.length > 10) {
      throw const FiscalValidationException(
        'O download deve conter entre uma e dez chaves de acesso.',
        code: 'INVALID_DOWNLOAD_KEYS',
      );
    }
    for (final accessKey in accessKeys) {
      if (!AccessKey.isValid(accessKey)) {
        throw const FiscalValidationException(
          'Uma das chaves do download é inválida.',
          code: 'INVALID_DOWNLOAD_ACCESS_KEY',
        );
      }
    }
    return sendXml(
      '''<downloadNFe xmlns="http://www.portalfiscal.inf.br/nfe" versao="1.00">
  <tpAmb>$environment</tpAmb>
  <xServ>DOWNLOAD NFE</xServ>
  <CNPJ>$cnpj</CNPJ>
  ${accessKeys.map((key) => '<chNFe>$key</chNFe>').join('\n  ')}
</downloadNFe>''',
      operation: SefazOperation.download,
      wrapInNfeDadosMsg: true,
    );
  }

  /// Envia um lote síncrono de NF-e ao endpoint configurado.
  Future<SefazResponse> sefazEnviaLote(
    String lotId,
    String nfeXml, {
    int synchronous = 1,
    bool compress = false,
  }) {
    if (!RegExp(r'^\d{1,15}$').hasMatch(lotId)) {
      throw const FiscalValidationException(
        'O identificador do lote deve conter de 1 a 15 dígitos.',
        code: 'INVALID_BATCH_ID',
      );
    }
    if (synchronous != 0 && synchronous != 1) {
      throw const FiscalValidationException(
        'O indicador de sincronismo deve ser 0 ou 1.',
        code: 'INVALID_BATCH_SYNC',
      );
    }
    if (!nfeXml.contains('<NFe')) {
      throw const FiscalValidationException(
        'O lote deve conter uma NF-e.',
        code: 'INVALID_BATCH_DOCUMENT',
      );
    }
    return sendXml(
      '''<enviNFe xmlns="http://www.portalfiscal.inf.br/nfe" versao="$serviceVersion">
  <idLote>$lotId</idLote>
  <indSinc>$synchronous</indSinc>
  $nfeXml
  </enviNFe>''',
      operation: SefazOperation.authorization,
      compress: compress,
      wrapInNfeDadosMsg: !compress,
    );
  }

  /// Envia um envelope `envEvento` já assinado.
  Future<SefazResponse> sefazEnviaEvento(String eventXml) {
    _assertOperationRoot(eventXml, 'envEvento', 'INVALID_EVENT_DOCUMENT');
    return sendXml(
      eventXml,
      operation: SefazOperation.event,
      wrapInNfeDadosMsg: true,
    );
  }

  /// Envia um pedido `inutNFe` já assinado.
  Future<SefazResponse> sefazInutilizacao(String inutilizationXml) {
    _assertOperationRoot(
      inutilizationXml,
      'inutNFe',
      'INVALID_INUTILIZATION_DOCUMENT',
    );
    return sendXml(
      inutilizationXml,
      operation: SefazOperation.inutilization,
      wrapInNfeDadosMsg: true,
    );
  }

  void _assertOperationRoot(String xml, String expected, String code) {
    try {
      final root = XmlDocument.parse(xml).rootElement;
      if (root.localName != expected) {
        throw FiscalValidationException(
          'A operação SEFAZ deve possuir raiz $expected.',
          code: code,
        );
      }
    } on FiscalException {
      rethrow;
    } on XmlException catch (error) {
      throw FiscalValidationException(
        'O XML da operação SEFAZ é inválido.',
        code: code,
        cause: error,
      );
    }
  }

  static String _dfeQuery(String group, String field, String value) =>
      '<$group><$field>$value</$field></$group>';

  static String? _soapFaultMessage(String xml) {
    try {
      final elements = XmlDocument.parse(
        xml,
      ).descendants.whereType<XmlElement>();
      final fault = elements.where((element) => element.localName == 'Fault');
      if (fault.isEmpty) return null;
      final faultElements = fault.first.descendants.whereType<XmlElement>();
      for (final name in const ['Text', 'faultstring', 'Value']) {
        for (final element in faultElements) {
          if (element.localName == name &&
              element.innerText.trim().isNotEmpty) {
            return element.innerText.trim();
          }
        }
      }
      return 'Mensagem SOAP não informada';
    } on XmlException {
      return null;
    }
  }

  static String _dfeKeyQuery(String value) {
    if (!AccessKey.isValid(value)) {
      throw const FiscalValidationException(
        'A chave de acesso da distribuição é inválida.',
        code: 'INVALID_DFE_ACCESS_KEY',
      );
    }
    return '<consChNFe><chNFe>$value</chNFe></consChNFe>';
  }

  static String _validateNsu(String value, String code) {
    if (!RegExp(r'^\d{15}$').hasMatch(value)) {
      throw FiscalValidationException(
        'O NSU deve conter 15 dígitos.',
        code: code,
      );
    }
    return value;
  }

  static void _validateEnvironment(int value, String code) {
    if (value != 1 && value != 2) {
      throw FiscalValidationException(
        'O ambiente deve ser 1 ou 2.',
        code: code,
      );
    }
  }

  static bool _isValidCnpj(String value) {
    if (value.length != 14 || RegExp(r'^(\d)\1{13}$').hasMatch(value)) {
      return false;
    }
    final first = _cnpjDigit(value.substring(0, 12));
    final second = _cnpjDigit('${value.substring(0, 12)}$first');
    return value == '${value.substring(0, 12)}$first$second';
  }

  static bool _isValidCpf(String value) {
    if (value.length != 11 || RegExp(r'^(\d)\1{10}$').hasMatch(value)) {
      return false;
    }
    final first = _cpfDigit(value.substring(0, 9));
    final second = _cpfDigit('${value.substring(0, 9)}$first');
    return value == '${value.substring(0, 9)}$first$second';
  }

  static int _cnpjDigit(String value) {
    final weights = value.length == 12
        ? const [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]
        : const [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
    final sum = List.generate(
      value.length,
      (index) => int.parse(value[index]) * weights[index],
    ).fold<int>(0, (total, item) => total + item);
    final remainder = sum % 11;
    return remainder < 2 ? 0 : 11 - remainder;
  }

  static int _cpfDigit(String value) {
    var sum = 0;
    for (var index = 0; index < value.length; index++) {
      sum += int.parse(value[index]) * (value.length + 1 - index);
    }
    final remainder = sum % 11;
    return remainder < 2 ? 0 : 11 - remainder;
  }
}
