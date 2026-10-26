import 'dart:convert';

import 'package:xml/xml.dart';

import '../exceptions/fiscal_exception.dart';
import '../tools.dart';
import '../models/access_key.dart';
import '../models/nfe_complements.dart';

/// Constrói envelopes XML de eventos NF-e sem assinatura.
///
/// O XML retornado deve ser assinado com o certificado do emitente antes do
/// envio à SEFAZ. Esta classe não simula protocolo nem autorização.
class NfeEventBuilder {
  /// Cria evento de cancelamento (`tpEvento=110111`).
  String cancelamento({
    required String accessKey,
    required int cOrgao,
    required int environment,
    required String issuerCnpj,
    required String protocol,
    required String justification,
    DateTime? eventDate,
    int sequence = 1,
  }) {
    _validateEvent(
      accessKey: accessKey,
      cOrgao: cOrgao,
      environment: environment,
      issuerCnpj: issuerCnpj,
      sequence: sequence,
    );
    _validateJustification(justification);
    if (protocol.trim().isEmpty) {
      throw const FiscalValidationException(
        'O protocolo de autorização é obrigatório para cancelamento.',
        code: 'INVALID_CANCEL_PROTOCOL',
      );
    }
    return _event(
      accessKey: accessKey,
      cOrgao: cOrgao,
      environment: environment,
      issuerCnpj: issuerCnpj,
      eventType: '110111',
      sequence: sequence,
      date: eventDate,
      description: 'Cancelamento',
      details: [_text('nProt', protocol), _text('xJust', justification)],
    );
  }

  /// Cria evento de cancelamento por substituição (`tpEvento=110112`).
  ///
  /// O protocolo informado é o da autorização da NF-e que será substituída;
  /// o XML ainda precisa ser assinado antes do envio.
  String cancelamentoPorSubstituicao({
    required String accessKey,
    required int cOrgao,
    required int environment,
    required String issuerCnpj,
    required String protocol,
    required String justification,
    String? referenceAccessKey,
    String? applicationVersion,
    DateTime? eventDate,
    int sequence = 1,
  }) {
    _validateEvent(
      accessKey: accessKey,
      cOrgao: cOrgao,
      environment: environment,
      issuerCnpj: issuerCnpj,
      sequence: sequence,
    );
    _validateJustification(justification);
    if (protocol.trim().isEmpty) {
      throw const FiscalValidationException(
        'O protocolo de autorização é obrigatório para cancelamento por '
        'substituição.',
        code: 'INVALID_CANCEL_PROTOCOL',
      );
    }
    final hasReference =
        referenceAccessKey != null || applicationVersion != null;
    if (hasReference &&
        (referenceAccessKey == null ||
            !AccessKey.isValid(referenceAccessKey) ||
            applicationVersion == null ||
            applicationVersion.trim().isEmpty ||
            applicationVersion.length > 20)) {
      throw const FiscalValidationException(
        'A chave da NFC-e substituta e a versão do aplicativo devem ser '
        'informadas juntas e ser válidas.',
        code: 'INVALID_CANCEL_SUBSTITUTION_DATA',
      );
    }
    return _event(
      accessKey: accessKey,
      cOrgao: cOrgao,
      environment: environment,
      issuerCnpj: issuerCnpj,
      eventType: '110112',
      sequence: sequence,
      date: eventDate,
      description: 'Cancelamento por substituicao',
      details: [
        if (hasReference) ...[
          _text('cOrgaoAutor', '$cOrgao'.padLeft(2, '0')),
          _text('tpAutor', '1'),
          _text('verAplic', applicationVersion!.trim()),
        ],
        _text('nProt', protocol),
        _text('xJust', justification),
        if (hasReference) _text('chNFeRef', referenceAccessKey!),
      ],
    );
  }

  /// Cria evento de carta de correção (`tpEvento=110110`).
  String cartaCorrecao({
    required String accessKey,
    required int cOrgao,
    required int environment,
    required String issuerCnpj,
    required String correction,
    DateTime? eventDate,
    int sequence = 1,
  }) {
    _validateEvent(
      accessKey: accessKey,
      cOrgao: cOrgao,
      environment: environment,
      issuerCnpj: issuerCnpj,
      sequence: sequence,
    );
    _validateJustification(correction, field: 'A correção');
    if (correction.length > 1000) {
      throw const FiscalValidationException(
        'A correção deve possuir no máximo 1000 caracteres.',
        code: 'INVALID_CORRECTION_LENGTH',
      );
    }
    return _event(
      accessKey: accessKey,
      cOrgao: cOrgao,
      environment: environment,
      issuerCnpj: issuerCnpj,
      eventType: '110110',
      sequence: sequence,
      date: eventDate,
      description: 'Carta de Correcao',
      details: [_text('xCorrecao', correction)],
    );
  }

