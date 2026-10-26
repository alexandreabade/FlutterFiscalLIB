/// ICMS próprio nos grupos de tributação normal do leiaute 4.00.
class IcmsTax {
  /// Cria os valores de ICMS do item.
  const IcmsTax({
    required this.cst,
    required this.base,
    required this.rate,
    required this.value,
    this.origin = 0,
    this.modality = 3,
    this.reduction,
    this.benefitReductionCode,
    this.desonerationValue,
    this.desonerationReason,
    this.deductDesoneration,
    this.operationValue,
    this.differenceRate,
    this.differenceValue,
    this.retainedBase,
    this.retainedRate,
    this.retainedValue,
    this.substitutedValue,
    this.retainedFcpBase,
    this.retainedFcpRate,
    this.retainedFcpValue,
    this.effectiveReduction,
    this.effectiveBase,
    this.effectiveRate,
    this.effectiveValue,
    this.fcpBase,
    this.fcpRate,
    this.fcpValue,
    this.fcpDifferenceRate,
    this.fcpDifferenceValue,
    this.fcpEffectiveValue,
  });

  /// CST de ICMS com dois dígitos (`00`, `20`, `40`, `41`, `50`, `51`,
  /// `60` ou `90`).
  final String cst;

  /// Origem da mercadoria (`orig`).
  final int origin;

  /// Base de cálculo.
  final double base;

  /// Alíquota percentual.
  final double rate;

  /// Valor do imposto.
  final double value;

  /// Modalidade da base de cálculo (`modBC`).
  final int modality;

  /// Percentual de redução da base (`pRedBC`), quando aplicável.
  final double? reduction;

  /// Código de benefício fiscal quando houver redução de base (`cBenefRBC`).
  final String? benefitReductionCode;

  /// Valor e motivo da desoneração (`vICMSDeson`/`motDesICMS`).
  final double? desonerationValue;

  /// Motivo legal da desoneração (`motDesICMS`).
  final int? desonerationReason;

  /// Indica se a desoneração deduz o valor do item (`indDeduzDeson`).
  final bool? deductDesoneration;

  /// Valores opcionais do diferimento (`vICMSOp`/`pDif`/`vICMSDif`).
  final double? operationValue;

  /// Percentual diferido (`pDif`).
  final double? differenceRate;

  /// Valor do ICMS diferido (`vICMSDif`).
  final double? differenceValue;

  /// Valores do ICMS-ST retido anteriormente (`ICMS60`).
  final double? retainedBase;

  /// Alíquota suportada pelo consumidor (`pST`).
  final double? retainedRate;

  /// Valor do ICMS-ST retido (`vICMSSTRet`).
  final double? retainedValue;

  /// Valor do ICMS próprio do substituto cobrado anteriormente.
  final double? substitutedValue;

  /// Base de cálculo do FCP-ST retido (`vBCFCPSTRet`).
  final double? retainedFcpBase;

  /// Alíquota do FCP-ST retido (`pFCPSTRet`).
  final double? retainedFcpRate;

  /// Valor do FCP-ST retido (`vFCPSTRet`).
  final double? retainedFcpValue;

  /// Percentual de redução da base efetiva (`pRedBCEfet`).
  final double? effectiveReduction;

  /// Base de cálculo efetiva (`vBCEfet`).
  final double? effectiveBase;

  /// Alíquota efetiva (`pICMSEfet`).
  final double? effectiveRate;

  /// Valor efetivo (`vICMSEfet`).
  final double? effectiveValue;

  /// Base de cálculo do FCP, quando aplicável.
  final double? fcpBase;

  /// Alíquota do FCP, quando aplicável.
  final double? fcpRate;

  /// Valor do FCP, quando aplicável.
  final double? fcpValue;

  /// Percentual do FCP diferido (`pFCPDif`) no ICMS51.
  final double? fcpDifferenceRate;

  /// Valor do FCP diferido (`vFCPDif`) no ICMS51.
  final double? fcpDifferenceValue;

  /// Valor efetivo do FCP (`vFCPEfet`) no ICMS51.
  final double? fcpEffectiveValue;
}

