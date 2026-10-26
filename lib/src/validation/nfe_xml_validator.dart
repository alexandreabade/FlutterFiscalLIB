import 'dart:convert';

import 'package:xml/xml.dart';

import '../exceptions/fiscal_exception.dart';
import '../common/fiscal_decimal.dart';
import '../crypto/rsa_signature.dart';
import '../models/access_key.dart';
import '../tools.dart';

/// Resultado da validação estrutural de um XML fiscal.
class NfeXmlValidationResult {
  /// Cria um resultado com a lista de erros encontrados.
  const NfeXmlValidationResult(this.errors);

  /// Mensagens de inconsistência, em ordem de detecção.
  final List<String> errors;

  /// Indica que não foram encontradas inconsistências estruturais.
  bool get isValid => errors.isEmpty;
}

/// Callback opcional para verificar criptograficamente a assinatura do XML.
typedef NfeXmlSignatureVerifier = bool Function(String xml);

/// Valida invariantes estruturais do XML NF-e/NFC-e.
class NfeXmlValidator {
  /// Analisa [xml] sem executar validação XSD.
  NfeXmlValidationResult validate(
    String xml, {
    bool requireSignature = false,
    NfeXmlSignatureVerifier? signatureVerifier,
    XmlSignatureVerifier? qrCodeSignatureVerifier,
  }) {
    try {
      final document = XmlDocument.parse(xml);
      final result = _validateDocument(
        document,
        requireSignature: requireSignature,
        qrCodeSignatureVerifier: qrCodeSignatureVerifier,
      );
      if (requireSignature && signatureVerifier == null) {
        return NfeXmlValidationResult([
          ...result.errors,
          'A validação de assinatura exige um verificador criptográfico explícito.',
        ]);
      }
      var signatureVerified = true;
      if (signatureVerifier != null) {
        try {
          signatureVerified = signatureVerifier(xml);
        } on Object {
          signatureVerified = false;
        }
      }
      if (signatureVerifier != null &&
          (!signatureVerified ||
              document.rootElement.getElement('Signature') == null)) {
        return NfeXmlValidationResult([
          ...result.errors,
          'A assinatura XMLDSig não foi verificada criptograficamente.',
        ]);
      }
      return result;
    } on XmlException catch (error) {
      return NfeXmlValidationResult(['XML inválido: ${error.message}']);
    }
  }

  /// Valida e lança uma exceção quando o XML não é estruturalmente válido.
  void assertValid(
    String xml, {
    bool requireSignature = false,
    NfeXmlSignatureVerifier? signatureVerifier,
    XmlSignatureVerifier? qrCodeSignatureVerifier,
  }) {
    final result = validate(
      xml,
      requireSignature: requireSignature,
      signatureVerifier: signatureVerifier,
      qrCodeSignatureVerifier: qrCodeSignatureVerifier,
    );
    if (!result.isValid) {
      throw FiscalValidationException(
        result.errors.join(' '),
        code: 'INVALID_NFE_XML',
      );
    }
  }