  /// Cria pedido de prorrogação de retorno de industrialização (`111500` ou
  /// `111501`), equivalente a `Tools::sefazEPP()`.
  String prorrogacaoRetorno({
    required String accessKey,
    required int cOrgao,
    required int environment,
    required String issuerCnpj,
    required String protocol,
    required List<ReturnExtensionItem> items,
    int term = 1,
    DateTime? eventDate,
    int sequence = 1,
  }) {
    _validateEvent(
      accessKey: accessKey,
      cOrgao: cOrgao,
      environment: environment,
      issuerCnpj: issuerCnpj,
      sequence: sequence,
    );
    if (protocol.trim().isEmpty || items.isEmpty || (term != 1 && term != 2)) {
      throw const FiscalValidationException(
        'Protocolo, prazo e itens da prorrogação são inválidos.',
        code: 'INVALID_RETURN_EXTENSION',
      );
    }
    if (items.any(
      (item) =>
          item.number < 1 ||
          item.number > 999 ||
          !item.quantity.isFinite ||
          item.quantity <= 0,
    )) {
      throw const FiscalValidationException(
        'Os itens da prorrogação devem possuir número e quantidade positivos.',
        code: 'INVALID_RETURN_EXTENSION_ITEM',
      );
    }
    return _event(
      accessKey: accessKey,
      cOrgao: cOrgao,
      environment: environment,
      issuerCnpj: issuerCnpj,
      eventType: term == 1 ? '111500' : '111501',
      sequence: sequence,
      date: eventDate,
      description: 'Pedido de Prorrogacao',
      details: [
        _text('nProt', protocol),
        for (final item in items)
          XmlElement(
            XmlName.parts('itemPedido'),
            [XmlAttribute(XmlName.parts('numItem'), '${item.number}')],
            [_text('qtdeItem', item.quantity.toStringAsFixed(4))],
          ),
      ],
    );
  }

  /// Cria cancelamento de pedido de prorrogação (`111502` ou `111503`),
  /// equivalente a `Tools::sefazECPP()`.
  String cancelamentoProrrogacao({
    required String accessKey,
    required int cOrgao,
    required int environment,
    required String issuerCnpj,
    required String protocol,
    int term = 1,
    DateTime? eventDate,
    int sequence = 1,
  }) {
    _validateEvent(
      accessKey: accessKey,
      cOrgao: cOrgao,
      environment: environment,
      issuerCnpj: issuerCnpj,
      sequence: sequence,
    );
    if (protocol.trim().isEmpty || (term != 1 && term != 2)) {
      throw const FiscalValidationException(
        'Protocolo e prazo do cancelamento são inválidos.',
        code: 'INVALID_RETURN_EXTENSION_CANCEL',
      );
    }
    final originalType = term == 1 ? '111500' : '111501';
    final eventType = term == 1 ? '111502' : '111503';
    final originalId =
        'ID$originalType$accessKey${sequence.toString().padLeft(2, '0')}';
    return _event(
      accessKey: accessKey,
      cOrgao: cOrgao,
      environment: environment,
      issuerCnpj: issuerCnpj,
      eventType: eventType,
      sequence: sequence,
      date: eventDate,
      description: 'Cancelamento de Pedido de Prorrogacao',
      details: [
        _text('idPedidoCancelado', originalId),
        _text('nProt', protocol),
      ],
    );
  }

