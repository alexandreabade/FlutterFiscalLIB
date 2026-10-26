/// Resultado da autorização usado na representação auxiliar do documento.
class NfeAuthorization {
  /// Cria os dados do protocolo retornado pelo autorizador.
  const NfeAuthorization({
    required this.protocol,
    required this.authorizedAt,
    this.status = 100,
    this.reason = 'Autorizado o uso da NF-e',
  });

  /// Número do protocolo (`nProt`).
  final String protocol;

  /// Data e hora de recebimento/autorização (`dhRecbto`).
  final DateTime authorizedAt;

  /// Código de situação retornado pelo autorizador (`cStat`).
  final int status;

  /// Motivo retornado pelo autorizador (`xMotivo`).
  final String reason;
}

/// Item de pedido informado nos eventos de prorrogação de retorno.
class ReturnExtensionItem {
  /// Cria um item com número da linha e quantidade devolvida.
  const ReturnExtensionItem({required this.number, required this.quantity});

  /// Número do item na NF-e original.
  final int number;

  /// Quantidade do item incluída no pedido.
  final double quantity;
}

/// Dados tipados de um evento de manifestação para envio em lote.
class ManifestationRequest {
  /// Cria uma manifestação para uma NF-e.
  const ManifestationRequest({
    required this.accessKey,
    required this.cOrgao,
    required this.environment,
    required this.participantTaxId,
    required this.eventType,
    this.justification,
    this.eventDate,
    this.sequence = 1,
  });

  /// Chave da NF-e manifestada.
  final String accessKey;

  /// Órgão de recepção do evento.
  final int cOrgao;

  /// Ambiente fiscal.
  final int environment;

  /// CPF/CNPJ do autor do evento.
  final String participantTaxId;

  /// Código de manifestação (`210200`, `210210`, `210220` ou `210240`).
  final String eventType;

  /// Justificativa exigida para operação não realizada.
  final String? justification;

  /// Data do evento; quando ausente, usa o relógio local.
  final DateTime? eventDate;

  /// Sequência do evento para a chave.
  final int sequence;
}

/// Retenções de tributos federais no total da NF-e (`retTrib`).
class TaxRetention {
  /// Cria os valores retidos e suas bases de cálculo.
  const TaxRetention({
    this.pis = 0,
    this.cofins = 0,
    this.csll = 0,
    this.irrfBase = 0,
    this.irrf = 0,
    this.socialSecurityBase = 0,
    this.socialSecurity = 0,
  });

  /// Valor retido de PIS.
  final double pis;

  /// Valor retido de COFINS.
  final double cofins;

  /// Valor retido de CSLL.
  final double csll;

  /// Base de cálculo do IRRF.
  final double irrfBase;

  /// Valor retido de IRRF.
  final double irrf;

  /// Base de cálculo da previdência social.
  final double socialSecurityBase;

  /// Valor retido da previdência social.
  final double socialSecurity;
}

/// Dados de emissão avulsa pelo Fisco (`avulsa`), usados pelo registro TXT D.
class AvulsaInfo {
  /// Cria os dados do órgão emissor da NF-e avulsa.
  const AvulsaInfo({
    required this.cnpj,
    required this.agency,
    required this.registration,
    required this.agent,
    required this.state,
    required this.fiscalOffice,
    this.phone,
    this.revenueDocumentNumber,
    this.documentIssueDate,
    this.revenueDocumentValue,
    this.paymentDate,
  });

  /// CNPJ do órgão emissor.
  final String cnpj;

  /// Órgão emitente (`xOrgao`).
  final String agency;

  /// Matrícula do agente (`matr`).
  final String registration;

  /// Nome do agente (`xAgente`).
  final String agent;

  /// Telefone do órgão/agente (`fone`).
  final String? phone;

  /// UF do órgão emissor.
  final String state;

  /// Número do documento de arrecadação (`nDAR`).
  final String? revenueDocumentNumber;

  /// Data de emissão do DAR (`dEmi`).
  final DateTime? documentIssueDate;

  /// Valor constante no DAR (`vDAR`).
  final double? revenueDocumentValue;

  /// Repartição fiscal emitente (`repEmi`).
  final String fiscalOffice;

  /// Data de pagamento (`dPag`).
  final DateTime? paymentDate;
}

/// Total declarado de ISSQN (`ISSQNtot`), quando recebido de layout legado.
class ServiceTotal {
  /// Cria os totalizadores de serviço declarados.
  const ServiceTotal({
    required this.serviceValue,
    required this.taxBase,
    required this.taxValue,
    required this.competenceDate,
    this.pis = 0,
    this.cofins = 0,
    this.deduction = 0,
    this.other = 0,
    this.unconditionalDiscount = 0,
    this.conditionalDiscount = 0,
    this.retained = 0,
    this.taxRegime,
  });

  /// Valor dos serviços (`vServ`).
  final double serviceValue;

  /// Base do ISSQN (`vBC`).
  final double taxBase;

  /// Valor do ISSQN (`vISS`).
  final double taxValue;

