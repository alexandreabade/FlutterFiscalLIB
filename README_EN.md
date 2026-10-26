# FlutterFiscalLIB

Dart/Flutter library for Brazilian electronic fiscal documents (NF-e model 55
and NFC-e model 65), maintained by Olímpia Sistemas.

The current public API includes typed fiscal models, exact decimal
totalization, access-key/CPF/CNPJ/GTIN validation, NF-e/NFC-e XML generation,
structural validation, ICMS/FCP/ICMS-ST, Simples Nacional, monophase ICMS,
IPI, PIS/COFINS, ISSQN, initial IBS/CBS/IS groups, A1 PFX/P12 reading, RSA
XMLDSig for NF-e/events/inutilization, SOAP transport with TLS client
certificates, response parsing, timeout/unknown-state handling, cancellation,
CC-e, recipient manifestation, EPEC, offline NFC-e queue, QR Code 2.00/3.00,
Drift/SQLite example and text/HTML/auxiliary PDF DANFE renderers. Product
metadata such as NVE, CEST, fiscal benefit, EXTIPI and purchase-order fields
are optional on `NfeItem`.

```dart
import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';

final xml = NfeXmlBuilder().build(document);
```

Generated XML is not authorization by itself. The application must configure
the appropriate certificate, UF endpoint, CSC and fiscal environment. The
repository includes schema-validation tools using `xmllint`; that external
validator is not a runtime dependency of the multiplatform Dart core.
Operation-specific HTTPS endpoints can be supplied through
`SefazClientConfig.serviceEndpoints`; unconfigured operations fall back to the
main endpoint. Batch GZIP compression is available through
`Tools.sefazEnviaLote(..., compactar: true)`.

`SefazClient.sendXml()` rejects malformed XML before calling the transport.
HTTP responses containing a SOAP Fault are normalized as `SEFAZ_SOAP_FAULT`
with the returned reason, while ordinary HTTP failures remain
`SEFAZ_HTTP_ERROR`. `SefazResult.protocols` preserves every `infProt` from a
processed batch, including batches containing both authorized and rejected
documents.

Signed XML validation requires an explicit cryptographic verifier. A
`SignatureValue` element alone is not accepted as proof of a valid signature;
configure `Tools.signatureVerifier` with the public key that matches the A1
certificate before calling `sefazValidate()`.

The PDF renderer is an auxiliary printable renderer, not the complete
official `sped-da` DANFE layout. Real SEFAZ homologation and device tests
require credentials, certificates, CSCs and platform environments not
included in this repository.

`DanfeHtmlRenderer` accepts `DanfeHtmlOptions(canceled: true)` to mark a
cancelled auxiliary copy visually. This option does not cancel the document at
SEFAZ and does not modify the XML.

For text thermal printing, `EscPosEncoder().encode(text)` produces
deterministic ESC/POS bytes; applications may provide a custom `textEncoder`
for printers that require a specific code page.

PDF bytes can be handed to Flutter printing, sharing, or native-channel
plugins through `PdfFiscalOutputAdapter`; Bluetooth ESC/POS integrations can
use `BluetoothFiscalOutputAdapter`. The core package does not depend on a
specific Flutter plugin.

For desktop and CI XSD validation, use `XsdValidator` with `xmllint`. On
Android/iOS, inject a real parser through `XsdContentValidator` and
`validateContent()`/`assertValidContent()`. Without such an adapter the API
fails explicitly instead of treating well-formed XML as XSD validation.
For official multi-file schemas, use `validateContentBundle()` or
`assertValidContentBundle()` and provide the named `xs:include`/`xs:import`
resources to the native adapter.

The `example_flutter` application demonstrates offline NFC-e persistence with
Drift/SQLite, HTML DANFE preview, thermal DANFE PDF delivery, ESC/POS output,
and runtime RSA-SHA1 XMLDSig verification. It does not include production
certificates, CSC credentials, or a real SEFAZ endpoint.

An offline document in an unknown state is never resent automatically. After
an explicit `retryUnknown()` decision, prior status, receipt and protocol
metadata are cleared before the next transmission attempt.

See `API_COMPATIBILITY.md`, `REFERENCE_ANALYSIS.md`, `TEST_REPORT.md` and
`schemas/README.md` for compatibility status and validation evidence.

