import '../common/fiscal_decimal.dart';
import '../exceptions/fiscal_exception.dart';
import '../models/contingency.dart';
import '../models/nfe_document.dart';
import '../models/nfe_item.dart';
import '../models/nfe_complements.dart';
import '../models/additional_info.dart';
import '../models/nfce_supplement.dart';
import '../models/payment.dart';
import '../models/party.dart';
import '../models/product_details.dart';
import '../models/taxes.dart';
import '../models/trade.dart';
import '../models/transport.dart';
import '../xml/nfe_xml_builder.dart';
import 'nfe_txt_validator.dart';

/// Conversor seguro do subconjunto TXT 4.00 mapeado para os modelos Dart.
///
/// Os registros suportados cobrem cabeçalho, participantes, endereço, produto
/// e os blocos tributários normais de ICMS, PIS e COFINS. Outros registros são
/// rejeitados com erro explícito, pois ignorá-los poderia alterar o significado
/// fiscal do XML.
class NfeTxtConverter {
  /// Cria o conversor usando o layout TXT informado.
  NfeTxtConverter({NfeTxtLayout? layout})
    : layout = layout ?? NfeTxtLayout.local400(),
      _validator = NfeTxtValidator(layout: layout ?? NfeTxtLayout.local400());

  /// Estrutura usada para validar o TXT antes da conversão.
  final NfeTxtLayout layout;
  final NfeTxtValidator _validator;

  /// Converte todas as NF-e declaradas no TXT em XMLs independentes.
  List<String> parse(String txt) => toXml(txt);

  /// Alias compatível com o método `Convert.toXml()` do NFePHP.
  List<String> toXml(String txt) {
    _validator.assertValid(txt);
    final rows = txt
        .replaceAll('\r', '')
        .replaceAll('\t', '')
        .trim()
        .split('\n');
    final declared = _declaredQuantity(rows);
    final documents = <List<String>>[];
    var current = <String>[];
    for (final row in rows) {
      final reference = _reference(row);
      if (reference == 'NOTAFISCAL') continue;
      if (reference == 'A' && current.isNotEmpty) {
        documents.add(current);
        current = <String>[];
      }
      current.add(row);
    }
    if (current.isNotEmpty) documents.add(current);
    if (declared != documents.length) {
      throw FiscalValidationException(
        'O TXT declara $declared NF-e, mas contém ${documents.length}.',
        code: 'INVALID_NFE_TXT_QUANTITY',
      );
    }
    return documents.map(_documentToXml).toList(growable: false);
  }

  NfeDocument _parseDocument(List<String> rows) {
    final grouped = <String, List<List<String>>>{};
    for (final row in rows) {
      final fields = _normalizeFields(row.split('|'));
      final reference = _canonicalReference(fields.first);
      grouped.putIfAbsent(reference, () => []).add(fields);
    }
    if (layout.baseLayout == 'SEBRAE' && grouped['UA'] != null) {
      final value = _value(grouped['UA03']?.first ?? const ['UA03'], 1);
      if (value != null) {
        final fields = grouped['UA']!.first;
        grouped['UA'] = [
          [...fields, value],
          ...grouped['UA']!.skip(1),
        ];
      }
    }
    final unsupported = grouped.keys.where((key) => !_supported.contains(key));
    if (unsupported.isNotEmpty) {
      throw FiscalValidationException(
        'Registros TXT ainda não mapeados: ${unsupported.join(', ')}.',
        code: 'UNSUPPORTED_NFE_TXT_RECORD',
      );
    }
    final header = _one(grouped, 'B');
    final issuerFields = _one(grouped, 'C');
    final issuerCnpj = _groupValue(grouped, 'C02', 1);
    final issuerCpf = _groupValue(grouped, 'C02A', 1);
    if (issuerCnpj != null && issuerCpf != null) {
      throw const FiscalValidationException(
        'O emitente TXT não pode informar CNPJ e CPF simultaneamente.',
        code: 'NFE_TXT_ISSUER_ID_AMBIGUOUS',
      );
    }
    final issuerTaxId = issuerCnpj ?? issuerCpf;
    if (issuerTaxId == null || issuerTaxId.isEmpty) {
      throw const FiscalValidationException(
        'O conversor TXT exige CNPJ ou CPF do emitente para calcular a chave.',
        code: 'NFE_TXT_ISSUER_ID_REQUIRED',
      );
    }
    final issueDate = _dateTime(_value(header, 7));
    final hasIntermediaryField = header.length >= 25;
    final model = _int(_value(header, 4), 'mod');
    final series = _int(_value(header, 5), 'serie');
    final number = _int(_value(header, 6), 'nNF');
    final tpEmis = _int(_value(header, 13), 'tpEmis');
    final cNf = _required(header, 2, 'cNF');
    final contingency = _contingency(
      tpEmis: tpEmis,
      activatedAt:
          _dateTimeOrNull(_value(header, hasIntermediaryField ? 22 : 21)) ??
          issueDate,
      reason: _value(header, hasIntermediaryField ? 23 : 22),
    );
    final issuerAddress = _address(grouped, 'C05');
    final issuer = Party(
      name: _required(issuerFields, 1, 'xNome'),
      cnpj: issuerCnpj,
      cpf: issuerCpf,
      fantasyName: _value(issuerFields, 2),
      ie: _value(issuerFields, 3),
      ieSubstitute: _value(issuerFields, 4),
      municipalRegistration: _value(issuerFields, 5),
      cnae: _value(issuerFields, 6),
      crt: _value(issuerFields, 7),
      address: issuerAddress?.street,
      addressNumber: issuerAddress?.number,
      addressComplement: issuerAddress?.complement,
      neighborhood: issuerAddress?.neighborhood,
      cityCode: issuerAddress?.cityCode,
      city: issuerAddress?.city,
      state: issuerAddress?.state,
      zipCode: issuerAddress?.zipCode,
      phone: issuerAddress?.phone,
    );
    final recipient = _recipient(grouped);
    final items = _items(grouped, issueDate, rows);
    if (items.isEmpty) {
      throw const FiscalValidationException(
        'O TXT deve conter ao menos um registro I de produto.',
        code: 'NFE_TXT_ITEMS_REQUIRED',
      );
    }
    final document = NfeDocument.fromComponents(
      cUf: _required(header, 1, 'cUF'),
      cnpj: issuerTaxId,
      cNf: cNf,
      number: number,
      series: series,
      issueDate: issueDate,
      departureDate: _dateTimeOrNull(_value(header, 8)),
      environment: _int(_value(header, 16), 'tpAmb'),
      model: model,
      issuer: issuer,
      recipient: recipient,
      avulsa: _avulsa(grouped),
      withdrawal: _location(grouped, 'F'),
      delivery: _location(grouped, 'G'),
      items: items,
      references: _references(grouped),
      technicalResponsible: _technicalResponsible(grouped),
      nfceSupplement: _nfceSupplement(grouped),
      taxRetention: _taxRetention(grouped),
      serviceTotal: _serviceTotal(grouped),
      exportInfo: _exportInfo(grouped),
      purchaseInfo: _purchaseInfo(grouped),
      sugarcane: _sugarcane(grouped),
      payments: _payments(grouped),
      changeValue: _changeValue(grouped),
      billing: _billing(grouped),
      additionalInfo: _additionalInfo(grouped),
      transport: _transport(grouped),
      contingency: contingency,
      operationNature: _value(header, 3),
      documentType: _intOrNull(_value(header, 9)),
      destinationType: _intOrNull(_value(header, 10)),
      municipalityCode: _value(header, 11),
      printFormat: _intOrNull(_value(header, 12)),
      purpose: _intOrNull(_value(header, 16)),
      finalConsumer: _intOrNull(_value(header, 17)),
      presenceIndicator: _intOrNull(_value(header, 18)),
      intermediaryIndicator: hasIntermediaryField
          ? _intOrNull(_value(header, 19))
          : null,
      intermediary: _intermediary(grouped),
      processCode: _value(header, hasIntermediaryField ? 20 : 19),
      applicationVersion: _value(header, hasIntermediaryField ? 21 : 20),
    );
    _validateDeclaredTotal(grouped, document);
    return document;
  }

  String _documentToXml(List<String> rows) {
    final document = _parseDocument(rows);
    final expectedDv = _value(
      rows
          .map((row) => row.split('|'))
          .firstWhere((fields) => fields.first.toUpperCase() == 'B'),
      14,
    );
    if (expectedDv != null &&
        expectedDv.isNotEmpty &&
        expectedDv != document.accessKey.substring(43)) {
      throw const FiscalValidationException(
        'O dígito verificador do TXT não corresponde à chave calculada.',
        code: 'NFE_TXT_CHECK_DIGIT_MISMATCH',
      );
    }
    return NfeXmlBuilder().build(document);
  }

