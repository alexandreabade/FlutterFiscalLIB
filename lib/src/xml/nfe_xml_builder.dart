import 'package:xml/xml.dart';

import '../exceptions/fiscal_exception.dart';
import '../common/fiscal_decimal.dart';
import '../models/access_key.dart';
import '../models/additional_info.dart';
import '../models/contingency.dart';
import '../models/nfe_document.dart';
import '../models/nfe_item.dart';
import '../models/payment.dart';
import '../models/party.dart';
import '../models/taxes.dart';
import '../models/nfe_complements.dart';
import '../models/nfce_supplement.dart';
import '../models/reform_taxes.dart';
import '../models/trade.dart';
import '../models/product_details.dart';
import '../models/transport.dart';
import '../tools.dart';
import '../validation/gtin.dart';

/// Gera o XML base de uma NF-e/NFC-e sem assinatura digital.
class NfeXmlBuilder {
  /// Cria um construtor XML sem estado.
  const NfeXmlBuilder();

  /// Equivalente tipado a `Make::taginfNFe()` do NFePHP.
  ///
  /// Diferentemente da API PHP baseada em `stdClass`, recebe um
  /// [NfeDocument] imutável e devolve o elemento XML já montado.
  XmlElement taginfNFe(NfeDocument document) => _infNfeHeader(document);

  /// Equivalente tipado a `Make::tagide()`.
  XmlElement tagide(NfeDocument document) => _ide(document);

  /// Monta um detalhe completo (`det`) com produto e impostos.
  XmlElement tagdet(NfeItem item) => _detail(item);

  /// Monta referência de NF-e por chave (`tagrefNFe`).
  XmlElement tagrefNFe(ReferencedDocument reference) => _reference(reference);

  /// Monta referência de NF-e com chave sigilosa (`tagrefNFeSig`).
  XmlElement tagrefNFeSig(ReferencedDocument reference) =>
      _reference(reference);

  /// Monta referência de CT-e (`tagrefCTe`).
  XmlElement tagrefCTe(ReferencedDocument reference) => _reference(reference);

  /// Monta referência resumida de documento modelo 1/1A (`tagrefNF`).
  XmlElement tagrefNF(ReferencedDocument reference) => _reference(reference);

  /// Monta referência de nota de produtor rural (`tagrefNFP`).
  XmlElement tagrefNFP(ReferencedDocument reference) => _reference(reference);

  /// Monta referência de cupom fiscal emitido por ECF (`tagrefECF`).
  XmlElement tagrefECF(ReferencedDocument reference) => _reference(reference);

  /// Equivalente tipado a `Make::tagemit()`.
  XmlElement tagemit(Party issuer) => _party('emit', issuer);

  /// Monta emissão avulsa compatível com `tagavulsa()`.
  XmlElement tagavulsa(AvulsaInfo avulsa) => _avulsa(avulsa);

  /// Equivalente tipado a `Make::tagdest()`.
  XmlElement tagdest(Party recipient) => _party('dest', recipient);

  /// Monta o local de retirada compatível com `tagretirada()`.
  XmlElement tagretirada(NfeLocation location) =>
      _location('retirada', location);

  /// Monta o local de entrega compatível com `tagentrega()`.
  XmlElement tagentrega(NfeLocation location) => _location('entrega', location);

  /// Equivalente tipado a `Make::tagRastro()`.
  XmlElement tagRastro(ProductTraceability batch) => _traceability(batch);

  /// Equivalente tipado a `Make::tagveicProd()`.
  XmlElement tagveicProd(NewVehicleInfo vehicle) => _newVehicle(vehicle);

  /// Equivalente tipado a `Make::tagmed()`.
  XmlElement tagmed(MedicationInfo medication) => _medication(medication);

  /// Equivalente tipado a `Make::tagarma()`.
  XmlElement tagarma(WeaponInfo weapon) => _weapon(weapon);

  /// Equivalente tipado a `Make::tagcomb()`.
  XmlElement tagcomb(FuelInfo fuel) => _fuel(fuel);

  /// Monta o encerrante de combustível (`tagencerrante`).
  XmlElement tagencerrante(FuelGauge gauge) =>
      XmlElement(XmlName.parts('encerrante'), const [], [
        _text('nBico', '${gauge.nozzle}'),
        if (gauge.pump != null) _text('nBomba', '${gauge.pump}'),
        _text('nTanque', '${gauge.tank}'),
        _text(
          'vEncIni',
          FiscalDecimal.fromNum(gauge.initialReading).toFixed(3),
        ),
        _text('vEncFin', FiscalDecimal.fromNum(gauge.finalReading).toFixed(3)),
      ]);

  /// Monta uma referência de pagamento antecipado (`taggPagAntecipado`).
  XmlElement taggPagAntecipado(String reference) => XmlElement(
    XmlName.parts('gPagAntecipado'),
    const [],
    [_text('refNFe', reference)],
  );

  /// Monta compra governamental compatível com `taggCompraGov()`.
  XmlElement taggCompraGov(GovernmentPurchase purchase) =>
      _governmentPurchase(purchase);

  /// Monta referência de documento anterior compatível com `tagrefDFeAnt()`.
  XmlElement tagrefDFeAnt(String reference) => _text('refDFeAnt', reference);

  /// Equivalente tipado a `Make::tagenderEmit()`.
  XmlElement tagenderEmit(Party issuer) => _address('enderEmit', issuer);

  /// Equivalente tipado a `Make::tagenderDest()`.
  XmlElement tagenderDest(Party recipient) => _address('enderDest', recipient);

  /// Equivalente tipado a `Make::tagNVE()`.
  XmlElement tagNVE(String value) => _text('NVE', value);

  /// Equivalente tipado a `Make::tagCEST()`.
  XmlElement tagCEST(String value) => _text('CEST', value);

  /// Equivalente tipado a `Make::taginfAdProd()`.
  XmlElement taginfAdProd(String value) => _text('infAdProd', value);

  /// Equivalente tipado a `Make::tagnFCI()`.
  XmlElement tagnFCI(String value) => _text('nFCI', value);

  /// Monta o registro RECOPI de um item (`tagRECOPI`).
  XmlElement tagRECOPI(NfeItem item) {
    final value = item.recopiNumber;
    if (value == null || value.trim().isEmpty) {
      throw const FiscalValidationException(
        'O item não possui número RECOPI.',
        code: 'MISSING_RECOPI_NUMBER',
      );
    }
    if (!RegExp(r'^\d{20}$').hasMatch(value)) {
      throw const FiscalValidationException(
        'O número RECOPI deve possuir exatamente 20 dígitos.',
        code: 'INVALID_RECOPI_NUMBER',
      );
    }
    return _text('nRECOPI', value);
  }

  /// Equivalente tipado a `Make::tagDI()`.
  XmlElement tagDI(ImportDeclaration declaration) =>
      _importDeclaration(declaration);

  /// Equivalente tipado a `Make::tagadi()`.
  XmlElement tagadi(ImportAddition addition) => _importAddition(addition);

  /// Equivalente tipado a `Make::tagdetExport()`.
  XmlElement tagdetExport(ExportDetail detail) => _exportDetail(detail);

  /// Equivalente tipado a `Make::tagdetExportInd()`.
  XmlElement tagdetExportInd(IndividualExport export) =>
      XmlElement(XmlName.parts('exportInd'), const [], [
        _text('nRE', export.registrationNumber),
        _text('chNFe', export.receivedInvoiceKey),
        _text(
          'qExport',
          FiscalDecimal.fromNum(export.exportedQuantity).toFixed(4),
        ),
      ]);

  /// Equivalente tipado a `Make::tagprod()`.
  XmlElement tagprod(NfeItem item) => _detail(item).getElement('prod')!;

  /// Equivalente tipado a `Make::tagimposto()`.
  XmlElement tagimposto(NfeItem item) => _taxes(item);

  /// Equivalente tipado a `Make::tagICMS()`.
  XmlElement tagICMS(IcmsTax tax) => _icms(tax);

  /// Monta ICMS com substituição tributária (`ICMS10`).
  XmlElement tagICMSST(IcmsStTax tax) => _icmsSt(tax);

  /// Monta partilha do ICMS compatível com `tagICMSPart()`.
  XmlElement tagICMSPart(IcmsPartTax tax) => _icmsPart(tax);

  /// Monta partilha para consumidor final compatível com `tagICMSUFDest()`.
  XmlElement tagICMSUFDest(IcmsUfDestinationTax tax) => _icmsUfDestination(tax);

  /// Equivalente tipado a `Make::tagICMSSN()`.
  XmlElement tagICMSSN(IcmsSimplesTax tax) => _icmsSimples(tax);

  /// Monta ICMS monofásico tipado.
  XmlElement tagICMSMono(IcmsMonophaseTax tax) => _icmsMonophase(tax);

  /// Equivalente tipado a `Make::tagIPI()`.
  XmlElement tagIPI(IpiTax tax) => _ipi(tax);

  /// Equivalente tipado a `Make::tagII()`.
  XmlElement tagII(ImportTax tax) => _importTax(tax);

  /// Equivalente tipado a `Make::tagPIS()`.
  XmlElement tagPIS(PisTax tax) => _pis(tax);

  /// Equivalente tipado a `Make::tagPISST()`.
  XmlElement tagPISST(PisStTax tax) => _pisSt(tax);

  /// Equivalente tipado a `Make::tagCOFINS()`.
  XmlElement tagCOFINS(CofinsTax tax) => _cofins(tax);

  /// Equivalente tipado a `Make::tagCOFINSST()`.
  XmlElement tagCOFINSST(CofinsStTax tax) => _cofinsSt(tax);

  /// Equivalente tipado a `Make::tagISSQN()`.
  XmlElement tagISSQN(ServiceTax tax) => _serviceTax(tax);

  /// Monta IPI devolvido compatível com `tagimpostoDevol()`.
  XmlElement tagimpostoDevol(IpiDevolution devolution) =>
      _impostoDevol(devolution);

  /// Monta retenções federais compatíveis com `tagretTrib()`.
  XmlElement tagretTrib(TaxRetention retention) => _retTrib(retention);

  /// Monta o grupo de totalizadores `total`.
  XmlElement tagtotal(NfeDocument document) => _total(document);

  /// Monta diretamente os totalizadores de ICMS (`tagICMSTot`).
  XmlElement tagICMSTot(NfeDocument document) =>
      _total(document).findElements('ICMSTot').single;

  /// Monta diretamente os totalizadores de ISSQN (`tagISSQNTot`).
  XmlElement tagISSQNTot(NfeDocument document) {
    if (!_hasServiceTax(document) && document.serviceTotal == null) {
      throw const FiscalValidationException(
        'O documento não possui itens de serviço para gerar ISSQNtot.',
        code: 'MISSING_SERVICE_TOTAL',
      );
    }
    return _serviceTotal(document);
  }

  /// Monta o grupo de pagamentos `pag`.
  XmlElement tagpag(NfeDocument document) => _payments(document);

  /// Monta um detalhe de pagamento (`tagdetPag`).
  XmlElement tagdetPag(Payment payment) => _payment(payment);

  /// Monta o grupo de transporte `transp`.
  XmlElement tagtransp(NfeDocument document) => _transport(document);

  /// Monta o transportador (`transporta`).
  XmlElement tagtransporta(TransportInfo transport) => _transporta(transport);

  /// Monta a retenção do transporte (`retTransp`).
  XmlElement tagretTransp(TransportTaxRetention retention) =>
      _retTransp(retention);

  /// Monta um lacre (`lacres`).
  XmlElement taglacres(String seal) =>
      XmlElement(XmlName.parts('lacres'), const [], [_text('nLacre', seal)]);

  /// Monta um veículo de transporte (`veicTransp`).
  XmlElement tagveicTransp(TransportVehicle vehicle) =>
      _transportVehicle('veicTransp', vehicle);

  /// Monta um reboque (`reboque`).
  XmlElement tagreboque(TransportVehicle vehicle) =>
      _transportVehicle('reboque', vehicle);

  /// Monta um volume (`vol`).
  XmlElement tagvol(TransportVolume volume) => _transportVolume(volume);

  /// Monta a identificação de vagão (`vagao`).
  XmlElement tagvagao(String identifier) => _text('vagao', identifier);

  /// Monta a identificação de balsa (`balsa`).
  XmlElement tagbalsa(String identifier) => _text('balsa', identifier);

  /// Monta o grupo de cobrança `cobr`.
  XmlElement tagcobr(BillingInfo billing) => _billing(billing);

  /// Monta a fatura (`tagfat`).
  XmlElement tagfat(BillingInfo billing) => _invoice(billing);

  /// Monta uma duplicata (`tagdup`).
  XmlElement tagdup(InvoiceInstallment installment) => _duplicate(installment);

  /// Monta o grupo de informações adicionais `infAdic`.
  XmlElement taginfAdic(NfeDocument document) => _additionalInfo(document);

  /// Monta observação do contribuinte compatível com `tagobsCont()`.
  XmlElement tagobsCont(AdditionalObservation observation) =>
      _observation('obsCont', observation);

  /// Monta observação fiscal compatível com `tagobsFisco()`.
  XmlElement tagobsFisco(AdditionalObservation observation) =>
      _observation('obsFisco', observation);

  /// Monta processo referenciado compatível com `tagprocRef()`.
  XmlElement tagprocRef(ReferencedProcess process) => XmlElement(
    XmlName.parts('procRef'),
    const [],
    [_text('nProc', process.number), _text('indProc', process.indicator)],
  );

  /// Monta autorização de download compatível com `tagautXML()`.
  XmlElement tagautXML(AuthorizedXmlDownload authorization) =>
      _authorizedXml(authorization);

  /// Monta o grupo de responsável técnico `infRespTec`.
  XmlElement taginfRespTec(TechnicalResponsible responsible) =>
      _technicalResponsible(responsible);

  /// Monta informações do intermediador compatíveis com `taginfIntermed()`.
  XmlElement taginfIntermed(IntermediaryInfo intermediary) =>
      _intermediary(intermediary);

  /// Monta o grupo de exportação `exporta`.
  XmlElement tagexporta(ExportInfo info) => _exportInfo(info);

  /// Monta o grupo de compra `compra`.
  XmlElement tagcompra(PurchaseInfo info) => _purchaseInfo(info);

  /// Monta o grupo de aquisição de cana `cana`.
  XmlElement tagcana(SugarcaneInfo info) => _sugarcane(info);

  /// Monta um fornecimento diário de cana (`forDia`).
  XmlElement tagforDia(SugarcaneDailySupply supply) => XmlElement(
    XmlName.parts('forDia'),
    [XmlAttribute(XmlName.parts('dia'), '${supply.day}')],
    [_text('qtde', FiscalDecimal.fromNum(supply.quantity).toFixed(10))],
  );

  /// Monta uma dedução de aquisição de cana (`deduc`).
  XmlElement tagdeduc(SugarcaneDeduction deduction) =>
      XmlElement(XmlName.parts('deduc'), const [], [
        _text('xDed', deduction.description),
        _text('vDed', FiscalDecimal.fromNum(deduction.value).toFixed(2)),
      ]);

  /// Monta o suplemento NFC-e (`infNFeSupl`).
  XmlElement taginfNFeSupl(NfceXmlSupplement supplement) =>
      _nfceSupplement(supplement);

  /// Constrói o XML autorizado estruturalmente a partir do documento.
  String build(NfeDocument document) {
    _validate(document);
    final root = XmlElement(
      XmlName.parts('NFe'),
      [
        XmlAttribute(
          XmlName.parts('xmlns'),
          'http://www.portalfiscal.inf.br/nfe',
        ),
      ],
      [
        _infNfe(document),
        if (document.nfceSupplement != null)
          _nfceSupplement(document.nfceSupplement!),
      ],
    );
    return XmlDocument([root]).toXmlString(pretty: true, indent: '  ');
  }

  /// Constrói o XML exigindo os campos mínimos do layout fiscal `ide` e do
  /// emitente antes da montagem.
  ///
  /// [build] continua disponível para composição incremental e compatibilidade
  /// com a fachada `Make`. Use este método no fluxo que pretende transmitir o
  /// documento, e combine-o com [XsdValidator] quando um parser XSD estiver
  /// disponível no ambiente.
  String buildStrict(NfeDocument document) {
    _validateStrictFiscalFields(document);
    return build(document);
  }

  XmlElement _infNfe(
    NfeDocument document,
  ) => XmlElement(XmlName.parts('infNFe'), _infNfeAttributes(document), [
    _ide(document),
    _party('emit', document.issuer),
    if (document.avulsa != null) _avulsa(document.avulsa!),
    if (document.recipient != null) _party('dest', document.recipient!),
    if (document.withdrawal != null)
      _location('retirada', document.withdrawal!),
    if (document.delivery != null) _location('entrega', document.delivery!),
    if (document.additionalInfo != null)
      for (final authorization in document.additionalInfo!.authorizedXml)
        _authorizedXml(authorization),
    for (final item in document.items) _detail(item),
    _total(document),
    _transport(document),
    if (document.billing != null) _billing(document.billing!),
    if (document.payments.isNotEmpty) _payments(document),
    if (document.intermediary != null) _intermediary(document.intermediary!),
    if (document.additionalInfo?.hasInfAdicContent ?? false)
      _additionalInfo(document),
    if (document.exportInfo != null) _exportInfo(document.exportInfo!),
    if (document.purchaseInfo != null) _purchaseInfo(document.purchaseInfo!),
    if (document.sugarcane != null) _sugarcane(document.sugarcane!),
    if (document.technicalResponsible != null)
      _technicalResponsible(document.technicalResponsible!),
  ]);

  XmlElement _infNfeHeader(NfeDocument document) =>
      XmlElement(XmlName.parts('infNFe'), _infNfeAttributes(document));

  List<XmlAttribute> _infNfeAttributes(NfeDocument document) => [
    XmlAttribute(XmlName.parts('Id'), 'NFe${document.accessKey}'),
    XmlAttribute(XmlName.parts('versao'), '4.00'),
  ];

  XmlElement _ide(NfeDocument d) => XmlElement(XmlName.parts('ide'), const [], [
    _text('cUF', d.accessKey.substring(0, 2)),
    _text('cNF', d.accessKey.substring(35, 43)),
    if (d.operationNature != null) _text('natOp', d.operationNature),
    _text('mod', '${d.model}'),
    _text('serie', '${d.series}'),
    _text('nNF', '${d.number}'),
    _text('dhEmi', _dateTime(d.issueDate)),
    if (d.departureDate != null) _text('dhSaiEnt', _dateTime(d.departureDate!)),
    if (d.deliveryForecast != null)
      _text('dPrevEntrega', _date(d.deliveryForecast!)),
    if (d.documentType != null) _text('tpNF', '${d.documentType}'),
    if (d.destinationType != null) _text('idDest', '${d.destinationType}'),
    if (d.documentType != null &&
        d.destinationType != null &&
        (d.municipalityCode != null || d.issuer.cityCode != null))
      _text('cMunFG', d.municipalityCode ?? d.issuer.cityCode),
    if (d.ibsMunicipalityCode != null)
      _text('cMunFGIBS', d.ibsMunicipalityCode),
    if (d.printFormat != null) _text('tpImp', '${d.printFormat}'),
    _text('tpEmis', '${d.contingency?.mode.code ?? 1}'),
    _text('cDV', d.accessKey.substring(43)),
    _text('tpAmb', '${d.environment}'),
    if (d.purpose != null) _text('finNFe', '${d.purpose}'),
    if (d.debitNoteType != null) _text('tpNFDebito', d.debitNoteType),
    if (d.creditNoteType != null) _text('tpNFCredito', d.creditNoteType),
    if (d.finalConsumer != null) _text('indFinal', '${d.finalConsumer}'),
    if (d.presenceIndicator != null) _text('indPres', '${d.presenceIndicator}'),
    if (d.intermediaryIndicator != null)
      _text('indIntermed', '${d.intermediaryIndicator}'),
    if (d.operationLocationCode != null)
      _text('cIndOp', d.operationLocationCode),
    if (d.processCode != null) _text('procEmi', d.processCode),
    if (d.applicationVersion != null) _text('verProc', d.applicationVersion),
    if (d.contingency != null) ...[
      _text('dhCont', _dateTime(d.contingency!.activatedAt)),
      _text('xJust', d.contingency!.reason),
    ],
    for (final reference in d.references) _reference(reference),
    if (d.governmentPurchase != null)
      _governmentPurchase(d.governmentPurchase!),
    if (d.advancePaymentReferences.isNotEmpty)
      XmlElement(XmlName.parts('gPagAntecipado'), const [], [
        for (final reference in d.advancePaymentReferences)
          _text('refNFe', reference),
      ]),
  ]);

  XmlElement _nfceSupplement(NfceXmlSupplement supplement) => XmlElement(
    XmlName.parts('infNFeSupl'),
    const [],
    [_text('qrCode', supplement.qrCode), _text('urlChave', supplement.keyUrl)],
  );

  XmlElement _reference(ReferencedDocument reference) {
    if (reference.ecfModel != null) {
      return XmlElement(XmlName.parts('NFref'), const [], [
        XmlElement(XmlName.parts('refECF'), const [], [
          _text('mod', reference.ecfModel),
          _text('nECF', '${reference.ecfNumber}'.padLeft(3, '0')),
          _text('nCOO', '${reference.cooNumber}'.padLeft(6, '0')),
        ]),
      ]);
    }
    if (reference.producerIe != null) {
      return XmlElement(XmlName.parts('NFref'), const [], [
        XmlElement(XmlName.parts('refNFP'), const [], [
          _text('cUF', reference.cUf),
          _text('AAMM', reference.yearMonth),
          if (reference.cnpj != null)
            _text('CNPJ', Tools.onlyDigits(reference.cnpj!)),
          if (reference.cpf != null)
            _text('CPF', Tools.onlyDigits(reference.cpf!)),
          _text('IE', reference.producerIe),
          _text('mod', reference.model.toString().padLeft(2, '0')),
          _text('serie', '${reference.series}'),
          _text('nNF', '${reference.number}'),
        ]),
      ]);
    }
    if (reference.accessKey != null) {
      return XmlElement(XmlName.parts('NFref'), const [], [
        _text('refNFe', reference.accessKey),
      ]);
    }
    if (reference.signedNfeKey != null) {
      return XmlElement(XmlName.parts('NFref'), const [], [
        _text('refNFeSig', reference.signedNfeKey),
      ]);
    }
    if (reference.cteKey != null) {
      return XmlElement(XmlName.parts('NFref'), const [], [
        _text('refCTe', reference.cteKey),
      ]);
    }
    return XmlElement(XmlName.parts('NFref'), const [], [
      XmlElement(XmlName.parts('refNF'), const [], [
        _text('cUF', reference.cUf),
        _text('AAMM', reference.yearMonth),
        _text('CNPJ', reference.cnpj),
        _text('mod', '${reference.model}'),
        _text('serie', '${reference.series}'),
        _text('nNF', '${reference.number}'),
      ]),
    ]);
  }

  XmlElement _party(String tag, dynamic party) =>
      XmlElement(XmlName.parts(tag), const [], [
        if (party.cnpj != null)
          _text('CNPJ', Tools.onlyDigits(party.cnpj!))
        else if (party.cpf != null)
          _text('CPF', Tools.onlyDigits(party.cpf!))
        else if (party.foreignId != null)
          _text('idEstrangeiro', party.foreignId),
        _text('xNome', party.name),
        if (tag == 'emit' && party.fantasyName != null)
          _text('xFant', party.fantasyName),
        _address(tag == 'emit' ? 'enderEmit' : 'enderDest', party),
        if (tag == 'dest' && party.recipientIeIndicator != null)
          _text('indIEDest', '${party.recipientIeIndicator}'),
        if (party.ie != null) _text('IE', party.ie),
        if (tag == 'emit' && party.ieSubstitute != null)
          _text('IEST', party.ieSubstitute),
        if (party.municipalRegistration != null)
          _text('IM', party.municipalRegistration),
        if (tag == 'emit' && party.cnae != null) _text('CNAE', party.cnae),
        if (party.crt != null) _text('CRT', party.crt),
        if (party.suframa != null)
          _text(tag == 'emit' ? 'ISUFEmit' : 'ISUF', party.suframa),
        if (tag == 'dest' && party.email != null) _text('email', party.email),
      ]);

  XmlElement _avulsa(
    AvulsaInfo avulsa,
  ) => XmlElement(XmlName.parts('avulsa'), const [], [
    _text('CNPJ', Tools.onlyDigits(avulsa.cnpj)),
    _text('xOrgao', avulsa.agency),
    _text('matr', avulsa.registration),
    _text('xAgente', avulsa.agent),
    if (avulsa.phone != null) _text('fone', Tools.onlyDigits(avulsa.phone!)),
    _text('UF', avulsa.state),
    if (avulsa.revenueDocumentNumber != null)
      _text('nDAR', avulsa.revenueDocumentNumber),
    if (avulsa.documentIssueDate != null)
      _text('dEmi', _date(avulsa.documentIssueDate!)),
    if (avulsa.revenueDocumentValue != null)
      _text(
        'vDAR',
        FiscalDecimal.fromNum(avulsa.revenueDocumentValue!).toFixed(2),
      ),
    _text('repEmi', avulsa.fiscalOffice),
    if (avulsa.paymentDate != null) _text('dPag', _date(avulsa.paymentDate!)),
  ]);

  XmlElement _location(String tag, NfeLocation location) =>
      XmlElement(XmlName.parts(tag), const [], [
        if (location.cnpj != null)
          _text('CNPJ', Tools.onlyDigits(location.cnpj!)),
        if (location.cpf != null) _text('CPF', Tools.onlyDigits(location.cpf!)),
        if (location.name != null) _text('xNome', location.name),
        _text('xLgr', location.street),
        _text('nro', location.number),
        if (location.complement != null) _text('xCpl', location.complement),
        _text('xBairro', location.neighborhood),
        _text('cMun', location.municipalityCode),
        _text('xMun', location.municipality),
        _text('UF', location.state),
        if (location.zipCode != null) _text('CEP', location.zipCode),
        if (location.countryCode != null) _text('cPais', location.countryCode),
        if (location.country != null) _text('xPais', location.country),
        if (location.phone != null)
          _text('fone', Tools.onlyDigits(location.phone!)),
        if (location.email != null) _text('email', location.email),
        if (location.ie != null) _text('IE', location.ie),
      ]);

  XmlElement _address(String tag, dynamic party) =>
      XmlElement(XmlName.parts(tag), const [], [
        if (party.address != null) _text('xLgr', party.address),
        if (party.addressNumber != null) _text('nro', party.addressNumber),
        if (party.addressComplement != null)
          _text('xCpl', party.addressComplement),
        if (party.neighborhood != null) _text('xBairro', party.neighborhood),
        if (party.cityCode != null) _text('cMun', party.cityCode),
        if (party.city != null) _text('xMun', party.city),
        if (party.state != null) _text('UF', party.state),
        if (party.zipCode != null) _text('CEP', party.zipCode),
        if (party.phone != null) _text('fone', Tools.onlyDigits(party.phone!)),
      ]);

