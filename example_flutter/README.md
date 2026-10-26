# Exemplo Flutter

Este exemplo demonstra a integração da FlutterFiscalLIB com persistência offline
em SQLite/Drift. A validação local pode ser reproduzida com:

```bash
flutter pub get
dart run build_runner build
flutter analyze
flutter build bundle --debug
flutter test
```

O exemplo também contém os scaffolds nativos Android, iOS, Linux, macOS e
Windows. Para validar os
artefatos móveis localmente:

```bash
flutter build apk --debug
flutter build ios --debug --no-codesign
```

O build iOS sem assinatura comprova a compilação do projeto e dos plugins; a
instalação em dispositivo exige identidade Apple e provisioning.

Para validar os alvos desktop no sistema correspondente:

```bash
flutter build linux --debug    # Linux
flutter build macos --debug    # macOS
flutter build windows --debug  # Windows
```

Os builds desktop dependem das ferramentas nativas do sistema (GTK/CMake no
Linux, Xcode no macOS e Visual Studio no Windows).

Este exemplo demonstra a geração de uma NFC-e em contingência offline e a
persistência do XML em SQLite usando Drift. O `FiscalDocumentStore` é adaptado
por `DriftFiscalDocumentStore` para a fila `NfceOfflineQueue`.

O aplicativo importa `flutter_fiscal_lib`, permite editar emitente e produto,
exibe o XML, pré-visualiza o DANFE HTML, prepara PDF e bytes ESC/POS por
adaptadores injetáveis, mostra o estado persistente da fila,
aceita um caminho externo para carregar um certificado A1 e mantém campos para
configuração de CSC. O botão de transmissão é deliberadamente opt-in e exibe
as pré-condições necessárias, sem inventar endpoint ou credencial.

O exemplo não possui certificado A1 nem comunica com a SEFAZ. Em uma aplicação
real, o XML deve ser assinado antes de ser inserido na fila e só deve ser
transmitido conforme as regras da UF.

No Android, a ponte `AndroidXsdContentValidator` usa o parser XSD nativo por
`MethodChannel` e pode ser injetada no núcleo:

```dart
final validator = XsdValidator(
  contentValidator: const AndroidXsdContentValidator().call,
);
await validator.assertValidContent(schema: schema, xml: xml);
```

Essa ponte pertence ao exemplo, não ao núcleo multiplataforma. No iOS, injete
`IosXsdContentValidator`, que usa `libxml2` do SDK por `MethodChannel`.

Para persistir PFX, senhas ou outros bytes sensíveis, o exemplo também fornece
`PlatformFiscalSecretStore`. No Android ele usa AES-GCM com chave gerenciada
pelo Android Keystore; no iOS usa o Keychain. O núcleo continua recebendo
apenas a interface `FiscalSecretStore`, sem registrar segredos em logs.

Para os schemas oficiais, passe também os arquivos referenciados pelo schema
principal:

```dart
final validator = XsdValidator(
  bundleValidator: const IosXsdContentValidator().callBundle,
);
await validator.assertValidContentBundle(
  schema: schemaPrincipal,
  xml: xml,
  resources: {'leiauteNFe_v4.00.xsd': leiaute, 'tiposBasico_v4.00.xsd': tipos},
);
```

O exemplo também expõe `DriftFiscalNumberAllocator`, que reserva numeração em
uma transação SQLite por UF, emitente, modelo e série. A coordenação entre
dispositivos sem o mesmo banco continua sendo responsabilidade da implantação.
O adapter `DriftFiscalDocumentStore` também reivindica documentos em uma
transação SQLite atômica quando usado com `NfceOfflineQueue`. O início da
tentativa também é persistido: após um reinício com lease expirado, o documento
vai para `unknown` e deve ser consultado antes de qualquer reenvio.

O smoke test de integração pode ser executado em um dispositivo ou simulador:

```bash
flutter test integration_test/offline_flow_test.dart -d <device-id>
```