  List<Payment> _payments(Map<String, List<List<String>>> grouped) => [
    if (layout.baseLayout == 'SEBRAE')
      for (
        var index = 0;
        index < (grouped['YA01'] ?? const <List<String>>[]).length;
        index++
      )
        Payment(
          indicator: _intOrNull(_value(grouped['YA01']![index], 1)) ?? 0,
          type: _required(grouped['YA01']![index], 2, 'tPag'),
          value: _doubleOrZero(_value(grouped['YA01']![index], 3)),
          brand: _value(
            grouped['YA04']?.elementAtOrNull(index) ?? const ['YA04'],
            3,
          ),
          authorization: _value(
            grouped['YA04']?.elementAtOrNull(index) ?? const ['YA04'],
            4,
          ),
          integration: _intOrNull(
            _value(
              grouped['YA04']?.elementAtOrNull(index) ?? const ['YA04'],
              1,
            ),
          ),
        )
    else
      for (final fields in grouped['YA'] ?? const <List<String>>[])
        Payment(
          indicator: _intOrNull(_value(fields, 1)) ?? 0,
          type: _required(fields, 2, 'tPag'),
          value: _doubleOrZero(_value(fields, 3)),
          brand: _value(fields, 5),
          authorization: _value(fields, 6),
          integration: _intOrNull(_value(fields, 7)),
          description: _value(fields, 8),
        ),
  ];

  IntermediaryInfo? _intermediary(Map<String, List<List<String>>> grouped) {
    final fields = grouped['YB']?.first;
    if (fields == null) return null;
    return IntermediaryInfo(
      cnpj: _required(fields, 1, 'CNPJ'),
      identifier: _required(fields, 2, 'idCadIntTran'),
    );
  }

  double? _changeValue(Map<String, List<List<String>>> grouped) {
    final fields = layout.baseLayout == 'SEBRAE'
        ? grouped['YA']?.first
        : grouped['Y']?.first;
    return fields == null ? null : _doubleOrZero(_value(fields, 1));
  }

  TaxRetention? _taxRetention(Map<String, List<List<String>>> grouped) {
    final fields = grouped['W23']?.first;
    if (fields == null) return null;
    return TaxRetention(
      pis: _doubleOrZero(_value(fields, 1)),
      cofins: _doubleOrZero(_value(fields, 2)),
      csll: _doubleOrZero(_value(fields, 3)),
      irrfBase: _doubleOrZero(_value(fields, 4)),
      irrf: _doubleOrZero(_value(fields, 5)),
      socialSecurityBase: _doubleOrZero(_value(fields, 6)),
      socialSecurity: _doubleOrZero(_value(fields, 7)),
    );
  }

  AvulsaInfo? _avulsa(Map<String, List<List<String>>> grouped) {
    final fields = grouped['D']?.first;
    if (fields == null) return null;
    return AvulsaInfo(
      cnpj: _required(fields, 1, 'CNPJ órgão avulso'),
      agency: _required(fields, 2, 'xOrgao'),
      registration: _required(fields, 3, 'matr'),
      agent: _required(fields, 4, 'xAgente'),
      phone: _value(fields, 5),
      state: _required(fields, 6, 'UF órgão avulso'),
      revenueDocumentNumber: _value(fields, 7),
      documentIssueDate: _dateOnlyOrNull(_value(fields, 8)),
      revenueDocumentValue: _doubleOrNull(_value(fields, 9)),
      fiscalOffice: _required(fields, 10, 'repEmi'),
      paymentDate: _dateOnlyOrNull(_value(fields, 11)),
    );
  }

  ServiceTotal? _serviceTotal(Map<String, List<List<String>>> grouped) {
    final fields = grouped['W17']?.first;
    if (fields == null) return null;
    return ServiceTotal(
      serviceValue: _doubleOrZero(_value(fields, 1)),
      taxBase: _doubleOrZero(_value(fields, 2)),
      taxValue: _doubleOrZero(_value(fields, 3)),
      pis: _doubleOrZero(_value(fields, 4)),
      cofins: _doubleOrZero(_value(fields, 5)),
      competenceDate: _dateOnly(_required(fields, 6, 'dCompet')),
      deduction: _doubleOrZero(_value(fields, 7)),
      other: _doubleOrZero(_value(fields, 8)),
      unconditionalDiscount: _doubleOrZero(_value(fields, 9)),
      conditionalDiscount: _doubleOrZero(_value(fields, 10)),
      retained: _doubleOrZero(_value(fields, 11)),
      taxRegime: _intOrNull(_value(fields, 12)),
    );
  }

  TechnicalResponsible? _technicalResponsible(
    Map<String, List<List<String>>> grouped,
  ) {
    final fields = grouped['ZD']?.first;
    if (fields == null) return null;
    return TechnicalResponsible(
      cnpj: _required(fields, 1, 'CNPJ responsável técnico'),
      contact: _required(fields, 2, 'xContato responsável técnico'),
      email: _required(fields, 3, 'email responsável técnico'),
      phone: _required(fields, 4, 'fone responsável técnico'),
      csrt: _value(fields, 5),
      csrtId: _value(fields, 6),
    );
  }

  NfceXmlSupplement? _nfceSupplement(Map<String, List<List<String>>> grouped) {
    final fields = grouped['ZX01']?.first;
    if (fields == null) return null;
    return NfceXmlSupplement(
      qrCode: _required(fields, 1, 'qrcode NFC-e'),
      keyUrl: _required(fields, 2, 'urlChave NFC-e'),
    );
  }

  ExportInfo? _exportInfo(Map<String, List<List<String>>> grouped) {
    final fields = grouped['ZA']?.first;
    if (fields == null) return null;
    return ExportInfo(
      departureState: _required(fields, 1, 'UFSaidaPais'),
      exportLocation: _required(fields, 2, 'xLocExporta'),
      dispatchLocation: _value(fields, 3),
    );
  }

  PurchaseInfo? _purchaseInfo(Map<String, List<List<String>>> grouped) {
    final fields = grouped['ZB']?.first;
    if (fields == null) return null;
    return PurchaseInfo(
      commitmentNote: _value(fields, 1),
      order: _value(fields, 2),
      contract: _value(fields, 3),
    );
  }

  SugarcaneInfo? _sugarcane(Map<String, List<List<String>>> grouped) {
    final fields = grouped['ZC']?.first;
    if (fields == null) return null;
    return SugarcaneInfo(
      harvest: _required(fields, 1, 'safra'),
      reference: _required(fields, 2, 'ref'),
      dailySupplies: [
        for (final row in grouped['ZC04'] ?? const <List<String>>[])
          SugarcaneDailySupply(
            day: _int(_value(row, 1), 'dia'),
            quantity: _doubleOrZero(_value(row, 2)),
          ),
      ],
      monthTotal: _doubleOrZero(_value(fields, 3)),
      previousTotal: _doubleOrZero(_value(fields, 4)),
      generalTotal: _doubleOrZero(_value(fields, 5)),
      supplyValue: _doubleOrZero(_value(fields, 6)),
      totalDeductions: _doubleOrZero(_value(fields, 7)),
      netSupplyValue: _doubleOrZero(_value(fields, 8)),
      deductions: [
        for (final row in grouped['ZC10'] ?? const <List<String>>[])
          SugarcaneDeduction(
            description: _required(row, 1, 'xDed'),
            value: _doubleOrZero(_value(row, 2)),
          ),
      ],
    );
  }

  BillingInfo? _billing(Map<String, List<List<String>>> grouped) {
    final fields = grouped['Y02']?.first;
    if (fields == null) return null;
    final installments = [
      for (final installment in grouped['Y07'] ?? const <List<String>>[])
        InvoiceInstallment(
          number: _required(installment, 1, 'nDup'),
          dueDate: _dateOnly(_required(installment, 2, 'dVenc')),
          value: _doubleOrZero(_value(installment, 3)),
        ),
    ];
    return BillingInfo(
      invoiceNumber: _required(fields, 1, 'nFat'),
      originalValue: _doubleOrZero(_value(fields, 2)),
      discount: _doubleOrZero(_value(fields, 3)),
      installments: installments,
    );
  }

  AdditionalInfo? _additionalInfo(Map<String, List<List<String>>> grouped) {
    final fields = grouped['Z']?.first;
    final contributor = [
      for (final row in grouped['Z04'] ?? const <List<String>>[])
        AdditionalObservation(
          field: _required(row, 1, 'xCampo'),
          text: _required(row, 2, 'xTexto'),
        ),
    ];
    final fiscal = [
      for (final row in grouped['Z07'] ?? const <List<String>>[])
        AdditionalObservation(
          field: _required(row, 1, 'xCampo'),
          text: _required(row, 2, 'xTexto'),
        ),
    ];
    final processes = [
      for (final row in grouped['Z10'] ?? const <List<String>>[])
        ReferencedProcess(
          number: _required(row, 1, 'nProc'),
          indicator: _required(row, 2, 'indProc'),
        ),
    ];
    final authorizedXml = [
      for (final row in grouped['GA02'] ?? const <List<String>>[])
        AuthorizedXmlDownload(cnpj: _required(row, 1, 'CNPJ autorizado')),
      for (final row in grouped['GA03'] ?? const <List<String>>[])
        AuthorizedXmlDownload(cpf: _required(row, 1, 'CPF autorizado')),
    ];
    if (fields == null &&
        contributor.isEmpty &&
        fiscal.isEmpty &&
        processes.isEmpty &&
        authorizedXml.isEmpty) {
      return null;
    }
    return AdditionalInfo(
      taxAuthority: _value(fields ?? const ['Z'], 1),
      complementary: _value(fields ?? const ['Z'], 2),
      contributorObservations: contributor,
      fiscalObservations: fiscal,
      referencedProcesses: processes,
      authorizedXml: authorizedXml,
    );
  }

