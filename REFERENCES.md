# Manifesto de referências

Este arquivo registra as fontes que orientam a implementação da FlutterFiscalLIB.

| Referência | Uso | Versão/data de consulta |
| --- | --- | --- |
| [NFePHP sped-nfe](https://github.com/nfephp-org/sped-nfe) | API pública e fluxo de NF-e/NFC-e | `v5.0.100` / `cf0baf005691c3a9e252314150c7dac18adbb2ee` |
| [NFePHP sped-common](https://github.com/nfephp-org/sped-common) | Infraestrutura comum e validações | `39ca47cce3b2b750e305cd84b7d98f3d670f6504` (`v5.1.17` resolvido pelo Composer) |
| [NFePHP sped-da](https://github.com/nfephp-org/sped-da) | DANFE e representação auxiliar | `308abfe0fe01a3a2c9acfc7b57bf59fcffc77717` (clone consultado em 25/10/2026) |
| [NFePHP sped-gtin](https://github.com/nfephp-org/sped-gtin) | Validação GTIN/EAN | `4ca4d57d9f57431b6c042b5a04266dffb7044575` (clone consultado em 25/10/2026) |
| [Portal Nacional da NF-e](https://www.nfe.fazenda.gov.br/portal/) | Documentos fiscais e comunicados oficiais | Consulta em 26/10/2026: PL_010f em uso (NT 2025.002 v.1.50 + NT 2026.007 v.1.00); NT 2025.002 v.1.52 e comunicados posteriores registrados como atualização de regras, sem alegar que o schema incorporado já as contém |
| [Schema PL_010f](https://www.nfe.fazenda.gov.br/portal/exibirArquivo.aspx?conteudo=8ITFuBLltXs%3D) | Pacote oficial vigente de XSD NF-e/NFC-e | `PL_010f_v1.04`, publicado em 31/08/2026, incorporado com hashes em `schemas/PL_010f_v1.04.MANIFEST.json` |
| [Manual DANFE-NFC-e e QR Code v6.0](https://www.nfe.fazenda.gov.br/portal/listaConteudo.aspx?tipoConteudo=ndIjl%2BiEFdE%3D) | QR Code e impressão auxiliar NFC-e | Publicado em março de 2025; implementação suporta os perfis QR Code 2.00 e 3.00, mantendo 2.00 para compatibilidade |
| [Manual de Contingência Offline NFC-e v2.0](https://www.nfe.fazenda.gov.br/portal/listaConteudo.aspx?tipoConteudo=GKxb5ZZeQIM%3D) | `tpEmis=9`, `dhCont`, `xJust` e payload offline | Referência oficial consultada |
| [NT 2025.002-RTC](https://www.nfe.fazenda.gov.br/portal/exibirArquivo.aspx?conteudo=DaB0yzqdbRU%3D) | Grupos IBS, CBS, Imposto Seletivo e totalizadores da reforma tributária | Versão consultada para o modelo inicial; acompanhar revisões vigentes |
| [Documentos vigentes do Portal NF-e](https://www.nfe.fazenda.gov.br/portal/listaConteudo.aspx?AspxAutoDetectCookieSupport=1&tipoConteudo=6WfrpZYE4Ik%3D) | NT 2025.002 v.1.52, NT 2026.007 v.1.10, NT 2026.008 v.1.00 e NT 2026.010 v.1.00 | Consultadas em 26/10/2026; a NT 2026.010 divulga o modelo de DANFE para RTC, ainda não reproduzido integralmente pelo renderizador auxiliar |

Em consulta de 26/10/2026, o Portal Nacional mantém o pacote de liberação 010f
como schema em uso e também lista a NT 2025.002 v.1.52, a NT 2026.007 v.1.10,
a NT 2026.008 v.1.00 e a NT 2026.010 v.1.00 em comunicados de atualização ou
implantação. O download do pacote incorporado foi realizado com o cookie de
compatibilidade do Portal; o checksum está registrado no manifesto. Essas
atualizações posteriores ficam rastreadas, mas não são declaradas implementadas
até que seus XSDs, regras e testes sejam incorporados.

Nenhuma referência acima é uma declaração de que uma regra fiscal já foi implementada. Cada módulo deve registrar a versão exata do código, schema ou nota técnica usada e seus testes associados.

## Licenças e redistribuição

O código Dart deste repositório é distribuído sob MIT, conforme `LICENSE`.
Os schemas incorporados são componentes separados: `PL_009_V4` mantém no
manifesto a referência `LGPL-3.0-or-later`, enquanto os pacotes oficiais
`PL_010b_NT2025_002_v1.30` e `PL_010f_v1.04` registram a origem no Portal
Nacional da NF-e e não são relicenciados como MIT. Os termos e hashes de cada
pacote estão em `schemas/*.MANIFEST.json`; qualquer redistribuição deve
preservar esses avisos e observar as condições da fonte oficial.

