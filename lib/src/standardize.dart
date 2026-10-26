import 'dart:convert';

import 'package:xml/xml.dart';

import 'exceptions/fiscal_exception.dart';

/// Identifica e normaliza documentos XML fiscais, inspirado no NFePHP.
class Standardize {
  /// Cria o normalizador com XML opcional.
  Standardize([String? xml]) : _xml = xml;

  String? _xml;
  String? _node;
  String _key = '';

  /// Nome da raiz identificada na última conversão, equivalente à propriedade
  /// pública `Standardize::$key`.
  String get key => _key;

  /// Raízes conhecidas pelo domínio NF-e/NFC-e.
  static const rootTagList = <String>{
    'distDFeInt',
    'resNFe',
    'resEvento',
    'envEvento',
    'ConsCad',
    'consSitNFe',
    'consReciNFe',
    'downloadNFe',
    'enviNFe',
    'inutNFe',
    'admCscNFCe',
    'consStatServ',
    'retDistDFeInt',
    'retEnvEvento',
    'retConsCad',
    'retConsSitNFe',
    'retConsReciNFe',
    'retDownloadNFe',
    'retEnviNFe',
    'retInutNFe',
    'retAdmCscNFCe',
    'retConsStatServ',
    'procInutNFe',
    'procEventoNFe',
    'procNFe',
    'nfeProc',
    'NFe',
  };

  /// Identifica a raiz fiscal e retorna seu nome local.
  String whichIs([String? xml]) {
    final document = _parse(xml);
    final root = document.rootElement;
    if (!rootTagList.contains(root.localName)) {
      throw const FiscalValidationException(
        'Documento XML não pertence ao domínio NF-e/NFC-e.',
        code: 'WRONG_FISCAL_DOCUMENT',
      );
    }
    _node = root.toXmlString(pretty: false);
    _key = root.localName;
    return root.localName;
  }

  /// Retorna o nó XML identificado como `XmlElement`, equivalente tipado a
  /// `Standardize::simpleXml()`.
  XmlElement simpleXml([String? xml]) {
    whichIs(xml);
    return XmlDocument.parse(_node!).rootElement;
  }

  /// Retorna o documento identificado como mapa Dart.
  Map<String, dynamic> toStd([String? xml]) {
    whichIs(xml);
    return _elementToMap(XmlDocument.parse(_node!).rootElement);
  }

  /// Retorna o documento identificado como JSON.
  String toJson([String? xml]) => jsonEncode(toStd(xml));

  /// Retorna o documento identificado como mapa, equivalente a `toArray`.
  Map<String, dynamic> toArray([String? xml]) => toStd(xml);

  /// XML do nó-raiz identificado.
  @override
  String toString() => _node ?? '';

  XmlDocument _parse(String? xml) {
    final source = xml ?? _xml;
    if (source == null || source.trim().isEmpty) {
      throw const FiscalValidationException(
        'O XML está vazio.',
        code: 'EMPTY_XML',
      );
    }
    try {
      _xml = source;
      return XmlDocument.parse(source);
    } on XmlException catch (error) {
      throw FiscalValidationException(
        'Documento XML inválido.',
        code: 'INVALID_XML',
        cause: error,
      );
    }
  }

  Map<String, dynamic> _elementToMap(XmlElement element) {
    final result = <String, dynamic>{};
    for (final attribute in element.attributes) {
      result['attributes'] ??= <String, dynamic>{};
      (result['attributes'] as Map<String, dynamic>)[attribute.name.local] =
          attribute.value;
    }
    final children = element.childElements.toList();
    if (children.isEmpty) {
      return {element.localName: element.innerText};
    }
    for (final child in children) {
      final value = _elementToMap(child);
      final name = child.localName;
      final childValue = value[name];
      if (result.containsKey(name)) {
        final current = result[name];
        if (current is List) {
          current.add(childValue);
        } else {
          result[name] = [current, childValue];
        }
      } else {
        result[name] = childValue;
      }
    }
    return {element.localName: result};
  }
}