  XmlElement _detail(NfeItem item) => XmlElement(
    XmlName.parts('det'),
    [XmlAttribute(XmlName.parts('nItem'), '${item.number}')],
    [
      XmlElement(XmlName.parts('prod'), const [], [
        _text('cProd', item.code),
        _text('cEAN', item.ean ?? 'SEM GTIN'),
        if (item.barcode != null) _text('cBarra', item.barcode),
        _text('xProd', item.description),
        _text('NCM', item.ncm),
        for (final nve in item.nve) _text('NVE', nve),
        if (item.cest != null) _text('CEST', item.cest),
        if (item.scaleIndicator != null)
          _text('indEscala', item.scaleIndicator),
        if (item.manufacturerCnpj != null)
          _text('CNPJFab', Tools.onlyDigits(item.manufacturerCnpj!)),
        if (item.benefitCode != null) _text('cBenef', item.benefitCode),
        for (final credit in item.presumedCredits) _presumedCredit(credit),
        if (item.zfmCreditType != null)
          _text('tpCredPresIBSZFM', item.zfmCreditType),
        if (item.extipi != null) _text('EXTIPI', item.extipi),
        _text('CFOP', item.cfop),
        _text('uCom', item.unit),
        _text('qCom', FiscalDecimal.fromNum(item.quantity).toFixed(4)),
        _text('vUnCom', FiscalDecimal.fromNum(item.unitPrice).toFixed(10)),
        _text('vProd', item.merchandiseTotalFormatted),
        _text('cEANTrib', item.eanTrib ?? item.ean ?? 'SEM GTIN'),
        if (item.taxableBarcode != null)
          _text('cBarraTrib', item.taxableBarcode),
        _text('uTrib', item.tribUnit ?? item.unit),
        _text(
          'qTrib',
          FiscalDecimal.fromNum(item.tribQuantity ?? item.quantity).toFixed(4),
        ),
        _text(
          'vUnTrib',
          FiscalDecimal.fromNum(
            item.tribUnitPrice ?? item.unitPrice,
          ).toFixed(10),
        ),
        _text('indTot', item.includeInTotal ? '1' : '0'),
        if (item.usedMovableAsset) _text('indBemMovelUsado', '1'),
        for (final declaration in item.importDeclarations)
          _importDeclaration(declaration),
        for (final detail in item.exportDetails) _exportDetail(detail),
        if (item.orderNumber != null) _text('xPed', item.orderNumber),
        if (item.orderItem != null) _text('nItemPed', '${item.orderItem}'),
        if (item.fciNumber != null) _text('nFCI', item.fciNumber),
        for (final batch in item.traceability) _traceability(batch),
        if (item.nffProduct != null)
          XmlElement(XmlName.parts('infProdNFF'), const [], [
            _text('cProdFisco', item.nffProduct!.fiscalProductCode),
            _text('cOperNFF', item.nffProduct!.operationCode),
          ]),
        if (item.embeddedProduct != null)
          XmlElement(XmlName.parts('infProdEmb'), const [], [
            _text('xEmb', item.embeddedProduct!.description),
            _text(
              'qVolEmb',
              FiscalDecimal.fromNum(item.embeddedProduct!.quantity).toFixed(3),
            ),
            _text('uEmb', item.embeddedProduct!.unit),
          ]),
        if (item.newVehicle != null) _newVehicle(item.newVehicle!),
        for (final weapon in item.weapons) _weapon(weapon),
        if (item.medication != null) _medication(item.medication!),
        if (item.fuel != null) _fuel(item.fuel!),
        if (item.recopiNumber != null) _text('nRECOPI', item.recopiNumber),
      ]),
      if (item.additionalInformation != null)
        _text('infAdProd', item.additionalInformation),
      if (item.icms != null ||
          item.approximateTaxValue != null ||
          item.icmsSt != null ||
          item.icmsStRetained != null ||
          item.icmsPart != null ||
          item.icmsUfDestination != null ||
          item.icmsSimples != null ||
          item.icmsMonophase != null ||
          item.ipi != null ||
          item.importTax != null ||
          item.pis != null ||
          item.pisSt != null ||
          item.cofins != null ||
          item.cofinsSt != null ||
          item.serviceTax != null ||
          item.ibsCbs != null ||
          item.ibsCbsMonophase != null ||
          item.selectiveTax != null)
        _taxes(item),
      if (item.ipiDevolution != null) _impostoDevol(item.ipiDevolution!),
    ],
  );

  XmlElement _importDeclaration(ImportDeclaration declaration) =>
      XmlElement(XmlName.parts('DI'), const [], [
        _text('nDI', declaration.number),
        _text('dDI', _date(declaration.registrationDate)),
        _text('xLocDesemb', declaration.customsLocation),
        _text('UFDesemb', declaration.customsState),
        _text('dDesemb', _date(declaration.clearanceDate)),
        _text('tpViaTransp', '${declaration.transportMode}'),
        if (declaration.afrmm != null)
          _text('vAFRMM', declaration.afrmmDecimal.toFixed(2)),
        _text('tpIntermedio', '${declaration.intermediaryType}'),
        if (declaration.importerCnpj != null)
          _text('CNPJ', declaration.importerCnpj),
        if (declaration.thirdPartyState != null)
          _text('UFTerceiro', declaration.thirdPartyState),
        _text('cExportador', declaration.exporterCode),
        for (final addition in declaration.additions) _importAddition(addition),
      ]);

  XmlElement _importAddition(ImportAddition addition) =>
      XmlElement(XmlName.parts('adi'), const [], [
        _text('nAdicao', '${addition.number}'),
        _text('nSeqAdic', '${addition.sequence}'),
        _text('cFabricante', addition.manufacturerCode),
        if (addition.discount > 0)
          _text('vDescDI', FiscalDecimal.fromNum(addition.discount).toFixed(2)),
        if (addition.drawbackNumber != null)
          _text('nDraw', addition.drawbackNumber),
      ]);

  XmlElement _exportDetail(ExportDetail detail) => XmlElement(
    XmlName.parts('detExport'),
    const [],
    [
      if (detail.drawbackNumber != null) _text('nDraw', detail.drawbackNumber),
      for (final export in detail.individualExports)
        XmlElement(XmlName.parts('exportInd'), const [], [
          _text('nRE', export.registrationNumber),
          _text('chNFe', export.receivedInvoiceKey),
          _text(
            'qExport',
            FiscalDecimal.fromNum(export.exportedQuantity).toFixed(4),
          ),
        ]),
    ],
  );

  XmlElement _traceability(ProductTraceability batch) =>
      XmlElement(XmlName.parts('rastro'), const [], [
        _text('nLote', batch.batchNumber),
        _text('qLote', batch.quantityDecimal.toFixed(3)),
        _text('dFab', _date(batch.manufacturedAt)),
        _text('dVal', _date(batch.expiresAt)),
        if (batch.aggregatedCode != null) _text('cAgreg', batch.aggregatedCode),
      ]);

  XmlElement _medication(MedicationInfo medication) =>
      XmlElement(XmlName.parts('med'), const [], [
        _text('cProdANVISA', medication.anvisaProductCode),
        if (medication.exemptionReason != null)
          _text('xMotivoIsencao', medication.exemptionReason),
        _text(
          'vPMC',
          FiscalDecimal.fromNum(medication.maximumConsumerPrice).toFixed(2),
        ),
      ]);

  XmlElement _newVehicle(NewVehicleInfo vehicle) =>
      XmlElement(XmlName.parts('veicProd'), const [], [
        _text('tpOp', '${vehicle.operationType}'),
        _text('chassi', vehicle.chassis),
        _text('cCor', vehicle.colorCode),
        _text('xCor', vehicle.colorDescription),
        _text('pot', vehicle.power),
        _text('cilin', vehicle.engineCapacity),
        _text('pesoL', vehicle.netWeight),
        _text('pesoB', vehicle.grossWeight),
        _text('nSerie', vehicle.serialNumber),
        _text('tpComb', vehicle.fuelType),
        _text('nMotor', vehicle.engineNumber),
        _text('CMT', vehicle.maxTractionCapacity),
        _text('dist', vehicle.wheelbase),
        _text('anoMod', '${vehicle.modelYear}'),
        _text('anoFab', '${vehicle.manufactureYear}'),
        _text('tpPint', vehicle.paintType),
        _text('tpVeic', '${vehicle.vehicleType}'),
        _text('espVeic', '${vehicle.vehicleSpecies}'),
        _text('VIN', vehicle.vinStatus),
        _text('condVeic', '${vehicle.vehicleCondition}'),
        _text('cMod', '${vehicle.brandModelCode}'),
        _text('cCorDENATRAN', '${vehicle.denatranColorCode}'),
        _text('lota', '${vehicle.seatingCapacity}'),
        _text('tpRest', '${vehicle.restrictionType}'),
      ]);

  XmlElement _weapon(WeaponInfo weapon) =>
      XmlElement(XmlName.parts('arma'), const [], [
        _text('tpArma', '${weapon.type}'),
        _text('nSerie', weapon.serialNumber),
        _text('nCano', weapon.barrelNumber),
        _text('descr', weapon.description),
      ]);

  XmlElement _fuel(
    FuelInfo fuel,
  ) => XmlElement(XmlName.parts('comb'), const [], [
    _text('cProdANP', fuel.anpProductCode),
    _text('descANP', fuel.anpDescription),
    if (fuel.glpPetroleumPercentage != null)
      _text(
        'pGLP',
        FiscalDecimal.fromNum(fuel.glpPetroleumPercentage!).toFixed(4),
      ),
    if (fuel.nationalNaturalGasPercentage != null)
      _text(
        'pGNn',
        FiscalDecimal.fromNum(fuel.nationalNaturalGasPercentage!).toFixed(4),
      ),
    if (fuel.importedNaturalGasPercentage != null)
      _text(
        'pGNi',
        FiscalDecimal.fromNum(fuel.importedNaturalGasPercentage!).toFixed(4),
      ),
    if (fuel.startingValue != null)
      _text('vPart', FiscalDecimal.fromNum(fuel.startingValue!).toFixed(2)),
    if (fuel.codif != null) _text('CODIF', fuel.codif),
    if (fuel.temperatureQuantity != null)
      _text(
        'qTemp',
        FiscalDecimal.fromNum(fuel.temperatureQuantity!).toFixed(4),
      ),
    _text('UFCons', fuel.consumptionState),
    if (fuel.cide != null)
      XmlElement(XmlName.parts('CIDE'), const [], [
        _text(
          'qBCProd',
          FiscalDecimal.fromNum(fuel.cide!.quantityBase).toFixed(4),
        ),
        _text('vAliqProd', FiscalDecimal.fromNum(fuel.cide!.rate).toFixed(4)),
        _text('vCIDE', FiscalDecimal.fromNum(fuel.cide!.value).toFixed(2)),
      ]),
    if (fuel.gauge != null)
      XmlElement(XmlName.parts('encerrante'), const [], [
        _text('nBico', '${fuel.gauge!.nozzle}'),
        if (fuel.gauge!.pump != null) _text('nBomba', '${fuel.gauge!.pump}'),
        _text('nTanque', '${fuel.gauge!.tank}'),
        _text(
          'vEncIni',
          FiscalDecimal.fromNum(fuel.gauge!.initialReading).toFixed(3),
        ),
        _text(
          'vEncFin',
          FiscalDecimal.fromNum(fuel.gauge!.finalReading).toFixed(3),
        ),
      ]),
    if (fuel.biofuelPercentage != null)
      _text('pBio', FiscalDecimal.fromNum(fuel.biofuelPercentage!).toFixed(4)),
    for (final origin in fuel.origins)
      XmlElement(XmlName.parts('origComb'), const [], [
        _text('indImport', origin.imported ? '1' : '0'),
        _text('cUFOrig', origin.originState),
        _text('pOrig', FiscalDecimal.fromNum(origin.percentage).toFixed(4)),
      ]),
  ]);

  XmlElement _presumedCredit(PresumedCredit credit) =>
      XmlElement(XmlName.parts('gCred'), const [], [
        _text('cCredPresumido', credit.code),
        _text('pCredPresumido', FiscalDecimal.fromNum(credit.rate).toFixed(4)),
        _text('vCredPresumido', FiscalDecimal.fromNum(credit.value).toFixed(2)),
      ]);

  XmlElement _taxes(NfeItem item) =>
      XmlElement(XmlName.parts('imposto'), const [], [
        if (item.approximateTaxValue != null)
          _text(
            'vTotTrib',
            FiscalDecimal.fromNum(item.approximateTaxValue!).toFixed(2),
          ),
        if (item.icms != null) _icms(item.icms!),
        if (item.icmsSt != null) _icmsSt(item.icmsSt!),
        if (item.icmsStRetained != null) _icmsStRetained(item.icmsStRetained!),
        if (item.icmsPart != null) _icmsPart(item.icmsPart!),
        if (item.icmsSimples != null) _icmsSimples(item.icmsSimples!),
        if (item.icmsMonophase != null) _icmsMonophase(item.icmsMonophase!),
        if (item.ipi != null) _ipi(item.ipi!),
        if (item.importTax != null) _importTax(item.importTax!),
        if (item.serviceTax != null) _serviceTax(item.serviceTax!),
        if (item.pis != null) _pis(item.pis!),
        if (item.pisSt != null) _pisSt(item.pisSt!),
        if (item.cofins != null) _cofins(item.cofins!),
        if (item.cofinsSt != null) _cofinsSt(item.cofinsSt!),
        if (item.icmsUfDestination != null)
          _icmsUfDestination(item.icmsUfDestination!),
        if (item.selectiveTax != null) _selectiveTax(item.selectiveTax!),
        if (item.ibsCbs != null) _ibsCbs(item.ibsCbs!),
        if (item.ibsCbsMonophase != null)
          _ibsCbsMonophase(item.ibsCbsMonophase!),
      ]);

  XmlElement _icmsSt(IcmsStTax tax) => tax.stOnly
      ? _icmsStOnly(tax)
      : XmlElement(XmlName.parts('ICMS'), const [], [
          XmlElement(
            XmlName.parts(
              tax.cst == '10'
                  ? 'ICMS10'
                  : tax.cst == '70'
                  ? 'ICMS70'
                  : 'ICMS90',
            ),
            const [],
            [
              _text('orig', '${tax.origin}'),
              _text('CST', tax.cst),
              _text('modBC', '${tax.ownModality}'),
              if (tax.ownReduction != null)
                _text(
                  'pRedBC',
                  FiscalDecimal.fromNum(tax.ownReduction!).toFixed(4),
                ),
              _text('vBC', FiscalDecimal.fromNum(tax.base).toFixed(2)),
              _text('pICMS', FiscalDecimal.fromNum(tax.rate).toFixed(2)),
              _text('vICMS', FiscalDecimal.fromNum(tax.value).toFixed(2)),
              if (tax.fcpBase != null)
                _text('vBCFCP', FiscalDecimal.fromNum(tax.fcpBase!).toFixed(2)),
              if (tax.fcpRate != null)
                _text('pFCP', FiscalDecimal.fromNum(tax.fcpRate!).toFixed(4)),
              if (tax.fcpValue != null)
                _text('vFCP', FiscalDecimal.fromNum(tax.fcpValue!).toFixed(2)),
              _text('modBCST', '${tax.modality}'),
              if (tax.mva != null)
                _text('pMVAST', FiscalDecimal.fromNum(tax.mva!).toFixed(4)),
              if (tax.reduction != null)
                _text(
                  'pRedBCST',
                  FiscalDecimal.fromNum(tax.reduction!).toFixed(4),
                ),
              _text('vBCST', FiscalDecimal.fromNum(tax.stBase).toFixed(2)),
              _text('pICMSST', FiscalDecimal.fromNum(tax.stRate).toFixed(2)),
              _text('vICMSST', FiscalDecimal.fromNum(tax.stValue).toFixed(2)),
              if (tax.fcpStBase != null)
                _text(
                  'vBCFCPST',
                  FiscalDecimal.fromNum(tax.fcpStBase!).toFixed(2),
                ),
              if (tax.fcpStRate != null)
                _text(
                  'pFCPST',
                  FiscalDecimal.fromNum(tax.fcpStRate!).toFixed(4),
                ),
              if (tax.fcpStValue != null)
                _text(
                  'vFCPST',
                  FiscalDecimal.fromNum(tax.fcpStValue!).toFixed(2),
                ),
              if ((tax.cst == '70' || tax.cst == '90') &&
                  tax.ownDesonerationValue != null) ...[
                _text(
                  'vICMSDeson',
                  FiscalDecimal.fromNum(tax.ownDesonerationValue!).toFixed(2),
                ),
                _text('motDesICMS', '${tax.ownDesonerationReason ?? 9}'),
                if (tax.deductDesoneration != null)
                  _text('indDeduzDeson', tax.deductDesoneration! ? '1' : '0'),
              ],
              if ((tax.cst == '70' || tax.cst == '90') &&
                  tax.stDesonerationValue != null) ...[
                _text(
                  'vICMSSTDeson',
                  FiscalDecimal.fromNum(tax.stDesonerationValue!).toFixed(2),
                ),
                _text('motDesICMSST', '${tax.stDesonerationReason ?? 9}'),
              ],
              if (tax.operationRate != null)
                _text(
                  'pBCOp',
                  FiscalDecimal.fromNum(tax.operationRate!).toFixed(4),
                ),
              if (tax.destinationState != null)
                _text('UFST', tax.destinationState),
            ],
          ),
        ]);

  XmlElement _icmsStOnly(IcmsStTax tax) =>
      XmlElement(XmlName.parts('ICMS'), const [], [
        XmlElement(XmlName.parts('ICMSST'), const [], [
          _text('orig', '${tax.origin}'),
          _text('CST', tax.cst),
          _text('modBCST', '${tax.modality}'),
          if (tax.mva != null)
            _text('pMVAST', FiscalDecimal.fromNum(tax.mva!).toFixed(4)),
          if (tax.reduction != null)
            _text('pRedBCST', FiscalDecimal.fromNum(tax.reduction!).toFixed(4)),
          _text('vBCST', FiscalDecimal.fromNum(tax.stBase).toFixed(2)),
          _text('pICMSST', FiscalDecimal.fromNum(tax.stRate).toFixed(2)),
          _text('vICMSST', FiscalDecimal.fromNum(tax.stValue).toFixed(2)),
          if (tax.fcpStBase != null)
            _text('vBCFCPST', FiscalDecimal.fromNum(tax.fcpStBase!).toFixed(2)),
          if (tax.fcpStRate != null)
            _text('pFCPST', FiscalDecimal.fromNum(tax.fcpStRate!).toFixed(4)),
          if (tax.fcpStValue != null)
            _text('vFCPST', FiscalDecimal.fromNum(tax.fcpStValue!).toFixed(2)),
          if (tax.desonerationValue != null)
            _text(
              'vICMSDeson',
              FiscalDecimal.fromNum(tax.desonerationValue!).toFixed(2),
            ),
          if (tax.desonerationReason != null)
            _text('motDesICMS', '${tax.desonerationReason}'),
        ]),
      ]);

  XmlElement _icmsStRetained(
    IcmsStRetainedTax tax,
  ) => XmlElement(XmlName.parts('ICMS'), const [], [
    XmlElement(XmlName.parts('ICMSST'), const [], [
      _text('orig', '${tax.origin}'),
      _text('CST', tax.cst),
      _text('vBCSTRet', FiscalDecimal.fromNum(tax.retainedBase).toFixed(2)),
      if (tax.retainedRate != null)
        _text('pST', FiscalDecimal.fromNum(tax.retainedRate!).toFixed(4)),
      _text('vICMSSTRet', FiscalDecimal.fromNum(tax.retainedValue).toFixed(2)),
      if (tax.retainedFcpBase != null)
        _text(
          'vBCFCPSTRet',
          FiscalDecimal.fromNum(tax.retainedFcpBase!).toFixed(2),
        ),
      if (tax.retainedFcpRate != null)
        _text(
          'pFCPSTRet',
          FiscalDecimal.fromNum(tax.retainedFcpRate!).toFixed(4),
        ),
      if (tax.retainedFcpValue != null)
        _text(
          'vFCPSTRet',
          FiscalDecimal.fromNum(tax.retainedFcpValue!).toFixed(2),
        ),
      _text('vBCSTDest', FiscalDecimal.fromNum(tax.destinationBase).toFixed(2)),
      _text(
        'vICMSSTDest',
        FiscalDecimal.fromNum(tax.destinationValue).toFixed(2),
      ),
      if (tax.substitutedValue != null)
        _text(
          'vICMSSubstituto',
          FiscalDecimal.fromNum(tax.substitutedValue!).toFixed(2),
        ),
      if (tax.effectiveReduction != null)
        _text(
          'pRedBCEfet',
          FiscalDecimal.fromNum(tax.effectiveReduction!).toFixed(4),
        ),
      if (tax.effectiveBase != null)
        _text('vBCEfet', FiscalDecimal.fromNum(tax.effectiveBase!).toFixed(2)),
      if (tax.effectiveRate != null)
        _text(
          'pICMSEfet',
          FiscalDecimal.fromNum(tax.effectiveRate!).toFixed(4),
        ),
      if (tax.effectiveValue != null)
        _text(
          'vICMSEfet',
          FiscalDecimal.fromNum(tax.effectiveValue!).toFixed(2),
        ),
    ]),
  ]);

  XmlElement _icmsPart(IcmsPartTax tax) => XmlElement(
    XmlName.parts('ICMS'),
    const [],
    [
      XmlElement(XmlName.parts('ICMSPart'), const [], [
        _text('orig', '${tax.origin}'),
        _text('CST', tax.cst),
        _text('modBC', '${tax.modality}'),
        _text('vBC', FiscalDecimal.fromNum(tax.base).toFixed(2)),
        if (tax.reduction != null)
          _text('pRedBC', FiscalDecimal.fromNum(tax.reduction!).toFixed(4)),
        _text('pICMS', FiscalDecimal.fromNum(tax.rate).toFixed(4)),
        _text('vICMS', FiscalDecimal.fromNum(tax.value).toFixed(2)),
        _text('modBCST', '${tax.stModality}'),
        if (tax.mva != null)
          _text('pMVAST', FiscalDecimal.fromNum(tax.mva!).toFixed(4)),
        if (tax.stReduction != null)
          _text('pRedBCST', FiscalDecimal.fromNum(tax.stReduction!).toFixed(4)),
        _text('vBCST', FiscalDecimal.fromNum(tax.stBase).toFixed(2)),
        _text('pICMSST', FiscalDecimal.fromNum(tax.stRate).toFixed(4)),
        _text('vICMSST', FiscalDecimal.fromNum(tax.stValue).toFixed(2)),
        _text('pBCOp', FiscalDecimal.fromNum(tax.operationRate).toFixed(4)),
        _text('UFST', tax.destinationState),
      ]),
    ],
  );

  XmlElement _icmsUfDestination(
    IcmsUfDestinationTax tax,
  ) => XmlElement(XmlName.parts('ICMSUFDest'), const [], [
    _text('vBCUFDest', FiscalDecimal.fromNum(tax.base).toFixed(2)),
    if (tax.fcpBase != null)
      _text('vBCFCPUFDest', FiscalDecimal.fromNum(tax.fcpBase!).toFixed(2)),
    if (tax.fcpRate != null)
      _text('pFCPUFDest', FiscalDecimal.fromNum(tax.fcpRate!).toFixed(4)),
    _text('pICMSUFDest', FiscalDecimal.fromNum(tax.destinationRate).toFixed(4)),
    _text('pICMSInter', FiscalDecimal.fromNum(tax.interstateRate).toFixed(2)),
    _text(
      'pICMSInterPart',
      FiscalDecimal.fromNum(tax.partitionRate).toFixed(4),
    ),
    if (tax.fcpValue != null)
      _text('vFCPUFDest', FiscalDecimal.fromNum(tax.fcpValue!).toFixed(2)),
    _text(
      'vICMSUFDest',
      FiscalDecimal.fromNum(tax.destinationValue).toFixed(2),
    ),
    _text('vICMSUFRemet', FiscalDecimal.fromNum(tax.originValue).toFixed(2)),
  ]);

  XmlElement _ipi(IpiTax tax) {
    const nonTaxedCsts = [
      '01',
      '02',
      '03',
      '04',
      '05',
      '51',
      '52',
      '53',
      '54',
      '55',
    ];
    final group = nonTaxedCsts.contains(tax.cst) ? 'IPINT' : 'IPITrib';
    return XmlElement(XmlName.parts('IPI'), const [], [
      _text('cEnq', tax.enquadramento),
      if (group == 'IPINT')
        XmlElement(XmlName.parts('IPINT'), const [], [_text('CST', tax.cst)])
      else
        XmlElement(XmlName.parts('IPITrib'), const [], [
          _text('CST', tax.cst),
          if (tax.quantity != null) ...[
            _text('qUnid', FiscalDecimal.fromNum(tax.quantity!).toFixed(4)),
            _text('vUnid', FiscalDecimal.fromNum(tax.unitRate ?? 0).toFixed(4)),
          ] else ...[
            _text('vBC', FiscalDecimal.fromNum(tax.base).toFixed(2)),
            _text('pIPI', FiscalDecimal.fromNum(tax.rate).toFixed(4)),
          ],
          _text('vIPI', FiscalDecimal.fromNum(tax.value).toFixed(2)),
        ]),
    ]);
  }

