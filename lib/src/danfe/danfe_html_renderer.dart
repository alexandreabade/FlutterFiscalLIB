import '../models/nfe_document.dart';
import '../models/nfe_item.dart';
import '../models/party.dart';
import '../models/additional_info.dart';
import '../models/nfe_complements.dart';
import '../models/taxes.dart';
import '../common/fiscal_decimal.dart';
import 'package:qr/qr.dart';
import 'package:barcode/barcode.dart';

/// Opções visuais do DANFE HTML.
class DanfeHtmlOptions {
  /// Cria opções sem alterar o XML ou o estado fiscal do documento.
  const DanfeHtmlOptions({
    this.canceled = false,
    this.title = 'DANFE - Documento Auxiliar da NF-e',
    this.quantityDecimals = 4,
    this.unitPriceDecimals = 2,
    this.showPisCofins = false,
    this.showApproximateTaxes = true,
    this.showInterstateTaxes = true,
    this.showItemAdditionalInfo = true,
    this.showItemTraceability = true,
    this.showItemTaxDetails = false,
    this.showTaxableUnit = true,
    this.generateAutomaticInfo = false,
    this.showBillingText = false,
    this.showPurchaseOrderItem = false,
    this.showContributorObservations = true,
    this.showFiscalObservations = true,
    this.epecProtocol,
    this.epecDate,
  }) : assert(quantityDecimals >= 0 && quantityDecimals <= 6),
       assert(unitPriceDecimals >= 0 && unitPriceDecimals <= 6);

  /// Exibe uma marca de documento cancelado na representação auxiliar.
  final bool canceled;

  /// Título principal da representação HTML.
  final String title;

  /// Casas decimais da quantidade comercial exibida.
  final int quantityDecimals;

  /// Casas decimais do preço unitário comercial exibido.
  final int unitPriceDecimals;

  /// Exibe PIS e COFINS no quadro de totais.
  final bool showPisCofins;

  /// Exibe a linha de tributos aproximados no quadro de totais.
  final bool showApproximateTaxes;

  /// Concatena tributos aproximados e benefício fiscal na descrição do item.
  /// Corresponde a `descProdInfoComplemento` do `sped-da`.
  final bool showItemTaxDetails;

  /// Exibe os valores de ICMS interestadual da partilha `ICMSUFDest`.
  final bool showInterstateTaxes;

  /// Inclui `infAdProd` na descrição dos itens.
  final bool showItemAdditionalInfo;

  /// Inclui lote, fabricação e validade na descrição dos itens.
  final bool showItemTraceability;

  /// Exibe unidade, quantidade e preço tributáveis quando informados.
  final bool showTaxableUnit;

  /// Gera textos derivados de compra, referências e tributos aproximados.
  final bool generateAutomaticInfo;

  /// Exibe o texto resumido de pagamento/fatura quando não há duplicatas.
  /// Corresponde a `exibirTextoFatura` do `sped-da`.
  final bool showBillingText;

  /// Exibe o pedido e o número do item do pedido de compra na descrição.
  /// Corresponde a `exibirNumeroItemPedido` do `sped-da`.
  final bool showPurchaseOrderItem;

  /// Exibe observações `obsCont`.
  final bool showContributorObservations;

  /// Exibe observações `obsFisco`.
  final bool showFiscalObservations;

  /// Protocolo EPEC apresentado no DANFE, quando fornecido pela aplicação.
  final String? epecProtocol;

  /// Data de registro do EPEC apresentado no DANFE.
  final DateTime? epecDate;
}

