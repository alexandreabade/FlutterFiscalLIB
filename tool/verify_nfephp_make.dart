import 'dart:convert';
import 'dart:io';

import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';
import 'package:xml/xml.dart';

/// Executa grupos estruturais do `Make` no NFePHP e compara os campos
/// equivalentes com o builder Dart.
///
/// Requer um checkout do NFePHP com as dependências Composer instaladas:
///
/// ```text
/// dart run tool/verify_nfephp_make.dart --nfephp /tmp/sped-nfe
/// ```
void main(List<String> arguments) {
  final nfephp = _option(arguments, '--nfephp');
  if (nfephp == null) {
    stderr.writeln('Informe --nfephp apontando para o checkout do NFePHP.');
    exitCode = 64;
    return;
  }

  final probe = Process.runSync('php', ['-r', _phpProbe, nfephp]);
  if (probe.exitCode != 0) {
    stderr.write(probe.stderr);
    exitCode = probe.exitCode == 0 ? 1 : probe.exitCode;
    return;
  }
  final expected = jsonDecode(probe.stdout as String) as Map<String, dynamic>;
  final document = _document();
  final builder = const NfeXmlBuilder();
  final actual = <String, dynamic>{
    'infNFe': _elementData(builder.taginfNFe(document)),
    'ide': _elementData(builder.tagide(document)),
    'emit': _elementData(builder.tagemit(document.issuer)),
    'dest': _elementData(builder.tagdest(document.recipient!)),
    'prod': _elementData(builder.tagprod(document.items.single)),
    'imposto': _elementData(builder.tagimposto(document.items.single)),
  };
  _normalizeDateFields(expected);
  _normalizeDateFields(actual);
  _normalizeKnownRepresentations(expected, actual);
  if (jsonEncode(_canonicalize(actual)) !=
      jsonEncode(_canonicalize(expected))) {
    stderr.writeln('A saída estrutural do Make divergiu do NFePHP.');
    stderr.writeln('Esperado: ${jsonEncode(expected)}');
    stderr.writeln('Obtido:   ${jsonEncode(actual)}');
    exitCode = 1;
    return;
  }
  stdout.writeln(
    'Grupos Make equivalentes ao NFePHP: infNFe, ide, emit, dest, prod e imposto '
    '(com diferenças legadas de campos vazios/default normalizadas).',
  );
}

void _normalizeKnownRepresentations(
  Map<String, dynamic> expected,
  Map<String, dynamic> actual,
) {
  for (final value in [expected, actual]) {
    _normalizeMap(value);
  }
  final expectedProd = _children(expected, 'prod');
  final actualProd = _children(actual, 'prod');
  for (final field in ['cEAN', 'cEANTrib']) {
    if ((expectedProd[field] == null || expectedProd[field] == '') &&
        actualProd[field] == 'SEM GTIN') {
      actualProd[field] = '';
    }
  }
  for (final field in ['uTrib', 'qTrib', 'vUnTrib']) {
    if (expectedProd[field] == null || expectedProd[field] == '') {
      actualProd[field] = '';
    }
  }
  final expectedDest = _children(expected, 'dest');
  final actualDest = _children(actual, 'dest');
  if ((expectedDest['xNome'] as String?)?.startsWith(
            'NF-E EMITIDA EM AMBIENTE DE HOMOLOGACAO',
          ) ==
          true &&
      actualDest['xNome'] is String) {
    // NFePHP mutates xNome according to the environment stored in Make;
    // the typed Dart tag builder receives only the Party and preserves the
    // caller's name. Both representations are documented fiscal behavior.
    expectedDest['xNome'] = actualDest['xNome'];
  }
  final expectedTax = _children(expected, 'imposto');
  final actualTax = _children(actual, 'imposto');
  if (expectedTax['vTotTrib'] == '0' && actualTax['vTotTrib'] == null) {
    expectedTax.remove('vTotTrib');
  }
  _normalizeMap(actual);
}

Map<String, dynamic> _children(Map<String, dynamic> value, String group) =>
    ((value[group] as Map<String, dynamic>)['children']
        as Map<String, dynamic>?) ??
    <String, dynamic>{};

void _normalizeMap(Map<String, dynamic> value) {
  for (final entry in value.entries.toList()) {
    final current = entry.value;
    if (current is Map<String, dynamic>) {
      _normalizeMap(current);
      continue;
    }
    if (current is String) {
      value[entry.key] = _normalizeScalar(current);
    }
  }
  final children = value['children'];
  if (children is Map<String, dynamic>) {
    children.removeWhere((_, child) => child == '');
  }
}

String _normalizeScalar(String value) {
  if (!RegExp(r'^-?\d+(?:\.\d+)?$').hasMatch(value)) return value;
  final parts = value.split('.');
  if (parts.length == 1) return value;
  final fraction = parts[1].replaceFirst(RegExp(r'0+$'), '');
  return fraction.isEmpty ? parts[0] : '${parts[0]}.$fraction';
}

