import 'dart:convert';

import '../exceptions/fiscal_exception.dart';

/// Estrutura de um layout TXT legado do NFePHP.
class NfeTxtLayout {
  /// Cria um layout a partir do mapa marcador -> linha de referência.
  NfeTxtLayout(Map<String, String> structure, {this.baseLayout = 'LOCAL'})
    : structure = Map.unmodifiable(Map<String, String>.from(structure));

  /// Estrutura local do layout 4.00 do NFePHP.
  factory NfeTxtLayout.local400() => NfeTxtLayout(_local400);

  /// Estrutura histórica `LOCAL_V12` do NFePHP v5.0.100.
  ///
  /// A versão 1.2 utiliza a mesma cardinalidade da estrutura local 4.00 no
  /// snapshot de referência, mas o identificador é preservado para que a
  /// aplicação consiga selecionar explicitamente essa base.
  factory NfeTxtLayout.localV12() =>
      NfeTxtLayout(_local400, baseLayout: 'LOCAL_V12');

  /// Estrutura de TXT compatível com o emissor SEBRAE do NFePHP.
  factory NfeTxtLayout.sebrae400() =>
      NfeTxtLayout(_sebrae400(), baseLayout: 'SEBRAE');

  /// Linhas de referência por marcador.
  final Map<String, String> structure;

  /// Nome da base de layout usada pelo conversor (`LOCAL`, `LOCAL_V12` ou
  /// `SEBRAE`).
  final String baseLayout;

  static Map<String, String> _sebrae400() {
    final structure = Map<String, String>.from(_local400);
    structure.addAll({
      'A': 'A|versao|Id|',
      'B':
          'B|cUF|cNF|natOp|mod|serie|nNF|dhEmi|dhSaiEnt|tpNF|idDest|cMunFG|tpImp|tpEmis|cDV|tpAmb|finNFe|indFinal|indPres|procEmi|verProc|dhCont|xJust|',
      'F': 'F|xLgr|nro|xCpl|xBairro|cMun|xMun|UF|',
      'G': 'G|xLgr|nro|xCpl|xBairro|cMun|xMun|UF|',
      'I':
          'I|cProd|cEAN|xProd|NCM|EXTIPI|CFOP|uCom|qCom|vUnCom|vProd|cEANTrib|uTrib|qTrib|vUnTrib|vFrete|vSeg|vDesc|vOutro|indTot|xPed|nItemPed|nFCI|',
      'I05C': 'I05C|CEST|indEscala|CNPJFab|cBenef|',
      'K': 'K|cProdANVISA|vPMC|',
      'N08':
          'N08|orig|CST|vBCSTRet|pST|vICMSSTRet|vBCFCPSTRet|pFCPSTRet|vFCPSTRet|pRedBCEfet|vBCEfet|pICMSEfet|vICMSEfet|',
      'N10B': 'N10b|orig|CST|vBCSTRet|vICMSSTRet|vBCSTDest|vICMSSTDest|',
      'N10E':
          'N10e|orig|CSOSN|modBCST|pMVAST|pRedBCST|vBCST|pICMSST|vICMSST|vBCFCPST|pFCPST|vFCPST|pCredSN|vCredICMSSN|pCredSN|vCredICMSSN|',
      'N10G':
          'N10g|orig|CSOSN|vBCSTRet|pST|vICMSSTRet|vBCFCPSTRet|pFCPSTRet|vFCPSTRet|',
      'R04': 'R04|qBCProd|vAliqProd|',
      'S': 'S|',
      'UA': 'UA|pDevol|',
      'UA03': 'UA03|vIPIDevol|',
      'W02':
          'W02|vBC|vICMS|vICMSDeson|vFCP|vBCST|vST|vFCPST|vFCPSTRet|vProd|vFrete|vSeg|vDesc|vII|vIPI|vIPIDevol|vPIS|vCOFINS|vOutro|vNF|vTotTrib|',
      'W04C': 'W04c|vFCPUFDest|',
      'W04E': 'W04e|vICMSUFDest|',
      'W04G': 'W04g|vICMSUFRemet|',
      'Y': 'Y|',
      'YA': 'YA|vTroco|',
      'YA01': 'YA01|indPag|tPag|vPag|',
      'YA04': 'YA04|tpIntegra|CNPJ|tBand|cAut|',
    });
    structure.remove('F02B');
    structure.remove('G02B');
    structure.remove('ZD');
    return structure;
  }

