import 'package:xml/xml.dart';

/// Canonicalização XML inclusiva (C14N 1.0) para os nós usados em XMLDSig.
///
/// Normaliza namespaces visíveis, ordena declarações e atributos e aplica as
/// regras de escape de C14N. Comentários são omitidos.
class XmlCanonicalizer {
  XmlCanonicalizer._();

  /// Retorna a forma canônica inclusiva de [element].
  static String canonicalize(
    XmlElement element, {
    Map<String, String> inheritedNamespaces = const {},
  }) => _write(element, Map<String, String>.from(inheritedNamespaces), true);

  static String _write(
    XmlElement element,
    Map<String, String> parentNamespaces,
    bool isRoot,
  ) {
    final namespaces = Map<String, String>.from(parentNamespaces);
    final declarations = <String, String>{};
    if (isRoot) {
      // Inclusive C14N serializes every namespace node that is in scope at
      // the root of a canonicalized subtree, not only namespaces used by the
      // root element. The `xml` prefix is implicitly bound and is never
      // emitted as an explicit declaration.
      for (final entry in parentNamespaces.entries) {
        if (entry.key != 'xml') {
          declarations[entry.key] = entry.value;
        }
      }
    }
    final regularAttributes = <XmlAttribute>[];
    for (final attribute in element.attributes) {
      final prefix = attribute.name.prefix;
      final isNamespace = attribute.name.local == 'xmlns' || prefix == 'xmlns';
      if (isNamespace) {
        final namespacePrefix = prefix == 'xmlns' ? attribute.name.local : '';
        if (namespaces[namespacePrefix] != attribute.value) {
          declarations[namespacePrefix] = attribute.value;
          namespaces[namespacePrefix] = attribute.value;
        }
      } else {
        regularAttributes.add(attribute);
      }
    }
    final elementPrefix = element.name.prefix ?? '';
    final elementNamespace =
        element.name.namespaceUri ?? namespaces[elementPrefix];
    if (elementNamespace != null &&
        (isRoot || namespaces[elementPrefix] != elementNamespace)) {
      declarations[elementPrefix] = elementNamespace;
      namespaces[elementPrefix] = elementNamespace;
    } else if (elementPrefix.isEmpty &&
        elementNamespace == null &&
        namespaces[''] != null &&
        namespaces['']!.isNotEmpty) {
      // An unqualified element below a non-empty default namespace requires
      // an explicit xmlns="" undeclaration in canonical form.
      declarations[''] = '';
      namespaces[''] = '';
    }
    for (final attribute in regularAttributes) {
      final prefix = attribute.name.prefix;
      final namespace = attribute.name.namespaceUri;
      if (prefix != null &&
          namespace != null &&
          namespaces[prefix] != namespace) {
        declarations[prefix] = namespace;
        namespaces[prefix] = namespace;
      }
    }
    final buffer = StringBuffer('<${element.name.qualified}');
    final sortedNamespaces = declarations.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    for (final declaration in sortedNamespaces) {
      final name = declaration.key.isEmpty
          ? 'xmlns'
          : 'xmlns:${declaration.key}';
      buffer.write(' $name="${_attribute(declaration.value)}"');
    }
    regularAttributes.sort((a, b) {
      final namespaceA = a.name.namespaceUri ?? '';
      final namespaceB = b.name.namespaceUri ?? '';
      final namespaceOrder = namespaceA.compareTo(namespaceB);
      return namespaceOrder == 0
          ? a.name.local.compareTo(b.name.local)
          : namespaceOrder;
    });
    for (final attribute in regularAttributes) {
      buffer.write(
        ' ${attribute.name.qualified}="${_attribute(attribute.value)}"',
      );
    }
    buffer.write('>');
    for (final child in element.children) {
      if (child is XmlElement) {
        buffer.write(_write(child, namespaces, false));
      } else if (child is XmlText) {
        buffer.write(_text(child.value));
      } else if (child is XmlProcessing) {
        buffer.write('<?${child.target}');
        if (child.value.isNotEmpty) {
          buffer.write(' ${child.value}');
        }
        buffer.write('?>');
      }
    }
    buffer.write('</${element.name.qualified}>');
    return buffer.toString();
  }

  static String _attribute(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('"', '&quot;')
      .replaceAll('\t', '&#x9;')
      .replaceAll('\n', '&#xA;')
      .replaceAll('\r', '&#xD;');

  static String _text(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('\r', '&#xD;');
}
