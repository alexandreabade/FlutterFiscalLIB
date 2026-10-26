import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/nfe_document.dart';
import '../models/nfe_item.dart';
import '../models/nfe_complements.dart';
import '../models/party.dart';
import '../models/contingency.dart';
import '../common/fiscal_decimal.dart';
import '../exceptions/fiscal_exception.dart';

/// Formatos de saída disponíveis para o PDF auxiliar.
enum DanfePdfLayout {
  /// DANFE em folha A4.
  a4,

  /// DANFE NF-e em folha A4 paisagem, compatível com a orientação alternativa
  /// do leiaute auxiliar do `sped-da`.
  a4Landscape,

  /// DANFE NFC-e em bobina térmica de 80 mm.
  nfceThermal80,
}

/// Opções de apresentação inspiradas nas configurações públicas do
/// `sped-da` para DANFE NFC-e.
class DanfePdfOptions {
  /// Cria opções de renderização sem alterar os dados fiscais.
  const DanfePdfOptions({
    this.paperWidthMm = 80,
    this.marginMm = 4,
    this.printSummary = false,
    this.establishmentCopy = false,
    this.canceled = false,
    this.offlineDoublePrint = false,
    this.showReceiptStub = true,
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
    this.showRecipientEmail = true,
    this.title = 'DANFE',
    this.quantityDecimals = 4,
    this.unitPriceDecimals = 2,
    this.showContributorObservations = true,
    this.showFiscalObservations = true,
    this.useDashedItemSeparators = true,
    this.epecProtocol,
    this.epecDate,
    this.extraContent,
    this.fontBytes,
    this.logoBytes,
    this.a4MarginMm = 12,
  }) : assert(paperWidthMm >= 50 && paperWidthMm <= 210),
       assert(marginMm >= 0 && marginMm < paperWidthMm / 2),
       assert(quantityDecimals >= 0 && quantityDecimals <= 6),
       assert(unitPriceDecimals >= 0 && unitPriceDecimals <= 6),
       assert(a4MarginMm >= 0 && a4MarginMm <= 40);

  /// Largura do papel em milímetros.
  final double paperWidthMm;

  /// Margem uniforme em milímetros.
  final double marginMm;

  /// Identifica uma via resumida no cabeçalho.
  final bool printSummary;

  /// Identifica a via destinada ao estabelecimento.
  final bool establishmentCopy;

  /// Marca o documento como cancelado na representação auxiliar.
  final bool canceled;

  /// Identifica uma segunda via de contingência offline.
  final bool offlineDoublePrint;

  /// Exibe o canhoto de recebimento no DANFE A4 de NF-e.
  final bool showReceiptStub;

  /// Exibe PIS e COFINS no quadro de cálculo do imposto.
  ///
  /// O padrão segue o `sped-da`, que oculta esses valores no DANFE resumido.
  final bool showPisCofins;

  /// Exibe a linha de tributos aproximados no quadro de cálculo.
  final bool showApproximateTaxes;

  /// Exibe os valores de ICMS interestadual da partilha `ICMSUFDest`.
  final bool showInterstateTaxes;

  /// Inclui `infAdProd`, lotes e dados ANVISA na descrição do item.
  final bool showItemAdditionalInfo;

  /// Inclui lote, fabricação, validade e dados de rastreabilidade na descrição.
  /// Corresponde a `descProdInfoLoteTxt` do `sped-da`.
  final bool showItemTraceability;

  /// Concatena tributos aproximados e benefício fiscal na descrição do item.
  /// Corresponde a `descProdInfoComplemento` do `sped-da`.
  final bool showItemTaxDetails;

  /// Exibe unidade, quantidade e preço tributáveis quando informados.
  ///
  /// Corresponde a `qTrib`/`uTrib`/`vUnTrib` do DANFE. O padrão segue o
  /// `sped-da`; defina `false` para uma apresentação resumida.
  final bool showTaxableUnit;

  /// Gera textos derivados de compra, referências e tributos aproximados.
  ///
  /// Corresponde a `setGerarInformacoesAutomaticas` do `sped-da` e permanece
  /// desativado por padrão para não alterar a apresentação existente.
  final bool generateAutomaticInfo;

  /// Exibe o texto resumido de pagamento/fatura quando não há duplicatas.
  /// Corresponde a `exibirTextoFatura` do `sped-da`.
  final bool showBillingText;

  /// Exibe o pedido e o número do item do pedido de compra na descrição.
  /// Corresponde a `exibirNumeroItemPedido` do `sped-da`.
  final bool showPurchaseOrderItem;

  /// Exibe o e-mail do destinatário no quadro de identificação.
  final bool showRecipientEmail;

  /// Título exibido no bloco central do DANFE (`setTitle` no `sped-da`).
  final String title;

  /// Casas decimais da quantidade comercial exibida no DANFE.
  final int quantityDecimals;

  /// Casas decimais do preço unitário comercial exibido no DANFE.
  final int unitPriceDecimals;

  /// Exibe observações de interesse do contribuinte (`obsCont`).
  final bool showContributorObservations;

  /// Exibe observações reservadas ao fisco (`obsFisco`).
  final bool showFiscalObservations;

  /// Usa linhas tracejadas nas separações verticais da tabela de itens.
  ///
  /// Corresponde ao padrão de `setUsarLinhaTracejadaSeparacaoItens()` do
  /// `sped-da`; pode ser desativado para impressoras que exigem linhas
  /// contínuas.
  final bool useDashedItemSeparators;

  /// Protocolo EPEC apresentado no DANFE, quando fornecido pela aplicação.
  final String? epecProtocol;

  /// Data de registro do EPEC apresentado no DANFE.
  final DateTime? epecDate;

  /// Conteúdo livre fornecido pela aplicação para o rodapé.
  final String? extraContent;

  /// Bytes de uma fonte TTF licenciada pela aplicação.
  ///
  /// Quando informado, o PDF usa a fonte nos textos normal e em negrito,
  /// evitando a limitação de caracteres das fontes Type 1 padrão do pacote
  /// `pdf`. A biblioteca não distribui fontes para não impor licença ou
  /// tamanho de asset ao aplicativo.
  final Uint8List? fontBytes;

  /// Bytes de uma imagem do logotipo do emitente (PNG/JPEG suportados pelo
  /// pacote PDF), sem dependência de arquivo ou plugin nativo.
  final Uint8List? logoBytes;

  /// Margem da folha A4 em milímetros.
  final double a4MarginMm;
}

/// Renderizador PDF básico e independente de plataforma para DANFE.
///
/// O documento é uma representação auxiliar para impressão e não substitui
/// autorização, XML protocolado nem os requisitos gráficos completos de uma
/// implementação oficial de DANFE.
class DanfePdfRenderer {
  /// Gera bytes PDF no [layout] escolhido.
  ///
  /// O layout térmico é exclusivo do modelo 65 e não depende do driver da
  /// impressora: o consumidor recebe um PDF com largura de bobina padrão.
  Future<Uint8List> render(
    NfeDocument document, {
    DanfePdfLayout layout = DanfePdfLayout.a4,
    DanfePdfOptions options = const DanfePdfOptions(),
  }) async {
    if (layout == DanfePdfLayout.nfceThermal80 && document.model != 65) {
      throw const FiscalValidationException(
        'O layout térmico de 80 mm é exclusivo da NFC-e modelo 65.',
        code: 'THERMAL_LAYOUT_MODEL_MISMATCH',
      );
    }
    if (options.logoBytes != null && options.logoBytes!.isEmpty) {
      throw const FiscalValidationException(
        'O logotipo do DANFE não pode estar vazio.',
        code: 'INVALID_DANFE_LOGO',
      );
    }
    final pdf = pw.Document(theme: _theme(options));
    if (layout == DanfePdfLayout.nfceThermal80) {
      _addThermalPage(pdf, document, options);
      return pdf.save();
    }
    _addA4Page(
      pdf,
      document,
      options,
      pageFormat: layout == DanfePdfLayout.a4Landscape
          ? PdfPageFormat.a4.landscape
          : PdfPageFormat.a4,
    );
    return pdf.save();
  }

  pw.ThemeData? _theme(DanfePdfOptions options) {
    final bytes = options.fontBytes;
    if (bytes == null || bytes.isEmpty) return null;
    if (!_looksLikeTrueType(bytes)) {
      throw const FiscalValidationException(
        'A fonte do DANFE deve ser um arquivo TTF/OTF válido.',
        code: 'INVALID_DANFE_FONT',
      );
    }
    final font = pw.Font.ttf(ByteData.sublistView(Uint8List.fromList(bytes)));
    return pw.ThemeData.withFont(
      base: font,
      bold: font,
      italic: font,
      boldItalic: font,
    );
  }

