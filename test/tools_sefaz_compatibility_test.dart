import 'dart:convert';
import 'dart:io';

import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';
import 'package:test/test.dart';

class _Transport implements SefazTransport {
  SefazRequest? request;

  @override
  Future<SefazResponse> post(SefazRequest request) async {
    this.request = request;
    return const SefazResponse(statusCode: 200, body: '<retorno/>');
  }
}

void main() {
  test(
    'sefazValidate exige e usa verificador criptográfico configurado',
    () async {
      final encoded = File(
        'test/fixtures/synthetic_a1.p12.b64',
      ).readAsStringSync().replaceAll(RegExp(r'\s'), '');
      final identity = PfxIdentity.fromPfx(
        bytes: base64Decode(encoded),
        password: 'test-password',
      );
      final signer = XmlSignatureService.fromPfx(identity);
      final verifier = RsaSha1SignatureVerifier(
        identity.certificate.rsaPublicKey,
      );
      final signed = await signer.sign(
        File('test/fixtures/nfe_minimal.xml').readAsStringSync(),
      );
      final transport = _Transport();
      final tools = Tools(
        sefaz: SefazClient(
          endpoint: Uri.parse('https://sefaz.example.test/nfe'),
          transport: transport,
        ),
        signatureVerifier: (xml) => signer.verifySignature(xml, verifier),
      );

      await tools.sefazValidate(signed);
      expect(transport.request!.body, contains('<consSitNFe'));
    },
  );

  test(
    'fachada Tools encaminha métodos SEFAZ compatíveis com NFePHP',
    () async {
      final transport = _Transport();
      final tools = Tools(
        sefaz: SefazClient(
          endpoint: Uri.parse('https://sefaz.example.test/nfe'),
          transport: transport,
        ),
      );
      final key = AccessKey.fromComponents(
        cUf: '11',
        issueDate: DateTime.utc(2026, 1, 1),
        cnpj: '04252011000110',
        model: 55,
        series: 1,
        number: 1,
        tpEmis: 1,
        cNf: '12345678',
      ).value;
      final epecKey = AccessKey.fromComponents(
        cUf: '11',
        issueDate: DateTime.utc(2026, 1, 1),
        cnpj: '04252011000110',
        model: 55,
        series: 1,
        number: 1,
        tpEmis: 4,
        cNf: '12345678',
      ).value;
      final replacementKey = AccessKey.fromComponents(
        cUf: '11',
        issueDate: DateTime.utc(2026, 1, 1),
        cnpj: '04252011000110',
        model: 65,
        series: 1,
        number: 2,
        tpEmis: 1,
        cNf: '12345678',
      ).value;

      await tools.sefazConsultaChave(key, environment: 2);
      expect(transport.request!.body, contains('<consSitNFe'));

      await tools.sefazCadastro('RO', environment: 2, cnpj: '04252011000110');
      expect(transport.request!.body, contains('<consCad'));

      await tools.sefazConsultaGTIN('7894900011517');
      expect(transport.request!.body, contains('<consGTIN'));

      await tools.sefazCsc(
        operationCode: 1,
        environment: 2,
        model: 65,
        rootCnpj: '04252011000110',
      );
      expect(transport.request!.body, contains('<admCscNFCe'));

      final eventBuilder = NfeEventBuilder();
      final firstEvent = eventBuilder.manifestacao(
        accessKey: key,
        cOrgao: 11,
        environment: 2,
        participantTaxId: '04252011000110',
        eventType: '210210',
      );
      final secondEvent = eventBuilder.manifestacao(
        accessKey: key,
        cOrgao: 11,
        environment: 2,
        participantTaxId: '04252011000110',
        eventType: '210220',
      );
      await tools.sefazEventoLote([firstEvent, secondEvent]);
      expect(transport.request!.body, contains('<envEvento'));
      expect(
        RegExp(r'<evento[ >]').allMatches(transport.request!.body).length,
        2,
      );

      await tools.sefazManifestaLote([
        ManifestationRequest(
          accessKey: key,
          cOrgao: 11,
          environment: 2,
          participantTaxId: '04252011000110',
          eventType: '210210',
        ),
      ]);
      expect(transport.request!.body, contains('<tpEvento>210210</tpEvento>'));

      expect(
        () => tools.sefazValidate('<NFe/>'),
        throwsA(isA<FiscalValidationException>()),
      );

      await tools.sefazEnviaLote(
        const ['<NFe><infNFe/></NFe>'],
        lotId: '10',
        synchronous: 1,
      );
      expect(transport.request!.body, contains('<idLote>10</idLote>'));

      await tools.sefazCancela(
        accessKey: key,
        cOrgao: 11,
        environment: 2,
        issuerCnpj: '04252011000110',
        protocol: '123456789012345',
        justification: 'Cancelamento solicitado pelo contribuinte',
      );
      expect(transport.request!.body, contains('<tpEvento>110111</tpEvento>'));

      await tools.sefazCancelaPorSubstituicao(
        accessKey: key,
        cOrgao: 11,
        environment: 2,
        issuerCnpj: '04252011000110',
        protocol: '123456789012345',
        justification: 'Cancelamento substituído pelo contribuinte',
        referenceAccessKey: replacementKey,
        applicationVersion: 'FFLIB-0.1.0',
      );
      expect(transport.request!.body, contains('<tpEvento>110112</tpEvento>'));
      expect(
        transport.request!.body,
        contains('<chNFeRef>$replacementKey</chNFeRef>'),
      );
      expect(
        transport.request!.body,
        contains('<verAplic>FFLIB-0.1.0</verAplic>'),
      );

      await tools.sefazManifesta(
        accessKey: key,
        cOrgao: 11,
        environment: 2,
        participantTaxId: '04252011000110',
        eventType: '210210',
      );
      expect(transport.request!.body, contains('<tpEvento>210210</tpEvento>'));

      await tools.sefazCCe(
        accessKey: key,
        cOrgao: 11,
        environment: 2,
        issuerCnpj: '04252011000110',
        correction: 'Correção de informação cadastral do documento',
      );
      expect(transport.request!.body, contains('<tpEvento>110110</tpEvento>'));

      await tools.sefazEPP(
        accessKey: key,
        cOrgao: 11,
        environment: 2,
        issuerCnpj: '04252011000110',
        protocol: '123456789012345',
        items: const [ReturnExtensionItem(number: 1, quantity: 2)],
      );
      expect(transport.request!.body, contains('<tpEvento>111500</tpEvento>'));

      await tools.sefazECPP(
        accessKey: key,
        cOrgao: 11,
        environment: 2,
        issuerCnpj: '04252011000110',
        protocol: '123456789012345',
      );
      expect(transport.request!.body, contains('<tpEvento>111502</tpEvento>'));

      await tools.sefazEPEC(
        accessKey: epecKey,
        cOrgao: 11,
        environment: 2,
        authorTaxId: '04252011000110',
        issuerIe: '123456789',
        applicationVersion: '1.0.0',
        issueDate: DateTime.utc(2026, 1, 1),
        total: 10,
        icms: 1,
      );
      expect(transport.request!.body, contains('<tpEvento>110140</tpEvento>'));

      await tools.sefazComprovanteEntrega(
        accessKey: key,
        cOrgao: 11,
        environment: 2,
        issuerCnpj: '04252011000110',
        applicationVersion: '1.0.0',
        deliveryDate: DateTime.utc(2026, 1, 2),
        documentNumber: 'RG123456',
        recipientName: 'Pessoa Recebedora',
        hashComprovante: 'AAAAAAAAAAAAAAAAAAAAAAAAAAA=',
      );
      expect(transport.request!.body, contains('<tpEvento>110130</tpEvento>'));

      await tools.sefazAtorInteressado(
        accessKey: key,
        cOrgao: 11,
        environment: 2,
        authorTaxId: '04252011000110',
        authorStateCode: 11,
        authorType: '3',
        applicationVersion: 'FFLIB-0.1.0',
        authorizedTaxId: '04252011000110',
        authorizationType: '1',
      );
      expect(transport.request!.body, contains('<tpEvento>110150</tpEvento>'));
    },
  );

  test('fachada Tools rejeita lote síncrono com múltiplos documentos', () {
    final tools = Tools(
      sefaz: SefazClient(
        endpoint: Uri.parse('https://sefaz.example.test/nfe'),
        transport: _Transport(),
      ),
    );

    expect(
      () => tools.sefazEnviaLote(const ['<NFe/>', '<NFe/>'], synchronous: 1),
      throwsA(isA<FiscalValidationException>()),
    );
  });

  test(
    'fachada Tools cobre consultas e downloads da superfície NFePHP',
    () async {
      final transport = _Transport();
      final tools = Tools(
        sefaz: SefazClient(
          endpoint: Uri.parse('https://sefaz.example.test/nfe'),
          transport: transport,
        ),
      );
      final key = AccessKey.fromComponents(
        cUf: '11',
        issueDate: DateTime.utc(2026, 1, 1),
        cnpj: '04252011000110',
        model: 55,
        series: 1,
        number: 1,
        tpEmis: 1,
        cNf: '12345678',
      ).value;

      await tools.sefazStatus(uf: '11', environment: 2);
      expect(transport.request!.body, contains('<consStatServ'));

      await tools.sefazConsultaRecibo('123456789012345', environment: 2);
      expect(transport.request!.body, contains('<consReciNFe'));

      await tools.sefazDistDFe(
        cUfAutor: '11',
        environment: 2,
        actorTaxId: '04252011000110',
        lastNsu: '000000000000001',
      );
      expect(transport.request!.body, contains('<distDFeInt'));

      await tools.sefazDownload(
        environment: 2,
        recipientCnpj: '04252011000110',
        accessKeys: [key],
      );
      expect(transport.request!.body, contains('<downloadNFe'));

      await tools.sefazConsultaCadastro(
        uf: 'RO',
        environment: 2,
        cnpj: '04252011000110',
      );
      expect(transport.request!.body, contains('<consCad'));

      await tools.sefazEpec(
        accessKey: AccessKey.fromComponents(
          cUf: '11',
          issueDate: DateTime.utc(2026, 1, 1),
          cnpj: '04252011000110',
          model: 55,
          series: 1,
          number: 1,
          tpEmis: 4,
          cNf: '12345678',
        ).value,
        cOrgao: 11,
        environment: 2,
        authorTaxId: '04252011000110',
        issuerIe: '123456789',
        applicationVersion: '1.0.0',
        issueDate: DateTime.utc(2026, 1, 1),
        total: 10,
        icms: 1,
      );
      expect(transport.request!.body, contains('<tpEvento>110140</tpEvento>'));
    },
  );

  test(
    'fachada Tools assina eventos quando recebe identidade configurada',
    () async {
      final transport = _Transport();
      final encoded = File(
        'test/fixtures/synthetic_a1.p12.b64',
      ).readAsStringSync().replaceAll(RegExp(r'\s'), '');
      final identity = PfxIdentity.fromPfx(
        bytes: base64Decode(encoded),
        password: 'test-password',
      );
      final key = AccessKey.fromComponents(
        cUf: '11',
        issueDate: DateTime.utc(2026, 1, 1),
        cnpj: '04252011000110',
        model: 55,
        series: 1,
        number: 1,
        tpEmis: 1,
        cNf: '12345678',
      ).value;
      final tools = Tools(
        sefaz: SefazClient(
          endpoint: Uri.parse('https://sefaz.example.test/evento'),
          transport: transport,
        ),
        signer: XmlSignatureService.fromPfx(identity),
      );

      await tools.sefazCCe(
        accessKey: key,
        cOrgao: 11,
        environment: 2,
        issuerCnpj: '04252011000110',
        correction: 'Correção assinada pela fachada de integração',
      );

      expect(transport.request!.body, contains('<Signature'));
      expect(transport.request!.body, contains('<tpEvento>110110</tpEvento>'));

      await tools.sefazInutiliza(
        cUf: '11',
        environment: 2,
        issuerCnpj: '04252011000110',
        model: 55,
        series: 1,
        startNumber: 10,
        endNumber: 12,
        reason: 'Numeração não utilizada por falha operacional',
      );
      expect(transport.request!.body, contains('<infInut'));
      expect(transport.request!.body, contains('<Signature'));
    },
  );
}