  NfeXmlValidationResult _validateDocument(
    XmlDocument document, {
    required bool requireSignature,
    XmlSignatureVerifier? qrCodeSignatureVerifier,
  }) {
    final errors = <String>[];
    final root = document.rootElement;
    if (root.localName != 'NFe') {
      errors.add('A raiz deve ser NFe.');
      return NfeXmlValidationResult(errors);
    }
    final infElements = root.childElements
        .where((element) => element.localName == 'infNFe')
        .toList();
    if (infElements.length != 1) {
      errors.add('Deve existir exatamente um grupo infNFe direto na raiz.');
      return NfeXmlValidationResult(errors);
    }
    final inf = infElements.single;
    final id = inf.getAttribute('Id');
    _validateSignatureEnvelope(
      root,
      inf,
      id,
      errors,
      requireSignature: requireSignature,
    );
    if (inf.getAttribute('versao') != '4.00') {
      errors.add('A versão de infNFe deve ser 4.00.');
    }
    if (id == null || !id.startsWith('NFe')) {
      errors.add('O atributo Id deve iniciar com NFe.');
    } else if (!AccessKey.isValid(id.substring(3))) {
      errors.add('O Id não contém uma chave de acesso válida.');
    }
    final ide = inf.getElement('ide');
    if (ide == null) {
      errors.add('O grupo ide é obrigatório.');
    } else {
      _required(ide, 'cUF', errors);
      _required(ide, 'nNF', errors);
      _required(ide, 'serie', errors);
      _required(ide, 'mod', errors);
      _required(ide, 'tpAmb', errors);
      _required(ide, 'dhEmi', errors);
      _validateIde(ide, id, errors);
    }
    final emit = inf.getElement('emit');
    if (emit == null) errors.add('O grupo emit é obrigatório.');
    if (emit != null) _validateParty(emit, errors, role: 'emitente');
    final recipient = inf.getElement('dest');
    if (recipient != null) {
      _validateParty(recipient, errors, role: 'destinatário');
    }
    _validateNfceSupplement(
      root,
      inf,
      ide,
      recipient,
      id,
      errors,
      qrCodeSignatureVerifier: qrCodeSignatureVerifier,
    );
    final details = inf.childElements
        .where((element) => element.localName == 'det')
        .toList();
    if (details.isEmpty) {
      errors.add('É necessário informar ao menos um grupo det.');
    } else {
      _validateDetails(details, errors);
    }
    final total = inf.getElement('total')?.getElement('ICMSTot');
    if (total == null) {
      errors.add('O grupo total/ICMSTot é obrigatório.');
    } else {
      _required(total, 'vProd', errors);
      _required(total, 'vNF', errors);
      for (final field in [
        'vProd',
        'vFrete',
        'vSeg',
        'vDesc',
        'vII',
        'vIPI',
        'vST',
        'vOutro',
        'vNF',
      ]) {
        final value = total.getElement(field)?.innerText.trim();
        if (value != null && value.isNotEmpty && !_isDecimal(value)) {
          errors.add('O totalizador $field deve ser decimal positivo.');
        }
      }
      _validateTotals(details, total, inf, errors);
    }
    return NfeXmlValidationResult(errors);
  }

  void _validateSignatureEnvelope(
    XmlElement root,
    XmlElement inf,
    String? id,
    List<String> errors, {
    required bool requireSignature,
  }) {
    final directSignatures = root.childElements
        .where((element) => element.localName == 'Signature')
        .toList();
    final nestedSignatures = inf.descendants
        .whereType<XmlElement>()
        .where((element) => element.localName == 'Signature')
        .toList();
    if (nestedSignatures.isNotEmpty) {
      errors.add('A assinatura deve ser filha direta de NFe, fora de infNFe.');
    }
    if (directSignatures.length > 1) {
      errors.add('O XML não pode possuir mais de uma assinatura direta.');
    }
    if (requireSignature && directSignatures.isEmpty) {
      errors.add('O XML assinado deve possuir uma assinatura direta.');
    }
    if (directSignatures.isEmpty) return;
    final signature = directSignatures.single;
    final reference = signature
        .getElement('SignedInfo')
        ?.getElement('Reference');
    final uri = reference?.getAttribute('URI');
    if (id == null || uri != '#$id') {
      errors.add('A assinatura deve referenciar exatamente o Id de infNFe.');
    }
    final referencedIds = root.descendants
        .whereType<XmlElement>()
        .where((element) => element.getAttribute('Id') == id)
        .length;
    if (id != null && referencedIds != 1) {
      errors.add('O Id referenciado pela assinatura deve ser único.');
    }
    if (reference?.getElement('DigestValue')?.innerText.trim().isEmpty ??
        true) {
      errors.add('A assinatura deve possuir DigestValue.');
    }
    if (signature.getElement('SignatureValue')?.innerText.trim().isEmpty ??
        true) {
      errors.add('A assinatura deve possuir SignatureValue.');
    }
  }

