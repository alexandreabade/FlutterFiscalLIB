import 'package:xml/xml.dart';

import '../exceptions/fiscal_exception.dart';

/// Protocolo individual retornado dentro de um lote processado.
class SefazProtocol {
  /// Cria o resultado de uma NF-e dentro de um retorno de lote.
  const SefazProtocol({
    required this.statusCode,
    required this.reason,
    this.accessKey,
    this.protocol,
  });

  /// Código fiscal `cStat` do documento.
  final int statusCode;

  /// Mensagem fiscal `xMotivo` do documento.
  final String reason;

  /// Chave da NF-e, quando retornada.
  final String? accessKey;

  /// Protocolo de autorização, quando retornado.
  final String? protocol;
}

/// Resultado normalizado de um retorno XML da SEFAZ.
class SefazResult {
  /// Cria um resultado de autorização ou consulta.
  const SefazResult({
    required this.statusCode,
    required this.reason,
    this.receipt,
    this.accessKey,
    this.protocol,
    this.protocols = const [],
  });

  /// Código fiscal `cStat` retornado.
  final int statusCode;

  /// Mensagem fiscal `xMotivo` retornada.
  final String reason;

  /// Recibo de lote, quando a operação é assíncrona.
  final String? receipt;

  /// Chave retornada pelo protocolo, quando disponível.
  final String? accessKey;

  /// Número do protocolo de autorização/evento, quando disponível.
  final String? protocol;

  /// Resultados individuais quando a resposta contém um ou mais `infProt`.
  ///
  /// Os campos [accessKey] e [protocol] continuam apontando para o primeiro
  /// protocolo para preservar a API anterior; use esta coleção para processar
  /// corretamente lotes com documentos autorizados e rejeitados juntos.
  final List<SefazProtocol> protocols;

  /// Indica autorização de NF-e/NFC-e (`100` ou `150`).
  bool get isAuthorized => statusCode == 100 || statusCode == 150;

  /// Indica que a operação fiscal foi aceita, incluindo eventos e inutilização.
  bool get isAccepted => const {
    100,
    102,
    110,
    135,
    136,
    150,
    155,
    205,
    301,
    302,
    303,
  }.contains(statusCode);

  /// Indica autorização de evento fiscal (`135`, `136` ou `155`).
  bool get isEventAuthorized =>
      statusCode == 135 || statusCode == 136 || statusCode == 155;

  /// Indica homologação de inutilização (`102`).
  bool get isInutilizationAuthorized => statusCode == 102;

  /// Indica que o lote foi recebido ou ainda está sendo processado.
  bool get isReceiptPending => statusCode == 103 || statusCode == 105;

  /// Indica rejeição fiscal conhecida (`3xx`, `4xx` ou `5xx`).
  ///
  /// A SEFAZ utiliza, entre outros, códigos `539` e `599` para rejeições de
  /// regra de negócio; restringir a classificação a `4xx` deixaria esses
  /// documentos indevidamente em estado desconhecido.
  bool get isRejected => !isAccepted && statusCode >= 300 && statusCode < 600;

  /// Indica que o retorno não permite concluir o estado fiscal.
  bool get isUnknown => !isAccepted && !isRejected;
}

/// Interpreta retornos de serviços NFe 4.00 sem depender do prefixo XML.
class SefazResponseParser {
  /// Cria um parser sem estado.
  const SefazResponseParser();

  /// Analisa um XML retornado pela SEFAZ.
  SefazResult parse(String xml) {
    try {
      final document = XmlDocument.parse(xml);
      final elements = document.descendants.whereType<XmlElement>();
      final fault = elements.where((element) => element.localName == 'Fault');
      if (fault.isNotEmpty) {
        final faultElements = fault.first.descendants.whereType<XmlElement>();
        final code = _text(faultElements, 'Value');
        final reason =
            _text(faultElements, 'Text') ??
            _text(faultElements, 'faultstring') ??
            'Falha SOAP sem motivo informado';
        throw FiscalException(
          'A SEFAZ retornou uma falha SOAP${code == null ? '' : ' ($code)'}: '
          '$reason',
          code: 'SEFAZ_SOAP_FAULT',
        );
      }
      final protocolNodes = document.descendants
          .whereType<XmlElement>()
          .where((element) => element.localName == 'infProt')
          .toList();
      final outerStatus = _text(elements, 'cStat');
      final outerReason = _text(elements, 'xMotivo');
      final protocols = protocolNodes
          .map(
            (element) => _parseProtocol(
              element,
              fallbackStatus: outerStatus,
              fallbackReason: outerReason,
            ),
          )
          .toList();
      final protocolElements = protocolNodes.expand(
        (element) => element.descendants.whereType<XmlElement>(),
      );
      final cStat = _text(protocolElements, 'cStat') ?? outerStatus;
      if (cStat == null || !RegExp(r'^\d{3}$').hasMatch(cStat)) {
        throw const FiscalValidationException(
          'O retorno da SEFAZ não contém um cStat válido.',
          code: 'INVALID_SEFAZ_RESPONSE_STATUS',
        );
      }
      final statusCode = int.parse(cStat);
      return SefazResult(
        statusCode: statusCode,
        reason:
            _text(protocolElements, 'xMotivo') ??
            _text(elements, 'xMotivo') ??
            'Motivo não informado',
        receipt: _text(elements, 'nRec'),
        accessKey: _text(protocolElements, 'chNFe') ?? _text(elements, 'chNFe'),
        protocol: _text(protocolElements, 'nProt') ?? _text(elements, 'nProt'),
        protocols: List.unmodifiable(protocols),
      );
    } on FiscalException {
      rethrow;
    } on XmlException catch (error) {
      throw FiscalValidationException(
        'O retorno da SEFAZ não é um XML válido.',
        code: 'INVALID_SEFAZ_RESPONSE_XML',
        cause: error,
      );
    }
  }

  SefazProtocol _parseProtocol(
    XmlElement element, {
    String? fallbackStatus,
    String? fallbackReason,
  }) {
    final elements = element.descendants.whereType<XmlElement>();
    final cStat = _text(elements, 'cStat') ?? fallbackStatus;
    if (cStat == null || !RegExp(r'^\d{3}$').hasMatch(cStat)) {
      throw const FiscalValidationException(
        'O protocolo da SEFAZ não contém um cStat válido.',
        code: 'INVALID_SEFAZ_PROTOCOL_STATUS',
      );
    }
    return SefazProtocol(
      statusCode: int.parse(cStat),
      reason:
          _text(elements, 'xMotivo') ??
          fallbackReason ??
          'Motivo não informado',
      accessKey: _text(elements, 'chNFe'),
      protocol: _text(elements, 'nProt'),
    );
  }

  String? _text(Iterable<XmlElement> elements, String localName) {
    for (final element in elements) {
      if (element.localName == localName) {
        final value = element.innerText.trim();
        if (value.isNotEmpty) return value;
      }
    }
    return null;
  }
}
