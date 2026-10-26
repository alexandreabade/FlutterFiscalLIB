/// Observação identificada por campo no grupo `obsCont` ou `obsFisco`.
class AdditionalObservation {
  /// Cria uma observação com nome de campo e texto.
  const AdditionalObservation({required this.field, required this.text});

  /// Identificador do campo (`xCampo`).
  final String field;

  /// Texto da observação (`xTexto`).
  final String text;
}

/// Processo referenciado no grupo `procRef`.
class ReferencedProcess {
  /// Cria um processo referenciado.
  const ReferencedProcess({required this.number, required this.indicator});

  /// Número ou descrição do processo (`nProc`).
  final String number;

  /// Indicador de origem do processo (`indProc`).
  final String indicator;
}

/// Pessoa autorizada a baixar o XML da NF-e (`autXML`).
class AuthorizedXmlDownload {
  /// Cria uma autorização por CNPJ ou CPF.
  const AuthorizedXmlDownload({this.cnpj, this.cpf});

  /// CNPJ autorizado.
  final String? cnpj;

  /// CPF autorizado.
  final String? cpf;
}

/// Informações adicionais que acompanham o documento fiscal.
class AdditionalInfo {
  /// Cria informações complementares.
  const AdditionalInfo({
    this.complementary,
    this.taxAuthority,
    this.contributorObservations = const [],
    this.fiscalObservations = const [],
    this.referencedProcesses = const [],
    this.authorizedXml = const [],
  });

  /// Informações de interesse do contribuinte.
  final String? complementary;

  /// Informações de interesse do fisco.
  final String? taxAuthority;

  /// Observações de interesse do contribuinte (`obsCont`).
  final List<AdditionalObservation> contributorObservations;

  /// Observações de interesse do fisco (`obsFisco`).
  final List<AdditionalObservation> fiscalObservations;

  /// Processos administrativos ou judiciais referenciados (`procRef`).
  final List<ReferencedProcess> referencedProcesses;

  /// Pessoas autorizadas a baixar o XML (`autXML`).
  final List<AuthorizedXmlDownload> authorizedXml;

  /// Indica se existe algum conteúdo para emitir.
  bool get isNotEmpty =>
      (complementary?.trim().isNotEmpty ?? false) ||
      (taxAuthority?.trim().isNotEmpty ?? false) ||
      contributorObservations.isNotEmpty ||
      fiscalObservations.isNotEmpty ||
      referencedProcesses.isNotEmpty ||
      authorizedXml.isNotEmpty;

  /// Indica se o grupo `infAdic` possui conteúdo próprio.
  bool get hasInfAdicContent =>
      (complementary?.trim().isNotEmpty ?? false) ||
      (taxAuthority?.trim().isNotEmpty ?? false) ||
      contributorObservations.isNotEmpty ||
      fiscalObservations.isNotEmpty ||
      referencedProcesses.isNotEmpty;
}
