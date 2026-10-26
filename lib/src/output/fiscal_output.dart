import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../exceptions/fiscal_exception.dart';

/// Formatos que podem ser entregues a um adaptador de saída.
enum FiscalOutputFormat {
  /// PDF auxiliar, normalmente produzido por [DanfePdfRenderer].
  pdf,

  /// HTML autocontido, normalmente produzido por [DanfeHtmlRenderer].
  html,

  /// Texto determinístico para terminal ou impressora configurada.
  text,

  /// Bytes já codificados no protocolo da impressora, como ESC/POS.
  escPos,
}

/// Codificador mínimo e determinístico para impressoras ESC/POS.
///
/// O texto é codificado em UTF-8 por padrão. Impressoras que exigem uma
/// página de código específica podem fornecer [textEncoder] para converter o
/// conteúdo antes do envio. Os comandos de inicialização, alimentação e corte
/// são bytes ESC/POS puros e não dependem de plugins Flutter.
class EscPosEncoder {
  /// Cria um encoder ESC/POS.
  const EscPosEncoder({this.textEncoder = _utf8Encode});

  /// Conversor de texto para a página de código da impressora.
  final List<int> Function(String text) textEncoder;

  /// Codifica [text] com inicialização, alimentação e corte opcionais.
  Uint8List encode(
    String text, {
    bool initialize = true,
    int feedLines = 3,
    bool cut = true,
  }) {
    if (feedLines < 0 || feedLines > 20) {
      throw const FiscalValidationException(
        'A quantidade de linhas de alimentação ESC/POS deve estar entre 0 e 20.',
        code: 'INVALID_ESCPOS_FEED',
      );
    }
    final bytes = <int>[
      if (initialize) ...const [0x1b, 0x40],
      ...textEncoder(_sanitizeText(text)),
    ];
    if (text.isNotEmpty && !text.endsWith('\n')) bytes.add(0x0a);
    bytes.addAll(List<int>.filled(feedLines, 0x0a));
    if (cut) bytes.addAll(const [0x1d, 0x56, 0x00]);
    return Uint8List.fromList(bytes);
  }

  /// Retorna o comando ESC/POS de negrito.
  Uint8List bold(bool enabled) =>
      Uint8List.fromList([0x1b, 0x45, enabled ? 1 : 0]);

  /// Retorna o comando ESC/POS de alinhamento: 0 esquerda, 1 centro, 2 direita.
  Uint8List align(int value) {
    if (value < 0 || value > 2) {
      throw const FiscalValidationException(
        'O alinhamento ESC/POS deve ser 0, 1 ou 2.',
        code: 'INVALID_ESCPOS_ALIGNMENT',
      );
    }
    return Uint8List.fromList([0x1b, 0x61, value]);
  }

  static String _sanitizeText(String value) =>
      value.replaceAll(RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]'), '');
}

List<int> _utf8Encode(String value) => utf8.encode(value);

/// Trabalho imutável de impressão, compartilhamento ou envio.
class FiscalOutputJob {
  /// Cria um trabalho com cópia defensiva dos bytes.
  FiscalOutputJob({
    required Uint8List bytes,
    required this.format,
    required this.fileName,
    String? mimeType,
  }) : _bytes = Uint8List.fromList(bytes),
       mimeType = mimeType ?? _defaultMimeType(format) {
    if (_bytes.isEmpty) {
      throw const FiscalValidationException(
        'O trabalho de saída não pode estar vazio.',
        code: 'EMPTY_OUTPUT_JOB',
      );
    }
    if (fileName.trim().isEmpty ||
        fileName.contains('/') ||
        fileName.contains(r'\')) {
      throw const FiscalValidationException(
        'O nome do arquivo de saída é inválido.',
        code: 'INVALID_OUTPUT_FILE_NAME',
      );
    }
  }

  /// Bytes a serem enviados, como cópia defensiva.
  final Uint8List _bytes;

  /// Formato lógico do trabalho.
  final FiscalOutputFormat format;

  /// Nome sugerido para salvar ou compartilhar.
  final String fileName;

  /// MIME type do conteúdo.
  final String mimeType;

  /// Retorna os bytes sem expor o buffer interno.
  Uint8List get content => Uint8List.fromList(_bytes);
}

/// Contrato para impressão, compartilhamento ou integração nativa.
abstract interface class FiscalOutputAdapter {
  /// Entrega [job] ao destino configurado.
  Future<void> send(FiscalOutputJob job);
}

/// Adaptador para plugins Flutter de impressão, compartilhamento ou Bluetooth.
///
/// O callback recebe o trabalho já validado e pode encaminhá-lo para
/// `printing`, `share_plus`, um canal de plataforma ou um SDK Bluetooth sem
/// acoplar essas dependências ao núcleo fiscal.
class CallbackFiscalOutputAdapter implements FiscalOutputAdapter {
  /// Cria um adaptador baseado em callback assíncrono.
  const CallbackFiscalOutputAdapter(this.callback);

