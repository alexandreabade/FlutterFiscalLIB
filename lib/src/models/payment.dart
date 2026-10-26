/// Meio de pagamento informado no documento fiscal.
class Payment {
  /// Cria um pagamento.
  const Payment({
    required this.type,
    required this.value,
    this.indicator = 0,
    this.integration,
    this.brand,
    this.authorization,
    this.description,
  });

  /// Código fiscal do meio de pagamento (`tPag`).
  final String type;

  /// Valor pago.
  final double value;

  /// Indicador: 0 à vista, 1 a prazo.
  final int indicator;

  /// Integração do pagamento eletrônico (`tpIntegra`), 1 ou 2.
  final int? integration;

  /// Bandeira do cartão (`tBand`).
  final String? brand;

  /// Código de autorização (`cAut`).
  final String? authorization;

  /// Descrição de meio de pagamento (`xPag`).
  final String? description;
}
