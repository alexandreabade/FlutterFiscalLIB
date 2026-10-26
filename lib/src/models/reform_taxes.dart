import '../common/fiscal_decimal.dart';

/// Diferimento de IBS/CBS (`gDif`).
class ReformDeferral {
  /// Cria um diferimento com percentual e valor fiscal explícitos.
  const ReformDeferral({required this.rate, required this.value});

  /// Percentual diferido (`pDif`).
  final double rate;

  /// Valor diferido (`vDif`).
  final double value;
}

/// Devolução de tributo/cashback (`gDevTrib`).
class ReformRefund {
  /// Cria uma devolução com percentual opcional e valor fiscal.
  const ReformRefund({this.rate, required this.value});

  /// Percentual devolvido (`pDevTrib`), quando exigido pela regra.
  final double? rate;

  /// Valor devolvido (`vDevTrib`).
  final double value;
}

/// Redução de alíquota IBS/CBS (`gRed`).
class ReformReduction {
  /// Cria uma redução com percentual original e alíquota efetiva.
  const ReformReduction({required this.rate, required this.effectiveRate});

  /// Percentual de redução (`pRedAliq`).
  final double rate;

  /// Alíquota efetiva (`pAliqEfet`).
  final double effectiveRate;
}

/// Estorno de crédito de IBS/CBS (`gEstornoCred`).
class ReformCreditReversal {
  /// Cria os valores de IBS e CBS a estornar.
  const ReformCreditReversal({required this.ibsValue, required this.cbsValue});

  /// Valor do IBS a estornar (`vIBSEstCred`).
  final double ibsValue;

  /// Valor da CBS a estornar (`vCBSEstCred`).
  final double cbsValue;
}

/// Crédito presumido da operação (`gCredPresOper`).
class ReformPresumedCredit {
  /// Cria um crédito com percentual e valor ou condição suspensiva.
  const ReformPresumedCredit({
    required this.rate,
    required this.value,
    this.conditionalSuspension = false,
  });

  /// Percentual do crédito (`pCredPres`).
  final double rate;

  /// Valor do crédito (`vCredPres` ou `vCredPresCondSus`).
  final double value;

  /// Emite o valor na condição suspensiva.
  final bool conditionalSuspension;
}

/// Crédito presumido da operação aplicável ao IBS e/ou à CBS.
class ReformOperationCredit {
  /// Cria os dados do crédito presumido da operação.
  const ReformOperationCredit({
    required this.base,
    required this.code,
    this.ibs,
    this.cbs,
  });

  /// Base do crédito (`vBCCredPres`).
  final double base;

  /// Código de classificação do crédito (`cCredPres`).
  final String code;

  /// Crédito presumido de IBS, quando aproveitado pelo emitente.
  final ReformPresumedCredit? ibs;

  /// Crédito presumido de CBS, quando aproveitado pelo emitente.
  final ReformPresumedCredit? cbs;
}

/// Crédito presumido de IBS para fornecimentos a partir da ZFM.
class ReformZfmCredit {
  /// Cria os dados de apuração do crédito presumido ZFM.
  const ReformZfmCredit({
    required this.competence,
    required this.type,
    required this.value,
  });

  /// Competência da apuração (`competApur`).
  final DateTime competence;

  /// Classificação ZFM de `0` a `4` (`tpCredPresIBSZFM`).
  final String type;

  /// Crédito calculado sobre o saldo devedor (`vCredPresIBSZFM`).
  final double value;
}

/// Tributação regular aplicável caso uma condição suspensiva não seja cumprida.
class ReformRegularTax {
  /// Cria a tributação regular de IBS e CBS.
  const ReformRegularTax({
    required this.cst,
    required this.classificationCode,
    required this.ibsUfRate,
    required this.ibsUfValue,
    required this.ibsMunicipalRate,
    required this.ibsMunicipalValue,
    required this.cbsRate,
    required this.cbsValue,
  });

  /// CST regular (`CSTReg`).
  final String cst;

  /// Classificação tributária regular (`cClassTribReg`).
  final String classificationCode;

  /// Alíquota regular do IBS da UF.
  final double ibsUfRate;

