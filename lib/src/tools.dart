import 'crypto/xml_signature_service.dart';
import 'package:xml/xml.dart';
import 'models/access_key.dart';
import 'models/nfe_complements.dart';
import 'common/fiscal_decimal.dart';
import 'exceptions/fiscal_exception.dart';
import 'sefaz/sefaz_client.dart';
import 'validation/nfe_xml_validator.dart';
import 'xml/nfe_event_builder.dart';

/// Utilitários fiscais equivalentes ao núcleo de `Tools` do NFePHP.
class Tools {
  /// Cria a fachada de operações SEFAZ compatível com os métodos de
  /// transporte do NFePHP. Os parâmetros fiscais ausentes na API PHP devem
  /// ser informados explicitamente pelos métodos Dart.
  Tools({required this._sefaz, this.signer, this.signatureVerifier});

  final SefazClient _sefaz;

  /// Assinador opcional usado automaticamente nos eventos `envEvento`.
  /// Quando ausente, os métodos mantêm o comportamento compatível de enviar
  /// o XML pré-assinatura para permitir integração com assinadores externos.
  final XmlSignatureService? signer;

  /// Verificador usado por [sefazValidate] para aceitar somente XMLDSig
  /// criptograficamente válido. Deve ser configurado pela aplicação com a
  /// chave pública correspondente ao certificado do emitente.
  final NfeXmlSignatureVerifier? signatureVerifier;

  /// Retorna somente os dígitos de [value].
  static String onlyDigits(String value) => value.replaceAll(RegExp(r'\D'), '');

  /// Formata um valor decimal para a representação fiscal com [scale] casas.
  static String formatDecimal(num value, {int scale = 2}) =>
      FiscalDecimal.fromNum(value).toFixed(scale);

  /// Verifica uma chave de acesso completa.
  static bool isValidAccessKey(String value) => AccessKey.isValid(value);

  /// Verifica CNPJ usando os dois dígitos verificadores oficiais.
  static bool isValidCnpj(String value) {
    final digits = onlyDigits(value);
    if (digits.length != 14 || RegExp(r'^(\d)\1{13}$').hasMatch(digits)) {
      return false;
    }
    final first = _cnpjDigit(digits.substring(0, 12));
    final second = _cnpjDigit('${digits.substring(0, 12)}$first');
    return digits == '${digits.substring(0, 12)}$first$second';
  }

