import '../exceptions/fiscal_exception.dart';

/// Modalidades de emissão previstas para contingência da NF-e/NFC-e.
enum ContingencyMode {
  /// Emissão normal (`tpEmis=1`).
  normal(1),

  /// Formulário de segurança (`tpEmis=2`).
  fsIa(2),

  /// Formulário de segurança DANFE (`tpEmis=5`).
  fsDa(5),

  /// Serviço Virtual de Contingência Ambiente Nacional (`tpEmis=6`).
  svcAn(6),

  /// Serviço Virtual de Contingência Rio Grande do Sul (`tpEmis=7`).
  svcRs(7),

  /// Contingência offline NFC-e (`tpEmis=9`).
  offlineNfce(9);

  const ContingencyMode(this.code);

  /// Código fiscal `tpEmis`.
  final int code;
}

/// Configuração explícita de emissão em contingência.
class Contingency {
  /// Cria contingência SVC automaticamente conforme a UF do emitente.
  ///
  /// A tabela segue o roteamento de contingência do NFePHP. [mode] pode ser
  /// informado quando a aplicação já recebeu a modalidade autorizada; quando
  /// omitido, a biblioteca escolhe SVC-AN ou SVC-RS para [state].
  factory Contingency.forState({
    required String state,
    required DateTime activatedAt,
    required String reason,
    ContingencyMode? mode,
  }) {
    final normalized = state.trim().toUpperCase();
    final selected = mode ?? svcModeForState(normalized);
    return Contingency(
      mode: selected,
      activatedAt: activatedAt,
      reason: reason,
    );
  }

  /// Retorna o serviço virtual de contingência correspondente à [state].
  static ContingencyMode svcModeForState(String state) {
    final mode = _svcByState[state.trim().toUpperCase()];
    if (mode == null) {
      throw const FiscalValidationException(
        'UF inválida ou sem roteamento SVC de contingência conhecido.',
        code: 'INVALID_CONTINGENCY_STATE',
      );
    }
    return mode;
  }

  /// Cria uma configuração de contingência validada.
  Contingency({
    required this.mode,
    required this.activatedAt,
    required this.reason,
  }) {
    if (mode == ContingencyMode.normal) {
      throw const FiscalValidationException(
        'A configuração normal não deve ser criada como contingência.',
        code: 'INVALID_CONTINGENCY_MODE',
      );
    }
    if (reason.trim().length < 15) {
      throw const FiscalValidationException(
        'A justificativa da contingência deve possuir ao menos 15 caracteres.',
        code: 'INVALID_CONTINGENCY_REASON',
      );
    }
  }

  /// Modalidade de contingência.
  final ContingencyMode mode;

  /// Data e hora de entrada em contingência.
  final DateTime activatedAt;

  /// Justificativa fiscal.
  final String reason;

  /// Indica se o DANFE deve usar formulário de segurança.
  bool get requiresFsDa => mode == ContingencyMode.fsDa;

  static const _svcByState = <String, ContingencyMode>{
    'AC': ContingencyMode.svcAn,
    'AL': ContingencyMode.svcAn,
    'AM': ContingencyMode.svcAn,
    'AP': ContingencyMode.svcRs,
    'BA': ContingencyMode.svcRs,
    'CE': ContingencyMode.svcRs,
    'DF': ContingencyMode.svcAn,
    'ES': ContingencyMode.svcRs,
    'GO': ContingencyMode.svcRs,
    'MA': ContingencyMode.svcRs,
    'MG': ContingencyMode.svcAn,
    'MS': ContingencyMode.svcRs,
    'MT': ContingencyMode.svcRs,
    'PA': ContingencyMode.svcRs,
    'PB': ContingencyMode.svcAn,
    'PE': ContingencyMode.svcRs,
    'PI': ContingencyMode.svcRs,
    'PR': ContingencyMode.svcRs,
    'RJ': ContingencyMode.svcAn,
    'RN': ContingencyMode.svcRs,
    'RO': ContingencyMode.svcAn,
    'RR': ContingencyMode.svcAn,
    'RS': ContingencyMode.svcAn,
    'SC': ContingencyMode.svcAn,
    'SE': ContingencyMode.svcAn,
    'SP': ContingencyMode.svcAn,
    'TO': ContingencyMode.svcRs,
  };
}