/// ICMS tributado com cobrança de substituição tributária (`ICMS10`).
class IcmsStTax {
  /// Cria os valores do ICMS próprio e do ICMS-ST.
  const IcmsStTax({
    this.cst = '10',
    this.origin = 0,
    required this.base,
    required this.rate,
    required this.value,
    required this.stBase,
    required this.stRate,
    required this.stValue,
    this.ownModality = 3,
    this.modality = 4,
    this.mva,
    this.ownReduction,
    this.reduction,
    this.fcpBase,
    this.fcpRate,
    this.fcpValue,
    this.fcpStBase,
    this.fcpStRate,
    this.fcpStValue,
    this.operationRate,
    this.destinationState,
    this.stOnly = false,
    this.desonerationValue,
    this.desonerationReason,
    this.ownDesonerationValue,
    this.ownDesonerationReason,
    this.deductDesoneration,
    this.stDesonerationValue,
    this.stDesonerationReason,
  });

  /// CST do grupo de ICMS com substituição tributária.
  final String cst;

  /// Origem da mercadoria (`orig`).
  final int origin;

  /// Base, alíquota e valor do ICMS próprio.
  final double base;

  /// Alíquota do ICMS próprio.
  final double rate;

  /// Valor do ICMS próprio.
  final double value;

  /// Modalidade da base de cálculo do ICMS-ST (`modBCST`).
  final int modality;

  /// Margem de valor agregado, quando aplicável.
  final double? mva;

  /// Redução da base do ICMS-ST, quando aplicável.
  final double? reduction;

  /// Base, alíquota e valor do ICMS-ST.
  final double stBase;

  /// Alíquota do ICMS-ST.
  final double stRate;

  /// Valor do ICMS-ST.
  final double stValue;

  /// Modalidade da base própria (`modBC`).
  final int ownModality;

  /// Percentual de redução da base própria (`pRedBC`).
  final double? ownReduction;

  /// Base, alíquota e valor do FCP próprio.
  final double? fcpBase;

  /// Alíquota do FCP próprio.
  final double? fcpRate;

  /// Valor do FCP próprio.
  final double? fcpValue;

  /// Base, alíquota e valor do FCP-ST.
  final double? fcpStBase;

  /// Alíquota do FCP-ST.
  final double? fcpStRate;

  /// Valor do FCP-ST.
  final double? fcpStValue;

  /// Percentual da operação própria para o cálculo do ICMS-ST (`pBCOp`).
  final double? operationRate;

  /// UF do substituto tributário (`UFST`).
  final String? destinationState;

  /// Indica o grupo `ICMSST`, sem tributação própria (`N05`).
  final bool stOnly;

  /// Valor desonerado no grupo `ICMSST`.
  final double? desonerationValue;

  /// Motivo da desoneração no grupo `ICMSST`.
  final int? desonerationReason;

  /// Valor desonerado do ICMS próprio no `ICMS70` (`vICMSDeson`).
  final double? ownDesonerationValue;

  /// Motivo da desoneração do ICMS próprio no `ICMS70`.
  final int? ownDesonerationReason;

  /// Indica se a desoneração própria deduz o valor do item.
  final bool? deductDesoneration;

  /// Valor desonerado do ICMS-ST no `ICMS70` (`vICMSSTDeson`).
  final double? stDesonerationValue;

  /// Motivo da desoneração do ICMS-ST no `ICMS70`.
  final int? stDesonerationReason;
}

/// ICMS-ST retido anteriormente e devido no destino (`N10B`/`ICMSST`).
class IcmsStRetainedTax {
  /// Cria os valores retidos, de destino e efetivos do ICMS-ST.
  const IcmsStRetainedTax({
    required this.origin,
    required this.cst,
    required this.retainedBase,
    required this.retainedValue,
    required this.destinationBase,
    required this.destinationValue,
    this.retainedRate,
    this.retainedFcpBase,
    this.retainedFcpRate,
    this.retainedFcpValue,
    this.substitutionRate,
    this.substitutedValue,
    this.effectiveReduction,
    this.effectiveBase,
    this.effectiveRate,
    this.effectiveValue,
  });

  /// Origem da mercadoria (`orig`).
  final int origin;