  XmlElement _icms(IcmsTax tax) {
    final group = switch (tax.cst) {
      '20' => 'ICMS20',
      '40' || '41' || '50' => 'ICMS40',
      '51' => 'ICMS51',
      '60' => 'ICMS60',
      '90' => 'ICMS90',
      _ => 'ICMS00',
    };
    final children = <XmlNode>[
      _text('orig', '${tax.origin}'),
      _text('CST', tax.cst),
    ];
    switch (group) {
      case 'ICMS20':
        children.addAll([
          _text('modBC', '${tax.modality}'),
          _text('pRedBC', FiscalDecimal.fromNum(tax.reduction ?? 0).toFixed(2)),
          _text('vBC', FiscalDecimal.fromNum(tax.base).toFixed(2)),
          _text('pICMS', FiscalDecimal.fromNum(tax.rate).toFixed(2)),
          _text('vICMS', FiscalDecimal.fromNum(tax.value).toFixed(2)),
        ]);
      case 'ICMS40':
        break;
      case 'ICMS51':
        if (tax.modality >= 0) children.add(_text('modBC', '${tax.modality}'));
        if (tax.reduction != null) {
          children.add(
            _text('pRedBC', FiscalDecimal.fromNum(tax.reduction!).toFixed(2)),
          );
        }
        if (tax.benefitReductionCode != null) {
          children.add(_text('cBenefRBC', tax.benefitReductionCode));
        }
        if (tax.base >= 0) {
          children.add(
            _text('vBC', FiscalDecimal.fromNum(tax.base).toFixed(2)),
          );
        }
        if (tax.rate >= 0) {
          children.add(
            _text('pICMS', FiscalDecimal.fromNum(tax.rate).toFixed(2)),
          );
        }
        if (tax.operationValue != null) {
          children.add(
            _text(
              'vICMSOp',
              FiscalDecimal.fromNum(tax.operationValue!).toFixed(2),
            ),
          );
        }
        if (tax.differenceRate != null) {
          children.add(
            _text(
              'pDif',
              FiscalDecimal.fromNum(tax.differenceRate!).toFixed(2),
            ),
          );
        }
        if (tax.differenceValue != null) {
          children.add(
            _text(
              'vICMSDif',
              FiscalDecimal.fromNum(tax.differenceValue!).toFixed(2),
            ),
          );
        }
        if (tax.value >= 0) {
          children.add(
            _text('vICMS', FiscalDecimal.fromNum(tax.value).toFixed(2)),
          );
        }
      case 'ICMS60':
        if (tax.retainedBase != null) {
          children.add(
            _text(
              'vBCSTRet',
              FiscalDecimal.fromNum(tax.retainedBase!).toFixed(2),
            ),
          );
        }
        if (tax.retainedRate != null) {
          children.add(
            _text('pST', FiscalDecimal.fromNum(tax.retainedRate!).toFixed(2)),
          );
        }
        if (tax.substitutedValue != null) {
          children.add(
            _text(
              'vICMSSubstituto',
              FiscalDecimal.fromNum(tax.substitutedValue!).toFixed(2),
            ),
          );
        }
        if (tax.retainedValue != null) {
          children.add(
            _text(
              'vICMSSTRet',
              FiscalDecimal.fromNum(tax.retainedValue!).toFixed(2),
            ),
          );
        }
        if (tax.retainedFcpBase != null) {
          children.add(
            _text(
              'vBCFCPSTRet',
              FiscalDecimal.fromNum(tax.retainedFcpBase!).toFixed(2),
            ),
          );
        }
        if (tax.retainedFcpRate != null) {
          children.add(
            _text(
              'pFCPSTRet',
              FiscalDecimal.fromNum(tax.retainedFcpRate!).toFixed(4),
            ),
          );
        }
        if (tax.retainedFcpValue != null) {
          children.add(
            _text(
              'vFCPSTRet',
              FiscalDecimal.fromNum(tax.retainedFcpValue!).toFixed(2),
            ),
          );
        }
        if (tax.effectiveReduction != null) {
          children.add(
            _text(
              'pRedBCEfet',
              FiscalDecimal.fromNum(tax.effectiveReduction!).toFixed(4),
            ),
          );
        }
        if (tax.effectiveBase != null) {
          children.add(
            _text(
              'vBCEfet',
              FiscalDecimal.fromNum(tax.effectiveBase!).toFixed(2),
            ),
          );
        }
        if (tax.effectiveRate != null) {
          children.add(
            _text(
              'pICMSEfet',
              FiscalDecimal.fromNum(tax.effectiveRate!).toFixed(4),
            ),
          );
        }
        if (tax.effectiveValue != null) {
          children.add(
            _text(
              'vICMSEfet',
              FiscalDecimal.fromNum(tax.effectiveValue!).toFixed(2),
            ),
          );
        }
      case 'ICMS90':
        if (tax.base >= 0) {
          children.addAll([
            _text('modBC', '${tax.modality}'),
            _text('vBC', FiscalDecimal.fromNum(tax.base).toFixed(2)),
          ]);
          if (tax.reduction != null) {
            children.add(
              _text('pRedBC', FiscalDecimal.fromNum(tax.reduction!).toFixed(2)),
            );
          }
          if (tax.benefitReductionCode != null) {
            children.add(_text('cBenefRBC', tax.benefitReductionCode));
          }
          children.addAll([
            _text('pICMS', FiscalDecimal.fromNum(tax.rate).toFixed(2)),
            _text('vICMS', FiscalDecimal.fromNum(tax.value).toFixed(2)),
          ]);
        }
      default:
        children.addAll([
          _text('modBC', '${tax.modality}'),
          _text('vBC', FiscalDecimal.fromNum(tax.base).toFixed(2)),
          _text('pICMS', FiscalDecimal.fromNum(tax.rate).toFixed(2)),
          _text('vICMS', FiscalDecimal.fromNum(tax.value).toFixed(2)),
        ]);
    }
    if (tax.fcpRate != null && tax.fcpValue != null && group != 'ICMS40') {
      if (group == 'ICMS00' ||
          group == 'ICMS20' ||
          group == 'ICMS51' ||
          group == 'ICMS90') {
        children.addAll([
          _text('pFCP', FiscalDecimal.fromNum(tax.fcpRate!).toFixed(2)),
          _text('vFCP', FiscalDecimal.fromNum(tax.fcpValue!).toFixed(2)),
        ]);
      }
    }
    if (group == 'ICMS51') {
      if (tax.fcpDifferenceRate != null) {
        children.add(
          _text(
            'pFCPDif',
            FiscalDecimal.fromNum(tax.fcpDifferenceRate!).toFixed(2),
          ),
        );
      }
      if (tax.fcpDifferenceValue != null) {
        children.add(
          _text(
            'vFCPDif',
            FiscalDecimal.fromNum(tax.fcpDifferenceValue!).toFixed(2),
          ),
        );
      }
      if (tax.fcpEffectiveValue != null) {
        children.add(
          _text(
            'vFCPEfet',
            FiscalDecimal.fromNum(tax.fcpEffectiveValue!).toFixed(2),
          ),
        );
      }
    }
    if ((group == 'ICMS20' || group == 'ICMS40') &&
        tax.desonerationValue != null) {
      children.addAll([
        _text(
          'vICMSDeson',
          FiscalDecimal.fromNum(tax.desonerationValue!).toFixed(2),
        ),
        _text('motDesICMS', '${tax.desonerationReason ?? 9}'),
        if (tax.deductDesoneration != null)
          _text('indDeduzDeson', tax.deductDesoneration! ? '1' : '0'),
      ]);
    }
    return XmlElement(XmlName.parts('ICMS'), const [], [
      XmlElement(XmlName.parts(group), const [], children),
    ]);
  }

  XmlElement _icmsSimples(IcmsSimplesTax tax) {
    final group = switch (tax.csosn) {
      '101' => 'ICMSSN101',
      '102' || '103' || '300' || '400' => 'ICMSSN102',
      '201' => 'ICMSSN201',
      '202' || '203' => 'ICMSSN202',
      '500' => 'ICMSSN500',
      _ => 'ICMSSN900',
    };
    final children = <XmlNode>[
      _text('orig', '${tax.origin}'),
      _text('CSOSN', tax.csosn),
    ];
    if (group == 'ICMSSN101' || group == 'ICMSSN201') {
      if (group == 'ICMSSN201') children.addAll(_simpleStChildren(tax));
      children.addAll([
        _text('pCredSN', FiscalDecimal.fromNum(tax.creditRate ?? 0).toFixed(2)),
        _text(
          'vCredICMSSN',
          FiscalDecimal.fromNum(tax.creditValue ?? 0).toFixed(2),
        ),
      ]);
    } else if (group == 'ICMSSN202') {
      children.addAll(_simpleStChildren(tax));
    } else if (group == 'ICMSSN500') {
      if (tax.retainedBase != null) {
        children.addAll([
          _text(
            'vBCSTRet',
            FiscalDecimal.fromNum(tax.retainedBase!).toFixed(2),
          ),
          _text('pST', FiscalDecimal.fromNum(tax.retainedRate ?? 0).toFixed(2)),
          _text(
            'vICMSSTRet',
            FiscalDecimal.fromNum(tax.retainedValue ?? 0).toFixed(2),
          ),
          if (tax.retainedFcpBase != null) ...[
            _text(
              'vBCFCPSTRet',
              FiscalDecimal.fromNum(tax.retainedFcpBase!).toFixed(2),
            ),
            _text(
              'pFCPSTRet',
              FiscalDecimal.fromNum(tax.retainedFcpRate ?? 0).toFixed(2),
            ),
            _text(
              'vFCPSTRet',
              FiscalDecimal.fromNum(tax.retainedFcpValue ?? 0).toFixed(2),
            ),
          ],
        ]);
      }
      if (tax.effectiveBase != null) {
        children.addAll([
          if (tax.effectiveReduction != null)
            _text(
              'pRedBCEfet',
              FiscalDecimal.fromNum(tax.effectiveReduction!).toFixed(2),
            ),
          _text(
            'vBCEfet',
            FiscalDecimal.fromNum(tax.effectiveBase!).toFixed(2),
          ),
          _text(
            'pICMSEfet',
            FiscalDecimal.fromNum(tax.effectiveRate ?? 0).toFixed(2),
          ),
          _text(
            'vICMSEfet',
            FiscalDecimal.fromNum(tax.effectiveValue ?? 0).toFixed(2),
          ),
          if (tax.substitutedValue != null)
            _text(
              'vICMSSubstituto',
              FiscalDecimal.fromNum(tax.substitutedValue!).toFixed(2),
            ),
        ]);
      }
    } else {
      if (tax.base != null) {
        children.addAll([
          _text('modBC', '${tax.modality > 3 ? 3 : tax.modality}'),
          _text('vBC', FiscalDecimal.fromNum(tax.base!).toFixed(2)),
          _text('pICMS', FiscalDecimal.fromNum(tax.rate ?? 0).toFixed(2)),
          _text('vICMS', FiscalDecimal.fromNum(tax.value ?? 0).toFixed(2)),
        ]);
      }
      if (tax.stBase != null) children.addAll(_simpleStChildren(tax));
      if (tax.creditRate != null || tax.creditValue != null) {
        children.addAll([
          _text(
            'pCredSN',
            FiscalDecimal.fromNum(tax.creditRate ?? 0).toFixed(2),
          ),
          _text(
            'vCredICMSSN',
            FiscalDecimal.fromNum(tax.creditValue ?? 0).toFixed(2),
          ),
        ]);
      }
    }
    return XmlElement(XmlName.parts('ICMS'), const [], [
      XmlElement(XmlName.parts(group), const [], children),
    ]);
  }

  List<XmlNode> _simpleStChildren(IcmsSimplesTax tax) => [
    _text('modBCST', '${tax.modality}'),
    if (tax.mva != null)
      _text('pMVAST', FiscalDecimal.fromNum(tax.mva!).toFixed(2)),
    if (tax.reduction != null)
      _text('pRedBCST', FiscalDecimal.fromNum(tax.reduction!).toFixed(2)),
    _text('vBCST', FiscalDecimal.fromNum(tax.stBase ?? 0).toFixed(2)),
    _text('pICMSST', FiscalDecimal.fromNum(tax.stRate ?? 0).toFixed(2)),
    _text('vICMSST', FiscalDecimal.fromNum(tax.stValue ?? 0).toFixed(2)),
    if (tax.fcpStBase != null) ...[
      _text('vBCFCPST', FiscalDecimal.fromNum(tax.fcpStBase!).toFixed(2)),
      _text('pFCPST', FiscalDecimal.fromNum(tax.fcpStRate ?? 0).toFixed(2)),
      _text('vFCPST', FiscalDecimal.fromNum(tax.fcpStValue ?? 0).toFixed(2)),
    ],
  ];

  XmlElement _icmsMonophase(IcmsMonophaseTax tax) {
    final group = 'ICMS${tax.cst}';
    final children = <XmlNode>[
      _text('orig', '${tax.origin}'),
      _text('CST', tax.cst),
    ];
    if (tax.cst == '02') {
      if (tax.quantity != null) {
        children.add(
          _text('qBCMono', FiscalDecimal.fromNum(tax.quantity!).toFixed(4)),
        );
      }
      children.addAll([
        _text('adRemICMS', FiscalDecimal.fromNum(tax.rate ?? 0).toFixed(4)),
        _text('vICMSMono', FiscalDecimal.fromNum(tax.value ?? 0).toFixed(2)),
      ]);
    } else if (tax.cst == '15') {
      if (tax.quantity != null) {
        children.add(
          _text('qBCMono', FiscalDecimal.fromNum(tax.quantity!).toFixed(4)),
        );
      }
      children.addAll([
        _text('adRemICMS', FiscalDecimal.fromNum(tax.rate ?? 0).toFixed(4)),
        _text('vICMSMono', FiscalDecimal.fromNum(tax.value ?? 0).toFixed(2)),
      ]);
      if (tax.retainedQuantity != null) {
        children.add(
          _text(
            'qBCMonoReten',
            FiscalDecimal.fromNum(tax.retainedQuantity!).toFixed(4),
          ),
        );
      }
      children.addAll([
        _text(
          'adRemICMSReten',
          FiscalDecimal.fromNum(tax.retainedRate ?? 0).toFixed(4),
        ),
        _text(
          'vICMSMonoReten',
          FiscalDecimal.fromNum(tax.retainedValue ?? 0).toFixed(2),
        ),
      ]);
      if (tax.reductionRate != null) {
        children.addAll([
          _text(
            'pRedAdRem',
            FiscalDecimal.fromNum(tax.reductionRate!).toFixed(2),
          ),
          _text('motRedAdRem', '${tax.reductionReason ?? 9}'),
        ]);
      }
    } else if (tax.cst == '53') {
      if (tax.quantity != null) {
        children.add(
          _text('qBCMono', FiscalDecimal.fromNum(tax.quantity!).toFixed(4)),
        );
      }
      if (tax.rate != null) {
        children.add(
          _text('adRemICMS', FiscalDecimal.fromNum(tax.rate!).toFixed(4)),
        );
      }
      if (tax.operationValue != null) {
        children.add(
          _text(
            'vICMSMonoOp',
            FiscalDecimal.fromNum(tax.operationValue!).toFixed(2),
          ),
        );
      }
      if (tax.differenceRate != null) {
        children.add(
          _text('pDif', FiscalDecimal.fromNum(tax.differenceRate!).toFixed(2)),
        );
      }
      if (tax.differenceValue != null) {
        children.add(
          _text(
            'vICMSMonoDif',
            FiscalDecimal.fromNum(tax.differenceValue!).toFixed(2),
          ),
        );
      }
      if (tax.value != null) {
        children.add(
          _text('vICMSMono', FiscalDecimal.fromNum(tax.value!).toFixed(2)),
        );
      }
      if (tax.differenceQuantity != null) {
        children.add(
          _text(
            'qBCMonoDif',
            FiscalDecimal.fromNum(tax.differenceQuantity!).toFixed(4),
          ),
        );
      }
      if (tax.differenceAdRemRate != null) {
        children.add(
          _text(
            'adRemICMSDif',
            FiscalDecimal.fromNum(tax.differenceAdRemRate!).toFixed(4),
          ),
        );
      }
    } else {
      if (tax.retainedQuantity != null) {
        children.add(
          _text(
            'qBCMonoRet',
            FiscalDecimal.fromNum(tax.retainedQuantity!).toFixed(4),
          ),
        );
      }
      children.addAll([
        _text(
          'adRemICMSRet',
          FiscalDecimal.fromNum(tax.retainedRate ?? 0).toFixed(4),
        ),
        _text(
          'vICMSMonoRet',
          FiscalDecimal.fromNum(tax.retainedValue ?? 0).toFixed(2),
        ),
      ]);
    }
    return XmlElement(XmlName.parts('ICMS'), const [], [
      XmlElement(XmlName.parts(group), const [], children),
    ]);
  }

  XmlElement _ibsCbs(IbsCbsTax tax) => XmlElement(
    XmlName.parts('IBSCBS'),
    const [],
    [
      _text('CST', tax.cst),
      _text('cClassTrib', tax.classificationCode),
      if (tax.donation != null) _text('indDoacao', tax.donation! ? '1' : '0'),
      XmlElement(XmlName.parts('gIBSCBS'), const [], [
        _text('vBC', FiscalDecimal.fromNum(tax.base).toFixed(2)),
        XmlElement(XmlName.parts('gIBSUF'), const [], [
          _text('pIBSUF', FiscalDecimal.fromNum(tax.ibsUfRate).toFixed(4)),
          if (tax.ibsUfDeferral != null) _reformDeferral(tax.ibsUfDeferral!),
          if (tax.ibsUfRefund != null) _reformRefund(tax.ibsUfRefund!),
          if (tax.ibsUfReduction != null) _reformReduction(tax.ibsUfReduction!),
          _text('vIBSUF', tax.ibsUfValue.toFixed(2)),
        ]),
        XmlElement(XmlName.parts('gIBSMun'), const [], [
          _text(
            'pIBSMun',
            FiscalDecimal.fromNum(tax.ibsMunicipalRate).toFixed(4),
          ),
          if (tax.ibsMunicipalDeferral != null)
            _reformDeferral(tax.ibsMunicipalDeferral!),
          if (tax.ibsMunicipalRefund != null)
            _reformRefund(tax.ibsMunicipalRefund!),
          if (tax.ibsMunicipalReduction != null)
            _reformReduction(tax.ibsMunicipalReduction!),
          _text('vIBSMun', tax.ibsMunicipalValue.toFixed(2)),
        ]),
        _text('vIBS', tax.ibsValue.toFixed(2)),
        XmlElement(XmlName.parts('gCBS'), const [], [
          _text('pCBS', FiscalDecimal.fromNum(tax.cbsRate).toFixed(4)),
          if (tax.cbsDeferral != null) _reformDeferral(tax.cbsDeferral!),
          if (tax.cbsRefund != null) _reformRefund(tax.cbsRefund!),
          if (tax.cbsReduction != null) _reformReduction(tax.cbsReduction!),
          _text('vCBS', tax.cbsValue.toFixed(2)),
        ]),
        if (tax.regularTax != null) _reformRegularTax(tax.regularTax!),
        if (tax.governmentTax != null) _reformGovernmentTax(tax.governmentTax!),
      ]),
      if (tax.creditReversal != null)
        XmlElement(XmlName.parts('gEstornoCred'), const [], [
          _text(
            'vIBSEstCred',
            FiscalDecimal.fromNum(tax.creditReversal!.ibsValue).toFixed(2),
          ),
          _text(
            'vCBSEstCred',
            FiscalDecimal.fromNum(tax.creditReversal!.cbsValue).toFixed(2),
          ),
        ]),
      if (tax.operationCredit != null)
        _reformOperationCredit(tax.operationCredit!),
      if (tax.zfmCredit != null) _reformZfmCredit(tax.zfmCredit!),
    ],
  );

  XmlElement _reformRegularTax(
    ReformRegularTax tax,
  ) => XmlElement(XmlName.parts('gTribRegular'), const [], [
    _text('CSTReg', tax.cst),
    _text('cClassTribReg', tax.classificationCode),
    _text('pAliqEfetRegIBSUF', FiscalDecimal.fromNum(tax.ibsUfRate).toFixed(4)),
    _text('vTribRegIBSUF', FiscalDecimal.fromNum(tax.ibsUfValue).toFixed(2)),
    _text(
      'pAliqEfetRegIBSMun',
      FiscalDecimal.fromNum(tax.ibsMunicipalRate).toFixed(4),
    ),
    _text(
      'vTribRegIBSMun',
      FiscalDecimal.fromNum(tax.ibsMunicipalValue).toFixed(2),
    ),
    _text('pAliqEfetRegCBS', FiscalDecimal.fromNum(tax.cbsRate).toFixed(4)),
    _text('vTribRegCBS', FiscalDecimal.fromNum(tax.cbsValue).toFixed(2)),
  ]);

  XmlElement _reformGovernmentTax(ReformGovernmentTax tax) =>
      XmlElement(XmlName.parts('gTribCompraGov'), const [], [
        _text('pAliqIBSUF', FiscalDecimal.fromNum(tax.ibsUfRate).toFixed(4)),
        _text('vTribIBSUF', FiscalDecimal.fromNum(tax.ibsUfValue).toFixed(2)),
        _text(
          'pAliqIBSMun',
          FiscalDecimal.fromNum(tax.ibsMunicipalRate).toFixed(4),
        ),
        _text(
          'vTribIBSMun',
          FiscalDecimal.fromNum(tax.ibsMunicipalValue).toFixed(2),
        ),
        _text('pAliqCBS', FiscalDecimal.fromNum(tax.cbsRate).toFixed(4)),
        _text('vTribCBS', FiscalDecimal.fromNum(tax.cbsValue).toFixed(2)),
      ]);

  XmlElement _ibsCbsMonophase(IbsCbsMonophaseTax tax) {
    final children = <XmlNode>[];
    if (tax.hasIbs) {
      final adValorem = tax.ibsAdValoremBase != null;
      final group = <XmlNode>[];
      if (adValorem) {
        group.add(
          XmlElement(XmlName.parts('gMonoPadrao'), const [], [
            _text(
              'vBCMono',
              FiscalDecimal.fromNum(tax.ibsAdValoremBase!).toFixed(2),
            ),
            _text(
              'pAliqMonoUF',
              FiscalDecimal.fromNum(tax.ibsAdValoremUfRate!).toFixed(4),
            ),
            _text(
              'vIBSMonoUF',
              FiscalDecimal.fromNum(tax.ibsAdValoremUfValue!).toFixed(2),
            ),
            _text(
              'pAliqMonoMun',
              FiscalDecimal.fromNum(tax.ibsAdValoremMunicipalRate!).toFixed(4),
            ),
            _text(
              'vIBSMonoMun',
              FiscalDecimal.fromNum(tax.ibsAdValoremMunicipalValue!).toFixed(2),
            ),
            _text(
              'vIBSMono',
              FiscalDecimal.fromNum(tax.ibsAdValoremValue!).toFixed(2),
            ),
          ]),
        );
      } else {
        group.add(
          XmlElement(XmlName.parts('gMonoPadrao'), const [], [
            _text('qBCMono', FiscalDecimal.fromNum(tax.quantity!).toFixed(4)),
            _text('adRemIBS', FiscalDecimal.fromNum(tax.ibsRate!).toFixed(4)),
            _text('vIBSMono', FiscalDecimal.fromNum(tax.ibsValue!).toFixed(2)),
          ]),
        );
        if (tax.ibsRetainedValue != null) {
          group.add(
            XmlElement(XmlName.parts('gMonoReten'), const [], [
              _text(
                'qBCMonoReten',
                FiscalDecimal.fromNum(tax.ibsRetainedQuantity!).toFixed(4),
              ),
              _text(
                'adRemIBSReten',
                FiscalDecimal.fromNum(tax.ibsRetainedRate!).toFixed(4),
              ),
              _text(
                'vIBSMonoReten',
                FiscalDecimal.fromNum(tax.ibsRetainedValue!).toFixed(2),
              ),
            ]),
          );
        }
        if (tax.ibsPreviouslyRetainedValue != null) {
          group.add(
            XmlElement(XmlName.parts('gMonoRet'), const [], [
              _text(
                'vIBSMonoRet',
                FiscalDecimal.fromNum(
                  tax.ibsPreviouslyRetainedValue!,
                ).toFixed(2),
              ),
            ]),
          );
        }
      }
      if (tax.ibsBiofuelQuantity != null) {
        group.add(
          XmlElement(XmlName.parts('gpBioDiferenca'), const [], [
            _text(
              'qBCBioComb',
              FiscalDecimal.fromNum(tax.ibsBiofuelQuantity!).toFixed(4),
            ),
            _text(
              'vIBSDiferenca',
              FiscalDecimal.fromNum(tax.ibsBiofuelDifference!).toFixed(2),
            ),
          ]),
        );
      }
      children.add(
        XmlElement(
          XmlName.parts(adValorem ? 'gIBSMonoAdValorem' : 'gIBSMonoAdRem'),
          const [],
          group,
        ),
      );
    }
    if (tax.hasCbs) {
      final adValorem = tax.cbsAdValoremBase != null;
      final group = <XmlNode>[];
      if (adValorem) {
        group.add(
          XmlElement(XmlName.parts('gMonoPadrao'), const [], [
            _text(
              'vBCMono',
              FiscalDecimal.fromNum(tax.cbsAdValoremBase!).toFixed(2),
            ),
            _text(
              'pAliqMonoCBS',
              FiscalDecimal.fromNum(tax.cbsAdValoremRate!).toFixed(4),
            ),
            _text(
              'vCBSMono',
              FiscalDecimal.fromNum(tax.cbsAdValoremValue!).toFixed(2),
            ),
          ]),
        );
      } else {
        group.add(
          XmlElement(XmlName.parts('gMonoPadrao'), const [], [
            _text('qBCMono', FiscalDecimal.fromNum(tax.quantity!).toFixed(4)),
            _text('adRemCBS', FiscalDecimal.fromNum(tax.cbsRate!).toFixed(4)),
            _text('vCBSMono', FiscalDecimal.fromNum(tax.cbsValue!).toFixed(2)),
          ]),
        );
        if (tax.cbsRetainedValue != null) {
          group.add(
            XmlElement(XmlName.parts('gMonoReten'), const [], [
              _text(
                'qBCMonoReten',
                FiscalDecimal.fromNum(tax.cbsRetainedQuantity!).toFixed(4),
              ),
              _text(
                'adRemCBSReten',
                FiscalDecimal.fromNum(tax.cbsRetainedRate!).toFixed(4),
              ),
              _text(
                'vCBSMonoReten',
                FiscalDecimal.fromNum(tax.cbsRetainedValue!).toFixed(2),
              ),
            ]),
          );
        }
        if (tax.cbsPreviouslyRetainedValue != null) {
          group.add(
            XmlElement(XmlName.parts('gMonoRet'), const [], [
              _text(
                'vCBSMonoRet',
                FiscalDecimal.fromNum(
                  tax.cbsPreviouslyRetainedValue!,
                ).toFixed(2),
              ),
            ]),
          );
        }
      }
      if (tax.cbsBiofuelQuantity != null) {
        group.add(
          XmlElement(XmlName.parts('gpBioDiferenca'), const [], [
            _text(
              'qBCBioComb',
              FiscalDecimal.fromNum(tax.cbsBiofuelQuantity!).toFixed(4),
            ),
            _text(
              'vCBSDiferenca',
              FiscalDecimal.fromNum(tax.cbsBiofuelDifference!).toFixed(2),
            ),
          ]),
        );
      }
      children.add(
        XmlElement(
          XmlName.parts(adValorem ? 'gCBSMonoAdValorem' : 'gCBSMonoAdRem'),
          const [],
          group,
        ),
      );
    }
    return XmlElement(XmlName.parts('IBSCBS'), const [], [
      _text('CST', tax.cst),
      _text('cClassTrib', tax.classificationCode),
      XmlElement(XmlName.parts('gIBSCBSMono'), const [], [
        ...children,
        _text('vTotIBSMonoItem', tax.totalIbsValue.toFixed(2)),
        _text('vTotCBSMonoItem', tax.totalCbsValue.toFixed(2)),
      ]),
    ]);
  }

