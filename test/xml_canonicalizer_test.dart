import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';
import 'package:xml/xml.dart';
import 'package:test/test.dart';

void main() {
  test('ordena atributos e escapa conteúdo conforme C14N', () {
    final element = XmlDocument.parse(
      '<x b="2" a="&quot;um&quot;"><y>texto &amp; valor</y></x>',
    ).rootElement;

    expect(
      XmlCanonicalizer.canonicalize(element),
      '<x a="&quot;um&quot;" b="2"><y>texto &amp; valor</y></x>',
    );
  });

  test('inclui namespace herdado ao canonicalizar subárvore', () {
    final document = XmlDocument.parse(
      '<NFe xmlns="http://www.portalfiscal.inf.br/nfe"><infNFe Id="NFe1"/></NFe>',
    );

    expect(
      XmlCanonicalizer.canonicalize(
        document.rootElement.getElement('infNFe')!,
        inheritedNamespaces: const {'': 'http://www.portalfiscal.inf.br/nfe'},
      ),
      '<infNFe xmlns="http://www.portalfiscal.inf.br/nfe" Id="NFe1"></infNFe>',
    );
  });

  test('inclui todos os namespaces herdados na C14N inclusiva', () {
    final document = XmlDocument.parse(
      '<root xmlns="urn:default" xmlns:p="urn:p"><child/></root>',
    );

    expect(
      XmlCanonicalizer.canonicalize(
        document.rootElement.getElement('child')!,
        inheritedNamespaces: const {'': 'urn:default', 'p': 'urn:p'},
      ),
      '<child xmlns="urn:default" xmlns:p="urn:p"></child>',
    );
  });

  test('emite a remoção do namespace default e instruções de processamento', () {
    final document = XmlDocument.parse(
      '<root xmlns="urn:default"><child xmlns=""><?trace data?></child></root>',
    );

    expect(
      XmlCanonicalizer.canonicalize(
        document.rootElement.getElement('child')!,
        inheritedNamespaces: const {'': 'urn:default'},
      ),
      '<child xmlns=""><?trace data?></child>',
    );
  });
}