  TransportInfo _transport(Map<String, List<List<String>>> grouped) {
    final header = grouped['X']?.first;
    if (header == null) return const TransportInfo();
    final carrier = grouped['X04']?.first;
    final carrierCpf = grouped['X05']?.first;
    final carrierDocument =
        _value(carrier ?? const ['X04'], 1) ??
        _value(carrierCpf ?? const ['X05'], 1);
    final vehicle = grouped['X18']?.first;
    final retention = grouped['X11']?.first;
    final trailers = [
      for (final row in grouped['X22'] ?? const <List<String>>[])
        TransportVehicle(
          plate: _required(row, 1, 'placa do reboque'),
          state: _value(row, 2),
          registration: _value(row, 3),
        ),
    ];
    final railcar = _value(grouped['X25A']?.first ?? const ['X25A'], 1);
    final barge = _value(grouped['X25B']?.first ?? const ['X25B'], 1);
    final volumes = [
      for (final row in grouped['X26'] ?? const <List<String>>[])
        TransportVolume(
          quantity: _intOrNull(_value(row, 1)),
          kind: _value(row, 2),
          brand: _value(row, 3),
          number: _value(row, 4),
          seal: [
            for (final seal in grouped['X33'] ?? const <List<String>>[])
              if (_value(seal, 1) != null) _value(seal, 1)!,
          ],
        ),
    ];
    return TransportInfo(
      freightMode: _int(_value(header, 1), 'modFrete'),
      carrier: carrierDocument,
      carrierName: _value(grouped['X03']?.first ?? const ['X03'], 1),
      carrierIe: _value(grouped['X03']?.first ?? const ['X03'], 2),
      carrierAddress: _value(grouped['X03']?.first ?? const ['X03'], 3),
      carrierCity: _value(grouped['X03']?.first ?? const ['X03'], 4),
      vehiclePlate: _value(vehicle ?? const ['X18'], 1),
      vehicleState: _value(vehicle ?? const ['X18'], 2),
      vehicleRegistration: _value(vehicle ?? const ['X18'], 3),
      trailers: trailers,
      railcar: railcar,
      barge: barge,
      retention: retention == null
          ? null
          : TransportTaxRetention(
              serviceValue: _doubleOrZero(_value(retention, 1)),
              taxBase: _doubleOrZero(_value(retention, 2)),
              rate: _doubleOrZero(_value(retention, 3)),
              taxValue: _doubleOrZero(_value(retention, 4)),
              cfop: _required(retention, 5, 'CFOP retenção'),
              municipalityCode: _required(retention, 6, 'cMunFG retenção'),
            ),
      volumes: volumes,
    );
  }

  List<NfeItem> _items(
    Map<String, List<List<String>>> grouped,
    DateTime issueDate,
    List<String> txtRows,
  ) {
    final rows = grouped['I'] ?? const <List<String>>[];
    final infos = grouped['H'] ?? const <List<String>>[];
    return [
      for (var index = 0; index < rows.length; index++)
        _item(
          rows[index],
          index + 1,
          _additionalItemInfo(infos, index + 1),
          grouped,
          issueDate,
          _itemRows(txtRows, index + 1),
        ),
    ];
  }

  NfeItem _item(
    List<String> fields,
    int number,
    String? additionalInformation,
    Map<String, List<List<String>>> grouped,
    DateTime issueDate,
    List<List<String>> itemRows,
  ) {
    final quantity = _decimal(_value(fields, 9), 'qCom');
    final unitPrice = _decimal(_value(fields, 10), 'vUnCom');
    final declaredTotal = _decimal(_value(fields, 11), 'vProd');
    final calculatedTotal = quantity * unitPrice;
    if (calculatedTotal.toFixed(2) != declaredTotal.toFixed(2)) {
      throw const FiscalValidationException(
        'O vProd do TXT não corresponde a qCom x vUnCom.',
        code: 'NFE_TXT_ITEM_TOTAL_MISMATCH',
      );
    }
    final productDetails = _itemRecord(grouped, 'I05C', number);
    return NfeItem(
      number: number,
      code: _required(fields, 1, 'cProd'),
      ean: _ean(_value(fields, 2)),
      nve: _nve(grouped: grouped, item: number),
      traceability: _traceability(grouped: grouped, item: number),
      cest: _value(productDetails ?? const ['I05C'], 1),
      scaleIndicator: _value(productDetails ?? const ['I05C'], 2),
      manufacturerCnpj: _value(productDetails ?? const ['I05C'], 3),
      description: _required(fields, 3, 'xProd'),
      ncm: _required(fields, 4, 'NCM'),
      benefitCode:
          _value(fields, 5) ?? _value(productDetails ?? const ['I05C'], 4),
      extipi: _value(fields, 6),
      cfop: _required(fields, 7, 'CFOP'),
      unit: _required(fields, 8, 'uCom'),
      quantity: quantity.toDouble(),
      unitPrice: unitPrice.toDouble(),
      eanTrib: _ean(_value(fields, 12)),
      tribUnit: _value(fields, 13),
      tribQuantity: _doubleOrNull(_value(fields, 14)),
      tribUnitPrice: _doubleOrNull(_value(fields, 15)),
      freight: _doubleOrZero(_value(fields, 16)),
      insurance: _doubleOrZero(_value(fields, 17)),
      discount: _doubleOrZero(_value(fields, 18)),
      other: _doubleOrZero(_value(fields, 19)),
      includeInTotal: _value(fields, 20) != '0',
      orderNumber: _value(fields, 21),
      orderItem: _intOrNull(_value(fields, 22)),
      additionalInformation: additionalInformation,
      importDeclarations: _importDeclarations(itemRows),
      exportDetails: _exportDetails(itemRows),
      recopiNumber: _value(
        itemRows.firstWhere(
          (row) => row.first == 'LB',
          orElse: () => const ['LB'],
        ),
        1,
      ),
      approximateTaxValue: _doubleOrNull(
        _value(_itemRecord(grouped, 'M', number) ?? const ['M'], 1),
      ),
      newVehicle: _newVehicle(itemRows),
      weapons: _weapons(itemRows),
      medication: _medication(grouped: grouped, item: number),
      fuel: _fuel(grouped: grouped, item: number),
      icms: _icms(grouped: grouped, item: number),
      icmsSt: _icmsSt(grouped: grouped, item: number),
      icmsStRetained: _icmsStRetained(grouped: grouped, item: number),
      icmsSimples: _icmsSimples(grouped: grouped, item: number),
      icmsUfDestination: _icmsUfDestination(grouped: grouped, item: number),
      ipi: _ipi(grouped: grouped, item: number),
      pis: _pis(grouped: grouped, item: number),
      cofins: _cofins(grouped: grouped, item: number),
      importTax: _importTax(grouped: grouped, item: number),
      pisSt: _pisSt(grouped: grouped, item: number),
      cofinsSt: _cofinsSt(grouped: grouped, item: number),
      ipiDevolution: _ipiDevolution(itemRows),
      serviceTax: _serviceTax(
        grouped: grouped,
        item: number,
        competenceDate: issueDate,
      ),
    );
  }

  List<ImportDeclaration> _importDeclarations(List<List<String>> itemRows) {
    final declarations = [
      for (final fields in itemRows.where((row) => row.first == 'I18'))
        ImportDeclaration(
          number: _required(fields, 1, 'nDI'),
          registrationDate: _dateOnly(_required(fields, 2, 'dDI')),
          customsLocation: _required(fields, 3, 'xLocDesemb'),
          customsState: _required(fields, 4, 'UFDesemb'),
          clearanceDate: _dateOnly(_required(fields, 5, 'dDesemb')),
          transportMode: _int(_value(fields, 6), 'tpViaTransp'),
          afrmm: _doubleOrNull(_value(fields, 7)),
          intermediaryType: _int(_value(fields, 8), 'tpIntermedio'),
          importerCnpj: _value(fields, 9),
          thirdPartyState: _value(fields, 10),
          exporterCode: _required(fields, 11, 'cExportador'),
          additions: [
            for (final addition in itemRows.where((row) => row.first == 'I25'))
              ImportAddition(
                number: _int(_value(addition, 1), 'nAdicao'),
                sequence: _int(_value(addition, 2), 'nSeqAdic'),
                manufacturerCode: _required(addition, 3, 'cFabricante'),
                discount: _doubleOrZero(_value(addition, 4)),
                drawbackNumber: _value(addition, 5),
              ),
          ],
        ),
    ];
    return declarations;
  }

