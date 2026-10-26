# Decisão arquitetural

## Um pacote principal, com exemplo Flutter

O projeto mantém um único pacote público, `flutter_fiscal_lib`, em vez de
manter um segundo pacote Flutter com uma superfície pública duplicada.

Essa decisão é adequada ao estado atual por três motivos:

1. O núcleo fiscal, XML, assinatura, modelos, DANFE e contratos de
   persistência não precisam importar `package:flutter`.
2. A mesma API Dart pode ser usada por aplicações Dart de servidor/desktop e
   por aplicações Flutter, reduzindo divergência entre duas versões públicas.
3. Recursos dependentes de plataforma permanecem injetáveis: transporte SEFAZ,
   armazenamento offline, validação XSD, impressão e compartilhamento não são
   acoplados ao núcleo.

## Fronteiras de plataforma

- `SefazTransport` permite substituir o transporte `dart:io` por um adaptador
  compatível com a aplicação.
- `FiscalDocumentStore` e `FiscalNumberAllocator` permitem SQLite/Drift,
  armazenamento seguro ou outro backend sem alterar o XML fiscal.
- `FiscalSecretStore` e `CallbackFiscalSecretStore` permitem encaminhar PFX,
  senhas e outros bytes sensíveis para Keychain, Keystore ou plugin seguro sem
  acoplar o núcleo a uma plataforma; `InMemoryFiscalSecretStore` é somente
  para testes e protótipos.
- `DanfePdfRenderer` retorna bytes; impressão, compartilhamento e Bluetooth
  podem usar `FiscalOutputAdapter`: o núcleo fornece callback, arquivo e TCP,
  enquanto plugins Flutter continuam responsáveis por compartilhamento,
  impressão do sistema e Bluetooth.
- `XsdValidator` delega a validação para um executor injetável; o núcleo não
  inicia processos arbitrários em Android/iOS.

O diretório `example_flutter` demonstra a integração Flutter com Drift e
reserva transacional de numeração. Um pacote Flutter separado será criado
quando houver adaptadores nativos estáveis que justifiquem uma API pública
adicional; criar apenas um segundo pacote sem esses adaptadores aumentaria a
superfície de manutenção sem ampliar o suporte comprovado.

## Consequência explícita

O pacote é destinado às plataformas nativas Dart/Flutter documentadas em
`PLATFORM_SUPPORT.md`. Suporte web não é declarado, pois o transporte padrão,
leitura de PFX por arquivo e validação XSD usam APIs de `dart:io`.
