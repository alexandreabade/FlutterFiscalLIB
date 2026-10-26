import '../models/nfe_document.dart';
import '../models/nfe_item.dart';
import '../models/party.dart';
import '../models/nfe_complements.dart';
import '../common/fiscal_decimal.dart';

/// Renderiza uma representação textual determinística do DANFE.
///
/// Esta saída é adequada para diagnóstico, terminal e testes. Não substitui o
/// DANFE auxiliar impresso em PDF nem valida requisitos gráficos oficiais.
class DanfeTextRenderer {
  /// Gera o texto do documento fiscal.
  String render(NfeDocument document) {
    final lines = <String>[
      'DANFE - DOCUMENTO AUXILIAR DA NF-E',
      if (document.environment == 2)
        'SEM VALOR FISCAL - AMBIENTE DE HOMOLOGAÇÃO',
      'MODELO ${document.model}  SÉRIE ${document.series}  NÚMERO ${document.number}',
      'CHAVE: ${document.accessKey}',
      'EMISSÃO: ${document.issueDate.toIso8601String()}',
      if (document.departureDate != null)
        'SAÍDA/ENTRADA: ${document.departureDate!.toIso8601String()}',
      if (document.deliveryForecast != null)
        'PREVISÃO DE ENTREGA: ${document.deliveryForecast!.toIso8601String()}',
      if (document.ibsMunicipalityCode != null)
        'MUNICÍPIO FATO GERADOR IBS/CBS: ${document.ibsMunicipalityCode}',
      'EMITENTE: ${document.issuer.name} - ${document.issuer.taxId}',
      if (document.issuer.fantasyName != null)
        'FANTASIA: ${document.issuer.fantasyName}',
      if (document.issuer.ie != null) 'IE EMITENTE: ${document.issuer.ie}',
      if (document.issuer.address != null)
        'ENDEREÇO EMITENTE: ${_partyAddress(document.issuer)}',
      if (document.issuer.phone != null)
        'FONE EMITENTE: ${document.issuer.phone}',
      if (document.issuer.email != null)
        'E-MAIL EMITENTE: ${document.issuer.email}',
      if (document.avulsa != null) 'EMISSÃO AVULSA: ${_avulsaText(document)}',
      if (document.recipient != null)
        'DESTINATÁRIO: ${document.recipient!.name} - ${document.recipient!.taxId}',
      if (document.recipient?.ie != null)
        'IE DESTINATÁRIO: ${document.recipient!.ie}',
      if (document.recipient?.address != null)
        'ENDEREÇO DESTINATÁRIO: ${_partyAddress(document.recipient!)}',
      if (document.recipient?.phone != null)
        'FONE DESTINATÁRIO: ${document.recipient!.phone}',
      if (document.recipient?.email != null)
        'E-MAIL DESTINATÁRIO: ${document.recipient!.email}',
      if (document.recipient?.city != null)
        'MUNICÍPIO DESTINATÁRIO: ${document.recipient!.city}/${document.recipient!.state ?? ''}',
      if (document.withdrawal != null)
        'RETIRADA: ${_locationText(document.withdrawal!)}',
      if (document.delivery != null)
        'ENTREGA: ${_locationText(document.delivery!)}',
      '',
      'ITENS',
      'Nº | CÓDIGO | DESCRIÇÃO | QTD | UN | V.UNIT | TOTAL',
    ];
    for (final item in document.items) {
      lines.add(
        '${item.number} | ${item.code} | ${_itemDescription(item)} | '
        '${FiscalDecimal.fromNum(item.quantity).toFixed(4)} | ${item.unit} | '
        '${FiscalDecimal.fromNum(item.unitPrice).toFixed(2)} | ${item.merchandiseTotalFormatted}',
      );
      if (item.approximateTaxValue != null) {
        lines.add(
          '  TRIBUTOS APROXIMADOS DO ITEM: '
          '${FiscalDecimal.fromNum(item.approximateTaxValue!).toFixed(2)}',
        );
      }
      if (item.ibsCbs != null) {
        lines.add(
          '  IBS UF: ${item.ibsCbs!.ibsUfValue.toFixed(2)} | '
          'IBS MUNICIPAL: ${item.ibsCbs!.ibsMunicipalValue.toFixed(2)} | '
          'CBS: ${item.ibsCbs!.cbsValue.toFixed(2)}',
        );
      }
      if (item.ibsCbsMonophase != null) {
        lines.add(
          '  IBS MONOFÁSICO: ${item.ibsCbsMonophase!.totalIbsValue.toFixed(2)} | '
          'CBS MONOFÁSICA: ${item.ibsCbsMonophase!.totalCbsValue.toFixed(2)}',
        );
      }
      if (item.selectiveTax != null) {
        lines.add('  IMPOSTO SELETIVO: ${item.selectiveTax!.value.toFixed(2)}');
      }
    }
    lines.addAll([
      '',
      'TOTAL DA NOTA: ${document.totalFormatted}',
      if (document.serviceTotal != null)
        'ISSQN DECLARADO: ${FiscalDecimal.fromNum(document.serviceTotal!.taxValue).toFixed(2)}',
      if (document.taxRetention != null)
        'RETENÇÕES FEDERAIS: ${_retentionTotal(document.taxRetention!).toFixed(2)}',
      if (document.contingency != null)
        'CONTINGÊNCIA: ${document.contingency!.mode.code} - ${document.contingency!.reason}',
      if (document.model == 65 && document.nfceSupplement != null) ...[
        'QR CODE NFC-e: ${document.nfceSupplement!.qrCode}',
        'URL DA CHAVE: ${document.nfceSupplement!.keyUrl}',
      ],
      'PAGAMENTOS: ${document.paymentTotalFormatted}',
      for (final payment in document.payments)
        '  ${payment.type}${payment.description == null ? '' : ' - ${payment.description}'}: ${FiscalDecimal.fromNum(payment.value).toFixed(2)}',
      if (document.changeValue != null)
        'TROCO: ${FiscalDecimal.fromNum(document.changeValue!).toFixed(2)}',
    ]);
    return lines.join('\n');
  }