  /// Callback de entrega do trabalho.
  final FutureOr<void> Function(FiscalOutputJob job) callback;

  @override
  Future<void> send(FiscalOutputJob job) async {
    await callback(job);
  }
}

/// Ponte explícita para plugins Flutter de impressão ou compartilhamento de PDF.
///
/// O callback recebe uma cópia defensiva dos bytes e o trabalho original. A
/// aplicação pode encaminhar os dados para `printing`, `share_plus` ou um
/// canal nativo sem acoplar essas dependências ao núcleo fiscal.
class PdfFiscalOutputAdapter implements FiscalOutputAdapter {
  /// Cria uma ponte PDF baseada em callback assíncrono.
  const PdfFiscalOutputAdapter(this.callback);

  /// Callback que recebe os bytes PDF e seus metadados.
  final FutureOr<void> Function(Uint8List bytes, FiscalOutputJob job) callback;

  @override
  Future<void> send(FiscalOutputJob job) async {
    if (job.format != FiscalOutputFormat.pdf) {
      throw const FiscalValidationException(
        'O adaptador PDF exige uma saída no formato PDF.',
        code: 'PDF_OUTPUT_FORMAT_REQUIRED',
      );
    }
    await callback(job.content, job);
  }
}

/// Ponte explícita para plugins Flutter de impressão Bluetooth.
///
/// O núcleo não abre sockets Bluetooth nem escolhe um SDK nativo. O callback
/// recebe uma cópia dos bytes ESC/POS e pode encaminhá-los ao plugin da
/// aplicação, preservando a separação entre fiscalidade e plataforma.
class BluetoothFiscalOutputAdapter implements FiscalOutputAdapter {
  /// Cria uma ponte Bluetooth baseada no callback do aplicativo.
  const BluetoothFiscalOutputAdapter(this.callback);

  /// Callback que entrega os bytes e o trabalho original ao plugin nativo.
  final FutureOr<void> Function(Uint8List bytes, FiscalOutputJob job) callback;

  @override
  Future<void> send(FiscalOutputJob job) async {
    if (job.format != FiscalOutputFormat.escPos) {
      throw const FiscalValidationException(
        'O adaptador Bluetooth exige uma saída no formato ESC/POS.',
        code: 'BLUETOOTH_OUTPUT_FORMAT_REQUIRED',
      );
    }
    await callback(job.content, job);
  }
}

/// Adaptador desktop para salvar o trabalho em um arquivo.
class FileFiscalOutputAdapter implements FiscalOutputAdapter {
  /// Cria um adaptador que grava em [directoryPath].
  const FileFiscalOutputAdapter(this.directoryPath);

  /// Diretório controlado pela aplicação para os arquivos produzidos.
  final String directoryPath;

  @override
  Future<void> send(FiscalOutputJob job) async {
    final directory = Directory(directoryPath);
    await directory.create(recursive: true);
    await File(
      '${directory.path}${Platform.pathSeparator}${job.fileName}',
    ).writeAsBytes(job.content, flush: true);
  }
}

/// Adaptador para impressoras de rede que aceitam bytes TCP, como ESC/POS.
class TcpFiscalOutputAdapter implements FiscalOutputAdapter {
  /// Cria um destino TCP com timeout de conexão e escrita.
  const TcpFiscalOutputAdapter({
    required this.host,
    required this.port,
    this.timeout = const Duration(seconds: 10),
  });

  /// Endereço da impressora na rede local.
  final String host;

  /// Porta TCP do serviço de impressão.
  final int port;

  /// Limite para conexão e envio.
  final Duration timeout;

  @override
  Future<void> send(FiscalOutputJob job) async {
    if (host.trim().isEmpty ||
        port < 1 ||
        port > 65535 ||
        timeout <= Duration.zero) {
      throw const FiscalValidationException(
        'O destino TCP da saída possui host, porta ou timeout inválidos.',
        code: 'INVALID_OUTPUT_NETWORK_TARGET',
      );
    }
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      try {
        socket.add(job.content);
        await socket.flush().timeout(timeout);
      } finally {
        await socket.close();
      }
    } on Object catch (error) {
      throw FiscalException(
        'Falha ao enviar o trabalho para a impressora TCP $host:$port.',
        code: 'OUTPUT_NETWORK_ERROR',
        cause: error,
      );
    }
  }
}

String _defaultMimeType(FiscalOutputFormat format) => switch (format) {
  FiscalOutputFormat.pdf => 'application/pdf',
  FiscalOutputFormat.html => 'text/html; charset=utf-8',
  FiscalOutputFormat.text => 'text/plain; charset=utf-8',
  FiscalOutputFormat.escPos => 'application/octet-stream',
};
