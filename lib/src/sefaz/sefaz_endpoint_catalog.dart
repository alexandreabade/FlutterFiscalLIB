import 'dart:convert';

import 'package:archive/archive.dart';

import '../crypto/certificate.dart';
import '../exceptions/fiscal_exception.dart';
import 'sefaz_client.dart';

/// Endpoint publicado por uma SEFAZ.
class SefazServiceEndpoint {
  /// Cria a descrição de um serviço.
  const SefazServiceEndpoint({
    required this.url,
    required this.operation,
    required this.version,
    required this.method,
  });

  /// URL do serviço.
  final Uri url;

  /// Operação SOAP.
  final String operation;

  /// Versão do leiaute.
  final String version;

  /// Método legado.
  final String method;
}

/// Perfil de endpoints da UF, modelo e ambiente.
class SefazEndpointProfile {
  /// Cria um perfil imutável.
  const SefazEndpointProfile({
    required this.uf,
    required this.cUf,
    required this.model,
    required this.environment,
    required this.authorizer,
    required this.services,
  });

  /// Sigla da UF.
  final String uf;

  /// Código IBGE da UF.
  final String cUf;

  /// Modelo fiscal.
  final int model;

  /// Ambiente fiscal.
  final int environment;

  /// Autorizador efetivo.
  final String authorizer;

  /// Serviços disponíveis.
  final Map<String, SefazServiceEndpoint> services;

  /// Busca um serviço pelo nome do catálogo.
  SefazServiceEndpoint? service(String name) => services[name];

  /// URL pública do QR Code da NFC-e.
  Uri get qrCodeUrl => _requiredService('NfeConsultaQR').url;

  SefazServiceEndpoint _requiredService(String name) {
    final value = services[name];
    if (value == null) {
      throw FiscalValidationException(
        'A UF $uf não publicou o serviço $name para o modelo $model e ambiente $environment.',
        code: 'SEFAZ_SERVICE_NOT_CATALOGUED',
      );
    }
    return value;
  }
}

/// Catálogo de endpoints derivado dos arquivos de serviços do NFePHP.
class SefazEndpointCatalog {
  SefazEndpointCatalog._();

  static Map<String, dynamic>? _decoded;

  /// Resolve serviços da [uf], com fallback SVRS/SVAN do autorizador.
  static SefazEndpointProfile resolve({
    required String uf,
    required int model,
    required int environment,
  }) {
    final normalizedUf = uf.trim().toUpperCase();
    final cUf = _ufCodes[normalizedUf];
    if (cUf == null) {
      throw const FiscalValidationException(
        'Informe uma UF brasileira válida.',
        code: 'INVALID_SEFAZ_UF',
      );
    }
    if (model != 55 && model != 65) {
      throw const FiscalValidationException(
        'O modelo fiscal deve ser 55 ou 65.',
        code: 'INVALID_SEFAZ_MODEL',
      );
    }
    if (environment != 1 && environment != 2) {
      throw const FiscalValidationException(
        'O ambiente fiscal deve ser 1 ou 2.',
        code: 'INVALID_SEFAZ_ENVIRONMENT',
      );
    }
    final data = _load();
    final modelData =
        (data['models'] as Map<String, dynamic>)['$model']
            as Map<String, dynamic>;
    final authData =
        (data['auth'] as Map<String, dynamic>)['$model']
            as Map<String, dynamic>;
    final authorizer = authData[normalizedUf] as String?;
    if (authorizer == null) {
      throw FiscalValidationException(
        'A UF $normalizedUf não possui autorizador catalogado para o modelo $model.',
        code: 'SEFAZ_AUTHORIZER_NOT_CATALOGUED',
      );
    }
    final local = _environmentServices(modelData[normalizedUf], environment);
    final fallback = _environmentServices(modelData[authorizer], environment);
    final merged = <String, dynamic>{...fallback, ...local};
    final services = <String, SefazServiceEndpoint>{};
    for (final entry in merged.entries) {
      final item = entry.value as Map<String, dynamic>;
      final uri = Uri.tryParse(item['url'] as String);
      if (uri == null) continue;
      services[entry.key] = SefazServiceEndpoint(
        url: uri,
        operation: item['operation'] as String,
        version: item['version'] as String,
        method: item['method'] as String,
      );
    }
    return SefazEndpointProfile(
      uf: normalizedUf,
      cUf: cUf,
      model: model,
      environment: environment,
      authorizer: authorizer,
      services: Map.unmodifiable(services),
    );
  }