  /// PIS total do serviço (`vPIS`).
  final double pis;

  /// COFINS total do serviço (`vCOFINS`).
  final double cofins;

  /// Competência (`dCompet`).
  final DateTime competenceDate;

  /// Dedução (`vDeducao`).
  final double deduction;

  /// Outras retenções/despesas (`vOutro`).
  final double other;

  /// Desconto incondicional (`vDescIncond`).
  final double unconditionalDiscount;

  /// Desconto condicional (`vDescCond`).
  final double conditionalDiscount;

  /// ISS retido (`vISSRet`).
  final double retained;

  /// Regime tributário (`cRegTrib`).
  final int? taxRegime;
}

/// Documento fiscal referenciado no grupo `ide/NFref`.
class ReferencedDocument {
  /// Referencia outra NF-e pela chave de acesso.
  const ReferencedDocument.nfe(this.accessKey)
    : cUf = null,
      yearMonth = null,
      cnpj = null,
      model = null,
      series = null,
      number = null,
      signedNfeKey = null,
      cteKey = null,
      producerIe = null,
      cpf = null,
      ecfModel = null,
      ecfNumber = null,
      cooNumber = null;

  /// Referencia uma NF-e por chave com código numérico sigiloso (`refNFeSig`).
  const ReferencedDocument.nfeSig(this.signedNfeKey)
    : accessKey = null,
      cUf = null,
      yearMonth = null,
      cnpj = null,
      model = null,
      series = null,
      number = null,
      cteKey = null,
      producerIe = null,
      cpf = null,
      ecfModel = null,
      ecfNumber = null,
      cooNumber = null;

  /// Referencia um CT-e pela chave de acesso (`refCTe`).
  const ReferencedDocument.cte(this.cteKey)
    : accessKey = null,
      cUf = null,
      yearMonth = null,
      cnpj = null,
      model = null,
      series = null,
      number = null,
      signedNfeKey = null,
      producerIe = null,
      cpf = null,
      ecfModel = null,
      ecfNumber = null,
      cooNumber = null;

  /// Referencia documento fiscal modelo 1/1A pelos seus campos resumidos.
  const ReferencedDocument.legacy({
    required this.cUf,
    required this.yearMonth,
    required this.cnpj,
    required this.model,
    required this.series,
    required this.number,
  }) : accessKey = null,
       signedNfeKey = null,
       cteKey = null,
       producerIe = null,
       cpf = null,
       ecfModel = null,
       ecfNumber = null,
       cooNumber = null;

  /// Referencia uma nota de produtor rural (`refNFP`).
  const ReferencedDocument.nfp({
    required this.cUf,
    required this.yearMonth,
    this.cnpj,
    this.cpf,
    required this.producerIe,
    required this.model,
    required this.series,
    required this.number,
  }) : accessKey = null,
       signedNfeKey = null,
       cteKey = null,
       ecfModel = null,
       ecfNumber = null,
       cooNumber = null;

  /// Referencia um cupom fiscal emitido por ECF (`refECF`).
  const ReferencedDocument.ecf({
    required this.ecfModel,
    required this.ecfNumber,
    required this.cooNumber,
  }) : accessKey = null,
       signedNfeKey = null,
       cteKey = null,
       cUf = null,
       yearMonth = null,
       cnpj = null,
       cpf = null,
       producerIe = null,
       model = null,
       series = null,
       number = null;

  /// Chave de acesso da NF-e referenciada.
  final String? accessKey;

  /// Chave da NF-e referenciada com sigilo do código numérico (`refNFeSig`).
  final String? signedNfeKey;

  /// Chave do CT-e referenciado (`refCTe`).
  final String? cteKey;

  /// CPF do produtor rural referenciado (`refNFP/CPF`).
  final String? cpf;

  /// Inscrição estadual do produtor rural (`refNFP/IE`).
  final String? producerIe;

  /// Modelo do equipamento fiscal (`refECF/mod`).
  final String? ecfModel;

  /// Número do ECF (`refECF/nECF`).
  final int? ecfNumber;

  /// Contador de ordem de operação (`refECF/nCOO`).
  final int? cooNumber;

  /// Código da UF do documento legado.
  final String? cUf;

  /// Ano/mês de emissão no formato AAMM.
  final String? yearMonth;

  /// CNPJ do emitente do documento legado.
  final String? cnpj;

  /// Modelo do documento legado referenciado.
  final int? model;

  /// Série do documento legado.
  final int? series;

  /// Número do documento legado.
  final int? number;
}

/// Duplicata de uma fatura fiscal.
class InvoiceInstallment {
  /// Cria uma duplicata com vencimento e valor.
  const InvoiceInstallment({
    required this.number,
    required this.dueDate,
    required this.value,
  });

  /// Número da duplicata.
  final String number;

  /// Data de vencimento.
  final DateTime dueDate;

  /// Valor da duplicata.
  final double value;
}