  List<ExportDetail> _exportDetails(List<List<String>> itemRows) {
    final drawback = itemRows
        .where((row) => row.first == 'I50')
        .map((row) => _value(row, 1))
        .firstWhere((value) => value != null, orElse: () => null);
    final exports = [
      for (final fields in itemRows.where((row) => row.first == 'I52'))
        IndividualExport(
          registrationNumber: _required(fields, 1, 'nRE'),
          receivedInvoiceKey: _required(fields, 2, 'chNFe'),
          exportedQuantity: _doubleOrZero(_value(fields, 3)),
        ),
    ];
    if (drawback == null && exports.isEmpty) return const [];
    return [ExportDetail(drawbackNumber: drawback, individualExports: exports)];
  }

  NewVehicleInfo? _newVehicle(List<List<String>> itemRows) {
    final fields = itemRows.where((row) => row.first == 'JA').firstOrNull;
    if (fields == null) return null;
    return NewVehicleInfo(
      operationType: _int(_value(fields, 1), 'tpOp'),
      chassis: _required(fields, 2, 'chassi'),
      colorCode: _required(fields, 3, 'cCor'),
      colorDescription: _required(fields, 4, 'xCor'),
      power: _required(fields, 5, 'pot'),
      engineCapacity: _required(fields, 6, 'cilin'),
      netWeight: _required(fields, 7, 'pesoL'),
      grossWeight: _required(fields, 8, 'pesoB'),
      serialNumber: _required(fields, 9, 'nSerie'),
      fuelType: _required(fields, 10, 'tpComb'),
      engineNumber: _required(fields, 11, 'nMotor'),
      maxTractionCapacity: _required(fields, 12, 'CMT'),
      wheelbase: _required(fields, 13, 'dist'),
      modelYear: _int(_value(fields, 14), 'anoMod'),
      manufactureYear: _int(_value(fields, 15), 'anoFab'),
      paintType: _required(fields, 16, 'tpPint'),
      vehicleType: _int(_value(fields, 17), 'tpVeic'),
      vehicleSpecies: _int(_value(fields, 18), 'espVeic'),
      vinStatus: _required(fields, 19, 'VIN'),
      vehicleCondition: _int(_value(fields, 20), 'condVeic'),
      brandModelCode: _int(_value(fields, 21), 'cMod'),
      denatranColorCode: _int(_value(fields, 22), 'cCorDENATRAN'),
      seatingCapacity: _int(_value(fields, 23), 'lota'),
      restrictionType: _int(_value(fields, 24), 'tpRest'),
    );
  }

  List<WeaponInfo> _weapons(List<List<String>> itemRows) => [
    for (final fields in itemRows.where((row) => row.first == 'L'))
      WeaponInfo(
        type: _int(_value(fields, 1), 'tpArma'),
        serialNumber: _required(fields, 2, 'nSerie'),
        barrelNumber: _required(fields, 3, 'nCano'),
        description: _required(fields, 4, 'descr'),
      ),
  ];

  IpiDevolution? _ipiDevolution(List<List<String>> itemRows) {
    final fields = itemRows.where((row) => row.first == 'UA').firstOrNull;
    if (fields == null) return null;
    return IpiDevolution(
      percentage: _doubleOrZero(_value(fields, 1)),
      value: _doubleOrZero(_value(fields, 2)),
    );
  }

  List<List<String>> _itemRows(List<String> rows, int item) {
    var currentItem = 0;
    final result = <List<String>>[];
    for (final row in rows) {
      final fields = row.split('|');
      final reference = fields.first.toUpperCase();
      if (reference == 'I') currentItem++;
      if (currentItem == item) result.add(fields);
    }
    return result;
  }

  List<String> _nve({
    required Map<String, List<List<String>>> grouped,
    required int item,
  }) {
    final fields = _itemRecord(grouped, 'I05A', item);
    return fields == null || _value(fields, 1) == null
        ? const []
        : [_value(fields, 1)!];
  }

  List<ProductTraceability> _traceability({
    required Map<String, List<List<String>>> grouped,
    required int item,
  }) {
    final fields = _itemRecord(grouped, 'I80', item);
    if (fields == null) return const [];
    return [
      ProductTraceability(
        batchNumber: _required(fields, 1, 'nLote'),
        quantity: _doubleOrZero(_value(fields, 2)),
        manufacturedAt: _dateOnly(_required(fields, 3, 'dFab')),
        expiresAt: _dateOnly(_required(fields, 4, 'dVal')),
        aggregatedCode: _value(fields, 5),
      ),
    ];
  }

  MedicationInfo? _medication({
    required Map<String, List<List<String>>> grouped,
    required int item,
  }) {
    final fields = _itemRecord(grouped, 'K', item);
    if (fields == null) return null;
    return MedicationInfo(
      anvisaProductCode: _required(fields, 1, 'cProdANVISA'),
      maximumConsumerPrice: _doubleOrZero(_value(fields, 2)),
      exemptionReason: _value(fields, 3),
    );
  }

  FuelInfo? _fuel({
    required Map<String, List<List<String>>> grouped,
    required int item,
  }) {
    final fields = _itemRecord(grouped, 'LA', item);
    if (fields == null) return null;
    final cide = _itemRecord(grouped, 'LA07', item);
    final gauge = _itemRecord(grouped, 'LA11', item);
    return FuelInfo(
      anpProductCode: _required(fields, 1, 'cProdANP'),
      anpDescription: _required(fields, 2, 'descANP'),
      glpPetroleumPercentage: _doubleOrNull(_value(fields, 3)),
      nationalNaturalGasPercentage: _doubleOrNull(_value(fields, 4)),
      importedNaturalGasPercentage: _doubleOrNull(_value(fields, 5)),
      startingValue: _doubleOrNull(_value(fields, 6)),
      codif: _value(fields, 7),
      temperatureQuantity: _doubleOrNull(_value(fields, 8)),
      consumptionState: _required(fields, 9, 'UFCons'),
      cide: cide == null
          ? null
          : FuelCide(
              quantityBase: _doubleOrZero(_value(cide, 1)),
              rate: _doubleOrZero(_value(cide, 2)),
              value: _doubleOrZero(_value(cide, 3)),
            ),
      gauge: gauge == null
          ? null
          : FuelGauge(
              nozzle: _int(_value(gauge, 1), 'nBico'),
              pump: _intOrNull(_value(gauge, 2)),
              tank: _int(_value(gauge, 3), 'nTanque'),
              initialReading: _doubleOrZero(_value(gauge, 4)),
              finalReading: _doubleOrZero(_value(gauge, 5)),
            ),
    );
  }

  ImportTax? _importTax({
    required Map<String, List<List<String>>> grouped,
    required int item,
  }) {
    final fields = _itemRecord(grouped, 'P', item);
    if (fields == null) return null;
    return ImportTax(
      base: _doubleOrZero(_value(fields, 1)),
      customsExpenses: _doubleOrZero(_value(fields, 2)),
      value: _doubleOrZero(_value(fields, 3)),
      iof: _doubleOrZero(_value(fields, 4)),
    );
  }

  PisStTax? _pisSt({
    required Map<String, List<List<String>>> grouped,
    required int item,
  }) {
    final total = _itemRecord(grouped, 'R', item);
    if (total == null) return null;
    final percent = _itemRecord(grouped, 'R02', item);
    final quantity = _itemRecord(grouped, 'R04', item);
    if (percent == null && quantity == null) {
      throw FiscalValidationException(
        'O PIS-ST do item $item exige base/alíquota ou quantidade.',
        code: 'NFE_TXT_ITEM_TAX_MISMATCH',
      );
    }
    return PisStTax(
      value: _doubleOrZero(_value(total, 1)),
      base: percent == null ? null : _doubleOrZero(_value(percent, 1)),
      rate: percent == null ? null : _doubleOrZero(_value(percent, 2)),
      quantity: quantity == null ? null : _doubleOrZero(_value(quantity, 1)),
      unitRate: quantity == null ? null : _doubleOrZero(_value(quantity, 2)),
    );
  }

  CofinsStTax? _cofinsSt({
    required Map<String, List<List<String>>> grouped,
    required int item,
  }) {
    final total = _itemRecord(grouped, 'T', item);
    if (total == null) return null;
    final percent = _itemRecord(grouped, 'T02', item);
    final quantity = _itemRecord(grouped, 'T04', item);
    if (percent == null && quantity == null) {
      throw FiscalValidationException(
        'A COFINS-ST do item $item exige base/alíquota ou quantidade.',
        code: 'NFE_TXT_ITEM_TAX_MISMATCH',
      );
    }
    return CofinsStTax(
      value: _doubleOrZero(_value(total, 1)),
      base: percent == null ? null : _doubleOrZero(_value(percent, 1)),
      rate: percent == null ? null : _doubleOrZero(_value(percent, 2)),
      quantity: quantity == null ? null : _doubleOrZero(_value(quantity, 1)),
      unitRate: quantity == null ? null : _doubleOrZero(_value(quantity, 2)),
    );
  }

