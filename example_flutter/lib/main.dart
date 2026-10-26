import 'package:flutter/material.dart';
import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';
import 'package:file_selector/file_selector.dart';

import 'offline_database.dart';

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
  final _history = <String>[];
  final _issuerNameController = TextEditingController(
    text: 'Empresa de Demonstração',
  );
  final _issuerCnpjController = TextEditingController(text: '04252011000110');
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
  late final Future<ExampleFiscalDatabase> _database;
  NfceOfflineQueue? _queue;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _database = openExampleDatabase().then((database) {
      _queue = NfceOfflineQueue(store: DriftFiscalDocumentStore(database));
      _refreshPendingCount();
      return database;
    });
  }

  Future<void> _generateXml() async {
    final queue = _queue;
    if (queue == null) return;
    final issuerName = _issuerNameController.text.trim();
    final issuerCnpj = _issuerCnpjController.text.trim();
    final productDescription = _productController.text.trim();
    final issueDate = DateTime.utc(2026, 1, 1);
    final database = await _database;
    final documentNumber = await DriftFiscalNumberAllocator(
      database,
    ).reserve(cUf: '11', issuerCnpj: issuerCnpj, model: 65, series: 1);
    final document = NfeDocument(
      accessKey: AccessKey.fromComponents(
        cUf: '11',
        issueDate: issueDate,
        cnpj: issuerCnpj,
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
      issuer: Party(
        name: issuerName,
        cnpj: issuerCnpj,
        address: 'Rua Fiscal',
        addressNumber: '1',
        neighborhood: 'Centro',
        cityCode: '1100015',
        city: 'Alta Floresta D Oeste',
        state: 'RO',
        zipCode: '76954000',
        crt: '1',
      ),
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

  Future<void> _prepareDanfePdf() async {
    final document = _document;
    if (document == null) {
      _showMessage('Gere uma NFC-e antes de preparar o PDF.');
      return;
    }
    final pdf = await DanfePdfRenderer().render(
      document,
      layout: DanfePdfLayout.nfceThermal80,
    );
    var deliveredBytes = 0;
    final adapter = PdfFiscalOutputAdapter((bytes, _) {
      deliveredBytes = bytes.length;
    });
    await adapter.send(
      FiscalOutputJob(
        bytes: pdf,
        format: FiscalOutputFormat.pdf,
        fileName: 'nfce-${document.accessKey}.pdf',
      ),
    );
    if (mounted) {
      setState(() {
        _status =
            'PDF DANFE preparado e entregue ao adaptador Flutter: $deliveredBytes bytes.';
        _history.insert(0, 'DANFE PDF preparado ($deliveredBytes bytes)');
      });
    }
  }

  Future<void> _loadCertificate() async {
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
    } on Object catch (error) {
      _showMessage('Falha ao carregar certificado: $error');
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
      final config = SefazEndpointCatalog.clientConfig(
        uf: 'RO',
        model: 65,
        environment: _environment,
        certificate: identity,
      );
      final client = SefazClient.fromConfig(config);
      final response = await client.sefazStatusServico(
        cUf: '11',
        environment: _environment,
      );
      if (mounted) {
        setState(() {
          _status =
              'Status SEFAZ: HTTP ${response.statusCode} — ${response.body}';
          _history.insert(
            0,
            'Consulta de status realizada (${_environment == 1 ? 'produção' : 'homologação'})',
          );
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _status = 'Falha na consulta de status: $error');
      }
    }
  }

  void _generateEscPos() {
    final document = _document;
    if (document == null) {
      _showMessage('Gere uma NFC-e antes de gerar o cupom ESC/POS.');
      return;
    }
    final text = DanfeTextRenderer().render(document);
    final bytes = EscPosEncoder().encode(text);
    if (mounted) {
      setState(() {
        _status =
            'Cupom ESC/POS preparado: ${bytes.length} bytes. Envie por TCP, USB ou Bluetooth usando um adaptador do aplicativo.';
        _history.insert(0, 'Cupom ESC/POS preparado (${bytes.length} bytes)');
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
    _issuerCnpjController.dispose();
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
    return Scaffold(
      appBar: AppBar(title: const Text('FlutterFiscalLIB')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Configuração da demonstração',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextField(
                controller: _issuerNameController,
                decoration: const InputDecoration(labelText: 'Emitente'),
              ),
              TextField(
                controller: _issuerCnpjController,
                decoration: const InputDecoration(
                  labelText: 'CNPJ do emitente',
                ),
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
                decoration: const InputDecoration(
                  labelText: 'ID CSC (opcional)',
                ),
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
                onPressed: _consultServiceStatus,
                icon: const Icon(Icons.cloud_outlined),
                label: const Text('Consultar status do serviço'),
              ),
              Text(_status),
              const SizedBox(height: 12),
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
                child: const Text('Preparar cupom ESC/POS'),
              ),
              OutlinedButton(
                onPressed: _prepareDanfePdf,
                child: const Text('Preparar PDF DANFE'),
              ),
              OutlinedButton(
                onPressed: () => _showMessage(
                  'Transmissão real exige endpoint oficial, certificado e autorização de homologação.',
                ),
                child: const Text('Transmitir pendentes (opt-in)'),
              ),
              const SizedBox(height: 8),
              Text('Documentos pendentes no SQLite: $_pendingCount'),
              const SizedBox(height: 12),
              const Text(
                'XML da NFC-e',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SelectableText(_xml),
              const SizedBox(height: 12),
              const Text(
                'Pré-visualização DANFE HTML',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SelectableText(_preview),
              const SizedBox(height: 12),
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
      ),
    );
  }
}
