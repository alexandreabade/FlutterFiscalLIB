/// Dados suplementares da NFC-e exigidos pelo leiaute quando o QR Code é
/// transportado no XML (`infNFeSupl`).
class NfceXmlSupplement {
  /// Cria o suplemento com QR Code e URL pública da chave.
  const NfceXmlSupplement({required this.qrCode, required this.keyUrl});

  /// Conteúdo da tag `qrCode`.
  final String qrCode;

  /// URL da consulta da chave (`urlChave`).
  final String keyUrl;
}