/// Renderiza uma representação HTML imprimível do DANFE.
class DanfeHtmlRenderer {
  /// Gera HTML autocontido com cabeçalho, itens, totais e informações auxiliares.
  String render(
    NfeDocument document, {
    DanfeHtmlOptions options = const DanfeHtmlOptions(),
  }) {
    final rows = document.items
        .map(
          (item) =>
              '''
      <tr>
        <td>${item.number}</td>
        <td>${_escape(_itemCode(item))}</td>
        <td>${_escape(_itemDescription(item, showTaxableUnit: options.showTaxableUnit, showPurchaseOrderItem: options.showPurchaseOrderItem, showItemTaxDetails: options.showItemTaxDetails, showItemAdditionalInfo: options.showItemAdditionalInfo, showItemTraceability: options.showItemTraceability, taxableQuantityDecimals: options.quantityDecimals, taxableUnitPriceDecimals: options.unitPriceDecimals))}</td>
        <td>${_escape(item.ncm)}</td>
        <td>${_escape(_itemCst(item))}</td>
        <td>${_escape(item.cfop)}</td>
        <td>${FiscalDecimal.fromNum(item.quantity).toFixed(options.quantityDecimals)}</td>
        <td>${_escape(item.unit)}</td>
        <td>${FiscalDecimal.fromNum(item.unitPrice).toFixed(options.unitPriceDecimals)}</td>
              <td>${item.merchandiseTotalFormatted}</td>
              <td>${_itemIcmsBase(item)}</td>
              <td>${_itemIcmsValue(item)}</td>
              <td>${FiscalDecimal.fromNum(item.ipi?.value ?? 0).toFixed(2)}</td>
      </tr>''',
        )
        .join();
    final recipient = document.recipient;
    final issuerAddress = _address(document.issuer);
    final recipientAddress = recipient == null ? '' : _address(recipient);
    final operation = _operationHtml(document);
    final paymentRows = document.payments
        .map(
          (payment) =>
              '<tr><td>${_escape(payment.type)}</td><td>${_escape(payment.description ?? '')}</td><td>${FiscalDecimal.fromNum(payment.value).toFixed(2)}</td></tr>',
        )
        .join();
    final freight = _sumItems(document, (item) => item.freight);
    final insurance = _sumItems(document, (item) => item.insurance);
    final discount = _sumItems(document, (item) => item.discount);
    final other = _sumItems(document, (item) => item.other);
    final importDuty = _sumItems(document, (item) => item.importDuty);
    final icmsBase = _sumTax(
      document,
      (item) =>
          item.icms?.base ??
          item.icmsSt?.base ??
          item.icmsPart?.base ??
          item.icmsUfDestination?.base ??
          item.icmsSimples?.base,
    );
    final icms = _sumTax(
      document,
      (item) =>
          item.icms?.value ??
          item.icmsSt?.value ??
          item.icmsPart?.value ??
          item.icmsUfDestination?.destinationValue ??
          item.icmsSimples?.value,
    );
    final stBase = _sumTax(
      document,
      (item) => item.icmsSt?.stBase ?? item.icmsSimples?.stBase,
    );
    final ipi = _sumItems(document, (item) => item.ipi?.value ?? 0);
    final icmsSt = _sumItems(
      document,
      (item) => item.icmsSt?.stValue ?? item.icmsSimples?.stValue ?? 0,
    );
    final fcp = _sumItems(
      document,
      (item) =>
          item.icms?.fcpValue ??
          item.icmsSt?.fcpValue ??
          item.icmsSimples?.fcpStValue ??
          0,
    );
    final fcpSt = _sumItems(
      document,
      (item) => item.icmsSt?.fcpStValue ?? item.icmsSimples?.fcpStValue ?? 0,
    );
    final fcpStRetained = _sumItems(
      document,
      (item) => item.icmsStRetained?.retainedFcpValue ?? 0,
    );
    final icmsMonophase = _sumItems(
      document,
      (item) => item.icmsMonophase?.value ?? 0,
    );
    final icmsMonophaseRetained = _sumItems(
      document,
      (item) => item.icmsMonophase?.retainedValue ?? 0,
    );
    final icmsDestination = _sumInterstate(
      document,
      (tax) => tax?.destinationValue,
    );
    final icmsOrigin = _sumInterstate(document, (tax) => tax?.originValue);
    final fcpDestination = _sumInterstate(document, (tax) => tax?.fcpValue);
    final optionalTaxRows = [
      if (options.showPisCofins)
        '<tr><td>PIS</td><td class="number">${_sumTax(document, (item) => item.pis?.value).toFixed(2)}</td></tr><tr><td>COFINS</td><td class="number">${_sumTax(document, (item) => item.cofins?.value).toFixed(2)}</td></tr>',
      if (options.showApproximateTaxes)
        '<tr><td>Tributos aproximados</td><td class="number">${_sumApproximateTaxes(document).toFixed(2)}</td></tr>',
    ].join();
    return '''<!doctype html>
<html lang="pt-BR">
<head><meta charset="utf-8"><title>DANFE ${document.number}</title>
<style>body{font-family:Arial,sans-serif;font-size:12px;margin:24px;color:#111}header{border-bottom:2px solid #111;margin-bottom:12px}.grid{display:grid;grid-template-columns:1fr 1fr;gap:12px;margin:12px 0}.box{border:1px solid #777;padding:8px}.box h2{font-size:13px;margin:0 0 5px}table{border-collapse:collapse;width:100%;margin:10px 0}thead{display:table-header-group}thead .continuation th{background:#fff;font-size:10px;text-align:left}th,td{border:1px solid #777;padding:5px;text-align:left}th{background:#eee}tbody tr{break-inside:avoid;page-break-inside:avoid}.number{text-align:right}.total{text-align:right;font-size:16px;font-weight:bold;margin-top:12px}.muted{color:#555}.canceled-banner{border:2px solid #b00020;color:#b00020;font-size:18px;font-weight:bold;padding:10px;text-align:center;margin:12px 0}@media print{body{margin:10mm}header{break-after:avoid}.box{break-inside:avoid}}</style>
</head>
<body>
<header><h1>${_escape(options.title)}</h1>
${document.environment == 2 ? '<div class="box"><strong>SEM VALOR FISCAL - AMBIENTE DE HOMOLOGAÇÃO</strong></div>' : ''}
<div>Modelo ${document.model} | Série ${document.series} | Número ${document.number}</div>
<div>Chave: ${_escape(document.accessKey)}</div>
<div class="access-key-barcode" aria-label="Código de barras da chave de acesso">${_accessKeyBarcodeSvg(document.accessKey)}</div>
<div>Emitente: ${_escape(document.issuer.name)} - ${_escape(document.issuer.taxId)}</div>
${_partyDetailsHtml(document.issuer)}
${document.departureDate == null ? '' : '<div>Saída/entrada: ${_formatDateTime(document.departureDate!)}</div>'}
<div>${issuerAddress.isEmpty ? '' : 'Endereço: ${_escape(issuerAddress)}'}</div></header>
${options.canceled ? '<div class="canceled-banner">DOCUMENTO CANCELADO</div>' : ''}
${document.avulsa == null ? '' : _avulsaHtml(document)}
${document.authorization == null ? '' : '<section class="box"><h2>Protocolo de autorização</h2><div>Status: ${document.authorization!.status} - ${_escape(document.authorization!.reason)}</div><div>Protocolo: ${_escape(document.authorization!.protocol)}</div><div>Recebimento: ${_formatDateTime(document.authorization!.authorizedAt)}</div></section>'}
${options.epecProtocol == null ? '' : '<section class="box"><h2>Registro EPEC</h2><div>Protocolo: ${_escape(options.epecProtocol!)}</div><div>Data: ${_formatDateTime(options.epecDate ?? document.issueDate)}</div></section>'}
${recipient == null ? '' : '<section class="box"><h2>Destinatário</h2><div>${_escape(recipient.name)} - ${_escape(recipient.taxId)}</div><div>${recipientAddress.isEmpty ? '' : _escape(recipientAddress)}</div>${_partyDetailsHtml(recipient)}</section>'}
$operation
${document.billing == null ? '' : _billingHtml(document, options)}
<section class="grid">
<div class="box"><h2>Totais</h2><table><tr><td>BC ICMS</td><td class="number">${icmsBase.toFixed(2)}</td></tr><tr><td>ICMS</td><td class="number">${icms.toFixed(2)}</td></tr><tr><td>BC ICMS-ST</td><td class="number">${stBase.toFixed(2)}</td></tr><tr><td>ICMS-ST</td><td class="number">${icmsSt.toFixed(2)}</td></tr><tr><td>Produtos</td><td class="number">${_sumMerchandise(document).toFixed(2)}</td></tr><tr><td>Frete</td><td class="number">${freight.toFixed(2)}</td></tr><tr><td>Seguro</td><td class="number">${insurance.toFixed(2)}</td></tr><tr><td>Desconto</td><td class="number">${discount.toFixed(2)}</td></tr><tr><td>II</td><td class="number">${importDuty.toFixed(2)}</td></tr><tr><td>IPI</td><td class="number">${ipi.toFixed(2)}</td></tr><tr><td>Outros</td><td class="number">${other.toFixed(2)}</td></tr><tr><td>FCP</td><td class="number">${fcp.toFixed(2)}</td></tr><tr><td>FCP ST</td><td class="number">${fcpSt.toFixed(2)}</td></tr><tr><td>FCP ST retido</td><td class="number">${fcpStRetained.toFixed(2)}</td></tr><tr><td>ICMS monofásico</td><td class="number">${icmsMonophase.toFixed(2)}</td></tr><tr><td>ICMS mono. retido</td><td class="number">${icmsMonophaseRetained.toFixed(2)}</td></tr>${options.showInterstateTaxes ? '<tr><td>ICMS UF destino</td><td class="number">${icmsDestination.toFixed(2)}</td></tr><tr><td>ICMS UF origem</td><td class="number">${icmsOrigin.toFixed(2)}</td></tr><tr><td>FCP UF destino</td><td class="number">${fcpDestination.toFixed(2)}</td></tr>' : ''}$optionalTaxRows<tr><th>Total da nota</th><th class="number">${document.totalFormatted}</th></tr></table></div>
<div class="box"><h2>Pagamentos</h2>${document.payments.isEmpty ? '<div class="muted">Pagamento não informado</div>' : '<table><tr><th>Código</th><th>Descrição</th><th>Valor</th></tr>$paymentRows</table>'}</div>
</section>
${_reformTotalsHtml(document)}
${_hasIssqn(document) ? _issqnHtml(document) : ''}
${_transportHtml(document)}
<div class="total">Total da nota: ${document.totalFormatted}</div>
<table><thead><tr class="continuation"><th colspan="13">DANFE - CONTINUAÇÃO | NF-e ${document.number} | Série ${document.series} | Chave: ${_escape(document.accessKey)}${document.environment == 2 ? ' | HOMOLOGAÇÃO' : ''}</th></tr><tr><th>Nº</th><th>Código</th><th>Descrição</th><th>NCM</th><th>CST</th><th>CFOP</th><th>Qtd.</th><th>Un.</th><th>V. unit.</th><th>Total</th><th>BC ICMS</th><th>V. ICMS</th><th>V. IPI</th></tr></thead>
<tbody>$rows</tbody></table>
${_reformItemsHtml(document)}
${_hasAdditionalContent(document, options) ? _additionalHtml(document, options) : ''}
${document.model == 65 && document.nfceSupplement != null ? '<section class="qr-code"><h2>Consulta NFC-e</h2>${_qrSvg(document.nfceSupplement!.qrCode)}<p>QR Code: ${_escape(document.nfceSupplement!.qrCode)}</p><p>URL da chave: ${_escape(document.nfceSupplement!.keyUrl)}</p></section>' : ''}
</body></html>''';
  }