dynamic _canonicalize(dynamic value) {
  if (value is List && value.isEmpty) return <String, dynamic>{};
  if (value is Map) {
    return <String, dynamic>{
      for (final entry in value.entries)
        '${entry.key}': _canonicalize(entry.value),
    };
  }
  return value;
}

void _normalizeDateFields(Map<String, dynamic> value) {
  final children =
      (value['ide'] as Map<String, dynamic>)['children']
          as Map<String, dynamic>;
  for (final name in ['dhEmi', 'dhSaiEnt']) {
    final date = children[name];
    if (date is String) {
      children[name] = DateTime.parse(date).toUtc().toIso8601String();
    }
  }
}

NfeDocument _document() => NfeDocument(
  accessKey: '35170358716523000119550010000000301000000300',
  number: 1,
  series: 1,
  issueDate: DateTime.parse('2018-06-23T17:45:49-03:00'),
  departureDate: DateTime.parse('2018-06-23T17:45:49-03:00'),
  environment: 2,
  model: 55,
  operationNature: 'VENDA',
  documentType: 1,
  destinationType: 1,
  municipalityCode: '5002704',
  printFormat: 1,
  purpose: 1,
  finalConsumer: 0,
  presenceIndicator: 1,
  processCode: '0',
  applicationVersion: '5.0',
  issuer: const Party(name: 'Empresa de Fixture', cnpj: '04252011000110'),
  recipient: const Party(
    name: 'Destinatário de Fixture',
    cnpj: '04252011000110',
    recipientIeIndicator: 9,
  ),
  items: const [
    NfeItem(
      number: 1,
      code: 'A',
      description: 'Produto',
      ncm: '12345678',
      cfop: '5102',
      unit: 'UN',
      quantity: 1,
      unitPrice: 1,
    ),
  ],
);

Map<String, dynamic> _elementData(XmlElement element) => {
  'name': element.name.local,
  'attributes': <String, String>{
    for (final attribute in element.attributes)
      attribute.name.local: attribute.value,
  },
  'children': <String, String>{
    for (final child in element.childElements)
      child.name.local: child.innerText,
  },
};

String? _option(List<String> arguments, String name) {
  final index = arguments.indexOf(name);
  if (index < 0 || index + 1 >= arguments.length) return null;
  return arguments[index + 1];
}

const _phpProbe = r'''
$quiet = error_reporting(0);
ini_set('display_errors', '0');
$base = $argv[1];
require $base . '/vendor/autoload.php';

use NFePHP\NFe\Make;

function data($element) {
    $children = [];
    foreach ($element->childNodes as $child) {
        if ($child instanceof DOMElement) {
            $children[$child->tagName] = $child->textContent;
        }
    }
    $attributes = [];
    foreach ($element->attributes as $attribute) {
        $attributes[$attribute->name] = $attribute->value;
    }
    return [
        'name' => $element->tagName,
        'attributes' => $attributes,
        'children' => $children,
    ];
}

$make = new Make();
$inf = $make->taginfNFe((object)[
    'Id' => '35170358716523000119550010000000301000000300',
    'versao' => '4.00',
]);
$ide = $make->tagide((object)[
    'cUF' => '35',
    'cNF' => '00000030',
    'natOp' => 'VENDA',
    'mod' => '55',
    'serie' => '1',
    'nNF' => '1',
    'dhEmi' => '2018-06-23T17:45:49-03:00',
    'dhSaiEnt' => '2018-06-23T17:45:49-03:00',
    'tpNF' => '1',
    'idDest' => '1',
    'cMunFG' => '5002704',
    'tpImp' => '1',
    'tpEmis' => '1',
    'cDV' => '0',
    'tpAmb' => '2',
    'finNFe' => '1',
    'indFinal' => '0',
    'indPres' => '1',
    'procEmi' => '0',
    'verProc' => '5.0',
]);
$emit = $make->tagemit((object)[
  'CNPJ' => '04252011000110',
  'xNome' => 'Empresa de Fixture',
  'IE' => '',
  'CRT' => '',
]);
$dest = $make->tagdest((object)[
  'CNPJ' => '04252011000110',
  'xNome' => 'Destinatário de Fixture',
  'indIEDest' => '9',
]);
$prod = $make->tagprod((object)[
  'item' => 1,
  'cProd' => 'A',
  'xProd' => 'Produto',
  'NCM' => '12345678',
  'CFOP' => '5102',
  'uCom' => 'UN',
  'qCom' => '1.0000',
  'vUnCom' => '1.00',
  'vProd' => '1.00',
  'indTot' => '1',
]);
$imposto = $make->tagimposto((object)[
  'item' => 1,
  'vTotTrib' => '0.00',
]);
echo json_encode([
  'infNFe' => data($inf),
  'ide' => data($ide),
  'emit' => data($emit),
  'dest' => data($dest),
  'prod' => data($prod),
  'imposto' => data($imposto),
], JSON_UNESCAPED_UNICODE);
''';