  void _validateIde(XmlElement ide, String? id, List<String> errors) {
    final key = id != null && id.startsWith('NFe') ? id.substring(3) : null;
    final values = <String, String?>{
      'cUF': ide.getElement('cUF')?.innerText.trim(),
      'mod': ide.getElement('mod')?.innerText.trim(),
      'serie': ide.getElement('serie')?.innerText.trim(),
      'nNF': ide.getElement('nNF')?.innerText.trim(),
      'tpEmis': ide.getElement('tpEmis')?.innerText.trim(),
      'tpAmb': ide.getElement('tpAmb')?.innerText.trim(),
    };
    final cUf = values['cUF'];
    if (cUf != null && !RegExp(r'^\d{2}$').hasMatch(cUf)) {
      errors.add('O cUF deve conter dois dígitos.');
    }
    final model = int.tryParse(values['mod'] ?? '');
    if (model != 55 && model != 65) {
      errors.add('O modelo deve ser 55 ou 65.');
    }
    final environment = int.tryParse(values['tpAmb'] ?? '');
    if (environment != 1 && environment != 2) {
      errors.add('O tpAmb deve ser 1 ou 2.');
    }
    final emission = int.tryParse(values['tpEmis'] ?? '');
    if (emission == null || emission < 1 || emission > 9) {
      errors.add('O tpEmis deve estar entre 1 e 9.');
    }
    if (model == 55 && emission == 9) {
      errors.add(
        'A contingência offline tpEmis=9 é exclusiva da NFC-e modelo 65.',
      );
    }
    if (model == 65 && emission != null && emission != 1 && emission != 9) {
      errors.add('A NFC-e modelo 65 aceita somente tpEmis=1 ou tpEmis=9.');
    }
    if (emission == 9) {
      _required(ide, 'dhCont', errors);
      _required(ide, 'xJust', errors);
      final justification = ide.getElement('xJust')?.innerText.trim() ?? '';
      if (justification.isNotEmpty && justification.length < 15) {
        errors.add(
          'A justificativa da contingência deve possuir ao menos 15 caracteres.',
        );
      }
      final contingencyDate = DateTime.tryParse(
        ide.getElement('dhCont')?.innerText ?? '',
      );
      if (contingencyDate == null) {
        errors.add('O dhCont deve ser uma data ISO-8601 válida.');
      }
    }
    final issueDate = DateTime.tryParse(
      ide.getElement('dhEmi')?.innerText ?? '',
    );
    if (issueDate == null) {
      errors.add('O dhEmi deve ser uma data ISO-8601 válida.');
    }
    if (key != null && AccessKey.isValid(key)) {
      final expected = <String, String>{
        'cUF': key.substring(0, 2),
        'mod': key.substring(20, 22),
        'serie': int.parse(key.substring(22, 25)).toString(),
        'nNF': int.parse(key.substring(25, 34)).toString(),
        'tpEmis': key[34],
      };
      for (final entry in expected.entries) {
        final actual = values[entry.key];
        if (actual != null && int.tryParse(actual) != null) {
          if (int.parse(actual) != int.parse(entry.value)) {
            errors.add(
              'O campo ${entry.key} do ide não corresponde à chave de acesso.',
            );
          }
        } else if (actual != entry.value) {
          errors.add(
            'O campo ${entry.key} do ide não corresponde à chave de acesso.',
          );
        }
      }
      if (model != null && model != AccessKey.modelOf(key)) {
        errors.add('O modelo do ide não corresponde à chave de acesso.');
      }
      if (emission != null && emission != AccessKey.emissionTypeOf(key)) {
        errors.add('O tpEmis não corresponde à chave de acesso.');
      }
    }
  }