  /// Cria uma manifestação do destinatário.
  ///
  /// Os códigos aceitos são `210210` (ciência), `210200` (confirmação),
  /// `210220` (desconhecimento) e `210240` (operação não realizada).
  String manifestacao({
    required String accessKey,
    required int cOrgao,
    required int environment,
    required String participantTaxId,
    required String eventType,
    String? justification,
    DateTime? eventDate,
    int sequence = 1,
  }) {
    const eventTypes = {'210200', '210210', '210220', '210240'};
    if (!eventTypes.contains(eventType)) {
      throw const FiscalValidationException(
        'O tipo de manifestação deve ser 210200, 210210, 210220 ou 210240.',
        code: 'INVALID_MANIFESTATION_TYPE',
      );
    }
    _validateEventBase(
      accessKey: accessKey,
      cOrgao: cOrgao,
      environment: environment,
      sequence: sequence,
    );
    final taxId = Tools.onlyDigits(participantTaxId);
    if (taxId.length == 11) {
      if (!Tools.isValidCpf(taxId)) {
        throw const FiscalValidationException(
          'O CPF do manifestante é inválido.',
          code: 'INVALID_MANIFESTATION_TAX_ID',
        );
      }
    } else if (!Tools.isValidCnpj(taxId)) {
      throw const FiscalValidationException(
        'O CPF/CNPJ do manifestante é inválido.',
        code: 'INVALID_MANIFESTATION_TAX_ID',
      );
    }
    if (eventType == '210240') {
      _validateJustification(
        justification ?? '',
        field: 'A justificativa da operação não realizada',
      );
    } else if (justification != null && justification.trim().isNotEmpty) {
      throw const FiscalValidationException(
        'Justificativa só é permitida para operação não realizada.',
        code: 'UNEXPECTED_MANIFESTATION_JUSTIFICATION',
      );
    }
    const descriptions = {
      '210200': 'Confirmacao da Operacao',
      '210210': 'Ciencia da Operacao',
      '210220': 'Desconhecimento da Operacao',
      '210240': 'Operacao nao Realizada',
    };
    return _event(
      accessKey: accessKey,
      cOrgao: cOrgao,
      environment: environment,
      issuerCnpj: taxId,
      taxIdTag: taxId.length == 11 ? 'CPF' : 'CNPJ',
      eventType: eventType,
      sequence: sequence,
      date: eventDate,
      description: descriptions[eventType]!,
      details: [
        if (eventType == '210240') _text('xJust', justification!.trim()),
      ],
    );
  }

  /// Cria comprovante de entrega da NF-e (`tpEvento=110130`).
  ///
  /// [hashComprovante] deve ser o SHA-1 em Base64 do comprovante, portanto
  /// representa exatamente 20 bytes decodificados. O XML deve ser assinado
  /// antes do envio à SEFAZ.
  String comprovanteEntrega({
    required String accessKey,
    required int cOrgao,
    required int environment,
    required String issuerCnpj,
    required String applicationVersion,
    required DateTime deliveryDate,
    required String documentNumber,
    required String recipientName,
    required String hashComprovante,
    String? latitude,
    String? longitude,
    DateTime? hashDate,
    DateTime? eventDate,
  }) {
    _validateEvent(
      accessKey: accessKey,
      cOrgao: cOrgao,
      environment: environment,
      issuerCnpj: issuerCnpj,
      sequence: 1,
    );
    if (applicationVersion.trim().isEmpty ||
        applicationVersion.length > 20 ||
        documentNumber.trim().length < 2 ||
        documentNumber.trim().length > 20 ||
        recipientName.trim().length < 2 ||
        recipientName.trim().length > 60) {
      throw const FiscalValidationException(
        'Os dados do comprovante de entrega são inválidos.',
        code: 'INVALID_DELIVERY_DATA',
      );
    }
    try {
      if (base64Decode(hashComprovante).length != 20) {
        throw const FormatException();
      }
    } on FormatException catch (error) {
      throw FiscalValidationException(
        'hashComprovante deve ser SHA-1 em Base64 com 20 bytes.',
        code: 'INVALID_DELIVERY_HASH',
        cause: error,
      );
    }
    _validateGps(latitude, longitude);
    return _event(
      accessKey: accessKey,
      cOrgao: cOrgao,
      environment: environment,
      issuerCnpj: issuerCnpj,
      eventType: '110130',
      sequence: 1,
      date: eventDate,
      description: 'Comprovante de Entrega da NF-e',
      details: [
        _text('cOrgaoAutor', cOrgao.toString().padLeft(2, '0')),
        _text('tpAutor', '1'),
        _text('verAplic', applicationVersion.trim()),
        _text('dhEntrega', _dateTime(deliveryDate)),
        _text('nDoc', documentNumber.trim()),
        _text('xNome', recipientName.trim()),
        if (latitude != null) _text('latGPS', latitude),
        if (longitude != null) _text('longGPS', longitude),
        _text('hashComprovante', hashComprovante),
        if (hashDate != null) _text('dhHashComprovante', _dateTime(hashDate)),
      ],
    );
  }