  /// Valor regular do IBS da UF.
  final double ibsUfValue;

  /// Alíquota regular do IBS do município.
  final double ibsMunicipalRate;

  /// Valor regular do IBS do município.
  final double ibsMunicipalValue;

  /// Alíquota regular da CBS.
  final double cbsRate;

  /// Valor regular da CBS.
  final double cbsValue;
}

/// Tributação sem o redutor aplicável à compra governamental (`gTribCompraGov`).
class ReformGovernmentTax {
  /// Cria os valores de IBS e CBS da compra governamental.
  const ReformGovernmentTax({
    required this.ibsUfRate,
    required this.ibsUfValue,
    required this.ibsMunicipalRate,
    required this.ibsMunicipalValue,
    required this.cbsRate,
    required this.cbsValue,
  });

  /// Alíquota do IBS da UF (`pAliqIBSUF`).
  final double ibsUfRate;

  /// Valor do IBS devido à UF sem o redutor (`vTribIBSUF`).
  final double ibsUfValue;

  /// Alíquota do IBS do município (`pAliqIBSMun`).
  final double ibsMunicipalRate;

  /// Valor do IBS devido ao município sem o redutor (`vTribIBSMun`).
  final double ibsMunicipalValue;

  /// Alíquota da CBS (`pAliqCBS`).
  final double cbsRate;

  /// Valor da CBS sem o redutor (`vTribCBS`).
  final double cbsValue;
}

/// Tributação IBS/CBS por item conforme os grupos da NT 2025.002-RTC.
class IbsCbsTax {
  /// Cria uma tributação IBS/CBS com alíquotas informadas pela aplicação.
  const IbsCbsTax({
    required this.cst,
    required this.classificationCode,
    required this.base,
    required this.ibsUfRate,
    required this.ibsMunicipalRate,
    required this.cbsRate,
    this.donation,
    this.ibsUfDeferral,
    this.ibsUfRefund,
    this.ibsUfReduction,
    this.ibsMunicipalDeferral,
    this.ibsMunicipalRefund,
    this.ibsMunicipalReduction,
    this.cbsDeferral,
    this.cbsRefund,
    this.cbsReduction,
    this.creditReversal,
    this.operationCredit,
    this.zfmCredit,
    this.regularTax,
    this.governmentTax,
  });

  /// CST do IBS/CBS (`CST`).
  final String cst;

  /// Código de classificação tributária (`cClassTrib`).
  final String classificationCode;

  /// Base comum (`vBC`).
  final double base;

  /// Alíquota do IBS estadual (`pIBSUF`).
  final double ibsUfRate;

  /// Alíquota do IBS municipal (`pIBSMun`).
  final double ibsMunicipalRate;

  /// Alíquota da CBS (`pCBS`).
  final double cbsRate;

  /// Indica operação de doação (`indDoacao`), quando exigido pelo CST.
  final bool? donation;

  /// Diferimento opcional do IBS estadual.
  final ReformDeferral? ibsUfDeferral;

  /// Devolução opcional do IBS estadual.
  final ReformRefund? ibsUfRefund;

  /// Redução opcional do IBS estadual.
  final ReformReduction? ibsUfReduction;

  /// Diferimento opcional do IBS municipal.
  final ReformDeferral? ibsMunicipalDeferral;

  /// Devolução opcional do IBS municipal.
  final ReformRefund? ibsMunicipalRefund;

  /// Redução opcional do IBS municipal.
  final ReformReduction? ibsMunicipalReduction;

  /// Diferimento opcional da CBS.
  final ReformDeferral? cbsDeferral;

  /// Devolução opcional da CBS.
  final ReformRefund? cbsRefund;

  /// Redução opcional da CBS.
  final ReformReduction? cbsReduction;

  /// Estorno de crédito informado conforme a classificação tributária.
  final ReformCreditReversal? creditReversal;

  /// Crédito presumido específico da operação.
  final ReformOperationCredit? operationCredit;

  /// Crédito presumido de IBS calculado para a ZFM.
  final ReformZfmCredit? zfmCredit;

