# Guia de migração

## Estado atual

O núcleo Dart usa objetos imutáveis e null safety. Em vez de reproduzir o estado mutável interno de `Make` do NFePHP, o chamador monta um `NfeDocument` e chama `Make().montaNFe(document)`.

| NFePHP | FlutterFiscalLIB | Observação |
| --- | --- | --- |
| `Make` | `Make` | Fachada tipada disponível |
| `montaNFe()` | `Make.montaNFe(document)` | XML estrutural, ainda sem assinatura |
| `Tools` | `Tools` | Utilitários básicos disponíveis |
| `Certificate` | `Certificate` / `PfxIdentity` | Leitura PEM/PFX/P12, validade X.509, extração segura em memória e identidade para assinatura/mTLS; não persiste senha |

