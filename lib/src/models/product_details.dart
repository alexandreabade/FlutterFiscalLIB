import '../common/fiscal_decimal.dart';

/// Informações fiscais específicas de produto da NFF (`infProdNFF`).
class NffProductInfo {
  /// Cria os códigos fiscais e operacionais do item na NFF.
  const NffProductInfo({
    required this.fiscalProductCode,
    required this.operationCode,
  });

  /// Código fiscal do produto (`cProdFisco`), com 14 caracteres.
  final String fiscalProductCode;

  /// Código da operação relacionada ao item (`cOperNFF`).
  final String operationCode;
}

/// Informações de embalagem de produto da NFF (`infProdEmb`).
class EmbeddedProductInfo {
  /// Cria a descrição, volume e unidade da embalagem.
  const EmbeddedProductInfo({
    required this.description,
    required this.quantity,
    required this.unit,
  });

  /// Descrição da embalagem (`xEmb`).
  final String description;

  /// Volume do produto na embalagem (`qVolEmb`).
  final double quantity;

  /// Unidade de medida da embalagem (`uEmb`).
  final String unit;
}

/// Crédito presumido aplicado ao item (`gCred`) no leiaute vigente.
class PresumedCredit {
  /// Cria um crédito presumido com código, percentual e valor.
  const PresumedCredit({
    required this.code,
    required this.rate,
    required this.value,
  });

  /// Código do benefício de crédito presumido (`cCredPresumido`).
  final String code;

  /// Percentual do crédito (`pCredPresumido`).
  final double rate;

  /// Valor do crédito (`vCredPresumido`).
  final double value;
}

/// Lote de rastreabilidade de um produto (`rastro`).
class ProductTraceability {
  /// Cria um lote com fabricação, validade e quantidade.
  const ProductTraceability({
    required this.batchNumber,
    required this.quantity,
    required this.manufacturedAt,
    required this.expiresAt,
    this.aggregatedCode,
  });

  /// Número do lote (`nLote`).
  final String batchNumber;

  /// Quantidade do produto no lote (`qLote`).
  final double quantity;

  /// Data de fabricação (`dFab`).
  final DateTime manufacturedAt;

  /// Data de validade (`dVal`).
  final DateTime expiresAt;

  /// Código de agregação (`cAgreg`).
  final String? aggregatedCode;

  /// Quantidade em decimal exato.
  FiscalDecimal get quantityDecimal => FiscalDecimal.fromNum(quantity);
}

/// Detalhamento de medicamento (`med`).
class MedicationInfo {
  /// Cria os dados de registro ANVISA e preço máximo ao consumidor.
  const MedicationInfo({
    required this.anvisaProductCode,
    this.exemptionReason,
    required this.maximumConsumerPrice,
  });

  /// Registro ANVISA ou literal `ISENTO` (`cProdANVISA`).
  final String anvisaProductCode;

  /// Motivo/ato da isenção (`xMotivoIsencao`).
  final String? exemptionReason;

  /// Preço máximo ao consumidor (`vPMC`).
  final double maximumConsumerPrice;
}

/// Dados de combustíveis e produtos regulados pela ANP (`comb`).
class FuelInfo {
  /// Cria os dados do produto ANP e, opcionalmente, da CIDE/encerrante.
  const FuelInfo({
    required this.anpProductCode,
    required this.anpDescription,
    required this.consumptionState,
    this.glpPetroleumPercentage,
    this.nationalNaturalGasPercentage,
    this.importedNaturalGasPercentage,
    this.startingValue,
    this.codif,
    this.temperatureQuantity,
    this.cide,
    this.gauge,
    this.biofuelPercentage,
    this.origins = const [],
  });

  /// Código de produto da ANP (`cProdANP`).
  final String anpProductCode;

  /// Descrição ANP (`descANP`).
  final String anpDescription;

  /// Percentual de GLP derivado do petróleo (`pGLP`).
  final double? glpPetroleumPercentage;

  /// Percentual de gás natural nacional (`pGNn`).
  final double? nationalNaturalGasPercentage;

  /// Percentual de gás natural importado (`pGNi`).
  final double? importedNaturalGasPercentage;

  /// Valor de partida (`vPart`).
  final double? startingValue;

  /// Código CODIF.
  final String? codif;

  /// Quantidade faturada à temperatura ambiente (`qTemp`).
  final double? temperatureQuantity;

  /// UF de consumo (`UFCons`).
  final String consumptionState;

  /// Dados da CIDE, quando informados.
  final FuelCide? cide;

  /// Dados do encerrante de abastecimento.
  final FuelGauge? gauge;

  /// Percentual de biodiesel B100 no óleo diesel B (`pBio`).
  final double? biofuelPercentage;

  /// Origens nacionais/importadas do combustível (`origComb`).
  final List<FuelOrigin> origins;
}

