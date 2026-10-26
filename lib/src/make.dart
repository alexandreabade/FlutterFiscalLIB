import 'package:xml/xml.dart';

import 'models/nfe_document.dart';
import 'models/nfe_item.dart';
import 'models/additional_info.dart';
import 'models/payment.dart';
import 'models/party.dart';
import 'models/nfe_complements.dart';
import 'models/nfce_supplement.dart';
import 'models/product_details.dart';
import 'models/trade.dart';
import 'models/taxes.dart';
import 'models/transport.dart';
import 'exceptions/fiscal_exception.dart';
import 'xml/nfe_xml_builder.dart';

/// Fachada compatível com o papel da classe `Make` do NFePHP.
///
/// A fachada recebe um documento tipado e delega a geração ao construtor XML.
/// Assinatura digital, grupos tributários e validação XSD são etapas separadas
/// e não são simuladas por esta classe.
class Make {
  /// Cria uma fachada com um construtor XML configurável.
  Make({NfeXmlBuilder? builder}) : _builder = builder ?? NfeXmlBuilder();

  final NfeXmlBuilder _builder;
  bool _onlyAscii = false;
  List<String> _errors = const [];

  /// Configura a conversão de caracteres acentuados para ASCII, equivalente
  /// a `Make::setOnlyAscii()`.
  void setOnlyAscii([bool option = false]) => _onlyAscii = option;

  /// Retorna os erros da última montagem, equivalente a `Make::getErrors()`.
  List<String> getErrors() => List.unmodifiable(_errors);

  String _build(NfeDocument document) {
    try {
      final xml = _builder.build(document);
      _errors = const [];
      return _onlyAscii ? _toAscii(xml) : xml;
    } on FiscalException catch (error) {
      _errors = [error.message];
      rethrow;
    }
  }

  String _toAscii(String value) {
    const replacements = <String, String>{
      'á': 'a',
      'à': 'a',
      'ã': 'a',
      'â': 'a',
      'ä': 'a',
      'Á': 'A',
      'À': 'A',
      'Ã': 'A',
      'Â': 'A',
      'Ä': 'A',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'É': 'E',
      'È': 'E',
      'Ê': 'E',
      'Ë': 'E',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'Í': 'I',
      'Ì': 'I',
      'Î': 'I',
      'Ï': 'I',
      'ó': 'o',
      'ò': 'o',
      'õ': 'o',
      'ô': 'o',
      'ö': 'o',
      'Ó': 'O',
      'Ò': 'O',
      'Õ': 'O',
      'Ô': 'O',
      'Ö': 'O',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'Ú': 'U',
      'Ù': 'U',
      'Û': 'U',
      'Ü': 'U',
      'ç': 'c',
      'Ç': 'C',
      'ñ': 'n',
      'Ñ': 'N',
    };
    return value.runes
        .map(
          (rune) =>
              replacements[String.fromCharCodes([rune])] ??
              String.fromCharCodes([rune]),
        )
        .join();
  }

  /// Monta o XML estrutural do documento fiscal.
  String montaNFe(NfeDocument document) => _build(document);

  /// Alias tipado de `Make::monta()`; o documento é explícito porque a
  /// fachada Dart não mantém o estado mutável da implementação PHP.
  String monta(NfeDocument document) => _build(document);

  /// Alias tipado de `Make::getXML()`.
  String getXML(NfeDocument document) => _build(document);

  /// Retorna a chave do documento tipado, equivalente a `getChave()`.
  String getChave(NfeDocument document) => document.accessKey;

  /// Retorna o modelo do documento tipado, equivalente a `getModelo()`.
  int getModelo(NfeDocument document) => document.model;

  /// Nome em inglês para integração idiomática com Dart.
  String build(NfeDocument document) => _build(document);

  /// Monta o grupo `infNFe` de forma compatível com `taginfNFe()`.
  XmlElement taginfNFe(NfeDocument document) => _builder.taginfNFe(document);

  /// Monta o grupo `ide` de forma compatível com `tagide()`.
  XmlElement tagide(NfeDocument document) => _builder.tagide(document);

  /// Monta um detalhe completo (`det`) compatível com `tagdet()`.
  XmlElement tagdet(NfeItem item) => _builder.tagdet(item);

  /// Monta referência de pagamento antecipado compatível com
  /// `taggPagAntecipado()`.
  XmlElement taggPagAntecipado(String reference) =>
      _builder.taggPagAntecipado(reference);

