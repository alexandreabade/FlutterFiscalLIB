import 'package:xml/xml.dart';

import '../exceptions/fiscal_exception.dart';
import '../models/access_key.dart';
import '../models/contingency.dart';

/// Ajusta um XML NF-e/NFC-e já montado para uma modalidade de contingência.
///
/// O resultado fica sem assinatura digital de propósito: alterar `tpEmis`,
/// a chave ou os dados de contingência invalida a assinatura anterior. O XML
/// retornado deve ser assinado novamente antes da transmissão/impressão.
class ContingencyXmlAdjuster {
  /// Ajusta [xml] usando os dados de [contingency].
  ///
  /// [Contingency.activatedAt] deve representar o instante no fuso que será
  /// escrito em `dhCont`, assim como no XML de origem.
  static String adjust({
    required String xml,
    required Contingency contingency,
  }) {
    final document = _parse(xml);
    _removeSignatures(document.rootElement);

    final ide = _descendant(document.rootElement, 'ide');
    final infNfe = _descendant(document.rootElement, 'infNFe');
    final emit = _descendant(document.rootElement, 'emit');
    final cUf = _required(ide, 'cUF');
    final cNf = _required(ide, 'cNF');
    final number = int.parse(_required(ide, 'nNF'));
    final series = int.parse(_required(ide, 'serie'));
    final model = int.parse(_required(ide, 'mod'));
    final taxId =
        _find(emit, 'CNPJ')?.innerText.trim() ??
        _find(emit, 'CPF')?.innerText.trim() ??
        '';
    if (!RegExp(r'^(?:\d{11}|\d{14})$').hasMatch(taxId)) {
      throw const FiscalValidationException(
        'O emitente deve possuir CNPJ ou CPF válido para recalcular a chave.',
        code: 'INVALID_CONTINGENCY_ISSUER',
      );
    }

    final issueDate = DateTime.tryParse(_required(ide, 'dhEmi'));
    if (issueDate == null) {
      throw const FiscalValidationException(
        'dhEmi não contém uma data ISO-8601 válida.',
        code: 'INVALID_CONTINGENCY_DATE',
      );
    }
    final mode = contingency.mode.code;
    if (model == 55 && mode == ContingencyMode.offlineNfce.code) {
      throw const FiscalValidationException(
        'A contingência offline tpEmis=9 é exclusiva da NFC-e modelo 65.',
        code: 'OFFLINE_CONTINGENCY_MODEL_MISMATCH',
      );
    }
    if (model == 65 && mode != ContingencyMode.offlineNfce.code) {
      throw const FiscalValidationException(
        'A NFC-e modelo 65 aceita somente contingência offline tpEmis=9.',
        code: 'NFCE_CONTINGENCY_MODE_MISMATCH',
      );
    }
    final key = AccessKey.fromComponents(
      cUf: cUf,
      issueDate: issueDate,
      cnpj: taxId,
      model: model,
      series: series,
      number: number,
      tpEmis: mode,
      cNf: cNf,
    );

    _set(ide, 'tpEmis', '$mode');
    _upsert(ide, 'dhCont', _iso(contingency.activatedAt));
    _upsert(ide, 'xJust', contingency.reason.trim());
    _set(ide, 'cDV', key.value.substring(43));
    infNfe.setAttribute('Id', 'NFe${key.value}');

    return document.toXmlString(pretty: false);
  }

  static XmlDocument _parse(String xml) {
    try {
      return XmlDocument.parse(xml);
    } on XmlException catch (error) {
      throw FiscalValidationException(
        'XML fiscal inválido para ajuste de contingência.',
        code: 'INVALID_CONTINGENCY_XML',
        cause: error,
      );
    }
  }

  static XmlElement _descendant(XmlElement root, String name) {
    final found = _find(root, name);
    if (found != null) return found;
    throw FiscalValidationException(
      'Elemento fiscal obrigatório ausente: $name.',
      code: 'INVALID_CONTINGENCY_XML',
    );
  }

  static XmlElement? _find(XmlElement root, String name) {
    for (final node in root.descendants) {
      if (node is XmlElement && node.localName == name) return node;
    }
    return null;
  }

  static String _required(XmlElement parent, String name) {
    final element = _descendant(parent, name);
    final value = element.innerText.trim();
    if (value.isEmpty) {
      throw FiscalValidationException(
        'Elemento fiscal obrigatório vazio: $name.',
        code: 'INVALID_CONTINGENCY_XML',
      );
    }
    return value;
  }

  static void _set(XmlElement parent, String name, String value) {
    final element = _descendant(parent, name);
    element.children
      ..clear()
      ..add(XmlText(value));
  }

  static void _upsert(XmlElement parent, String name, String value) {
    for (final node in parent.children) {
      if (node is XmlElement && node.localName == name) {
        node.children
          ..clear()
          ..add(XmlText(value));
        return;
      }
    }
    parent.children.add(
      XmlElement(XmlName.parts(name), const [], [XmlText(value)]),
    );
  }

  static void _removeSignatures(XmlElement parent) {
    final signatures = parent.children
        .whereType<XmlElement>()
        .where((element) => element.localName == 'Signature')
        .toList();
    parent.children.removeWhere((node) => signatures.contains(node));
    for (final child in parent.children.whereType<XmlElement>().toList()) {
      _removeSignatures(child);
    }
  }

  static String _iso(DateTime value) {
    final offset = value.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final base =
        '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}T'
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}:'
        '${value.second.toString().padLeft(2, '0')}';
    return '$base$sign$hours:$minutes';
  }
}
