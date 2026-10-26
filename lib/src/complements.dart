import 'package:xml/xml.dart';

import 'exceptions/fiscal_exception.dart';

/// Complementos pós-autorização inspirados no NFePHP `Complements`.
class Complements {
  Complements._();

  /// Status que representam autorização/denegação processável no protocolo.
  static const acceptedStatuses = <String>{
    '100',
    '110',
    '150',
    '205',
    '301',
    '302',
    '303',
  };

  /// Anexa uma tag B2B a um documento protocolado, como `b2bTag()` do
  /// NFePHP, produzindo um envelope `nfeProcB2B`.
  static String b2bTag(String nfe, String b2b, {String tagName = 'NFeB2BFin'}) {
    final nfeDocument = _parse(nfe);
    if (nfeDocument.rootElement.localName != 'nfeProc') {
      throw const FiscalValidationException(
        'O documento deve ser um nfeProc protocolado.',
        code: 'INVALID_B2B_DOCUMENT',
      );
    }
    final b2bDocument = _parse(b2b);
    final tag = b2bDocument.descendants
        .whereType<XmlElement>()
        .where((element) => element.localName == tagName)
        .firstOrNull;
    if (tag == null) {
      throw FiscalValidationException(
        'A tag B2B $tagName não foi encontrada.',
        code: 'MISSING_B2B_TAG',
      );
    }
    final envelope = XmlElement(XmlName.parts('nfeProcB2B'), const [], [
      nfeDocument.rootElement.copy(),
      tag.copy(),
    ]);
    return XmlDocument([envelope]).toXmlString(pretty: false);
  }

  /// Registra o cancelamento no protocolo, seguindo `Complements::cancelRegister()`.
  static String cancelRegister(String nfe, String cancellationResponse) {
    final document = _parse(nfe);
    final protocol = document.rootElement.getElement('protNFe');
    final key = protocol
        ?.getElement('infProt')
        ?.getElement('chNFe')
        ?.innerText
        .trim();
    if (document.rootElement.localName != 'nfeProc' || key == null) {
      throw const FiscalValidationException(
        'A NF-e precisa estar protocolada em nfeProc.',
        code: 'INVALID_PROTOCOL_DOCUMENT',
      );
    }
    final response = _parse(cancellationResponse);
    for (final event in response.findAllElements('retEvento')) {
      final info = event.getElement('infEvento');
      final status = info?.getElement('cStat')?.innerText.trim();
      final eventType = info?.getElement('tpEvento')?.innerText.trim();
      final eventKey = info?.getElement('chNFe')?.innerText.trim();
      final eventProtocol = info?.getElement('nProt')?.innerText.trim();
      if ({'135', '136', '155'}.contains(status) &&
          {'110111', '110112'}.contains(eventType) &&
          eventKey == key &&
          eventProtocol != null &&
          eventProtocol.isNotEmpty) {
        final infoProtocol = protocol!.getElement('infProt');
        if (infoProtocol == null) return nfe;
        _replaceText(infoProtocol, 'cStat', '101');
        _replaceText(infoProtocol, 'nProt', eventProtocol);
        _replaceText(
          infoProtocol,
          'xMotivo',
          'Cancelamento de NF-e homologado',
        );
        return document.toXmlString(pretty: true, indent: '  ');
      }
    }
    return nfe;
  }

  /// Junta uma NF-e e seu `protNFe` em um `nfeProc`.
  static String toAuthorize(String request, String response) {
    if (request.trim().isEmpty || response.trim().isEmpty) {
      throw const FiscalValidationException(
        'XML da requisição e resposta são obrigatórios.',
        code: 'EMPTY_PROTOCOL_XML',
      );
    }
    final requestDocument = _parse(request);
    final responseDocument = _parse(response);
    switch (requestDocument.rootElement.localName) {
      case 'envEvento':
        return _authorizeEvent(requestDocument, responseDocument);
      case 'inutNFe':
        return _authorizeInutilization(requestDocument, responseDocument);
      case 'NFe':
        break;
      default:
        throw const FiscalValidationException(
          'O documento não é NFe, envEvento ou inutNFe.',
          code: 'INVALID_PROTOCOL_REQUEST',
        );
    }
    final nfe = requestDocument.rootElement.localName == 'NFe'
        ? requestDocument.rootElement
        : requestDocument.rootElement.getElement('NFe');
    if (nfe == null) {
      throw const FiscalValidationException(
        'A requisição não contém uma NF-e.',
        code: 'INVALID_PROTOCOL_REQUEST',
      );
    }
    final infNfe = nfe.getElement('infNFe');
    final id = infNfe?.getAttribute('Id');
    final key = id != null && id.startsWith('NFe') ? id.substring(3) : null;
    final protocol = responseDocument.rootElement.localName == 'protNFe'
        ? responseDocument.rootElement
        : responseDocument.rootElement.getElement('protNFe');
    final infProt = protocol?.getElement('infProt');
    if (protocol == null || infProt == null || key == null) {
      throw const FiscalValidationException(
        'A resposta não contém protNFe/infProt ou a requisição não possui chave.',
        code: 'INVALID_PROTOCOL_RESPONSE',
      );
    }
    final status = infProt.getElement('cStat')?.innerText.trim();
    if (status == null || !acceptedStatuses.contains(status)) {
      final reason = infProt.getElement('xMotivo')?.innerText.trim() ?? '';
      throw FiscalValidationException(
        'A NF-e não foi autorizada: [$status] $reason',
        code: 'NFE_NOT_AUTHORIZED',
      );
    }
    final responseKey = infProt.getElement('chNFe')?.innerText.trim();
    if (responseKey != key) {
      throw const FiscalValidationException(
        'A chave do protocolo diverge da chave da NF-e.',
        code: 'PROTOCOL_KEY_MISMATCH',
      );
    }
    final requestDigest = nfe
        .findAllElements('DigestValue')
        .firstOrNull
        ?.innerText
        .trim();
    final protocolDigest = infProt.getElement('digVal')?.innerText.trim();
    if (requestDigest != null &&
        requestDigest.isNotEmpty &&
        requestDigest != protocolDigest) {
      throw const FiscalValidationException(
        'O digest do protocolo diverge do digest da NF-e.',
        code: 'PROTOCOL_DIGEST_MISMATCH',
      );
    }
    final version =
        infNfe?.getAttribute('versao') ??
        protocol.getAttribute('versao') ??
        '4.00';
    final processed = XmlElement(
      XmlName.parts('nfeProc'),
      [
        XmlAttribute(XmlName.parts('versao'), version),
        XmlAttribute(
          XmlName.parts('xmlns'),
          'http://www.portalfiscal.inf.br/nfe',
        ),
      ],
      [nfe.copy(), protocol.copy()],
    );
    return XmlDocument([processed]).toXmlString(pretty: true, indent: '  ');
  }