  /// Cria o evento de insucesso na entrega (`110192`) ou seu cancelamento
  /// (`110193`).
  String insucessoEntrega({
    required String accessKey,
    required int cOrgao,
    required int environment,
    required String issuerCnpj,
    required DateTime attemptDate,
    required int reasonType,
    required String attemptHash,
    int attempts = 1,
    String? justification,
    String? latitude,
    String? longitude,
    String? protocol,
    bool cancel = false,
    DateTime? hashDate,
    DateTime? eventDate,
    int sequence = 1,
  }) {
    _validateEvent(
      accessKey: accessKey,
      cOrgao: cOrgao,
      environment: environment,
      issuerCnpj: issuerCnpj,
      sequence: sequence,
    );
    if (cancel && (protocol == null || protocol.trim().isEmpty)) {
      throw const FiscalValidationException(
        'O protocolo é obrigatório para cancelar o insucesso de entrega.',
        code: 'INVALID_DELIVERY_FAILURE_PROTOCOL',
      );
    }
    if (!cancel && (reasonType < 1 || reasonType > 4 || attempts < 1)) {
      throw const FiscalValidationException(
        'O motivo e o número de tentativas de entrega são inválidos.',
        code: 'INVALID_DELIVERY_FAILURE_DATA',
      );
    }
    if (!cancel &&
        reasonType == 4 &&
        (justification == null || justification.trim().isEmpty)) {
      throw const FiscalValidationException(
        'A justificativa é obrigatória para o motivo 4.',
        code: 'INVALID_DELIVERY_FAILURE_JUSTIFICATION',
      );
    }
    if (!cancel) _validateGps(latitude, longitude);
    final eventType = cancel ? '110193' : '110192';
    return _event(
      accessKey: accessKey,
      cOrgao: cOrgao,
      environment: environment,
      issuerCnpj: issuerCnpj,
      eventType: eventType,
      sequence: sequence,
      date: eventDate,
      description: cancel
          ? 'Cancelamento do Insucesso na Entrega'
          : 'Insucesso na Entrega',
      details: [
        if (!cancel) ...[
          _text('dhTentativaEntrega', _dateTime(attemptDate)),
          _text('nTentativa', '$attempts'),
          _text('tpMotivo', '$reasonType'),
          if (reasonType == 4) _text('xJustMotivo', justification!.trim()),
          if (latitude != null) _text('latGPS', latitude),
          if (longitude != null) _text('longGPS', longitude),
          _text('hashTentativaEntrega', attemptHash),
          if (hashDate != null)
            _text('dhHashTentativaEntrega', _dateTime(hashDate)),
        ],
        if (cancel) _text('nProtEvento', protocol!.trim()),
      ],
    );
  }

  /// Cria o evento de conciliação financeira (`110750`) ou seu cancelamento
  /// (`110751`).
  String conciliacaoFinanceira({
    required String accessKey,
    required int cOrgao,
    required int environment,
    required String issuerCnpj,
    required String applicationVersion,
    List<FinancialReconciliationPayment> payments = const [],
    bool cancel = false,
    String? protocol,
    DateTime? eventDate,
    int sequence = 1,
  }) {
    _validateEvent(
      accessKey: accessKey,
      cOrgao: cOrgao,
      environment: environment,
      issuerCnpj: issuerCnpj,
      sequence: sequence,
    );
    if (applicationVersion.trim().isEmpty || applicationVersion.length > 20) {
      throw const FiscalValidationException(
        'A versão do aplicativo é inválida.',
        code: 'INVALID_RECONCILIATION_VERSION',
      );
    }
    if (cancel && (protocol == null || protocol.trim().isEmpty)) {
      throw const FiscalValidationException(
        'O protocolo é obrigatório para cancelar a conciliação.',
        code: 'INVALID_RECONCILIATION_PROTOCOL',
      );
    }
    if (!cancel && payments.isEmpty) {
      throw const FiscalValidationException(
        'Informe ao menos um pagamento para a conciliação.',
        code: 'EMPTY_RECONCILIATION_PAYMENTS',
      );
    }
    return _event(
      accessKey: accessKey,
      cOrgao: cOrgao,
      environment: environment,
      issuerCnpj: issuerCnpj,
      eventType: cancel ? '110751' : '110750',
      sequence: sequence,
      date: eventDate,
      description: cancel
          ? 'Cancelamento da Conciliação Financeira'
          : 'Conciliação Financeira',
      details: [
        _text('verAplic', applicationVersion.trim()),
        if (cancel)
          _text('nProtEvento', protocol!.trim())
        else
          for (final payment in payments) payment.toXml(),
      ],
    );
  }

