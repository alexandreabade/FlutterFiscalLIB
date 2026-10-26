import '../crypto/certificate.dart';
import '../crypto/xml_digest.dart';
import '../exceptions/fiscal_exception.dart';
import '../sefaz/sefaz_client.dart';
import '../sefaz/sefaz_endpoint_catalog.dart';
import '../tools.dart';
import '../validation/nfce_qr_code.dart';
import 'party.dart';

/// Cadastro fiscal do emitente usado para montar documentos e configurar a
/// comunicação com a SEFAZ.
///
/// A UF é informada como sigla (`RO`, `SP`, ...). Os códigos IBGE, endpoints
/// SOAP e URL pública do QR Code são resolvidos pelo catálogo incorporado.
class FiscalCompanyRegistration {
  /// Cria o cadastro fiscal da empresa.
  FiscalCompanyRegistration({
    required this.name,
    required this.cnpj,
    required this.ie,
    required String uf,
    this.fantasyName,
    this.address,
    this.addressNumber,
    this.addressComplement,
    this.neighborhood,
    this.cityCode,
    this.city,
    this.zipCode,
    this.phone,
    this.email,
    this.crt,
    this.ieSubstitute,
    this.municipalRegistration,
    this.cnae,
    this.suframa,
  }) : uf = uf.trim().toUpperCase() {
    if (!Tools.isValidCnpj(cnpj)) {
      throw const FiscalValidationException(
        'O CNPJ da empresa é inválido.',
        code: 'INVALID_COMPANY_CNPJ',
      );
    }
    if (ie.trim().isEmpty) {
      throw const FiscalValidationException(
        'A inscrição estadual da empresa é obrigatória.',
        code: 'INVALID_COMPANY_IE',
      );
    }
    SefazEndpointCatalog.ufCode(this.uf);
  }

  /// Razão social.
  final String name;

  /// CNPJ com ou sem pontuação.
  final String cnpj;

  /// Inscrição estadual.
  final String ie;

  /// Sigla da UF do estabelecimento.
  final String uf;

  /// Nome fantasia.
  final String? fantasyName;

  /// Endereço do estabelecimento.
  final String? address;

  /// Número do endereço.
  final String? addressNumber;

  /// Complemento do endereço.
  final String? addressComplement;

  /// Bairro.
  final String? neighborhood;

  /// Código IBGE do município.
  final String? cityCode;

  /// Município.
  final String? city;

  /// CEP.
  final String? zipCode;

  /// Telefone.
  final String? phone;

  /// E-mail.
  final String? email;

  /// CRT do emitente.
  final String? crt;

  /// IE de substituto tributário.
  final String? ieSubstitute;

  /// Inscrição municipal.
  final String? municipalRegistration;

  /// CNAE.
  final String? cnae;

  /// SUFRAMA.
  final String? suframa;

  /// Código IBGE de dois dígitos da UF.
  String get cUf => SefazEndpointCatalog.ufCode(uf);

  /// Converte o cadastro para o participante emitente do XML.
  Party get party => Party(
    name: name,
    cnpj: cnpj,
    ie: ie,
    fantasyName: fantasyName,
    address: address,
    addressNumber: addressNumber,
    addressComplement: addressComplement,
    neighborhood: neighborhood,
    cityCode: cityCode,
    city: city,
    state: uf,
    zipCode: zipCode,
    phone: phone,
    email: email,
    crt: crt,
    ieSubstitute: ieSubstitute,
    municipalRegistration: municipalRegistration,
    cnae: cnae,
    suframa: suframa,
  );

  /// Cria a configuração SEFAZ com todos os endpoints catalogados.
  SefazClientConfig sefazConfig({
    required int model,
    required int environment,
    PfxIdentity? certificate,
    Duration timeout = const Duration(seconds: 30),
    SefazRetryPolicy? retryPolicy,
    List<List<int>> trustedCertificates = const [],
  }) => SefazEndpointCatalog.clientConfig(
    uf: uf,
    model: model,
    environment: environment,
    certificate: certificate,
    timeout: timeout,
    retryPolicy: retryPolicy,
    trustedCertificates: trustedCertificates,
  );

  /// URL de consulta pública da NFC-e para o ambiente informado.
  Uri nfceQrCodeUrl({required int environment}) =>
      SefazEndpointCatalog.qrCodeUrl(uf: uf, environment: environment);

  /// Gera automaticamente o QR Code online conforme a versão publicada pela
  /// UF: QR Code 2.00 com CSC ou 3.00 sem CSC.
  NfceQrCodePayload nfceOnlineQrCode({
    required String accessKey,
    required int environment,
    int? cscId,
    String? csc,
  }) {
    final profile = SefazEndpointCatalog.resolve(
      uf: uf,
      model: 65,
      environment: environment,
    );
    final baseUrl = profile.qrCodeUrl.toString();
    if (profile.service('NfeConsultaQR')!.version.startsWith('3')) {
      return NfceQrCode.onlineV3(
        accessKey: accessKey,
        environment: environment,
        baseUrl: baseUrl,
      );
    }
    if (cscId == null || csc == null) {
      throw const FiscalValidationException(
        'O QR Code 2.00 exige idCSC e CSC.',
        code: 'CSC_REQUIRED_FOR_QR_CODE_V2',
      );
    }
    return NfceQrCode.online(
      accessKey: accessKey,
      environment: environment,
      cscId: cscId,
      csc: csc,
      baseUrl: baseUrl,
    );
  }

  /// Gera QR Code offline 2.00 usando a URL catalogada da UF.
  NfceQrCodePayload nfceOfflineQrCode({
    required String accessKey,
    required int environment,
    required DateTime issueDate,
    required num total,
    required String digestValue,
    required int cscId,
    required String csc,
  }) => NfceQrCode.offline(
    accessKey: accessKey,
    environment: environment,
    issueDate: issueDate,
    total: total,
    digestValue: digestValue,
    cscId: cscId,
    csc: csc,
    baseUrl: nfceQrCodeUrl(environment: environment).toString(),
  );

  /// Gera QR Code offline 3.00 usando a URL catalogada da UF.
  Future<NfceQrCodePayload> nfceOfflineQrCodeV3({
    required String accessKey,
    required int environment,
    required DateTime issueDate,
    required num total,
    String? recipientTaxId,
    int? recipientType,
    required XmlSignatureProvider signatureProvider,
  }) => NfceQrCode.offlineV3(
    accessKey: accessKey,
    environment: environment,
    issueDate: issueDate,
    total: total,
    recipientTaxId: recipientTaxId,
    recipientType: recipientType,
    signatureProvider: signatureProvider,
    baseUrl: nfceQrCodeUrl(environment: environment).toString(),
  );
}