  XmlElement _reformDeferral(ReformDeferral value) =>
      XmlElement(XmlName.parts('gDif'), const [], [
        _text('pDif', FiscalDecimal.fromNum(value.rate).toFixed(4)),
        _text('vDif', FiscalDecimal.fromNum(value.value).toFixed(2)),
      ]);

  XmlElement _reformRefund(ReformRefund value) =>
      XmlElement(XmlName.parts('gDevTrib'), const [], [
        if (value.rate != null)
          _text('pDevTrib', FiscalDecimal.fromNum(value.rate!).toFixed(4)),
        _text('vDevTrib', FiscalDecimal.fromNum(value.value).toFixed(2)),
      ]);

  XmlElement _reformReduction(ReformReduction value) =>
      XmlElement(XmlName.parts('gRed'), const [], [
        _text('pRedAliq', FiscalDecimal.fromNum(value.rate).toFixed(4)),
        _text(
          'pAliqEfet',
          FiscalDecimal.fromNum(value.effectiveRate).toFixed(4),
        ),
      ]);

  XmlElement _selectiveTax(SelectiveTax tax) =>
      XmlElement(XmlName.parts('IS'), const [], [
        _text('CSTIS', tax.cst),
        _text('cClassTribIS', tax.classificationCode),
        _text('vBCIS', FiscalDecimal.fromNum(tax.base).toFixed(2)),
        _text('pIS', FiscalDecimal.fromNum(tax.rate).toFixed(4)),
        if (tax.adRemRate != null)
          _text('adRemIS', FiscalDecimal.fromNum(tax.adRemRate!).toFixed(4)),
        if (tax.unit != null) _text('uTrib', tax.unit!),
        if (tax.quantity != null)
          _text('qTrib', FiscalDecimal.fromNum(tax.quantity!).toFixed(4)),
        _text('vIS', tax.value.toFixed(2)),
      ]);

  XmlElement _impostoDevol(IpiDevolution devolution) => XmlElement(
    XmlName.parts('impostoDevol'),
    const [],
    [
      _text('pDevol', FiscalDecimal.fromNum(devolution.percentage).toFixed(2)),
      XmlElement(XmlName.parts('IPI'), const [], [
        _text('vIPIDevol', FiscalDecimal.fromNum(devolution.value).toFixed(2)),
      ]),
    ],
  );

  XmlElement _reformOperationCredit(
    ReformOperationCredit credit,
  ) => XmlElement(XmlName.parts('gCredPresOper'), const [], [
    _text('vBCCredPres', FiscalDecimal.fromNum(credit.base).toFixed(2)),
    _text('cCredPres', credit.code),
    if (credit.ibs != null) _reformPresumedCredit('gIBSCredPres', credit.ibs!),
    if (credit.cbs != null) _reformPresumedCredit('gCBSCredPres', credit.cbs!),
  ]);

  XmlElement _reformPresumedCredit(String tag, ReformPresumedCredit credit) =>
      XmlElement(XmlName.parts(tag), const [], [
        _text('pCredPres', FiscalDecimal.fromNum(credit.rate).toFixed(4)),
        _text(
          credit.conditionalSuspension ? 'vCredPresCondSus' : 'vCredPres',
          FiscalDecimal.fromNum(credit.value).toFixed(2),
        ),
      ]);

  XmlElement _reformZfmCredit(ReformZfmCredit credit) =>
      XmlElement(XmlName.parts('gCredPresIBSZFM'), const [], [
        _text('competApur', _yearMonth(credit.competence)),
        _text('tpCredPresIBSZFM', credit.type),
        _text(
          'vCredPresIBSZFM',
          FiscalDecimal.fromNum(credit.value).toFixed(2),
        ),
      ]);

  String _yearMonth(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}';

  XmlElement _retTrib(
    TaxRetention retention,
  ) => XmlElement(XmlName.parts('retTrib'), const [], [
    if (retention.pis > 0)
      _text('vRetPIS', FiscalDecimal.fromNum(retention.pis).toFixed(2)),
    if (retention.cofins > 0)
      _text('vRetCOFINS', FiscalDecimal.fromNum(retention.cofins).toFixed(2)),
    if (retention.csll > 0)
      _text('vRetCSLL', FiscalDecimal.fromNum(retention.csll).toFixed(2)),
    if (retention.irrfBase > 0)
      _text('vBCIRRF', FiscalDecimal.fromNum(retention.irrfBase).toFixed(2)),
    if (retention.irrf > 0)
      _text('vIRRF', FiscalDecimal.fromNum(retention.irrf).toFixed(2)),
    if (retention.socialSecurityBase > 0)
      _text(
        'vBCRetPrev',
        FiscalDecimal.fromNum(retention.socialSecurityBase).toFixed(2),
      ),
    if (retention.socialSecurity > 0)
      _text(
        'vRetPrev',
        FiscalDecimal.fromNum(retention.socialSecurity).toFixed(2),
      ),
  ]);

  XmlElement _importTax(ImportTax tax) =>
      XmlElement(XmlName.parts('II'), const [], [
        _text('vBC', FiscalDecimal.fromNum(tax.base).toFixed(2)),
        _text(
          'vDespAdu',
          FiscalDecimal.fromNum(tax.customsExpenses).toFixed(2),
        ),
        _text('vII', FiscalDecimal.fromNum(tax.value).toFixed(2)),
        _text('vIOF', FiscalDecimal.fromNum(tax.iof).toFixed(2)),
      ]);

  XmlElement _pisSt(PisStTax tax) {
    final children = <XmlNode>[];
    if (tax.quantity != null) {
      final unitRate = tax.unitRate;
      if (unitRate == null) {
        throw const FiscalValidationException(
          'PISST por quantidade exige vAliqProd.',
          code: 'INVALID_PISST',
        );
      }
      children.addAll([
        _text('qBCProd', FiscalDecimal.fromNum(tax.quantity!).toFixed(4)),
        _text('vAliqProd', FiscalDecimal.fromNum(unitRate).toFixed(4)),
      ]);
    } else {
      final base = tax.base;
      final rate = tax.rate;
      if (base == null || rate == null) {
        throw const FiscalValidationException(
          'PISST por percentual exige vBC e pPIS.',
          code: 'INVALID_PISST',
        );
      }
      children.addAll([
        _text('vBC', FiscalDecimal.fromNum(base).toFixed(2)),
        _text('pPIS', FiscalDecimal.fromNum(rate).toFixed(4)),
      ]);
    }
    children.add(_text('vPIS', FiscalDecimal.fromNum(tax.value).toFixed(2)));
    return XmlElement(XmlName.parts('PISST'), const [], children);
  }

  XmlElement _cofinsSt(CofinsStTax tax) {
    final children = <XmlNode>[];
    if (tax.quantity != null) {
      final unitRate = tax.unitRate;
      if (unitRate == null) {
        throw const FiscalValidationException(
          'COFINSST por quantidade exige vAliqProd.',
          code: 'INVALID_COFINSST',
        );
      }
      children.addAll([
        _text('qBCProd', FiscalDecimal.fromNum(tax.quantity!).toFixed(4)),
        _text('vAliqProd', FiscalDecimal.fromNum(unitRate).toFixed(4)),
      ]);
    } else {
      final base = tax.base;
      final rate = tax.rate;
      if (base == null || rate == null) {
        throw const FiscalValidationException(
          'COFINSST por percentual exige vBC e pCOFINS.',
          code: 'INVALID_COFINSST',
        );
      }
      children.addAll([
        _text('vBC', FiscalDecimal.fromNum(base).toFixed(2)),
        _text('pCOFINS', FiscalDecimal.fromNum(rate).toFixed(4)),
      ]);
    }
    children.add(_text('vCOFINS', FiscalDecimal.fromNum(tax.value).toFixed(2)));
    return XmlElement(XmlName.parts('COFINSST'), const [], children);
  }

  XmlElement _pis(PisTax tax) {
    final group = tax.cst == '03'
        ? 'PISQtde'
        : tax.base == null && tax.quantity == null
        ? 'PISNT'
        : _isAliquotCst(tax.cst)
        ? 'PISAliq'
        : 'PISOutr';
    return XmlElement(XmlName.parts('PIS'), const [], [
      XmlElement(XmlName.parts(group), const [], [
        _text('CST', tax.cst),
        if (group == 'PISQtde' || tax.quantity != null) ...[
          _text('qBCProd', FiscalDecimal.fromNum(tax.quantity ?? 0).toFixed(4)),
          _text(
            'vAliqProd',
            FiscalDecimal.fromNum(tax.unitRate ?? 0).toFixed(4),
          ),
        ] else if (tax.base != null)
          _text('vBC', FiscalDecimal.fromNum(tax.base!).toFixed(2)),
        if (group != 'PISQtde' && tax.quantity == null && tax.rate != null)
          _text('pPIS', FiscalDecimal.fromNum(tax.rate!).toFixed(4)),
        if (tax.value != null)
          _text('vPIS', FiscalDecimal.fromNum(tax.value!).toFixed(2)),
      ]),
    ]);
  }

  XmlElement _cofins(CofinsTax tax) {
    final group = tax.cst == '03'
        ? 'COFINSQtde'
        : tax.base == null && tax.quantity == null
        ? 'COFINSNT'
        : _isAliquotCst(tax.cst)
        ? 'COFINSAliq'
        : 'COFINSOutr';
    return XmlElement(XmlName.parts('COFINS'), const [], [
      XmlElement(XmlName.parts(group), const [], [
        _text('CST', tax.cst),
        if (group == 'COFINSQtde' || tax.quantity != null) ...[
          _text('qBCProd', FiscalDecimal.fromNum(tax.quantity ?? 0).toFixed(4)),
          _text(
            'vAliqProd',
            FiscalDecimal.fromNum(tax.unitRate ?? 0).toFixed(4),
          ),
        ] else if (tax.base != null)
          _text('vBC', FiscalDecimal.fromNum(tax.base!).toFixed(2)),
        if (group != 'COFINSQtde' && tax.quantity == null && tax.rate != null)
          _text('pCOFINS', FiscalDecimal.fromNum(tax.rate!).toFixed(4)),
        if (tax.value != null)
          _text('vCOFINS', FiscalDecimal.fromNum(tax.value!).toFixed(2)),
      ]),
    ]);
  }

  bool _isAliquotCst(String cst) => cst == '01' || cst == '02';

  XmlElement _serviceTax(ServiceTax tax) =>
      XmlElement(XmlName.parts('ISSQN'), const [], [
        _text('vBC', FiscalDecimal.fromNum(tax.base).toFixed(2)),
        _text('vAliq', FiscalDecimal.fromNum(tax.rate).toFixed(4)),
        _text('vISSQN', FiscalDecimal.fromNum(tax.value).toFixed(2)),
        _text('cMunFG', tax.municipalityCode),
        _text('cListServ', tax.serviceListCode),
        if (tax.deduction > 0)
          _text('vDeducao', FiscalDecimal.fromNum(tax.deduction).toFixed(2)),
        if (tax.other > 0)
          _text('vOutro', FiscalDecimal.fromNum(tax.other).toFixed(2)),
        if (tax.unconditionalDiscount > 0)
          _text(
            'vDescIncond',
            FiscalDecimal.fromNum(tax.unconditionalDiscount).toFixed(2),
          ),
        if (tax.conditionalDiscount > 0)
          _text(
            'vDescCond',
            FiscalDecimal.fromNum(tax.conditionalDiscount).toFixed(2),
          ),
        if (tax.retained > 0)
          _text('vISSRet', FiscalDecimal.fromNum(tax.retained).toFixed(2)),
        _text('indISS', '${tax.exigibility}'),
        if (tax.serviceCode != null) _text('cServico', tax.serviceCode),
        if (tax.incidenceMunicipalityCode != null)
          _text('cMun', tax.incidenceMunicipalityCode),
        _text('indIncentivo', tax.incentive ? '1' : '2'),
      ]);

  XmlElement _total(NfeDocument d) =>
      XmlElement(XmlName.parts('total'), const [], [
        XmlElement(XmlName.parts('ICMSTot'), const [], [
          _text('vBC', _sumIcmsBase(d).toFixed(2)),
          _text('vICMS', _sumIcmsValue(d).toFixed(2)),
          _text('vICMSDeson', _sumIcmsDesoneration(d).toFixed(2)),
          if (_hasIcmsUfDestination(d)) ...[
            _text('vFCPUFDest', _sumIcmsUfDestinationFcp(d).toFixed(2)),
            _text('vICMSUFDest', _sumIcmsUfDestinationValue(d).toFixed(2)),
            _text('vICMSUFRemet', _sumIcmsUfOriginValue(d).toFixed(2)),
          ],
          _text('vFCP', _sumFcpValue(d).toFixed(2)),
          _text('vBCST', _sumIcmsStBase(d).toFixed(2)),
          _text('vST', _sumIcmsStValue(d).toFixed(2)),
          _text('vFCPST', _sumFcpStValue(d).toFixed(2)),
          _text('vFCPSTRet', _sumFcpStRetainedValue(d).toFixed(2)),
          if (_hasMonophase(d)) ...[
            _text('qBCMono', _sumMonophaseQuantity(d).toFixed(2)),
            _text('vICMSMono', _sumMonophaseValue(d).toFixed(2)),
            _text('qBCMonoReten', _sumMonophaseRetainedQuantity(d).toFixed(2)),
            _text('vICMSMonoReten', _sumMonophaseRetainedValue(d).toFixed(2)),
            _text('qBCMonoRet', _sumMonophaseRetainedQuantity61(d).toFixed(2)),
            _text('vICMSMonoRet', _sumMonophaseRetainedValue61(d).toFixed(2)),
          ],
          _text('vProd', _sumMerchandise(d).toFixed(2)),
          _text('vFrete', _sumFreight(d).toFixed(2)),
          _text('vSeg', _sumInsurance(d).toFixed(2)),
          _text('vDesc', _sumDiscount(d).toFixed(2)),
          _text('vII', _sumImportDuty(d).toFixed(2)),
          _text('vIPI', _sumIpiValue(d).toFixed(2)),
          _text('vIPIDevol', _sumIpiDevolution(d).toFixed(2)),
          _text('vPIS', _sumPisValue(d).toFixed(2)),
          _text('vCOFINS', _sumCofinsValue(d).toFixed(2)),
          _text('vOutro', _sumOther(d).toFixed(2)),
          _text('vNF', _invoiceTotal(d).toFixed(2)),
        ]),
        if (_hasServiceTax(d) || d.serviceTotal != null) _serviceTotal(d),
        if (d.taxRetention != null) _retTrib(d.taxRetention!),
        if (_hasSelectiveTax(d))
          XmlElement(XmlName.parts('ISTot'), const [], [
            _text('vIS', _sumSelectiveValue(d).toFixed(2)),
          ]),
        if (_hasIbsCbsTax(d)) _ibsCbsTotal(d),
        if (_hasIbsCbsTax(d) || _hasSelectiveTax(d))
          _text('vNFTot', _totalWithReformTaxes(d).toFixed(2)),
      ]);

  XmlElement _ibsCbsTotal(
    NfeDocument d,
  ) => XmlElement(XmlName.parts('IBSCBSTot'), const [], [
    _text('vBCIBSCBS', _sumIbsCbsBase(d).toFixed(2)),
    XmlElement(XmlName.parts('gIBS'), const [], [
      XmlElement(XmlName.parts('gIBSUF'), const [], [
        _text('vDif', _sumIbsUfDeferral(d).toFixed(2)),
        _text('vDevTrib', _sumIbsUfRefund(d).toFixed(2)),
        _text('vIBSUF', _sumIbsUfValue(d).toFixed(2)),
      ]),
      XmlElement(XmlName.parts('gIBSMun'), const [], [
        _text('vDif', _sumIbsMunicipalDeferral(d).toFixed(2)),
        _text('vDevTrib', _sumIbsMunicipalRefund(d).toFixed(2)),
        _text('vIBSMun', _sumIbsMunicipalValue(d).toFixed(2)),
      ]),
      _text('vIBS', _sumIbsValue(d).toFixed(2)),
      _text('vCredPres', _sumIbsPresumedCredit(d).toFixed(2)),
      _text('vCredPresCondSus', _sumOperationCredit(d, true, true).toFixed(2)),
    ]),
    XmlElement(XmlName.parts('gCBS'), const [], [
      _text('vDif', _sumCbsDeferral(d).toFixed(2)),
      _text('vDevTrib', _sumCbsRefund(d).toFixed(2)),
      _text('vCBS', _sumCbsValue(d).toFixed(2)),
      _text('vCredPres', _sumOperationCredit(d, false, false).toFixed(2)),
      _text('vCredPresCondSus', _sumOperationCredit(d, false, true).toFixed(2)),
    ]),
    XmlElement(XmlName.parts('gMono'), const [], [
      _text('vIBSMono', _sumIbsMonophaseValue(d).toFixed(2)),
      _text('vCBSMono', _sumCbsMonophaseValue(d).toFixed(2)),
      _text('vIBSMonoReten', _sumIbsRetainedValue(d, true).toFixed(2)),
      _text('vCBSMonoReten', _sumIbsRetainedValue(d, false).toFixed(2)),
      _text('vIBSMonoRet', _sumPreviouslyRetainedValue(d, true).toFixed(2)),
      _text('vCBSMonoRet', _sumPreviouslyRetainedValue(d, false).toFixed(2)),
    ]),
    if (_hasCreditReversal(d))
      XmlElement(XmlName.parts('gEstornoCred'), const [], [
        _text('vIBSEstCred', _sumCreditReversal(d, true).toFixed(2)),
        _text('vCBSEstCred', _sumCreditReversal(d, false).toFixed(2)),
      ]),
  ]);

  Iterable<NfeItem> _includedItems(NfeDocument d) =>
      d.items.where((item) => item.includeInTotal);

  FiscalDecimal _sumIbsCbsBase(NfeDocument d) => _includedItems(d).fold(
    FiscalDecimal.parse('0'),
    (sum, item) => sum + FiscalDecimal.fromNum(item.ibsCbs?.base ?? 0),
  );

  FiscalDecimal _sumIcmsDesoneration(NfeDocument d) => _includedItems(d).fold(
    FiscalDecimal.parse('0'),
    (sum, item) =>
        sum +
        FiscalDecimal.fromNum(item.icms?.desonerationValue ?? 0) +
        FiscalDecimal.fromNum(item.icmsSt?.desonerationValue ?? 0),
  );

  FiscalDecimal _sumIbsUfDeferral(NfeDocument d) => _includedItems(d).fold(
    FiscalDecimal.parse('0'),
    (sum, item) =>
        sum + FiscalDecimal.fromNum(item.ibsCbs?.ibsUfDeferral?.value ?? 0),
  );

  FiscalDecimal _sumIbsUfRefund(NfeDocument d) => _includedItems(d).fold(
    FiscalDecimal.parse('0'),
    (sum, item) =>
        sum + FiscalDecimal.fromNum(item.ibsCbs?.ibsUfRefund?.value ?? 0),
  );

  FiscalDecimal _sumIbsMunicipalDeferral(NfeDocument d) =>
      _includedItems(d).fold(
        FiscalDecimal.parse('0'),
        (sum, item) =>
            sum +
            FiscalDecimal.fromNum(
              item.ibsCbs?.ibsMunicipalDeferral?.value ?? 0,
            ),
      );

  FiscalDecimal _sumIbsMunicipalRefund(NfeDocument d) => _includedItems(d).fold(
    FiscalDecimal.parse('0'),
    (sum, item) =>
        sum +
        FiscalDecimal.fromNum(item.ibsCbs?.ibsMunicipalRefund?.value ?? 0),
  );

  FiscalDecimal _sumCbsDeferral(NfeDocument d) => _includedItems(d).fold(
    FiscalDecimal.parse('0'),
    (sum, item) =>
        sum + FiscalDecimal.fromNum(item.ibsCbs?.cbsDeferral?.value ?? 0),
  );

  FiscalDecimal _sumCbsRefund(NfeDocument d) => _includedItems(d).fold(
    FiscalDecimal.parse('0'),
    (sum, item) =>
        sum + FiscalDecimal.fromNum(item.ibsCbs?.cbsRefund?.value ?? 0),
  );

  FiscalDecimal _sumOperationCredit(
    NfeDocument d,
    bool ibs,
    bool conditionalSuspension,
  ) => _includedItems(d).fold(FiscalDecimal.parse('0'), (sum, item) {
    final credit = ibs
        ? item.ibsCbs?.operationCredit?.ibs
        : item.ibsCbs?.operationCredit?.cbs;
    if (credit == null ||
        credit.conditionalSuspension != conditionalSuspension) {
      return sum;
    }
    return sum + FiscalDecimal.fromNum(credit.value);
  });

  FiscalDecimal _sumIbsPresumedCredit(NfeDocument d) => _includedItems(d).fold(
    FiscalDecimal.parse('0'),
    (sum, item) =>
        sum +
        (item.ibsCbs?.operationCredit?.ibs == null
            ? FiscalDecimal.parse('0')
            : FiscalDecimal.fromNum(
                item.ibsCbs!.operationCredit!.ibs!.conditionalSuspension
                    ? 0
                    : item.ibsCbs!.operationCredit!.ibs!.value,
              )) +
        FiscalDecimal.fromNum(item.ibsCbs?.zfmCredit?.value ?? 0),
  );

  bool _hasCreditReversal(NfeDocument d) =>
      _includedItems(d).any((item) => item.ibsCbs?.creditReversal != null);

  FiscalDecimal _sumCreditReversal(NfeDocument d, bool ibs) =>
      _includedItems(d).fold(
        FiscalDecimal.parse('0'),
        (sum, item) =>
            sum +
            FiscalDecimal.fromNum(
              ibs
                  ? item.ibsCbs?.creditReversal?.ibsValue ?? 0
                  : item.ibsCbs?.creditReversal?.cbsValue ?? 0,
            ),
      );

  FiscalDecimal _sumIbsUfValue(NfeDocument d) => _includedItems(d).fold(
    FiscalDecimal.parse('0'),
    (sum, item) => sum + (item.ibsCbs?.ibsUfValue ?? FiscalDecimal.parse('0')),
  );

  FiscalDecimal _sumIbsMunicipalValue(NfeDocument d) => _includedItems(d).fold(
    FiscalDecimal.parse('0'),
    (sum, item) =>
        sum + (item.ibsCbs?.ibsMunicipalValue ?? FiscalDecimal.parse('0')),
  );

  FiscalDecimal _sumIbsValue(NfeDocument d) => _includedItems(d).fold(
    FiscalDecimal.parse('0'),
    (sum, item) =>
        sum +
        (item.ibsCbs?.ibsValue ??
            FiscalDecimal.fromNum(item.ibsCbsMonophase?.ibsValue ?? 0)),
  );

  FiscalDecimal _sumCbsValue(NfeDocument d) => _includedItems(d).fold(
    FiscalDecimal.parse('0'),
    (sum, item) =>
        sum +
        (item.ibsCbs?.cbsValue ??
            FiscalDecimal.fromNum(item.ibsCbsMonophase?.cbsValue ?? 0)),
  );

  FiscalDecimal _sumIbsMonophaseValue(NfeDocument d) => _includedItems(d).fold(
    FiscalDecimal.parse('0'),
    (sum, item) =>
        sum + (item.ibsCbsMonophase?.totalIbsValue ?? FiscalDecimal.parse('0')),
  );

  FiscalDecimal _sumCbsMonophaseValue(NfeDocument d) => _includedItems(d).fold(
    FiscalDecimal.parse('0'),
    (sum, item) =>
        sum + (item.ibsCbsMonophase?.totalCbsValue ?? FiscalDecimal.parse('0')),
  );

  FiscalDecimal _sumIbsRetainedValue(NfeDocument d, bool ibs) =>
      _includedItems(d).fold(
        FiscalDecimal.parse('0'),
        (sum, item) =>
            sum +
            FiscalDecimal.fromNum(
              ibs
                  ? item.ibsCbsMonophase?.ibsRetainedValue ?? 0
                  : item.ibsCbsMonophase?.cbsRetainedValue ?? 0,
            ),
      );

  FiscalDecimal _sumPreviouslyRetainedValue(NfeDocument d, bool ibs) =>
      _includedItems(d).fold(
        FiscalDecimal.parse('0'),
        (sum, item) =>
            sum +
            FiscalDecimal.fromNum(
              ibs
                  ? item.ibsCbsMonophase?.ibsPreviouslyRetainedValue ?? 0
                  : item.ibsCbsMonophase?.cbsPreviouslyRetainedValue ?? 0,
            ),
      );

  FiscalDecimal _sumSelectiveValue(NfeDocument d) => _includedItems(d).fold(
    FiscalDecimal.parse('0'),
    (sum, item) => sum + (item.selectiveTax?.value ?? FiscalDecimal.parse('0')),
  );

  bool _hasIbsCbsTax(NfeDocument d) => _includedItems(
    d,
  ).any((item) => item.ibsCbs != null || item.ibsCbsMonophase != null);

  bool _hasSelectiveTax(NfeDocument d) =>
      _includedItems(d).any((item) => item.selectiveTax != null);

  bool _hasServiceTax(NfeDocument d) =>
      _includedItems(d).any((item) => item.serviceTax != null);