  static const _local400 = <String, String>{
    "NOTAFISCAL": "NOTAFISCAL|qtd|",
    "A": "A|versao|Id|pk_nItem|",
    "B":
        "B|cUF|cNF|natOp|mod|serie|nNF|dhEmi|dhSaiEnt|tpNF|idDest|cMunFG|tpImp|tpEmis|cDV|tpAmb|finNFe|indFinal|indPres|indIntermed|procEmi|verProc|dhCont|xJust|",
    "BA": "BA|",
    "BA02": "BA02|refNFe|",
    "BA03": "BA03|cUF|AAMM|CNPJ|mod|serie|nNF|",
    "BA10": "BA10|cUF|AAMM|IE|mod|serie|nNF|",
    "BA13": "BA13|CNPJ|",
    "BA14": "BA14|CPF|",
    "B19": "B19|refCTe|",
    "BA19": "B19|refCTe|",
    "BA20": "BA20|mod|nECF|nCOO|",
    "C": "C|xNome|xFant|IE|IEST|IM|CNAE|CRT|",
    "C02": "C02|CNPJ|",
    "C02A": "C02a|CPF|",
    "C05": "C05|xLgr|nro|xCpl|xBairro|cMun|xMun|UF|CEP|cPais|xPais|fone|",
    "D": "D|CNPJ|xOrgao|matr|xAgente|fone|UF|nDAR|dEmi|vDAR|repEmi|dPag|",
    "E": "E|xNome|indIEDest|IE|ISUF|IM|email|",
    "E02": "E02|CNPJ|",
    "E03": "E03|CPF|",
    "E03A": "E03a|idEstrangeiro|",
    "E05": "E05|xLgr|nro|xCpl|xBairro|cMun|xMun|UF|CEP|cPais|xPais|fone|",
    "F": "F|xLgr|nro|xCpl|xBairro|cMun|xMun|UF|CEP|cPais|xPais|fone|email|IE|",
    "F02": "F02|CNPJ|",
    "F02A": "F02a|CPF|",
    "F02B": "F02b|xNome|",
    "G": "G|xLgr|nro|xCpl|xBairro|cMun|xMun|UF|CEP|cPais|xPais|fone|email|IE|",
    "G02": "G02|CNPJ|",
    "G02A": "G02a|CPF|",
    "G02B": "G02b|xNome|",
    "GA": "GA|",
    "GA02": "GA02|CNPJ|",
    "GA03": "GA03|CPF|",
    "H": "H|item|infAdProd|",
    "I":
        "I|cProd|cEAN|xProd|NCM|cBenef|EXTIPI|CFOP|uCom|qCom|vUnCom|vProd|cEANTrib|uTrib|qTrib|vUnTrib|vFrete|vSeg|vDesc|vOutro|indTot|xPed|nItemPed|nFCI|",
    "I05A": "I05A|NVE|",
    "I05C": "I05C|CEST|indEscala|CNPJFab|",
    "I18":
        "I18|nDI|dDI|xLocDesemb|UFDesemb|dDesemb|tpViaTransp|vAFRMM|tpIntermedio|CNPJ|UFTerceiro|cExportador|",
    "I25": "I25|nAdicao|nSeqAdic|cFabricante|vDescDI|nDraw|",
    "I50": "I50|nDraw|",
    "I52": "I52|nRE|chNFe|qExport|",
    "I80": "I80|nLote|qLote|dFab|dVal|cAgreg|",
    "JA":
        "JA|tpOp|chassi|cCor|xCor|pot|cilin|pesoL|pesoB|nSerie|tpComb|nMotor|CMT|dist|anoMod|anoFab|tpPint|tpVeic|espVeic|VIN|condVeic|cMod|cCorDENATRAN|lota|tpRest|",
    "K": "K|cProdANVISA|vPMC|xMotivoIsencao|",
    "L": "L|tpArma|nSerie|nCano|descr|",
    "LA": "LA|cProdANP|descANP|pGLP|pGNn|pGNi|vPart|CODIF|qTemp|UFCons|",
    "LA07": "LA07|qBCProd|vAliqProd|vCIDE|",
    "LA11": "LA11|nBico|nBomba|nTanque|vEncIni|vEncFin|",
    "LB": "LB|nRECOPI|",
    "M": "M|vTotTrib|",
    "N": "N|",
    "N02": "N02|orig|CST|modBC|vBC|pICMS|vICMS|pFCP|vFCP|",
    "N03":
        "N03|orig|CST|modBC|vBC|pICMS|vICMS|vBCFCP|pFCP|vFCP|modBCST|pMVAST|pRedBCST|vBCST|pICMSST|vICMSST|vBCFCPST|pFCPST|vFCPST|",
    "N04":
        "N04|orig|CST|modBC|pRedBC|vBC|pICMS|vICMS|vBCFCP|pFCP|vFCP|vICMSDeson|motDesICMS|",
    "N05":
        "N05|orig|CST|modBCST|pMVAST|pRedBCST|vBCST|pICMSST|vICMSST|vBCFCPST|pFCPST|vFCPST|vICMSDeson|motDesICMS|",
    "N06": "N06|orig|CST|vICMSDeson|motDesICMS|",
    "N07":
        "N07|orig|CST|modBC|pRedBC|vBC|pICMS|vICMSOp|pDif|vICMSDif|vICMS|vBCFCP|pFCP|vFCP|",
    "N08":
        "N08|orig|CST|vBCSTRet|pST|vICMSSTRet|vBCFCPSTRet|pFCPSTRet|vFCPSTRet|pRedBCEfet|vBCEfet|pICMSEfet|vICMSEfet|vICMSSubstituto|",
    "N09":
        "N09|orig|CST|modBC|pRedBC|vBC|pICMS|vICMS|vBCFCP|pFCP|vFCP|modBCST|pMVAST|pRedBCST|vBCST|pICMSST|vICMSST|vBCFCPST|pFCPST|vFCPST|vICMSDeson|motDesICMS|",
    "N10":
        "N10|orig|CST|modBC|vBC|pRedBC|pICMS|vICMS|vBCFCP|pFCP|vFCP|modBCST|pMVAST|pRedBCST|vBCST|pICMSST|vICMSST|vBCFCPST|pFCPST|vFCPST|vICMSDeson|motDesICMS|",
    "N10A":
        "N10a|orig|CST|modBC|vBC|pRedBC|pICMS|vICMS|modBCST|pMVAST|pRedBCST|vBCST|pICMSST|vICMSST|pBCOp|UFST|",
    "N10B":
        "N10b|orig|CST|vBCSTRet|vICMSSTRet|vBCSTDest|vICMSSTDest|vBCFCPSTRet|pFCPSTRet|vFCPSTRet|pST|vICMSSubstituto|pRedBCEfet|vBCEfet|pICMSEfet|vICMSEfet|",
    "N10C": "N10c|orig|CSOSN|pCredSN|vCredICMSSN|",
    "N10D": "N10d|orig|CSOSN|",
    "N10E":
        "N10e|orig|CSOSN|modBCST|pMVAST|pRedBCST|vBCST|pICMSST|vICMSST|vBCFCPST|pFCPST|vFCPST|pCredSN|vCredICMSSN|",
    "N10F":
        "N10f|orig|CSOSN|modBCST|pMVAST|pRedBCST|vBCST|pICMSST|vICMSST|vBCFCPST|pFCPST|vFCPST|",
    "N10G":
        "N10g|orig|CSOSN|vBCSTRet|pST|vICMSSTRet|vBCFCPSTRet|pFCPSTRet|vFCPSTRet|pRedBCEfet|vBCEfet|pICMSEfet|vICMSEfet|vICMSSubstituto|",
    "N10H":
        "N10h|orig|CSOSN|modBC|vBC|pRedBC|pICMS|vICMS|modBCST|pMVAST|pRedBCST|vBCST|pICMSST|vICMSST|vBCFCPST|pFCPST|vFCPST|pCredSN|vCredICMSSN|",
    "NA":
        "NA|vBCUFDest|vBCFCPUFDest|pFCPUFDest|pICMSUFDest|pICMSInter|pICMSInterPart|vFCPUFDest|vICMSUFDest|vICMSUFRemet|",
    "O": "O|CNPJProd|cSelo|qSelo|cEnq|",
    "O07": "O07|CST|vIPI|",
    "O08": "O08|CST|",
    "O10": "O10|vBC|pIPI|",
    "O11": "O11|qUnid|vUnid|",
    "P": "P|vBC|vDespAdu|vII|vIOF|",
    "Q": "Q|",
    "Q02": "Q02|CST|vBC|pPIS|vPIS|",
    "Q03": "Q03|CST|qBCProd|vAliqProd|vPIS|",
    "Q04": "Q04|CST|",
    "Q05": "Q05|CST|vPIS|",
    "Q07": "Q07|vBC|pPIS|",
    "Q10": "Q10|qBCProd|vAliqProd|",
    "R": "R|vPIS|",
    "R02": "R02|vBC|pPIS|",
    "R04": "R04|qBCProd|vAliqProd|vPIS|",
    "S": "S|",
    "S02": "S02|CST|vBC|pCOFINS|vCOFINS|",
    "S03": "S03|CST|qBCProd|vAliqProd|vCOFINS|",
    "S04": "S04|CST|",
    "S05": "S05|CST|vCOFINS|",
    "S07": "S07|vBC|pCOFINS|",
    "S09": "S09|qBCProd|vAliqProd|",
    "T": "T|vCOFINS|",
    "T02": "T02|vBC|pCOFINS|",
    "T04": "T04|qBCProd|vAliqProd|",
    "U":
        "U|vBC|vAliq|vISSQN|cMunFG|cListServ|vDeducao|vOutro|vDescIncond|vDescCond|vISSRet|indISS|cServico|cMun|cPais|nProcesso|indIncentivo|",
    "UA": "UA|pDevol|vIPIDevol|",
    "W": "W|",
    "W02":
        "W02|vBC|vICMS|vICMSDeson|vFCP|vBCST|vST|vFCPST|vFCPSTRet|vProd|vFrete|vSeg|vDesc|vII|vIPI|vIPIDevol|vPIS|vCOFINS|vOutro|vNF|vTotTrib|vFCPUFDest|vICMSUFDest|vICMSUFRemet|",
    "W17":
        "W17|vServ|vBC|vISS|vPIS|vCOFINS|dCompet|vDeducao|vOutro|vDescIncond|vDescCond|vISSRet|cRegTrib|",
    "W23": "W23|vRetPIS|vRetCOFINS|vRetCSLL|vBCIRRF|vIRRF|vBCRetPrev|vRetPrev|",
    "X": "X|modFrete|",
    "X03": "X03|xNome|IE|xEnder|xMun|UF|",
    "X04": "X04|CNPJ|",
    "X05": "X05|CPF|",
    "X11": "X11|vServ|vBCRet|pICMSRet|vICMSRet|CFOP|cMunFG|",
    "X18": "X18|placa|UF|RNTC|",
    "X22": "X22|placa|UF|RNTC|",
    "X25A": "X25a|vagao|",
    "X25B": "X25b|balsa|",
    "X26": "X26|qVol|esp|marca|nVol|pesoL|pesoB|",
    "X33": "X33|nLacre|",
    "Y": "Y|vTroco|",
    "Y02": "Y02|nFat|vOrig|vDesc|vLiq|",
    "Y07": "Y07|nDup|dVenc|vDup|",
    "YA": "YA|indPag|tPag|vPag|CNPJ|tBand|cAut|tpIntegra|xPag|",
    "YB": "YB|CNPJ|idCadIntTran|",
    "Z": "Z|infAdFisco|infCpl|",
    "Z04": "Z04|xCampo|xTexto|",
    "Z07": "Z07|xCampo|xTexto|",
    "Z10": "Z10|nProc|indProc|",
    "ZA": "ZA|UFSaidaPais|xLocExporta|xLocDespacho|",
    "ZB": "ZB|xNEmp|xPed|xCont|",
    "ZC": "ZC|safra|ref|qTotMes|qTotAnt|qTotGer|vFor|vTotDed|vLiqFor|",
    "ZC04": "ZC04|dia|qtde|",
    "ZC10": "ZC10|xDed|vDed|",
    "ZD": "ZD|CNPJ|xContato|email|fone|CSRT|idCSRT|",
    "ZX01": "ZX01|qrcode|urlChave|",
  };
}

