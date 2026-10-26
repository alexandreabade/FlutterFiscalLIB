import 'dart:typed_data';

import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';
import 'package:test/test.dart';

void main() {
  test('store em memória protege cópias e remove segredos', () async {
    final store = InMemoryFiscalSecretStore();
    final source = Uint8List.fromList([1, 2, 3]);
    await store.write('certificate', source);
    source[0] = 9;

    final first = await store.read('certificate');
    expect(first, [1, 2, 3]);
    first![1] = 8;
    expect(await store.read('certificate'), [1, 2, 3]);

    await store.delete('certificate');
    expect(await store.read('certificate'), isNull);
  });

  test('adaptador por callback valida chave e copia buffers', () async {
    final values = <String, Uint8List>{};
    final store = CallbackFiscalSecretStore(
      onRead: (key) async => values[key],
      onWrite: (key, value) async => values[key] = value,
      onDelete: (key) async => values.remove(key),
    );
    final source = Uint8List.fromList([4, 5]);
    await store.write('pfx', source);
    source[0] = 0;
    expect(await store.read('pfx'), [4, 5]);

    expect(
      () => store.write('../pfx', Uint8List.fromList([1])),
      throwsA(isA<FiscalValidationException>()),
    );
    expect(
      () => store.write('pfx', Uint8List(0)),
      throwsA(isA<FiscalValidationException>()),
    );
  });
}
