import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';
import 'package:test/test.dart';

void main() {
  test('monta chave pelos componentes fiscais', () {
    final key = AccessKey.fromComponents(
      cUf: '11',
      issueDate: DateTime.utc(2026, 1, 1),
      cnpj: '04.252.011/0001-10',
      model: 55,
      series: 1,
      number: 1,
      tpEmis: 1,
      cNf: '12345678',
    );

    expect(key.value, hasLength(44));
    expect(key.value.substring(0, 2), '11');
    expect(key.value.substring(20, 22), '55');
    expect(key.value[34], '1');
    expect(AccessKey.isValid(key.value), isTrue);
  });

  test('calcula SHA-256 determinístico em hexadecimal e Base64', () {
    expect(
      XmlDigest.hex('abc'),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
    expect(
      XmlDigest.base64('abc'),
      'ungWv48Bz+pBQUDeXa4iI7ADYaOWF3qctBD/YfIAFa0=',
    );
  });

  test('calcula SHA-1 determinístico para XMLDSig fiscal', () {
    expect(
      XmlDigest.hex('abc', algorithm: XmlDigestAlgorithm.sha1),
      'a9993e364706816aba3e25717850c26c9cd0d89d',
    );
    expect(
      XmlDigest.base64('abc', algorithm: XmlDigestAlgorithm.sha1),
      'qZk+NkcGgWq6PiVxeFDCbJzQ2J0=',
    );
  });
}
