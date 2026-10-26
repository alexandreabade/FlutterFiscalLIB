import '../common/fiscal_decimal.dart';

/// Adição de uma Declaração de Importação (`adi`).
class ImportAddition {
  /// Cria uma adição vinculada a uma [ImportDeclaration].
  const ImportAddition({
    required this.number,
    required this.sequence,
    required this.manufacturerCode,
    this.discount = 0,
    this.drawbackNumber,
  });

  /// Número da adição.
  final int number;

  /// Sequência do item dentro da adição.
  final int sequence;

  /// Código do fabricante estrangeiro.
  final String manufacturerCode;

  /// Desconto do item da adição (`vDescDI`).
  final double discount;

  /// Ato concessório de drawback (`nDraw`).
  final String? drawbackNumber;
}

/// Declaração de Importação (`DI`) de um item da NF-e.
class ImportDeclaration {
  /// Cria os dados de desembaraço aduaneiro.
  const ImportDeclaration({
    required this.number,
    required this.registrationDate,
    required this.customsLocation,
    required this.customsState,
    required this.clearanceDate,
    required this.transportMode,
    required this.intermediaryType,
    required this.exporterCode,
    this.afrmm,
    this.importerCnpj,
    this.thirdPartyState,
    this.additions = const [],
  });

  /// Número do documento de importação (`nDI`).
  final String number;

  /// Data de registro (`dDI`).
  final DateTime registrationDate;

  /// Local do desembaraço (`xLocDesemb`).
  final String customsLocation;

  /// UF do desembaraço (`UFDesemb`).
  final String customsState;

  /// Data do desembaraço (`dDesemb`).
  final DateTime clearanceDate;

  /// Via de transporte internacional (`tpViaTransp`).
  final int transportMode;

  /// Forma de intermediação (`tpIntermedio`).
  final int intermediaryType;

  /// Código do exportador (`cExportador`).
  final String exporterCode;

  /// Valor AFRMM (`vAFRMM`).
  final double? afrmm;

  /// CNPJ do adquirente/encomendante (`CNPJ`).
  final String? importerCnpj;

  /// UF do adquirente/encomendante (`UFTerceiro`).
  final String? thirdPartyState;

  /// Adições vinculadas à DI.
  final List<ImportAddition> additions;

  /// Valor do AFRMM em decimal exato.
  FiscalDecimal get afrmmDecimal => FiscalDecimal.fromNum(afrmm ?? 0);
}

/// Registro individual de exportação (`exportInd`).
class IndividualExport {
  /// Cria a referência da exportação efetivamente realizada.
  const IndividualExport({
    required this.registrationNumber,
    required this.receivedInvoiceKey,
    required this.exportedQuantity,
  });

  /// Número do Registro de Exportação (`nRE`).
  final String registrationNumber;

  /// Chave da NF-e recebida para exportação (`chNFe`).
  final String receivedInvoiceKey;

  /// Quantidade efetivamente exportada (`qExport`).
  final double exportedQuantity;
}

/// Informações de exportação vinculadas ao item (`detExport`).
class ExportDetail {
  /// Cria um detalhe de exportação.
  const ExportDetail({this.drawbackNumber, this.individualExports = const []});

  /// Ato concessório de drawback (`nDraw`).
  final String? drawbackNumber;

  /// Registros de exportação individual.
  final List<IndividualExport> individualExports;
}
