import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';
import 'package:test/test.dart';

void main() {
  test('codifica texto ESC/POS com comandos e sanitização', () {
    final bytes = EscPosEncoder().encode(
      'Cupom\x1b\n',
      initialize: false,
      feedLines: 1,
    );

    expect(bytes.sublist(0, 5), [67, 117, 112, 111, 109]);
    expect(bytes, contains(0x0a));
    expect(bytes.sublist(bytes.length - 3), [0x1d, 0x56, 0x00]);
    expect(bytes, isNot(contains(0x1b)));
  });

  test('valida comandos ESC/POS e permite encoder de página', () {
    final encoder = EscPosEncoder(textEncoder: (text) => text.codeUnits);
    expect(encoder.encode('ABC', initialize: false, feedLines: 0, cut: false), [
      65,
      66,
      67,
      10,
    ]);
    expect(encoder.bold(true), [0x1b, 0x45, 1]);
    expect(encoder.align(2), [0x1b, 0x61, 2]);
    expect(
      () => encoder.encode('x', feedLines: 21),
      throwsA(isA<FiscalValidationException>()),
    );
    expect(() => encoder.align(3), throwsA(isA<FiscalValidationException>()));
  });

  test('trabalho de saída protege bytes e deriva MIME type', () {
    final source = Uint8List.fromList([1, 2, 3]);
    final job = FiscalOutputJob(
      bytes: source,
      format: FiscalOutputFormat.pdf,
      fileName: 'danfe.pdf',
    );
    source[0] = 9;
    final content = job.content;
    content[1] = 8;

    expect(job.content, [1, 2, 3]);
    expect(job.mimeType, 'application/pdf');
  });

  test(
    'callback recebe o trabalho e adaptador de arquivo grava conteúdo',
    () async {
      FiscalOutputJob? received;
      final callback = CallbackFiscalOutputAdapter((job) => received = job);
      final job = FiscalOutputJob(
        bytes: Uint8List.fromList([7, 8]),
        format: FiscalOutputFormat.escPos,
        fileName: 'cupom.bin',
      );
      await callback.send(job);
      expect(received?.content, [7, 8]);

      final directory = await Directory.systemTemp.createTemp('fiscal-output-');
      try {
        await FileFiscalOutputAdapter(directory.path).send(job);
        expect(
          await File(
            '${directory.path}${Platform.pathSeparator}cupom.bin',
          ).readAsBytes(),
          [7, 8],
        );
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  test('ponte Bluetooth entrega uma cópia de bytes ESC/POS', () async {
    Uint8List? received;
    final adapter = BluetoothFiscalOutputAdapter((bytes, _) {
      received = bytes;
    });
    final job = FiscalOutputJob(
      bytes: Uint8List.fromList([7, 8]),
      format: FiscalOutputFormat.escPos,
      fileName: 'cupom.bin',
    );

    await adapter.send(job);
    received![0] = 99;
    expect(received, [99, 8]);
    expect(job.content, [7, 8]);
  });

  test(
    'ponte PDF entrega uma cópia para impressão ou compartilhamento',
    () async {
      Uint8List? received;
      final adapter = PdfFiscalOutputAdapter((bytes, _) {
        received = bytes;
      });
      final job = FiscalOutputJob(
        bytes: Uint8List.fromList([0x25, 0x50, 0x44, 0x46]),
        format: FiscalOutputFormat.pdf,
        fileName: 'danfe.pdf',
      );

      await adapter.send(job);

      expect(received, [0x25, 0x50, 0x44, 0x46]);
      expect(received, isNot(same(job.content)));
    },
  );

  test('ponte PDF rejeita formatos que não são PDF', () async {
    final adapter = PdfFiscalOutputAdapter((_, __) {});
    final job = FiscalOutputJob(
      bytes: Uint8List.fromList([1, 2, 3]),
      format: FiscalOutputFormat.escPos,
      fileName: 'cupom.bin',
    );

    expect(
      () => adapter.send(job),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'PDF_OUTPUT_FORMAT_REQUIRED',
        ),
      ),
    );
  });

  test('ponte Bluetooth rejeita PDF e HTML', () async {
    final adapter = BluetoothFiscalOutputAdapter((_, __) {});
    final job = FiscalOutputJob(
      bytes: Uint8List.fromList([1]),
      format: FiscalOutputFormat.pdf,
      fileName: 'danfe.pdf',
    );
    expect(
      adapter.send(job),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'BLUETOOTH_OUTPUT_FORMAT_REQUIRED',
        ),
      ),
    );
  });

  test('adaptador TCP entrega bytes a uma impressora de rede', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final received = server.first.then((socket) async {
      final bytes = await socket.fold<List<int>>(
        <int>[],
        (previous, chunk) => [...previous, ...chunk],
      );
      await socket.close();
      return bytes;
    });
    try {
      await TcpFiscalOutputAdapter(
        host: InternetAddress.loopbackIPv4.address,
        port: server.port,
      ).send(
        FiscalOutputJob(
          bytes: Uint8List.fromList([10, 20, 30]),
          format: FiscalOutputFormat.escPos,
          fileName: 'cupom.bin',
        ),
      );
      expect(await received.timeout(const Duration(seconds: 2)), [10, 20, 30]);
    } finally {
      await server.close();
    }
  });

  test('rejeita trabalho sem bytes ou com nome inseguro', () {
    expect(
      () => FiscalOutputJob(
        bytes: Uint8List(0),
        format: FiscalOutputFormat.text,
        fileName: 'saida.txt',
      ),
      throwsA(isA<FiscalValidationException>()),
    );
    expect(
      () => FiscalOutputJob(
        bytes: Uint8List.fromList([1]),
        format: FiscalOutputFormat.text,
        fileName: '../saida.txt',
      ),
      throwsA(isA<FiscalValidationException>()),
    );
  });

  test('rejeita destino TCP inválido antes de conectar', () async {
    final adapter = TcpFiscalOutputAdapter(
      host: '',
      port: 70000,
      timeout: Duration.zero,
    );
    final job = FiscalOutputJob(
      bytes: Uint8List.fromList([1]),
      format: FiscalOutputFormat.escPos,
      fileName: 'cupom.bin',
    );
    expect(
      adapter.send(job),
      throwsA(
        isA<FiscalValidationException>().having(
          (error) => error.code,
          'code',
          'INVALID_OUTPUT_NETWORK_TARGET',
        ),
      ),
    );
  });
}