  /// CST do grupo (`CST`).
  final String cst;

  /// Base do ICMS-ST retido (`vBCSTRet`).
  final double retainedBase;

  /// Alíquota suportada no cálculo retido (`pST`).
  final double? retainedRate;

  /// Valor do ICMS-ST retido (`vICMSSTRet`).
  final double retainedValue;

  /// Base do FCP-ST retido (`vBCFCPSTRet`).
  final double? retainedFcpBase;

  /// Alíquota do FCP-ST retido (`pFCPSTRet`).
  final double? retainedFcpRate;

  /// Valor do FCP-ST retido (`vFCPSTRet`).
  final double? retainedFcpValue;

  /// Base do ICMS-ST no destino (`vBCSTDest`).
  final double destinationBase;

  /// Valor do ICMS-ST no destino (`vICMSSTDest`).
  final double destinationValue;

  /// Alíquota do ICMS substituto (`pICMSSubstituto`).
  final double? substitutionRate;

  /// Valor do ICMS substituto (`vICMSSubstituto`).
  final double? substitutedValue;

  /// Redução da base efetiva (`pRedBCEfet`).
  final double? effectiveReduction;

  /// Base efetiva (`vBCEfet`).
  final double? effectiveBase;

  /// Alíquota efetiva (`pICMSEfet`).
  final double? effectiveRate;

  /// Valor efetivo (`vICMSEfet`).
  final double? effectiveValue;
}

/// Partilha do ICMS entre a UF de origem e a UF de destino (`ICMSPart`).
class IcmsPartTax {
  /// Cria os valores próprios e de substituição da partilha.
  const IcmsPartTax({
    required this.cst,
    required this.base,
    required this.rate,
    required this.value,
    required this.stBase,
    required this.stRate,
    required this.stValue,
    required this.operationRate,
    required this.destinationState,
    this.origin = 0,
    this.modality = 3,
    this.reduction,
    this.stModality = 4,
    this.mva,
    this.stReduction,
  });

  /// CST da partilha (`10` ou `90`).
  final String cst;

  /// Origem da mercadoria.
  final int origin;

  /// Base, alíquota e valor do ICMS próprio.
  final double base;

  /// Alíquota do ICMS próprio.
  final double rate;

  /// Valor do ICMS próprio.
  final double value;

  /// Modalidade e redução da base própria.
  final int modality;

  /// Percentual de redução da base própria.
  final double? reduction;

  /// Modalidade, MVA, redução, base, alíquota e valor do ICMS-ST.
  final int stModality;

  /// Margem de valor agregado do ICMS-ST.
  final double? mva;

  /// Percentual de redução da base do ICMS-ST.
  final double? stReduction;

  /// Base do ICMS-ST.
  final double stBase;

  /// Alíquota do ICMS-ST.
  final double stRate;

  /// Valor do ICMS-ST.
  final double stValue;

  /// Percentual da base da operação própria (`pBCOp`).
  final double operationRate;

  /// UF para a qual o ICMS-ST é devido (`UFST`).
  final String destinationState;
}

/// Partilha do ICMS para consumidor final não contribuinte (`ICMSUFDest`).
class IcmsUfDestinationTax {
  /// Cria os valores de partilha entre as UFs.
  const IcmsUfDestinationTax({
    required this.base,
    required this.destinationRate,
    required this.interstateRate,
    required this.partitionRate,
    required this.destinationValue,
    required this.originValue,
    this.fcpBase,
    this.fcpRate,
    this.fcpValue,
  });

  /// Base do ICMS na UF de destino.
  final double base;

  /// Base e alíquota do FCP na UF de destino.

  /// Base de cálculo do FCP na UF de destino.
  final double? fcpBase;

  /// Alíquota do FCP na UF de destino.
  final double? fcpRate;

  /// Valor do FCP na UF de destino.
  final double? fcpValue;

  /// Alíquota interna, interestadual e percentual de partilha.

  /// Alíquota interna da UF de destino.
  final double destinationRate;

  /// Alíquota interestadual.
  final double interstateRate;

  /// Percentual da partilha destinado à UF de destino.
  final double partitionRate;

