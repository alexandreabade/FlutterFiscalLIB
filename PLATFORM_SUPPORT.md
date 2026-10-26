# Matriz de plataformas

Esta matriz registra comandos efetivamente executados no projeto e não
substitui homologação fiscal nem testes em dispositivos físicos.

Validação local adicional em 25/10/2026: no macOS com Flutter 3.47.1,
`flutter pub get`, `dart run build_runner build`,
`flutter analyze`, `flutter test`, `flutter build macos --debug` e
`flutter build ios --debug --no-codesign` foram executados com sucesso. O
build iOS foi produzido sem assinatura, portanto não comprova instalação em
dispositivo.

Em 26/10/2026, após as alterações de XMLDSig e DANFE, foram novamente
executados `flutter pub get`, `flutter analyze`, `flutter test`,
`flutter build apk --debug`, `flutter build ios --debug --no-codesign` e
`flutter build macos --debug`, com os artefatos Android, iOS e macOS gerados.
Os builds Linux e Windows não foram executados neste host macOS; continuam
cobertos pelos jobs nativos correspondentes da CI.

Após a integração do `PdfFiscalOutputAdapter` no exemplo Flutter, os três
builds móveis/desktop acima foram repetidos com sucesso: APK Android de debug,
`Runner.app` iOS sem assinatura e aplicativo macOS de debug.

Na validação local mais recente, com Flutter 3.47.1/Dart 3.13.1 em macOS x64,
`flutter pub get`, `dart run build_runner build`, `flutter analyze`, `flutter
test` e `flutter build macos --debug` foram executados novamente com sucesso.
O exemplo gerou 22 saídas do build_runner, 8 testes Flutter aprovados e o
aplicativo macOS de debug.

Na mesma rodada, `flutter test integration_test/xsd_platform_test.dart -d macos`
passou com 1 teste, cobrindo o parser nativo macOS e a resolução de bundle XSD
em runtime. O runner emitiu apenas o aviso operacional de foreground do app;
o teste terminou aprovado.

O mesmo ambiente também concluiu `flutter build apk --debug`, produzindo o
APK Android de depuração. Isso comprova compilação do alvo, mas não execução
em aparelho físico nem integração com armazenamento seguro nativo.

O exemplo agora inclui `PlatformFiscalSecretStore`: a implementação Android
usa uma chave AES-GCM criada no Android Keystore e valores cifrados em
SharedPreferences; a implementação iOS usa o Keychain. Os contratos Dart e o
canal foram testados no host, e os builds APK/iOS sem assinatura compilaram as
pontes; a execução real do armazenamento seguro continua dependente de
emulador/dispositivo.

Em 26/10/2026, o teste Flutter de integração passou no iPhone 17 Pro
Simulator (iOS 26.3), incluindo gravação, leitura e remoção reais no Keychain.
O cenário Android permanece coberto pelo job de emulador da CI.

O exemplo agora inclui `AndroidXsdContentValidator`, uma ponte MethodChannel
que valida o XML em memória com o parser XSD do Android e bloqueia DTD/schema
externos. O build comprova a compilação dessa ponte; o teste runtime dedicado
foi adicionado, mas ainda depende de emulador/dispositivo executável.

No iOS, o exemplo também inclui `IosXsdContentValidator`, compilado contra o
`libxml2` fornecido pelo SDK e protegido contra acesso de rede (`XML_PARSE_NONET`).
Além do build sem assinatura, o teste de bundle XSD passou no iPhone 17 Pro
Simulator (iOS 26.3), cobrindo o canal em runtime; a execução em dispositivo
físico ainda depende de provisionamento e conectividade Flutter.

O exemplo agora inclui `MacosXsdContentValidator`, também compilado contra o
`libxml2` do SDK macOS e protegido contra carregamento externo. Em 26/10/2026,
`flutter build macos --debug` e
`flutter test integration_test/xsd_platform_test.dart -d macos` passaram,
cobrindo validação em memória e bundle com `xs:include` no runtime macOS.

O runner Linux agora inclui `LinuxXsdContentValidator`, ligado ao `libxml2`
do sistema pelo CMake e com o mesmo bloqueio `XML_PARSE_NONET`. O build e o
teste de integração Linux são executados no job Flutter Linux da CI; não foram
executados localmente porque este host é macOS.

O runner Windows agora inclui `WindowsXsdContentValidator`, usando MSXML6 com
`ProhibitDTD=true`, `resolveExternals=false`, validação de carregamento e
arquivos temporários controlados para suportar bundles. O build e o teste de
integração ficam no job Windows da CI; não foram executados localmente neste
host macOS.