  /// Cria uma configuração sem exigir URLs manuais.
  static SefazClientConfig clientConfig({
    required String uf,
    required int model,
    required int environment,
    PfxIdentity? certificate,
    Duration timeout = const Duration(seconds: 30),
    SefazRetryPolicy? retryPolicy,
    List<List<int>> trustedCertificates = const [],
  }) {
    final profile = resolve(uf: uf, model: model, environment: environment);
    final names = <SefazOperation, String>{
      SefazOperation.authorization: 'NfeAutorizacao',
      SefazOperation.receipt: 'NfeRetAutorizacao',
      SefazOperation.inutilization: 'NfeInutilizacao',
      SefazOperation.query: 'NfeConsultaProtocolo',
      SefazOperation.status: 'NfeStatusServico',
      SefazOperation.event: 'RecepcaoEvento',
      SefazOperation.distribution: 'NfeDistribuicaoDFe',
      SefazOperation.registration: 'NfeConsultaCadastro',
      SefazOperation.gtin: 'NfeConsultaGTIN',
      SefazOperation.download: 'NfeDownload',
    };
    final endpoints = <SefazOperation, Uri>{};
    final actions = <SefazOperation, String>{};
    for (final entry in names.entries) {
      final service = profile.service(entry.value);
      if (service != null) {
        endpoints[entry.key] = service.url;
        actions[entry.key] = _soapAction(service.operation);
      }
    }
    final primary =
        endpoints[SefazOperation.authorization] ??
        endpoints[SefazOperation.status];
    if (primary == null || primary.scheme != 'https') {
      throw FiscalValidationException(
        'A UF ${profile.uf} não possui endpoint HTTPS de autorização/status para o modelo $model.',
        code: 'SEFAZ_AUTHORIZATION_ENDPOINT_NOT_CATALOGUED',
      );
    }
    final version =
        profile.service('NfeAutorizacao')?.version ??
        profile.service('NfeStatusServico')?.version ??
        '4.00';
    return SefazClientConfig(
      endpoint: primary,
      uf: profile.cUf,
      environment: environment,
      model: model,
      serviceVersion: version,
      serviceActions: actions,
      serviceEndpoints: endpoints,
      timeout: timeout,
      retryPolicy: retryPolicy,
      certificate: certificate,
      trustedCertificates: trustedCertificates,
    );
  }

  /// Retorna a URL base do QR Code da NFC-e.
  static Uri qrCodeUrl({required String uf, required int environment}) =>
      resolve(uf: uf, model: 65, environment: environment).qrCodeUrl;

  /// Retorna o código IBGE de dois dígitos da UF.
  static String ufCode(String uf) =>
      resolve(uf: uf, model: 55, environment: 1).cUf;

  static Map<String, dynamic> _environmentServices(dynamic value, int env) {
    if (value is! Map<String, dynamic>) return const {};
    final services = value['$env'];
    return services is Map<String, dynamic> ? services : const {};
  }

  static String _soapAction(String operation) {
    final normalized = operation.trim();
    if (normalized.isEmpty || normalized.startsWith('http')) {
      return normalized;
    }
    return 'http://www.portalfiscal.inf.br/nfe/wsdl/$normalized';
  }

  static Map<String, dynamic> _load() {
    return _decoded ??=
        jsonDecode(
              utf8.decode(ZLibDecoder().decodeBytes(base64Decode(_compressed))),
            )
            as Map<String, dynamic>;
  }

  static const _ufCodes = <String, String>{
    'AC': '12',
    'AL': '27',
    'AP': '16',
    'AM': '13',
    'BA': '29',
    'CE': '23',
    'DF': '53',
    'ES': '32',
    'GO': '52',
    'MA': '21',
    'MT': '51',
    'MS': '50',
    'MG': '31',
    'PA': '15',
    'PB': '25',
    'PR': '41',
    'PE': '26',
    'PI': '22',
    'RJ': '33',
    'RN': '24',
    'RS': '43',
    'RO': '11',
    'RR': '14',
    'SC': '42',
    'SP': '35',
    'SE': '28',
    'TO': '17',
  };

  static const _compressed =
      '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';
}
