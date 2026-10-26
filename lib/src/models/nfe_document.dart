import 'nfe_item.dart';
import 'party.dart';
import 'payment.dart';
import 'contingency.dart';
import 'additional_info.dart';
import '../common/fiscal_decimal.dart';
import 'transport.dart';
import 'nfe_complements.dart';
import 'nfce_supplement.dart';
import 'access_key.dart';

/// Documento fiscal eletrônico modelo 55 ou 65.
class NfeDocument {
  /// Cria um documento calculando automaticamente a chave de acesso.
  ///
  /// [cNf] é o código numérico de oito dígitos definido pelo emissor. O tipo
  /// de emissão é normal (`1`) ou o código da [contingency] informada.
  factory NfeDocument.fromComponents({
    required String cUf,
    required String cnpj,
    required String cNf,
    required int number,
    required int series,
    required DateTime issueDate,
    DateTime? departureDate,
    DateTime? deliveryForecast,
    required int environment,
    required int model,
    required Party issuer,
    Party? recipient,
    NfeLocation? withdrawal,
    NfeLocation? delivery,
    required List<NfeItem> items,
    List<Payment> payments = const [],
    Contingency? contingency,
    AdditionalInfo? additionalInfo,
    TransportInfo transport = const TransportInfo(),
    List<ReferencedDocument> references = const [],
    BillingInfo? billing,
    TechnicalResponsible? technicalResponsible,
    IntermediaryInfo? intermediary,
    NfeAuthorization? authorization,
    AvulsaInfo? avulsa,
    TaxRetention? taxRetention,
    ServiceTotal? serviceTotal,
    ExportInfo? exportInfo,
    PurchaseInfo? purchaseInfo,
    SugarcaneInfo? sugarcane,
    String? operationNature,
    int? finalConsumer,
    int? presenceIndicator,
    int? intermediaryIndicator,
    String? operationLocationCode,
    List<String> advancePaymentReferences = const [],
    GovernmentPurchase? governmentPurchase,
    int? documentType,
    int? destinationType,
    String? municipalityCode,
    String? ibsMunicipalityCode,
    int? printFormat,
    int? purpose,
    String? debitNoteType,
    String? creditNoteType,
    String? processCode,
    String? applicationVersion,
    NfceXmlSupplement? nfceSupplement,
    double? changeValue,
  }) {
    final accessKey = AccessKey.fromComponents(
      cUf: cUf,
      issueDate: issueDate,
      cnpj: cnpj,
      model: model,
      series: series,
      number: number,
      tpEmis: contingency?.mode.code ?? 1,
      cNf: cNf,
    );
    return NfeDocument(
      accessKey: accessKey.value,
      number: number,
      series: series,
      issueDate: issueDate,
      departureDate: departureDate,
      deliveryForecast: deliveryForecast,
      environment: environment,
      model: model,
      issuer: issuer,
      recipient: recipient,
      withdrawal: withdrawal,
      delivery: delivery,
      items: items,
      payments: payments,
      contingency: contingency,
      additionalInfo: additionalInfo,
      transport: transport,
      references: references,
      billing: billing,
      technicalResponsible: technicalResponsible,
      intermediary: intermediary,
      authorization: authorization,
      avulsa: avulsa,
      taxRetention: taxRetention,
      serviceTotal: serviceTotal,
      exportInfo: exportInfo,
      purchaseInfo: purchaseInfo,
      sugarcane: sugarcane,
      operationNature: operationNature,
      finalConsumer: finalConsumer,
      presenceIndicator: presenceIndicator,
      intermediaryIndicator: intermediaryIndicator,
      operationLocationCode: operationLocationCode,
      advancePaymentReferences: advancePaymentReferences,
      governmentPurchase: governmentPurchase,
      documentType: documentType,
      destinationType: destinationType,
      municipalityCode: municipalityCode,
      ibsMunicipalityCode: ibsMunicipalityCode,
      printFormat: printFormat,
      purpose: purpose,
      debitNoteType: debitNoteType,
      creditNoteType: creditNoteType,
      processCode: processCode,
      applicationVersion: applicationVersion,
      nfceSupplement: nfceSupplement,
      changeValue: changeValue,
    );
  }

  /// Cria um documento fiscal em memória.
  const NfeDocument({
    required this.accessKey,
    required this.number,
    required this.series,
    required this.issueDate,
    this.departureDate,
    this.deliveryForecast,
    required this.environment,
    required this.model,
    required this.issuer,
    this.recipient,
    this.withdrawal,
    this.delivery,
    required this.items,
    this.payments = const [],
    this.contingency,
    this.additionalInfo,
    this.transport = const TransportInfo(),
    this.references = const [],
    this.billing,
    this.technicalResponsible,
    this.intermediary,
    this.authorization,
    this.avulsa,
    this.taxRetention,
    this.serviceTotal,
    this.exportInfo,
    this.purchaseInfo,
    this.sugarcane,
    this.operationNature,
    this.finalConsumer,
    this.presenceIndicator,
    this.intermediaryIndicator,
    this.operationLocationCode,
    this.advancePaymentReferences = const [],
    this.governmentPurchase,
    this.documentType,
    this.destinationType,
    this.municipalityCode,
    this.ibsMunicipalityCode,
    this.printFormat,
    this.purpose,
    this.debitNoteType,
    this.creditNoteType,
    this.processCode,
    this.applicationVersion,
    this.nfceSupplement,
    this.changeValue,
  });

  /// Chave de acesso, com 44 dígitos quando já calculada.
  final String accessKey;

  /// Número do documento.
  final int number;

  /// Série fiscal.
  final int series;

