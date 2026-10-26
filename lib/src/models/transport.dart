/// Informações de transporte da NF-e/NFC-e.
class TransportInfo {
  /// Cria informações de transporte.
  const TransportInfo({
    this.freightMode = 9,
    this.carrier,
    this.carrierName,
    this.carrierIe,
    this.carrierAddress,
    this.carrierCity,
    this.retention,
    this.vehiclePlate,
    this.vehicleState,
    this.vehicleRegistration,
    this.trailers = const [],
    this.railcar,
    this.barge,
    this.volumes = const [],
  });

  /// Modalidade do frete (`modFrete`).
  ///
  /// O valor 9 significa sem ocorrência de transporte e é o padrão quando
  /// nenhuma informação de transportador foi fornecida.
  final int freightMode;

  /// CNPJ/CPF do transportador, quando informado.
  final String? carrier;

  /// Nome/razão social do transportador (`xNome`).
  final String? carrierName;

  /// Inscrição estadual do transportador (`IE`).
  final String? carrierIe;

  /// Endereço do transportador (`xEnder`).
  final String? carrierAddress;

  /// Município do transportador (`xMun`).
  final String? carrierCity;

  /// Retenção de ICMS do serviço de transporte (`retTransp`).
  final TransportTaxRetention? retention;

  /// Placa do veículo, quando informada.
  final String? vehiclePlate;

  /// UF da placa, quando informada.
  final String? vehicleState;

  /// Registro Nacional de Transportadores de Carga (`RNTC`).
  final String? vehicleRegistration;

  /// Reboques/Dolly vinculados ao transporte.
  final List<TransportVehicle> trailers;

  /// Identificação do vagão ferroviário.
  final String? railcar;

  /// Identificação da balsa.
  final String? barge;

  /// Volumes transportados.
  final List<TransportVolume> volumes;
}

/// Veículo de transporte ou reboque (`veicTransp`/`reboque`).
class TransportVehicle {
  /// Cria a identificação de um veículo rodoviário.
  const TransportVehicle({required this.plate, this.state, this.registration});

  /// Placa do veículo.
  final String plate;

  /// UF da placa.
  final String? state;

  /// Registro nacional de transporte de carga.
  final String? registration;
}

/// Retenção de ICMS do transporte (`retTransp`).
class TransportTaxRetention {
  /// Cria os valores fiscais retidos no transporte.
  const TransportTaxRetention({
    required this.serviceValue,
    required this.taxBase,
    required this.rate,
    required this.taxValue,
    required this.cfop,
    required this.municipalityCode,
  });

  /// Valor do serviço (`vServ`).
  final double serviceValue;

  /// Base de cálculo retida (`vBCRet`).
  final double taxBase;

  /// Alíquota da retenção (`pICMSRet`).
  final double rate;

  /// Valor do ICMS retido (`vICMSRet`).
  final double taxValue;

  /// CFOP do transporte (`CFOP`).
  final String cfop;

  /// Município do fato gerador (`cMunFG`).
  final String municipalityCode;
}

/// Volume transportado (`vol`).
class TransportVolume {
  /// Cria um volume transportado.
  const TransportVolume({
    this.quantity,
    this.kind,
    this.brand,
    this.number,
    this.seal = const [],
  });

  /// Quantidade de volumes.
  final int? quantity;

  /// Espécie do volume.
  final String? kind;

  /// Marca do volume.
  final String? brand;

  /// Numeração do volume.
  final String? number;

  /// Lacres associados ao volume (`lacres`).
  final List<String> seal;
}