Foi adicionado `example_flutter/integration_test/offline_flow_test.dart` para
executar a geração e persistência SQLite em dispositivo/simulador. No ambiente
local de 25/10/2026, o build do simulador iOS terminou, mas a instalação via
`simctl` ficou bloqueada pelo runtime do simulador; portanto essa execução não
é contada como teste aprovado.

Em 25/10/2026, o mesmo smoke test passou no emulador Android `Medium_Phone`
(`emulator-5554`), cobrindo instalação do APK, execução Flutter, geração da
NFC-e offline e persistência SQLite.

Em nova tentativa local, um iPhone físico foi detectado via conexão sem fio,
mas o Flutter exigiu `--publish-port` para iniciar o app; essa execução não foi
contabilizada como aprovada.

O smoke test no alvo macOS também compilou o aplicativo, mas falhou ao
colocá-lo em primeiro plano (`open returned 1`); somente o build é contado.

A CI também possui o job `flutter-android-integration`, que inicializa um
emulador Android e repete o smoke test offline e o teste de bundle XSD a cada
alteração.

O teste de integração Flutter também gera uma chave RSA efêmera em memória e
assina/verifica XMLDSig com RSA-SHA1 no runtime, sem usar um assinador fictício;
isso cobre a execução criptográfica do pacote nos alvos móveis quando os jobs
Android/iOS da CI rodam.

O job `flutter-ios-integration` faz o mesmo em um iPhone Simulator nos runners
macOS, incluindo o bundle XSD nativo, sem exigir assinatura Apple ou dispositivo
físico.

| Plataforma | Evidência local/CI | Escopo comprovado | Limitação conhecida |
| --- | --- | --- | --- |
| Linux x64 | CI `portable-dart`; CI Flutter `build linux` e integração XSD nativa | Núcleo Dart, exemplo Flutter, compilação Linux e validação XSD nativa quando o job passa | Não comprova impressoras ou certificado A1 de produção |
| macOS | CI `portable-dart`; CI Flutter `build macos`; `flutter test integration_test/xsd_platform_test.dart -d macos`; `flutter build ios --no-codesign` | Núcleo Dart, compilação do exemplo e validação XSD nativa em runtime macOS | Não comprova dispositivo iOS nem macOS Intel e Apple Silicon separadamente |
| Windows x64 | CI `portable-dart`; CI Flutter `build windows` e integração XSD nativa | Núcleo Dart, compilação do exemplo Windows e validação XSD nativa quando o job passa | Não comprova cadeia de certificados instalada no ambiente do usuário |
| Android | CI Flutter `build apk`; smoke test `integration_test` aprovado no emulador local; `flutter analyze`/`flutter test` local | Compilação APK, execução Flutter, persistência SQLite, ponte Bluetooth ESC/POS e adaptador XSD nativo compilado | Não comprova aparelho ARM64 físico, execução runtime do XSD nesta rodada nem armazenamento seguro nativo |
| iOS ARM64/Simulator | CI Flutter `build ios --debug --no-codesign`; smoke test XSD/bundle aprovado localmente no iPhone 17 Pro Simulator; CI `flutter-ios-integration` | Compilação sem assinatura, execução do smoke test, persistência SQLite, ponte Bluetooth ESC/POS e adaptador XSD nativo em runtime | Exige provisionamento Apple para instalar/executar em dispositivo físico |

## Validações comuns

- `dart analyze` e a suíte Dart são executados na CI em Linux, macOS e
  Windows.
- `flutter analyze`, `flutter test` e `build_runner` são executados no exemplo
  Flutter; os builds nativos são condicionados ao sistema operacional do job.
- A validação XSD usa `xmllint` no job Windows/fixtures de CI. O exemplo fornece
  `AndroidXsdContentValidator`, `IosXsdContentValidator`,
  `MacosXsdContentValidator` e `LinuxXsdContentValidator`; o núcleo continua recebendo validadores por
  injeção e não simula validação de schema. Para
  schemas oficiais com `xs:include`/`xs:import`, use
  `validateContentBundle()` com os recursos nomeados.
- Comunicação SEFAZ real, TLS com certificado produtivo, impressoras,
  Bluetooth e homologação fiscal continuam dependentes de credenciais,
  endpoints e hardware externos.
- A consulta real de homologação está preparada em
  `test/sefaz_homologation_test.dart`, mas não é executada automaticamente e
  não foi declarada como aprovada sem credenciais/endpoint oficiais.