  ServiceTax? _serviceTax({
    required Map<String, List<List<String>>> grouped,
    required int item,
    required DateTime competenceDate,
  }) {
    final fields = _itemRecord(grouped, 'U', item);
    if (fields == null) return null;
    return ServiceTax(
      base: _doubleOrZero(_value(fields, 1)),
      rate: _doubleOrZero(_value(fields, 2)),
      value: _doubleOrZero(_value(fields, 3)),
      municipalityCode: _required(fields, 4, 'cMunFG'),
      serviceListCode: _required(fields, 5, 'cListServ'),
      competenceDate: competenceDate,
      deduction: _doubleOrZero(_value(fields, 6)),
      other: _doubleOrZero(_value(fields, 7)),
      unconditionalDiscount: _doubleOrZero(_value(fields, 8)),
      conditionalDiscount: _doubleOrZero(_value(fields, 9)),
      retained: _doubleOrZero(_value(fields, 10)),
      exigibility: _int(_value(fields, 11), 'indISS'),
      serviceCode: _value(fields, 12),
      incidenceMunicipalityCode: _value(fields, 13),
      incentive: _value(fields, 16) == '1',
    );
  }

  IcmsTax? _icms({
    required Map<String, List<List<String>>> grouped,
    required int item,
  }) {
    final fields =
        _itemRecord(grouped, 'N02', item) ??
        _itemRecord(grouped, 'N04', item) ??
        _itemRecord(grouped, 'N06', item) ??
        _itemRecord(grouped, 'N07', item) ??
        _itemRecord(grouped, 'N08', item);
    if (fields == null) return null;
    final record = fields.first.toUpperCase();
    if (record == 'N06') {
      return IcmsTax(
        origin: _int(_value(fields, 1), 'orig'),
        cst: _required(fields, 2, 'CST'),
        modality: 3,
        base: 0,
        rate: 0,
        value: 0,
        desonerationValue: _doubleOrZero(_value(fields, 3)),
        desonerationReason: _int(_value(fields, 4), 'motDesICMS'),
      );
    }
    if (record == 'N08') {
      return IcmsTax(
        origin: _int(_value(fields, 1), 'orig'),
        cst: _required(fields, 2, 'CST'),
        modality: 3,
        base: 0,
        rate: _doubleOrZero(_value(fields, 4)),
        value: _doubleOrZero(_value(fields, 5)),
        retainedBase: _doubleOrZero(_value(fields, 3)),
        retainedRate: _doubleOrZero(_value(fields, 4)),
        retainedValue: _doubleOrZero(_value(fields, 5)),
      );
    }
    if (record == 'N04') {
      return IcmsTax(
        origin: _int(_value(fields, 1), 'orig'),
        cst: _required(fields, 2, 'CST'),
        modality: _int(_value(fields, 3), 'modBC'),
        reduction: _doubleOrNull(_value(fields, 4)),
        base: _doubleOrZero(_value(fields, 5)),
        rate: _doubleOrZero(_value(fields, 6)),
        value: _doubleOrZero(_value(fields, 7)),
        fcpBase: _doubleOrNull(_value(fields, 8)),
        fcpRate: _doubleOrNull(_value(fields, 9)),
        fcpValue: _doubleOrNull(_value(fields, 10)),
        desonerationValue: _doubleOrNull(_value(fields, 11)),
        desonerationReason: _intOrNull(_value(fields, 12)),
      );
    }
    if (record == 'N07') {
      return IcmsTax(
        origin: _int(_value(fields, 1), 'orig'),
        cst: _required(fields, 2, 'CST'),
        modality: _int(_value(fields, 3), 'modBC'),
        reduction: _doubleOrNull(_value(fields, 4)),
        base: _doubleOrZero(_value(fields, 5)),
        rate: _doubleOrZero(_value(fields, 6)),
        value: _doubleOrZero(_value(fields, 10)),
        operationValue: _doubleOrNull(_value(fields, 7)),
        differenceRate: _doubleOrNull(_value(fields, 8)),
        differenceValue: _doubleOrNull(_value(fields, 9)),
        fcpBase: _doubleOrNull(_value(fields, 11)),
        fcpRate: _doubleOrNull(_value(fields, 12)),
        fcpValue: _doubleOrNull(_value(fields, 13)),
      );
    }
    return IcmsTax(
      origin: _int(_value(fields, 1), 'orig'),
      cst: _required(fields, 2, 'CST'),
      modality: _int(_value(fields, 3), 'modBC'),
      base: _doubleOrZero(_value(fields, 4)),
      rate: _doubleOrZero(_value(fields, 5)),
      value: _doubleOrZero(_value(fields, 6)),
      fcpRate: _doubleOrNull(_value(fields, 7)),
      fcpValue: _doubleOrNull(_value(fields, 8)),
      fcpBase: _value(fields, 7) == null
          ? null
          : _doubleOrZero(_value(fields, 4)),
    );
  }

  IcmsUfDestinationTax? _icmsUfDestination({
    required Map<String, List<List<String>>> grouped,
    required int item,
  }) {
    final fields = _itemRecord(grouped, 'NA', item);
    if (fields == null) return null;
    return IcmsUfDestinationTax(
      base: _doubleOrZero(_value(fields, 1)),
      fcpBase: _doubleOrNull(_value(fields, 2)),
      fcpRate: _doubleOrNull(_value(fields, 3)),
      destinationRate: _doubleOrZero(_value(fields, 4)),
      interstateRate: _doubleOrZero(_value(fields, 5)),
      partitionRate: _doubleOrZero(_value(fields, 6)),
      fcpValue: _doubleOrNull(_value(fields, 7)),
      destinationValue: _doubleOrZero(_value(fields, 8)),
      originValue: _doubleOrZero(_value(fields, 9)),
    );
  }

  IcmsSimplesTax? _icmsSimples({
    required Map<String, List<List<String>>> grouped,
    required int item,
  }) {
    final fields =
        _itemRecord(grouped, 'N10C', item) ??
        _itemRecord(grouped, 'N10D', item) ??
        _itemRecord(grouped, 'N10E', item) ??
        _itemRecord(grouped, 'N10F', item) ??
        _itemRecord(grouped, 'N10G', item) ??
        _itemRecord(grouped, 'N10H', item);
    if (fields == null) return null;
    final record = fields.first.toUpperCase();
    if (record == 'N10G') {
      return IcmsSimplesTax(
        origin: _int(_value(fields, 1), 'orig'),
        csosn: _required(fields, 2, 'CSOSN'),
        retainedBase: _doubleOrZero(_value(fields, 3)),
        retainedRate: _doubleOrZero(_value(fields, 4)),
        retainedValue: _doubleOrZero(_value(fields, 5)),
        retainedFcpBase: _doubleOrZero(_value(fields, 6)),
        retainedFcpRate: _doubleOrZero(_value(fields, 7)),
        retainedFcpValue: _doubleOrZero(_value(fields, 8)),
        effectiveReduction: _doubleOrNull(_value(fields, 9)),
        effectiveBase: _doubleOrZero(_value(fields, 10)),
        effectiveRate: _doubleOrZero(_value(fields, 11)),
        effectiveValue: _doubleOrZero(_value(fields, 12)),
        substitutedValue: _doubleOrNull(_value(fields, 13)),
      );
    }
    final hasSt = record == 'N10E' || record == 'N10F';
    final hasOwn = record == 'N10H';
    return IcmsSimplesTax(
      origin: _int(_value(fields, 1), 'orig'),
      csosn: _required(fields, 2, 'CSOSN'),
      creditRate: record == 'N10C'
          ? _doubleOrNull(_value(fields, 3))
          : record == 'N10E' || record == 'N10H'
          ? _doubleOrNull(_value(fields, hasOwn ? 17 : 12))
          : null,
      creditValue: record == 'N10C'
          ? _doubleOrNull(_value(fields, 4))
          : record == 'N10E' || record == 'N10H'
          ? _doubleOrNull(_value(fields, hasOwn ? 18 : 13))
          : null,
      modality: hasSt
          ? _int(_value(fields, 3), 'modBCST')
          : hasOwn
          ? _int(_value(fields, 8), 'modBCST')
          : 4,
      mva: hasSt
          ? _doubleOrNull(_value(fields, 4))
          : hasOwn
          ? _doubleOrNull(_value(fields, 9))
          : null,
      reduction: hasSt
          ? _doubleOrNull(_value(fields, 5))
          : hasOwn
          ? _doubleOrNull(_value(fields, 10))
          : null,
      base: hasOwn ? _doubleOrNull(_value(fields, 4)) : null,
      rate: hasOwn ? _doubleOrNull(_value(fields, 6)) : null,
      value: hasOwn ? _doubleOrNull(_value(fields, 7)) : null,
      stBase: hasSt
          ? _doubleOrNull(_value(fields, 6))
          : hasOwn
          ? _doubleOrNull(_value(fields, 11))
          : null,
      stRate: hasSt
          ? _doubleOrNull(_value(fields, 7))
          : hasOwn
          ? _doubleOrNull(_value(fields, 12))
          : null,
      stValue: hasSt
          ? _doubleOrNull(_value(fields, 8))
          : hasOwn
          ? _doubleOrNull(_value(fields, 13))
          : null,
      fcpStBase: hasSt
          ? _doubleOrNull(_value(fields, 9))
          : hasOwn
          ? _doubleOrNull(_value(fields, 14))
          : null,
      fcpStRate: hasSt
          ? _doubleOrNull(_value(fields, 10))
          : hasOwn
          ? _doubleOrNull(_value(fields, 15))
          : null,
      fcpStValue: hasSt
          ? _doubleOrNull(_value(fields, 11))
          : hasOwn
          ? _doubleOrNull(_value(fields, 16))
          : null,
    );
  }