/// Cobrança/fatura da NF-e.
class BillingInfo {
  /// Cria uma cobrança opcional com fatura e duplicatas.
  const BillingInfo({
    required this.invoiceNumber,
    required this.originalValue,
    this.discount = 0,
    this.installments = const [],
  });

  /// Número da fatura (`nFat`).
  final String invoiceNumber;

  /// Valor original da fatura (`vOrig`).
  final double originalValue;

  /// Desconto da fatura (`vDesc`).
  final double discount;

  /// Duplicatas (`dup`).
  final List<InvoiceInstallment> installments;

  /// Valor líquido calculado (`vLiq`).
  double get netValue => originalValue - discount;
}

/// Responsável técnico informado no documento fiscal.
class TechnicalResponsible {
  /// Cria os dados do responsável técnico.
  const TechnicalResponsible({
    required this.cnpj,
    required this.contact,
    required this.email,
    required this.phone,
    this.csrt,
    this.csrtId,
  });

  /// CNPJ do responsável técnico.
  final String cnpj;

  /// Nome do contato técnico.
  final String contact;

  /// E-mail do contato técnico.
  final String email;

  /// Telefone do contato técnico.
  final String phone;

  /// Hash CSRT calculado pelo responsável técnico (`hashCSRT`).
  final String? csrt;

  /// Identificador do CSRT (`idCSRT`).
  final String? csrtId;
}

/// Informações do intermediador da transação (`infIntermed`).
class IntermediaryInfo {
  /// Cria os dados do marketplace, plataforma ou agenciador.
  const IntermediaryInfo({required this.cnpj, required this.identifier});

  /// CNPJ do intermediador da transação.
  final String cnpj;

  /// Identificador do cadastro da transação no intermediador.
  final String identifier;
}

/// Informações de compras governamentais no grupo `ide/gCompraGov`.
class GovernmentPurchase {
  /// Cria uma compra governamental tipada.
  const GovernmentPurchase({
    required this.governmentEntityType,
    required this.reductionPercentage,
    required this.operationType,
    this.previousDocumentReferences = const [],
  });

  /// Tipo do ente governamental (`tpEnteGov`), de 1 a 6.
  final int governmentEntityType;

  /// Percentual redutor de alíquota (`pRedutor`).
  final double reductionPercentage;

  /// Tipo da operação governamental (`tpOperGov`), de 1 a 4.
  final int operationType;

  /// Chaves de documentos fiscais anteriores (`refDFeAnt`).
  final List<String> previousDocumentReferences;
}

/// Informações de exportação do documento (`exporta`).
class ExportInfo {
  /// Cria os dados de embarque/exportação.
  const ExportInfo({
    required this.departureState,
    required this.exportLocation,
    this.dispatchLocation,
  });

  /// UF de saída do país.
  final String departureState;

  /// Local de embarque ou transposição de fronteira.
  final String exportLocation;

  /// Local de despacho, quando informado.
  final String? dispatchLocation;
}

/// Informações de compra pública/contrato (`compra`).
class PurchaseInfo {
  /// Cria referências de empenho, pedido e contrato.
  const PurchaseInfo({this.commitmentNote, this.order, this.contract});

  /// Nota de empenho (`xNEmp`).
  final String? commitmentNote;

  /// Pedido de compra (`xPed`).
  final String? order;

  /// Contrato (`xCont`).
  final String? contract;
}

/// Fornecimento diário de cana (`forDia`).
class SugarcaneDailySupply {
  /// Cria o fornecimento de um dia da safra.
  const SugarcaneDailySupply({required this.day, required this.quantity});

  /// Dia do mês.
  final int day;

  /// Quantidade em quilogramas.
  final double quantity;
}

/// Dedução de aquisição de cana (`deduc`).
class SugarcaneDeduction {
  /// Cria uma dedução.
  const SugarcaneDeduction({required this.description, required this.value});

  /// Descrição da dedução.
  final String description;

  /// Valor da dedução.
  final double value;
}

/// Registro de aquisição de cana (`cana`).
class SugarcaneInfo {
  /// Cria o resumo da safra e dos fornecimentos.
  const SugarcaneInfo({
    required this.harvest,
    required this.reference,
    required this.dailySupplies,
    required this.monthTotal,
    required this.previousTotal,
    required this.generalTotal,
    required this.supplyValue,
    required this.totalDeductions,
    required this.netSupplyValue,
    this.deductions = const [],
  });

  /// Identificação da safra.
  final String harvest;

  /// Mês/ano no formato `MM/AAAA`.
  final String reference;

  /// Fornecimentos diários.
  final List<SugarcaneDailySupply> dailySupplies;

  /// Total do mês.
  final double monthTotal;

  /// Total anterior.
  final double previousTotal;

  /// Total geral.
  final double generalTotal;

  /// Deduções.
  final List<SugarcaneDeduction> deductions;

  /// Valor dos fornecimentos.
  final double supplyValue;

  /// Total das deduções.
  final double totalDeductions;

  /// Valor líquido dos fornecimentos.
  final double netSupplyValue;
}