  String _qrSvg(String data) {
    final code = QrCode.fromData(
      data: data,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    final image = QrImage(code);
    final size = image.moduleCount;
    final path = StringBuffer();
    for (var row = 0; row < size; row++) {
      for (var column = 0; column < size; column++) {
        if (image.isDark(row, column)) {
          path.write('M${column + 4} ${row + 4}h1v1h-1z');
        }
      }
    }
    return '<svg xmlns="http://www.w3.org/2000/svg" '
        'viewBox="0 0 ${size + 8} ${size + 8}" '
        'width="180" height="180" role="img" '
        'aria-label="QR Code NFC-e"><rect width="100%" height="100%" '
        'fill="#fff"/><path fill="#000" d="${path.toString()}"/></svg>';
  }

  String _itemCst(NfeItem item) =>
      item.icms?.cst ??
      item.icmsSt?.cst ??
      item.icmsSimples?.csosn ??
      item.icmsMonophase?.cst ??
      item.icmsStRetained?.cst ??
      '-';

  String _itemIcmsBase(NfeItem item) {
    final base =
        item.icms?.base ??
        item.icmsSt?.base ??
        item.icmsPart?.base ??
        item.icmsUfDestination?.base ??
        item.icmsSimples?.base ??
        0;
    return FiscalDecimal.fromNum(base).toFixed(2);
  }

  String _itemIcmsValue(NfeItem item) {
    final value =
        item.icms?.value ??
        item.icmsSt?.value ??
        item.icmsPart?.value ??
        item.icmsUfDestination?.destinationValue ??
        item.icmsSimples?.value ??
        0;
    return FiscalDecimal.fromNum(value).toFixed(2);
  }

  String _accessKeyBarcodeSvg(String accessKey) => Barcode.code128(
    useCode128A: false,
    useCode128B: false,
  ).toSvg(accessKey, width: 520, height: 72, fontHeight: 12);

  String _billingHtml(NfeDocument document, DanfeHtmlOptions options) {
    final billing = document.billing!;
    final paymentIndicator = document.payments.isEmpty
        ? null
        : document.payments.first.indicator;
    final installments = billing.installments
        .map(
          (item) =>
              '<tr><td>${_escape(item.number)}</td><td>${_formatDate(item.dueDate)}</td><td class="number">${FiscalDecimal.fromNum(item.value).toFixed(2)}</td></tr>',
        )
        .join();
    final text = options.showBillingText && billing.installments.isEmpty
        ? '<div>${paymentIndicator == 0 ? 'Pagamento à Vista' : 'Pagamento à Prazo'} - Fatura: ${_escape(billing.invoiceNumber)} | Valor Original: ${FiscalDecimal.fromNum(billing.originalValue).toFixed(2)} | Desconto: ${FiscalDecimal.fromNum(billing.discount).toFixed(2)} | Valor Líquido: ${FiscalDecimal.fromNum(billing.netValue).toFixed(2)}</div>'
        : '';
    return '<section class="box"><h2>Cobrança</h2>$text<div>Fatura: ${_escape(billing.invoiceNumber)} | Original: ${FiscalDecimal.fromNum(billing.originalValue).toFixed(2)} | Líquido: ${FiscalDecimal.fromNum(billing.netValue).toFixed(2)}</div>${billing.installments.isEmpty ? '' : '<table><tr><th>Duplicata</th><th>Vencimento</th><th>Valor</th></tr>$installments</table>'}</section>';
  }

  bool _hasIssqn(NfeDocument document) =>
      document.serviceTotal != null ||
      document.items.any((item) => item.serviceTax != null);

  String _issqnHtml(NfeDocument document) {
    final rows = document.items.where((item) => item.serviceTax != null).map((
      item,
    ) {
      final tax = item.serviceTax!;
      return '<tr><td>${item.number}</td><td>${_escape(tax.serviceCode ?? tax.serviceListCode)}</td><td>${_escape(tax.municipalityCode)}</td><td>${_formatDate(tax.competenceDate)}</td><td class="number">${FiscalDecimal.fromNum(tax.base).toFixed(2)}</td><td class="number">${FiscalDecimal.fromNum(tax.rate).toFixed(2)}</td><td class="number">${FiscalDecimal.fromNum(tax.value).toFixed(2)}</td><td class="number">${FiscalDecimal.fromNum(tax.retained).toFixed(2)}</td></tr>';
    }).join();
    final fallback = rows.isNotEmpty || document.serviceTotal == null
        ? rows
        : '<tr><td>-</td><td>${document.serviceTotal!.taxRegime ?? '-'}</td><td>-</td><td>${_formatDate(document.serviceTotal!.competenceDate)}</td><td class="number">${FiscalDecimal.fromNum(document.serviceTotal!.taxBase).toFixed(2)}</td><td class="number">-</td><td class="number">${FiscalDecimal.fromNum(document.serviceTotal!.taxValue).toFixed(2)}</td><td class="number">${FiscalDecimal.fromNum(document.serviceTotal!.retained).toFixed(2)}</td></tr>';
    return '<section class="box"><h2>ISSQN - Serviços</h2><table><thead><tr><th>Item</th><th>Cód. serviço/lista</th><th>Município fato gerador</th><th>Competência</th><th>BC ISSQN</th><th>Alíquota</th><th>ISSQN</th><th>Retido</th></tr></thead><tbody>$fallback</tbody></table></section>';
  }

  String _additionalHtml(NfeDocument document, DanfeHtmlOptions options) {
    final additional = document.additionalInfo;
    final automatic = options.generateAutomaticInfo
        ? _automaticAdditionalInfo(document)
        : const <String>[];
    final complementary = StringBuffer()
      ..write(automatic.map((item) => '<div>${_escape(item)}</div>').join())
      ..write(
        additional?.complementary == null
            ? ''
            : '<div>${_escape(additional!.complementary!)}</div>',
      )
      ..write(
        (additional != null && options.showContributorObservations
                ? additional.contributorObservations
                : const <AdditionalObservation>[])
            .map(
              (item) =>
                  '<div>Contribuinte [${_escape(item.field)}]: ${_escape(item.text)}</div>',
            )
            .join(),
      )
      ..write(
        (additional?.referencedProcesses ?? const <ReferencedProcess>[])
            .map(
              (item) =>
                  '<div>Processo ${_escape(item.number)} (${_escape(item.indicator)})</div>',
            )
            .join(),
      )
      ..write(
        (additional?.authorizedXml ?? const <AuthorizedXmlDownload>[])
            .map(
              (item) =>
                  '<div>XML autorizado: ${_escape(item.cnpj ?? item.cpf ?? '')}</div>',
            )
            .join(),
      );
    final fiscal = StringBuffer()
      ..write(
        additional?.taxAuthority == null
            ? ''
            : '<div>${_escape(additional!.taxAuthority!)}</div>',
      )
      ..write(
        (additional != null && options.showFiscalObservations
                ? additional.fiscalObservations
                : const <AdditionalObservation>[])
            .map(
              (item) =>
                  '<div>Fisco [${_escape(item.field)}]: ${_escape(item.text)}</div>',
            )
            .join(),
      );
    return '${complementary.isEmpty ? '' : '<section class="box"><h2>Informações complementares</h2>$complementary</section>'}'
        '${fiscal.isEmpty ? '' : '<section class="box"><h2>Reservado ao fisco</h2>$fiscal</section>'}';
  }

  bool _hasAdditionalContent(NfeDocument document, DanfeHtmlOptions options) =>
      document.additionalInfo?.isNotEmpty == true ||
      (options.generateAutomaticInfo &&
          _automaticAdditionalInfo(document).isNotEmpty);

  List<String> _automaticAdditionalInfo(NfeDocument document) => [
    if (document.purchaseInfo?.commitmentNote != null)
      'Nota de Empenho: ${document.purchaseInfo!.commitmentNote}',
    if (document.purchaseInfo?.order != null)
      'Pedido: ${document.purchaseInfo!.order}',
    if (document.purchaseInfo?.contract != null)
      'Contrato: ${document.purchaseInfo!.contract}',
    for (final reference in document.references)
      _automaticReferenceText(reference),
    if (_sumApproximateTaxes(document).toFixed(2) != '0.00')
      'Valor aproximado dos tributos: R\$ ${_sumApproximateTaxes(document).toFixed(2)}',
  ];

  String _automaticReferenceText(ReferencedDocument reference) {
    if (reference.accessKey != null) return 'NFe Ref.: ${reference.accessKey}';
    if (reference.cteKey != null) return 'CTe Ref.: ${reference.cteKey}';
    if (reference.signedNfeKey != null) {
      return 'NFe referenciada com código numérico sigiloso';
    }
    if (reference.ecfModel != null) {
      return 'ECF Ref.: modelo ${reference.ecfModel} ECF:${reference.ecfNumber} COO:${reference.cooNumber}';
    }
    if (reference.producerIe != null) {
      return 'NFP Ref.: série ${reference.series} número ${reference.number} IE ${reference.producerIe}';
    }
    if (reference.model != null) {
      return 'NF Ref.: série ${reference.series} número ${reference.number} emit ${reference.cnpj ?? reference.cpf ?? ''}';
    }
    return 'Documento fiscal referenciado';
  }

  String _avulsaHtml(NfeDocument document) {
    final avulsa = document.avulsa!;
    return '<section class="box"><h2>Emissão avulsa</h2>'
        '<div>Órgão: ${_escape(avulsa.agency)}</div>'
        '<div>Agente: ${_escape(avulsa.agent)} | UF: ${_escape(avulsa.state)}</div>'
        '<div>Repartição fiscal: ${_escape(avulsa.fiscalOffice)}</div>'
        '${avulsa.revenueDocumentNumber == null ? '' : '<div>DAR: ${_escape(avulsa.revenueDocumentNumber!)}</div>'}'
        '</section>';
  }

  String _operationHtml(NfeDocument document) {
    final fields = <String>[
      if (document.operationNature != null)
        '<div>Natureza da operação: ${_escape(document.operationNature!)}</div>',
      if (document.documentType != null)
        '<div>Tipo: ${document.documentType == 0 ? 'Entrada' : 'Saída'} (${document.documentType})</div>',
      if (document.destinationType != null)
        '<div>Destino da operação: ${document.destinationType}</div>',
      if (document.purpose != null)
        '<div>Finalidade da emissão: ${document.purpose}</div>',
      if (document.finalConsumer != null)
        '<div>Consumidor final: ${document.finalConsumer}</div>',
      if (document.presenceIndicator != null)
        '<div>Presença do comprador: ${document.presenceIndicator}</div>',
      if (document.intermediaryIndicator != null)
        '<div>Intermediador: ${document.intermediaryIndicator}</div>',
      if (document.operationLocationCode != null)
        '<div>Local da operação: ${_escape(document.operationLocationCode!)}</div>',
      if (document.municipalityCode != null)
        '<div>Município do fato gerador: ${_escape(document.municipalityCode!)}</div>',
      if (document.ibsMunicipalityCode != null)
        '<div>Município do fato gerador IBS/CBS: ${_escape(document.ibsMunicipalityCode!)}</div>',
      if (document.deliveryForecast != null)
        '<div>Previsão de entrega: ${_formatDate(document.deliveryForecast!)}</div>',
      if (document.processCode != null || document.applicationVersion != null)
        '<div>Processo: ${document.processCode == null ? '' : _escape(document.processCode!)}${document.applicationVersion == null ? '' : ' / ${_escape(document.applicationVersion!)}'}</div>',
      if (document.contingency != null)
        '<div><strong>CONTINGÊNCIA</strong>: tpEmis ${document.contingency!.mode.code} — ${_escape(document.contingency!.reason)}; ativada em ${_formatDateTime(document.contingency!.activatedAt)}</div>',
      if (document.withdrawal != null)
        '<div>Retirada: ${_escape(_locationText(document.withdrawal!))}</div>',
      if (document.delivery != null)
        '<div>Entrega: ${_escape(_locationText(document.delivery!))}</div>',
      if (document.references.isNotEmpty)
        '<div>Documentos referenciados: ${document.references.length}</div>',
    ];
    if (fields.isEmpty) return '';
    return '<section class="box"><h2>Identificação da operação</h2>${fields.join()}</section>';
  }

  String _locationText(NfeLocation location) => [
    if (location.name != null) location.name!,
    location.street,
    location.number,
    if (location.complement != null) location.complement!,
    location.neighborhood,
    location.municipality,
    location.state,
    if (location.zipCode != null) location.zipCode!,
  ].join(', ');

  String _transportHtml(NfeDocument document) {
    final transport = document.transport;
    final volumes = transport.volumes
        .map(
          (volume) =>
              '<li>${volume.quantity ?? ''} ${_escape(volume.kind ?? '')} ${_escape(volume.number ?? '')}${volume.seal.isEmpty ? '' : ' | Lacres: ${_escape(volume.seal.join(', '))}'}</li>',
        )
        .join();
    return '<section class="box"><h2>Transporte</h2><div>Modalidade: ${transport.freightMode}</div>${transport.carrierName == null ? '' : '<div>Transportador: ${_escape(transport.carrierName!)}</div>'}${transport.vehiclePlate == null ? '' : '<div>Veículo: ${_escape(transport.vehiclePlate!)}${transport.vehicleState == null ? '' : ' / ${_escape(transport.vehicleState!)}'}</div>'}${transport.retention == null ? '' : '<div>ICMS retido: ${FiscalDecimal.fromNum(transport.retention!.taxValue).toFixed(2)}</div>'}${volumes.isEmpty ? '' : '<ul>$volumes</ul>'}</section>';
  }

  String _formatDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  String _formatDateTime(DateTime value) =>
      '${_formatDate(value)} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';

  String _address(Party party) => [
    party.address,
    party.addressNumber,
    party.addressComplement,
    party.neighborhood,
    party.city,
    party.state,
    party.zipCode,
  ].whereType<String>().where((part) => part.isNotEmpty).join(', ');

  String _partyDetailsHtml(Party party) => [
    if (party.fantasyName != null)
      '<div>Fantasia: ${_escape(party.fantasyName!)}</div>',
    if (party.ie != null) '<div>IE: ${_escape(party.ie!)}</div>',
    if (party.ieSubstitute != null)
      '<div>IEST: ${_escape(party.ieSubstitute!)}</div>',
    if (party.municipalRegistration != null)
      '<div>IM: ${_escape(party.municipalRegistration!)}</div>',
    if (party.cnae != null) '<div>CNAE: ${_escape(party.cnae!)}</div>',
    if (party.suframa != null) '<div>SUFRAMA: ${_escape(party.suframa!)}</div>',
    if (party.recipientIeIndicator != null)
      '<div>Ind. IE destinatário: ${party.recipientIeIndicator}</div>',
    if (party.crt != null) '<div>CRT: ${_escape(party.crt!)}</div>',
    if (party.phone != null) '<div>Fone: ${_escape(party.phone!)}</div>',
    if (party.email != null) '<div>E-mail: ${_escape(party.email!)}</div>',
  ].join();

  FiscalDecimal _sumItems(
    NfeDocument document,
    num Function(NfeItem item) value,
  ) => document.items
      .where((item) => item.includeInTotal)
      .fold(
        FiscalDecimal.parse('0'),
        (sum, item) => sum + FiscalDecimal.fromNum(value(item)),
      );

  FiscalDecimal _sumInterstate(
    NfeDocument document,
    num? Function(IcmsUfDestinationTax? tax) value,
  ) => document.items
      .where((item) => item.includeInTotal)
      .fold(
        FiscalDecimal.parse('0'),
        (sum, item) =>
            sum + FiscalDecimal.fromNum(value(item.icmsUfDestination) ?? 0),
      );

  FiscalDecimal _sumTax(
    NfeDocument document,
    num? Function(NfeItem item) value,
  ) => document.items
      .where((item) => item.includeInTotal)
      .fold(
        FiscalDecimal.parse('0'),
        (sum, item) => sum + FiscalDecimal.fromNum(value(item) ?? 0),
      );

  FiscalDecimal _sumMerchandise(NfeDocument document) => document.items
      .where((item) => item.includeInTotal)
      .fold(
        FiscalDecimal.parse('0'),
        (sum, item) => sum + item.merchandiseTotalDecimal,
      );

  FiscalDecimal _sumApproximateTaxes(NfeDocument document) => document.items
      .where((item) => item.includeInTotal)
      .fold(
        FiscalDecimal.parse('0'),
        (sum, item) =>
            sum + FiscalDecimal.fromNum(item.approximateTaxValue ?? 0),
      );

  String _reformTotalsHtml(NfeDocument document) {
    final hasReformTaxes = document.items.any(
      (item) =>
          item.ibsCbs != null ||
          item.ibsCbsMonophase != null ||
          item.selectiveTax != null,
    );
    if (!hasReformTaxes &&
        document.serviceTotal == null &&
        document.taxRetention == null) {
      return '';
    }
    final rows = <String>[];
    final ibsUf = _sumReform(document, (item) => item.ibsCbs?.ibsUfValue);
    final ibsMunicipal = _sumReform(
      document,
      (item) => item.ibsCbs?.ibsMunicipalValue,
    );
    final cbs = _sumReform(document, (item) => item.ibsCbs?.cbsValue);
    final ibsMono = _sumReform(
      document,
      (item) => item.ibsCbsMonophase?.totalIbsValue,
    );
    final cbsMono = _sumReform(
      document,
      (item) => item.ibsCbsMonophase?.totalCbsValue,
    );
    final selective = _sumReform(document, (item) => item.selectiveTax?.value);
    if (ibsUf.compareTo(FiscalDecimal.parse('0')) != 0) {
      rows.add(
        '<tr><td>IBS UF</td><td class="number">${ibsUf.toFixed(2)}</td></tr>',
      );
    }
    if (ibsMunicipal.compareTo(FiscalDecimal.parse('0')) != 0) {
      rows.add(
        '<tr><td>IBS município</td><td class="number">${ibsMunicipal.toFixed(2)}</td></tr>',
      );
    }
    if (cbs.compareTo(FiscalDecimal.parse('0')) != 0) {
      rows.add(
        '<tr><td>CBS</td><td class="number">${cbs.toFixed(2)}</td></tr>',
      );
    }
    if (ibsMono.compareTo(FiscalDecimal.parse('0')) != 0) {
      rows.add(
        '<tr><td>IBS monofásico</td><td class="number">${ibsMono.toFixed(2)}</td></tr>',
      );
    }
    if (cbsMono.compareTo(FiscalDecimal.parse('0')) != 0) {
      rows.add(
        '<tr><td>CBS monofásica</td><td class="number">${cbsMono.toFixed(2)}</td></tr>',
      );
    }
    final ibsMonoRetained = _sumReform(
      document,
      (item) => item.ibsCbsMonophase?.ibsRetainedValue == null
          ? null
          : FiscalDecimal.fromNum(item.ibsCbsMonophase!.ibsRetainedValue!),
    );
    final cbsMonoRetained = _sumReform(
      document,
      (item) => item.ibsCbsMonophase?.cbsRetainedValue == null
          ? null
          : FiscalDecimal.fromNum(item.ibsCbsMonophase!.cbsRetainedValue!),
    );
    if (ibsMonoRetained.compareTo(FiscalDecimal.parse('0')) != 0) {
      rows.add(
        '<tr><td>IBS monofásico retido</td><td class="number">${ibsMonoRetained.toFixed(2)}</td></tr>',
      );
    }
    if (cbsMonoRetained.compareTo(FiscalDecimal.parse('0')) != 0) {
      rows.add(
        '<tr><td>CBS monofásica retida</td><td class="number">${cbsMonoRetained.toFixed(2)}</td></tr>',
      );
    }
    if (selective.compareTo(FiscalDecimal.parse('0')) != 0) {
      rows.add(
        '<tr><td>Imposto seletivo</td><td class="number">${selective.toFixed(2)}</td></tr>',
      );
    }
    final ibsCredit = _sumOperationCredit(document, true);
    final cbsCredit = _sumOperationCredit(document, false);
    final ibsReversal = _sumCreditReversal(document, true);
    final cbsReversal = _sumCreditReversal(document, false);
    if (ibsCredit.compareTo(FiscalDecimal.parse('0')) != 0) {
      rows.add(
        '<tr><td>Crédito presumido IBS</td><td class="number">${ibsCredit.toFixed(2)}</td></tr>',
      );
    }
    if (cbsCredit.compareTo(FiscalDecimal.parse('0')) != 0) {
      rows.add(
        '<tr><td>Crédito presumido CBS</td><td class="number">${cbsCredit.toFixed(2)}</td></tr>',
      );
    }
    if (ibsReversal.compareTo(FiscalDecimal.parse('0')) != 0) {
      rows.add(
        '<tr><td>Estorno de crédito IBS</td><td class="number">${ibsReversal.toFixed(2)}</td></tr>',
      );
    }
    if (cbsReversal.compareTo(FiscalDecimal.parse('0')) != 0) {
      rows.add(
        '<tr><td>Estorno de crédito CBS</td><td class="number">${cbsReversal.toFixed(2)}</td></tr>',
      );
    }
    if (document.serviceTotal != null) {
      rows.add(
        '<tr><td>ISSQN declarado</td><td class="number">${FiscalDecimal.fromNum(document.serviceTotal!.taxValue).toFixed(2)}</td></tr>',
      );
    }
    final retention = document.taxRetention;
    if (retention != null) {
      rows.add(
        '<tr><td>Retenções federais</td><td class="number">${_retentionTotal(retention).toFixed(2)}</td></tr>',
      );
    }
    final title = hasReformTaxes
        ? 'Total do IBS/CBS/IS'
        : 'Totais fiscais complementares';
    return '<section class="box"><h2>$title</h2><table>${rows.join()}</table></section>';
  }

  String _reformItemsHtml(NfeDocument document) {
    final rows = document.items
        .where(
          (item) =>
              item.ibsCbs != null ||
              item.ibsCbsMonophase != null ||
              item.selectiveTax != null,
        )
        .map((item) {
          final ibsCbs = item.ibsCbs;
          final mono = item.ibsCbsMonophase;
          final selective = item.selectiveTax;
          final ibsCbsText = <String>[
            if (ibsCbs != null) ...[
              'BC ${FiscalDecimal.fromNum(ibsCbs.base).toFixed(2)}',
              'IBS UF ${_formatRtcRate(ibsCbs.ibsUfReduction?.effectiveRate ?? ibsCbs.ibsUfRate)}% / ${ibsCbs.ibsUfValue.toFixed(2)}',
              'IBS Mun. ${_formatRtcRate(ibsCbs.ibsMunicipalReduction?.effectiveRate ?? ibsCbs.ibsMunicipalRate)}% / ${ibsCbs.ibsMunicipalValue.toFixed(2)}',
              'CBS ${_formatRtcRate(ibsCbs.cbsReduction?.effectiveRate ?? ibsCbs.cbsRate)}% / ${ibsCbs.cbsValue.toFixed(2)}',
            ],
            if (mono?.ibsValue != null)
              'IBS mono. ${FiscalDecimal.fromNum(mono!.ibsValue!).toFixed(2)}',
            if (mono?.cbsValue != null)
              'CBS mono. ${FiscalDecimal.fromNum(mono!.cbsValue!).toFixed(2)}',
            if (mono?.ibsRetainedValue != null)
              'IBS mono. retido ${FiscalDecimal.fromNum(mono!.ibsRetainedValue!).toFixed(2)}',
            if (mono?.cbsRetainedValue != null)
              'CBS mono. retida ${FiscalDecimal.fromNum(mono!.cbsRetainedValue!).toFixed(2)}',
          ];
          final isText = selective == null
              ? '-'
              : 'BC ${FiscalDecimal.fromNum(selective.base).toFixed(2)} | '
                    'IS ${_formatRtcRate(selective.rate)}% / ${selective.value.toFixed(2)}';
          return '<tr><td>${item.number}</td><td>${_escape([if (ibsCbs != null) 'IBS/CBS ${ibsCbs.classificationCode}', if (mono != null) 'Mono ${mono.classificationCode}', if (selective != null) 'IS ${selective.classificationCode}'].join(' | '))}</td><td>${_escape(ibsCbsText.join(' | '))}</td><td>${_escape(isText)}</td></tr>';
        })
        .join();
    if (rows.isEmpty) return '';
    return '<section class="box"><h2>Detalhamento IBS / CBS / IS por item</h2><table><thead><tr><th>Item</th><th>Classificação tributária</th><th>IBS / CBS</th><th>IS</th></tr></thead><tbody>$rows</tbody></table></section>';
  }

  String _formatRtcRate(num value) => FiscalDecimal.fromNum(value).toFixed(4);

  FiscalDecimal _retentionTotal(TaxRetention retention) =>
      FiscalDecimal.fromNum(retention.pis) +
      FiscalDecimal.fromNum(retention.cofins) +
      FiscalDecimal.fromNum(retention.csll) +
      FiscalDecimal.fromNum(retention.irrf) +
      FiscalDecimal.fromNum(retention.socialSecurity);

  FiscalDecimal _sumReform(
    NfeDocument document,
    FiscalDecimal? Function(NfeItem item) value,
  ) => document.items
      .where((item) => item.includeInTotal)
      .fold(
        FiscalDecimal.parse('0'),
        (sum, item) => sum + (value(item) ?? FiscalDecimal.parse('0')),
      );

  FiscalDecimal _sumOperationCredit(NfeDocument document, bool ibs) => document
      .items
      .where((item) => item.includeInTotal)
      .fold(FiscalDecimal.parse('0'), (sum, item) {
        final credit = ibs
            ? item.ibsCbs?.operationCredit?.ibs
            : item.ibsCbs?.operationCredit?.cbs;
        return sum +
            (credit == null
                ? FiscalDecimal.parse('0')
                : FiscalDecimal.fromNum(credit.value));
      });

  FiscalDecimal _sumCreditReversal(NfeDocument document, bool ibs) => document
      .items
      .where((item) => item.includeInTotal)
      .fold(
        FiscalDecimal.parse('0'),
        (sum, item) =>
            sum +
            FiscalDecimal.fromNum(
              ibs
                  ? item.ibsCbs?.creditReversal?.ibsValue ?? 0
                  : item.ibsCbs?.creditReversal?.cbsValue ?? 0,
            ),
      );

  String _itemDescription(
    NfeItem item, {
    bool showTaxableUnit = true,
    bool showPurchaseOrderItem = false,
    bool showItemTaxDetails = false,
    bool showItemAdditionalInfo = true,
    bool showItemTraceability = true,
    int taxableQuantityDecimals = 4,
    int taxableUnitPriceDecimals = 4,
  }) => [
    item.description,
    if (showItemTaxDetails && (item.approximateTaxValue ?? 0) != 0)
      'Tributos aprox.: R\$ ${FiscalDecimal.fromNum(item.approximateTaxValue!).toFixed(2)}',
    if (showItemTaxDetails && item.benefitCode != null)
      'Benefício fiscal: ${item.benefitCode}',
    if (item.ibsCbs != null)
      'Class. IBS/CBS: ${item.ibsCbs!.classificationCode}',
    if (item.ibsCbs != null)
      'RTC IBS/CBS: BC ${FiscalDecimal.fromNum(item.ibsCbs!.base).toFixed(2)} | '
          'IBS UF ${FiscalDecimal.fromNum(item.ibsCbs!.ibsUfReduction?.effectiveRate ?? item.ibsCbs!.ibsUfRate).toFixed(4)}% '
          '${item.ibsCbs!.ibsUfValue.toFixed(2)} | IBS Mun. '
          '${FiscalDecimal.fromNum(item.ibsCbs!.ibsMunicipalReduction?.effectiveRate ?? item.ibsCbs!.ibsMunicipalRate).toFixed(4)}% '
          '${item.ibsCbs!.ibsMunicipalValue.toFixed(2)} | CBS '
          '${FiscalDecimal.fromNum(item.ibsCbs!.cbsReduction?.effectiveRate ?? item.ibsCbs!.cbsRate).toFixed(4)}% '
          '${item.ibsCbs!.cbsValue.toFixed(2)}',
    if (item.ibsCbs?.regularTax != null)
      'Tributação regular: CST ${item.ibsCbs!.regularTax!.cst} | '
          'IBS UF ${FiscalDecimal.fromNum(item.ibsCbs!.regularTax!.ibsUfValue).toFixed(2)} | '
          'IBS Mun. ${FiscalDecimal.fromNum(item.ibsCbs!.regularTax!.ibsMunicipalValue).toFixed(2)} | '
          'CBS ${FiscalDecimal.fromNum(item.ibsCbs!.regularTax!.cbsValue).toFixed(2)}',
    if (item.ibsCbs?.governmentTax != null)
      'Compra governamental sem redutor: IBS UF '
          '${FiscalDecimal.fromNum(item.ibsCbs!.governmentTax!.ibsUfValue).toFixed(2)} | '
          'IBS Mun. ${FiscalDecimal.fromNum(item.ibsCbs!.governmentTax!.ibsMunicipalValue).toFixed(2)} | '
          'CBS ${FiscalDecimal.fromNum(item.ibsCbs!.governmentTax!.cbsValue).toFixed(2)}',
    if (item.ibsCbs?.creditReversal != null)
      'Estorno de crédito: IBS ${FiscalDecimal.fromNum(item.ibsCbs!.creditReversal!.ibsValue).toFixed(2)} | '
          'CBS ${FiscalDecimal.fromNum(item.ibsCbs!.creditReversal!.cbsValue).toFixed(2)}',
    if (item.ibsCbs?.operationCredit != null)
      'Crédito presumido: base ${FiscalDecimal.fromNum(item.ibsCbs!.operationCredit!.base).toFixed(2)} | código ${item.ibsCbs!.operationCredit!.code}',
    if (item.ibsCbsMonophase != null)
      'Class. IBS/CBS monofásico: ${item.ibsCbsMonophase!.classificationCode}',
    if (item.selectiveTax != null)
      'Class. IS: ${item.selectiveTax!.classificationCode}',
    if (item.selectiveTax != null)
      'RTC IS: BC ${FiscalDecimal.fromNum(item.selectiveTax!.base).toFixed(2)} | '
          '${FiscalDecimal.fromNum(item.selectiveTax!.rate).toFixed(4)}% | '
          '${item.selectiveTax!.value.toFixed(2)}',
    if (showPurchaseOrderItem && item.orderNumber != null)
      'PED ${item.orderNumber}',
    if (showPurchaseOrderItem && item.orderItem != null)
      'ITEM ${item.orderItem}',
    if (showTaxableUnit &&
        (item.tribUnit != null ||
            item.tribQuantity != null ||
            item.tribUnitPrice != null))
      'Trib.: ${FiscalDecimal.fromNum(item.tribQuantity ?? item.quantity).toFixed(taxableQuantityDecimals)} ${item.tribUnit ?? item.unit} x ${FiscalDecimal.fromNum(item.tribUnitPrice ?? item.unitPrice).toFixed(taxableUnitPriceDecimals)}',
    if (showItemAdditionalInfo && item.additionalInformation != null)
      item.additionalInformation!,
    if (showItemAdditionalInfo && showItemTraceability)
      for (final batch in item.traceability)
        'Lote ${batch.batchNumber} | Fab. ${_formatDate(batch.manufacturedAt)} | Val. ${_formatDate(batch.expiresAt)}',
    if (showItemAdditionalInfo && item.medication != null)
      'ANVISA ${item.medication!.anvisaProductCode} | PMC ${FiscalDecimal.fromNum(item.medication!.maximumConsumerPrice).toFixed(2)}',
  ].join('\n');

  String _itemCode(NfeItem item) => [
    item.code,
    if (item.ean != null) 'EAN: ${item.ean}',
    if (item.barcode != null) 'CBarra: ${item.barcode}',
    if (item.eanTrib != null) 'EAN trib.: ${item.eanTrib}',
    if (item.taxableBarcode != null) 'CBarra trib.: ${item.taxableBarcode}',
  ].join('\n');

  String _escape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}