  IcmsStTax? _icmsSt({
    required Map<String, List<List<String>>> grouped,
    required int item,
  }) {
    final fields =
        _itemRecord(grouped, 'N03', item) ??
        _itemRecord(grouped, 'N05', item) ??
        _itemRecord(grouped, 'N09', item) ??
        _itemRecord(grouped, 'N10A', item) ??
        _itemRecord(grouped, 'N10', item);
    if (fields == null) return null;
    final record = fields.first.toUpperCase();
    if (record == 'N05') {
      return IcmsStTax(
        cst: _required(fields, 2, 'CST'),
        origin: _int(_value(fields, 1), 'orig'),
        base: 0,
        rate: 0,
        value: 0,
        modality: _int(_value(fields, 3), 'modBCST'),
        mva: _doubleOrNull(_value(fields, 4)),
        reduction: _doubleOrNull(_value(fields, 5)),
        stBase: _doubleOrZero(_value(fields, 6)),
        stRate: _doubleOrZero(_value(fields, 7)),
        stValue: _doubleOrZero(_value(fields, 8)),
        fcpStBase: _doubleOrNull(_value(fields, 9)),
        fcpStRate: _doubleOrNull(_value(fields, 10)),
        fcpStValue: _doubleOrNull(_value(fields, 11)),
        stOnly: true,
        desonerationValue: _doubleOrNull(_value(fields, 12)),
        desonerationReason: _intOrNull(_value(fields, 13)),
      );
    }
    if (record == 'N10A') {
      return IcmsStTax(
        cst: _required(fields, 2, 'CST'),
        origin: _int(_value(fields, 1), 'orig'),
        ownModality: _int(_value(fields, 3), 'modBC'),
        ownReduction: _doubleOrNull(_value(fields, 5)),
        base: _doubleOrZero(_value(fields, 4)),
        rate: _doubleOrZero(_value(fields, 6)),
        value: _doubleOrZero(_value(fields, 7)),
        modality: _int(_value(fields, 8), 'modBCST'),
        mva: _doubleOrNull(_value(fields, 9)),
        reduction: _doubleOrNull(_value(fields, 10)),
        stBase: _doubleOrZero(_value(fields, 11)),
        stRate: _doubleOrZero(_value(fields, 12)),
        stValue: _doubleOrZero(_value(fields, 13)),
        operationRate: _doubleOrNull(_value(fields, 14)),
        destinationState: _value(fields, 15),
      );
    }
    if (record == 'N09' || record == 'N10') {
      final n09 = record == 'N09';
      return IcmsStTax(
        cst: _required(fields, 2, 'CST'),
        origin: _int(_value(fields, 1), 'orig'),
        ownModality: _int(_value(fields, 3), 'modBC'),
        ownReduction: _doubleOrNull(_value(fields, n09 ? 4 : 5)),
        base: _doubleOrZero(_value(fields, n09 ? 5 : 4)),
        rate: _doubleOrZero(_value(fields, n09 ? 6 : 6)),
        value: _doubleOrZero(_value(fields, 7)),
        modality: _int(_value(fields, 11), 'modBCST'),
        mva: _doubleOrNull(_value(fields, 12)),
        reduction: _doubleOrNull(_value(fields, 13)),
        stBase: _doubleOrZero(_value(fields, 14)),
        stRate: _doubleOrZero(_value(fields, 15)),
        stValue: _doubleOrZero(_value(fields, 16)),
        fcpBase: _doubleOrNull(_value(fields, 8)),
        fcpRate: _doubleOrNull(_value(fields, 9)),
        fcpValue: _doubleOrNull(_value(fields, 10)),
        fcpStBase: _doubleOrNull(_value(fields, 17)),
        fcpStRate: _doubleOrNull(_value(fields, 18)),
        fcpStValue: _doubleOrNull(_value(fields, 19)),
      );
    }
    return IcmsStTax(
      cst: _required(fields, 2, 'CST'),
      origin: _int(_value(fields, 1), 'orig'),
      modality: _int(_value(fields, 10), 'modBCST'),
      mva: _doubleOrNull(_value(fields, 11)),
      reduction: _doubleOrNull(_value(fields, 12)),
      base: _doubleOrZero(_value(fields, 4)),
      rate: _doubleOrZero(_value(fields, 5)),
      value: _doubleOrZero(_value(fields, 6)),
      stBase: _doubleOrZero(_value(fields, 13)),
      stRate: _doubleOrZero(_value(fields, 14)),
      stValue: _doubleOrZero(_value(fields, 15)),
      fcpBase: _doubleOrNull(_value(fields, 7)),
      fcpRate: _doubleOrNull(_value(fields, 8)),
      fcpValue: _doubleOrNull(_value(fields, 9)),
      fcpStBase: _doubleOrNull(_value(fields, 16)),
      fcpStRate: _doubleOrNull(_value(fields, 17)),
      fcpStValue: _doubleOrNull(_value(fields, 18)),
    );
  }

  IcmsStRetainedTax? _icmsStRetained({
    required Map<String, List<List<String>>> grouped,
    required int item,
  }) {
    final fields = _itemRecord(grouped, 'N10B', item);
    if (fields == null) return null;
    return IcmsStRetainedTax(
      origin: _int(_value(fields, 1), 'orig'),
      cst: _required(fields, 2, 'CST'),
      retainedBase: _doubleOrZero(_value(fields, 3)),
      retainedValue: _doubleOrZero(_value(fields, 4)),
      destinationBase: _doubleOrZero(_value(fields, 5)),
      destinationValue: _doubleOrZero(_value(fields, 6)),
      retainedFcpBase: _doubleOrNull(_value(fields, 7)),
      retainedFcpRate: _doubleOrNull(_value(fields, 8)),
      retainedFcpValue: _doubleOrNull(_value(fields, 9)),
      retainedRate: _doubleOrNull(_value(fields, 10)),
      substitutedValue: _doubleOrNull(_value(fields, 11)),
      effectiveReduction: _doubleOrNull(_value(fields, 12)),
      effectiveBase: _doubleOrNull(_value(fields, 13)),
      effectiveRate: _doubleOrNull(_value(fields, 14)),
      effectiveValue: _doubleOrNull(_value(fields, 15)),
    );
  }

  IpiTax? _ipi({
    required Map<String, List<List<String>>> grouped,
    required int item,
  }) {
    final header = _itemRecord(grouped, 'O', item);
    if (header == null) return null;
    final taxed = _itemRecord(grouped, 'O07', item);
    final notTaxed = _itemRecord(grouped, 'O08', item);
    if (taxed != null && notTaxed != null) {
      throw FiscalValidationException(
        'O item $item não pode possuir IPI tributado e não tributado.',
        code: 'NFE_TXT_ITEM_TAX_MISMATCH',
      );
    }
    final cEnq = _required(header, 4, 'cEnq');
    if (taxed != null) {
      final base = _itemRecord(grouped, 'O10', item);
      final unit = _itemRecord(grouped, 'O11', item);
      if (base == null && unit == null) {
        throw FiscalValidationException(
          'O IPI tributado do item $item exige O10 ou O11.',
          code: 'NFE_TXT_ITEM_TAX_MISMATCH',
        );
      }
      return IpiTax(
        enquadramento: cEnq,
        cst: _required(taxed, 1, 'CST IPI'),
        base: unit == null ? _doubleOrZero(_value(base!, 1)) : 0,
        rate: unit == null ? _doubleOrZero(_value(base!, 2)) : 0,
        value: _doubleOrZero(_value(taxed, 2)),
        quantity: unit == null ? null : _doubleOrZero(_value(unit, 1)),
        unitRate: unit == null ? null : _doubleOrZero(_value(unit, 2)),
      );
    }
    if (notTaxed != null) {
      return IpiTax(
        enquadramento: cEnq,
        cst: _required(notTaxed, 1, 'CST IPI'),
        base: 0,
        rate: 0,
        value: 0,
      );
    }
    throw FiscalValidationException(
      'O grupo IPI do item $item não possui O07 ou O08.',
      code: 'NFE_TXT_ITEM_TAX_MISMATCH',
    );
  }

