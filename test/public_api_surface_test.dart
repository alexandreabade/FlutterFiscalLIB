import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';
import 'package:test/test.dart';

void main() {
  test('entrypoint público exporta as superfícies fiscais principais', () {
    final exportedTypes = <Type>[
      AccessKey,
      FiscalDecimal,
      NfeDocument,
      NfeItem,
      Party,
      IcmsTax,
      IbsCbsTax,
      TransportInfo,
      NfeXmlBuilder,
      NfeEventBuilder,
      NfeEmissionService,
      Certificate,
      XmlSignatureService,
      SefazClient,
      SefazResponseParser,
      NfceOfflineEmissionService,
      NfceOfflineTransmissionService,
      DanfeTextRenderer,
      DanfeHtmlRenderer,
      DanfePdfRenderer,
      NfeXmlValidator,
      XsdValidator,
      NfeTxtValidator,
      NfeTxtConverter,
      NfceQrCode,
      Complements,
      Make,
      Tools,
      FiscalOutputJob,
      EscPosEncoder,
    ];

    expect(exportedTypes, hasLength(30));
    expect(exportedTypes.toSet(), hasLength(exportedTypes.length));
  });
}