  void _validateNfceSupplement(
    XmlElement root,
    XmlElement inf,
    XmlElement? ide,
    XmlElement? recipient,
    String? id,
    List<String> errors, {
    XmlSignatureVerifier? qrCodeSignatureVerifier,
  }) {
    final supplement = root.childElements
        .where((element) => element.localName == 'infNFeSupl')
        .toList();
    if (supplement.isEmpty) return;
    final key = id != null && id.startsWith('NFe') ? id.substring(3) : null;
    final model = int.tryParse(
      inf.getElement('ide')?.getElement('mod')?.innerText.trim() ?? '',
    );
    if (model != 65) {
      errors.add('O grupo infNFeSupl só pode ser usado em NFC-e modelo 65.');
      return;
    }
    if (supplement.length != 1) {
      errors.add('Deve existir no máximo um grupo infNFeSupl.');
      return;
    }
    final supplementElement = supplement.single;
    final qrElements = supplementElement.childElements
        .where((element) => element.localName == 'qrCode')
        .toList();
    final keyUrlElements = supplementElement.childElements
        .where((element) => element.localName == 'urlChave')
        .toList();
    if (qrElements.length > 1) {
      errors.add('O grupo infNFeSupl não pode possuir qrCode duplicado.');
    }
    if (keyUrlElements.length > 1) {
      errors.add('O grupo infNFeSupl não pode possuir urlChave duplicado.');
    }
    final qrCode = qrElements.length == 1
        ? qrElements.single.innerText.trim()
        : null;
    final keyUrl = keyUrlElements.length == 1
        ? keyUrlElements.single.innerText.trim()
        : null;
    if (qrCode == null || qrCode.isEmpty) {
      errors.add('O grupo infNFeSupl deve informar qrCode.');
      return;
    }
    if (keyUrl == null || keyUrl.isEmpty) {
      errors.add('O grupo infNFeSupl deve informar urlChave.');
    } else {
      final uri = Uri.tryParse(keyUrl);
      if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
        errors.add('O urlChave deve usar HTTP ou HTTPS.');
      }
    }
    final uri = Uri.tryParse(qrCode);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      errors.add('O qrCode deve ser uma URL HTTP ou HTTPS.');
      return;
    }
    final marker = uri.query
        .split('&')
        .firstWhere((part) => part.startsWith('p='), orElse: () => '');
    if (marker.isEmpty) {
      errors.add('O qrCode deve possuir o parâmetro p.');
      return;
    }
    final payload = Uri.decodeComponent(marker.substring(2));
    final fields = payload.split('|');
    if (fields.length < 3 || fields[0] != key) {
      errors.add('A chave do qrCode não corresponde ao Id da NFC-e.');
      return;
    }
    final version = fields[1];
    final environment = int.tryParse(fields[2]);
    final ideEnvironment = int.tryParse(
      ide?.getElement('tpAmb')?.innerText.trim() ?? '',
    );
    if (environment == null || environment != ideEnvironment) {
      errors.add('O tpAmb do qrCode não corresponde ao ide.');
    }
    if (version == '2') {
      _validateQrCodeV2(fields, inf, ide, key, errors);
    } else if (version == '3') {
      _validateQrCodeV3(
        fields,
        inf,
        ide,
        key,
        recipient,
        errors,
        qrCodeSignatureVerifier: qrCodeSignatureVerifier,
      );
    } else {
      errors.add('A versão do qrCode NFC-e deve ser 2 ou 3.');
    }
  }

  void _validateQrCodeV2(
    List<String> fields,
    XmlElement inf,
    XmlElement? ide,
    String? key,
    List<String> errors,
  ) {
    if (fields.length != 5 && fields.length != 8) {
      errors.add('O qrCode 2.00 possui quantidade de parâmetros inválida.');
      return;
    }
    if (fields[0] != key || fields[1] != '2') {
      errors.add('Os parâmetros iniciais do qrCode 2.00 são inválidos.');
    }
    final cscId = fields.length == 5 ? fields[3] : fields[6];
    final hash = fields.length == 5 ? fields[4] : fields[7];
    if (!RegExp(r'^[1-9][0-9]{0,5}$').hasMatch(cscId)) {
      errors.add('O identificador CSC do qrCode 2.00 é inválido.');
    }
    if (!RegExp(r'^[a-fA-F0-9]{40}$').hasMatch(hash)) {
      errors.add('O hash do qrCode 2.00 deve possuir 40 dígitos hexadecimais.');
    }
    if (fields.length != 8) return;
    final emission = int.tryParse(
      ide?.getElement('tpEmis')?.innerText.trim() ?? '',
    );
    if (emission != 9) {
      errors.add('O qrCode 2.00 offline exige tpEmis=9.');
    }
    final issue = DateTime.tryParse(ide?.getElement('dhEmi')?.innerText ?? '');
    if (issue == null || fields[3] != issue.day.toString().padLeft(2, '0')) {
      errors.add('O dia de emissão do qrCode 2.00 não corresponde ao ide.');
    }
    final total = _decimal(fields[4]);
    final xmlTotal = _decimal(
      inf
          .getElement('total')
          ?.getElement('ICMSTot')
          ?.getElement('vNF')
          ?.innerText,
    );
    if (!_isDecimal(fields[4]) || total.toFixed(2) != xmlTotal.toFixed(2)) {
      errors.add('O valor do qrCode 2.00 não corresponde ao vNF.');
    }
    if (!RegExp(r'^[a-fA-F0-9]{56}$').hasMatch(fields[5])) {
      errors.add(
        'O DigestValue do qrCode 2.00 deve possuir 56 dígitos hexadecimais.',
      );
    }
  }

  void _validateQrCodeV3(
    List<String> fields,
    XmlElement inf,
    XmlElement? ide,
    String? key,
    XmlElement? recipient,
    List<String> errors, {
    XmlSignatureVerifier? qrCodeSignatureVerifier,
  }) {
    if (fields.length != 3 && fields.length != 8) {
      errors.add('O qrCode 3.00 possui quantidade de parâmetros inválida.');
      return;
    }
    if (fields[0] != key || fields[1] != '3') {
      errors.add('Os parâmetros iniciais do qrCode 3.00 são inválidos.');
    }
    if (fields.length == 3) {
      final emission = int.tryParse(
        ide?.getElement('tpEmis')?.innerText.trim() ?? '',
      );
      if (emission != 1) {
        errors.add('O qrCode 3.00 online exige tpEmis=1.');
      }
      return;
    }
    final emission = int.tryParse(
      ide?.getElement('tpEmis')?.innerText.trim() ?? '',
    );
    if (emission != 9) {
      errors.add('O qrCode 3.00 offline exige tpEmis=9.');
    }
    final issue = DateTime.tryParse(ide?.getElement('dhEmi')?.innerText ?? '');
    if (issue == null || fields[3] != issue.day.toString().padLeft(2, '0')) {
      errors.add('O dia de emissão do qrCode 3.00 não corresponde ao ide.');
    }
    final xmlTotal = _decimal(
      inf
          .getElement('total')
          ?.getElement('ICMSTot')
          ?.getElement('vNF')
          ?.innerText,
    );
    if (!_isDecimal(fields[4]) ||
        _decimal(fields[4]).toFixed(2) != xmlTotal.toFixed(2)) {
      errors.add('O valor do qrCode 3.00 não corresponde ao vNF.');
    }
    _validateQrCodeRecipient(fields[5], fields[6], recipient, errors);
    try {
      base64Decode(fields[7]);
    } on FormatException {
      errors.add('A assinatura do qrCode 3.00 deve ser Base64 válida.');
    }
    if (fields[7].trim().isEmpty || fields[7].contains(RegExp(r'\s'))) {
      errors.add('A assinatura do qrCode 3.00 deve ser uma linha única.');
    }
    if (qrCodeSignatureVerifier != null &&
        fields[7].trim().isNotEmpty &&
        !fields[7].contains(RegExp(r'\s'))) {
      var verified = false;
      try {
        verified = qrCodeSignatureVerifier.verify(
          utf8.encode(fields.sublist(0, 7).join('|')),
          fields[7],
        );
      } on Object {
        verified = false;
      }
      if (!verified) {
        errors.add(
          'A assinatura do qrCode 3.00 não foi verificada criptograficamente.',
        );
      }
    }
  }

  void _validateQrCodeRecipient(
    String type,
    String identifier,
    XmlElement? recipient,
    List<String> errors,
  ) {
    if (type.isEmpty && identifier.isEmpty) {
      if (recipient != null) {
        errors.add('O qrCode 3.00 omite um destinatário informado no XML.');
      }
      return;
    }
    if (!const ['1', '2', '3'].contains(type) ||
        identifier.length < 3 ||
        identifier.length > 14) {
      errors.add('A identificação do destinatário no qrCode 3.00 é inválida.');
      return;
    }
    final expected = switch (type) {
      '1' => recipient?.getElement('CNPJ')?.innerText.trim(),
      '2' => recipient?.getElement('CPF')?.innerText.trim(),
      '3' => recipient?.getElement('idEstrangeiro')?.innerText.trim(),
      _ => null,
    };
    final normalizedExpected = type == '3'
        ? expected
        : Tools.onlyDigits(expected ?? '');
    final normalizedIdentifier = type == '3'
        ? identifier
        : Tools.onlyDigits(identifier);
    if (expected == null || normalizedExpected != normalizedIdentifier) {
      errors.add('O destinatário do qrCode 3.00 não corresponde ao XML.');
    }
  }

  void _validateParty(
    XmlElement party,
    List<String> errors, {
    required String role,
  }) {
    final cnpj = party.getElement('CNPJ')?.innerText.trim();
    final cpf = party.getElement('CPF')?.innerText.trim();
    if ((cnpj == null) == (cpf == null)) {
      errors.add('O $role deve informar exatamente um CNPJ ou CPF.');
    } else if (cnpj != null && !Tools.isValidCnpj(cnpj)) {
      errors.add('O CNPJ do $role é inválido.');
    } else if (cpf != null && !Tools.isValidCpf(cpf)) {
      errors.add('O CPF do $role é inválido.');
    }
    if (party.getElement('xNome') == null ||
        party.getElement('xNome')!.innerText.trim().isEmpty) {
      errors.add('O $role deve informar xNome.');
    }
  }

  void _validateDetails(List<XmlElement> details, List<String> errors) {
    final numbers = <int>{};
    for (final detail in details) {
      final number = int.tryParse(detail.getAttribute('nItem') ?? '');
      if (number == null || number < 1 || !numbers.add(number)) {
        errors.add('Cada det deve possuir nItem positivo e único.');
      }
      final product = detail.getElement('prod');
      if (product == null) {
        errors.add('Cada det deve possuir o grupo prod.');
        continue;
      }
      for (final field in [
        'cProd',
        'xProd',
        'NCM',
        'CFOP',
        'uCom',
        'qCom',
        'vProd',
      ]) {
        _required(product, field, errors);
      }
      for (final field in ['qCom', 'vUnCom', 'vProd']) {
        final value = product.getElement(field)?.innerText.trim();
        if (value != null && !_isDecimal(value)) {
          errors.add('O campo $field do produto deve ser decimal positivo.');
        }
      }
      final indTot = product.getElement('indTot')?.innerText.trim();
      if (indTot != null && indTot != '0' && indTot != '1') {
        errors.add('O campo indTot do produto deve ser 0 ou 1.');
      }
    }
  }

  void _validateTotals(
    List<XmlElement> details,
    XmlElement total,
    XmlElement inf,
    List<String> errors,
  ) {
    final expected = details.fold(
      FiscalDecimal.parse('0'),
      (sum, detail) =>
          sum +
          (detail.getElement('prod')?.getElement('indTot')?.innerText.trim() ==
                  '0'
              ? FiscalDecimal.parse('0')
              : _decimal(
                  detail.getElement('prod')?.getElement('vProd')?.innerText,
                )),
    );
    final productTotal = _decimal(total.getElement('vProd')?.innerText);
    if (productTotal.toFixed(2) != expected.toFixed(2)) {
      errors.add('O total vProd não corresponde à soma dos itens.');
    }
    final documentTotal = _decimal(total.getElement('vNF')?.innerText);
    final expectedDocumentTotal =
        productTotal +
        _decimal(total.getElement('vFrete')?.innerText) +
        _decimal(total.getElement('vSeg')?.innerText) +
        _decimal(total.getElement('vOutro')?.innerText) +
        _decimal(total.getElement('vII')?.innerText) +
        _decimal(total.getElement('vIPI')?.innerText) +
        _decimal(total.getElement('vST')?.innerText) -
        _decimal(total.getElement('vDesc')?.innerText);
    if (documentTotal.toFixed(2) != expectedDocumentTotal.toFixed(2)) {
      errors.add(
        'O total vNF não corresponde aos totalizadores monetários do documento.',
      );
    }
    final pag = inf.getElement('pag');
    if (pag != null) {
      final paid = pag.childElements
          .where((element) => element.localName == 'detPag')
          .fold(FiscalDecimal.parse('0'), (sum, detail) {
            final value = detail.getElement('vPag')?.innerText.trim();
            if (value != null && value.isNotEmpty && !_isDecimal(value)) {
              errors.add('O pagamento vPag deve ser decimal positivo.');
            }
            return sum + _decimal(value);
          });
      final change = _decimal(pag.getElement('vTroco')?.innerText);
      final changeText = pag.getElement('vTroco')?.innerText.trim();
      if (changeText != null && !_isDecimal(changeText)) {
        errors.add('O pagamento vTroco deve ser decimal positivo.');
      }
      if ((paid - change).toFixed(2) != documentTotal.toFixed(2)) {
        errors.add('A soma dos pagamentos não corresponde ao vNF.');
      }
    }
  }

  FiscalDecimal _decimal(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return FiscalDecimal.parse('0');
    try {
      return FiscalDecimal.parse(text);
    } on FiscalException {
      return FiscalDecimal.parse('0');
    }
  }

  bool _isDecimal(String value) => RegExp(r'^\d+(\.\d+)?$').hasMatch(value);

  void _required(XmlElement parent, String name, List<String> errors) {
    final child = parent.getElement(name);
    if (child == null || child.innerText.trim().isEmpty) {
      errors.add('O campo $name é obrigatório.');
    }
  }
}
