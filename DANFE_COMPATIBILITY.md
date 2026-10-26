# Compatibilidade DANFE com `sped-da`

Esta matriz compara a superfície pública do snapshot `sped-da`
`308abfe0fe01a3a2c9acfc7b57bf59fcffc77717` com os renderizadores da
FlutterFiscalLIB. A comparação é de comportamento e configuração; não promete
igualdade binária entre TCPDF e o pacote `pdf`.

## `NFe\Danfe`

| Método `sped-da` | FlutterFiscalLIB | Status | Evidência |
| --- | --- | --- | --- |
| `setTitle($title)` | `DanfePdfOptions.title` | Mapeado | `test/danfe_pdf_renderer_test.dart` |
| `epec($protocolo, $data)` | `epecProtocol` / `epecDate` | Mapeado | `test/danfe_pdf_renderer_test.dart` |
| `obsContShow($flag)` | `showContributorObservations` | Mapeado | `test/danfe_pdf_renderer_test.dart` |
| `setVUnComCasasDec($n)` | `unitPriceDecimals` | Mapeado | `test/danfe_pdf_renderer_test.dart` |
| `setQComCasasDec($n)` | `quantityDecimals` | Mapeado | `test/danfe_pdf_renderer_test.dart` |
| `setOcultarUnidadeTributavel($flag)` | `showTaxableUnit: !flag` | Mapeado | `test/danfe_pdf_renderer_test.dart` |
| `setExibirEmailDestinatario($flag)` | `showRecipientEmail` | Mapeado | `test/danfe_pdf_renderer_test.dart` |
| `setGerarInformacoesAutomaticas($flag)` | `generateAutomaticInfo` | Mapeado | `test/danfe_pdf_renderer_test.dart` |
| `setUsarLinhaTracejadaSeparacaoItens($flag)` | `useDashedItemSeparators` | Mapeado | `test/danfe_pdf_renderer_test.dart` e inspeção PNG |
| `descProdInfoLoteTxt` | `showItemTraceability` | Mapeado | `test/danfe_pdf_renderer_test.dart` |

## `NFe\Danfce`

| Método `sped-da` | FlutterFiscalLIB | Status | Evidência |
| --- | --- | --- | --- |
| `setPaperWidth($width)` | `paperWidthMm` | Mapeado | `test/danfe_pdf_renderer_test.dart` |
| `setMargins($width)` | `marginMm` | Mapeado | `test/danfe_pdf_renderer_test.dart` |
| `setFont($font)` | `fontBytes` | Adaptado | fonte licenciada é recebida por bytes, sem caminho nativo obrigatório |
| `setPrintResume($flag)` | `printSummary` | Mapeado | `test/danfe_pdf_renderer_test.dart` |
| `setAsCanceled()` | `canceled` | Mapeado | `test/danfe_pdf_renderer_test.dart` |
| `setViaEstabelecimento()` | `establishmentCopy` | Mapeado | `test/danfe_pdf_renderer_test.dart` |
| `setOffLineDoublePrint($flag)` | `offlineDoublePrint` | Mapeado | `test/danfe_pdf_renderer_test.dart` |
| `setExtraContent($texto)` | `extraContent` | Mapeado | `test/danfe_pdf_renderer_test.dart` |
| `render($logo)` | `DanfePdfRenderer.render()` | Adaptado | `test/danfe_pdf_renderer_test.dart` |

O renderer HTML também expõe `showItemAdditionalInfo` e
`showItemTraceability`, mantendo o mesmo controle tipado da descrição dos
itens sem alterar o XML fiscal.

## Diferenças assumidas

- O renderer Dart recebe `NfeDocument` tipado e não XML arbitrário; a leitura,
  validação e assinatura do XML são etapas separadas do núcleo fiscal.
- O PDF é gerado pelo pacote Dart `pdf`, portanto a geometria não é uma cópia
  byte a byte do TCPDF do `sped-da`. A saída atual inclui cabeçalho, canhoto,
  destinatário, cálculo do imposto, transporte, itens, cobrança, pagamentos,
  informações adicionais, QR Code, continuação e paginação.
- Fontes Unicode não são presumidas no sistema operacional. Para acentos e
  outros caracteres fora das fontes Type 1 padrão, a aplicação deve fornecer
  uma fonte TTF/OTF licenciada em `fontBytes`; isso evita depender de caminhos
  de fonte específicos de Windows, macOS, Linux, Android ou iOS.
- A equivalência geométrica oficial completa continua pendente e é mantida
  explícita em `REFERENCE_ANALYSIS.md` e `PLATFORM_SUPPORT.md`.