/// Origem do combustível por UF, conforme o grupo `origComb`.
class FuelOrigin {
  /// Cria uma origem nacional ou importada do combustível.
  const FuelOrigin({
    required this.imported,
    required this.originState,
    required this.percentage,
  });

  /// Indica se a origem é importada (`indImport=1`).
  final bool imported;

  /// Código IBGE de dois dígitos da UF de origem (`cUFOrig`).
  final String originState;

  /// Percentual originário para a UF (`pOrig`).
  final double percentage;
}

/// CIDE vinculada ao combustível.
class FuelCide {
  /// Cria os valores de base, alíquota e contribuição.
  const FuelCide({
    required this.quantityBase,
    required this.rate,
    required this.value,
  });

  /// Base de cálculo em quantidade (`qBCProd`).
  final double quantityBase;

  /// Valor da alíquota (`vAliqProd`).
  final double rate;

  /// Valor da CIDE (`vCIDE`).
  final double value;
}

/// Encerrante/bomba/tanque do abastecimento.
class FuelGauge {
  /// Cria a leitura inicial e final do encerrante.
  const FuelGauge({
    required this.nozzle,
    required this.tank,
    required this.initialReading,
    required this.finalReading,
    this.pump,
  });

  /// Número do bico (`nBico`).
  final int nozzle;

  /// Número do tanque (`nTanque`).
  final int tank;

  /// Leitura inicial (`vEncIni`).
  final double initialReading;

  /// Leitura final (`vEncFin`).
  final double finalReading;

  /// Número da bomba (`nBomba`).
  final int? pump;
}

/// Dados de veículo novo (`veicProd`).
class NewVehicleInfo {
  /// Cria o detalhamento obrigatório de veículo novo do layout da NF-e.
  const NewVehicleInfo({
    required this.operationType,
    required this.chassis,
    required this.colorCode,
    required this.colorDescription,
    required this.power,
    required this.engineCapacity,
    required this.netWeight,
    required this.grossWeight,
    required this.serialNumber,
    required this.fuelType,
    required this.engineNumber,
    required this.maxTractionCapacity,
    required this.wheelbase,
    required this.modelYear,
    required this.manufactureYear,
    required this.paintType,
    required this.vehicleType,
    required this.vehicleSpecies,
    required this.vinStatus,
    required this.vehicleCondition,
    required this.brandModelCode,
    required this.denatranColorCode,
    required this.seatingCapacity,
    required this.restrictionType,
  });

  /// Tipo de operação RENAVAM (`tpOp`).
  final int operationType;

  /// Chassi/VIN (`chassi`).
  final String chassis;

  /// Código da cor da montadora (`cCor`).
  final String colorCode;

  /// Descrição da cor (`xCor`).
  final String colorDescription;

  /// Potência (`pot`).
  final String power;

  /// Cilindrada (`cilin`).
  final String engineCapacity;

  /// Peso líquido (`pesoL`).
  final String netWeight;

  /// Peso bruto (`pesoB`).
  final String grossWeight;

  /// Número de série (`nSerie`).
  final String serialNumber;

  /// Tipo de combustível (`tpComb`).
  final String fuelType;

  /// Número do motor (`nMotor`).
  final String engineNumber;

  /// Capacidade máxima de tração (`CMT`).
  final String maxTractionCapacity;

  /// Distância entre eixos (`dist`).
  final String wheelbase;

  /// Ano do modelo (`anoMod`).
  final int modelYear;

  /// Ano de fabricação (`anoFab`).
  final int manufactureYear;

  /// Tipo de pintura (`tpPint`).
  final String paintType;

  /// Tipo de veículo RENAVAM (`tpVeic`).
  final int vehicleType;

  /// Espécie do veículo (`espVeic`).
  final int vehicleSpecies;

  /// Situação do VIN (`VIN`): normal ou remarcado.
  final String vinStatus;

  /// Condição do veículo (`condVeic`).
  final int vehicleCondition;

  /// Código marca/modelo RENAVAM (`cMod`).
  final int brandModelCode;

  /// Código de cor DENATRAN (`cCorDENATRAN`).
  final int denatranColorCode;

  /// Lotação (`lota`).
  final int seatingCapacity;

  /// Restrição (`tpRest`).
  final int restrictionType;
}

/// Dados de armamento (`arma`).
class WeaponInfo {
  /// Cria o detalhamento de uma arma comercializada.
  const WeaponInfo({
    required this.type,
    required this.serialNumber,
    required this.barrelNumber,
    required this.description,
  });

  /// Tipo de arma: uso permitido (`0`) ou restrito (`1`).
  final int type;

  /// Número de série da arma.
  final String serialNumber;

  /// Número de série do cano.
  final String barrelNumber;

  /// Descrição completa da arma.
  final String description;
}
