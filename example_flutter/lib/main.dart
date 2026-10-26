import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';

import 'offline_database.dart';
import 'serpro_trust.dart';
import 'secure_secret_store.dart';

void main() => runApp(const FiscalExampleApp());

/// Aplicativo de demonstração da biblioteca fiscal.
class FiscalExampleApp extends StatelessWidget {
  /// Cria o aplicativo de demonstração.
  const FiscalExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlutterFiscalLIB',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const FiscalHomePage(),
    );
  }
}

/// Tela que gera e exibe um XML de demonstração.
class FiscalHomePage extends StatefulWidget {
  /// Cria a tela principal.
  const FiscalHomePage({super.key});

  @override
  State<FiscalHomePage> createState() => _FiscalHomePageState();
}

class _FiscalHomePageState extends State<FiscalHomePage> {
  String _xml = 'Toque em “Gerar XML” para criar um documento de teste.';
  String _preview = 'O DANFE HTML aparecerá aqui após gerar o documento.';
  String _status = 'Nenhum certificado carregado.';
  String _sefazResponseXml = 'Nenhuma resposta XML da SEFAZ.';
  SefazResult? _sefazResult;
  int? _sefazHttpStatus;
  String? _sefazTechnicalError;
  final _history = <String>[];
  final _issuerNameController = TextEditingController(
    text: 'Empresa de Demonstração',
  );
  final _fantasyNameController = TextEditingController(
    text: 'Mercado Demonstração',
  );
  final _issuerCnpjController = TextEditingController(text: '04252011000110');
  final _issuerIeController = TextEditingController(text: '123456789');
  final _addressController = TextEditingController(text: 'Rua Fiscal');
  final _addressNumberController = TextEditingController(text: '1');
  final _neighborhoodController = TextEditingController(text: 'Centro');
  final _cityCodeController = TextEditingController(text: '1100015');
  final _cityController = TextEditingController(text: 'Alta Floresta D Oeste');
  final _zipCodeController = TextEditingController(text: '76954000');
  final _phoneController = TextEditingController(text: '69999999999');
  final _emailController = TextEditingController(text: 'fiscal@empresa.test');
  final _crtController = TextEditingController(text: '1');
  final _productController = TextEditingController(
    text: 'Produto de demonstração',
  );
  final _certificatePathController = TextEditingController();
  final _certificatePasswordController = TextEditingController();
  final _cscIdController = TextEditingController();
  final _cscController = TextEditingController();
  XFile? _selectedCertificateFile;
  NfeDocument? _document;
  PfxIdentity? _certificateIdentity;
  int _environment = 2;
  String _uf = 'RO';