  /// Cria um evento EPEC (`tpEvento=110140`) para emissão em contingência.
  ///
  /// A chave precisa codificar `tpEmis=4`, conforme o leiaute oficial. O XML
  /// retornado ainda precisa ser assinado antes do envio.
  String epec({
    required String accessKey,
    required int cOrgao,
    required int environment,
    required String authorTaxId,
    required String issuerIe,
    required String applicationVersion,
    required DateTime issueDate,
    required num total,
    required num icms,
    String? destinationUf,
    String? destinationTaxId,
    DateTime? eventDate,
  }) {
    _validateEventBase(
      accessKey: accessKey,
      cOrgao: cOrgao,
      environment: environment,
      sequence: 1,
    );
    if (AccessKey.emissionTypeOf(accessKey) != 4) {
      throw const FiscalValidationException(
        'A chave do EPEC deve possuir tpEmis=4.',
        code: 'INVALID_EPEC_EMISSION_TYPE',
      );
    }
    if (issuerIe.trim().isEmpty ||
        applicationVersion.trim().isEmpty ||
        applicationVersion.length > 20) {
      throw const FiscalValidationException(
        'A IE do emitente e a versão do aplicativo são obrigatórias no EPEC.',
        code: 'INVALID_EPEC_ISSUER_DATA',
      );
    }
    _validateNonNegative(total, 'vNF');
    _validateNonNegative(icms, 'vICMS');
    final author = Tools.onlyDigits(authorTaxId);
    final authorTag = author.length == 11 ? 'CPF' : 'CNPJ';
    if (authorTag == 'CPF'
        ? !Tools.isValidCpf(author)
        : !Tools.isValidCnpj(author)) {
      throw const FiscalValidationException(
        'O CPF/CNPJ do autor do EPEC é inválido.',
        code: 'INVALID_EPEC_AUTHOR_TAX_ID',
      );
    }
    XmlElement? destination;
    if (destinationUf != null || destinationTaxId != null) {
      final uf = destinationUf?.trim().toUpperCase();
      if (uf == null || !RegExp(r'^[A-Z]{2}$').hasMatch(uf)) {
        throw const FiscalValidationException(
          'A UF do destinatário do EPEC deve possuir duas letras.',
          code: 'INVALID_EPEC_DESTINATION_UF',
        );
      }
      final taxId = Tools.onlyDigits(destinationTaxId ?? '');
      final tag = taxId.length == 11 ? 'CPF' : 'CNPJ';
      if (tag == 'CPF' ? !Tools.isValidCpf(taxId) : !Tools.isValidCnpj(taxId)) {
        throw const FiscalValidationException(
          'O CPF/CNPJ do destinatário do EPEC é inválido.',
          code: 'INVALID_EPEC_DESTINATION_TAX_ID',
        );
      }
      destination = XmlElement(XmlName.parts('dest'), const [], [
        _text('UF', uf),
        _text(tag, taxId),
      ]);
    }
    return _event(
      accessKey: accessKey,
      cOrgao: cOrgao,
      environment: environment,
      issuerCnpj: author,
      taxIdTag: authorTag,
      eventType: '110140',
      sequence: 1,
      date: eventDate,
      description: 'EPEC',
      details: [
        _text('cOrgaoAutor', cOrgao.toString().padLeft(2, '0')),
        _text('tpAutor', '1'),
        _text('verAplic', applicationVersion),
        _text('dhEmi', _dateTime(issueDate)),
        _text('tpNF', '1'),
        _text('IE', issuerIe),
        if (destination != null) destination,
        _text('vNF', _formatFiscal(total)),
        _text('vICMS', _formatFiscal(icms)),
      ],
    );
  }

