/// Pessoa física ou jurídica participante do documento fiscal.
class Party {
  /// Cria um participante fiscal.
  const Party({
    required this.name,
    this.cnpj,
    this.cpf,
    this.foreignId,
    this.fantasyName,
    this.ie,
    this.ieSubstitute,
    this.municipalRegistration,
    this.cnae,
    this.suframa,
    this.recipientIeIndicator,
    this.address,
    this.addressNumber,
    this.addressComplement,
    this.neighborhood,
    this.cityCode,
    this.city,
    this.state,
    this.zipCode,
    this.phone,
    this.email,
    this.crt,
  }) : assert(
         cnpj != null || cpf != null || foreignId != null,
         'Informe CNPJ, CPF ou identificador estrangeiro.',
       );

  /// Razão social ou nome.
  final String name;

  /// CNPJ sem pontuação.
  final String? cnpj;

  /// CPF sem pontuação.
  final String? cpf;

  /// Identificador do destinatário estrangeiro (`idEstrangeiro`).
  final String? foreignId;

  /// Nome fantasia do emitente (`xFant`).
  final String? fantasyName;

  /// Inscrição estadual.
  final String? ie;

  /// Inscrição estadual de substituto tributário (`IEST`).
  final String? ieSubstitute;

  /// Inscrição municipal (`IM`).
  final String? municipalRegistration;

  /// CNAE fiscal com sete dígitos (`CNAE`).
  final String? cnae;

  /// Inscrição SUFRAMA (`ISUFEmit`/`ISUF`).
  final String? suframa;

  /// Indicador da inscrição estadual do destinatário (`indIEDest`).
  final int? recipientIeIndicator;

  /// Logradouro e número.
  final String? address;

  /// Número do endereço (`nro`).
  final String? addressNumber;

  /// Complemento do endereço (`xCpl`).
  final String? addressComplement;

  /// Bairro do endereço (`xBairro`).
  final String? neighborhood;

  /// Código IBGE do município.
  final String? cityCode;

  /// Nome do município.
  final String? city;

  /// UF com dois caracteres.
  final String? state;

  /// CEP sem pontuação.
  final String? zipCode;

  /// Telefone sem pontuação (`fone`).
  final String? phone;

  /// E-mail (`email`).
  final String? email;

  /// Código de regime tributário do emitente (`CRT`).
  final String? crt;

  /// Identificação fiscal disponível.
  String get taxId => cnpj ?? cpf ?? foreignId!;
}

/// Local fiscal de retirada ou entrega da mercadoria.
class NfeLocation {
  /// Cria um endereço fiscal de retirada/entrega.
  const NfeLocation({
    required this.street,
    required this.number,
    required this.neighborhood,
    required this.municipalityCode,
    required this.municipality,
    required this.state,
    this.name,
    this.cnpj,
    this.cpf,
    this.complement,
    this.zipCode,
    this.countryCode,
    this.country,
    this.phone,
    this.email,
    this.ie,
  });

  /// Nome do responsável pelo local (`xNome`).
  final String? name;

  /// CNPJ do local.
  final String? cnpj;

  /// CPF do local.
  final String? cpf;

  /// Logradouro (`xLgr`).
  final String street;

  /// Número (`nro`).
  final String number;

  /// Complemento (`xCpl`).
  final String? complement;

  /// Bairro (`xBairro`).
  final String neighborhood;

  /// Código IBGE do município (`cMun`).
  final String municipalityCode;

  /// Nome do município (`xMun`).
  final String municipality;

  /// UF (`UF`).
  final String state;

  /// CEP (`CEP`).
  final String? zipCode;

  /// Código do país (`cPais`).
  final String? countryCode;

  /// Nome do país (`xPais`).
  final String? country;

  /// Telefone (`fone`).
  final String? phone;

  /// E-mail (`email`).
  final String? email;

  /// Inscrição estadual (`IE`).
  final String? ie;
}