  /// Data e hora de emissão.
  final DateTime issueDate;

  /// Data e hora de saída/entrada da mercadoria (`dhSaiEnt`), quando informada.
  final DateTime? departureDate;

  /// Data prevista de entrega/disponibilização (`dPrevEntrega`).
  final DateTime? deliveryForecast;

  /// Ambiente de autorização: 1 produção, 2 homologação.
  final int environment;

  /// Modelo: 55 NF-e ou 65 NFC-e.
  final int model;

  /// Emitente.
  final Party issuer;

  /// Destinatário, quando informado.
  final Party? recipient;

  /// Local de retirada da mercadoria (`retirada`).
  final NfeLocation? withdrawal;

  /// Local de entrega da mercadoria (`entrega`).
  final NfeLocation? delivery;

  /// Itens comerciais.
  final List<NfeItem> items;

  /// Pagamentos informados no documento.
  final List<Payment> payments;

  /// Configuração de contingência, quando a emissão não é normal.
  final Contingency? contingency;

  /// Informações adicionais do contribuinte e do fisco.
  final AdditionalInfo? additionalInfo;

  /// Informações de transporte; por padrão indica ausência de transporte.
  final TransportInfo transport;

  /// Documentos fiscais referenciados no grupo `ide/NFref`.
  final List<ReferencedDocument> references;

  /// Cobrança/fatura opcional.
  final BillingInfo? billing;

  /// Responsável técnico opcional.
  final TechnicalResponsible? technicalResponsible;

  /// Dados do intermediador da transação, quando [intermediaryIndicator] é 1.
  final IntermediaryInfo? intermediary;

  /// Protocolo de autorização, quando o documento já foi autorizado.
  final NfeAuthorization? authorization;

  /// Dados de emissão avulsa pelo Fisco (`avulsa`).
  final AvulsaInfo? avulsa;

  /// Retenções de tributos federais no total.
  final TaxRetention? taxRetention;

  /// Total de ISSQN declarado por layout legado, quando disponível.
  final ServiceTotal? serviceTotal;

  /// Informações de exportação do documento.
  final ExportInfo? exportInfo;

  /// Informações de compra pública/contrato.
  final PurchaseInfo? purchaseInfo;

  /// Registro de aquisição de cana.
  final SugarcaneInfo? sugarcane;

  /// Natureza da operação (`natOp`), quando informada.
  final String? operationNature;

  /// Indicador de consumidor final (`indFinal`): 0 ou 1.
  final int? finalConsumer;

  /// Indicador de presença do comprador (`indPres`).
  final int? presenceIndicator;

  /// Indicador de intermediador/marketplace (`indIntermed`): 0 ou 1.
  final int? intermediaryIndicator;

  /// Código indicador do local da operação de fornecimento (`cIndOp`).
  final String? operationLocationCode;

  /// Chaves das NF-e anteriores usadas para pagamento antecipado (`gPagAntecipado`).
  final List<String> advancePaymentReferences;

  /// Compra governamental informada no grupo `ide/gCompraGov`.
  final GovernmentPurchase? governmentPurchase;

  /// Tipo da operação (`tpNF`): 0 entrada ou 1 saída.
  final int? documentType;

  /// Destino da operação (`idDest`): 1 interna, 2 interestadual, 3 exterior.
  final int? destinationType;

  /// Município do fato gerador (`cMunFG`).
  final String? municipalityCode;

  /// Município do fato gerador de IBS/CBS (`cMunFGIBS`).
  final String? ibsMunicipalityCode;

  /// Formato de impressão do DANFE (`tpImp`).
  final int? printFormat;

  /// Finalidade da emissão (`finNFe`).
  final int? purpose;

  /// Tipo da nota de débito (`tpNFDebito`), códigos `01` a `08`.
  final String? debitNoteType;

  /// Tipo da nota de crédito (`tpNFCredito`), códigos `01` a `06`.
  final String? creditNoteType;

  /// Código do processo de emissão (`procEmi`).
  final String? processCode;

  /// Versão do aplicativo emissor (`verProc`).
  final String? applicationVersion;

  /// QR Code/URL suplementares da NFC-e, quando configurados.
  final NfceXmlSupplement? nfceSupplement;

  /// Troco informado em pagamentos (`vTroco`).
  final double? changeValue;

  /// Valor fiscal total do documento, incluindo rateios e tributos que
  /// compõem `vNF` (como IPI e ICMS-ST).
  double get total => totalDecimal.toDouble();

  /// Total dos itens calculado em decimal exato.
  FiscalDecimal get totalDecimal => items
      .where((item) => item.includeInTotal)
      .fold(
        FiscalDecimal.parse('0'),
        (sum, item) =>
            sum +
            item.totalDecimal +
            FiscalDecimal.fromNum(item.ipi?.value ?? 0) +
            FiscalDecimal.fromNum(item.importTax?.value ?? 0) +
            FiscalDecimal.fromNum(item.icmsSt?.stValue ?? 0) +
            FiscalDecimal.fromNum(item.icmsSimples?.stValue ?? 0),
      );

  /// Total da nota com duas casas fiscais.
  String get totalFormatted => totalDecimal.toFixed(2);

  /// Soma dos pagamentos informados.
  double get paymentTotal => paymentTotalDecimal.toDouble();

  /// Total dos pagamentos calculado em decimal exato.
  FiscalDecimal get paymentTotalDecimal => payments.fold(
    FiscalDecimal.parse('0'),
    (sum, payment) => sum + FiscalDecimal.fromNum(payment.value),
  );

  /// Total dos pagamentos com duas casas fiscais.
  String get paymentTotalFormatted => paymentTotalDecimal.toFixed(2);
}