  /// Cria o evento de ator interessado na NF-e (`tpEvento=110150`).
  ///
  /// O evento autoriza o transportador indicado em [authorizedTaxId] a
  /// acessar o XML da NF-e. [authorTaxId] pode ser CNPJ ou CPF; o XML deve
  /// ser assinado antes do envio.
  String atorInteressado({
    required String accessKey,
    required int cOrgao,
    required int environment,
    required String authorTaxId,
    required int authorStateCode,
    required String authorType,
    required String applicationVersion,
    required String authorizedTaxId,
    String? authorizationType,
    DateTime? occurredAt,
  }) {
    _validateEventBase(
      accessKey: accessKey,
      cOrgao: cOrgao,
      environment: environment,
      sequence: 1,
    );
    final author = Tools.onlyDigits(authorTaxId);
    final authorTag = author.length == 11 ? 'CPF' : 'CNPJ';
    if (authorTag == 'CPF'
        ? !Tools.isValidCpf(author)
        : !Tools.isValidCnpj(author)) {
      throw const FiscalValidationException(
        'O CPF/CNPJ do autor do evento é inválido.',
        code: 'INVALID_INTERESTED_ACTOR_AUTHOR',
      );
    }
    if (authorStateCode < 1 ||
        authorStateCode > 99 ||
        !const ['1', '2', '3'].contains(authorType) ||
        applicationVersion.trim().isEmpty ||
        applicationVersion.length > 20) {
      throw const FiscalValidationException(
        'Os dados do autor interessado são inválidos.',
        code: 'INVALID_INTERESTED_ACTOR_DATA',
      );
    }
    final authorized = Tools.onlyDigits(authorizedTaxId);
    final authorizedTag = authorized.length == 11 ? 'CPF' : 'CNPJ';
    if (authorizedTag == 'CPF'
        ? !Tools.isValidCpf(authorized)
        : !Tools.isValidCnpj(authorized)) {
      throw const FiscalValidationException(
        'O CPF/CNPJ autorizado para acesso ao XML é inválido.',
        code: 'INVALID_INTERESTED_ACTOR_AUTHORIZED',
      );
    }
    if (authorizationType != null &&
        !const ['0', '1'].contains(authorizationType)) {
      throw const FiscalValidationException(
        'tpAutorizacao deve ser 0 ou 1.',
        code: 'INVALID_INTERESTED_ACTOR_AUTHORIZATION',
      );
    }
    final condition =
        'O emitente ou destinatário da NF-e, declara que '
        'permite o transportador declarado no campo CNPJ/CPF deste evento a '
        'autorizar os transportadores subcontratados ou redespachados a '
        'terem acesso ao download da NF-e';
    return _event(
      accessKey: accessKey,
      cOrgao: cOrgao,
      environment: environment,
      issuerCnpj: author,
      taxIdTag: authorTag,
      eventType: '110150',
      sequence: 1,
      date: occurredAt,
      description: 'Ator interessado na NF-e',
      details: [
        _text('cOrgaoAutor', authorStateCode.toString().padLeft(2, '0')),
        _text('tpAutor', authorType),
        _text('verAplic', applicationVersion.trim()),
        XmlElement(XmlName.parts('autXML'), const [], [
          _text(authorizedTag, authorized),
        ]),
        if (authorizationType != null)
          _text('tpAutorizacao', authorizationType),
        if (authorizationType == '1') _text('xCondUso', condition),
      ],
    );
  }

  String _event({
    required String accessKey,
    required int cOrgao,
    required int environment,
    required String issuerCnpj,
    String taxIdTag = 'CNPJ',
    required String eventType,
    required int sequence,
    required DateTime? date,
    required String description,
    required List<XmlElement> details,
  }) {
    final inf = XmlElement(
      XmlName.parts('infEvento'),
      [
        XmlAttribute(
          XmlName.parts('Id'),
          'ID$eventType$accessKey${sequence.toString().padLeft(2, '0')}',
        ),
      ],
      [
        _text('cOrgao', cOrgao.toString().padLeft(2, '0')),
        _text('tpAmb', '$environment'),
        _text(taxIdTag, issuerCnpj),
        _text('chNFe', accessKey),
        _text('dhEvento', _dateTime(date ?? DateTime.now())),
        _text('tpEvento', eventType),
        _text('nSeqEvento', '$sequence'),
        _text('verEvento', '1.00'),
        XmlElement(
          XmlName.parts('detEvento'),
          [XmlAttribute(XmlName.parts('versao'), '1.00')],
          [_text('descEvento', description), ...details],
        ),
      ],
    );
    final root = XmlElement(
      XmlName.parts('envEvento'),
      [
        XmlAttribute(
          XmlName.parts('xmlns'),
          'http://www.portalfiscal.inf.br/nfe',
        ),
        XmlAttribute(XmlName.parts('versao'), '1.00'),
      ],
      [
        _text(
          'idLote',
          (DateTime.now().microsecondsSinceEpoch % 1000000000000000)
              .toString()
              .padLeft(15, '0'),
        ),
        XmlElement(
          XmlName.parts('evento'),
          [XmlAttribute(XmlName.parts('versao'), '1.00')],
          [inf],
        ),
      ],
    );
    return XmlDocument([root]).toXmlString(pretty: true, indent: '  ');
  }

