import 'taxes.dart';
import '../common/fiscal_decimal.dart';
import 'reform_taxes.dart';
import 'trade.dart';
import 'product_details.dart';

/// Item comercial da NF-e/NFC-e.
class NfeItem {
  /// Cria um item de produto ou serviço.
  const NfeItem({
    required this.number,
    required this.code,
    required this.description,
    required this.ncm,
    required this.cfop,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    this.freight = 0,
    this.insurance = 0,
    this.discount = 0,
    this.other = 0,
    this.importDuty = 0,
    this.ean,
    this.barcode,
    this.eanTrib,
    this.taxableBarcode,
    this.nve = const [],
    this.cest,
    this.scaleIndicator,
    this.manufacturerCnpj,
    this.benefitCode,
    this.presumedCredits = const [],
    this.zfmCreditType,
    this.extipi,
    this.orderNumber,
    this.orderItem,
    this.fciNumber,
    this.usedMovableAsset = false,
    this.nffProduct,
    this.embeddedProduct,
    this.additionalInformation,
    this.importDeclarations = const [],
    this.exportDetails = const [],
    this.traceability = const [],
    this.newVehicle,
    this.weapons = const [],
    this.medication,
    this.fuel,
    this.recopiNumber,
    this.tribUnit,
    this.tribQuantity,
    this.tribUnitPrice,
    this.includeInTotal = true,
    this.approximateTaxValue,
    this.icms,
    this.icmsSt,
    this.icmsStRetained,
    this.icmsPart,
    this.icmsUfDestination,
    this.icmsSimples,
    this.icmsMonophase,
    this.ipi,
    this.importTax,
    this.pis,
    this.pisSt,
    this.cofins,
    this.cofinsSt,
    this.ipiDevolution,
    this.serviceTax,
    this.ibsCbs,
    this.ibsCbsMonophase,
    this.selectiveTax,
  });

  /// Número sequencial do item.
  final int number;

  /// Código interno do produto.
  final String code;

  /// GTIN/EAN, quando disponível.
  final String? ean;

  /// Código de barras comercial fora do padrão GTIN (`cBarra`).
  final String? barcode;

  /// GTIN da unidade tributável; usa [ean] quando não informado.
  final String? eanTrib;

  /// Código de barras tributável fora do padrão GTIN (`cBarraTrib`).
  final String? taxableBarcode;

  /// Nomenclaturas de Valor Aduaneiro e Estatística (`NVE`).
  final List<String> nve;

  /// Código Especificador da Substituição Tributária (`CEST`).
  final String? cest;

  /// Indicador de produção em escala relevante (`S`/`N`).
  final String? scaleIndicator;

  /// CNPJ do fabricante quando a escala não é relevante (`CNPJFab`).
  final String? manufacturerCnpj;

  /// Código de benefício fiscal (`cBenef`).
  final String? benefitCode;

  /// Créditos presumidos vinculados ao item (`gCred`).
  final List<PresumedCredit> presumedCredits;

  /// Classificação do crédito presumido IBS na ZFM (`tpCredPresIBSZFM`).
  final String? zfmCreditType;

  /// Código de exceção da TIPI (`EXTIPI`).
  final String? extipi;

  /// Número do pedido de compra (`xPed`).
  final String? orderNumber;

  /// Item do pedido de compra (`nItemPed`).
  final int? orderItem;

  /// Número da Ficha de Conteúdo de Importação (`nFCI`).
  final String? fciNumber;

  /// Indica fornecimento de bem móvel usado (`indBemMovelUsado=1`).
  final bool usedMovableAsset;

  /// Informações fiscais específicas da NFF (`infProdNFF`).
  final NffProductInfo? nffProduct;

  /// Informações de embalagem da NFF (`infProdEmb`).
  final EmbeddedProductInfo? embeddedProduct;

  /// Informação adicional do produto (`infAdProd`).
  final String? additionalInformation;

  /// Declarações de importação (`DI`) vinculadas ao item.
  final List<ImportDeclaration> importDeclarations;

  /// Detalhes de exportação (`detExport`) vinculados ao item.
  final List<ExportDetail> exportDetails;

  /// Lotes de rastreabilidade do produto.
  final List<ProductTraceability> traceability;

  /// Detalhamento de veículo novo (`veicProd`).
  final NewVehicleInfo? newVehicle;