/// Resultado da validação estrutural de um TXT fiscal.
class NfeTxtValidationResult {
  /// Cria um resultado imutável.
  NfeTxtValidationResult(Iterable<String> errors)
    : errors = List.unmodifiable(errors);

  /// Erros encontrados; lista vazia indica validade estrutural.
  final List<String> errors;

  /// Indica se o TXT foi aceito.
  bool get isValid => errors.isEmpty;
}

/// Validador compatível com NFePHP/NFe/Common/ValidTXT.
///
/// A classe valida a estrutura dos registros, quantidade de campos,
/// terminadores, marcadores e caracteres proibidos. Ela não converte o TXT em
/// XML: essa conversão depende do parser histórico de cada layout e deve ser
/// feita por uma camada de aplicação ou por um conversor específico.
class NfeTxtValidator {
  /// Cria um validador para [layout].
  const NfeTxtValidator({required this.layout});

  /// Layout usado para contar os campos de cada marcador.
  final NfeTxtLayout layout;

  /// Valida [txt] e retorna todos os erros encontrados.
  NfeTxtValidationResult validate(String txt) {
    final normalized = txt.replaceAll('\r', '').replaceAll('\t', '').trim();
    if (normalized.isEmpty) {
      return NfeTxtValidationResult(const ['ERRO: O TXT não pode ser vazio.']);
    }
    final errors = <String>[];
    var itemNumber = 0;
    for (final row in normalized.split('\n')) {
      final fields = row.split('|');
      if (fields.isEmpty) continue;
      final reference = fields.first.toUpperCase();
      if (reference.isEmpty || reference == 'NOTAFISCAL') continue;
      if (reference == 'A') itemNumber = 0;
      if (reference == 'I') itemNumber++;
      if (!row.endsWith('|')) {
        errors.add(
          'ERRO: ($itemNumber) Todas as linhas devem terminar com \'pipe\'. [$row]',
        );
        continue;
      }
      final expected = layout.structure[reference];
      if (expected == null) {
        errors.add(
          'ERRO: ($itemNumber) Essa referência não está definida. [$row]',
        );
        continue;
      }
      final expectedCount = expected.split('|').length - 1;
      final actualCount = fields.length - 1;
      final acceptedCounts = switch (reference) {
        // NFePHP v5.0.100 does not include indIntermed in B; newer local
        // layouts insert it after indPres.
        'B' => {22, 23, 24},
        // xPag was added after tpIntegra and remains optional in old files.
        'YA' => {8, 9},
        _ => {expectedCount},
      };
      if (!acceptedCounts.contains(actualCount)) {
        errors.add(
          'ERRO: ($itemNumber) O número de parâmetros na linha está errado '
          '(esperado #$expectedCount) -> (encontrado #$actualCount). [$row]',
        );
        continue;
      }
      for (final field in fields) {
        if (field.isEmpty) continue;
        if (field.trim().isEmpty) {
          errors.add(
            'ERRO: ($itemNumber) Existem apenas espaços no campo dos dados. [$row]',
          );
          continue;
        }
        if (field.contains('<') ||
            field.contains('>') ||
            field.contains('"') ||
            field.contains("'")) {
          errors.add(
            'ERRO: ($itemNumber) Existem caracteres especiais não permitidos '
            'na entidade [$row]',
          );
          continue;
        }
        if (!_isValidUnicode(field)) {
          errors.add(
            'ERRO: ($itemNumber) Existem caracteres não UTF-8, não permitidos, '
            'no campo [$field]',
          );
        }
      }
    }
    return NfeTxtValidationResult(errors);
  }

  /// Valida [txt] e lança uma exceção no primeiro conjunto de erros.
  void assertValid(String txt) {
    final result = validate(txt);
    if (!result.isValid) {
      throw FiscalValidationException(
        result.errors.join('\n'),
        code: 'INVALID_NFE_TXT',
      );
    }
  }

  static bool _isValidUnicode(String value) {
    try {
      utf8.encode(value);
      for (final unit in value.codeUnits) {
        if (unit >= 0xD800 && unit <= 0xDFFF) return false;
      }
      return true;
    } on FormatException {
      return false;
    }
  }
}