  XmlElement _serviceTotal(NfeDocument d) {
    final declared = d.serviceTotal;
    if (declared != null) {
      return XmlElement(XmlName.parts('ISSQNtot'), const [], [
        _text('vServ', FiscalDecimal.fromNum(declared.serviceValue).toFixed(2)),
        _text('vBC', FiscalDecimal.fromNum(declared.taxBase).toFixed(2)),
        _text('vISS', FiscalDecimal.fromNum(declared.taxValue).toFixed(2)),
        if (declared.pis > 0)
          _text('vPIS', FiscalDecimal.fromNum(declared.pis).toFixed(2)),
        if (declared.cofins > 0)
          _text('vCOFINS', FiscalDecimal.fromNum(declared.cofins).toFixed(2)),
        _text('dCompet', _date(declared.competenceDate)),
        if (declared.deduction > 0)
          _text(
            'vDeducao',
            FiscalDecimal.fromNum(declared.deduction).toFixed(2),
          ),
        if (declared.other > 0)
          _text('vOutro', FiscalDecimal.fromNum(declared.other).toFixed(2)),
        if (declared.unconditionalDiscount > 0)
          _text(
            'vDescIncond',
            FiscalDecimal.fromNum(declared.unconditionalDiscount).toFixed(2),
          ),
        if (declared.conditionalDiscount > 0)
          _text(
            'vDescCond',
            FiscalDecimal.fromNum(declared.conditionalDiscount).toFixed(2),
          ),
        if (declared.retained > 0)
          _text('vISSRet', FiscalDecimal.fromNum(declared.retained).toFixed(2)),
        if (declared.taxRegime != null)
          _text('cRegTrib', '${declared.taxRegime}'),
      ]);
    }
    final services = _includedItems(
      d,
    ).where((item) => item.serviceTax != null).toList();
    final first = services.first.serviceTax!;
    return XmlElement(XmlName.parts('ISSQNtot'), const [], [
      _text('vServ', _sumServiceValue(d).toFixed(2)),
      _text('vBC', _sumServiceBase(d).toFixed(2)),
      _text('vISS', _sumServiceTax(d).toFixed(2)),
      _text('dCompet', _date(first.competenceDate)),
      if (_hasFiscalValue(_sumServiceDeduction(d)))
        _text('vDeducao', _sumServiceDeduction(d).toFixed(2)),
      if (_hasFiscalValue(_sumServiceOther(d)))
        _text('vOutro', _sumServiceOther(d).toFixed(2)),
      if (_hasFiscalValue(_sumServiceUnconditionalDiscount(d)))
        _text('vDescIncond', _sumServiceUnconditionalDiscount(d).toFixed(2)),
      if (_hasFiscalValue(_sumServiceConditionalDiscount(d)))
        _text('vDescCond', _sumServiceConditionalDiscount(d).toFixed(2)),
      if (_hasFiscalValue(_sumServiceRetained(d)))
        _text('vISSRet', _sumServiceRetained(d).toFixed(2)),
    ]);
  }

  FiscalDecimal _sumServiceValue(NfeDocument d) => _includedItems(d).fold(
    FiscalDecimal.parse('0'),
    (sum, item) =>
        item.serviceTax == null ? sum : sum + item.merchandiseTotalDecimal,
  );

  FiscalDecimal _sumServiceBase(NfeDocument d) => _includedItems(d).fold(
    FiscalDecimal.parse('0'),
    (sum, item) => sum + FiscalDecimal.fromNum(item.serviceTax?.base ?? 0),
  );

  FiscalDecimal _sumServiceTax(NfeDocument d) => _includedItems(d).fold(
    FiscalDecimal.parse('0'),
    (sum, item) => sum + FiscalDecimal.fromNum(item.serviceTax?.value ?? 0),
  );

  FiscalDecimal _sumServiceDeduction(NfeDocument d) => _includedItems(d).fold(
    FiscalDecimal.parse('0'),
    (sum, item) => sum + FiscalDecimal.fromNum(item.serviceTax?.deduction ?? 0),
  );

  FiscalDecimal _sumServiceOther(NfeDocument d) => _includedItems(d).fold(
    FiscalDecimal.parse('0'),
    (sum, item) => sum + FiscalDecimal.fromNum(item.serviceTax?.other ?? 0),
  );

  FiscalDecimal _sumServiceUnconditionalDiscount(NfeDocument d) =>
      _includedItems(d).fold(
        FiscalDecimal.parse('0'),
        (sum, item) =>
            sum +
            FiscalDecimal.fromNum(item.serviceTax?.unconditionalDiscount ?? 0),
      );

  FiscalDecimal _sumServiceConditionalDiscount(NfeDocument d) =>
      _includedItems(d).fold(
        FiscalDecimal.parse('0'),
        (sum, item) =>
            sum +
            FiscalDecimal.fromNum(item.serviceTax?.conditionalDiscount ?? 0),
      );

  FiscalDecimal _sumServiceRetained(NfeDocument d) => _includedItems(d).fold(
    FiscalDecimal.parse('0'),
    (sum, item) => sum + FiscalDecimal.fromNum(item.serviceTax?.retained ?? 0),
  );

  bool _hasFiscalValue(FiscalDecimal value) => value.toFixed(2) != '0.00';

  FiscalDecimal _totalWithReformTaxes(NfeDocument d) =>
      d.totalDecimal +
      _sumIbsValue(d) +
      _sumCbsValue(d) +
      _sumSelectiveValue(d);

  FiscalDecimal _sumIcmsBase(NfeDocument d) => _includedItems(d).fold(
    FiscalDecimal.parse('0'),
    (sum, item) => sum + FiscalDecimal.fromNum(item.icms?.base ?? 0),
  );

  FiscalDecimal _sumMerchandise(NfeDocument d) => _includedItems(d).fold(
    FiscalDecimal.parse('0'),
    (sum, item) => sum + item.merchandiseTotalDecimal,
  );

  FiscalDecimal _sumFreight(NfeDocument d) => _includedItems(d).fold(
    FiscalDecimal.parse('0'),
    (sum, item) => sum + FiscalDecimal.fromNum(item.freight),
  );

  FiscalDecimal _sumInsurance(NfeDocument d) => _includedItems(d).fold(
    FiscalDecimal.parse('0'),
    (sum, item) => sum + FiscalDecimal.fromNum(item.insurance),
  );

  FiscalDecimal _sumDiscount(NfeDocument d) => _includedItems(d).fold(
    FiscalDecimal.parse('0'),
    (sum, item) => sum + FiscalDecimal.fromNum(item.discount),
  );

  FiscalDecimal _sumOther(NfeDocument d) => _includedItems(d).fold(
    FiscalDecimal.parse('0'),
    (sum, item) => sum + FiscalDecimal.fromNum(item.other),
  );

  FiscalDecimal _sumImportDuty(NfeDocument d) => _includedItems(d).fold(
    FiscalDecimal.parse('0'),
    (sum, item) =>
        sum +
        FiscalDecimal.fromNum(item.importDuty) +
        FiscalDecimal.fromNum(item.importTax?.value ?? 0),
  );

  FiscalDecimal _invoiceTotal(NfeDocument d) =>
      _sumMerchandise(d) +
      _sumFreight(d) +
      _sumInsurance(d) +
      _sumOther(d) +
      _sumImportDuty(d) +
      _sumIpiValue(d) +
      _sumIcmsStValue(d) -
      _sumDiscount(d);

  FiscalDecimal _sumIcmsValue(NfeDocument d) => _includedItems(d).fold(
    FiscalDecimal.parse('0'),
    (sum, item) => sum + FiscalDecimal.fromNum(item.icms?.value ?? 0),
  );

  FiscalDecimal _sumFcpValue(NfeDocument d) => _includedItems(d).fold(
    FiscalDecimal.parse('0'),
    (sum, item) =>
        sum +
        FiscalDecimal.fromNum(
          item.icms?.fcpValue ?? item.icmsSt?.fcpValue ?? 0,
        ),
  );

  FiscalDecimal _sumIcmsStBase(NfeDocument d) => _includedItems(d).fold(
    FiscalDecimal.parse('0'),
    (sum, item) =>
        sum +
        FiscalDecimal.fromNum(item.icmsSt?.stBase ?? 0) +
        FiscalDecimal.fromNum(item.icmsSimples?.stBase ?? 0),
  );

  FiscalDecimal _sumIcmsStValue(NfeDocument d) => _includedItems(d).fold(
    FiscalDecimal.parse('0'),
    (sum, item) =>
        sum +
        FiscalDecimal.fromNum(item.icmsSt?.stValue ?? 0) +
        FiscalDecimal.fromNum(item.icmsSimples?.stValue ?? 0),
  );

  bool _hasIcmsUfDestination(NfeDocument d) =>
      _includedItems(d).any((item) => item.icmsUfDestination != null);

  FiscalDecimal _sumIcmsUfDestinationFcp(NfeDocument d) =>
      _includedItems(d).fold(
        FiscalDecimal.parse('0'),
        (sum, item) =>
            sum + FiscalDecimal.fromNum(item.icmsUfDestination?.fcpValue ?? 0),
      );

  FiscalDecimal _sumIcmsUfDestinationValue(NfeDocument d) =>
      _includedItems(d).fold(
        FiscalDecimal.parse('0'),
        (sum, item) =>
            sum +
            FiscalDecimal.fromNum(
              item.icmsUfDestination?.destinationValue ?? 0,
            ),
      );

  FiscalDecimal _sumIcmsUfOriginValue(NfeDocument d) => _includedItems(d).fold(
    FiscalDecimal.parse('0'),
    (sum, item) =>
        sum + FiscalDecimal.fromNum(item.icmsUfDestination?.originValue ?? 0),
  );

  FiscalDecimal _sumFcpStValue(NfeDocument d) => _includedItems(d).fold(
    FiscalDecimal.parse('0'),
    (sum, item) =>
        sum +
        FiscalDecimal.fromNum(item.icmsSt?.fcpStValue ?? 0) +
        FiscalDecimal.fromNum(item.icmsSimples?.fcpStValue ?? 0),
  );

  bool _hasMonophase(NfeDocument d) =>
      _includedItems(d).any((item) => item.icmsMonophase != null);

  FiscalDecimal _sumMonophaseQuantity(NfeDocument d) => _includedItems(d).fold(
    FiscalDecimal.parse('0'),
    (sum, item) =>
        sum + FiscalDecimal.fromNum(item.icmsMonophase?.quantity ?? 0),
  );

  FiscalDecimal _sumMonophaseValue(NfeDocument d) => _includedItems(d).fold(
    FiscalDecimal.parse('0'),
    (sum, item) => sum + FiscalDecimal.fromNum(item.icmsMonophase?.value ?? 0),
  );

  FiscalDecimal _sumMonophaseRetainedQuantity(
    NfeDocument d,
  ) => _includedItems(d).fold(
    FiscalDecimal.parse('0'),
    (sum, item) => item.icmsMonophase?.cst == '15'
        ? sum + FiscalDecimal.fromNum(item.icmsMonophase?.retainedQuantity ?? 0)
        : sum,
  );

  FiscalDecimal _sumMonophaseRetainedValue(NfeDocument d) =>
      _includedItems(d).fold(
        FiscalDecimal.parse('0'),
        (sum, item) => item.icmsMonophase?.cst == '15'
            ? sum +
                  FiscalDecimal.fromNum(item.icmsMonophase?.retainedValue ?? 0)
            : sum,
      );

  FiscalDecimal _sumFcpStRetainedValue(NfeDocument d) => _includedItems(d).fold(
    FiscalDecimal.parse('0'),
    (sum, item) =>
        sum + FiscalDecimal.fromNum(item.icmsStRetained?.retainedFcpValue ?? 0),
  );

  FiscalDecimal _sumMonophaseRetainedQuantity61(
    NfeDocument d,
  ) => _includedItems(d).fold(
    FiscalDecimal.parse('0'),
    (sum, item) => item.icmsMonophase?.cst == '61'
        ? sum + FiscalDecimal.fromNum(item.icmsMonophase?.retainedQuantity ?? 0)
        : sum,
  );

  FiscalDecimal _sumMonophaseRetainedValue61(NfeDocument d) =>
      _includedItems(d).fold(
        FiscalDecimal.parse('0'),
        (sum, item) => item.icmsMonophase?.cst == '61'
            ? sum +
                  FiscalDecimal.fromNum(item.icmsMonophase?.retainedValue ?? 0)
            : sum,
      );

  FiscalDecimal _sumPisValue(NfeDocument d) => _includedItems(d).fold(
    FiscalDecimal.parse('0'),
    (sum, item) => sum + FiscalDecimal.fromNum(item.pis?.value ?? 0),
  );

  FiscalDecimal _sumCofinsValue(NfeDocument d) => _includedItems(d).fold(
    FiscalDecimal.parse('0'),
    (sum, item) => sum + FiscalDecimal.fromNum(item.cofins?.value ?? 0),
  );

  FiscalDecimal _sumIpiValue(NfeDocument d) => _includedItems(d).fold(
    FiscalDecimal.parse('0'),
    (sum, item) => sum + FiscalDecimal.fromNum(item.ipi?.value ?? 0),
  );

  FiscalDecimal _sumIpiDevolution(NfeDocument d) => _includedItems(d).fold(
    FiscalDecimal.parse('0'),
    (sum, item) => sum + FiscalDecimal.fromNum(item.ipiDevolution?.value ?? 0),
  );

  XmlElement _payments(NfeDocument d) =>
      XmlElement(XmlName.parts('pag'), const [], [
        for (final payment in d.payments) _payment(payment),
        if (d.changeValue != null)
          _text('vTroco', FiscalDecimal.fromNum(d.changeValue!).toFixed(2)),
      ]);

  XmlElement _billing(BillingInfo billing) =>
      XmlElement(XmlName.parts('cobr'), const [], [
        _invoice(billing),
        for (final installment in billing.installments) _duplicate(installment),
      ]);

  XmlElement _payment(Payment payment) =>
      XmlElement(XmlName.parts('detPag'), const [], [
        _text('indPag', '${payment.indicator}'),
        _text('tPag', payment.type),
        if (payment.description != null) _text('xPag', payment.description),
        _text('vPag', FiscalDecimal.fromNum(payment.value).toFixed(2)),
        if (payment.integration != null ||
            payment.brand != null ||
            payment.authorization != null)
          XmlElement(XmlName.parts('card'), const [], [
            _text('tpIntegra', '${payment.integration}'),
            if (payment.brand != null) _text('tBand', payment.brand),
            if (payment.authorization != null)
              _text('cAut', payment.authorization),
          ]),
      ]);

  XmlElement _invoice(BillingInfo billing) =>
      XmlElement(XmlName.parts('fat'), const [], [
        _text('nFat', billing.invoiceNumber),
        _text('vOrig', FiscalDecimal.fromNum(billing.originalValue).toFixed(2)),
        _text('vDesc', FiscalDecimal.fromNum(billing.discount).toFixed(2)),
        _text('vLiq', FiscalDecimal.fromNum(billing.netValue).toFixed(2)),
      ]);

  XmlElement _duplicate(InvoiceInstallment installment) =>
      XmlElement(XmlName.parts('dup'), const [], [
        _text('nDup', installment.number),
        _text('dVenc', _date(installment.dueDate)),
        _text('vDup', FiscalDecimal.fromNum(installment.value).toFixed(2)),
      ]);

  XmlElement _technicalResponsible(TechnicalResponsible responsible) =>
      XmlElement(XmlName.parts('infRespTec'), const [], [
        _text('CNPJ', responsible.cnpj),
        _text('xContato', responsible.contact),
        _text('email', responsible.email),
        _text('fone', responsible.phone),
        if (responsible.csrtId != null) _text('idCSRT', responsible.csrtId),
        if (responsible.csrt != null) _text('hashCSRT', responsible.csrt),
      ]);

  XmlElement _intermediary(IntermediaryInfo intermediary) =>
      XmlElement(XmlName.parts('infIntermed'), const [], [
        _text('CNPJ', Tools.onlyDigits(intermediary.cnpj)),
        _text('idCadIntTran', intermediary.identifier),
      ]);

  XmlElement _governmentPurchase(GovernmentPurchase purchase) =>
      XmlElement(XmlName.parts('gCompraGov'), const [], [
        _text('tpEnteGov', '${purchase.governmentEntityType}'),
        _text(
          'pRedutor',
          FiscalDecimal.fromNum(purchase.reductionPercentage).toFixed(4),
        ),
        _text('tpOperGov', '${purchase.operationType}'),
        for (final reference in purchase.previousDocumentReferences)
          _text('refDFeAnt', reference),
      ]);