  bool _looksLikeTrueType(Uint8List bytes) {
    if (bytes.length < 12) return false;
    final signature = String.fromCharCodes(bytes.take(4));
    return signature == 'OTTO' ||
        signature == 'ttcf' ||
        signature == 'true' ||
        (bytes[0] == 0 && bytes[1] == 1 && bytes[2] == 0 && bytes[3] == 0);
  }

  void _addA4Page(
    pw.Document pdf,
    NfeDocument document,
    DanfePdfOptions options, {
    PdfPageFormat pageFormat = PdfPageFormat.a4,
  }) {
    final itemBorder = pw.TableBorder(
      top: const pw.BorderSide(),
      right: const pw.BorderSide(),
      bottom: const pw.BorderSide(),
      left: const pw.BorderSide(),
      horizontalInside: const pw.BorderSide(),
      verticalInside: pw.BorderSide(
        style: options.useDashedItemSeparators
            ? pw.BorderStyle.dashed
            : pw.BorderStyle.solid,
      ),
    );
    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.all(options.a4MarginMm * PdfPageFormat.mm),
        header: (context) => context.pageNumber == 1
            ? pw.SizedBox()
            : pw.Container(
                width: double.infinity,
                margin: const pw.EdgeInsets.only(bottom: 5),
                padding: const pw.EdgeInsets.only(bottom: 3),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide()),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            'DANFE ${document.model == 65 ? 'NFC-e' : 'NF-e'} - CONTINUAÇÃO | FOLHA ${context.pageNumber}',
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.Text(
                          [
                            'NF-e ${document.number}  Série ${document.series}',
                            if (document.environment == 2) 'HOMOLOGAÇÃO',
                          ].join(' | '),
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: document.environment == 2
                                ? pw.FontWeight.bold
                                : pw.FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    pw.Text(
                      'Chave de acesso: ${document.accessKey}',
                      style: const pw.TextStyle(fontSize: 7),
                    ),
                  ],
                ),
              ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'DANFE - Página ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 7),
          ),
        ),
        build: (context) => [
          if (document.model == 55 && options.showReceiptStub) ...[
            _receiptStub(document),
            pw.SizedBox(height: 8),
          ],
          _a4OfficialHeader(document, options),
          if (document.model == 55 && options.canceled) ...[
            _canceledA4Banner(),
            pw.SizedBox(height: 8),
          ],
          if (document.contingency != null) ...[
            _contingencyA4Banner(document.contingency!),
            pw.SizedBox(height: 8),
          ],
          if (document.avulsa != null) ...[
            pw.SizedBox(height: 8),
            _avulsaBlock(document),
          ],
          if (document.recipient != null) ...[
            pw.SizedBox(height: 8),
            _recipientBlock(
              document.recipient!,
              showEmail: options.showRecipientEmail,
            ),
          ],
          if (document.withdrawal != null || document.delivery != null) ...[
            pw.SizedBox(height: 8),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (document.withdrawal != null)
                  pw.Expanded(
                    child: _locationBlock(
                      'Local de retirada',
                      document.withdrawal!,
                    ),
                  ),
                if (document.withdrawal != null && document.delivery != null)
                  pw.SizedBox(width: 12),
                if (document.delivery != null)
                  pw.Expanded(
                    child: _locationBlock(
                      'Local de entrega',
                      document.delivery!,
                    ),
                  ),
              ],
            ),
          ],
          if (_hasOperationContext(document)) ...[
            pw.SizedBox(height: 8),
            _sectionTitle('Identificação da operação'),
            pw.Text(
              _operationText(document),
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
          if (document.billing != null) ...[
            pw.SizedBox(height: 8),
            _billingBlock(document, options),
          ],
          pw.SizedBox(height: 8),
          _a4FiscalTotals(document, options),
          if (_hasReformTaxes(document)) _a4RtcTotals(document),
          if (_hasIssqn(document)) ...[
            pw.SizedBox(height: 8),
            _issqnBlock(document),
          ],
          pw.SizedBox(height: 8),
          _transportBlock(document),
          pw.SizedBox(height: 10),
          _sectionTitle('Dados dos produtos / serviços'),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Nº',
              'Cód',
              'Desc.',
              'NCM',
              'CST',
              'CFOP',
              'Un',
              'Qtd',
              'V. unit.',
              'Total',
              'BC ICMS',
              'V. ICMS',
              'V. IPI',
            ],
            data: [
              for (final item in document.items)
                [
                  '${item.number}',
                  _itemCode(item),
                  _itemDescription(
                    item,
                    includeAdditionalInfo: options.showItemAdditionalInfo,
                    showItemTaxDetails: options.showItemTaxDetails,
                    showItemTraceability: options.showItemTraceability,
                    showTaxableUnit: options.showTaxableUnit,
                    showPurchaseOrderItem: options.showPurchaseOrderItem,
                    taxableQuantityDecimals: options.quantityDecimals,
                    taxableUnitPriceDecimals: options.unitPriceDecimals,
                  ),
                  item.ncm,
                  _itemCst(item),
                  item.cfop,
                  item.unit,
                  FiscalDecimal.fromNum(
                    item.quantity,
                  ).toFixed(options.quantityDecimals),
                  FiscalDecimal.fromNum(
                    item.unitPrice,
                  ).toFixed(options.unitPriceDecimals),
                  item.merchandiseTotalFormatted,
                  _itemIcmsBase(item),
                  _itemIcmsValue(item),
                  FiscalDecimal.fromNum(item.ipi?.value ?? 0).toFixed(2),
                ],
            ],
            headerStyle: pw.TextStyle(
              fontSize: 6,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 7),
            border: itemBorder,
            cellAlignment: pw.Alignment.centerLeft,
            columnWidths: const {
              0: pw.FlexColumnWidth(0.45),
              1: pw.FlexColumnWidth(1.0),
              2: pw.FlexColumnWidth(2.75),
              3: pw.FlexColumnWidth(0.85),
              4: pw.FlexColumnWidth(0.75),
              5: pw.FlexColumnWidth(0.8),
              6: pw.FlexColumnWidth(0.55),
              7: pw.FlexColumnWidth(0.85),
              8: pw.FlexColumnWidth(1.05),
              9: pw.FlexColumnWidth(1.05),
              10: pw.FlexColumnWidth(1.08),
              11: pw.FlexColumnWidth(0.98),
              12: pw.FlexColumnWidth(1.03),
            },
          ),
          if (_hasReformTaxes(document)) ...[
            pw.SizedBox(height: 8),
            _a4RtcItemDetails(document),
          ],
          if (document.payments.isNotEmpty || document.changeValue != null) ...[
            pw.SizedBox(height: 8),
            _a4PaymentsBlock(document),
          ],
          if (_hasAdditionalContent(document, options)) ...[
            pw.SizedBox(height: 10),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (document.additionalInfo?.isNotEmpty == true)
                  pw.Expanded(child: _additionalBlock(document, options)),
              ],
            ),
          ],
          if (document.model == 65 && document.nfceSupplement != null) ...[
            pw.SizedBox(height: 10),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.BarcodeWidget(
                  data: document.nfceSupplement!.qrCode,
                  barcode: pw.Barcode.qrCode(),
                  width: 100,
                  height: 100,
                  drawText: false,
                ),
                pw.SizedBox(width: 10),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Consulta NFC-e',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      'QR Code: ${document.nfceSupplement!.qrCode}',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    pw.Text(
                      'URL da chave: ${document.nfceSupplement!.keyUrl}',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ],
                ),
              ],
            ),
          ],
          if (options.extraContent != null) ...[
            pw.SizedBox(height: 10),
            _sectionTitle('Conteúdo adicional'),
            pw.Text(
              options.extraContent!,
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _a4OfficialHeader(NfeDocument document, DanfePdfOptions options) {
    final issuer = document.issuer;
    final protocol = document.authorization == null
        ? options.epecProtocol == null
              ? 'DANFE sem protocolo de autorização'
              : 'EPEC ${options.epecProtocol} | ${_formatDateTime(options.epecDate ?? document.issueDate)}'
        : 'Protocolo ${document.authorization!.protocol} | '
              'Status ${document.authorization!.status} | '
              '${_formatDateTime(document.authorization!.authorizedAt)}';
    final operation = document.documentType == null
        ? ''
        : document.documentType == 0
        ? '0 - ENTRADA'
        : '1 - SAÍDA';
    final issuerLines = <pw.Widget>[
      pw.Text(
        issuer.name,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
      ),
      if (issuer.fantasyName != null)
        pw.Text(
          'Fantasia: ${issuer.fantasyName}',
          style: const pw.TextStyle(fontSize: 7),
        ),
      if (issuer.cnpj != null)
        pw.Text('CNPJ: ${issuer.cnpj}', style: const pw.TextStyle(fontSize: 7)),
      if (issuer.cpf != null)
        pw.Text('CPF: ${issuer.cpf}', style: const pw.TextStyle(fontSize: 7)),
      if (issuer.ie != null)
        pw.Text('IE: ${issuer.ie}', style: const pw.TextStyle(fontSize: 7)),
      if (issuer.ieSubstitute != null)
        pw.Text(
          'IE do substituto tributário: ${issuer.ieSubstitute}',
          style: const pw.TextStyle(fontSize: 7),
        ),
      if (issuer.municipalRegistration != null)
        pw.Text(
          'IM: ${issuer.municipalRegistration}',
          style: const pw.TextStyle(fontSize: 7),
        ),
      if (issuer.cnae != null)
        pw.Text('CNAE: ${issuer.cnae}', style: const pw.TextStyle(fontSize: 7)),
      if (issuer.suframa != null)
        pw.Text(
          'SUFRAMA: ${issuer.suframa}',
          style: const pw.TextStyle(fontSize: 7),
        ),
      if (issuer.crt != null)
        pw.Text('CRT: ${issuer.crt}', style: const pw.TextStyle(fontSize: 7)),
      if (issuer.address != null)
        pw.Text(
          '${issuer.address}, ${issuer.addressNumber ?? 's/n'}'
          '${issuer.addressComplement == null ? '' : ' - ${issuer.addressComplement}'}'
          '${issuer.neighborhood == null ? '' : ' - ${issuer.neighborhood}'}',
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 7),
        ),
      if (issuer.city != null || issuer.state != null)
        pw.Text(
          '${issuer.city ?? ''}/${issuer.state ?? ''}'
          '${issuer.zipCode == null ? '' : ' - CEP ${issuer.zipCode}'}',
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 7),
        ),
      if (issuer.phone != null)
        pw.Text(
          'Fone/Fax: ${issuer.phone}',
          style: const pw.TextStyle(fontSize: 7),
        ),
    ];
    final logo = options.logoBytes == null
        ? null
        : pw.Container(
            height: 28,
            margin: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Image(
              pw.MemoryImage(Uint8List.fromList(options.logoBytes!)),
              fit: pw.BoxFit.contain,
            ),
          );
    return pw.Column(
      children: [
        pw.Table(
          border: pw.TableBorder.all(),
          columnWidths: const {
            0: pw.FlexColumnWidth(0.41),
            1: pw.FlexColumnWidth(0.17),
            2: pw.FlexColumnWidth(0.42),
          },
          children: [
            pw.TableRow(
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(
                        'IDENTIFICAÇÃO DO EMITENTE',
                        style: const pw.TextStyle(fontSize: 6),
                      ),
                      if (logo != null) logo,
                      ...issuerLines,
                    ],
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(
                        options.title,
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Documento Auxiliar da Nota Fiscal Eletrônica',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(fontSize: 6),
                      ),
                      if (operation.isNotEmpty)
                        pw.Text(
                          operation,
                          style: const pw.TextStyle(fontSize: 7),
                        ),
                      pw.Text(
                        'Nº ${document.number.toString().padLeft(9, '0')}',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Série ${document.series.toString().padLeft(3, '0')}',
                        style: const pw.TextStyle(fontSize: 7),
                      ),
                      pw.Text(
                        'Emissão ${_formatDate(document.issueDate)}',
                        style: const pw.TextStyle(fontSize: 7),
                      ),
                      pw.Text(
                        'FOLHA 1',
                        style: const pw.TextStyle(fontSize: 7),
                      ),
                    ],
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Column(
                    children: [
                      pw.BarcodeWidget(
                        data: document.accessKey,
                        barcode: pw.Barcode.code128(),
                        height: 25,
                        width: 180,
                        drawText: false,
                      ),
                      pw.Text(
                        'CHAVE DE ACESSO',
                        style: pw.TextStyle(fontSize: 6),
                      ),
                      pw.Text(
                        _groupAccessKey(document.accessKey),
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        document.environment == 2
                            ? 'SEM VALOR FISCAL - HOMOLOGAÇÃO'
                            : 'Consulta de autenticidade no portal da NF-e',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: 6,
                          fontWeight: document.environment == 2
                              ? pw.FontWeight.bold
                              : pw.FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.Table(
          border: pw.TableBorder.all(),
          columnWidths: const {
            0: pw.FlexColumnWidth(0.58),
            1: pw.FlexColumnWidth(0.42),
          },
          children: [
            pw.TableRow(
              children: [
                _headerField(
                  'NATUREZA DA OPERAÇÃO',
                  document.operationNature ?? 'Não informada',
                ),
                _headerField('PROTOCOLO DE AUTORIZAÇÃO DE USO', protocol),
              ],
            ),
          ],
        ),
        pw.Table(
          border: pw.TableBorder.all(),
          columnWidths: const {
            0: pw.FlexColumnWidth(0.34),
            1: pw.FlexColumnWidth(0.33),
            2: pw.FlexColumnWidth(0.33),
          },
          children: [
            pw.TableRow(
              children: [
                _headerField(
                  'INSCRIÇÃO ESTADUAL',
                  issuer.ie ?? 'Não informada',
                ),
                _headerField(
                  'IE DO SUBSTITUTO TRIBUTÁRIO',
                  issuer.ieSubstitute ?? 'Não informada',
                ),
                _headerField('CNPJ / CPF', issuer.taxId),
              ],
            ),
          ],
        ),
        pw.Table(
          border: pw.TableBorder.all(),
          columnWidths: const {
            0: pw.FlexColumnWidth(0.34),
            1: pw.FlexColumnWidth(0.66),
          },
          children: [
            pw.TableRow(
              children: [
                _headerField(
                  'CÓDIGO DO REGIME TRIBUTÁRIO',
                  issuer.crt ?? 'Não informado',
                ),
                _headerField(
                  'TIPO DE REGIME DE APURAÇÃO DO IBS E DA CBS',
                  'Campo reservado',
                ),
              ],
            ),
          ],
        ),
        if (options.canceled ||
            options.establishmentCopy ||
            options.printSummary ||
            options.offlineDoublePrint ||
            options.extraContent != null)
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 3),
            child: pw.Text(
              options.canceled ? 'DOCUMENTO CANCELADO' : _optionText(options),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
          ),
        pw.SizedBox(height: 6),
      ],
    );
  }

  pw.Widget _headerField(String label, String value) => pw.Container(
    padding: const pw.EdgeInsets.all(4),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 6)),
        pw.Text(
          value,
          maxLines: 2,
          overflow: pw.TextOverflow.clip,
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
        ),
      ],
    ),
  );

  pw.Widget _a4FiscalTotals(NfeDocument document, DanfePdfOptions options) {
    final rows = <List<String>>[
      ['BC ICMS', _sumIcmsBase(document), 'ICMS', _sumIcms(document)],
      ['BC ICMS-ST', _sumStBase(document), 'ICMS-ST', _sumSt(document)],
      ['FCP', _sumFcp(document), 'FCP ST', _sumFcpSt(document)],
      ['FCP ST retido', _sumFcpStRetained(document), '', ''],
      [
        'ICMS monofásico',
        _sumIcmsMonophase(document, false),
        'ICMS mono. retido',
        _sumIcmsMonophase(document, true),
      ],
      ['Produtos', _sumProducts(document), 'Frete', _sumFreight(document)],
      ['Seguro', _sumInsurance(document), 'Desconto', _sumDiscount(document)],
      ['II', _sumImportDuty(document), 'IPI', _sumIpi(document)],
      ['ISSQN', _sumIssqn(document), 'Outros', _sumOther(document)],
      if (options.showInterstateTaxes) ...[
        [
          'ICMS UF destino',
          _sumIcmsDestination(document),
          'ICMS UF origem',
          _sumIcmsOrigin(document),
        ],
        ['FCP UF destino', _sumFcpDestination(document), '', ''],
      ],
      if (options.showApproximateTaxes)
        [
          'Tributos aproximados',
          _sumApproximateTaxes(document),
          'Valor da nota',
          document.totalFormatted,
        ]
      else
        ['Valor da nota', document.totalFormatted, '', ''],
    ];
    if (options.showPisCofins) {
      rows.insert(5, [
        'PIS',
        _sumPis(document),
        'COFINS',
        _sumCofins(document),
      ]);
    }
    if (document.serviceTotal != null) {
      rows.add([
        'ISSQN declarado',
        FiscalDecimal.fromNum(document.serviceTotal!.taxValue).toFixed(2),
        'Retenções',
        _sumRetentions(document),
      ]);
      rows.add([
        'Serviços',
        FiscalDecimal.fromNum(document.serviceTotal!.taxBase).toFixed(2),
        '',
        '',
      ]);
    } else if (document.taxRetention != null) {
      rows.add(['Retenções', _sumRetentions(document), '', '']);
    }
    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(border: pw.Border.all()),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              'CÁLCULO DO IMPOSTO',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.TableHelper.fromTextArray(
            headers: const ['Campo', 'Valor', 'Campo', 'Valor'],
            data: rows,
            headerStyle: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 7),
            cellAlignment: pw.Alignment.centerLeft,
            border: pw.TableBorder.all(),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.5),
              1: pw.FlexColumnWidth(0.8),
              2: pw.FlexColumnWidth(1.5),
              3: pw.FlexColumnWidth(0.8),
            },
          ),
        ],
      ),
    );
  }

  bool _hasIssqn(NfeDocument document) =>
      document.serviceTotal != null ||
      document.items.any((item) => item.serviceTax != null);

  bool _hasReformTaxes(NfeDocument document) => document.items.any(
    (item) =>
        item.ibsCbs != null ||
        item.ibsCbsMonophase != null ||
        item.selectiveTax != null,
  );

  pw.Widget _a4RtcTotals(NfeDocument document) {
    final rows = <List<String>>[
      ['CBS', _sumCbs(document), 'IBS UF', _sumIbsUf(document)],
      [
        'IBS município',
        _sumIbsMunicipal(document),
        'Imposto seletivo',
        _sumSelective(document),
      ],
      [
        'IBS monofásico',
        _sumIbsMonophase(document, true),
        'CBS monofásica',
        _sumIbsMonophase(document, false),
      ],
      [
        'IBS mono. por retenção',
        _sumIbsMonophaseRetained(document, true),
        'CBS mono. por retenção',
        _sumIbsMonophaseRetained(document, false),
      ],
      [
        'Crédito presumido IBS',
        _sumOperationCredit(document, true, false),
        'Crédito presumido CBS',
        _sumOperationCredit(document, false, false),
      ],
      [
        'Estorno de crédito IBS',
        _sumCreditReversal(document, true),
        'Estorno de crédito CBS',
        _sumCreditReversal(document, false),
      ],
    ];
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(top: 8),
      decoration: pw.BoxDecoration(border: pw.Border.all()),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              'TOTAL DO IBS / CBS / IS',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.TableHelper.fromTextArray(
            headers: const ['Campo', 'Valor', 'Campo', 'Valor'],
            data: rows,
            headerStyle: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 7),
            cellAlignment: pw.Alignment.centerLeft,
            border: pw.TableBorder.all(),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.8),
              1: pw.FlexColumnWidth(0.8),
              2: pw.FlexColumnWidth(1.8),
              3: pw.FlexColumnWidth(0.8),
            },
          ),
        ],
      ),
    );
  }

  pw.Widget _a4RtcItemDetails(NfeDocument document) {
    final rows = <List<String>>[
      for (final item in document.items)
        if (item.ibsCbs != null ||
            item.ibsCbsMonophase != null ||
            item.selectiveTax != null)
          [
            '${item.number}',
            [
              if (item.ibsCbs != null)
                'IBS/CBS ${item.ibsCbs!.classificationCode}',
              if (item.ibsCbsMonophase != null)
                'Mono ${item.ibsCbsMonophase!.classificationCode}',
              if (item.selectiveTax != null)
                'IS ${item.selectiveTax!.classificationCode}',
            ].join('\n'),
            [
              if (item.ibsCbs != null) ...[
                'BC ${FiscalDecimal.fromNum(item.ibsCbs!.base).toFixed(2)}',
                'IBS UF ${_rtcRate(item.ibsCbs!.ibsUfReduction?.effectiveRate ?? item.ibsCbs!.ibsUfRate)}% / ${item.ibsCbs!.ibsUfValue.toFixed(2)}',
                'IBS Mun. ${_rtcRate(item.ibsCbs!.ibsMunicipalReduction?.effectiveRate ?? item.ibsCbs!.ibsMunicipalRate)}% / ${item.ibsCbs!.ibsMunicipalValue.toFixed(2)}',
                'CBS ${_rtcRate(item.ibsCbs!.cbsReduction?.effectiveRate ?? item.ibsCbs!.cbsRate)}% / ${item.ibsCbs!.cbsValue.toFixed(2)}',
              ],
              if (item.ibsCbsMonophase != null) ...[
                if (item.ibsCbsMonophase!.ibsValue != null)
                  'IBS mono. ${FiscalDecimal.fromNum(item.ibsCbsMonophase!.ibsValue!).toFixed(2)}',
                if (item.ibsCbsMonophase!.cbsValue != null)
                  'CBS mono. ${FiscalDecimal.fromNum(item.ibsCbsMonophase!.cbsValue!).toFixed(2)}',
                if (item.ibsCbsMonophase!.ibsRetainedValue != null)
                  'IBS mono. retido ${FiscalDecimal.fromNum(item.ibsCbsMonophase!.ibsRetainedValue!).toFixed(2)}',
                if (item.ibsCbsMonophase!.cbsRetainedValue != null)
                  'CBS mono. retida ${FiscalDecimal.fromNum(item.ibsCbsMonophase!.cbsRetainedValue!).toFixed(2)}',
              ],
            ].join('\n'),
            item.selectiveTax == null
                ? '-'
                : 'BC ${FiscalDecimal.fromNum(item.selectiveTax!.base).toFixed(2)}\n'
                      'IS ${_rtcRate(item.selectiveTax!.rate)}% / ${item.selectiveTax!.value.toFixed(2)}',
          ],
    ];
    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(border: pw.Border.all()),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              'DETALHAMENTO IBS / CBS / IS POR ITEM',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Item',
              'Classificação tributária',
              'IBS / CBS',
              'IS',
            ],
            data: rows,
            headerStyle: pw.TextStyle(
              fontSize: 6,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 6),
            cellAlignment: pw.Alignment.topLeft,
            border: pw.TableBorder.all(),
            columnWidths: const {
              0: pw.FlexColumnWidth(0.35),
              1: pw.FlexColumnWidth(1.1),
              2: pw.FlexColumnWidth(3.15),
              3: pw.FlexColumnWidth(1.3),
            },
          ),
        ],
      ),
    );
  }

  String _rtcRate(num rate) => FiscalDecimal.fromNum(rate).toFixed(4);

  pw.Widget _issqnBlock(NfeDocument document) {
    final rows = <List<String>>[
      for (final item in document.items)
        if (item.serviceTax != null)
          [
            '${item.number}',
            item.serviceTax!.serviceCode ?? item.serviceTax!.serviceListCode,
            item.serviceTax!.municipalityCode,
            _formatDate(item.serviceTax!.competenceDate),
            FiscalDecimal.fromNum(item.serviceTax!.base).toFixed(2),
            FiscalDecimal.fromNum(item.serviceTax!.rate).toFixed(2),
            FiscalDecimal.fromNum(item.serviceTax!.value).toFixed(2),
            FiscalDecimal.fromNum(item.serviceTax!.retained).toFixed(2),
          ],
    ];
    final total = document.serviceTotal;
    if (rows.isEmpty && total != null) {
      rows.add([
        '-',
        total.taxRegime?.toString() ?? '-',
        '-',
        _formatDate(total.competenceDate),
        FiscalDecimal.fromNum(total.taxBase).toFixed(2),
        '-',
        FiscalDecimal.fromNum(total.taxValue).toFixed(2),
        FiscalDecimal.fromNum(total.retained).toFixed(2),
      ]);
    }
    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(border: pw.Border.all()),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              'ISSQN - SERVIÇOS',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Item',
              'Cód. serviço / lista',
              'Município fato gerador',
              'Competência',
              'BC ISSQN',
              'Alíquota',
              'ISSQN',
              'Retido',
            ],
            data: rows,
            headerStyle: pw.TextStyle(
              fontSize: 6,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 6),
            cellAlignment: pw.Alignment.centerLeft,
            border: pw.TableBorder.all(),
          ),
        ],
      ),
    );
  }

  pw.Widget _a4PaymentsBlock(NfeDocument document) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(5),
    decoration: pw.BoxDecoration(border: pw.Border.all()),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'PAGAMENTOS',
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
        ),
        for (final payment in document.payments)
          pw.Text(
            '${payment.type}${payment.description == null ? '' : ' - ${payment.description}'}: ${FiscalDecimal.fromNum(payment.value).toFixed(2)}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        if (document.changeValue != null)
          pw.Text(
            'Troco: ${FiscalDecimal.fromNum(document.changeValue!).toFixed(2)}',
            style: const pw.TextStyle(fontSize: 8),
          ),
      ],
    ),
  );

  String _groupAccessKey(String value) => value
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAllMapped(RegExp(r'.{1,4}'), (match) => '${match.group(0)} ')
      .trim();

  pw.Widget _recipientBlock(
    Party recipient, {
    bool showEmail = true,
  }) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(5),
    decoration: pw.BoxDecoration(border: pw.Border.all()),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'DESTINATÁRIO / REMETENTE',
          style: const pw.TextStyle(fontSize: 6),
        ),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 3,
              child: pw.Text(
                recipient.name,
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Expanded(
              flex: 2,
              child: pw.Text(
                recipient.taxId,
                textAlign: pw.TextAlign.right,
                style: const pw.TextStyle(fontSize: 8),
              ),
            ),
          ],
        ),
        pw.Text(
          [
            if (recipient.ie != null) 'IE: ${recipient.ie}',
            if (recipient.recipientIeIndicator != null)
              'indIEDest: ${recipient.recipientIeIndicator}',
          ].join(' | '),
          style: const pw.TextStyle(fontSize: 7),
        ),
        if (recipient.address != null)
          pw.Text(
            '${recipient.address}, ${recipient.addressNumber ?? 's/n'}'
            '${recipient.addressComplement == null ? '' : ' - ${recipient.addressComplement}'}'
            '${recipient.neighborhood == null ? '' : ' - ${recipient.neighborhood}'}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        if (recipient.city != null ||
            recipient.state != null ||
            recipient.zipCode != null)
          pw.Text(
            '${recipient.city ?? ''}/${recipient.state ?? ''}'
            '${recipient.zipCode == null ? '' : ' - CEP ${recipient.zipCode}'}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        if (recipient.phone != null || (showEmail && recipient.email != null))
          pw.Text(
            [
              if (recipient.phone != null) 'Fone: ${recipient.phone}',
              if (showEmail && recipient.email != null)
                'E-mail: ${recipient.email}',
            ].join(' | '),
            style: const pw.TextStyle(fontSize: 7),
          ),
      ],
    ),
  );

  pw.Widget _sectionTitle(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.Text(text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
  );

  pw.Widget _canceledA4Banner() => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 8),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.red, width: 1.5),
    ),
    child: pw.Text(
      'DOCUMENTO CANCELADO',
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(
        color: PdfColors.red,
        fontSize: 13,
        fontWeight: pw.FontWeight.bold,
      ),
    ),
  );

  pw.Widget _contingencyA4Banner(Contingency contingency) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.orange, width: 1.2),
    ),
    child: pw.Column(
      children: [
        pw.Text(
          'DANFE IMPRESSO EM CONTINGÊNCIA',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            color: PdfColors.orange,
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Text(
          'tpEmis ${contingency.mode.code} | ${contingency.reason} | '
          '${_formatDateTime(contingency.activatedAt)}',
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 7),
        ),
      ],
    ),
  );

  pw.Widget _locationBlock(String title, NfeLocation location) => pw.Container(
    padding: const pw.EdgeInsets.all(5),
    decoration: pw.BoxDecoration(border: pw.Border.all()),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle(title),
        pw.Text(
          [
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
          ].join(' - '),
          style: const pw.TextStyle(fontSize: 8),
        ),
      ],
    ),
  );

  pw.Widget _receiptStub(NfeDocument document) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(6),
    decoration: pw.BoxDecoration(border: pw.Border.all()),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'CANHOTO - RECEBIMENTO DA MERCADORIA',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Recebemos de ${document.issuer.name} os produtos constantes desta nota fiscal.',
          style: const pw.TextStyle(fontSize: 8),
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                'NF-e ${document.number}  Série ${document.series}',
                style: const pw.TextStyle(fontSize: 8),
              ),
            ),
            pw.SizedBox(
              width: 170,
              child: pw.Text(
                'Data: ____/____/________',
                style: const pw.TextStyle(fontSize: 8),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Text(
          'Nome e assinatura do recebedor: ________________________________________________',
          style: const pw.TextStyle(fontSize: 8),
        ),
      ],
    ),
  );

  pw.Widget _transportBlock(NfeDocument document) {
    final transport = document.transport;
    final hasCarrier =
        transport.carrier != null ||
        transport.carrierName != null ||
        transport.carrierAddress != null ||
        transport.carrierCity != null;
    final hasVehicle =
        transport.vehiclePlate != null ||
        transport.railcar != null ||
        transport.barge != null ||
        transport.trailers.isNotEmpty;
    final hasVolumes = transport.volumes.isNotEmpty;
    final hasRetention = transport.retention != null;
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(5),
      decoration: pw.BoxDecoration(border: pw.Border.all()),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('Transportador / Volumes transportados'),
          pw.Text(
            'Frete: ${transport.freightMode}',
            style: const pw.TextStyle(fontSize: 8),
          ),
          if (hasCarrier)
            pw.Text(
              [
                if (transport.carrierName != null) transport.carrierName!,
                if (transport.carrier != null) 'Doc. ${transport.carrier}',
                if (transport.carrierIe != null) 'IE ${transport.carrierIe}',
                if (transport.carrierAddress != null) transport.carrierAddress!,
                if (transport.carrierCity != null) transport.carrierCity!,
              ].join(' | '),
              style: const pw.TextStyle(fontSize: 8),
            ),
          if (hasVehicle)
            pw.Text(
              [
                if (transport.vehiclePlate != null)
                  'Veículo ${transport.vehiclePlate}',
                if (transport.vehicleState != null) transport.vehicleState!,
                if (transport.vehicleRegistration != null)
                  'RNTC ${transport.vehicleRegistration}',
                if (transport.railcar != null) 'Vagão ${transport.railcar}',
                if (transport.barge != null) 'Balsa ${transport.barge}',
                if (transport.trailers.isNotEmpty)
                  'Reboques ${transport.trailers.map((v) => v.plate).join(', ')}',
              ].join(' | '),
              style: const pw.TextStyle(fontSize: 8),
            ),
          if (hasVolumes)
            pw.Text(
              'Volumes: ${transport.volumes.map((volume) => [if (volume.quantity != null) volume.quantity.toString(), if (volume.kind != null) volume.kind!, if (volume.brand != null) volume.brand!, if (volume.number != null) volume.number!, if (volume.seal.isNotEmpty) 'Lacres ${volume.seal.join(', ')}'].join(' ')).join(' | ')}',
              style: const pw.TextStyle(fontSize: 8),
            ),
          if (hasRetention)
            pw.Text(
              'Retenção: serviço ${FiscalDecimal.fromNum(transport.retention!.serviceValue).toFixed(2)} | '
              'BC ${FiscalDecimal.fromNum(transport.retention!.taxBase).toFixed(2)} | '
              'ICMS ${FiscalDecimal.fromNum(transport.retention!.taxValue).toFixed(2)}',
              style: const pw.TextStyle(fontSize: 8),
            ),
        ],
      ),
    );
  }

  String _optionText(DanfePdfOptions options) => [
    if (options.canceled) 'DOCUMENTO CANCELADO',
    if (options.establishmentCopy) 'Via estabelecimento',
    if (options.printSummary) 'Via resumida',
    if (options.offlineDoublePrint) '2a via de contingência offline',
  ].join(' | ');

  String _formatDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';

  String _formatDateTime(DateTime value) =>
      '${_formatDate(value)} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';

  bool _hasOperationContext(NfeDocument document) =>
      document.operationNature != null ||
      document.documentType != null ||
      document.destinationType != null ||
      document.purpose != null ||
      document.finalConsumer != null ||
      document.presenceIndicator != null ||
      document.intermediaryIndicator != null ||
      document.operationLocationCode != null ||
      document.municipalityCode != null ||
      document.ibsMunicipalityCode != null ||
      document.deliveryForecast != null ||
      document.processCode != null ||
      document.applicationVersion != null ||
      document.contingency != null ||
      document.withdrawal != null ||
      document.delivery != null ||
      document.references.isNotEmpty;

  String _operationText(NfeDocument document) => [
    if (document.operationNature != null)
      'Natureza da operação: ${document.operationNature}',
    if (document.documentType != null)
      'Tipo: ${document.documentType == 0 ? 'Entrada' : 'Saída'} (${document.documentType})',
    if (document.destinationType != null)
      'Destino: ${document.destinationType}',
    if (document.purpose != null) 'Finalidade: ${document.purpose}',
    if (document.finalConsumer != null)
      'Consumidor final: ${document.finalConsumer}',
    if (document.presenceIndicator != null)
      'Presença: ${document.presenceIndicator}',
    if (document.intermediaryIndicator != null)
      'Intermediador: ${document.intermediaryIndicator}',
    if (document.operationLocationCode != null)
      'Local da operação: ${document.operationLocationCode}',
    if (document.municipalityCode != null)
      'Município do fato gerador: ${document.municipalityCode}',
    if (document.ibsMunicipalityCode != null)
      'Município do fato gerador IBS/CBS: ${document.ibsMunicipalityCode}',
    if (document.deliveryForecast != null)
      'Previsão de entrega: ${_formatDate(document.deliveryForecast!)}',
    if (document.processCode != null || document.applicationVersion != null)
      'Processo: ${document.processCode ?? ''}${document.applicationVersion == null ? '' : ' / ${document.applicationVersion}'}',
    if (document.contingency != null)
      'CONTINGÊNCIA: tpEmis ${document.contingency!.mode.code} - ${document.contingency!.reason} (${_formatDateTime(document.contingency!.activatedAt)})',
    if (document.withdrawal != null) 'Retirada informada',
    if (document.delivery != null) 'Entrega informada',
    if (document.references.isNotEmpty)
      'Documentos referenciados: ${document.references.length}',
  ].join(' | ');

  String _sumProducts(NfeDocument document) => document.items
      .where((item) => item.includeInTotal)
      .fold(
        FiscalDecimal.parse('0'),
        (sum, item) => sum + item.merchandiseTotalDecimal,
      )
      .toFixed(2);

  String _sumIcmsBase(NfeDocument document) => document.items
      .where((item) => item.includeInTotal)
      .fold(
        FiscalDecimal.parse('0'),
        (sum, item) =>
            sum +
            FiscalDecimal.fromNum(
              item.icms?.base ??
                  item.icmsSt?.base ??
                  item.icmsSimples?.base ??
                  0,
            ),
      )
      .toFixed(2);

  String _sumStBase(NfeDocument document) => document.items
      .where((item) => item.includeInTotal)
      .fold(
        FiscalDecimal.parse('0'),
        (sum, item) =>
            sum +
            FiscalDecimal.fromNum(
              item.icmsSt?.stBase ?? item.icmsSimples?.stBase ?? 0,
            ),
      )
      .toFixed(2);

  String _sumFreight(NfeDocument document) => document.items
      .where((item) => item.includeInTotal)
      .fold(
        FiscalDecimal.parse('0'),
        (sum, item) => sum + FiscalDecimal.fromNum(item.freight),
      )
      .toFixed(2);

  String _sumInsurance(NfeDocument document) => document.items
      .where((item) => item.includeInTotal)
      .fold(
        FiscalDecimal.parse('0'),
        (sum, item) => sum + FiscalDecimal.fromNum(item.insurance),
      )
      .toFixed(2);

  String _sumImportDuty(NfeDocument document) => document.items
      .where((item) => item.includeInTotal)
      .fold(
        FiscalDecimal.parse('0'),
        (sum, item) => sum + FiscalDecimal.fromNum(item.importDuty),
      )
      .toFixed(2);

  String _sumOther(NfeDocument document) => document.items
      .where((item) => item.includeInTotal)
      .fold(
        FiscalDecimal.parse('0'),
        (sum, item) => sum + FiscalDecimal.fromNum(item.other),
      )
      .toFixed(2);

  String _sumRetentions(NfeDocument document) {
    final retention = document.taxRetention;
    if (retention == null) return '0.00';
    return (FiscalDecimal.fromNum(retention.pis) +
            FiscalDecimal.fromNum(retention.cofins) +
            FiscalDecimal.fromNum(retention.csll) +
            FiscalDecimal.fromNum(retention.irrf) +
            FiscalDecimal.fromNum(retention.socialSecurity))
        .toFixed(2);
  }

  String _sumDiscount(NfeDocument document) => document.items
      .where((item) => item.includeInTotal)
      .fold(
        FiscalDecimal.parse('0'),
        (sum, item) => sum + FiscalDecimal.fromNum(item.discount),
      )
      .toFixed(2);

  String _sumIpi(NfeDocument document) => document.items
      .where((item) => item.includeInTotal)
      .fold(
        FiscalDecimal.parse('0'),
        (sum, item) => sum + FiscalDecimal.fromNum(item.ipi?.value ?? 0),
      )
      .toFixed(2);

  String _sumSt(NfeDocument document) => document.items
      .where((item) => item.includeInTotal)
      .fold(
        FiscalDecimal.parse('0'),
        (sum, item) => sum + FiscalDecimal.fromNum(item.icmsSt?.stValue ?? 0),
      )
      .toFixed(2);

  String _sumIcms(NfeDocument document) => document.items
      .where((item) => item.includeInTotal)
      .fold(
        FiscalDecimal.parse('0'),
        (sum, item) => sum + FiscalDecimal.fromNum(item.icms?.value ?? 0),
      )
      .toFixed(2);

  String _sumIcmsDestination(NfeDocument document) => document.items
      .where((item) => item.includeInTotal)
      .fold(
        FiscalDecimal.parse('0'),
        (sum, item) =>
            sum +
            FiscalDecimal.fromNum(
              item.icmsUfDestination?.destinationValue ?? 0,
            ),
      )
      .toFixed(2);

  String _sumIcmsOrigin(NfeDocument document) => document.items
      .where((item) => item.includeInTotal)
      .fold(
        FiscalDecimal.parse('0'),
        (sum, item) =>
            sum +
            FiscalDecimal.fromNum(item.icmsUfDestination?.originValue ?? 0),
      )
      .toFixed(2);

  String _sumFcpDestination(NfeDocument document) => document.items
      .where((item) => item.includeInTotal)
      .fold(
        FiscalDecimal.parse('0'),
        (sum, item) =>
            sum + FiscalDecimal.fromNum(item.icmsUfDestination?.fcpValue ?? 0),
      )
      .toFixed(2);

  String _sumPis(NfeDocument document) => document.items
      .where((item) => item.includeInTotal)
      .fold(
        FiscalDecimal.parse('0'),
        (sum, item) => sum + FiscalDecimal.fromNum(item.pis?.value ?? 0),
      )
      .toFixed(2);

  String _sumCofins(NfeDocument document) => document.items
      .where((item) => item.includeInTotal)
      .fold(
        FiscalDecimal.parse('0'),
        (sum, item) => sum + FiscalDecimal.fromNum(item.cofins?.value ?? 0),
      )
      .toFixed(2);

  String _sumIssqn(NfeDocument document) => document.items
      .where((item) => item.includeInTotal)
      .fold(
        FiscalDecimal.parse('0'),
        (sum, item) => sum + FiscalDecimal.fromNum(item.serviceTax?.value ?? 0),
      )
      .toFixed(2);

  String _sumIbsUf(NfeDocument document) => document.items
      .where((item) => item.includeInTotal)
      .fold(
        FiscalDecimal.parse('0'),
        (sum, item) =>
            sum + (item.ibsCbs?.ibsUfValue ?? FiscalDecimal.parse('0')),
      )
      .toFixed(2);

  String _sumIcmsMonophase(NfeDocument document, bool retained) => document
      .items
      .where((item) => item.includeInTotal)
      .fold(
        FiscalDecimal.parse('0'),
        (sum, item) =>
            sum +
            FiscalDecimal.fromNum(
              retained
                  ? (item.icmsMonophase?.retainedValue ?? 0)
                  : (item.icmsMonophase?.value ?? 0),
            ),
      )
      .toFixed(2);

  String _sumFcp(NfeDocument document) => document.items
      .where((item) => item.includeInTotal)
      .fold(
        FiscalDecimal.parse('0'),
        (sum, item) =>
            sum +
            FiscalDecimal.fromNum(
              item.icms?.fcpValue ??
                  item.icmsSt?.fcpValue ??
                  item.icmsSimples?.fcpStValue ??
                  0,
            ),
      )
      .toFixed(2);

  String _sumFcpSt(NfeDocument document) => document.items
      .where((item) => item.includeInTotal)
      .fold(
        FiscalDecimal.parse('0'),
        (sum, item) =>
            sum +
            FiscalDecimal.fromNum(
              item.icmsSt?.fcpStValue ?? item.icmsSimples?.fcpStValue ?? 0,
            ),
      )
      .toFixed(2);

  String _sumFcpStRetained(NfeDocument document) => document.items
      .where((item) => item.includeInTotal)
      .fold(
        FiscalDecimal.parse('0'),
        (sum, item) =>
            sum +
            FiscalDecimal.fromNum(item.icmsStRetained?.retainedFcpValue ?? 0),
      )
      .toFixed(2);

  String _sumIbsMunicipal(NfeDocument document) => document.items
      .where((item) => item.includeInTotal)
      .fold(
        FiscalDecimal.parse('0'),
        (sum, item) =>
            sum + (item.ibsCbs?.ibsMunicipalValue ?? FiscalDecimal.parse('0')),
      )
      .toFixed(2);

  String _sumCbs(NfeDocument document) => document.items
      .where((item) => item.includeInTotal)
      .fold(
        FiscalDecimal.parse('0'),
        (sum, item) =>
            sum + (item.ibsCbs?.cbsValue ?? FiscalDecimal.parse('0')),
      )
      .toFixed(2);

  String _sumIbsMonophase(NfeDocument document, bool ibs) => document.items
      .where((item) => item.includeInTotal)
      .fold(
        FiscalDecimal.parse('0'),
        (sum, item) =>
            sum +
            (ibs
                ? (item.ibsCbsMonophase?.totalIbsValue ??
                      FiscalDecimal.parse('0'))
                : (item.ibsCbsMonophase?.totalCbsValue ??
                      FiscalDecimal.parse('0'))),
      )
      .toFixed(2);

  String _sumIbsMonophaseRetained(NfeDocument document, bool ibs) => document
      .items
      .where((item) => item.includeInTotal)
      .fold(
        FiscalDecimal.parse('0'),
        (sum, item) =>
            sum +
            FiscalDecimal.fromNum(
              ibs
                  ? (item.ibsCbsMonophase?.ibsRetainedValue ?? 0)
                  : (item.ibsCbsMonophase?.cbsRetainedValue ?? 0),
            ),
      )
      .toFixed(2);

  String _sumSelective(NfeDocument document) => document.items
      .where((item) => item.includeInTotal)
      .fold(
        FiscalDecimal.parse('0'),
        (sum, item) =>
            sum + (item.selectiveTax?.value ?? FiscalDecimal.parse('0')),
      )
      .toFixed(2);

  String _sumOperationCredit(
    NfeDocument document,
    bool ibs,
    bool conditionalSuspension,
  ) => document.items
      .where((item) => item.includeInTotal)
      .fold(FiscalDecimal.parse('0'), (sum, item) {
        final credit = ibs
            ? item.ibsCbs?.operationCredit?.ibs
            : item.ibsCbs?.operationCredit?.cbs;
        if (credit == null ||
            credit.conditionalSuspension != conditionalSuspension) {
          return sum;
        }
        return sum + FiscalDecimal.fromNum(credit.value);
      })
      .toFixed(2);

  String _sumCreditReversal(NfeDocument document, bool ibs) => document.items
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
      )
      .toFixed(2);

  String _sumApproximateTaxes(NfeDocument document) => document.items
      .where((item) => item.includeInTotal)
      .fold(
        FiscalDecimal.parse('0'),
        (sum, item) =>
            sum + FiscalDecimal.fromNum(item.approximateTaxValue ?? 0),
      )
      .toFixed(2);

  String _itemDescription(
    NfeItem item, {
    bool includeAdditionalInfo = true,
    bool showItemTraceability = true,
    bool showItemTaxDetails = false,
    bool showTaxableUnit = true,
    bool showPurchaseOrderItem = false,
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
          'IBS UF ${FiscalDecimal.fromNum(item.ibsCbs!.regularTax!.ibsUfRate).toFixed(4)}% '
          '${FiscalDecimal.fromNum(item.ibsCbs!.regularTax!.ibsUfValue).toFixed(2)} | '
          'IBS Mun. ${FiscalDecimal.fromNum(item.ibsCbs!.regularTax!.ibsMunicipalRate).toFixed(4)}% '
          '${FiscalDecimal.fromNum(item.ibsCbs!.regularTax!.ibsMunicipalValue).toFixed(2)} | '
          'CBS ${FiscalDecimal.fromNum(item.ibsCbs!.regularTax!.cbsRate).toFixed(4)}% '
          '${FiscalDecimal.fromNum(item.ibsCbs!.regularTax!.cbsValue).toFixed(2)}',
    if (item.ibsCbs?.governmentTax != null)
      'Compra governamental sem redutor: IBS UF '
          '${FiscalDecimal.fromNum(item.ibsCbs!.governmentTax!.ibsUfValue).toFixed(2)} | '
          'IBS Mun. ${FiscalDecimal.fromNum(item.ibsCbs!.governmentTax!.ibsMunicipalValue).toFixed(2)} | '
          'CBS ${FiscalDecimal.fromNum(item.ibsCbs!.governmentTax!.cbsValue).toFixed(2)}',
    if (item.ibsCbs?.creditReversal != null)
      'Estorno de crédito: IBS ${FiscalDecimal.fromNum(item.ibsCbs!.creditReversal!.ibsValue).toFixed(2)} | '
          'CBS ${FiscalDecimal.fromNum(item.ibsCbs!.creditReversal!.cbsValue).toFixed(2)}',
    if (item.ibsCbs?.operationCredit != null)
      'Crédito presumido: base ${FiscalDecimal.fromNum(item.ibsCbs!.operationCredit!.base).toFixed(2)} | '
          'código ${item.ibsCbs!.operationCredit!.code}',
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
    if (includeAdditionalInfo && item.additionalInformation != null)
      item.additionalInformation!,
    if (includeAdditionalInfo && showItemTraceability)
      for (final batch in item.traceability)
        'Lote ${batch.batchNumber} | Fab. ${_formatDate(batch.manufacturedAt)} | Val. ${_formatDate(batch.expiresAt)}',
    if (includeAdditionalInfo && item.medication != null)
      'ANVISA ${item.medication!.anvisaProductCode} | PMC ${FiscalDecimal.fromNum(item.medication!.maximumConsumerPrice).toFixed(2)}',
  ].join('\n');

  String _itemCode(NfeItem item) => [
    item.code,
    if (item.ean != null) 'EAN: ${item.ean}',
    if (item.barcode != null) 'CBarra: ${item.barcode}',
    if (item.eanTrib != null) 'EAN trib.: ${item.eanTrib}',
    if (item.taxableBarcode != null) 'CBarra trib.: ${item.taxableBarcode}',
  ].join('\n');

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

  pw.Widget _billingBlock(NfeDocument document, DanfePdfOptions options) {
    final billing = document.billing!;
    final paymentIndicator = document.payments.isEmpty
        ? null
        : document.payments.first.indicator;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Cobrança'),
        if (options.showBillingText && billing.installments.isEmpty)
          pw.Text(
            '${paymentIndicator == 0 ? 'Pagamento à Vista' : 'Pagamento à Prazo'} - Fatura: ${billing.invoiceNumber} | Valor Original: ${FiscalDecimal.fromNum(billing.originalValue).toFixed(2)} | Desconto: ${FiscalDecimal.fromNum(billing.discount).toFixed(2)} | Valor Líquido: ${FiscalDecimal.fromNum(billing.netValue).toFixed(2)}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        pw.Text(
          'Fatura ${billing.invoiceNumber}  Original ${FiscalDecimal.fromNum(billing.originalValue).toFixed(2)}  Líquido ${FiscalDecimal.fromNum(billing.netValue).toFixed(2)}',
          style: const pw.TextStyle(fontSize: 8),
        ),
        for (final installment in billing.installments)
          pw.Text(
            'Duplicata ${installment.number} - ${_formatDate(installment.dueDate)} - ${FiscalDecimal.fromNum(installment.value).toFixed(2)}',
            style: const pw.TextStyle(fontSize: 8),
          ),
      ],
    );
  }

  pw.Widget _additionalBlock(NfeDocument document, DanfePdfOptions options) {
    final additional = document.additionalInfo;
    final automatic = options.generateAutomaticInfo
        ? _automaticAdditionalInfo(document)
        : const <String>[];
    final complementary = <pw.Widget>[
      for (final line in automatic)
        pw.Text(line, style: const pw.TextStyle(fontSize: 8)),
      if (additional?.complementary != null)
        pw.Text(
          additional!.complementary!,
          style: const pw.TextStyle(fontSize: 8),
        ),
      if (additional != null && options.showContributorObservations)
        for (final observation in additional.contributorObservations)
          pw.Text(
            'Contribuinte [${observation.field}]: ${observation.text}',
            style: const pw.TextStyle(fontSize: 8),
          ),
      if (additional != null)
        for (final process in additional.referencedProcesses)
          pw.Text(
            'Processo ${process.number} (${process.indicator})',
            style: const pw.TextStyle(fontSize: 8),
          ),
      if (additional != null)
        for (final authorized in additional.authorizedXml)
          pw.Text(
            'XML autorizado: ${authorized.cnpj ?? authorized.cpf}',
            style: const pw.TextStyle(fontSize: 8),
          ),
    ];
    final fiscal = <pw.Widget>[
      if (additional?.taxAuthority != null)
        pw.Text(
          additional!.taxAuthority!,
          style: const pw.TextStyle(fontSize: 8),
        ),
      if (additional != null && options.showFiscalObservations)
        for (final observation in additional.fiscalObservations)
          pw.Text(
            'Fisco [${observation.field}]: ${observation.text}',
            style: const pw.TextStyle(fontSize: 8),
          ),
    ];
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (complementary.isNotEmpty) ...[
          _sectionTitle('Informações complementares'),
          ...complementary,
        ],
        if (fiscal.isNotEmpty) ...[
          if (complementary.isNotEmpty) pw.SizedBox(height: 6),
          _sectionTitle('Reservado ao fisco'),
          ...fiscal,
        ],
      ],
    );
  }

  bool _hasAdditionalContent(NfeDocument document, DanfePdfOptions options) =>
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
    if (_sumApproximateTaxes(document) != '0.00')
      'Valor aproximado dos tributos: R\$ ${_sumApproximateTaxes(document)}',
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

  pw.Widget _avulsaBlock(NfeDocument document) {
    final avulsa = document.avulsa!;
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(border: pw.Border.all()),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('Emissão avulsa'),
          pw.Text(
            'Órgão: ${avulsa.agency} | Agente: ${avulsa.agent}',
            style: const pw.TextStyle(fontSize: 8),
          ),
          pw.Text(
            'UF: ${avulsa.state} | Repartição fiscal: ${avulsa.fiscalOffice}',
            style: const pw.TextStyle(fontSize: 8),
          ),
          if (avulsa.revenueDocumentNumber != null)
            pw.Text(
              'DAR: ${avulsa.revenueDocumentNumber}',
              style: const pw.TextStyle(fontSize: 8),
            ),
        ],
      ),
    );
  }

  void _addThermalPage(
    pw.Document pdf,
    NfeDocument document,
    DanfePdfOptions options,
  ) {
    final printEstablishmentCopy =
        options.offlineDoublePrint &&
        document.contingency?.mode.code == ContingencyMode.offlineNfce.code;
    final copies = printEstablishmentCopy ? 2 : 1;
    for (var copy = 0; copy < copies; copy++) {
      _addThermalSinglePage(
        pdf,
        document,
        copy == 0
            ? options
            : DanfePdfOptions(
                paperWidthMm: options.paperWidthMm,
                marginMm: options.marginMm,
                printSummary: options.printSummary,
                establishmentCopy: true,
                canceled: options.canceled,
                offlineDoublePrint: false,
                showReceiptStub: options.showReceiptStub,
                showPisCofins: options.showPisCofins,
                showApproximateTaxes: options.showApproximateTaxes,
                showInterstateTaxes: options.showInterstateTaxes,
                showItemAdditionalInfo: options.showItemAdditionalInfo,
                showItemTraceability: options.showItemTraceability,
                showItemTaxDetails: options.showItemTaxDetails,
                showTaxableUnit: options.showTaxableUnit,
                showPurchaseOrderItem: options.showPurchaseOrderItem,
                generateAutomaticInfo: options.generateAutomaticInfo,
                showBillingText: options.showBillingText,
                showRecipientEmail: options.showRecipientEmail,
                title: options.title,
                quantityDecimals: options.quantityDecimals,
                unitPriceDecimals: options.unitPriceDecimals,
                showContributorObservations:
                    options.showContributorObservations,
                showFiscalObservations: options.showFiscalObservations,
                epecProtocol: options.epecProtocol,
                epecDate: options.epecDate,
                extraContent: options.extraContent,
                fontBytes: options.fontBytes,
                logoBytes: options.logoBytes,
                a4MarginMm: options.a4MarginMm,
              ),
      );
    }
  }

  void _addThermalSinglePage(
    pw.Document pdf,
    NfeDocument document,
    DanfePdfOptions options,
  ) {
    final supplement = document.nfceSupplement;
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          options.paperWidthMm * PdfPageFormat.mm,
          _thermalHeight(document, options) * PdfPageFormat.mm,
          marginAll: options.marginMm * PdfPageFormat.mm,
        ),
        build: (context) => pw.Stack(
          children: [
            if (document.environment == 2)
              pw.Positioned.fill(
                child: pw.Center(
                  child: pw.Opacity(
                    opacity: 0.16,
                    child: pw.Transform.rotate(
                      angle: -0.55,
                      child: pw.Text(
                        'SEM VALOR FISCAL',
                        style: pw.TextStyle(
                          fontSize: 25,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor(0.35, 0.35, 0.35),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                if (options.logoBytes != null)
                  pw.Center(
                    child: pw.SizedBox(
                      width: 28 * PdfPageFormat.mm,
                      height: 16 * PdfPageFormat.mm,
                      child: pw.Image(
                        pw.MemoryImage(Uint8List.fromList(options.logoBytes!)),
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                  ),
                pw.Text(
                  'DANFE NFC-e${options.canceled ? ' - CANCELADA' : ''}',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (document.environment == 2)
                  pw.Text(
                    'SEM VALOR FISCAL - HOMOLOGAÇÃO',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                pw.SizedBox(height: 3),
                pw.Text(
                  document.issuer.name,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                if (document.issuer.cnpj != null)
                  pw.Text(
                    'CNPJ ${document.issuer.cnpj}',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                if (document.issuer.cpf != null)
                  pw.Text(
                    'CPF ${document.issuer.cpf}',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                if (document.avulsa != null)
                  pw.Text(
                    'Emissão avulsa: ${document.avulsa!.agency} - ${document.avulsa!.state}',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                if (document.recipient != null) ...[
                  pw.Text(
                    'Consumidor: ${document.recipient!.name}',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                  pw.Text(
                    '${document.recipient!.taxId}${document.recipient!.city == null ? '' : ' - ${document.recipient!.city}/${document.recipient!.state ?? ''}'}',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
                pw.Divider(),
                if (options.establishmentCopy ||
                    options.printSummary ||
                    options.offlineDoublePrint)
                  pw.Text(
                    _optionText(options),
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                pw.Text(
                  'NFC-e ${document.number}  Série ${document.series}',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 9),
                ),
                if (document.operationNature != null)
                  pw.Text(
                    'Natureza: ${document.operationNature}',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                if (document.authorization != null)
                  pw.Text(
                    'Protocolo: ${document.authorization!.protocol} - ${_formatDateTime(document.authorization!.authorizedAt)}',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                if (options.epecProtocol != null)
                  pw.Text(
                    'EPEC: ${options.epecProtocol} - ${_formatDateTime(options.epecDate ?? document.issueDate)}',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                pw.Text(
                  'Chave: ${document.accessKey}',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 7),
                ),
                pw.SizedBox(height: 3),
                pw.Center(
                  child: pw.BarcodeWidget(
                    data: document.accessKey,
                    barcode: pw.Barcode.code128(),
                    width: 66 * PdfPageFormat.mm,
                    height: 18 * PdfPageFormat.mm,
                    drawText: false,
                  ),
                ),
                pw.SizedBox(height: 5),
                for (final item in document.items)
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.SizedBox(
                          width: 18,
                          child: pw.Text(
                            '${item.number}',
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            '${_itemDescription(item, showTaxableUnit: options.showTaxableUnit, showPurchaseOrderItem: options.showPurchaseOrderItem, showItemTaxDetails: options.showItemTaxDetails, showItemTraceability: options.showItemTraceability, taxableQuantityDecimals: options.quantityDecimals, taxableUnitPriceDecimals: options.unitPriceDecimals)}\n${FiscalDecimal.fromNum(item.quantity).toFixed(options.quantityDecimals)} ${item.unit} x ${FiscalDecimal.fromNum(item.unitPrice).toFixed(options.unitPriceDecimals)}',
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        ),
                        pw.Text(
                          item.merchandiseTotalFormatted,
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      ],
                    ),
                  ),
                pw.Divider(),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    'TOTAL: ${document.totalFormatted}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Text(
                  'Pagamentos: ${document.paymentTotalFormatted}',
                  textAlign: pw.TextAlign.right,
                  style: const pw.TextStyle(fontSize: 8),
                ),
                for (final payment in document.payments)
                  pw.Text(
                    ' ${payment.type}${payment.description == null ? '' : ' - ${payment.description}'}: ${FiscalDecimal.fromNum(payment.value).toFixed(2)}',
                    textAlign: pw.TextAlign.right,
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                if (document.changeValue != null)
                  pw.Text(
                    'Troco: ${FiscalDecimal.fromNum(document.changeValue!).toFixed(2)}',
                    textAlign: pw.TextAlign.right,
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                if (document.contingency != null)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 4),
                    child: pw.Text(
                      'CONTINGÊNCIA: ${document.contingency!.reason}',
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ),
                if (supplement != null) ...[
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Consulte pela chave ou QR Code',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                  pw.Center(
                    child: pw.BarcodeWidget(
                      data: supplement.qrCode,
                      barcode: pw.Barcode.qrCode(),
                      width: 48 * PdfPageFormat.mm,
                      height: 48 * PdfPageFormat.mm,
                      drawText: false,
                    ),
                  ),
                  pw.Text(
                    supplement.keyUrl,
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 7),
                  ),
                ],
                if (options.extraContent != null) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    options.extraContent!,
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Estima o comprimento necessário para uma bobina NFC-e de 80 mm.
  ///
  /// O `sped-da` calcula o comprimento a partir dos itens e dos blocos
  /// opcionais. O cálculo aqui é deliberadamente conservador: considera a
  /// quebra aproximada da descrição e reserva espaço para QR Code,
  /// contingência e cabeçalho, evitando que uma venda extensa seja cortada
  /// pela altura fixa de uma página PDF.
  double _thermalHeight(NfeDocument document, DanfePdfOptions options) {
    var millimeters = 105.0;
    for (final item in document.items) {
      final lineCount = ((item.description.length + item.code.length) / 34)
          .ceil()
          .clamp(1, 8);
      millimeters += 9 + (lineCount * 3.2);
    }
    if (document.recipient != null) millimeters += 10;
    if (options.logoBytes != null) millimeters += 18;
    if (document.contingency != null) millimeters += 10;
    if (document.nfceSupplement != null) millimeters += 60;
    if (options.extraContent != null) millimeters += 12;
    if (options.canceled ||
        options.establishmentCopy ||
        options.printSummary ||
        options.offlineDoublePrint) {
      millimeters += 8;
    }
    return millimeters < 240 ? 240 : millimeters;
  }
}