  void _validateEvent({
    required String accessKey,
    required int cOrgao,
    required int environment,
    required String issuerCnpj,
    required int sequence,
  }) {
    _validateEventBase(
      accessKey: accessKey,
      cOrgao: cOrgao,
      environment: environment,
      sequence: sequence,
    );
    if (!Tools.isValidCnpj(issuerCnpj)) {
      throw const FiscalValidationException(
        'O CNPJ do emitente é inválido.',
        code: 'INVALID_EVENT_CNPJ',
      );
    }
  }

  void _validateEventBase({
    required String accessKey,
    required int cOrgao,
    required int environment,
    required int sequence,
  }) {
    if (!AccessKey.isValid(accessKey)) {
      throw const FiscalValidationException(
        'A chave da NF-e é inválida.',
        code: 'INVALID_EVENT_ACCESS_KEY',
      );
    }
    if (cOrgao < 1 || cOrgao > 99) {
      throw const FiscalValidationException(
        'O código do órgão deve estar entre 01 e 99.',
        code: 'INVALID_EVENT_AUTHORITY',
      );
    }
    if (environment != 1 && environment != 2) {
      throw const FiscalValidationException(
        'O ambiente do evento deve ser 1 ou 2.',
        code: 'INVALID_EVENT_ENVIRONMENT',
      );
    }
    if (sequence < 1 || sequence > 20) {
      throw const FiscalValidationException(
        'A sequência do evento deve estar entre 1 e 20.',
        code: 'INVALID_EVENT_SEQUENCE',
      );
    }
  }

  void _validateNonNegative(num value, String field) {
    if (!value.isFinite || value < 0) {
      throw FiscalValidationException(
        'O valor $field do EPEC deve ser finito e não negativo.',
        code: 'INVALID_EPEC_VALUE',
      );
    }
  }

  void _validateGps(String? latitude, String? longitude) {
    if ((latitude == null) != (longitude == null)) {
      throw const FiscalValidationException(
        'Latitude e longitude devem ser informadas juntas.',
        code: 'INVALID_DELIVERY_GPS',
      );
    }
    if (latitude != null &&
        (!RegExp(r'^-?(?:\d|[1-8]\d|90)\.\d{6}$').hasMatch(latitude) ||
            !RegExp(
              r'^-?(?:\d|[1-9]\d|1[0-7]\d|180)\.\d{6}$',
            ).hasMatch(longitude!))) {
      throw const FiscalValidationException(
        'Latitude ou longitude do comprovante de entrega é inválida.',
        code: 'INVALID_DELIVERY_GPS',
      );
    }
  }

  String _formatFiscal(num value) => value.toStringAsFixed(2);

  String _dateTime(DateTime value) {
    final date = value.toUtc();
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}T'
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}:'
        '${date.second.toString().padLeft(2, '0')}+00:00';
  }

  void _validateJustification(
    String value, {
    String field = 'A justificativa',
  }) {
    if (value.trim().length < 15) {
      throw FiscalValidationException(
        '$field deve possuir pelo menos 15 caracteres.',
        code: 'INVALID_EVENT_JUSTIFICATION',
      );
    }
  }

  XmlElement _text(String name, String value) =>
      XmlElement(XmlName.parts(name), const [], [XmlText(value)]);
}

/// Pagamento informado no evento de conciliação financeira.
class FinancialReconciliationPayment {
  /// Cria um detalhe `detPag` do evento de conciliação.
  const FinancialReconciliationPayment({
    required this.paymentType,
    required this.value,
    this.paymentDate,
    this.description,
  });