  /// Tributação regular para a condição resolutória/suspensiva.
  final ReformRegularTax? regularTax;

  /// Tributação sem redutor da compra governamental.
  final ReformGovernmentTax? governmentTax;

  /// IBS estadual calculado sem ponto flutuante.
  FiscalDecimal get ibsUfValue =>
      FiscalDecimal.fromNum(base).percentage(FiscalDecimal.fromNum(ibsUfRate));

  /// IBS municipal calculado sem ponto flutuante.
  FiscalDecimal get ibsMunicipalValue => FiscalDecimal.fromNum(
    base,
  ).percentage(FiscalDecimal.fromNum(ibsMunicipalRate));

  /// IBS total calculado sem ponto flutuante.
  FiscalDecimal get ibsValue => ibsUfValue + ibsMunicipalValue;

  /// CBS calculada sem ponto flutuante.
  FiscalDecimal get cbsValue =>
      FiscalDecimal.fromNum(base).percentage(FiscalDecimal.fromNum(cbsRate));
}

/// Imposto Seletivo por item, na forma básica da NT 2025.002-RTC.
class SelectiveTax {
  /// Cria um imposto seletivo com alíquota percentual.
  const SelectiveTax({
    required this.cst,
    required this.classificationCode,
    required this.base,
    required this.rate,
    this.adRemRate,
    this.unit,
    this.quantity,
  });

  /// CST do Imposto Seletivo (`CSTIS`).
  final String cst;

  /// Código de classificação do Imposto Seletivo (`cClassTribIS`).
  final String classificationCode;

  /// Base de cálculo (`vBC`).
  final double base;

  /// Alíquota percentual (`pIS`).
  final double rate;

  /// Alíquota específica por unidade (`adRemIS`), quando aplicável.
  final double? adRemRate;

  /// Unidade tributável da operação ad rem (`uTrib`).
  final String? unit;

  /// Quantidade tributável da operação ad rem (`qTrib`).
  final double? quantity;

  /// Valor calculado (`vIS`).
  FiscalDecimal get value => adRemRate != null && quantity != null
      ? FiscalDecimal.fromNum(quantity!) * FiscalDecimal.fromNum(adRemRate!)
      : FiscalDecimal.fromNum(base).percentage(FiscalDecimal.fromNum(rate));
}

/// Tributação monofásica padrão de IBS/CBS (`CST 620`).
///
/// Este modelo cobre os grupos ad rem e ad valorem da NT 2025.002. Os
/// valores são recebidos explicitamente para não presumir regras de cálculo
/// específicas do produto.
class IbsCbsMonophaseTax {
  /// Cria uma tributação monofásica padrão.
  const IbsCbsMonophaseTax({
    required this.cst,
    required this.classificationCode,
    this.quantity,
    this.ibsRate,
    this.ibsValue,
    this.cbsRate,
    this.cbsValue,
    this.ibsAdValoremBase,
    this.ibsAdValoremUfRate,
    this.ibsAdValoremUfValue,
    this.ibsAdValoremMunicipalRate,
    this.ibsAdValoremMunicipalValue,
    this.ibsAdValoremValue,
    this.cbsAdValoremBase,
    this.cbsAdValoremRate,
    this.cbsAdValoremValue,
    this.ibsBiofuelQuantity,
    this.ibsBiofuelDifference,
    this.cbsBiofuelQuantity,
    this.cbsBiofuelDifference,
    this.ibsRetainedQuantity,
    this.ibsRetainedRate,
    this.ibsRetainedValue,
    this.ibsPreviouslyRetainedValue,
    this.cbsRetainedQuantity,
    this.cbsRetainedRate,
    this.cbsRetainedValue,
    this.cbsPreviouslyRetainedValue,
  });

  /// CST do IBS/CBS, normalmente `620` para monofasia.
  final String cst;

  /// Classificação tributária oficial (`cClassTrib`).
  final String classificationCode;

  /// Quantidade tributada comum (`qBCMono`).
  final double? quantity;

  /// Alíquota ad rem do IBS (`adRemIBS`).
  final double? ibsRate;

  /// Valor do IBS monofásico (`vIBSMono`).
  final double? ibsValue;