  String _date(DateTime value) {
    final date = value.toUtc();
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _dateTime(DateTime value) {
    final date = value.toUtc();
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}T'
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}:'
        '${date.second.toString().padLeft(2, '0')}+00:00';
  }

  XmlElement _transport(NfeDocument d) {
    final transport = d.transport;
    if (transport.freightMode < 0 || transport.freightMode > 9) {
      throw const FiscalValidationException(
        'A modalidade do frete deve estar entre 0 e 9.',
        code: 'INVALID_FREIGHT_MODE',
      );
    }
    final carrier = transport.carrier == null
        ? null
        : Tools.onlyDigits(transport.carrier!);
    if (carrier != null &&
        !Tools.isValidCnpj(carrier) &&
        !Tools.isValidCpf(carrier)) {
      throw const FiscalValidationException(
        'O CPF/CNPJ do transportador é inválido.',
        code: 'INVALID_CARRIER_TAX_ID',
      );
    }
    final state = transport.vehicleState?.trim().toUpperCase();
    if (state != null && !RegExp(r'^[A-Z]{2}$').hasMatch(state)) {
      throw const FiscalValidationException(
        'A UF do veículo deve possuir duas letras.',
        code: 'INVALID_VEHICLE_STATE',
      );
    }
    final plate = transport.vehiclePlate?.trim().toUpperCase();
    if (plate != null && !RegExp(r'^[A-Z0-9]{7}$').hasMatch(plate)) {
      throw const FiscalValidationException(
        'A placa do veículo deve possuir sete caracteres alfanuméricos.',
        code: 'INVALID_VEHICLE_PLATE',
      );
    }
    if ((transport.railcar != null || transport.barge != null) &&
        (plate != null || transport.trailers.isNotEmpty)) {
      throw const FiscalValidationException(
        'Vagão ou balsa não podem coexistir com veículo rodoviário ou reboques.',
        code: 'CONFLICTING_TRANSPORT_MODALITIES',
      );
    }
    if (transport.railcar != null && transport.barge != null) {
      throw const FiscalValidationException(
        'Vagão e balsa não podem ser informados simultaneamente.',
        code: 'CONFLICTING_TRANSPORT_MODALITIES',
      );
    }
    if (transport.carrierName != null &&
        (transport.carrierName!.trim().length < 2 ||
            transport.carrierName!.length > 60)) {
      throw const FiscalValidationException(
        'O nome do transportador deve possuir entre 2 e 60 caracteres.',
        code: 'INVALID_CARRIER_NAME',
      );
    }
    final retention = transport.retention;
    if (retention != null &&
        (retention.serviceValue < 0 ||
            retention.taxBase < 0 ||
            retention.rate < 0 ||
            retention.rate > 100 ||
            retention.taxValue < 0 ||
            !RegExp(r'^[1-9][0-9]{3}$').hasMatch(retention.cfop) ||
            !RegExp(r'^\d{7}$').hasMatch(retention.municipalityCode))) {
      throw const FiscalValidationException(
        'Os dados da retenção do transporte são inválidos.',
        code: 'INVALID_TRANSPORT_RETENTION',
      );
    }
    return XmlElement(XmlName.parts('transp'), const [], [
      _text('modFrete', '${transport.freightMode}'),
      if (carrier != null ||
          transport.carrierName != null ||
          transport.carrierIe != null ||
          transport.carrierAddress != null ||
          transport.carrierCity != null)
        _transporta(transport),
      if (retention != null) _retTransp(retention),
      if (plate != null)
        XmlElement(XmlName.parts('veicTransp'), const [], [
          _text('placa', plate),
          if (state != null) _text('UF', state),
          if (transport.vehicleRegistration != null)
            _text('RNTC', transport.vehicleRegistration),
        ]),
      for (final trailer in transport.trailers)
        _transportVehicle('reboque', trailer),
      if (transport.railcar != null) _text('vagao', transport.railcar),
      if (transport.barge != null) _text('balsa', transport.barge),
      for (final volume in transport.volumes) _transportVolume(volume),
    ]);
  }

  XmlElement _transporta(TransportInfo transport) {
    final carrier = transport.carrier == null
        ? null
        : Tools.onlyDigits(transport.carrier!);
    return XmlElement(XmlName.parts('transporta'), const [], [
      if (carrier != null && carrier.length == 14)
        _text('CNPJ', carrier)
      else if (carrier != null)
        _text('CPF', carrier),
      if (transport.carrierName != null) _text('xNome', transport.carrierName),
      if (transport.carrierIe != null) _text('IE', transport.carrierIe),
      if (transport.carrierAddress != null)
        _text('xEnder', transport.carrierAddress),
      if (transport.carrierCity != null) _text('xMun', transport.carrierCity),
    ]);
  }

  XmlElement _retTransp(TransportTaxRetention retention) {
    if (retention.serviceValue < 0 ||
        retention.taxBase < 0 ||
        retention.rate < 0 ||
        retention.rate > 100 ||
        retention.taxValue < 0 ||
        !RegExp(r'^[1-9][0-9]{3}$').hasMatch(retention.cfop) ||
        !RegExp(r'^\d{7}$').hasMatch(retention.municipalityCode)) {
      throw const FiscalValidationException(
        'Os dados da retenção do transporte são inválidos.',
        code: 'INVALID_TRANSPORT_RETENTION',
      );
    }
    return XmlElement(XmlName.parts('retTransp'), const [], [
      _text('vServ', FiscalDecimal.fromNum(retention.serviceValue).toFixed(2)),
      _text('vBCRet', FiscalDecimal.fromNum(retention.taxBase).toFixed(2)),
      _text('pICMSRet', FiscalDecimal.fromNum(retention.rate).toFixed(2)),
      _text('vICMSRet', FiscalDecimal.fromNum(retention.taxValue).toFixed(2)),
      _text('CFOP', retention.cfop),
      _text('cMunFG', retention.municipalityCode),
    ]);
  }

  XmlElement _transportVehicle(String tag, TransportVehicle vehicle) {
    final normalizedPlate = vehicle.plate.trim().toUpperCase();
    final normalizedState = vehicle.state?.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{7}$').hasMatch(normalizedPlate) ||
        normalizedState != null &&
            !RegExp(r'^[A-Z]{2}$').hasMatch(normalizedState)) {
      throw const FiscalValidationException(
        'Os dados do veículo de transporte são inválidos.',
        code: 'INVALID_TRANSPORT_VEHICLE',
      );
    }
    return XmlElement(XmlName.parts(tag), const [], [
      _text('placa', normalizedPlate),
      if (normalizedState != null) _text('UF', normalizedState),
      if (vehicle.registration != null) _text('RNTC', vehicle.registration),
    ]);
  }

  XmlElement _transportVolume(TransportVolume volume) {
    if (volume.quantity != null && volume.quantity! < 0 ||
        volume.seal.any((seal) => seal.trim().isEmpty)) {
      throw const FiscalValidationException(
        'Os dados do volume transportado são inválidos.',
        code: 'INVALID_TRANSPORT_VOLUME',
      );
    }
    return XmlElement(XmlName.parts('vol'), const [], [
      if (volume.quantity != null) _text('qVol', '${volume.quantity}'),
      if (volume.kind != null) _text('esp', volume.kind),
      if (volume.brand != null) _text('marca', volume.brand),
      if (volume.number != null) _text('nVol', volume.number),
      for (final seal in volume.seal)
        XmlElement(XmlName.parts('lacres'), const [], [_text('nLacre', seal)]),
    ]);
  }

  XmlElement _additionalInfo(NfeDocument d) =>
      XmlElement(XmlName.parts('infAdic'), const [], [
        if (d.additionalInfo?.complementary != null)
          _text('infCpl', d.additionalInfo!.complementary),
        if (d.additionalInfo?.taxAuthority != null)
          _text('infAdFisco', d.additionalInfo!.taxAuthority),
        if (d.additionalInfo != null) ...[
          for (final observation in d.additionalInfo!.contributorObservations)
            _observation('obsCont', observation),
          for (final observation in d.additionalInfo!.fiscalObservations)
            _observation('obsFisco', observation),
          for (final process in d.additionalInfo!.referencedProcesses)
            tagprocRef(process),
        ],
      ]);

  XmlElement _observation(String tag, AdditionalObservation observation) =>
      XmlElement(
        XmlName.parts(tag),
        [XmlAttribute(XmlName.parts('xCampo'), observation.field)],
        [_text('xTexto', observation.text)],
      );

  XmlElement _authorizedXml(AuthorizedXmlDownload authorization) =>
      XmlElement(XmlName.parts('autXML'), const [], [
        if (authorization.cnpj != null)
          _text('CNPJ', Tools.onlyDigits(authorization.cnpj!)),
        if (authorization.cpf != null)
          _text('CPF', Tools.onlyDigits(authorization.cpf!)),
      ]);

  XmlElement _exportInfo(ExportInfo info) =>
      XmlElement(XmlName.parts('exporta'), const [], [
        _text('UFSaidaPais', info.departureState),
        _text('xLocExporta', info.exportLocation),
        if (info.dispatchLocation != null)
          _text('xLocDespacho', info.dispatchLocation),
      ]);

  XmlElement _purchaseInfo(PurchaseInfo info) =>
      XmlElement(XmlName.parts('compra'), const [], [
        if (info.commitmentNote != null) _text('xNEmp', info.commitmentNote),
        if (info.order != null) _text('xPed', info.order),
        if (info.contract != null) _text('xCont', info.contract),
      ]);

  XmlElement _sugarcane(SugarcaneInfo info) => XmlElement(
    XmlName.parts('cana'),
    const [],
    [
      _text('safra', info.harvest),
      _text('ref', info.reference),
      for (final supply in info.dailySupplies)
        XmlElement(
          XmlName.parts('forDia'),
          [XmlAttribute(XmlName.parts('dia'), '${supply.day}')],
          [_text('qtde', FiscalDecimal.fromNum(supply.quantity).toFixed(10))],
        ),
      _text('qTotMes', FiscalDecimal.fromNum(info.monthTotal).toFixed(10)),
      _text('qTotAnt', FiscalDecimal.fromNum(info.previousTotal).toFixed(10)),
      _text('qTotGer', FiscalDecimal.fromNum(info.generalTotal).toFixed(10)),
      for (final deduction in info.deductions)
        XmlElement(XmlName.parts('deduc'), const [], [
          _text('xDed', deduction.description),
          _text('vDed', FiscalDecimal.fromNum(deduction.value).toFixed(2)),
        ]),
      _text('vFor', FiscalDecimal.fromNum(info.supplyValue).toFixed(2)),
      _text('vTotDed', FiscalDecimal.fromNum(info.totalDeductions).toFixed(2)),
      _text('vLiqFor', FiscalDecimal.fromNum(info.netSupplyValue).toFixed(2)),
    ],
  );

  XmlElement _text(String name, String? value) => XmlElement(
    XmlName.parts(name),
    const [],
    value == null ? const [] : [XmlText(value)],
  );

  void _validate(NfeDocument d) {
    if (!RegExp(r'^\d{44}$').hasMatch(d.accessKey)) {
      throw const FiscalValidationException(
        'A chave de acesso deve conter 44 dígitos.',
        code: 'INVALID_ACCESS_KEY',
      );
    }
    if (!AccessKey.isValid(d.accessKey)) {
      throw const FiscalValidationException(
        'O dígito verificador da chave de acesso é inválido.',
        code: 'INVALID_ACCESS_KEY_CHECK_DIGIT',
      );
    }
    if (AccessKey.modelOf(d.accessKey) != d.model) {
      throw const FiscalValidationException(
        'O modelo do documento não corresponde ao modelo da chave de acesso.',
        code: 'ACCESS_KEY_MODEL_MISMATCH',
      );
    }
    final emissionType = d.contingency?.mode.code ?? 1;
    if (AccessKey.emissionTypeOf(d.accessKey) != emissionType) {
      throw const FiscalValidationException(
        'O tipo de emissão não corresponde ao tpEmis da chave de acesso.',
        code: 'ACCESS_KEY_EMISSION_MISMATCH',
      );
    }
    final keyTaxId = d.accessKey.substring(6, 20);
    final issuerTaxId = d.issuer.cnpj != null
        ? Tools.onlyDigits(d.issuer.cnpj!)
        : d.issuer.cpf == null
        ? null
        : Tools.onlyDigits(d.issuer.cpf!).padLeft(14, '0');
    if (issuerTaxId == null || issuerTaxId != keyTaxId) {
      throw const FiscalValidationException(
        'O CNPJ/CPF do emitente não corresponde à chave de acesso.',
        code: 'ACCESS_KEY_ISSUER_MISMATCH',
      );
    }
    final keyYearMonth = d.accessKey.substring(2, 6);
    final issueDateUtc = d.issueDate.toUtc();
    final issueYearMonth =
        '${(issueDateUtc.year % 100).toString().padLeft(2, '0')}'
        '${issueDateUtc.month.toString().padLeft(2, '0')}';
    if (keyYearMonth != issueYearMonth) {
      throw const FiscalValidationException(
        'O ano/mês da emissão não corresponde à chave de acesso.',
        code: 'ACCESS_KEY_DATE_MISMATCH',
      );
    }
    if (int.parse(d.accessKey.substring(22, 25)) != d.series ||
        int.parse(d.accessKey.substring(25, 34)) != d.number) {
      throw const FiscalValidationException(
        'A série ou o número não correspondem à chave de acesso.',
        code: 'ACCESS_KEY_NUMBER_MISMATCH',
      );
    }
    if (d.model != 55 && d.model != 65) {
      throw const FiscalValidationException(
        'O modelo deve ser 55 ou 65.',
        code: 'INVALID_MODEL',
      );
    }
    final avulsa = d.avulsa;
    if (avulsa != null) {
      if (!Tools.isValidCnpj(avulsa.cnpj)) {
        throw const FiscalValidationException(
          'O CNPJ da emissão avulsa é inválido.',
          code: 'INVALID_AVULSA_CNPJ',
        );
      }
      if (avulsa.agency.trim().isEmpty ||
          avulsa.registration.trim().isEmpty ||
          avulsa.agent.trim().isEmpty ||
          avulsa.fiscalOffice.trim().isEmpty ||
          !RegExp(r'^[A-Z]{2}$').hasMatch(avulsa.state)) {
        throw const FiscalValidationException(
          'Os campos obrigatórios da emissão avulsa são inválidos.',
          code: 'INVALID_AVULSA_IDENTIFICATION',
        );
      }
      if (avulsa.phone != null &&
          !RegExp(r'^\d{6,14}$').hasMatch(Tools.onlyDigits(avulsa.phone!))) {
        throw const FiscalValidationException(
          'O telefone da emissão avulsa deve possuir de 6 a 14 dígitos.',
          code: 'INVALID_AVULSA_PHONE',
        );
      }
      if (avulsa.revenueDocumentValue != null &&
          (!avulsa.revenueDocumentValue!.isFinite ||
              avulsa.revenueDocumentValue! < 0)) {
        throw const FiscalValidationException(
          'O valor do DAR deve ser finito e não negativo.',
          code: 'INVALID_AVULSA_VALUE',
        );
      }
    }
    final serviceTotal = d.serviceTotal;
    if (serviceTotal != null) {
      final values = [
        serviceTotal.serviceValue,
        serviceTotal.taxBase,
        serviceTotal.taxValue,
        serviceTotal.pis,
        serviceTotal.cofins,
        serviceTotal.deduction,
        serviceTotal.other,
        serviceTotal.unconditionalDiscount,
        serviceTotal.conditionalDiscount,
        serviceTotal.retained,
      ];
      if (values.any((value) => !value.isFinite || value < 0)) {
        throw const FiscalValidationException(
          'Os valores do total ISSQN devem ser finitos e não negativos.',
          code: 'INVALID_SERVICE_TOTAL',
        );
      }
      if (serviceTotal.taxRegime != null &&
          (serviceTotal.taxRegime! < 0 || serviceTotal.taxRegime! > 9)) {
        throw const FiscalValidationException(
          'O regime tributário do total ISSQN deve estar entre 0 e 9.',
          code: 'INVALID_SERVICE_TAX_REGIME',
        );
      }
    }
    final supplement = d.nfceSupplement;
    if (supplement != null) {
      final keyUrl = Uri.tryParse(supplement.keyUrl);
      if (d.model != 65 ||
          supplement.qrCode.trim().isEmpty ||
          keyUrl == null ||
          (keyUrl.scheme != 'http' && keyUrl.scheme != 'https')) {
        throw const FiscalValidationException(
          'O suplemento QR Code só pode ser usado em NFC-e com URL válida.',
          code: 'INVALID_NFCE_SUPPLEMENT',
        );
      }
    }
    final additionalInfo = d.additionalInfo;
    if (additionalInfo != null) {
      for (final observation in [
        ...additionalInfo.contributorObservations,
        ...additionalInfo.fiscalObservations,
      ]) {
        if (observation.field.trim().isEmpty ||
            observation.field.length > 20 ||
            observation.text.trim().isEmpty ||
            observation.text.length > 60) {
          throw const FiscalValidationException(
            'As observações adicionais devem conter campo e texto válidos.',
            code: 'INVALID_ADDITIONAL_OBSERVATION',
          );
        }
      }
      for (final process in additionalInfo.referencedProcesses) {
        if (process.number.trim().isEmpty ||
            process.number.length > 60 ||
            !RegExp(r'^[0-3]$').hasMatch(process.indicator)) {
          throw const FiscalValidationException(
            'O processo referenciado possui campos inválidos.',
            code: 'INVALID_REFERENCED_PROCESS',
          );
        }
      }
      for (final authorization in additionalInfo.authorizedXml) {
        final hasCnpj = authorization.cnpj != null;
        final hasCpf = authorization.cpf != null;
        if (hasCnpj == hasCpf ||
            hasCnpj && !Tools.isValidCnpj(authorization.cnpj!) ||
            hasCpf && !Tools.isValidCpf(authorization.cpf!)) {
          throw const FiscalValidationException(
            'Cada autXML deve conter exatamente um CNPJ ou CPF válido.',
            code: 'INVALID_AUTHORIZED_XML',
          );
        }
      }
    }
    if (d.contingency?.mode == ContingencyMode.offlineNfce && d.model != 65) {
      throw const FiscalValidationException(
        'A contingência offline é exclusiva da NFC-e modelo 65.',
        code: 'OFFLINE_CONTINGENCY_MODEL_MISMATCH',
      );
    }
    if (d.model == 65 &&
        d.contingency != null &&
        d.contingency!.mode != ContingencyMode.offlineNfce) {
      throw const FiscalValidationException(
        'A NFC-e modelo 65 aceita somente contingência offline tpEmis=9.',
        code: 'NFCE_CONTINGENCY_MODE_MISMATCH',
      );
    }
    final contingencyDate = d.contingency?.activatedAt.toUtc();
    final issueDate = d.issueDate.toUtc();
    final contingencyIsOnLaterDate =
        contingencyDate != null &&
        DateTime.utc(
          contingencyDate.year,
          contingencyDate.month,
          contingencyDate.day,
        ).isAfter(DateTime.utc(issueDate.year, issueDate.month, issueDate.day));
    if (contingencyIsOnLaterDate) {
      throw const FiscalValidationException(
        'A ativação da contingência não pode ocorrer depois da emissão.',
        code: 'CONTINGENCY_DATE_AFTER_ISSUE',
      );
    }
    if (d.environment != 1 && d.environment != 2) {
      throw const FiscalValidationException(
        'O ambiente deve ser 1 ou 2.',
        code: 'INVALID_ENVIRONMENT',
      );
    }
    if (d.operationNature != null && d.operationNature!.trim().isEmpty) {
      throw const FiscalValidationException(
        'A natureza da operação não pode ser vazia.',
        code: 'INVALID_OPERATION_NATURE',
      );
    }
    if (d.finalConsumer != null &&
        d.finalConsumer != 0 &&
        d.finalConsumer != 1) {
      throw const FiscalValidationException(
        'O indicador de consumidor final deve ser 0 ou 1.',
        code: 'INVALID_FINAL_CONSUMER',
      );
    }
    if (d.presenceIndicator != null &&
        !const [0, 1, 2, 3, 4, 5, 9].contains(d.presenceIndicator)) {
      throw const FiscalValidationException(
        'O indicador de presença deve estar entre 0 e 5.',
        code: 'INVALID_PRESENCE_INDICATOR',
      );
    }
    if (d.intermediaryIndicator != null &&
        d.intermediaryIndicator != 0 &&
        d.intermediaryIndicator != 1) {
      throw const FiscalValidationException(
        'O indicador de intermediador deve ser 0 ou 1.',
        code: 'INVALID_INTERMEDIARY_INDICATOR',
      );
    }
    if ((d.intermediaryIndicator == 1) != (d.intermediary != null)) {
      throw const FiscalValidationException(
        'indIntermed=1 exige infIntermed e infIntermed só pode ser usado com '
        'indIntermed=1.',
        code: 'INVALID_INTERMEDIARY_DATA',
      );
    }
    final intermediary = d.intermediary;
    if (intermediary != null &&
        (!Tools.isValidCnpj(intermediary.cnpj) ||
            intermediary.identifier.trim().length < 2 ||
            intermediary.identifier.trim().length > 60)) {
      throw const FiscalValidationException(
        'Os dados do intermediador da transação são inválidos.',
        code: 'INVALID_INTERMEDIARY_DATA',
      );
    }
    if (d.operationLocationCode != null &&
        !RegExp(r'^\d{6}$').hasMatch(d.operationLocationCode!)) {
      throw const FiscalValidationException(
        'O código do local da operação deve possuir seis dígitos.',
        code: 'INVALID_OPERATION_LOCATION_CODE',
      );
    }
    if (d.advancePaymentReferences.length > 99 ||
        d.advancePaymentReferences.any(
          (reference) => !AccessKey.isValid(reference),
        )) {
      throw const FiscalValidationException(
        'As referências de pagamento antecipado devem conter até 99 chaves '
        'de acesso válidas.',
        code: 'INVALID_ADVANCE_PAYMENT_REFERENCES',
      );
    }
    final governmentPurchase = d.governmentPurchase;
    if (governmentPurchase != null) {
      final references = governmentPurchase.previousDocumentReferences;
      final type = governmentPurchase.operationType;
      final referencesRequired = type == 2 || type == 3;
      final referencesForbidden = type == 1 || type == 4;
      if (governmentPurchase.governmentEntityType < 1 ||
          governmentPurchase.governmentEntityType > 6 ||
          governmentPurchase.reductionPercentage < 0 ||
          governmentPurchase.reductionPercentage > 100 ||
          type < 1 ||
          type > 4 ||
          references.length > 99 ||
          references.any((reference) => !AccessKey.isValid(reference)) ||
          (referencesRequired && references.isEmpty) ||
          (referencesForbidden && references.isNotEmpty) ||
          (type == 2 && references.length > 1)) {
        throw const FiscalValidationException(
          'Os dados de gCompraGov/refDFeAnt são incompatíveis com o leiaute.',
          code: 'INVALID_GOVERNMENT_PURCHASE',
        );
      }
    }
    if (d.documentType != null && d.documentType != 0 && d.documentType != 1) {
      throw const FiscalValidationException(
        'O tipo da operação deve ser 0 ou 1.',
        code: 'INVALID_DOCUMENT_TYPE',
      );
    }
    if (d.destinationType != null &&
        !const [1, 2, 3].contains(d.destinationType)) {
      throw const FiscalValidationException(
        'O destino da operação deve ser 1, 2 ou 3.',
        code: 'INVALID_DESTINATION_TYPE',
      );
    }
    if (d.municipalityCode != null &&
        !RegExp(r'^\d{7}$').hasMatch(d.municipalityCode!)) {
      throw const FiscalValidationException(
        'O município do fato gerador deve possuir sete dígitos.',
        code: 'INVALID_MUNICIPALITY_CODE',
      );
    }
    if (d.ibsMunicipalityCode != null &&
        !RegExp(r'^\d{7}$').hasMatch(d.ibsMunicipalityCode!)) {
      throw const FiscalValidationException(
        'O município do fato gerador de IBS/CBS deve possuir sete dígitos.',
        code: 'INVALID_IBS_MUNICIPALITY_CODE',
      );
    }
    if (d.printFormat != null && (d.printFormat! < 0 || d.printFormat! > 5)) {
      throw const FiscalValidationException(
        'O formato de impressão deve estar entre 0 e 5.',
        code: 'INVALID_PRINT_FORMAT',
      );
    }
    if (d.purpose != null && (d.purpose! < 1 || d.purpose! > 6)) {
      throw const FiscalValidationException(
        'A finalidade da emissão deve estar entre 1 e 6.',
        code: 'INVALID_PURPOSE',
      );
    }
    if (d.debitNoteType != null &&
        !const [
          '01',
          '02',
          '03',
          '04',
          '05',
          '06',
          '07',
          '08',
        ].contains(d.debitNoteType)) {
      throw const FiscalValidationException(
        'O tipo da nota de débito deve estar entre 01 e 08.',
        code: 'INVALID_DEBIT_NOTE_TYPE',
      );
    }
    if (d.creditNoteType != null &&
        !const [
          '01',
          '02',
          '03',
          '04',
          '05',
          '06',
        ].contains(d.creditNoteType)) {
      throw const FiscalValidationException(
        'O tipo da nota de crédito deve estar entre 01 e 06.',
        code: 'INVALID_CREDIT_NOTE_TYPE',
      );
    }
    if (d.processCode != null && !RegExp(r'^[0-4]$').hasMatch(d.processCode!)) {
      throw const FiscalValidationException(
        'O processo de emissão deve estar entre 0 e 4.',
        code: 'INVALID_PROCESS_CODE',
      );
    }
    if (d.applicationVersion != null &&
        (d.applicationVersion!.trim().isEmpty ||
            d.applicationVersion!.length > 20)) {
      throw const FiscalValidationException(
        'A versão do aplicativo emissor deve ter de 1 a 20 caracteres.',
        code: 'INVALID_APPLICATION_VERSION',
      );
    }
    final exportInfo = d.exportInfo;
    if (exportInfo != null &&
        (!RegExp(r'^[A-Z]{2}$').hasMatch(exportInfo.departureState) ||
            exportInfo.exportLocation.trim().isEmpty ||
            exportInfo.exportLocation.length > 60 ||
            exportInfo.dispatchLocation != null &&
                (exportInfo.dispatchLocation!.trim().isEmpty ||
                    exportInfo.dispatchLocation!.length > 60))) {
      throw const FiscalValidationException(
        'Os dados de exportação do documento são inválidos.',
        code: 'INVALID_EXPORT_INFO',
      );
    }
    final purchaseInfo = d.purchaseInfo;
    if (purchaseInfo != null &&
            [
              purchaseInfo.commitmentNote,
              purchaseInfo.order,
              purchaseInfo.contract,
            ].every((value) => value == null) ||
        purchaseInfo != null &&
            [
              purchaseInfo.commitmentNote,
              purchaseInfo.order,
              purchaseInfo.contract,
            ].any((value) => value != null && value.trim().isEmpty)) {
      throw const FiscalValidationException(
        'As informações de compra devem conter ao menos um valor não vazio.',
        code: 'INVALID_PURCHASE_INFO',
      );
    }
    final sugarcane = d.sugarcane;
    if (sugarcane != null &&
        (sugarcane.harvest.length < 4 ||
            sugarcane.harvest.length > 9 ||
            !RegExp(
              r'^(0[1-9]|1[0-2])/2\d{3}$',
            ).hasMatch(sugarcane.reference) ||
            sugarcane.dailySupplies.length > 31 ||
            sugarcane.dailySupplies.any(
              (supply) =>
                  supply.day < 1 || supply.day > 31 || supply.quantity < 0,
            ) ||
            sugarcane.deductions.length > 10 ||
            sugarcane.deductions.any(
              (deduction) =>
                  deduction.description.trim().isEmpty ||
                  deduction.description.length > 60 ||
                  deduction.value < 0,
            ) ||
            sugarcane.monthTotal < 0 ||
            sugarcane.previousTotal < 0 ||
            sugarcane.generalTotal < 0 ||
            sugarcane.supplyValue < 0 ||
            sugarcane.totalDeductions < 0 ||
            sugarcane.netSupplyValue < 0)) {
      throw const FiscalValidationException(
        'Os dados de aquisição de cana são inválidos.',
        code: 'INVALID_SUGARCANE_INFO',
      );
    }
    if (d.items.isEmpty) {
      throw const FiscalValidationException(
        'O documento deve possuir ao menos um item.',
        code: 'EMPTY_ITEMS',
      );
    }
    for (final reference in d.references) {
      if (reference.ecfModel != null) {
        if (reference.ecfModel!.trim().isEmpty ||
            reference.ecfNumber == null ||
            reference.ecfNumber! < 0 ||
            reference.ecfNumber! > 999 ||
            reference.cooNumber == null ||
            reference.cooNumber! < 0 ||
            reference.cooNumber! > 999999) {
          throw const FiscalValidationException(
            'Os campos do cupom fiscal ECF referenciado são inválidos.',
            code: 'INVALID_REFERENCED_ECF',
          );
        }
      } else if (reference.producerIe != null) {
        final hasCnpj = reference.cnpj != null;
        final hasCpf = reference.cpf != null;
        if (reference.cUf == null ||
            !RegExp(r'^\d{2}$').hasMatch(reference.cUf!) ||
            reference.yearMonth == null ||
            !RegExp(r'^\d{4}$').hasMatch(reference.yearMonth!) ||
            hasCnpj == hasCpf ||
            hasCnpj && !Tools.isValidCnpj(reference.cnpj!) ||
            hasCpf && !Tools.isValidCpf(reference.cpf!) ||
            reference.producerIe!.trim().isEmpty ||
            reference.producerIe!.length > 14 ||
            reference.model == null ||
            reference.model! < 1 ||
            reference.model! > 99 ||
            reference.series == null ||
            reference.series! < 0 ||
            reference.series! > 999 ||
            reference.number == null ||
            reference.number! < 1) {
          throw const FiscalValidationException(
            'Os campos da nota de produtor rural referenciada são inválidos.',
            code: 'INVALID_REFERENCED_PRODUCER_DOCUMENT',
          );
        }
      } else if (reference.accessKey != null ||
          reference.signedNfeKey != null ||
          reference.cteKey != null) {
        final key =
            reference.accessKey ?? reference.signedNfeKey ?? reference.cteKey!;
        if (!AccessKey.isValid(key)) {
          throw const FiscalValidationException(
            'A chave do documento referenciado é inválida.',
            code: 'INVALID_REFERENCED_ACCESS_KEY',
          );
        }
      } else if (reference.cUf == null ||
          !RegExp(r'^\d{2}$').hasMatch(reference.cUf!) ||
          reference.yearMonth == null ||
          !RegExp(r'^\d{4}$').hasMatch(reference.yearMonth!) ||
          reference.cnpj == null ||
          !Tools.isValidCnpj(reference.cnpj!) ||
          reference.model == null ||
          (reference.model != 1 && reference.model != 2) ||
          reference.series == null ||
          reference.series! < 0 ||
          reference.series! > 999 ||
          reference.number == null ||
          reference.number! < 1) {
        throw const FiscalValidationException(
          'Os campos do documento legado referenciado são inválidos.',
          code: 'INVALID_REFERENCED_DOCUMENT',
        );
      }
    }
    final billing = d.billing;
    if (billing != null) {
      if (billing.invoiceNumber.trim().isEmpty ||
          billing.originalValue < 0 ||
          billing.discount < 0 ||
          billing.discount > billing.originalValue ||
          billing.installments.any(
            (item) => item.number.trim().isEmpty || item.value < 0,
          )) {
        throw const FiscalValidationException(
          'Os valores da cobrança/fatura são inválidos.',
          code: 'INVALID_BILLING',
        );
      }
      final installments = billing.installments.fold(
        FiscalDecimal.parse('0'),
        (sum, item) => sum + FiscalDecimal.fromNum(item.value),
      );
      if (billing.installments.isNotEmpty &&
          installments.toFixed(2) !=
              FiscalDecimal.fromNum(billing.netValue).toFixed(2)) {
        throw const FiscalValidationException(
          'A soma das duplicatas deve corresponder ao valor líquido da fatura.',
          code: 'BILLING_INSTALLMENTS_MISMATCH',
        );
      }
    }
    final technical = d.technicalResponsible;
    if (technical != null &&
        (!Tools.isValidCnpj(technical.cnpj) ||
            technical.contact.trim().isEmpty ||
            technical.email.trim().isEmpty ||
            technical.phone.trim().isEmpty ||
            technical.csrt != null && technical.csrtId == null ||
            technical.csrt == null && technical.csrtId != null)) {
      throw const FiscalValidationException(
        'Os dados do responsável técnico são inválidos.',
        code: 'INVALID_TECHNICAL_RESPONSIBLE',
      );
    }
    _validateParty(d.issuer, 'emitente');
    if (d.recipient != null) {
      _validateParty(d.recipient!, 'destinatário');
    }
    if (d.withdrawal != null) {
      _validateLocation(d.withdrawal!, 'retirada');
    }
    if (d.delivery != null) {
      _validateLocation(d.delivery!, 'entrega');
    }
    if (d.payments.any((payment) => payment.value < 0)) {
      throw const FiscalValidationException(
        'O valor do pagamento não pode ser negativo.',
        code: 'INVALID_PAYMENT_VALUE',
      );
    }
    for (final payment in d.payments) {
      if (!RegExp(r'^\d{2}$').hasMatch(payment.type) ||
          (payment.indicator != 0 && payment.indicator != 1) ||
          (payment.integration != null &&
              payment.integration != 1 &&
              payment.integration != 2) ||
          (payment.brand != null &&
              !RegExp(r'^\d{2}$').hasMatch(payment.brand!)) ||
          (payment.authorization != null &&
              (payment.authorization!.trim().isEmpty ||
                  payment.authorization!.length > 128)) ||
          (payment.description != null &&
              (payment.description!.length < 2 ||
                  payment.description!.length > 60))) {
        throw const FiscalValidationException(
          'Os dados do pagamento são inválidos.',
          code: 'INVALID_PAYMENT_DETAILS',
        );
      }
      if ((payment.brand != null || payment.authorization != null) &&
          payment.integration == null) {
        throw const FiscalValidationException(
          'Pagamento eletrônico deve informar tpIntegra.',
          code: 'MISSING_PAYMENT_INTEGRATION',
        );
      }
    }
    if (d.changeValue != null && d.changeValue! < 0) {
      throw const FiscalValidationException(
        'O troco não pode ser negativo.',
        code: 'INVALID_CHANGE_VALUE',
      );
    }
    if (d.payments.isNotEmpty &&
        (d.paymentTotalDecimal - FiscalDecimal.fromNum(d.changeValue ?? 0))
                .toFixed(2) !=
            d.totalDecimal.toFixed(2)) {
      throw const FiscalValidationException(
        'A soma dos pagamentos deve ser igual ao total do documento.',
        code: 'PAYMENT_TOTAL_MISMATCH',
      );
    }
    final itemNumbers = <int>{};
    for (final item in d.items) {
      if (item.number < 1 ||
          !itemNumbers.add(item.number) ||
          item.code.trim().isEmpty ||
          item.description.trim().isEmpty ||
          item.unit.trim().isEmpty) {
        throw const FiscalValidationException(
          'Número, código, descrição e unidade são obrigatórios no item; '
          'o número do item também deve ser único.',
          code: 'INVALID_ITEM_IDENTIFICATION',
        );
      }
      if (!RegExp(r'^\d{8}$').hasMatch(item.ncm) ||
          !RegExp(r'^\d{4}$').hasMatch(item.cfop)) {
        throw const FiscalValidationException(
          'NCM deve ter 8 dígitos e CFOP deve ter 4 dígitos.',
          code: 'INVALID_ITEM_CLASSIFICATION',
        );
      }
      if (item.nve.any((value) => value.trim().isEmpty || value.length > 6)) {
        throw const FiscalValidationException(
          'Cada NVE deve possuir de 1 a 6 caracteres.',
          code: 'INVALID_NVE',
        );
      }
      if (item.cest != null && !RegExp(r'^\d{7}$').hasMatch(item.cest!)) {
        throw const FiscalValidationException(
          'O CEST deve possuir sete dígitos.',
          code: 'INVALID_CEST',
        );
      }
      if (item.barcode != null &&
          (item.barcode!.length < 3 || item.barcode!.length > 30)) {
        throw const FiscalValidationException(
          'O código de barras comercial deve possuir de 3 a 30 caracteres.',
          code: 'INVALID_BARCODE',
        );
      }
      if (item.taxableBarcode != null &&
          (item.taxableBarcode!.length < 3 ||
              item.taxableBarcode!.length > 30)) {
        throw const FiscalValidationException(
          'O código de barras tributável deve possuir de 3 a 30 caracteres.',
          code: 'INVALID_TAXABLE_BARCODE',
        );
      }
      if (item.scaleIndicator != null &&
          !const ['S', 'N'].contains(item.scaleIndicator)) {
        throw const FiscalValidationException(
          'O indicador de escala deve ser S ou N.',
          code: 'INVALID_SCALE_INDICATOR',
        );
      }
      if ((item.scaleIndicator != null || item.manufacturerCnpj != null) &&
          item.cest == null) {
        throw const FiscalValidationException(
          'indEscala/CNPJFab exigem CEST no grupo do produto.',
          code: 'SCALE_FIELDS_WITHOUT_CEST',
        );
      }
      if (item.manufacturerCnpj != null &&
          !Tools.isValidCnpj(item.manufacturerCnpj!)) {
        throw const FiscalValidationException(
          'O CNPJ do fabricante é inválido.',
          code: 'INVALID_MANUFACTURER_CNPJ',
        );
      }
      if (item.recopiNumber != null &&
          !RegExp(r'^\d{20}$').hasMatch(item.recopiNumber!)) {
        throw const FiscalValidationException(
          'O número RECOPI deve possuir exatamente 20 dígitos.',
          code: 'INVALID_RECOPI_NUMBER',
        );
      }
      if (item.fciNumber != null &&
          !RegExp(
            r'^[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}$',
          ).hasMatch(item.fciNumber!)) {
        throw const FiscalValidationException(
          'O número FCI deve estar no formato GUID hexadecimal em maiúsculas.',
          code: 'INVALID_FCI_NUMBER',
        );
      }
      if (item.nffProduct != null &&
          (item.nffProduct!.fiscalProductCode.length != 14 ||
              !RegExp(r'^\d{1,5}$').hasMatch(item.nffProduct!.operationCode))) {
        throw const FiscalValidationException(
          'As informações NFF do produto são inválidas.',
          code: 'INVALID_NFF_PRODUCT_INFO',
        );
      }
      if (item.embeddedProduct != null &&
          (item.embeddedProduct!.description.isEmpty ||
              item.embeddedProduct!.description.length > 8 ||
              item.embeddedProduct!.unit.isEmpty ||
              item.embeddedProduct!.unit.length > 8 ||
              item.embeddedProduct!.quantity < 0 ||
              !item.embeddedProduct!.quantity.isFinite)) {
        throw const FiscalValidationException(
          'As informações de embalagem do produto são inválidas.',
          code: 'INVALID_EMBEDDED_PRODUCT_INFO',
        );
      }
      if (item.benefitCode != null &&
          (item.benefitCode!.trim().isEmpty || item.benefitCode!.length > 20)) {
        throw const FiscalValidationException(
          'O código de benefício fiscal é inválido.',
          code: 'INVALID_BENEFIT_CODE',
        );
      }
      if (item.presumedCredits.length > 4 ||
          item.presumedCredits.any(
            (credit) =>
                !RegExp(r'^[!-ÿ]{8}$|^[!-ÿ]{10}$').hasMatch(credit.code) ||
                credit.rate < 0 ||
                credit.value < 0,
          )) {
        throw const FiscalValidationException(
          'Os créditos presumidos do item são inválidos.',
          code: 'INVALID_PRESUMED_CREDIT',
        );
      }
      if (item.zfmCreditType != null &&
          !const ['0', '1', '2', '3', '4'].contains(item.zfmCreditType)) {
        throw const FiscalValidationException(
          'A classificação do crédito presumido IBS na ZFM é inválida.',
          code: 'INVALID_ZFM_CREDIT_TYPE',
        );
      }
      if (item.extipi != null && !RegExp(r'^\d{3}$').hasMatch(item.extipi!)) {
        throw const FiscalValidationException(
          'O EXTIPI deve possuir três dígitos.',
          code: 'INVALID_EXTIPI',
        );
      }
      if (item.orderItem != null &&
          (item.orderItem! < 1 || item.orderItem! > 999999)) {
        throw const FiscalValidationException(
          'O item do pedido de compra deve ser positivo.',
          code: 'INVALID_ORDER_ITEM',
        );
      }
      if (item.importDeclarations.isNotEmpty && d.model != 55) {
        throw const FiscalValidationException(
          'Declaração de importação só pode ser informada em NF-e modelo 55.',
          code: 'IMPORT_DECLARATION_MODEL_MISMATCH',
        );
      }
      for (final declaration in item.importDeclarations) {
        if (declaration.number.trim().isEmpty ||
            declaration.customsLocation.trim().isEmpty ||
            !RegExp(r'^[A-Z]{2}$').hasMatch(declaration.customsState) ||
            declaration.exporterCode.trim().isEmpty ||
            declaration.transportMode < 1 ||
            declaration.transportMode > 9 ||
            declaration.intermediaryType < 1 ||
            declaration.intermediaryType > 3 ||
            (declaration.afrmm != null && declaration.afrmm! < 0) ||
            (declaration.importerCnpj != null &&
                !Tools.isValidCnpj(declaration.importerCnpj!)) ||
            (declaration.thirdPartyState != null &&
                !RegExp(
                  r'^[A-Z]{2}$',
                ).hasMatch(declaration.thirdPartyState!))) {
          throw const FiscalValidationException(
            'Os dados da declaração de importação são inválidos.',
            code: 'INVALID_IMPORT_DECLARATION',
          );
        }
        for (final addition in declaration.additions) {
          if (addition.number < 1 ||
              addition.sequence < 1 ||
              addition.manufacturerCode.trim().isEmpty ||
              addition.discount < 0) {
            throw const FiscalValidationException(
              'Os dados da adição da importação são inválidos.',
              code: 'INVALID_IMPORT_ADDITION',
            );
          }
        }
      }
      for (final detail in item.exportDetails) {
        if ((detail.drawbackNumber == null ||
                detail.drawbackNumber!.trim().isEmpty) &&
            detail.individualExports.isEmpty) {
          throw const FiscalValidationException(
            'O detalhe de exportação deve informar drawback ou exportação individual.',
            code: 'INVALID_EXPORT_DETAIL',
          );
        }
        for (final export in detail.individualExports) {
          if (!RegExp(r'^\d+$').hasMatch(export.registrationNumber) ||
              !AccessKey.isValid(export.receivedInvoiceKey) ||
              export.exportedQuantity <= 0) {
            throw const FiscalValidationException(
              'Os dados da exportação individual são inválidos.',
              code: 'INVALID_INDIVIDUAL_EXPORT',
            );
          }
        }
      }
      for (final batch in item.traceability) {
        if (batch.batchNumber.trim().isEmpty ||
            batch.batchNumber.length > 20 ||
            batch.quantity <= 0 ||
            batch.aggregatedCode != null &&
                (batch.aggregatedCode!.trim().isEmpty ||
                    batch.aggregatedCode!.length > 20) ||
            batch.expiresAt.isBefore(batch.manufacturedAt)) {
          throw const FiscalValidationException(
            'Os dados de rastreabilidade do lote são inválidos.',
            code: 'INVALID_PRODUCT_TRACEABILITY',
          );
        }
      }
      final medication = item.medication;
      final specialProductGroups = [
        if (item.newVehicle != null) 'veicProd',
        if (item.weapons.isNotEmpty) 'arma',
        if (medication != null) 'med',
        if (item.fuel != null) 'comb',
      ];
      if (specialProductGroups.length > 1) {
        throw const FiscalValidationException(
          'Os grupos especiais veicProd, arma, med e comb são mutuamente exclusivos por item.',
          code: 'CONFLICTING_PRODUCT_SPECIAL_GROUPS',
        );
      }
      if (medication != null &&
          (!RegExp(
                r'^(?:\d{11}|\d{13}|ISENTO)$',
              ).hasMatch(medication.anvisaProductCode) ||
              medication.maximumConsumerPrice < 0 ||
              (medication.exemptionReason != null &&
                  (medication.exemptionReason!.trim().isEmpty ||
                      medication.exemptionReason!.length > 255)))) {
        throw const FiscalValidationException(
          'Os dados do medicamento/ANVISA são inválidos.',
          code: 'INVALID_MEDICATION',
        );
      }
      final fuel = item.fuel;
      if (fuel != null) {
        bool invalidPercentage(double? value) =>
            value != null && (value < 0 || value > 100);
        if (!RegExp(r'^\d{9}$').hasMatch(fuel.anpProductCode) ||
            fuel.anpDescription.trim().length < 2 ||
            fuel.anpDescription.length > 95 ||
            !RegExp(r'^[A-Z]{2}$').hasMatch(fuel.consumptionState) ||
            invalidPercentage(fuel.glpPetroleumPercentage) ||
            invalidPercentage(fuel.nationalNaturalGasPercentage) ||
            invalidPercentage(fuel.importedNaturalGasPercentage) ||
            invalidPercentage(fuel.biofuelPercentage) ||
            (fuel.startingValue != null && fuel.startingValue! < 0) ||
            (fuel.temperatureQuantity != null &&
                fuel.temperatureQuantity! < 0) ||
            fuel.origins.length > 30 ||
            fuel.origins.any(
              (origin) =>
                  !RegExp(r'^\d{2}$').hasMatch(origin.originState) ||
                  origin.percentage < 0 ||
                  origin.percentage > 100,
            )) {
          throw const FiscalValidationException(
            'Os dados do combustível/ANP são inválidos.',
            code: 'INVALID_FUEL_DETAILS',
          );
        }
        final cide = fuel.cide;
        if (cide != null &&
            (cide.quantityBase < 0 || cide.rate < 0 || cide.value < 0)) {
          throw const FiscalValidationException(
            'Os valores da CIDE não podem ser negativos.',
            code: 'INVALID_FUEL_CIDE',
          );
        }
        final gauge = fuel.gauge;
        if (gauge != null &&
            (gauge.nozzle < 1 ||
                gauge.tank < 1 ||
                gauge.pump != null && gauge.pump! < 1 ||
                gauge.initialReading < 0 ||
                gauge.finalReading < gauge.initialReading)) {
          throw const FiscalValidationException(
            'Os dados do encerrante são inválidos.',
            code: 'INVALID_FUEL_GAUGE',
          );
        }
      }
      final vehicle = item.newVehicle;
      if (vehicle != null &&
          (vehicle.operationType < 0 ||
              vehicle.operationType > 3 ||
              !RegExp(r'^[A-Z0-9]{17}$').hasMatch(vehicle.chassis) ||
              vehicle.colorCode.isEmpty ||
              vehicle.colorCode.length > 4 ||
              vehicle.colorDescription.isEmpty ||
              vehicle.colorDescription.length > 40 ||
              vehicle.power.isEmpty ||
              vehicle.power.length > 4 ||
              vehicle.engineCapacity.isEmpty ||
              vehicle.engineCapacity.length > 4 ||
              vehicle.netWeight.isEmpty ||
              vehicle.netWeight.length > 9 ||
              vehicle.grossWeight.isEmpty ||
              vehicle.grossWeight.length > 9 ||
              vehicle.serialNumber.isEmpty ||
              vehicle.serialNumber.length > 9 ||
              vehicle.fuelType.isEmpty ||
              vehicle.fuelType.length > 2 ||
              vehicle.engineNumber.isEmpty ||
              vehicle.engineNumber.length > 21 ||
              vehicle.maxTractionCapacity.isEmpty ||
              vehicle.maxTractionCapacity.length > 9 ||
              vehicle.wheelbase.isEmpty ||
              vehicle.wheelbase.length > 4 ||
              vehicle.modelYear < 1900 ||
              vehicle.modelYear > 2999 ||
              vehicle.manufactureYear < 1900 ||
              vehicle.manufactureYear > 2999 ||
              vehicle.paintType.length != 1 ||
              vehicle.vehicleType < 0 ||
              vehicle.vehicleType > 99 ||
              vehicle.vehicleSpecies < 0 ||
              vehicle.vehicleSpecies > 9 ||
              !const ['R', 'N'].contains(vehicle.vinStatus) ||
              !const [1, 2, 3].contains(vehicle.vehicleCondition) ||
              vehicle.brandModelCode < 0 ||
              vehicle.brandModelCode > 999999 ||
              vehicle.denatranColorCode < 0 ||
              vehicle.denatranColorCode > 99 ||
              vehicle.seatingCapacity < 0 ||
              vehicle.seatingCapacity > 999 ||
              !const [0, 1, 2, 3, 4, 9].contains(vehicle.restrictionType))) {
        throw const FiscalValidationException(
          'Os dados do veículo novo são inválidos.',
          code: 'INVALID_NEW_VEHICLE_DETAILS',
        );
      }
      for (final weapon in item.weapons) {
        if (!const [0, 1].contains(weapon.type) ||
            weapon.serialNumber.trim().isEmpty ||
            weapon.serialNumber.length > 15 ||
            weapon.barrelNumber.trim().isEmpty ||
            weapon.barrelNumber.length > 15 ||
            weapon.description.trim().isEmpty ||
            weapon.description.length > 256) {
          throw const FiscalValidationException(
            'Os dados do armamento são inválidos.',
            code: 'INVALID_WEAPON_DETAILS',
          );
        }
      }
      if (!item.quantity.isFinite ||
          !item.unitPrice.isFinite ||
          item.quantity <= 0 ||
          item.unitPrice < 0) {
        throw const FiscalValidationException(
          'Quantidade deve ser positiva e preço não pode ser negativo.',
          code: 'INVALID_ITEM_VALUE',
        );
      }
      if (item.ean != null) {
        Gtin.assertValid(item.ean!);
      }
      if (item.eanTrib != null) {
        Gtin.assertValid(item.eanTrib!);
      }
      if (!(item.tribQuantity ?? item.quantity).isFinite ||
          !(item.tribUnitPrice ?? item.unitPrice).isFinite ||
          (item.tribQuantity ?? item.quantity) <= 0 ||
          (item.tribUnitPrice ?? item.unitPrice) < 0 ||
          (item.tribUnit?.trim().isEmpty ?? false)) {
        throw const FiscalValidationException(
          'Quantidade, preço e unidade tributáveis são inválidos.',
          code: 'INVALID_TRIBUTARY_MEASURE',
        );
      }
      final values = <num>[
        if (item.approximateTaxValue != null) item.approximateTaxValue!,
        item.freight,
        item.insurance,
        item.discount,
        item.other,
        item.importDuty,
        if (item.icms != null) ...[
          item.icms!.base,
          item.icms!.rate,
          item.icms!.value,
          if (item.icms!.reduction != null) item.icms!.reduction!,
          if (item.icms!.desonerationValue != null)
            item.icms!.desonerationValue!,
          if (item.icms!.operationValue != null) item.icms!.operationValue!,
          if (item.icms!.differenceRate != null) item.icms!.differenceRate!,
          if (item.icms!.differenceValue != null) item.icms!.differenceValue!,
          if (item.icms!.retainedBase != null) item.icms!.retainedBase!,
          if (item.icms!.retainedRate != null) item.icms!.retainedRate!,
          if (item.icms!.retainedValue != null) item.icms!.retainedValue!,
          if (item.icms!.fcpBase != null) item.icms!.fcpBase!,
          if (item.icms!.fcpRate != null) item.icms!.fcpRate!,
          if (item.icms!.fcpValue != null) item.icms!.fcpValue!,
        ],
        if (item.icmsSt != null) ...[
          item.icmsSt!.base,
          item.icmsSt!.rate,
          item.icmsSt!.value,
          item.icmsSt!.stBase,
          item.icmsSt!.stRate,
          item.icmsSt!.stValue,
          if (item.icmsSt!.mva != null) item.icmsSt!.mva!,
          if (item.icmsSt!.reduction != null) item.icmsSt!.reduction!,
          if (item.icmsSt!.fcpBase != null) item.icmsSt!.fcpBase!,
          if (item.icmsSt!.fcpRate != null) item.icmsSt!.fcpRate!,
          if (item.icmsSt!.fcpValue != null) item.icmsSt!.fcpValue!,
          if (item.icmsSt!.fcpStBase != null) item.icmsSt!.fcpStBase!,
          if (item.icmsSt!.fcpStRate != null) item.icmsSt!.fcpStRate!,
          if (item.icmsSt!.fcpStValue != null) item.icmsSt!.fcpStValue!,
        ],
        if (item.icmsSimples != null) ...[
          if (item.icmsSimples!.creditRate != null)
            item.icmsSimples!.creditRate!,
          if (item.icmsSimples!.creditValue != null)
            item.icmsSimples!.creditValue!,
          if (item.icmsSimples!.mva != null) item.icmsSimples!.mva!,
          if (item.icmsSimples!.reduction != null) item.icmsSimples!.reduction!,
          if (item.icmsSimples!.base != null) item.icmsSimples!.base!,
          if (item.icmsSimples!.rate != null) item.icmsSimples!.rate!,
          if (item.icmsSimples!.value != null) item.icmsSimples!.value!,
          if (item.icmsSimples!.stBase != null) item.icmsSimples!.stBase!,
          if (item.icmsSimples!.stRate != null) item.icmsSimples!.stRate!,
          if (item.icmsSimples!.stValue != null) item.icmsSimples!.stValue!,
          if (item.icmsSimples!.retainedBase != null)
            item.icmsSimples!.retainedBase!,
          if (item.icmsSimples!.retainedRate != null)
            item.icmsSimples!.retainedRate!,
          if (item.icmsSimples!.retainedValue != null)
            item.icmsSimples!.retainedValue!,
          if (item.icmsSimples!.fcpStBase != null) item.icmsSimples!.fcpStBase!,
          if (item.icmsSimples!.fcpStRate != null) item.icmsSimples!.fcpStRate!,
          if (item.icmsSimples!.fcpStValue != null)
            item.icmsSimples!.fcpStValue!,
        ],
        if (item.icmsMonophase != null) ...[
          if (item.icmsMonophase!.quantity != null)
            item.icmsMonophase!.quantity!,
          if (item.icmsMonophase!.rate != null) item.icmsMonophase!.rate!,
          if (item.icmsMonophase!.value != null) item.icmsMonophase!.value!,
          if (item.icmsMonophase!.retainedQuantity != null)
            item.icmsMonophase!.retainedQuantity!,
          if (item.icmsMonophase!.retainedRate != null)
            item.icmsMonophase!.retainedRate!,
          if (item.icmsMonophase!.retainedValue != null)
            item.icmsMonophase!.retainedValue!,
          if (item.icmsMonophase!.operationValue != null)
            item.icmsMonophase!.operationValue!,
          if (item.icmsMonophase!.differenceRate != null)
            item.icmsMonophase!.differenceRate!,
          if (item.icmsMonophase!.differenceValue != null)
            item.icmsMonophase!.differenceValue!,
          if (item.icmsMonophase!.differenceQuantity != null)
            item.icmsMonophase!.differenceQuantity!,
          if (item.icmsMonophase!.differenceAdRemRate != null)
            item.icmsMonophase!.differenceAdRemRate!,
          if (item.icmsMonophase!.reductionRate != null)
            item.icmsMonophase!.reductionRate!,
        ],
        if (item.ipi != null) ...[
          item.ipi!.base,
          item.ipi!.rate,
          item.ipi!.value,
        ],
        if (item.pis != null) ...[
          if (item.pis!.base != null) item.pis!.base!,
          if (item.pis!.rate != null) item.pis!.rate!,
          if (item.pis!.value != null) item.pis!.value!,
          if (item.pis!.quantity != null) item.pis!.quantity!,
          if (item.pis!.unitRate != null) item.pis!.unitRate!,
        ],
        if (item.cofins != null) ...[
          if (item.cofins!.base != null) item.cofins!.base!,
          if (item.cofins!.rate != null) item.cofins!.rate!,
          if (item.cofins!.value != null) item.cofins!.value!,
          if (item.cofins!.quantity != null) item.cofins!.quantity!,
          if (item.cofins!.unitRate != null) item.cofins!.unitRate!,
        ],
        if (item.serviceTax != null) ...[
          item.serviceTax!.base,
          item.serviceTax!.rate,
          item.serviceTax!.value,
          item.serviceTax!.deduction,
          item.serviceTax!.other,
          item.serviceTax!.unconditionalDiscount,
          item.serviceTax!.conditionalDiscount,
          item.serviceTax!.retained,
        ],
        if (item.ibsCbs != null) ...[
          item.ibsCbs!.base,
          item.ibsCbs!.ibsUfRate,
          item.ibsCbs!.ibsMunicipalRate,
          item.ibsCbs!.cbsRate,
          if (item.ibsCbs!.ibsUfDeferral != null) ...[
            item.ibsCbs!.ibsUfDeferral!.rate,
            item.ibsCbs!.ibsUfDeferral!.value,
          ],
          if (item.ibsCbs!.ibsUfRefund != null) ...[
            if (item.ibsCbs!.ibsUfRefund!.rate != null)
              item.ibsCbs!.ibsUfRefund!.rate!,
            item.ibsCbs!.ibsUfRefund!.value,
          ],
          if (item.ibsCbs!.ibsUfReduction != null) ...[
            item.ibsCbs!.ibsUfReduction!.rate,
            item.ibsCbs!.ibsUfReduction!.effectiveRate,
          ],
          if (item.ibsCbs!.ibsMunicipalDeferral != null) ...[
            item.ibsCbs!.ibsMunicipalDeferral!.rate,
            item.ibsCbs!.ibsMunicipalDeferral!.value,
          ],
          if (item.ibsCbs!.ibsMunicipalRefund != null) ...[
            if (item.ibsCbs!.ibsMunicipalRefund!.rate != null)
              item.ibsCbs!.ibsMunicipalRefund!.rate!,
            item.ibsCbs!.ibsMunicipalRefund!.value,
          ],
          if (item.ibsCbs!.ibsMunicipalReduction != null) ...[
            item.ibsCbs!.ibsMunicipalReduction!.rate,
            item.ibsCbs!.ibsMunicipalReduction!.effectiveRate,
          ],
          if (item.ibsCbs!.cbsDeferral != null) ...[
            item.ibsCbs!.cbsDeferral!.rate,
            item.ibsCbs!.cbsDeferral!.value,
          ],
          if (item.ibsCbs!.cbsRefund != null) ...[
            if (item.ibsCbs!.cbsRefund!.rate != null)
              item.ibsCbs!.cbsRefund!.rate!,
            item.ibsCbs!.cbsRefund!.value,
          ],
          if (item.ibsCbs!.cbsReduction != null) ...[
            item.ibsCbs!.cbsReduction!.rate,
            item.ibsCbs!.cbsReduction!.effectiveRate,
          ],
        ],
        if (item.selectiveTax != null) ...[
          item.selectiveTax!.base,
          item.selectiveTax!.rate,
          if (item.selectiveTax!.adRemRate != null)
            item.selectiveTax!.adRemRate!,
          if (item.selectiveTax!.quantity != null) item.selectiveTax!.quantity!,
        ],
      ];
      if (values.any((value) => !value.isFinite || value < 0)) {
        throw const FiscalValidationException(
          'Valores tributários não podem ser negativos.',
          code: 'INVALID_TAX_VALUE',
        );
      }
      if (item.totalDecimal.isNegative) {
        throw const FiscalValidationException(
          'O valor fiscal do item não pode ser negativo.',
          code: 'NEGATIVE_ITEM_TOTAL',
        );
      }
      if (item.pis != null &&
          (!RegExp(r'^\d{2}$').hasMatch(item.pis!.cst) ||
              (item.pis!.cst == '03' &&
                  (item.pis!.quantity == null ||
                      item.pis!.unitRate == null ||
                      item.pis!.value == null)) ||
              (item.pis!.cst == '03' &&
                  (item.pis!.base != null || item.pis!.rate != null)) ||
              (item.pis!.cst != '03' &&
                  item.pis!.quantity != null &&
                  (item.pis!.unitRate == null ||
                      item.pis!.value == null ||
                      item.pis!.base != null ||
                      item.pis!.rate != null)) ||
              (item.pis!.cst != '03' &&
                  item.pis!.base == null &&
                  item.pis!.quantity == null &&
                  (item.pis!.rate != null || item.pis!.value != null)) ||
              (item.pis!.cst != '03' &&
                  item.pis!.base != null &&
                  (item.pis!.rate == null || item.pis!.value == null)))) {
        throw const FiscalValidationException(
          'O CST e os valores do PIS são inválidos ou incompletos.',
          code: 'INVALID_PIS_TAX',
        );
      }
      if (item.cofins != null &&
          (!RegExp(r'^\d{2}$').hasMatch(item.cofins!.cst) ||
              (item.cofins!.cst == '03' &&
                  (item.cofins!.quantity == null ||
                      item.cofins!.unitRate == null ||
                      item.cofins!.value == null)) ||
              (item.cofins!.cst == '03' &&
                  (item.cofins!.base != null || item.cofins!.rate != null)) ||
              (item.cofins!.cst != '03' &&
                  item.cofins!.quantity != null &&
                  (item.cofins!.unitRate == null ||
                      item.cofins!.value == null ||
                      item.cofins!.base != null ||
                      item.cofins!.rate != null)) ||
              (item.cofins!.cst != '03' &&
                  item.cofins!.base == null &&
                  item.cofins!.quantity == null &&
                  (item.cofins!.rate != null || item.cofins!.value != null)) ||
              (item.cofins!.cst != '03' &&
                  item.cofins!.base != null &&
                  (item.cofins!.rate == null || item.cofins!.value == null)))) {
        throw const FiscalValidationException(
          'O CST e os valores da COFINS são inválidos ou incompletos.',
          code: 'INVALID_COFINS_TAX',
        );
      }
      if (item.icms != null) {
        final tax = item.icms!;
        if (!const [
              '00',
              '20',
              '40',
              '41',
              '50',
              '51',
              '60',
              '90',
            ].contains(tax.cst) ||
            tax.origin < 0 ||
            tax.origin > 8 ||
            tax.modality < 0 ||
            tax.modality > 6 ||
            (tax.cst == '20' && tax.reduction == null) ||
            (tax.cst == '60' &&
                (tax.retainedBase == null ||
                    tax.retainedRate == null ||
                    tax.retainedValue == null)) ||
            (tax.desonerationValue != null && tax.desonerationReason == null)) {
          throw const FiscalValidationException(
            'Os dados do ICMS ou o CST informado são inválidos ou incompletos.',
            code: 'INVALID_ICMS_TAX',
          );
        }
        if (tax.desonerationReason != null &&
            !const [
              1,
              3,
              4,
              5,
              6,
              7,
              8,
              9,
              10,
              11,
              12,
              16,
              90,
            ].contains(tax.desonerationReason)) {
          throw const FiscalValidationException(
            'O motivo da desoneração do ICMS é inválido.',
            code: 'INVALID_ICMS_DESONERATION_REASON',
          );
        }
      }
      if (item.icmsSimples != null) {
        final tax = item.icmsSimples!;
        const validCsosn = [
          '101',
          '102',
          '103',
          '201',
          '202',
          '203',
          '300',
          '400',
          '500',
          '900',
        ];
        final hasCredit = tax.creditRate != null || tax.creditValue != null;
        final hasSt =
            tax.stBase != null || tax.stRate != null || tax.stValue != null;
        final hasRetained =
            tax.retainedBase != null ||
            tax.retainedRate != null ||
            tax.retainedValue != null;
        final hasEffective =
            tax.effectiveBase != null ||
            tax.effectiveRate != null ||
            tax.effectiveValue != null ||
            tax.effectiveReduction != null ||
            tax.substitutedValue != null;
        final hasRetainedFcp =
            tax.retainedFcpBase != null ||
            tax.retainedFcpRate != null ||
            tax.retainedFcpValue != null;
        if (!validCsosn.contains(tax.csosn) ||
            tax.origin < 0 ||
            tax.origin > 8 ||
            tax.modality < 0 ||
            tax.modality > 6 ||
            (tax.csosn == '101' &&
                (tax.creditRate == null || tax.creditValue == null)) ||
            ((tax.csosn == '201' || tax.csosn == '202') &&
                (!hasSt ||
                    tax.stBase == null ||
                    tax.stRate == null ||
                    tax.stValue == null)) ||
            (tax.csosn == '500' &&
                hasRetained &&
                (tax.retainedBase == null ||
                    tax.retainedRate == null ||
                    tax.retainedValue == null)) ||
            (hasCredit &&
                (tax.creditRate == null || tax.creditValue == null)) ||
            (hasSt &&
                (tax.stBase == null ||
                    tax.stRate == null ||
                    tax.stValue == null)) ||
            (hasEffective &&
                (tax.effectiveBase == null ||
                    tax.effectiveRate == null ||
                    tax.effectiveValue == null)) ||
            (hasRetainedFcp &&
                (tax.retainedFcpBase == null ||
                    tax.retainedFcpRate == null ||
                    tax.retainedFcpValue == null))) {
          throw const FiscalValidationException(
            'Os dados do ICMS do Simples Nacional são inválidos ou incompletos.',
            code: 'INVALID_ICMS_SIMPLES_TAX',
          );
        }
      }
      if (item.icmsMonophase != null) {
        final tax = item.icmsMonophase!;
        const validCst = ['02', '15', '53', '61'];
        final ownComplete = tax.rate != null && tax.value != null;
        final retainedComplete =
            tax.retainedRate != null && tax.retainedValue != null;
        if (!validCst.contains(tax.cst) ||
            tax.origin < 0 ||
            tax.origin > 8 ||
            (tax.cst == '02' && !ownComplete) ||
            (tax.cst == '15' && (!ownComplete || !retainedComplete)) ||
            (tax.cst == '61' && !retainedComplete) ||
            (tax.reductionRate != null &&
                (tax.reductionReason == null ||
                    !const [1, 9].contains(tax.reductionReason)))) {
          throw const FiscalValidationException(
            'Os dados do ICMS monofásico são inválidos ou incompletos.',
            code: 'INVALID_ICMS_MONOPHASE_TAX',
          );
        }
      }
      if (item.icms != null && item.icmsSimples != null) {
        throw const FiscalValidationException(
          'ICMS normal e ICMS do Simples Nacional não podem coexistir no item.',
          code: 'ICMS_TAX_CONFLICT',
        );
      }
      if (item.icmsMonophase != null &&
          (item.icms != null ||
              item.icmsSt != null ||
              item.icmsSimples != null)) {
        throw const FiscalValidationException(
          'ICMS monofásico não pode coexistir com outro grupo de ICMS no item.',
          code: 'ICMS_TAX_CONFLICT',
        );
      }
      if (item.serviceTax != null &&
          (!RegExp(r'^\d{7}$').hasMatch(item.serviceTax!.municipalityCode) ||
              !RegExp(
                r'^\d{2}\.\d{2}$',
              ).hasMatch(item.serviceTax!.serviceListCode) ||
              item.serviceTax!.exigibility < 1 ||
              item.serviceTax!.exigibility > 7 ||
              (item.serviceTax!.serviceCode == null &&
                  item.serviceTax!.incidenceMunicipalityCode == null))) {
        throw const FiscalValidationException(
          'Os dados de ISSQN do serviço são inválidos.',
          code: 'INVALID_SERVICE_TAX',
        );
      }
      if (item.serviceTax != null &&
          (item.icms != null ||
              item.icmsSt != null ||
              item.pis != null ||
              item.cofins != null ||
              item.ibsCbs != null ||
              item.selectiveTax != null)) {
        throw const FiscalValidationException(
          'ISSQN não pode ser combinado com os grupos de tributos de produto.',
          code: 'SERVICE_TAX_CONFLICT',
        );
      }
      if (item.icms != null &&
          ((item.icms!.fcpBase == null) != (item.icms!.fcpRate == null) ||
              (item.icms!.fcpRate == null) != (item.icms!.fcpValue == null))) {
        throw const FiscalValidationException(
          'Base, alíquota e valor do FCP próprio devem ser informados juntos.',
          code: 'INCOMPLETE_FCP',
        );
      }
      if (item.icms != null &&
          ((item.icms!.fcpDifferenceRate == null) !=
                  (item.icms!.fcpDifferenceValue == null) ||
              item.icms!.fcpDifferenceRate != null && item.icms!.cst != '51')) {
        throw const FiscalValidationException(
          'O FCP diferido exige percentual e valor e só é permitido no CST 51.',
          code: 'INCOMPLETE_FCP_DIFFERENCE',
        );
      }
      final icms60 = item.icms;
      if (icms60 != null && icms60.cst == '60') {
        final tax = icms60;
        if ((tax.retainedFcpBase == null) != (tax.retainedFcpRate == null) ||
            (tax.retainedFcpRate == null) != (tax.retainedFcpValue == null) ||
            (tax.effectiveReduction == null) != (tax.effectiveBase == null) ||
            (tax.effectiveBase == null) != (tax.effectiveRate == null) ||
            (tax.effectiveRate == null) != (tax.effectiveValue == null)) {
          throw const FiscalValidationException(
            'Os dados retidos/efetivos do ICMS60 devem ser completos.',
            code: 'INCOMPLETE_ICMS60_DETAILS',
          );
        }
      }
      if (item.icms?.deductDesoneration != null &&
          (item.icms!.desonerationValue == null ||
              !const ['20', '40', '41', '50'].contains(item.icms!.cst))) {
        throw const FiscalValidationException(
          'indDeduzDeson exige desoneração nos CST 20, 40, 41 ou 50.',
          code: 'INVALID_ICMS_DESONERATION_DEDUCTION',
        );
      }
      if (item.icms?.benefitReductionCode != null &&
          !RegExp(
            r'^[!-ÿ]{8}$|^[!-ÿ]{10}$',
          ).hasMatch(item.icms!.benefitReductionCode!)) {
        throw const FiscalValidationException(
          'O código cBenefRBC do ICMS é inválido.',
          code: 'INVALID_ICMS_REDUCTION_BENEFIT',
        );
      }
      if (item.icms != null && item.icmsSt != null) {
        throw const FiscalValidationException(
          'O item deve escolher ICMS próprio ou ICMS-ST.',
          code: 'MULTIPLE_ICMS_GROUPS',
        );
      }
      if (item.icmsSt != null &&
          ((!item.icmsSt!.stOnly &&
                  !const ['10', '70', '90'].contains(item.icmsSt!.cst)) ||
              (item.icmsSt!.cst == '70' && item.icmsSt!.ownReduction == null) ||
              item.icmsSt!.origin < 0 ||
              item.icmsSt!.origin > 8 ||
              (!item.icmsSt!.stOnly && item.icmsSt!.ownModality < 0) ||
              item.icmsSt!.ownModality > 6 ||
              item.icmsSt!.modality < 0 ||
              item.icmsSt!.modality > 6 ||
              ((item.icmsSt!.fcpBase == null) !=
                  (item.icmsSt!.fcpRate == null)) ||
              (item.icmsSt!.fcpRate == null) !=
                  (item.icmsSt!.fcpValue == null) ||
              ((item.icmsSt!.fcpStBase == null) !=
                  (item.icmsSt!.fcpStRate == null)) ||
              (item.icmsSt!.fcpStRate == null) !=
                  (item.icmsSt!.fcpStValue == null))) {
        throw const FiscalValidationException(
          'Os dados do ICMS-ST/FCP devem ser completos e válidos.',
          code: 'INVALID_ICMS_ST',
        );
      }
      if (item.ibsCbs != null &&
          (!RegExp(r'^\d{3}$').hasMatch(item.ibsCbs!.cst) ||
              !RegExp(r'^\d{6}$').hasMatch(item.ibsCbs!.classificationCode) ||
              item.ibsCbs!.base < 0 ||
              item.ibsCbs!.ibsUfRate < 0 ||
              item.ibsCbs!.ibsUfRate > 100 ||
              item.ibsCbs!.ibsMunicipalRate < 0 ||
              item.ibsCbs!.ibsMunicipalRate > 100 ||
              item.ibsCbs!.cbsRate < 0 ||
              item.ibsCbs!.cbsRate > 100)) {
        throw const FiscalValidationException(
          'CST/classificação do IBS/CBS, base e alíquotas devem ser válidos.',
          code: 'INVALID_IBS_CBS_CLASSIFICATION',
        );
      }
      final operationCredit = item.ibsCbs?.operationCredit;
      if (operationCredit != null &&
          (operationCredit.base < 0 ||
              !RegExp(r'^\d{2}$').hasMatch(operationCredit.code) ||
              operationCredit.ibs != null &&
                  (operationCredit.ibs!.rate < 0 ||
                      operationCredit.ibs!.value < 0) ||
              operationCredit.cbs != null &&
                  (operationCredit.cbs!.rate < 0 ||
                      operationCredit.cbs!.value < 0))) {
        throw const FiscalValidationException(
          'Os dados do crédito presumido RTC são inválidos.',
          code: 'INVALID_IBS_CBS_CREDIT',
        );
      }
      final zfmCredit = item.ibsCbs?.zfmCredit;
      if (zfmCredit != null &&
          (operationCredit != null ||
              !const ['0', '1', '2', '3', '4'].contains(zfmCredit.type) ||
              zfmCredit.value < 0 ||
              zfmCredit.competence.year < 2025 ||
              zfmCredit.competence.month < 1 ||
              zfmCredit.competence.month > 12)) {
        throw const FiscalValidationException(
          'Os dados do crédito presumido ZFM são inválidos ou conflitantes.',
          code: 'INVALID_IBS_CBS_ZFM_CREDIT',
        );
      }
      final creditReversal = item.ibsCbs?.creditReversal;
      if (creditReversal != null &&
          (creditReversal.ibsValue < 0 || creditReversal.cbsValue < 0)) {
        throw const FiscalValidationException(
          'Os valores do estorno de crédito RTC não podem ser negativos.',
          code: 'INVALID_IBS_CBS_CREDIT_REVERSAL',
        );
      }
      final regularTax = item.ibsCbs?.regularTax;
      if (regularTax != null &&
          (!RegExp(r'^\d{3}$').hasMatch(regularTax.cst) ||
              !RegExp(r'^\d{6}$').hasMatch(regularTax.classificationCode) ||
              regularTax.ibsUfRate < 0 ||
              regularTax.ibsUfRate > 100 ||
              regularTax.ibsUfValue < 0 ||
              regularTax.ibsMunicipalRate < 0 ||
              regularTax.ibsMunicipalRate > 100 ||
              regularTax.ibsMunicipalValue < 0 ||
              regularTax.cbsRate < 0 ||
              regularTax.cbsRate > 100 ||
              regularTax.cbsValue < 0)) {
        throw const FiscalValidationException(
          'Os dados da tributação regular RTC são inválidos.',
          code: 'INVALID_IBS_CBS_REGULAR_TAX',
        );
      }
      final governmentTax = item.ibsCbs?.governmentTax;
      if (governmentTax != null &&
          (governmentTax.ibsUfRate < 0 ||
              governmentTax.ibsUfRate > 100 ||
              governmentTax.ibsUfValue < 0 ||
              governmentTax.ibsMunicipalRate < 0 ||
              governmentTax.ibsMunicipalRate > 100 ||
              governmentTax.ibsMunicipalValue < 0 ||
              governmentTax.cbsRate < 0 ||
              governmentTax.cbsRate > 100 ||
              governmentTax.cbsValue < 0)) {
        throw const FiscalValidationException(
          'Os dados da tributação de compra governamental RTC são inválidos.',
          code: 'INVALID_IBS_CBS_GOVERNMENT_TAX',
        );
      }
      if (item.ibsCbs != null && item.ibsCbsMonophase != null) {
        throw const FiscalValidationException(
          'O item não pode combinar IBS/CBS regular e monofásico.',
          code: 'INVALID_IBS_CBS_COMBINATION',
        );
      }
      if (item.ibsCbsMonophase != null) {
        final tax = item.ibsCbsMonophase!;
        final values = [
          tax.quantity,
          tax.ibsRate,
          tax.ibsValue,
          tax.cbsRate,
          tax.cbsValue,
          tax.ibsRetainedQuantity,
          tax.ibsRetainedRate,
          tax.ibsRetainedValue,
          tax.ibsPreviouslyRetainedValue,
          tax.cbsRetainedQuantity,
          tax.cbsRetainedRate,
          tax.cbsRetainedValue,
          tax.cbsPreviouslyRetainedValue,
          tax.ibsAdValoremBase,
          tax.ibsAdValoremUfRate,
          tax.ibsAdValoremUfValue,
          tax.ibsAdValoremMunicipalRate,
          tax.ibsAdValoremMunicipalValue,
          tax.ibsAdValoremValue,
          tax.cbsAdValoremBase,
          tax.cbsAdValoremRate,
          tax.cbsAdValoremValue,
          tax.ibsBiofuelQuantity,
          tax.ibsBiofuelDifference,
          tax.cbsBiofuelQuantity,
          tax.cbsBiofuelDifference,
        ].whereType<double>().toList();
        final completeIbsAdRem =
            (tax.ibsRate == null) == (tax.ibsValue == null);
        final completeCbsAdRem =
            (tax.cbsRate == null) == (tax.cbsValue == null);
        final ibsAdValorem = [
          tax.ibsAdValoremBase,
          tax.ibsAdValoremUfRate,
          tax.ibsAdValoremUfValue,
          tax.ibsAdValoremMunicipalRate,
          tax.ibsAdValoremMunicipalValue,
          tax.ibsAdValoremValue,
        ];
        final cbsAdValorem = [
          tax.cbsAdValoremBase,
          tax.cbsAdValoremRate,
          tax.cbsAdValoremValue,
        ];
        final completeIbsAdValorem =
            ibsAdValorem.every((value) => value != null) ||
            ibsAdValorem.every((value) => value == null);
        final completeCbsAdValorem =
            cbsAdValorem.every((value) => value != null) ||
            cbsAdValorem.every((value) => value == null);
        final ibsUsesAdRem = tax.ibsRate != null || tax.ibsValue != null;
        final cbsUsesAdRem = tax.cbsRate != null || tax.cbsValue != null;
        final ibsUsesAdValorem = tax.ibsAdValoremBase != null;
        final cbsUsesAdValorem = tax.cbsAdValoremBase != null;
        final completeIbsBiofuel =
            (tax.ibsBiofuelQuantity == null) ==
            (tax.ibsBiofuelDifference == null);
        final completeCbsBiofuel =
            (tax.cbsBiofuelQuantity == null) ==
            (tax.cbsBiofuelDifference == null);
        final retainedGroups = [
          [tax.ibsRetainedQuantity, tax.ibsRetainedRate, tax.ibsRetainedValue],
          [tax.cbsRetainedQuantity, tax.cbsRetainedRate, tax.cbsRetainedValue],
        ];
        final completeRetained = retainedGroups.every((group) {
          final present = group.whereType<double>().length;
          return present == 0 || present == group.length;
        });
        if (tax.cst != '620' ||
            !RegExp(r'^\d{6}$').hasMatch(tax.classificationCode) ||
            (tax.quantity == null && (ibsUsesAdRem || cbsUsesAdRem)) ||
            !completeIbsAdRem ||
            !completeCbsAdRem ||
            !completeIbsAdValorem ||
            !completeCbsAdValorem ||
            !completeIbsBiofuel ||
            !completeCbsBiofuel ||
            (ibsUsesAdRem && ibsUsesAdValorem) ||
            (cbsUsesAdRem && cbsUsesAdValorem) ||
            (ibsUsesAdValorem &&
                (tax.ibsRetainedQuantity != null ||
                    tax.ibsRetainedRate != null ||
                    tax.ibsRetainedValue != null ||
                    tax.ibsPreviouslyRetainedValue != null)) ||
            (cbsUsesAdValorem &&
                (tax.cbsRetainedQuantity != null ||
                    tax.cbsRetainedRate != null ||
                    tax.cbsRetainedValue != null ||
                    tax.cbsPreviouslyRetainedValue != null)) ||
            !completeRetained ||
            (!tax.hasIbs && !tax.hasCbs) ||
            values.any((value) => !value.isFinite || value < 0)) {
          throw const FiscalValidationException(
            'Os dados da tributação monofásica IBS/CBS são inválidos ou incompletos.',
            code: 'INVALID_IBS_CBS_MONOPHASE',
          );
        }
      }
      if (item.ibsCbs != null) {
        final tax = item.ibsCbs!;
        final rates = <double>[
          tax.ibsUfRate,
          tax.ibsMunicipalRate,
          tax.cbsRate,
          if (tax.ibsUfDeferral != null) tax.ibsUfDeferral!.rate,
          if (tax.ibsUfRefund?.rate != null) tax.ibsUfRefund!.rate!,
          if (tax.ibsUfReduction != null) ...[
            tax.ibsUfReduction!.rate,
            tax.ibsUfReduction!.effectiveRate,
          ],
          if (tax.ibsMunicipalDeferral != null) tax.ibsMunicipalDeferral!.rate,
          if (tax.ibsMunicipalRefund?.rate != null)
            tax.ibsMunicipalRefund!.rate!,
          if (tax.ibsMunicipalReduction != null) ...[
            tax.ibsMunicipalReduction!.rate,
            tax.ibsMunicipalReduction!.effectiveRate,
          ],
          if (tax.cbsDeferral != null) tax.cbsDeferral!.rate,
          if (tax.cbsRefund?.rate != null) tax.cbsRefund!.rate!,
          if (tax.cbsReduction != null) ...[
            tax.cbsReduction!.rate,
            tax.cbsReduction!.effectiveRate,
          ],
        ];
        if (rates.any((rate) => !rate.isFinite || rate < 0 || rate > 100)) {
          throw const FiscalValidationException(
            'As alíquotas e percentuais do IBS/CBS devem estar entre 0 e 100.',
            code: 'INVALID_IBS_CBS_RATE',
          );
        }
      }
      if (item.ipi != null &&
          (!RegExp(r'^\d{1,3}$').hasMatch(item.ipi!.enquadramento) ||
              !const [
                '00',
                '01',
                '02',
                '03',
                '04',
                '05',
                '49',
                '50',
                '51',
                '52',
                '53',
                '54',
                '55',
                '99',
              ].contains(item.ipi!.cst))) {
        throw const FiscalValidationException(
          'O enquadramento ou CST do IPI é inválido.',
          code: 'INVALID_IPI_CLASSIFICATION',
        );
      }
      if (item.selectiveTax != null &&
          (!RegExp(r'^\d{3}$').hasMatch(item.selectiveTax!.cst) ||
              !RegExp(
                r'^\d{6}$',
              ).hasMatch(item.selectiveTax!.classificationCode) ||
              item.selectiveTax!.base < 0 ||
              item.selectiveTax!.rate < 0 ||
              item.selectiveTax!.rate > 100 ||
              (item.selectiveTax!.adRemRate != null &&
                  (item.selectiveTax!.adRemRate!.isNegative ||
                      !item.selectiveTax!.adRemRate!.isFinite)) ||
              (item.selectiveTax!.unit == null) !=
                  (item.selectiveTax!.quantity == null) ||
              (item.selectiveTax!.unit != null &&
                  (item.selectiveTax!.unit!.trim().isEmpty ||
                      item.selectiveTax!.unit!.length > 6)) ||
              (item.selectiveTax!.quantity != null &&
                  (item.selectiveTax!.quantity!.isNegative ||
                      !item.selectiveTax!.quantity!.isFinite)))) {
        throw const FiscalValidationException(
          'CSTIS/classificação do Imposto Seletivo, base e alíquota devem ser '
          'válidos.',
          code: 'INVALID_SELECTIVE_CLASSIFICATION',
        );
      }
    }
  }

  void _validateStrictFiscalFields(NfeDocument d) {
    final operationNature = d.operationNature?.trim() ?? '';
    if (operationNature.isEmpty || operationNature.length > 60) {
      throw const FiscalValidationException(
        'A natureza da operação é obrigatória no modo fiscal estrito.',
        code: 'STRICT_OPERATION_NATURE_REQUIRED',
      );
    }
    if (d.documentType == null || d.documentType! < 0 || d.documentType! > 1) {
      throw const FiscalValidationException(
        'O tipo da operação deve ser 0 (entrada) ou 1 (saída).',
        code: 'STRICT_DOCUMENT_TYPE_REQUIRED',
      );
    }
    if (d.destinationType == null ||
        d.destinationType! < 1 ||
        d.destinationType! > 3) {
      throw const FiscalValidationException(
        'O destino da operação deve ser 1, 2 ou 3.',
        code: 'STRICT_DESTINATION_REQUIRED',
      );
    }
    final municipality = d.municipalityCode ?? d.issuer.cityCode;
    if (municipality == null || !RegExp(r'^\d{7}$').hasMatch(municipality)) {
      throw const FiscalValidationException(
        'O município do fato gerador deve possuir sete dígitos IBGE.',
        code: 'STRICT_MUNICIPALITY_REQUIRED',
      );
    }
    if (d.printFormat == null || d.printFormat! < 0 || d.printFormat! > 5) {
      throw const FiscalValidationException(
        'O formato de impressão é obrigatório no modo fiscal estrito.',
        code: 'STRICT_PRINT_FORMAT_REQUIRED',
      );
    }
    if (d.purpose == null || d.purpose! < 1 || d.purpose! > 4) {
      throw const FiscalValidationException(
        'A finalidade da emissão deve estar entre 1 e 4.',
        code: 'STRICT_PURPOSE_REQUIRED',
      );
    }
    if (d.finalConsumer == null ||
        d.finalConsumer! < 0 ||
        d.finalConsumer! > 1) {
      throw const FiscalValidationException(
        'O indicador de consumidor final é obrigatório.',
        code: 'STRICT_FINAL_CONSUMER_REQUIRED',
      );
    }
    if (d.presenceIndicator == null ||
        d.presenceIndicator! < 0 ||
        d.presenceIndicator! > 9) {
      throw const FiscalValidationException(
        'O indicador de presença é obrigatório no modo fiscal estrito.',
        code: 'STRICT_PRESENCE_REQUIRED',
      );
    }
    if (d.processCode == null || d.processCode!.trim().isEmpty) {
      throw const FiscalValidationException(
        'O processo de emissão é obrigatório.',
        code: 'STRICT_PROCESS_REQUIRED',
      );
    }
    if (d.applicationVersion == null || d.applicationVersion!.trim().isEmpty) {
      throw const FiscalValidationException(
        'A versão do processo de emissão é obrigatória.',
        code: 'STRICT_APPLICATION_VERSION_REQUIRED',
      );
    }
    final issuer = d.issuer;
    if (issuer.address == null ||
        issuer.address!.trim().isEmpty ||
        issuer.addressNumber == null ||
        issuer.neighborhood == null ||
        issuer.city == null ||
        issuer.state == null ||
        issuer.zipCode == null ||
        issuer.cityCode == null) {
      throw const FiscalValidationException(
        'O endereço completo e o município IBGE do emitente são obrigatórios.',
        code: 'STRICT_ISSUER_ADDRESS_REQUIRED',
      );
    }
  }

  void _validateParty(dynamic party, String label) {
    final identifiers = [
      party.cnpj,
      party.cpf,
      party.foreignId,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).length;
    if (identifiers != 1) {
      throw FiscalValidationException(
        'O $label deve informar exatamente um identificador fiscal.',
        code: 'INVALID_PARTY_IDENTIFIER',
      );
    }
    final valid = party.foreignId != null
        ? party.foreignId!.trim().isNotEmpty && party.foreignId!.length <= 20
        : party.cnpj != null
        ? Tools.isValidCnpj(party.cnpj!)
        : Tools.isValidCpf(party.cpf!);
    if (!valid) {
      throw FiscalValidationException(
        'O CPF/CNPJ do $label é inválido.',
        code: 'INVALID_PARTY_TAX_ID',
      );
    }
    if (party.recipientIeIndicator != null &&
        !const [1, 2, 9].contains(party.recipientIeIndicator)) {
      throw const FiscalValidationException(
        'O indicador da IE do destinatário deve ser 1, 2 ou 9.',
        code: 'INVALID_RECIPIENT_IE_INDICATOR',
      );
    }
    if (party.addressComplement != null &&
        party.addressComplement!.trim().isEmpty) {
      throw const FiscalValidationException(
        'O complemento do endereço não pode ser vazio.',
        code: 'INVALID_ADDRESS_COMPLEMENT',
      );
    }
    if (party.phone != null &&
        !RegExp(r'^\d{6,14}$').hasMatch(Tools.onlyDigits(party.phone!))) {
      throw const FiscalValidationException(
        'O telefone deve conter de 6 a 14 dígitos.',
        code: 'INVALID_PARTY_PHONE',
      );
    }
    if (party.email != null &&
        (party.email!.trim().isEmpty || party.email!.length > 60)) {
      throw const FiscalValidationException(
        'O e-mail do participante é inválido.',
        code: 'INVALID_PARTY_EMAIL',
      );
    }
    if (party.cnae != null && !RegExp(r'^\d{7}$').hasMatch(party.cnae!)) {
      throw const FiscalValidationException(
        'O CNAE deve conter sete dígitos.',
        code: 'INVALID_PARTY_CNAE',
      );
    }
    if (party.suframa != null &&
        !RegExp(r'^\d{8,9}$').hasMatch(party.suframa!)) {
      throw const FiscalValidationException(
        'A inscrição SUFRAMA deve conter de 8 a 9 dígitos.',
        code: 'INVALID_PARTY_SUFRAMA',
      );
    }
  }

  void _validateLocation(NfeLocation location, String label) {
    final identifiers = [
      location.cnpj,
      location.cpf,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).length;
    if (identifiers > 1 ||
        location.cnpj != null && !Tools.isValidCnpj(location.cnpj!) ||
        location.cpf != null && !Tools.isValidCpf(location.cpf!)) {
      throw FiscalValidationException(
        'O local de $label possui CPF/CNPJ inválido.',
        code: 'INVALID_LOCATION_TAX_ID',
      );
    }
    if (location.street.trim().isEmpty ||
        location.street.length > 60 ||
        location.number.trim().isEmpty ||
        location.number.length > 60 ||
        location.neighborhood.trim().isEmpty ||
        location.neighborhood.length > 60 ||
        !RegExp(r'^\d{7}$').hasMatch(location.municipalityCode) ||
        location.municipality.trim().isEmpty ||
        location.municipality.length > 60 ||
        !RegExp(r'^[A-Z]{2}$').hasMatch(location.state)) {
      throw FiscalValidationException(
        'O endereço do local de $label é inválido.',
        code: 'INVALID_LOCATION_ADDRESS',
      );
    }
    if (location.phone != null &&
        !RegExp(r'^\d{6,14}$').hasMatch(Tools.onlyDigits(location.phone!))) {
      throw FiscalValidationException(
        'O telefone do local de $label é inválido.',
        code: 'INVALID_LOCATION_PHONE',
      );
    }
  }
}