  String _avulsaText(NfeDocument document) {
    final avulsa = document.avulsa!;
    return 'Órgão ${avulsa.agency} - Agente ${avulsa.agent} - '
        'UF ${avulsa.state} - Repartição ${avulsa.fiscalOffice}';
  }

  String _partyAddress(Party party) => [
    party.address,
    party.addressNumber,
    party.addressComplement,
    party.neighborhood,
    party.city,
    party.state,
    party.zipCode,
  ].whereType<String>().where((part) => part.isNotEmpty).join(', ');

  String _locationText(NfeLocation location) => [
    if (location.name != null) location.name!,
    location.street,
    location.number,
    if (location.complement != null) location.complement!,
    location.neighborhood,
    location.municipality,
    location.state,
    if (location.zipCode != null) location.zipCode!,
    if (location.cnpj != null) 'CNPJ ${location.cnpj}',
    if (location.cpf != null) 'CPF ${location.cpf}',
  ].join(', ');

  String _itemDescription(NfeItem item) => [
    item.description,
    if (item.additionalInformation != null) item.additionalInformation!,
    for (final batch in item.traceability)
      'Lote ${batch.batchNumber} Fab. ${batch.manufacturedAt.day.toString().padLeft(2, '0')}/${batch.manufacturedAt.month.toString().padLeft(2, '0')}/${batch.manufacturedAt.year} Val. ${batch.expiresAt.day.toString().padLeft(2, '0')}/${batch.expiresAt.month.toString().padLeft(2, '0')}/${batch.expiresAt.year}',
    if (item.medication != null)
      'ANVISA ${item.medication!.anvisaProductCode} PMC ${FiscalDecimal.fromNum(item.medication!.maximumConsumerPrice).toFixed(2)}',
  ].join(' / ');

  FiscalDecimal _retentionTotal(TaxRetention retention) =>
      FiscalDecimal.fromNum(retention.pis) +
      FiscalDecimal.fromNum(retention.cofins) +
      FiscalDecimal.fromNum(retention.csll) +
      FiscalDecimal.fromNum(retention.irrf) +
      FiscalDecimal.fromNum(retention.socialSecurity);
}