  /// Armamentos vinculados ao item (`arma`).
  final List<WeaponInfo> weapons;

  /// Detalhamento farmacêutico opcional.
  final MedicationInfo? medication;

  /// Detalhamento de combustível/ANP opcional.
  final FuelInfo? fuel;

  /// Número do registro RECOPI (`nRECOPI`).
  final String? recopiNumber;

  /// Unidade tributável; usa [unit] quando não informada.
  final String? tribUnit;

  /// Quantidade tributável; usa [quantity] quando não informada.
  final double? tribQuantity;

  /// Preço unitário tributável; usa [unitPrice] quando não informado.
  final double? tribUnitPrice;

  /// Indica que o valor do item compõe o total da NF-e (`indTot=1`).
  final bool includeInTotal;

  /// Valor aproximado total dos tributos informado pelo registro TXT `M`.
  final double? approximateTaxValue;

  /// Descrição do produto.
  final String description;

  /// NCM com oito dígitos.
  final String ncm;

  /// CFOP do item.
  final String cfop;

  /// Unidade comercial.
  final String unit;

  /// Quantidade comercial.
  final double quantity;

  /// Preço unitário comercial.
  final double unitPrice;

  /// Frete rateado no item (`vFrete`).
  final double freight;

  /// Seguro rateado no item (`vSeg`).
  final double insurance;

  /// Desconto rateado no item (`vDesc`).
  final double discount;

  /// Outras despesas acessórias rateadas no item (`vOutro`).
  final double other;

  /// Imposto de importação rateado no item (`vII`).
  final double importDuty;

  /// ICMS básico do item, quando tributado nesta forma.
  final IcmsTax? icms;

  /// ICMS próprio com cobrança de substituição tributária (`ICMS10`).
  final IcmsStTax? icmsSt;

  /// ICMS-ST retido/destinado informado pelo grupo `N10B`.
  final IcmsStRetainedTax? icmsStRetained;

  /// Partilha do ICMS entre UF de origem e destino.
  final IcmsPartTax? icmsPart;

  /// Partilha para consumidor final não contribuinte.
  final IcmsUfDestinationTax? icmsUfDestination;

  /// ICMS do Simples Nacional por CSOSN.
  final IcmsSimplesTax? icmsSimples;

  /// ICMS monofásico de combustíveis.
  final IcmsMonophaseTax? icmsMonophase;

  /// IPI tributado do item.
  final IpiTax? ipi;

  /// Imposto de importação do item.
  final ImportTax? importTax;

  /// PIS do item.
  final PisTax? pis;

  /// PIS por substituição tributária.
  final PisStTax? pisSt;

  /// COFINS do item.
  final CofinsTax? cofins;

  /// COFINS por substituição tributária.
  final CofinsStTax? cofinsSt;

  /// IPI devolvido no item.
  final IpiDevolution? ipiDevolution;

  /// ISSQN do item quando a operação é prestação de serviço.
  final ServiceTax? serviceTax;

  /// IBS/CBS do item, quando aplicável.
  final IbsCbsTax? ibsCbs;

  /// IBS/CBS monofásico ad rem padrão (`CST 620`), quando aplicável.
  final IbsCbsMonophaseTax? ibsCbsMonophase;

  /// Imposto Seletivo do item, quando aplicável.
  final SelectiveTax? selectiveTax;

  /// Valor bruto do item.
  double get total => totalDecimal.toDouble();

  /// Valor bruto calculado sem aritmética binária de ponto flutuante.
  FiscalDecimal get merchandiseTotalDecimal =>
      FiscalDecimal.fromNum(quantity) * FiscalDecimal.fromNum(unitPrice);

  /// Valor fiscal do item após acréscimos e desconto.
  FiscalDecimal get totalDecimal =>
      merchandiseTotalDecimal +
      FiscalDecimal.fromNum(freight) +
      FiscalDecimal.fromNum(insurance) +
      FiscalDecimal.fromNum(other) +
      FiscalDecimal.fromNum(importDuty) -
      FiscalDecimal.fromNum(discount);

  /// Valor bruto com duas casas fiscais.
  String get totalFormatted => totalDecimal.toFixed(2);

  /// Valor bruto da mercadoria, sem rateios do total da nota.
  String get merchandiseTotalFormatted => merchandiseTotalDecimal.toFixed(2);
}