  /// Código do meio de pagamento (`tPag`).
  final String paymentType;

  /// Valor conciliado (`vPag`).
  final num value;

  /// Data do pagamento (`dPag`), quando aplicável.
  final DateTime? paymentDate;

  /// Descrição de meio de pagamento (`xPag`).
  final String? description;

  /// Converte o detalhe para o elemento XML `detPag`.
  XmlElement toXml() => XmlElement(XmlName.parts('detPag'), const [], [
    XmlElement(XmlName.parts('indPag'), const [], [XmlText('0')]),
    XmlElement(XmlName.parts('tPag'), const [], [XmlText(paymentType)]),
    if (description != null)
      XmlElement(XmlName.parts('xPag'), const [], [XmlText(description!)]),
    XmlElement(XmlName.parts('vPag'), const [], [
      XmlText(value.toStringAsFixed(2)),
    ]),
    if (paymentDate != null)
      XmlElement(XmlName.parts('dPag'), const [], [
        XmlText(paymentDate!.toIso8601String().substring(0, 10)),
      ]),
  ]);
}

/// Constrói o pedido de inutilização de numeração sem assinatura.
class NfeInutilizationBuilder {
  /// Constrói `inutNFe` para uma faixa de numeração.
  String build({
    required String cUf,
    required int environment,
    required String issuerCnpj,
    required int model,
    required int series,
    required int startNumber,
    required int endNumber,
    required String reason,
    DateTime? year,
  }) {
    if (!RegExp(r'^\d{2}$').hasMatch(cUf)) {
      throw const FiscalValidationException(
        'O código da UF deve conter dois dígitos.',
        code: 'INVALID_INUTILIZATION_UF',
      );
    }
    if (environment != 1 && environment != 2 || model != 55 && model != 65) {
      throw const FiscalValidationException(
        'Ambiente ou modelo inválido para inutilização.',
        code: 'INVALID_INUTILIZATION_CONTEXT',
      );
    }
    if (!Tools.isValidCnpj(issuerCnpj)) {
      throw const FiscalValidationException(
        'O CNPJ do emitente é inválido.',
        code: 'INVALID_INUTILIZATION_CNPJ',
      );
    }
    if (series < 0 ||
        series > 999 ||
        startNumber < 1 ||
        endNumber < startNumber ||
        endNumber > 999999999) {
      throw const FiscalValidationException(
        'Série ou faixa de numeração inválida.',
        code: 'INVALID_INUTILIZATION_RANGE',
      );
    }
    if (reason.trim().length < 15 || reason.length > 255) {
      throw const FiscalValidationException(
        'A justificativa deve possuir entre 15 e 255 caracteres.',
        code: 'INVALID_INUTILIZATION_REASON',
      );
    }
    final referenceYear = (year ?? DateTime.now()).year % 100;
    final serie = series.toString().padLeft(3, '0');
    final ini = startNumber.toString().padLeft(9, '0');
    final fin = endNumber.toString().padLeft(9, '0');
    final id =
        'ID$cUf${referenceYear.toString().padLeft(2, '0')}'
        '${Tools.onlyDigits(issuerCnpj)}${model.toString().padLeft(2, '0')}'
        '$serie$ini$fin';
    final root = XmlElement(
      XmlName.parts('inutNFe'),
      [
        XmlAttribute(
          XmlName.parts('xmlns'),
          'http://www.portalfiscal.inf.br/nfe',
        ),
        XmlAttribute(XmlName.parts('versao'), '4.00'),
      ],
      [
        XmlElement(
          XmlName.parts('infInut'),
          [XmlAttribute(XmlName.parts('Id'), id)],
          [
            _text('tpAmb', '$environment'),
            _text('xServ', 'INUTILIZAR'),
            _text('cUF', cUf),
            _text('ano', referenceYear.toString().padLeft(2, '0')),
            _text('CNPJ', Tools.onlyDigits(issuerCnpj)),
            _text('mod', '$model'),
            _text('serie', '$series'),
            _text('nNFIni', '$startNumber'),
            _text('nNFFin', '$endNumber'),
            _text('xJust', reason),
          ],
        ),
      ],
    );
    return XmlDocument([root]).toXmlString(pretty: true, indent: '  ');
  }

  XmlElement _text(String name, String value) =>
      XmlElement(XmlName.parts(name), const [], [XmlText(value)]);
}