  static const _ufCodes = <String, String>{
    'AC': '12',
    'AL': '27',
    'AP': '16',
    'AM': '13',
    'BA': '29',
    'CE': '23',
    'DF': '53',
    'ES': '32',
    'GO': '52',
    'MA': '21',
    'MT': '51',
    'MS': '50',
    'MG': '31',
    'PA': '15',
    'PB': '25',
    'PR': '41',
    'PE': '26',
    'PI': '22',
    'RJ': '33',
    'RN': '24',
    'RS': '43',
    'RO': '11',
    'RR': '14',
    'SC': '42',
    'SP': '35',
    'SE': '28',
    'TO': '17',
  };
  late final Future<ExampleFiscalDatabase> _database;
  late final Future<void> _settings;
  NfceOfflineQueue? _queue;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _settings = _loadSavedSettings();
    _database = openExampleDatabase().then((database) {
      _queue = NfceOfflineQueue(store: DriftFiscalDocumentStore(database));
      _refreshPendingCount();
      return database;
    });
  }

  Future<File> _settingsFile() async {
    final directory = await getApplicationSupportDirectory();
    final file = File('${directory.path}/flutter_fiscal_lib_demo.json');
    await file.parent.create(recursive: true);
    return file;
  }

  Future<void> _loadSavedSettings() async {
    try {
      final file = await _settingsFile();
      if (await file.exists()) {
        final raw = jsonDecode(await file.readAsString());
        if (raw is Map<String, dynamic>) {
          _issuerNameController.text =
              raw['issuerName'] as String? ?? _issuerNameController.text;
          _fantasyNameController.text =
              raw['fantasyName'] as String? ?? _fantasyNameController.text;
          _issuerCnpjController.text =
              raw['cnpj'] as String? ?? _issuerCnpjController.text;
          _issuerIeController.text =
              raw['ie'] as String? ?? _issuerIeController.text;
          _uf = raw['uf'] as String? ?? _uf;
          _addressController.text =
              raw['address'] as String? ?? _addressController.text;
          _addressNumberController.text =
              raw['addressNumber'] as String? ?? _addressNumberController.text;
          _neighborhoodController.text =
              raw['neighborhood'] as String? ?? _neighborhoodController.text;
          _cityCodeController.text =
              raw['cityCode'] as String? ?? _cityCodeController.text;
          _cityController.text = raw['city'] as String? ?? _cityController.text;
          _zipCodeController.text =
              raw['zipCode'] as String? ?? _zipCodeController.text;
          _phoneController.text =
              raw['phone'] as String? ?? _phoneController.text;
          _emailController.text =
              raw['email'] as String? ?? _emailController.text;
          _crtController.text = raw['crt'] as String? ?? _crtController.text;
          _productController.text =
              raw['product'] as String? ?? _productController.text;
          _certificatePathController.text =
              raw['certificatePath'] as String? ?? '';
          _cscIdController.text = raw['cscId'] as String? ?? '';
          _environment = raw['environment'] as int? ?? _environment;
        }
      }
      final password = await const PlatformFiscalSecretStore().read(
        'demo_certificate_password',
      );
      if (password != null) {
        _certificatePasswordController.text = utf8.decode(password);
      }
      if (mounted) setState(() {});
    } on Object catch (error) {
      if (mounted) {
        setState(
          () => _status = 'Não foi possível restaurar o cadastro: $error',
        );
      }
    }
  }

  Future<void> _saveDemoSettings() async {
    final file = await _settingsFile();
    await file.writeAsString(
      jsonEncode({
        'issuerName': _issuerNameController.text,
        'fantasyName': _fantasyNameController.text,
        'cnpj': _issuerCnpjController.text,
        'ie': _issuerIeController.text,
        'uf': _uf,
        'address': _addressController.text,
        'addressNumber': _addressNumberController.text,
        'neighborhood': _neighborhoodController.text,
        'cityCode': _cityCodeController.text,
        'city': _cityController.text,
        'zipCode': _zipCodeController.text,
        'phone': _phoneController.text,
        'email': _emailController.text,
        'crt': _crtController.text,
        'product': _productController.text,
        'certificatePath': _certificatePathController.text,
        'cscId': _cscIdController.text,
        'environment': _environment,
      }),
      flush: true,
    );
    final password = _certificatePasswordController.text;
    if (password.isNotEmpty) {
      await const PlatformFiscalSecretStore().write(
        'demo_certificate_password',
        Uint8List.fromList(utf8.encode(password)),
      );
    }
  }

  Future<void> _generateXml() async {
    final queue = _queue;
    if (queue == null) return;
    late final FiscalCompanyRegistration company;
    try {
      company = _companyFromForm();
    } on Object catch (error) {
      _showMessage('Cadastro inválido: $error');
      return;
    }
    final productDescription = _productController.text.trim();
    final issueDate = DateTime.utc(2026, 1, 1);
    final database = await _database;
    final documentNumber = await DriftFiscalNumberAllocator(
      database,
    ).reserve(cUf: company.cUf, issuerCnpj: company.cnpj, model: 65, series: 1);
    final document = NfeDocument(
      accessKey: AccessKey.fromComponents(
        cUf: company.cUf,
        issueDate: issueDate,
        cnpj: company.cnpj,
        model: 65,
        series: 1,
        number: documentNumber,
        tpEmis: 9,
        cNf: '12345678',
      ).value,
      number: documentNumber,
      series: 1,
      issueDate: issueDate,
      environment: _environment,
      model: 65,
      operationNature: 'Venda de mercadoria',
      documentType: 1,
      destinationType: 1,
      printFormat: 4,
      purpose: 1,
      finalConsumer: 1,
      presenceIndicator: 1,
      processCode: '0',
      applicationVersion: '0.1.0',
      issuer: company.party,
      items: [
        NfeItem(
          number: 1,
          code: 'DEMO-001',
          description: productDescription,
          ncm: '12345678',
          cfop: '5102',
          unit: 'UN',
          quantity: 1,
          unitPrice: 10,
        ),
      ],
      contingency: Contingency(
        mode: ContingencyMode.offlineNfce,
        activatedAt: issueDate,
        reason: 'Indisponibilidade temporária do serviço autorizador',
      ),
    );
    final xml = Make().build(document);
    await queue.enqueue(
      accessKey: document.accessKey,
      model: document.model,
      // Este exemplo não possui certificado A1; a aplicação real deve
      // assinar o XML antes de persistir na fila.
      signedXml: xml,
    );
    await _refreshPendingCount();
    if (mounted) {
      setState(() {
        _document = document;
        _xml = xml;
        _preview = 'Documento gerado. Toque em “Visualizar DANFE HTML”.';
        _status =
            'NFC-e offline persistida como pendente; ainda não autorizada.';
        _history.insert(0, 'NFC-e ${document.accessKey}: pendente offline');
      });
    }
  }

  Future<void> _generateAndAuthorizeNfce() async {
    final identity = _certificateIdentity;
    if (identity == null) {
      _showMessage('Carregue o certificado A1 antes de emitir a NFC-e.');
      return;
    }
    final cscId = int.tryParse(_cscIdController.text.trim());
    final csc = _cscController.text.trim();
    if (cscId == null || cscId < 1 || csc.isEmpty) {
      _showMessage(
        'Informe o ID CSC e o CSC de homologação da empresa antes de emitir.',
      );
      return;
    }
    if (_environment != 2) {
      _showMessage(
        'Este botão de teste envia somente para homologação. Selecione esse ambiente.',
      );
      return;
    }
    try {
      final company = _companyFromForm();
      final database = await _database;
      final documentNumber = await DriftFiscalNumberAllocator(database).reserve(
        cUf: company.cUf,
        issuerCnpj: company.cnpj,
        model: 65,
        series: 1,
      );
      final issueDate = DateTime.now();
      final accessKey = AccessKey.fromComponents(
        cUf: company.cUf,
        issueDate: issueDate,
        cnpj: company.cnpj,
        model: 65,
        series: 1,
        number: documentNumber,
        tpEmis: 1,
        cNf: documentNumber.toString().padLeft(8, '0'),
      ).value;
      final qrCode = company.nfceOnlineQrCode(
        accessKey: accessKey,
        environment: 2,
        cscId: cscId,
        csc: csc,
      );
      final document = NfeDocument(
        accessKey: accessKey,
        number: documentNumber,
        series: 1,
        issueDate: issueDate,
        environment: 2,
        model: 65,
        operationNature: 'Venda de mercadoria',
        documentType: 1,
        destinationType: 1,
        printFormat: 4,
        purpose: 1,
        finalConsumer: 1,
        presenceIndicator: 1,
        processCode: '0',
        applicationVersion: '0.1.0',
        issuer: company.party,
        items: [
          NfeItem(
            number: 1,
            code: 'DEMO-001',
            description: _productController.text.trim(),
            ncm: '12345678',
            cfop: '5102',
            unit: 'UN',
            quantity: 1,
            unitPrice: 10,
            icmsSimples: const IcmsSimplesTax(csosn: '102'),
          ),
        ],
        payments: const [Payment(type: '01', value: 10)],
        nfceSupplement: NfceXmlSupplement(
          qrCode: qrCode.url,
          keyUrl: company.nfceQrCodeUrl(environment: 2).toString(),
        ),
      );
      final emission = NfeEmissionService(
        signer: XmlSignatureService.fromPfx(identity),
      );
      final signedXml = await emission.buildAndSign(document);
      final config = company.sefazConfig(
        model: 65,
        environment: 2,
        certificate: identity,
        trustedCertificates: [utf8.encode(serproSslV1Certificate)],
      );
      final response = await SefazClient.fromConfig(
        config,
      ).sefazEnviaLote('$documentNumber', signedXml, synchronous: 1);
      final result = const SefazResponseParser().parse(response.body);
      if (!result.isAuthorized) {
        throw FiscalException(
          'A SEFAZ não autorizou a NFC-e: cStat ${result.statusCode} — ${result.reason}',
          code: 'NFCE_NOT_AUTHORIZED',
        );
      }
      final pdf = await DanfePdfRenderer().render(
        document,
        layout: DanfePdfLayout.a4,
      );
      final pdfPath = await _saveOutput(
        pdf,
        format: FiscalOutputFormat.pdf,
        fileName: 'nfce-autorizada-${document.accessKey}.pdf',
      );
      if (mounted) {
        setState(() {
          _document = document;
          _xml = signedXml;
          _sefazResponseXml = response.body;
          _sefazHttpStatus = response.statusCode;
          _sefazResult = result;
          _sefazTechnicalError = null;
          _status =
              'NFC-e autorizada: cStat ${result.statusCode} — ${result.reason}. PDF A4: $pdfPath';
          _history.insert(
            0,
            'NFC-e ${document.accessKey} autorizada; protocolo ${result.protocol ?? 'não informado'}',
          );
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _status = _friendlyErrorMessage(error);
          _history.insert(0, 'Falha na emissão NFC-e: $_status');
        });
      }
    }
  }

  Future<void> _renderDanfe() async {
    final document = _document;
    if (document == null) {
      _showMessage('Gere uma NFC-e antes de visualizar o DANFE.');
      return;
    }
    final html = DanfeHtmlRenderer().render(document);
    if (mounted) {
      setState(() => _preview = html);
    }
  }

  Future<void> _prepareDanfePdf({required DanfePdfLayout layout}) async {
    final document = _document;
    if (document == null) {
      _showMessage('Gere uma NFC-e antes de gerar o DANFE.');
      return;
    }
    final pdf = await DanfePdfRenderer().render(document, layout: layout);
    final fileName = layout == DanfePdfLayout.a4
        ? 'danfe-a4-${document.accessKey}.pdf'
        : 'danfe-cupom-80mm-${document.accessKey}.pdf';
    final outputPath = await _saveOutput(
      pdf,
      format: FiscalOutputFormat.pdf,
      fileName: fileName,
    );
    if (mounted) {
      setState(() {
        _status = layout == DanfePdfLayout.a4
            ? 'DANFE A4 gerado para impressão: $outputPath'
            : 'DANFE cupom 80 mm gerado para impressão: $outputPath';
        _history.insert(0, 'PDF gerado: $fileName (${pdf.length} bytes)');
      });
    }
  }

  Future<String> _saveOutput(
    Uint8List bytes, {
    required FiscalOutputFormat format,
    required String fileName,
  }) async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final outputDirectory =
        '${documentsDirectory.path}/FlutterFiscalLIB/saidas';
    await FileFiscalOutputAdapter(
      outputDirectory,
    ).send(FiscalOutputJob(bytes: bytes, format: format, fileName: fileName));
    return '$outputDirectory/$fileName';
  }

  Future<void> _loadCertificate() async {
    await _settings;
    final path = _certificatePathController.text.trim();
    final password = _certificatePasswordController.text;
    if (path.isEmpty || password.isEmpty) {
      _showMessage('Informe o caminho do PFX/P12 e a senha fora do código.');
      return;
    }
    try {
      final selectedFile = _selectedCertificateFile;
      final identity = selectedFile == null
          ? await PfxIdentity.fromPfxFile(path: path, password: password)
          : PfxIdentity.fromPfx(
              bytes: await selectedFile.readAsBytes(),
              password: password,
            );
      if (mounted) {
        setState(() {
          _certificateIdentity = identity;
          _status =
              'Certificado A1 carregado: ${identity.getCompanyName() ?? 'emitente não identificado'}.';
          _history.insert(0, 'Certificado A1 carregado em memória');
        });
      }
      try {
        await _saveDemoSettings();
        if (mounted) {
          setState(() {
            _status = 'Certificado e cadastro salvos para a próxima execução.';
          });
        }
      } on Object catch (error) {
        if (mounted) {
          setState(() {
            _status =
                'Certificado carregado, mas não foi possível salvar o cadastro: $error';
          });
        }
      }
    } on Object catch (error) {
      _showMessage('Falha ao carregar certificado: $error');
    }
  }

  Future<void> _saveSettingsFromButton() async {
    try {
      await _settings;
      await _saveDemoSettings();
      if (mounted) {
        setState(() => _status = 'Cadastro salvo com sucesso.');
      }
    } on Object catch (error) {
      if (mounted) setState(() => _status = 'Falha ao salvar cadastro: $error');
    }
  }

  Future<void> _selectCertificateFile() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'Certificado A1', extensions: ['pfx', 'p12']),
        ],
      );
      if (file == null || !mounted) return;
      setState(() {
        _selectedCertificateFile = file;
        _certificatePathController.text = file.path;
        _status = 'Arquivo selecionado: ${file.name}';
      });
    } on Object catch (error) {
      if (mounted) {
        setState(() => _status = 'Falha ao abrir o seletor de arquivo: $error');
      }
    }
  }

  Future<void> _consultServiceStatus() async {
    final identity = _certificateIdentity;
    if (identity == null) {
      _showMessage('Carregue um certificado A1 antes de consultar o status.');
      return;
    }
    if (mounted) {
      setState(() => _status = 'Consultando status da SEFAZ...');
    }
    try {
      final company = _companyFromForm();
      final config = company.sefazConfig(
        model: 65,
        environment: _environment,
        certificate: identity,
        trustedCertificates: [utf8.encode(serproSslV1Certificate)],
      );
      final client = SefazClient.fromConfig(config);
      final response = await client.sefazStatusServico(
        cUf: company.cUf,
        environment: _environment,
      );
      final result = SefazResponseParser().parse(response.body);
      if (mounted) {
        setState(() {
          _sefazHttpStatus = response.statusCode;
          _sefazResponseXml = response.body;
          _sefazResult = result;
          _sefazTechnicalError = null;
          _status = _formatSefazResult(response.statusCode, result);
          _history.insert(
            0,
            'Status SEFAZ: cStat ${result.statusCode} — ${result.reason}',
          );
        });
      }
    } on Object catch (error) {
      if (mounted) {
        final detail = error is FiscalException && error.cause != null
            ? '\nDetalhe técnico: ${error.cause}'
            : '';
        setState(() {
          _sefazResult = null;
          _sefazTechnicalError = detail.isEmpty ? null : detail.trim();
          _status = _friendlyErrorMessage(error);
          _history.insert(0, 'Falha SEFAZ: ${_status.replaceAll('\n', ' ')}');
        });
      }
    }
  }

  String _formatSefazResult(int httpStatus, SefazResult result) {
    final classification = result.isAccepted
        ? 'aceito'
        : result.isRejected
        ? 'rejeitado'
        : 'não conclusivo';
    return 'SEFAZ $classification: HTTP $httpStatus — cStat '
        '${result.statusCode}: ${result.reason}';
  }

  String _friendlyErrorMessage(Object error) {
    if (error is FiscalException) {
      final code = error.code;
      final message = switch (code) {
        'SEFAZ_NETWORK_ERROR' =>
          'Não foi possível conectar à SEFAZ. Verifique internet, firewall, certificado e endpoint.',
        'SEFAZ_TIMEOUT' =>
          'A SEFAZ não respondeu no tempo configurado. Consulte o documento antes de reenviar.',
        'SEFAZ_HTTP_ERROR' =>
          'A SEFAZ recusou a chamada HTTP. Verifique o endpoint e o ambiente.',
        'SEFAZ_SOAP_FAULT' =>
          'A SEFAZ retornou uma falha SOAP. Consulte a aba “Retorno SEFAZ”.',
        _ => error.message,
      };
      return 'Falha na consulta de status [$code]: $message';
    }
    return 'Falha na consulta de status: $error';
  }

  FiscalCompanyRegistration _companyFromForm() => FiscalCompanyRegistration(
    name: _issuerNameController.text.trim(),
    fantasyName: _fantasyNameController.text.trim(),
    cnpj: _issuerCnpjController.text.trim(),
    ie: _issuerIeController.text.trim(),
    uf: _uf,
    address: _addressController.text.trim(),
    addressNumber: _addressNumberController.text.trim(),
    neighborhood: _neighborhoodController.text.trim(),
    cityCode: _cityCodeController.text.trim(),
    city: _cityController.text.trim(),
    zipCode: _zipCodeController.text.trim(),
    phone: _phoneController.text.trim(),
    email: _emailController.text.trim(),
    crt: _crtController.text.trim(),
  );

  Future<void> _generateEscPos() async {
    final document = _document;
    if (document == null) {
      _showMessage('Gere uma NFC-e antes de gerar o cupom ESC/POS.');
      return;
    }
    final text = DanfeTextRenderer().render(document);
    final bytes = EscPosEncoder().encode(text);
    final outputPath = await _saveOutput(
      bytes,
      format: FiscalOutputFormat.escPos,
      fileName: 'cupom-escpos-${document.accessKey}.bin',
    );
    if (mounted) {
      setState(() {
        _status =
            'Cupom ESC/POS gerado: $outputPath. Envie os bytes para a impressora via TCP, USB ou Bluetooth.';
        _history.insert(0, 'Cupom ESC/POS gerado (${bytes.length} bytes)');
      });
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _issuerNameController.dispose();
    _fantasyNameController.dispose();
    _issuerCnpjController.dispose();
    _issuerIeController.dispose();
    _addressController.dispose();
    _addressNumberController.dispose();
    _neighborhoodController.dispose();
    _cityCodeController.dispose();
    _cityController.dispose();
    _zipCodeController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _crtController.dispose();
    _productController.dispose();
    _certificatePathController.dispose();
    _certificatePasswordController.dispose();
    _cscIdController.dispose();
    _cscController.dispose();
    _database.then((database) => database.close());
    super.dispose();
  }

  Future<void> _refreshPendingCount() async {
    final queue = _queue;
    if (queue == null) return;
    final records = await queue.store.list(
      states: {FiscalDocumentState.pending, FiscalDocumentState.failed},
    );
    if (mounted) setState(() => _pendingCount = records.length);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('FlutterFiscalLIB'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Cadastro'),
              Tab(text: 'Retorno SEFAZ'),
              Tab(text: 'Documentos'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildConfigurationTab(),
            _buildSefazResponseTab(),
            _buildDocumentsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigurationTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Configuração da demonstração',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Cadastro completo da empresa',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: _issuerNameController,
              decoration: const InputDecoration(labelText: 'Razão social'),
            ),
            TextField(
              controller: _fantasyNameController,
              decoration: const InputDecoration(labelText: 'Nome fantasia'),
            ),
            TextField(
              controller: _issuerCnpjController,
              decoration: const InputDecoration(labelText: 'CNPJ do emitente'),
            ),
            TextField(
              controller: _issuerIeController,
              decoration: const InputDecoration(
                labelText: 'Inscrição estadual',
              ),
            ),
            DropdownButtonFormField<String>(
              initialValue: _uf,
              decoration: const InputDecoration(labelText: 'UF da empresa'),
              items: _ufCodes.keys
                  .map(
                    (uf) => DropdownMenuItem(
                      value: uf,
                      child: Text('$uf — cUF ${_ufCodes[uf]}'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _uf = value);
              },
            ),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Logradouro'),
            ),
            TextField(
              controller: _addressNumberController,
              decoration: const InputDecoration(labelText: 'Número'),
            ),
            TextField(
              controller: _neighborhoodController,
              decoration: const InputDecoration(labelText: 'Bairro'),
            ),
            TextField(
              controller: _cityCodeController,
              decoration: const InputDecoration(
                labelText: 'Código IBGE do município',
              ),
            ),
            TextField(
              controller: _cityController,
              decoration: const InputDecoration(labelText: 'Município'),
            ),
            TextField(
              controller: _zipCodeController,
              decoration: const InputDecoration(labelText: 'CEP'),
            ),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Telefone'),
            ),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-mail'),
            ),
            TextField(
              controller: _crtController,
              decoration: const InputDecoration(
                labelText: 'CRT (regime tributário)',
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Dados da NFC-e e certificado',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: _productController,
              decoration: const InputDecoration(labelText: 'Produto'),
            ),
            DropdownButtonFormField<int>(
              initialValue: _environment,
              decoration: const InputDecoration(labelText: 'Ambiente SEFAZ'),
              items: const [
                DropdownMenuItem(value: 2, child: Text('Homologação')),
                DropdownMenuItem(value: 1, child: Text('Produção')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _environment = value);
              },
            ),
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Homologação é o ambiente recomendado para testes. Produção exige certificado, CSC e autorização fiscal válidos.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            TextField(
              controller: _cscIdController,
              decoration: const InputDecoration(labelText: 'ID CSC (opcional)'),
            ),
            TextField(
              controller: _cscController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'CSC (não persistido)',
              ),
            ),
            TextField(
              controller: _certificatePathController,
              readOnly: true,
              onTap: _selectCertificateFile,
              decoration: const InputDecoration(
                labelText: 'Caminho do certificado A1',
              ),
            ),
            OutlinedButton.icon(
              onPressed: _selectCertificateFile,
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('Escolher arquivo PFX/P12'),
            ),
            TextField(
              controller: _certificatePasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Senha do certificado A1',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _loadCertificate,
              child: const Text('Carregar certificado A1'),
            ),
            OutlinedButton.icon(
              onPressed: _saveSettingsFromButton,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Salvar cadastro e certificado'),
            ),
            OutlinedButton.icon(
              onPressed: _consultServiceStatus,
              icon: const Icon(Icons.cloud_outlined),
              label: const Text('Consultar status do serviço'),
            ),
            Text(
              _status,
              style: TextStyle(
                color: _sefazResult?.isRejected == true
                    ? Colors.red.shade800
                    : null,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _generateAndAuthorizeNfce,
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Gerar, autorizar NFC-e teste e emitir PDF A4'),
            ),
            ElevatedButton(
              onPressed: _queue == null ? null : _generateXml,
              child: const Text('Gerar e persistir NFC-e offline'),
            ),
            OutlinedButton(
              onPressed: _renderDanfe,
              child: const Text('Visualizar DANFE HTML'),
            ),
            OutlinedButton(
              onPressed: _generateEscPos,
              child: const Text('Gerar cupom ESC/POS'),
            ),
            OutlinedButton(
              onPressed: () =>
                  _prepareDanfePdf(layout: DanfePdfLayout.nfceThermal80),
              child: const Text('Gerar DANFE cupom PDF (80 mm)'),
            ),
            OutlinedButton(
              onPressed: () => _prepareDanfePdf(layout: DanfePdfLayout.a4),
              child: const Text('Gerar DANFE A4 PDF'),
            ),
            OutlinedButton(
              onPressed: () => _showMessage(
                'Transmissão real exige endpoint oficial, certificado e autorização de homologação.',
              ),
              child: const Text('Transmitir pendentes (opt-in)'),
            ),
            const SizedBox(height: 8),
            Text('Documentos pendentes no SQLite: $_pendingCount'),
          ],
        ),
      ),
    );
  }

  Widget _buildSefazResponseTab() {
    final result = _sefazResult;
    final statusColor = result == null
        ? null
        : result.isAccepted
        ? Colors.green.shade800
        : result.isRejected
        ? Colors.red.shade800
        : Colors.orange.shade800;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Retorno da SEFAZ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: result == null
                    ? Text(_status)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            result.isAccepted
                                ? 'Operação aceita'
                                : result.isRejected
                                ? 'Operação rejeitada'
                                : 'Retorno não conclusivo',
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('HTTP: ${_sefazHttpStatus ?? '-'}'),
                          Text('cStat: ${result.statusCode}'),
                          Text('Motivo: ${result.reason}'),
                        ],
                      ),
              ),
            ),
            if (_sefazTechnicalError != null) ...[
              const SizedBox(height: 8),
              Text(
                'Detalhe técnico: $_sefazTechnicalError',
                style: TextStyle(color: Colors.red.shade800),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'XML retornado pela SEFAZ',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            SelectableText(_sefazResponseXml),
            const SizedBox(height: 16),
            const Text(
              'Histórico da demonstração',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (_history.isEmpty)
              const Text('Nenhum evento registrado.')
            else
              for (final entry in _history) Text(entry),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Documentos gerados',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'XML da NFC-e',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SelectableText(_xml),
            const SizedBox(height: 16),
            const Text(
              'Pré-visualização DANFE HTML',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SelectableText(_preview),
          ],
        ),
      ),
    );
  }
}