  PisTax? _pis({
    required Map<String, List<List<String>>> grouped,
    required int item,
  }) {
    final percent = _itemRecord(grouped, 'Q02', item);
    if (percent != null) {
      return PisTax(
        cst: _required(percent, 1, 'CST PIS'),
        base: _doubleOrZero(_value(percent, 2)),
        rate: _doubleOrZero(_value(percent, 3)),
        value: _doubleOrZero(_value(percent, 4)),
      );
    }
    final quantity = _itemRecord(grouped, 'Q03', item);
    if (quantity != null) {
      return PisTax(
        cst: _required(quantity, 1, 'CST PIS'),
        quantity: _doubleOrZero(_value(quantity, 2)),
        unitRate: _doubleOrZero(_value(quantity, 3)),
        value: _doubleOrZero(_value(quantity, 4)),
      );
    }
    final notTaxed = _itemRecord(grouped, 'Q04', item);
    if (notTaxed != null) {
      return PisTax.nonTaxed(cst: _required(notTaxed, 1, 'CST PIS'));
    }
    final other = _itemRecord(grouped, 'Q05', item);
    if (other != null) {
      final base = _itemRecord(grouped, 'Q07', item);
      final quantity = _itemRecord(grouped, 'Q10', item);
      if (base != null && quantity != null) {
        throw const FiscalValidationException(
          'O PISOutr não pode possuir base/alíquota e quantidade ao mesmo tempo.',
          code: 'NFE_TXT_ITEM_TAX_MISMATCH',
        );
      }
      return PisTax(
        cst: _required(other, 1, 'CST PIS'),
        base: base == null ? null : _doubleOrZero(_value(base, 1)),
        rate: base == null ? null : _doubleOrZero(_value(base, 2)),
        quantity: quantity == null ? null : _doubleOrZero(_value(quantity, 1)),
        unitRate: quantity == null ? null : _doubleOrZero(_value(quantity, 2)),
        value: _doubleOrZero(_value(other, 2)),
      );
    }
    return null;
  }

  CofinsTax? _cofins({
    required Map<String, List<List<String>>> grouped,
    required int item,
  }) {
    final percent = _itemRecord(grouped, 'S02', item);
    if (percent != null) {
      return CofinsTax(
        cst: _required(percent, 1, 'CST COFINS'),
        base: _doubleOrZero(_value(percent, 2)),
        rate: _doubleOrZero(_value(percent, 3)),
        value: _doubleOrZero(_value(percent, 4)),
      );
    }
    final quantity = _itemRecord(grouped, 'S03', item);
    if (quantity != null) {
      return CofinsTax(
        cst: _required(quantity, 1, 'CST COFINS'),
        quantity: _doubleOrZero(_value(quantity, 2)),
        unitRate: _doubleOrZero(_value(quantity, 3)),
        value: _doubleOrZero(_value(quantity, 4)),
      );
    }
    final notTaxed = _itemRecord(grouped, 'S04', item);
    if (notTaxed != null) {
      return CofinsTax.nonTaxed(cst: _required(notTaxed, 1, 'CST COFINS'));
    }
    final other = _itemRecord(grouped, 'S05', item);
    if (other != null) {
      final base = _itemRecord(grouped, 'S07', item);
      final quantity = _itemRecord(grouped, 'S09', item);
      if (base != null && quantity != null) {
        throw const FiscalValidationException(
          'A COFINSOutr não pode possuir base/alíquota e quantidade ao mesmo tempo.',
          code: 'NFE_TXT_ITEM_TAX_MISMATCH',
        );
      }
      return CofinsTax(
        cst: _required(other, 1, 'CST COFINS'),
        base: base == null ? null : _doubleOrZero(_value(base, 1)),
        rate: base == null ? null : _doubleOrZero(_value(base, 2)),
        quantity: quantity == null ? null : _doubleOrZero(_value(quantity, 1)),
        unitRate: quantity == null ? null : _doubleOrZero(_value(quantity, 2)),
        value: _doubleOrZero(_value(other, 2)),
      );
    }
    return null;
  }

  List<String>? _itemRecord(
    Map<String, List<List<String>>> grouped,
    String key,
    int item,
  ) {
    final records = grouped[key];
    if (records == null) return null;
    if (records.length < item) {
      throw FiscalValidationException(
        'Registro $key ausente para o item $item.',
        code: 'NFE_TXT_ITEM_TAX_MISMATCH',
      );
    }
    return records[item - 1];
  }

  void _validateDeclaredTotal(
    Map<String, List<List<String>>> grouped,
    NfeDocument document,
  ) {
    final fields = grouped['W02']?.first;
    if (fields == null) return;
    final declared = _decimal(_value(fields, 19), 'vNF');
    if (declared.toFixed(2) != document.totalDecimal.toFixed(2)) {
      throw const FiscalValidationException(
        'O vNF do TXT não corresponde ao total calculado.',
        code: 'NFE_TXT_TOTAL_MISMATCH',
      );
    }
  }

  Party? _recipient(Map<String, List<List<String>>> grouped) {
    final fields = grouped['E']?.first;
    if (fields == null) return null;
    final cnpj = _groupValue(grouped, 'E02', 1);
    final cpf = _groupValue(grouped, 'E03', 1);
    final foreignId = _groupValue(grouped, 'E03A', 1);
    final address = _address(grouped, 'E05');
    return Party(
      name: _required(fields, 1, 'xNome'),
      cnpj: cnpj,
      cpf: cpf,
      foreignId: foreignId,
      ie: _value(fields, 3),
      suframa: _value(fields, 4),
      municipalRegistration: _value(fields, 5),
      email: _value(fields, 6),
      recipientIeIndicator: _intOrNull(_value(fields, 2)),
      address: address?.street,
      addressNumber: address?.number,
      addressComplement: address?.complement,
      neighborhood: address?.neighborhood,
      cityCode: address?.cityCode,
      city: address?.city,
      state: address?.state,
      zipCode: address?.zipCode,
      phone: address?.phone,
    );
  }

  NfeLocation? _location(
    Map<String, List<List<String>>> grouped,
    String prefix,
  ) {
    final fields = grouped[prefix]?.first;
    if (fields == null) return null;
    final cnpj = _groupValue(grouped, '${prefix}02', 1);
    final cpf = _groupValue(grouped, '${prefix}02A', 1);
    return NfeLocation(
      name: _groupValue(grouped, '${prefix}02B', 1),
      cnpj: cnpj,
      cpf: cpf,
      street: _required(fields, 1, 'xLgr'),
      number: _required(fields, 2, 'nro'),
      complement: _value(fields, 3),
      neighborhood: _required(fields, 4, 'xBairro'),
      municipalityCode: _required(fields, 5, 'cMun'),
      municipality: _required(fields, 6, 'xMun'),
      state: _required(fields, 7, 'UF'),
      zipCode: _value(fields, 8),
      countryCode: _value(fields, 9),
      country: _value(fields, 10),
      phone: _value(fields, 11),
      email: _value(fields, 12),
      ie: _value(fields, 13),
    );
  }

  List<ReferencedDocument> _references(
    Map<String, List<List<String>>> grouped,
  ) => [
    for (final fields in grouped['BA02'] ?? const <List<String>>[])
      ReferencedDocument.nfe(_required(fields, 1, 'refNFe')),
    for (final fields in grouped['BA03'] ?? const <List<String>>[])
      ReferencedDocument.legacy(
        cUf: _required(fields, 1, 'cUF'),
        yearMonth: _required(fields, 2, 'AAMM'),
        cnpj: _required(fields, 3, 'CNPJ'),
        model: _int(_value(fields, 4), 'mod'),
        series: _int(_value(fields, 5), 'serie'),
        number: _int(_value(fields, 6), 'nNF'),
      ),
    for (
      var index = 0;
      index < (grouped['BA10'] ?? const <List<String>>[]).length;
      index++
    )
      _nfpReference(grouped, index),
    for (final fields in grouped['BA19'] ?? const <List<String>>[])
      ReferencedDocument.cte(_required(fields, 1, 'refCTe')),
    for (final fields in grouped['BA20'] ?? const <List<String>>[])
      ReferencedDocument.ecf(
        ecfModel: _required(fields, 1, 'mod'),
        ecfNumber: _int(_value(fields, 2), 'nECF'),
        cooNumber: _int(_value(fields, 3), 'nCOO'),
      ),
  ];