  static String _authorizeEvent(XmlDocument request, XmlDocument response) {
    final event = request.rootElement.getElement('evento');
    final returned = response.rootElement.getElement('retEvento');
    final requestBatch = request.rootElement
        .getElement('idLote')
        ?.innerText
        .trim();
    final responseBatch = response.rootElement
        .getElement('idLote')
        ?.innerText
        .trim();
    final info = returned?.getElement('infEvento');
    final status = info?.getElement('cStat')?.innerText.trim();
    final type = info?.getElement('tpEvento')?.innerText.trim();
    final validStatuses = <String>{'135', '136'};
    if (type == '110111') validStatuses.add('155');
    if (event == null ||
        returned == null ||
        info == null ||
        requestBatch == null ||
        responseBatch != requestBatch ||
        status == null ||
        !validStatuses.contains(status)) {
      final reason = info?.getElement('xMotivo')?.innerText.trim() ?? '';
      throw FiscalValidationException(
        'O evento não foi autorizado: [$status] $reason',
        code: 'EVENT_NOT_AUTHORIZED',
      );
    }
    final version = event.getAttribute('versao') ?? '1.00';
    return _joinProtocol(
      name: 'procEventoNFe',
      version: version,
      children: [event.copy(), returned.copy()],
    );
  }

  static String _authorizeInutilization(
    XmlDocument request,
    XmlDocument response,
  ) {
    final inutilization = request.rootElement;
    final returned = response.rootElement.localName == 'retInutNFe'
        ? response.rootElement
        : response.rootElement.getElement('retInutNFe');
    final requestInfo = inutilization.getElement('infInut');
    final responseInfo = returned?.getElement('infInut');
    if (returned == null ||
        requestInfo == null ||
        responseInfo == null ||
        responseInfo.getElement('cStat')?.innerText.trim() != '102') {
      final status = responseInfo?.getElement('cStat')?.innerText.trim();
      final reason =
          responseInfo?.getElement('xMotivo')?.innerText.trim() ?? '';
      throw FiscalValidationException(
        'A inutilização não foi autorizada: [$status] $reason',
        code: 'INUTILIZATION_NOT_AUTHORIZED',
      );
    }
    const fields = [
      'tpAmb',
      'cUF',
      'ano',
      'CNPJ',
      'mod',
      'serie',
      'nNFIni',
      'nNFFin',
    ];
    for (final field in fields) {
      if (requestInfo.getElement(field)?.innerText.trim() !=
          responseInfo.getElement(field)?.innerText.trim()) {
        throw const FiscalValidationException(
          'A resposta da inutilização diverge da requisição.',
          code: 'INUTILIZATION_MISMATCH',
        );
      }
    }
    return _joinProtocol(
      name: 'procInutNFe',
      version: inutilization.getAttribute('versao') ?? '4.00',
      children: [inutilization.copy(), returned.copy()],
    );
  }

  static String _joinProtocol({
    required String name,
    required String version,
    required List<XmlNode> children,
  }) {
    final root = XmlElement(XmlName.parts(name), [
      XmlAttribute(XmlName.parts('versao'), version),
      XmlAttribute(
        XmlName.parts('xmlns'),
        'http://www.portalfiscal.inf.br/nfe',
      ),
    ], children);
    return XmlDocument([root]).toXmlString(pretty: true, indent: '  ');
  }

  static XmlDocument _parse(String xml) {
    try {
      return XmlDocument.parse(xml);
    } on XmlException catch (error) {
      throw FiscalValidationException(
        'XML de protocolo inválido.',
        code: 'INVALID_PROTOCOL_XML',
        cause: error,
      );
    }
  }

  static void _replaceText(XmlElement parent, String name, String value) {
    final element = parent.getElement(name);
    if (element == null) return;
    element.children
      ..clear()
      ..add(XmlText(value));
  }
}