  /// Alíquota ad rem da CBS (`adRemCBS`).
  final double? cbsRate;

  /// Valor da CBS monofásica (`vCBSMono`).
  final double? cbsValue;

  /// Base de cálculo do IBS monofásico ad valorem (`vBCMono`).
  final double? ibsAdValoremBase;

  /// Alíquota estadual do IBS monofásico ad valorem (`pAliqMonoUF`).
  final double? ibsAdValoremUfRate;

  /// Valor estadual do IBS monofásico ad valorem (`vIBSMonoUF`).
  final double? ibsAdValoremUfValue;

  /// Alíquota municipal do IBS monofásico ad valorem (`pAliqMonoMun`).
  final double? ibsAdValoremMunicipalRate;

  /// Valor municipal do IBS monofásico ad valorem (`vIBSMonoMun`).
  final double? ibsAdValoremMunicipalValue;

  /// Valor total do IBS monofásico ad valorem (`vIBSMono`).
  final double? ibsAdValoremValue;

  /// Base de cálculo da CBS monofásica ad valorem (`vBCMono`).
  final double? cbsAdValoremBase;

  /// Alíquota da CBS monofásica ad valorem (`pAliqMono`).
  final double? cbsAdValoremRate;

  /// Valor da CBS monofásica ad valorem (`vCBSMono`).
  final double? cbsAdValoremValue;

  /// Quantidade de biocombustível da diferença de mistura no IBS
  /// (`gpBioDiferenca/qBCBioComb`).
  final double? ibsBiofuelQuantity;

  /// Valor da diferença de IBS relativa ao percentual obrigatório
  /// (`gpBioDiferenca/vIBSDiferenca`).
  final double? ibsBiofuelDifference;

  /// Quantidade de biocombustível da diferença de mistura na CBS
  /// (`gpBioDiferenca/qBCBioComb`).
  final double? cbsBiofuelQuantity;

  /// Valor da diferença de CBS relativa ao percentual obrigatório
  /// (`gpBioDiferenca/vCBSDiferenca`).
  final double? cbsBiofuelDifference;

  /// Quantidade IBS sujeita à retenção (`qBCMonoReten`).
  final double? ibsRetainedQuantity;

  /// Alíquota IBS ad rem sujeita à retenção (`adRemIBSReten`).
  final double? ibsRetainedRate;

  /// Valor IBS monofásico sujeito à retenção (`vIBSMonoReten`).
  final double? ibsRetainedValue;

  /// Valor IBS monofásico retido anteriormente (`vIBSMonoRet`).
  final double? ibsPreviouslyRetainedValue;

  /// Quantidade CBS sujeita à retenção (`qBCMonoReten`).
  final double? cbsRetainedQuantity;

  /// Alíquota CBS ad rem sujeita à retenção (`adRemCBSReten`).
  final double? cbsRetainedRate;

  /// Valor CBS monofásico sujeito à retenção (`vCBSMonoReten`).
  final double? cbsRetainedValue;

  /// Valor CBS monofásico retido anteriormente (`vCBSMonoRet`).
  final double? cbsPreviouslyRetainedValue;

  /// Indica se há ao menos um grupo monofásico configurado.
  bool get hasIbs =>
      ibsRate != null ||
      ibsValue != null ||
      ibsAdValoremBase != null ||
      ibsBiofuelQuantity != null ||
      ibsBiofuelDifference != null;

  /// Indica se há grupo CBS monofásico configurado.
  bool get hasCbs =>
      cbsRate != null ||
      cbsValue != null ||
      cbsAdValoremBase != null ||
      cbsBiofuelQuantity != null ||
      cbsBiofuelDifference != null;

  /// Valor total do IBS monofásico, independentemente da modalidade.
  FiscalDecimal get totalIbsValue =>
      FiscalDecimal.fromNum(ibsAdValoremValue ?? ibsValue ?? 0);

  /// Valor total da CBS monofásica, independentemente da modalidade.
  FiscalDecimal get totalCbsValue =>
      FiscalDecimal.fromNum(cbsAdValoremValue ?? cbsValue ?? 0);
}