  ReferencedDocument _nfpReference(
    Map<String, List<List<String>>> grouped,
    int index,
  ) {
    final fields = grouped['BA10']![index];
    final cnpj = _value(
      (grouped['BA13'] ?? const <List<String>>[]).elementAtOrNull(index) ??
          const ['BA13'],
      1,
    );
    final cpf = _value(
      (grouped['BA14'] ?? const <List<String>>[]).elementAtOrNull(index) ??
          const ['BA14'],
      1,
    );
    if (cnpj != null && cpf != null) {
      throw const FiscalValidationException(
        'A referência refNFP não pode informar CNPJ e CPF simultaneamente.',
        code: 'NFE_TXT_REFERENCE_ID_AMBIGUOUS',
      );
    }
    return ReferencedDocument.nfp(
      cUf: _required(fields, 1, 'cUF'),
      yearMonth: _required(fields, 2, 'AAMM'),
      cnpj: cnpj,
      cpf: cpf,
      producerIe: _required(fields, 3, 'IE'),
      model: _int(_value(fields, 4), 'mod'),
      series: _int(_value(fields, 5), 'serie'),
      number: _int(_value(fields, 6), 'nNF'),
    );
  }

  _TxtAddress? _address(Map<String, List<List<String>>> grouped, String key) {
    final fields = grouped[key]?.first;
    if (fields == null) return null;
    return _TxtAddress(
      street: _value(fields, 1),
      number: _value(fields, 2),
      complement: _value(fields, 3),
      neighborhood: _value(fields, 4),
      cityCode: _value(fields, 5),
      city: _value(fields, 6),
      state: _value(fields, 7),
      zipCode: _value(fields, 8),
      phone: _value(fields, 12),
    );
  }

  String? _additionalItemInfo(List<List<String>> rows, int item) {
    for (final fields in rows) {
      if (_intOrNull(_value(fields, 1)) == item) return _value(fields, 2);
    }
    return null;
  }

  Contingency? _contingency({
    required int tpEmis,
    required DateTime activatedAt,
    required String? reason,
  }) {
    if (tpEmis == 1) return null;
    final mode = ContingencyMode.values.firstWhere(
      (value) => value.code == tpEmis,
      orElse: () => throw const FiscalValidationException(
        'tpEmis do TXT não é suportado pelo conversor.',
        code: 'UNSUPPORTED_NFE_TXT_EMISSION',
      ),
    );
    return Contingency(
      mode: mode,
      activatedAt: activatedAt,
      reason:
          reason ??
          (throw const FiscalValidationException(
            'A contingência TXT exige xJust.',
            code: 'NFE_TXT_CONTINGENCY_REASON_REQUIRED',
          )),
    );
  }

  int _declaredQuantity(List<String> rows) {
    final row = rows.firstWhere(
      (value) => _reference(value) == 'NOTAFISCAL',
      orElse: () => throw const FiscalValidationException(
        'O TXT deve iniciar com NOTAFISCAL|quantidade|.',
        code: 'INVALID_NFE_TXT_HEADER',
      ),
    );
    return _int(_value(row.split('|'), 1), 'quantidade');
  }

  static const _supported = {
    'A',
    'B',
    'C',
    'C02',
    'C02A',
    'C05',
    'D',
    'E',
    'E02',
    'E03',
    'E03A',
    'E05',
    'BA',
    'BA02',
    'BA03',
    'BA10',
    'BA13',
    'BA14',
    'BA19',
    'BA20',
    'F',
    'F02',
    'F02A',
    'F02B',
    'G',
    'G02',
    'G02A',
    'G02B',
    'GA',
    'GA02',
    'GA03',
    'H',
    'I',
    'I05A',
    'I05C',
    'I18',
    'I25',
    'I50',
    'I52',
    'I80',
    'JA',
    'K',
    'L',
    'LA',
    'LA07',
    'LA11',
    'LB',
    'M',
    'N',
    'W',
    'X',
    'X03',
    'X04',
    'X05',
    'X11',
    'X18',
    'X22',
    'X25A',
    'X25B',
    'X26',
    'X33',
    'Y',
    'Y02',
    'Y07',
    'YA',
    'YB',
    'YA01',
    'YA04',
    'Z',
    'Z04',
    'Z07',
    'Z10',
    'ZA',
    'ZB',
    'ZC',
    'ZC04',
    'ZC10',
    'ZD',
    'ZX01',
    'N02',
    'N03',
    'N04',
    'N05',
    'N06',
    'N07',
    'N08',
    'N09',
    'N10',
    'N10A',
    'N10B',
    'N10C',
    'N10D',
    'N10E',
    'N10F',
    'N10G',
    'N10H',
    'NA',
    'O',
    'O07',
    'O08',
    'O10',
    'O11',
    'Q',
    'Q02',
    'Q03',
    'Q04',
    'Q05',
    'Q07',
    'Q10',
    'S02',
    'S',
    'S03',
    'S04',
    'S05',
    'S07',
    'S09',
    'W02',
    'W17',
    'W23',
    'P',
    'R',
    'R02',
    'R04',
    'T',
    'T02',
    'T04',
    'U',
    'UA',
    'UA03',
  };

  List<String> _normalizeFields(List<String> fields) {
    if (layout.baseLayout != 'SEBRAE') return fields;
    final reference = fields.first.toUpperCase();
    if (reference == 'I') {
      // SEBRAE omits cBenef after NCM; restore the local slot used by the
      // typed Dart model and by the NFePHP LOCAL parser.
      return [...fields.take(5), '', ...fields.skip(5)];
    }
    if (reference == 'I05C') {
      return fields;
    }
    return fields;
  }

  static String _reference(String row) => row.split('|').first.toUpperCase();

  static String _canonicalReference(String reference) {
    final normalized = reference.toUpperCase();
    // O leiaute oficial chama este registro de B19. BA19 foi usado por
    // versões antigas da implementação local e permanece aceito como alias.
    return normalized == 'B19' ? 'BA19' : normalized;
  }

  static List<String> _one(
    Map<String, List<List<String>>> grouped,
    String key,
  ) =>
      grouped[key]?.first ??
      (throw FiscalValidationException(
        'Registro TXT obrigatório ausente: $key.',
        code: 'NFE_TXT_REQUIRED_RECORD',
      ));

  static String? _groupValue(
    Map<String, List<List<String>>> grouped,
    String key,
    int index,
  ) => grouped[key] == null ? null : _value(grouped[key]!.first, index);

  static String? _value(List<String> fields, int index) {
    if (index >= fields.length - 1) return null;
    final value = fields[index].trim();
    return value.isEmpty ? null : value;
  }

  static String _required(List<String> fields, int index, String name) =>
      _value(fields, index) ??
      (throw FiscalValidationException(
        'Campo TXT obrigatório ausente: $name.',
        code: 'NFE_TXT_REQUIRED_FIELD',
      ));

  static int _int(String? value, String name) =>
      int.tryParse(value ?? '') ??
      (throw FiscalValidationException(
        'Campo TXT $name não é inteiro.',
        code: 'NFE_TXT_INVALID_NUMBER',
      ));

  static int? _intOrNull(String? value) =>
      value == null ? null : int.tryParse(value);

  static double? _doubleOrNull(String? value) =>
      value == null ? null : double.tryParse(value);

  static double _doubleOrZero(String? value) =>
      value == null ? 0 : double.parse(value);

  static FiscalDecimal _decimal(String? value, String name) {
    if (value == null) {
      throw FiscalValidationException(
        'Campo TXT decimal ausente: $name.',
        code: 'NFE_TXT_REQUIRED_FIELD',
      );
    }
    try {
      return FiscalDecimal.parse(value);
    } on FiscalException catch (error) {
      throw FiscalValidationException(
        'Campo TXT decimal inválido: $name.',
        code: 'NFE_TXT_INVALID_NUMBER',
        cause: error,
      );
    }
  }

  static DateTime _dateTime(String? value) {
    try {
      return DateTime.parse(value ?? '').toUtc();
    } on FormatException catch (error) {
      throw FiscalValidationException(
        'Data/hora TXT inválida: $value.',
        code: 'NFE_TXT_INVALID_DATE',
        cause: error,
      );
    }
  }

  static DateTime _dateOnly(String value) => _dateTime('${value}T00:00:00Z');

  static DateTime? _dateOnlyOrNull(String? value) =>
      value == null ? null : _dateOnly(value);

  static DateTime? _dateTimeOrNull(String? value) =>
      value == null ? null : _dateTime(value);

  static String? _ean(String? value) =>
      value == null || value == 'SEM GTIN' ? null : value;
}

class _TxtAddress {
  const _TxtAddress({
    required this.street,
    required this.number,
    required this.complement,
    required this.neighborhood,
    required this.cityCode,
    required this.city,
    required this.state,
    required this.zipCode,
    required this.phone,
  });

  final String? street;
  final String? number;
  final String? complement;
  final String? neighborhood;
  final String? cityCode;
  final String? city;
  final String? state;
  final String? zipCode;
  final String? phone;
}