  /// Monta compra governamental compatível com `taggCompraGov()`.
  XmlElement taggCompraGov(GovernmentPurchase purchase) =>
      _builder.taggCompraGov(purchase);

  /// Monta referência de documento anterior compatível com `tagrefDFeAnt()`.
  XmlElement tagrefDFeAnt(String reference) => _builder.tagrefDFeAnt(reference);

  /// Monta referência de NF-e compatível com `tagrefNFe()`.
  XmlElement tagrefNFe(ReferencedDocument reference) =>
      _builder.tagrefNFe(reference);

  /// Monta referência sigilosa compatível com `tagrefNFeSig()`.
  XmlElement tagrefNFeSig(ReferencedDocument reference) =>
      _builder.tagrefNFeSig(reference);

  /// Monta referência de CT-e compatível com `tagrefCTe()`.
  XmlElement tagrefCTe(ReferencedDocument reference) =>
      _builder.tagrefCTe(reference);

  /// Monta referência resumida compatível com `tagrefNF()`.
  XmlElement tagrefNF(ReferencedDocument reference) =>
      _builder.tagrefNF(reference);

  /// Monta referência de produtor rural compatível com `tagrefNFP()`.
  XmlElement tagrefNFP(ReferencedDocument reference) =>
      _builder.tagrefNFP(reference);

  /// Monta referência de ECF compatível com `tagrefECF()`.
  XmlElement tagrefECF(ReferencedDocument reference) =>
      _builder.tagrefECF(reference);

  /// Monta o grupo `emit` de forma compatível com `tagemit()`.
  XmlElement tagemit(Party issuer) => _builder.tagemit(issuer);

  /// Monta emissão avulsa compatível com `tagavulsa()`.
  XmlElement tagavulsa(AvulsaInfo avulsa) => _builder.tagavulsa(avulsa);

  /// Monta o grupo `dest` de forma compatível com `tagdest()`.
  XmlElement tagdest(Party recipient) => _builder.tagdest(recipient);

  /// Monta local de retirada compatível com `tagretirada()`.
  XmlElement tagretirada(NfeLocation location) =>
      _builder.tagretirada(location);

  /// Monta local de entrega compatível com `tagentrega()`.
  XmlElement tagentrega(NfeLocation location) => _builder.tagentrega(location);

  /// Monta rastreabilidade de lote compatível com `tagRastro()`.
  XmlElement tagRastro(ProductTraceability batch) => _builder.tagRastro(batch);

  /// Monta veículo novo compatível com `tagveicProd()`.
  XmlElement tagveicProd(NewVehicleInfo vehicle) =>
      _builder.tagveicProd(vehicle);

  /// Monta medicamento compatível com `tagmed()`.
  XmlElement tagmed(MedicationInfo medication) => _builder.tagmed(medication);

  /// Monta armamento compatível com `tagarma()`.
  XmlElement tagarma(WeaponInfo weapon) => _builder.tagarma(weapon);

  /// Monta combustível compatível com `tagcomb()`.
  XmlElement tagcomb(FuelInfo fuel) => _builder.tagcomb(fuel);

  /// Monta encerrante compatível com `tagencerrante()`.
  XmlElement tagencerrante(FuelGauge gauge) => _builder.tagencerrante(gauge);

  /// Monta o endereço do emitente de forma compatível com `tagenderEmit()`.
  XmlElement tagenderEmit(Party issuer) => _builder.tagenderEmit(issuer);

  /// Monta o endereço do destinatário de forma compatível com `tagenderDest()`.
  XmlElement tagenderDest(Party recipient) => _builder.tagenderDest(recipient);

  /// Monta NVE compatível com `tagNVE()`.
  XmlElement tagNVE(String value) => _builder.tagNVE(value);

  /// Monta CEST compatível com `tagCEST()`.
  XmlElement tagCEST(String value) => _builder.tagCEST(value);

  /// Monta informação adicional do produto compatível com `taginfAdProd()`.
  XmlElement taginfAdProd(String value) => _builder.taginfAdProd(value);

  /// Monta FCI compatível com `tagnFCI()`.
  XmlElement tagnFCI(String value) => _builder.tagnFCI(value);

  /// Monta registro RECOPI compatível com `tagRECOPI()`.
  XmlElement tagRECOPI(NfeItem item) => _builder.tagRECOPI(item);

