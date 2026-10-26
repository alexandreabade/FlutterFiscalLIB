import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_fiscal_lib/flutter_fiscal_lib.dart';

/// Store de segredos do exemplo Flutter apoiado pelo cofre nativo da plataforma.
///
/// No Android, o canal usa uma chave AES-GCM gerenciada pelo Android Keystore
/// e persiste apenas o texto cifrado em SharedPreferences. No iOS, usa itens
/// `kSecClassGenericPassword` do Keychain. O núcleo fiscal continua sem
/// dependência de Flutter ou de um plugin específico.
class PlatformFiscalSecretStore implements FiscalSecretStore {
  /// Cria o store usando o canal nativo padrão ou um canal injetado em testes.
  const PlatformFiscalSecretStore({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('flutter_fiscal_lib/secret');

  final MethodChannel _channel;

  @override
  Future<Uint8List?> read(String key) async {
    final encoded = await _channel.invokeMethod<String>('read', {'key': key});
    return encoded == null ? null : Uint8List.fromList(base64Decode(encoded));
  }

  @override
  Future<void> write(String key, Uint8List value) async {
    await _channel.invokeMethod<void>('write', {
      'key': key,
      'value': base64Encode(value),
    });
  }

  @override
  Future<void> delete(String key) async {
    await _channel.invokeMethod<void>('delete', {'key': key});
  }
}