  /// Verifica CPF com os dois dígitos verificadores oficiais.
  static bool isValidCpf(String value) {
    final digits = onlyDigits(value);
    if (digits.length != 11 || RegExp(r'^(\d)\1{10}$').hasMatch(digits)) {
      return false;
    }
    final first = _cpfDigit(digits.substring(0, 9));
    final second = _cpfDigit('${digits.substring(0, 9)}$first');
    return digits == '${digits.substring(0, 9)}$first$second';
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

  SefazClient get _client => _sefaz;

  /// Equivalente a `Tools::sefazEnviaLote()` para uma ou mais NF-e.
  Future<SefazResponse> sefazEnviaLote(
    List<String> xmls, {
    String lotId = '1',
    int synchronous = 0,
    bool compactar = false,
  }) {
    if (xmls.isEmpty) {
      throw const FiscalValidationException(
        'O lote deve possuir ao menos uma NF-e.',
        code: 'EMPTY_BATCH',
      );
    }
    if (synchronous == 1 && xmls.length != 1) {
      throw const FiscalValidationException(
        'O envio síncrono deve conter uma única NF-e.',
        code: 'SYNC_BATCH_MULTIPLE_DOCUMENTS',
      );
    }
    return _client.sefazEnviaLote(
      lotId,
      xmls.join(),
      synchronous: synchronous,
      compress: compactar,
    );
  }

  /// Equivalente a `Tools::sefazConsultaRecibo()`.
  Future<SefazResponse> sefazConsultaRecibo(
    String receipt, {
    required int environment,
  }) => _client.sefazConsultaRecibo(receipt, environment: environment);

  /// Equivalente a `Tools::sefazConsultaChave()`.
  Future<SefazResponse> sefazConsultaChave(
    String accessKey, {
    required int environment,
  }) => _client.sefazConsultaChave(accessKey, environment: environment);

  /// Equivalente a `Tools::sefazDistDFe()` para distribuição de documentos.
  Future<SefazResponse> sefazDistDFe({
    required String cUfAutor,
    required int environment,
    required String actorTaxId,
    String? lastNsu,
    String? nsu,
    String? accessKey,
  }) => _client.sefazDistribuicaoDFe(
    cUfAutor: cUfAutor,
    environment: environment,
    actorTaxId: actorTaxId,
    lastNsu: lastNsu,
    nsu: nsu,
    accessKey: accessKey,
  );

  /// Equivalente a `Tools::sefazConsultaCadastro()`.
  Future<SefazResponse> sefazConsultaCadastro({
    required String uf,
    required int environment,
    String? cnpj,
    String? cpf,
    String? ie,
  }) => _client.sefazConsultaCadastro(
    uf: uf,
    environment: environment,
    cnpj: cnpj,
    cpf: cpf,
    ie: ie,
  );

  /// Alias compatível com `Tools::sefazCadastro()`.
  Future<SefazResponse> sefazCadastro(
    String uf, {
    required int environment,
    String? cnpj,
    String? cpf,
    String? ie,
  }) => sefazConsultaCadastro(
    uf: uf,
    environment: environment,
    cnpj: cnpj,
    cpf: cpf,
    ie: ie,
  );

  /// Equivalente a `Tools::sefazConsultaGTIN()`.
  Future<SefazResponse> sefazConsultaGtin(String gtin) =>
      _client.sefazConsultaGtin(gtin);

  /// Alias com a capitalização exata da API PHP (`sefazConsultaGTIN`).
  Future<SefazResponse> sefazConsultaGTIN(String gtin) =>
      sefazConsultaGtin(gtin);

  /// Equivalente a `Tools::sefazDownload()` para uma ou mais chaves.
  Future<SefazResponse> sefazDownload({
    required int environment,
    required String recipientCnpj,
    required List<String> accessKeys,
  }) => _client.sefazDownloadNFe(
    environment: environment,
    recipientCnpj: recipientCnpj,
    accessKeys: accessKeys,
  );

  /// Equivalente a `Tools::sefazStatus()`.
  Future<SefazResponse> sefazStatus({
    required String uf,
    required int environment,
  }) => _client.sefazStatusServico(cUf: uf, environment: environment);

  /// Administra o CSC da NFC-e (`Tools::sefazCsc()`).
  ///
  /// O endpoint e a ação SOAP permanecem configuráveis em [SefazClient].
  Future<SefazResponse> sefazCsc({
    required int operationCode,
    required int environment,
    required int model,
    required String rootCnpj,
    String? cscId,
    String? cscCode,
  }) {
    if (operationCode < 1 || operationCode > 3) {
      throw const FiscalValidationException(
        'A operação CSC deve ser 1, 2 ou 3.',
        code: 'INVALID_CSC_OPERATION',
      );
    }
    if ((environment != 1 && environment != 2) || model != 65) {
      throw const FiscalValidationException(
        'O CSC só pode ser administrado para NFC-e nos ambientes 1 ou 2.',
        code: 'INVALID_CSC_CONTEXT',
      );
    }
    final digits = onlyDigits(rootCnpj);
    final root = digits.length == 14
        ? digits.substring(0, 8)
        : digits.length == 8
        ? digits
        : '';
    if (root.isEmpty ||
        operationCode == 3 &&
            (cscId == null ||
                cscId.trim().isEmpty ||
                cscCode == null ||
                cscCode.trim().isEmpty)) {
      throw const FiscalValidationException(
        'A raiz do CNPJ e os dados do CSC são inválidos.',
        code: 'INVALID_CSC_DATA',
      );
    }
    final rootElement = XmlElement(
      XmlName.parts('admCscNFCe'),
      [
        XmlAttribute(
          XmlName.parts('xmlns'),
          'http://www.portalfiscal.inf.br/nfe',
        ),
        XmlAttribute(XmlName.parts('versao'), _client.serviceVersion),
      ],
      [
        _xmlText('tpAmb', '$environment'),
        _xmlText('indOp', '$operationCode'),
        _xmlText('raizCNPJ', root),
        if (operationCode == 3)
          XmlElement(XmlName.parts('dadosCsc'), const [], [
            _xmlText('idCsc', cscId),
            _xmlText('codigoCsc', cscCode),
          ]),
      ],
    );
    return _client.sendXml(
      rootElement.toXmlString(pretty: false),
      wrapInNfeDadosMsg: true,
    );
  }

  /// Equivalente a `Tools::sefazInutiliza()` usando o builder tipado.
  Future<SefazResponse> sefazInutiliza({
    required String cUf,
    required int environment,
    required String issuerCnpj,
    required int model,
    required int series,
    required int startNumber,
    required int endNumber,
    required String reason,
    DateTime? year,
  }) async {
    final xml = NfeInutilizationBuilder().build(
      cUf: cUf,
      environment: environment,
      issuerCnpj: issuerCnpj,
      model: model,
      series: series,
      startNumber: startNumber,
      endNumber: endNumber,
      reason: reason,
      year: year,
    );
    final signed = signer == null ? xml : await signer!.signInutilization(xml);
    return _client.sefazInutilizacao(signed);
  }

  /// Equivalente a `Tools::sefazCancela()`; gera e envia o evento.
  Future<SefazResponse> sefazCancela({
    required String accessKey,
    required int cOrgao,
    required int environment,
    required String issuerCnpj,
    required String protocol,
    required String justification,
    DateTime? eventDate,
    int sequence = 1,
  }) async {
    final event = NfeEventBuilder().cancelamento(
      accessKey: accessKey,
      cOrgao: cOrgao,
      environment: environment,
      issuerCnpj: issuerCnpj,
      protocol: protocol,
      justification: justification,
      eventDate: eventDate,
      sequence: sequence,
    );
    return _sendEvent(event);
  }

  /// Envia cancelamento por substituição (`tpEvento=110112`).
  Future<SefazResponse> sefazCancelaPorSubstituicao({
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
  }) async {
    if (_client.model == 65 &&
        (referenceAccessKey == null || applicationVersion == null)) {
      throw const FiscalValidationException(
        'Cancelamento por substituição de NFC-e exige a chave da NFC-e '
        'substituta e a versão do aplicativo.',
        code: 'INVALID_CANCEL_SUBSTITUTION_DATA',
      );
    }
    final event = NfeEventBuilder().cancelamentoPorSubstituicao(
      accessKey: accessKey,
      cOrgao: cOrgao,
      environment: environment,
      issuerCnpj: issuerCnpj,
      protocol: protocol,
      justification: justification,
      referenceAccessKey: referenceAccessKey,
      applicationVersion: applicationVersion,
      eventDate: eventDate,
      sequence: sequence,
    );
    return _sendEvent(event);
  }

  /// Equivalente a `Tools::sefazCCe()`; gera e envia a Carta de Correção.
  Future<SefazResponse> sefazCCe({
    required String accessKey,
    required int cOrgao,
    required int environment,
    required String issuerCnpj,
    required String correction,
    DateTime? eventDate,
    int sequence = 1,
  }) async {
    final event = NfeEventBuilder().cartaCorrecao(
      accessKey: accessKey,
      cOrgao: cOrgao,
      environment: environment,
      issuerCnpj: issuerCnpj,
      correction: correction,
      eventDate: eventDate,
      sequence: sequence,
    );
    return _sendEvent(event);
  }

  /// Envia pedido de prorrogação de retorno (`111500`/`111501`).
  Future<SefazResponse> sefazEPP({
    required String accessKey,
    required int cOrgao,
    required int environment,
    required String issuerCnpj,
    required String protocol,
    required List<ReturnExtensionItem> items,
    int term = 1,
    DateTime? eventDate,
    int sequence = 1,
  }) async {
    final event = NfeEventBuilder().prorrogacaoRetorno(
      accessKey: accessKey,
      cOrgao: cOrgao,
      environment: environment,
      issuerCnpj: issuerCnpj,
      protocol: protocol,
      items: items,
      term: term,
      eventDate: eventDate,
      sequence: sequence,
    );
    return _sendEvent(event);
  }

  /// Envia cancelamento de pedido de prorrogação (`111502`/`111503`).
  Future<SefazResponse> sefazECPP({
    required String accessKey,
    required int cOrgao,
    required int environment,
    required String issuerCnpj,
    required String protocol,
    int term = 1,
    DateTime? eventDate,
    int sequence = 1,
  }) async {
    final event = NfeEventBuilder().cancelamentoProrrogacao(
      accessKey: accessKey,
      cOrgao: cOrgao,
      environment: environment,
      issuerCnpj: issuerCnpj,
      protocol: protocol,
      term: term,
      eventDate: eventDate,
      sequence: sequence,
    );
    return _sendEvent(event);
  }

  /// Envia uma manifestação do destinatário (`210200`, `210210`, `210220`
  /// ou `210240`).
  Future<SefazResponse> sefazManifestacao({
    required String accessKey,
    required int cOrgao,
    required int environment,
    required String participantTaxId,
    required String eventType,
    String? justification,
    DateTime? eventDate,
    int sequence = 1,
  }) async {
    final event = NfeEventBuilder().manifestacao(
      accessKey: accessKey,
      cOrgao: cOrgao,
      environment: environment,
      participantTaxId: participantTaxId,
      eventType: eventType,
      justification: justification,
      eventDate: eventDate,
      sequence: sequence,
    );

    return _sendEvent(event);
  }

  /// Alias compatível com `Tools::sefazManifesta()`.
  Future<SefazResponse> sefazManifesta({
    required String accessKey,
    required int cOrgao,
    required int environment,
    required String participantTaxId,
    required String eventType,
    String? justification,
    DateTime? eventDate,
    int sequence = 1,
  }) => sefazManifestacao(
    accessKey: accessKey,
    cOrgao: cOrgao,
    environment: environment,
    participantTaxId: participantTaxId,
    eventType: eventType,
    justification: justification,
    eventDate: eventDate,
    sequence: sequence,
  );

  /// Envia um `envEvento` já montado, com assinatura opcional configurada na
  /// fachada. Mantém a extensão para eventos não encapsulados por métodos
  /// específicos, sem inventar códigos de evento.
  Future<SefazResponse> sefazEvento(String eventXml) => _sendEvent(eventXml);

  /// Combina e envia até 20 eventos `envEvento` em um único lote.
  ///
  /// Cada entrada deve conter exatamente um grupo `evento`. Quando [signer]
  /// foi configurado, cada evento é assinado antes da combinação.
  Future<SefazResponse> sefazEventoLote(List<String> eventXmls) async {
    if (eventXmls.isEmpty || eventXmls.length > 20) {
      throw const FiscalValidationException(
        'O lote de eventos deve conter entre 1 e 20 eventos.',
        code: 'INVALID_EVENT_BATCH_SIZE',
      );
    }
    final events = <XmlElement>[];
    for (final source in eventXmls) {
      if (source.trim().isEmpty) {
        throw const FiscalValidationException(
          'O XML de evento não pode ser vazio.',
          code: 'EMPTY_EVENT_XML',
        );
      }
      _parseEvent(source);
      final signedSource = signer == null
          ? source
          : await signer!.signEvent(source);
      final signedDocument = _parseEvent(signedSource);
      events.add(signedDocument.rootElement.getElement('evento')!.copy());
    }
    final batch = XmlElement(
      XmlName.parts('envEvento'),
      [
        XmlAttribute(
          XmlName.parts('xmlns'),
          'http://www.portalfiscal.inf.br/nfe',
        ),
        XmlAttribute(XmlName.parts('versao'), '1.00'),
      ],
      [
        _xmlText(
          'idLote',
          (DateTime.now().microsecondsSinceEpoch % 1000000000000000)
              .toString()
              .padLeft(15, '0'),
        ),
        ...events,
      ],
    );
    return _client.sefazEnviaEvento(
      XmlDocument([batch]).toXmlString(pretty: true, indent: '  '),
    );
  }

  /// Constrói e envia até 20 manifestações, equivalente a
  /// `Tools::sefazManifestaLote()`.
  Future<SefazResponse> sefazManifestaLote(
    List<ManifestationRequest> requests,
  ) {
    if (requests.isEmpty || requests.length > 20) {
      throw const FiscalValidationException(
        'O lote de manifestações deve conter entre 1 e 20 eventos.',
        code: 'INVALID_MANIFESTATION_BATCH_SIZE',
      );
    }
    final builder = NfeEventBuilder();
    final events = requests
        .map(
          (request) => builder.manifestacao(
            accessKey: request.accessKey,
            cOrgao: request.cOrgao,
            environment: request.environment,
            participantTaxId: request.participantTaxId,
            eventType: request.eventType,
            justification: request.justification,
            eventDate: request.eventDate,
            sequence: request.sequence,
          ),
        )
        .toList(growable: false);
    return sefazEventoLote(events);
  }

  /// Valida estruturalmente uma NF-e e consulta sua situação pela chave.
  ///
  /// A resposta permanece explícita para que o consumidor trate rejeição,
  /// autorização ou estado desconhecido; não é convertida silenciosamente em
  /// um booleano.
  Future<SefazResponse> sefazValidate(String nfeXml) {
    final verifier = signatureVerifier;
    if (verifier == null) {
      throw const FiscalValidationException(
        'Configure um verificador criptográfico antes de validar uma NF-e assinada.',
        code: 'SIGNATURE_VERIFIER_REQUIRED',
      );
    }
    NfeXmlValidator().assertValid(
      nfeXml,
      requireSignature: true,
      signatureVerifier: verifier,
    );
    try {
      final document = XmlDocument.parse(nfeXml);
      final inf = document.rootElement.getElement('infNFe');
      final id = inf?.getAttribute('Id');
      final environment = inf
          ?.getElement('ide')
          ?.getElement('tpAmb')
          ?.innerText;
      if (id == null || !id.startsWith('NFe') || environment == null) {
        throw const FiscalValidationException(
          'A NF-e não contém chave ou ambiente válidos.',
          code: 'INVALID_NFE_VALIDATION_CONTEXT',
        );
      }
      return _client.sefazConsultaChave(
        id.substring(3),
        environment: int.parse(environment),
      );
    } on XmlException catch (error) {
      throw FiscalValidationException(
        'A NF-e é inválida.',
        code: 'INVALID_NFE_XML',
        cause: error,
      );
    }
  }

  /// Envia um comprovante de entrega (`tpEvento=110130`).
  Future<SefazResponse> sefazComprovanteEntrega({
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
    bool cancel = false,
    String? protocol,
  }) async {
    final event = NfeEventBuilder().comprovanteEntrega(
      accessKey: accessKey,
      cOrgao: cOrgao,
      environment: environment,
      issuerCnpj: issuerCnpj,
      applicationVersion: applicationVersion,
      deliveryDate: deliveryDate,
      documentNumber: documentNumber,
      recipientName: recipientName,
      hashComprovante: hashComprovante,
      latitude: latitude,
      longitude: longitude,
      hashDate: hashDate,
      eventDate: eventDate,
      cancel: cancel,
      protocol: protocol,
    );
    return _sendEvent(event);
  }

  /// Envia o evento de insucesso na entrega (`110192`) ou o cancelamento
  /// correspondente (`110193`).
  Future<SefazResponse> sefazInsucessoEntrega({
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
  }) async {
    final event = NfeEventBuilder().insucessoEntrega(
      accessKey: accessKey,
      cOrgao: cOrgao,
      environment: environment,
      issuerCnpj: issuerCnpj,
      attemptDate: attemptDate,
      reasonType: reasonType,
      attemptHash: attemptHash,
      attempts: attempts,
      justification: justification,
      latitude: latitude,
      longitude: longitude,
      protocol: protocol,
      cancel: cancel,
      hashDate: hashDate,
      eventDate: eventDate,
      sequence: sequence,
    );
    return _sendEvent(event);
  }

  /// Envia o evento de conciliação financeira (`110750`) ou cancelamento
  /// (`110751`).
  Future<SefazResponse> sefazConciliacao({
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
  }) async {
    final event = NfeEventBuilder().conciliacaoFinanceira(
      accessKey: accessKey,
      cOrgao: cOrgao,
      environment: environment,
      issuerCnpj: issuerCnpj,
      applicationVersion: applicationVersion,
      payments: payments,
      cancel: cancel,
      protocol: protocol,
      eventDate: eventDate,
      sequence: sequence,
    );
    return _sendEvent(event);
  }

  /// Envia o evento de ator interessado na NF-e (`tpEvento=110150`).
  Future<SefazResponse> sefazAtorInteressado({
    required String accessKey,
    required int cOrgao,
    required int environment,
    required String authorTaxId,
    required int authorStateCode,
    required String authorType,
    required String applicationVersion,
    required String authorizedTaxId,
    String? authorizationType,
    DateTime? eventDate,
  }) async {
    final event = NfeEventBuilder().atorInteressado(
      accessKey: accessKey,
      cOrgao: cOrgao,
      environment: environment,
      authorTaxId: authorTaxId,
      authorStateCode: authorStateCode,
      authorType: authorType,
      applicationVersion: applicationVersion,
      authorizedTaxId: authorizedTaxId,
      authorizationType: authorizationType,
      occurredAt: eventDate,
    );
    return _sendEvent(event);
  }

  /// Envia um evento EPEC (`tpEvento=110140`).
  Future<SefazResponse> sefazEpec({
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
  }) async {
    final event = NfeEventBuilder().epec(
      accessKey: accessKey,
      cOrgao: cOrgao,
      environment: environment,
      authorTaxId: authorTaxId,
      issuerIe: issuerIe,
      applicationVersion: applicationVersion,
      issueDate: issueDate,
      total: total,
      icms: icms,
      destinationUf: destinationUf,
      destinationTaxId: destinationTaxId,
      eventDate: eventDate,
    );
    return _sendEvent(event);
  }

  /// Alias com a capitalização original de `Tools::sefazEPEC()`.
  Future<SefazResponse> sefazEPEC({
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
  }) => sefazEpec(
    accessKey: accessKey,
    cOrgao: cOrgao,
    environment: environment,
    authorTaxId: authorTaxId,
    issuerIe: issuerIe,
    applicationVersion: applicationVersion,
    issueDate: issueDate,
    total: total,
    icms: icms,
    destinationUf: destinationUf,
    destinationTaxId: destinationTaxId,
    eventDate: eventDate,
  );

  Future<SefazResponse> _sendEvent(String event) async {
    final signed = signer == null ? event : await signer!.signEvent(event);
    return _client.sefazEnviaEvento(signed);
  }

  XmlElement _xmlText(String name, String? value) =>
      XmlElement(XmlName.parts(name), const [], [XmlText(value ?? '')]);

  XmlDocument _parseEvent(String source) {
    try {
      final document = XmlDocument.parse(source);
      if (document.rootElement.localName != 'envEvento' ||
          document.rootElement.findElements('evento').length != 1) {
        throw const FiscalValidationException(
          'O XML de evento deve possuir raiz envEvento e um evento.',
          code: 'INVALID_EVENT_DOCUMENT',
        );
      }
      return document;
    } on XmlException catch (error) {
      throw FiscalValidationException(
        'O XML de evento é inválido.',
        code: 'INVALID_EVENT_XML',
        cause: error,
      );
    }
  }
}