  /// Monta declaração de importação compatível com `tagDI()`.
  XmlElement tagDI(ImportDeclaration declaration) =>
      _builder.tagDI(declaration);

  /// Monta adição de importação compatível com `tagadi()`.
  XmlElement tagadi(ImportAddition addition) => _builder.tagadi(addition);

  /// Monta detalhe de exportação compatível com `tagdetExport()`.
  XmlElement tagdetExport(ExportDetail detail) => _builder.tagdetExport(detail);

  /// Monta exportação individual compatível com `tagdetExportInd()`.
  XmlElement tagdetExportInd(IndividualExport export) =>
      _builder.tagdetExportInd(export);

  /// Monta o grupo `prod` de forma compatível com `tagprod()`.
  XmlElement tagprod(NfeItem item) => _builder.tagprod(item);

  /// Monta o grupo `imposto` de forma compatível com `tagimposto()`.
  XmlElement tagimposto(NfeItem item) => _builder.tagimposto(item);

  /// Monta ICMS compatível com `tagICMS()`.
  XmlElement tagICMS(IcmsTax tax) => _builder.tagICMS(tax);

  /// Monta ICMS-ST compatível com `tagICMSST()`.
  XmlElement tagICMSST(IcmsStTax tax) => _builder.tagICMSST(tax);

  /// Monta partilha de ICMS compatível com `tagICMSPart()`.
  XmlElement tagICMSPart(IcmsPartTax tax) => _builder.tagICMSPart(tax);

  /// Monta partilha para consumidor final compatível com `tagICMSUFDest()`.
  XmlElement tagICMSUFDest(IcmsUfDestinationTax tax) =>
      _builder.tagICMSUFDest(tax);

  /// Monta ICMS do Simples Nacional compatível com `tagICMSSN()`.
  XmlElement tagICMSSN(IcmsSimplesTax tax) => _builder.tagICMSSN(tax);

  /// Monta ICMS monofásico tipado.
  XmlElement tagICMSMono(IcmsMonophaseTax tax) => _builder.tagICMSMono(tax);

  /// Monta IPI compatível com `tagIPI()`.
  XmlElement tagIPI(IpiTax tax) => _builder.tagIPI(tax);

  /// Monta imposto de importação compatível com `tagII()`.
  XmlElement tagII(ImportTax tax) => _builder.tagII(tax);

  /// Monta PIS compatível com `tagPIS()`.
  XmlElement tagPIS(PisTax tax) => _builder.tagPIS(tax);

  /// Monta PIS-ST compatível com `tagPISST()`.
  XmlElement tagPISST(PisStTax tax) => _builder.tagPISST(tax);

  /// Monta COFINS compatível com `tagCOFINS()`.
  XmlElement tagCOFINS(CofinsTax tax) => _builder.tagCOFINS(tax);

  /// Monta COFINS-ST compatível com `tagCOFINSST()`.
  XmlElement tagCOFINSST(CofinsStTax tax) => _builder.tagCOFINSST(tax);

  /// Monta ISSQN compatível com `tagISSQN()`.
  XmlElement tagISSQN(ServiceTax tax) => _builder.tagISSQN(tax);

  /// Monta IPI devolvido compatível com `tagimpostoDevol()`.
  XmlElement tagimpostoDevol(IpiDevolution devolution) =>
      _builder.tagimpostoDevol(devolution);

  /// Monta retenções federais compatíveis com `tagretTrib()`.
  XmlElement tagretTrib(TaxRetention retention) =>
      _builder.tagretTrib(retention);

  /// Monta o grupo `total` de forma compatível com `tagtotal()`.
  XmlElement tagtotal(NfeDocument document) => _builder.tagtotal(document);

  /// Monta totalizadores de ICMS compatíveis com `tagICMSTot()`.
  XmlElement tagICMSTot(NfeDocument document) => _builder.tagICMSTot(document);

  /// Monta totalizadores de ISSQN compatíveis com `tagISSQNTot()`.
  XmlElement tagISSQNTot(NfeDocument document) =>
      _builder.tagISSQNTot(document);

  /// Monta o grupo `pag` de forma compatível com `tagpag()`.
  XmlElement tagpag(NfeDocument document) => _builder.tagpag(document);

  /// Monta detalhe de pagamento compatível com `tagdetPag()`.
  XmlElement tagdetPag(Payment payment) => _builder.tagdetPag(payment);