  /// Valores destinados às UFs de destino e origem.

  /// Valor do ICMS destinado à UF de destino.
  final double destinationValue;

  /// Valor do ICMS destinado à UF de origem.
  final double originValue;
}

/// Imposto de importação do item (`II`).
class ImportTax {
  /// Cria os valores aduaneiros e o IOF.
  const ImportTax({
    required this.base,
    required this.customsExpenses,
    required this.value,
    required this.iof,
  });

  /// Base de cálculo do imposto de importação (`vBC`).
  final double base;

  /// Despesas aduaneiras (`vDespAdu`).
  final double customsExpenses;

  /// Valor do imposto de importação (`vII`).
  final double value;

  /// Valor do IOF (`vIOF`).
  final double iof;
}

/// PIS por substituição tributária (`PISST`).
class PisStTax {
  /// Cria PIS-ST por percentual ou por quantidade.
  const PisStTax({
    required this.value,
    this.base,
    this.rate,
    this.quantity,
    this.unitRate,
  });

  /// Valor do PIS-ST.
  final double value;

  /// Base e alíquota percentual, quando usados.

  /// Base de cálculo percentual do PIS-ST.
  final double? base;

  /// Alíquota percentual do PIS-ST.
  final double? rate;

  /// Quantidade e alíquota monetária por unidade, quando usados.

  /// Quantidade tributada do PIS-ST.
  final double? quantity;

  /// Alíquota monetária por unidade do PIS-ST.
  final double? unitRate;
}

/// COFINS por substituição tributária (`COFINSST`).
class CofinsStTax {
  /// Cria COFINS-ST por percentual ou por quantidade.
  const CofinsStTax({
    required this.value,
    this.base,
    this.rate,
    this.quantity,
    this.unitRate,
  });

  /// Valor da COFINS-ST.
  final double value;

  /// Base e alíquota percentual, quando usados.

  /// Base de cálculo percentual da COFINS-ST.
  final double? base;

  /// Alíquota percentual da COFINS-ST.
  final double? rate;

  /// Quantidade e alíquota monetária por unidade, quando usados.

  /// Quantidade tributada da COFINS-ST.
  final double? quantity;

  /// Alíquota monetária por unidade da COFINS-ST.
  final double? unitRate;
}

/// Informação de IPI devolvido no item (`impostoDevol`).
class IpiDevolution {
  /// Cria o percentual devolvido e o valor do IPI correspondente.
  const IpiDevolution({required this.percentage, required this.value});

  /// Percentual da mercadoria devolvida (`pDevol`).
  final double percentage;

  /// Valor do IPI devolvido (`vIPIDevol`).
  final double value;
}

/// ICMS do Simples Nacional nos grupos `ICMSSN101` a `ICMSSN900`.
class IcmsSimplesTax {
  /// Cria os valores de ICMS com CSOSN.
  const IcmsSimplesTax({
    required this.csosn,
    this.origin = 0,
    this.creditRate,
    this.creditValue,
    this.modality = 4,
    this.mva,
    this.reduction,
    this.base,
    this.rate,
    this.value,
    this.stBase,
    this.stRate,
    this.stValue,
    this.retainedBase,
    this.retainedRate,
    this.retainedValue,
    this.effectiveReduction,
    this.effectiveBase,
    this.effectiveRate,
    this.effectiveValue,
    this.substitutedValue,
    this.retainedFcpBase,
    this.retainedFcpRate,
    this.retainedFcpValue,
    this.fcpStBase,
    this.fcpStRate,
    this.fcpStValue,
  });

  /// Código de situação da operação no Simples Nacional.
  final String csosn;

  /// Origem da mercadoria (`orig`).
  final int origin;

  /// Crédito permitido nos CSOSN 101/201/900.
  final double? creditRate;

  /// Valor do crédito de ICMS do Simples Nacional.
  final double? creditValue;

  /// Modalidade, MVA e redução da base de ICMS-ST.
  final int modality;

  /// Margem de valor agregado da substituição tributária.
  final double? mva;

  /// Redução da base de cálculo da substituição tributária.
  final double? reduction;

  /// Base, alíquota e valor de ICMS no CSOSN 900.
  final double? base;

  /// Alíquota de ICMS no CSOSN 900.
  final double? rate;

  /// Valor de ICMS no CSOSN 900.
  final double? value;

  /// Base, alíquota e valor de ICMS-ST nos CSOSN 201/202/900.
  final double? stBase;

  /// Alíquota de ICMS-ST.
  final double? stRate;

  /// Valor de ICMS-ST.
  final double? stValue;

  /// ICMS-ST retido anteriormente no CSOSN 500.
  final double? retainedBase;

  /// Alíquota suportada pelo consumidor no CSOSN 500.
  final double? retainedRate;

  /// Valor retido anteriormente no CSOSN 500.
  final double? retainedValue;

  /// Percentual de redução da base efetiva do ICMS-ST (`pRedBCEfet`).
  final double? effectiveReduction;

  /// Base efetiva do ICMS-ST (`vBCEfet`).
  final double? effectiveBase;

  /// Alíquota efetiva do ICMS-ST (`pICMSEfet`).
  final double? effectiveRate;

  /// Valor efetivo do ICMS-ST (`vICMSEfet`).
  final double? effectiveValue;

  /// ICMS do substituto tributário (`vICMSSubstituto`).
  final double? substitutedValue;

  /// Base do FCP-ST retido anteriormente (`vBCFCPSTRet`).
  final double? retainedFcpBase;

  /// Alíquota do FCP-ST retido anteriormente (`pFCPSTRet`).
  final double? retainedFcpRate;

  /// Valor do FCP-ST retido anteriormente (`vFCPSTRet`).
  final double? retainedFcpValue;

  /// FCP-ST, quando informado junto ao ICMS-ST.
  final double? fcpStBase;

  /// Alíquota de FCP-ST.
  final double? fcpStRate;

  /// Valor de FCP-ST.
  final double? fcpStValue;
}

/// ICMS monofásico de combustíveis (`ICMS02`, `15`, `53` e `61`).
class IcmsMonophaseTax {
  /// Cria os valores do ICMS monofásico.
  const IcmsMonophaseTax({
    required this.cst,
    this.origin = 0,
    this.quantity,
    this.rate,
    this.value,
    this.retainedQuantity,
    this.retainedRate,
    this.retainedValue,
    this.operationValue,
    this.differenceRate,
    this.differenceValue,
    this.differenceQuantity,
    this.differenceAdRemRate,
    this.reductionRate,
    this.reductionReason,
  });

  /// CST monofásico (`02`, `15`, `53` ou `61`).
  final String cst;

  /// Origem da mercadoria.
  final int origin;

  /// Quantidade, alíquota ad rem e valor próprios.
  final double? quantity;

  /// Alíquota ad rem própria.
  final double? rate;

  /// Valor do ICMS monofásico próprio.
  final double? value;

  /// Quantidade, alíquota ad rem e valor retidos anteriormente.
  final double? retainedQuantity;

  /// Alíquota ad rem retida anteriormente.
  final double? retainedRate;

  /// Valor do ICMS monofásico retido anteriormente.
  final double? retainedValue;

  /// Valores de operação e diferimento do `ICMS53`.
  final double? operationValue;

  /// Percentual de diferimento (`pDif`).
  final double? differenceRate;

  /// Valor diferido (`vICMSMonoDif`).
  final double? differenceValue;

  /// Quantidade diferida (`qBCMonoDif`).
  final double? differenceQuantity;

  /// Alíquota ad rem diferida (`adRemICMSDif`).
  final double? differenceAdRemRate;

  /// Redução da alíquota ad rem do `ICMS15`.
  final double? reductionRate;

  /// Motivo legal da redução da alíquota ad rem.
  final int? reductionReason;
}

/// IPI tributado por base de cálculo (`IPITrib`).
class IpiTax {
  /// Cria os valores do IPI.
  const IpiTax({
    required this.enquadramento,
    required this.cst,
    required this.base,
    required this.rate,
    required this.value,
    this.quantity,
    this.unitRate,
  });

  /// Código de enquadramento legal (`cEnq`).
  final String enquadramento;