  /// Monta o grupo `transp` de forma compatível com `tagtransp()`.
  XmlElement tagtransp(NfeDocument document) => _builder.tagtransp(document);

  /// Monta transportador compatível com `tagtransporta()`.
  XmlElement tagtransporta(TransportInfo transport) =>
      _builder.tagtransporta(transport);

  /// Monta retenção do transporte compatível com `tagretTransp()`.
  XmlElement tagretTransp(TransportTaxRetention retention) =>
      _builder.tagretTransp(retention);

  /// Monta lacre compatível com `taglacres()`.
  XmlElement taglacres(String seal) => _builder.taglacres(seal);

  /// Monta veículo de transporte compatível com `tagveicTransp()`.
  XmlElement tagveicTransp(TransportVehicle vehicle) =>
      _builder.tagveicTransp(vehicle);

  /// Monta reboque compatível com `tagreboque()`.
  XmlElement tagreboque(TransportVehicle vehicle) =>
      _builder.tagreboque(vehicle);

  /// Monta volume compatível com `tagvol()`.
  XmlElement tagvol(TransportVolume volume) => _builder.tagvol(volume);

  /// Monta vagão compatível com `tagvagao()`.
  XmlElement tagvagao(String identifier) => _builder.tagvagao(identifier);

  /// Monta balsa compatível com `tagbalsa()`.
  XmlElement tagbalsa(String identifier) => _builder.tagbalsa(identifier);

  /// Monta o grupo `cobr` de forma compatível com `tagcobr()`.
  XmlElement tagcobr(BillingInfo billing) => _builder.tagcobr(billing);

  /// Monta fatura compatível com `tagfat()`.
  XmlElement tagfat(BillingInfo billing) => _builder.tagfat(billing);

  /// Monta duplicata compatível com `tagdup()`.
  XmlElement tagdup(InvoiceInstallment installment) =>
      _builder.tagdup(installment);

  /// Monta o grupo `infAdic` de forma compatível com `taginfAdic()`.
  XmlElement taginfAdic(NfeDocument document) => _builder.taginfAdic(document);

  /// Monta observação do contribuinte compatível com `tagobsCont()`.
  XmlElement tagobsCont(AdditionalObservation observation) =>
      _builder.tagobsCont(observation);

  /// Monta observação fiscal compatível com `tagobsFisco()`.
  XmlElement tagobsFisco(AdditionalObservation observation) =>
      _builder.tagobsFisco(observation);

  /// Monta processo referenciado compatível com `tagprocRef()`.
  XmlElement tagprocRef(ReferencedProcess process) =>
      _builder.tagprocRef(process);

  /// Monta autorização XML compatível com `tagautXML()`.
  XmlElement tagautXML(AuthorizedXmlDownload authorization) =>
      _builder.tagautXML(authorization);

  /// Monta o grupo `infRespTec` de forma compatível com `taginfRespTec()`.
  XmlElement taginfRespTec(TechnicalResponsible responsible) =>
      _builder.taginfRespTec(responsible);

  /// Monta o intermediador da transação compatível com `taginfIntermed()`.
  XmlElement taginfIntermed(IntermediaryInfo intermediary) =>
      _builder.taginfIntermed(intermediary);

  /// Monta o grupo `exporta` de forma compatível com `tagexporta()`.
  XmlElement tagexporta(ExportInfo info) => _builder.tagexporta(info);

  /// Monta o grupo `compra` de forma compatível com `tagcompra()`.
  XmlElement tagcompra(PurchaseInfo info) => _builder.tagcompra(info);

  /// Monta o grupo `cana` de forma compatível com `tagcana()`.
  XmlElement tagcana(SugarcaneInfo info) => _builder.tagcana(info);

  /// Monta fornecimento diário de cana compatível com `tagforDia()`.
  XmlElement tagforDia(SugarcaneDailySupply supply) =>
      _builder.tagforDia(supply);

  /// Monta dedução de cana compatível com `tagdeduc()`.
  XmlElement tagdeduc(SugarcaneDeduction deduction) =>
      _builder.tagdeduc(deduction);

  /// Monta suplemento NFC-e compatível com `taginfNFeSupl()`.
  XmlElement taginfNFeSupl(NfceXmlSupplement supplement) =>
      _builder.taginfNFeSupl(supplement);
}