  /// CST do IPI tributado (`00`, `49`, `50`, `99`) ou não tributado
  /// (`01`, `02`, `03`, `04`, `05`, `51`, `52`, `53`, `54`, `55`).
  final String cst;

  /// Base de cálculo do IPI.
  final double base;

  /// Alíquota percentual do IPI.
  final double rate;

  /// Valor do IPI.
  final double value;

  /// Quantidade tributável quando o IPI é calculado por unidade (`qUnid`).
  final double? quantity;

  /// Valor do IPI por unidade (`vUnid`).
  final double? unitRate;
}

/// PIS em operação tributada com alíquota percentual (`PISAliq`).
class PisTax {
  /// Cria os valores de PIS do item.
  const PisTax({
    required this.cst,
    this.base,
    this.rate,
    this.value,
    this.quantity,
    this.unitRate,
  });

  /// Cria PIS não tributado (`PISNT`).
  const PisTax.nonTaxed({required this.cst})
    : base = null,
      rate = null,
      value = null,
      quantity = null,
      unitRate = null;

  /// CST de PIS.
  final String cst;

  /// Base de cálculo.
  final double? base;

  /// Alíquota percentual.
  final double? rate;

  /// Valor do imposto.
  final double? value;

  /// Quantidade e alíquota por unidade do grupo `PISQtde` (CST 03).
  final double? quantity;

  /// Alíquota monetária por unidade (`vAliqProd`).
  final double? unitRate;
}

/// COFINS em operação tributada com alíquota percentual (`COFINSAliq`).
class CofinsTax {
  /// Cria os valores de COFINS do item.
  const CofinsTax({
    required this.cst,
    this.base,
    this.rate,
    this.value,
    this.quantity,
    this.unitRate,
  });

  /// Cria COFINS não tributado (`COFINSNT`).
  const CofinsTax.nonTaxed({required this.cst})
    : base = null,
      rate = null,
      value = null,
      quantity = null,
      unitRate = null;

  /// CST de COFINS.
  final String cst;

  /// Base de cálculo.
  final double? base;

  /// Alíquota percentual.
  final double? rate;

  /// Valor do imposto.
  final double? value;

  /// Quantidade e alíquota por unidade do grupo `COFINSQtde` (CST 03).
  final double? quantity;

  /// Alíquota monetária por unidade (`vAliqProd`).
  final double? unitRate;
}

/// ISSQN incidente sobre um item de serviço (`ISSQN`).
class ServiceTax {
  /// Cria os dados fiscais do serviço.
  const ServiceTax({
    required this.base,
    required this.rate,
    required this.value,
    required this.municipalityCode,
    required this.serviceListCode,
    required this.competenceDate,
    this.exigibility = 1,
    this.deduction = 0,
    this.other = 0,
    this.unconditionalDiscount = 0,
    this.conditionalDiscount = 0,
    this.retained = 0,
    this.serviceCode,
    this.incidenceMunicipalityCode,
    this.incentive = false,
  });

  /// Base de cálculo do ISSQN.
  final double base;

  /// Alíquota percentual do ISSQN.
  final double rate;

  /// Valor do ISSQN.
  final double value;

  /// Município do fato gerador (`cMunFG`).
  final String municipalityCode;

  /// Item da lista de serviços da LC 116/03 (`cListServ`, formato `99.99`).
  final String serviceListCode;

  /// Data de competência do serviço.
  final DateTime competenceDate;

  /// Exigibilidade do ISS (`indISS`).
  final int exigibility;

  /// Dedução da base de cálculo (`vDeducao`).
  final double deduction;

  /// Outras retenções (`vOutro`).
  final double other;

  /// Desconto incondicionado (`vDescIncond`).
  final double unconditionalDiscount;

  /// Desconto condicionado (`vDescCond`).
  final double conditionalDiscount;

  /// ISS retido (`vISSRet`).
  final double retained;

  /// Código do serviço no município (`cServico`).
  final String? serviceCode;

  /// Município de incidência (`cMun`).
  final String? incidenceMunicipalityCode;

  /// Indica incentivo fiscal (`indIncentivo` 1/2).
  final bool incentive;
}
