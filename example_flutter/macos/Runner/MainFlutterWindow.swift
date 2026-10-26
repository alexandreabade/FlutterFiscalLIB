import Cocoa
import FlutterMacOS
import Foundation
import Security

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    XsdPlatformChannel.configure(with: flutterViewController.engine.binaryMessenger)
    SecretPlatformChannel.configure(with: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}

/// Persiste segredos do exemplo no Keychain do macOS.
final class SecretPlatformChannel {
  static func configure(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "flutter_fiscal_lib/secret",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      guard let arguments = call.arguments as? [String: Any],
            let key = arguments["key"] as? String,
            !key.isEmpty,
            !key.contains("/"),
            !key.contains("\\") else {
        result(FlutterError(code: "INVALID_SECRET_KEY", message: "chave inválida", details: nil))
        return
      }

      let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "flutter_fiscal_lib",
        kSecAttrAccount as String: key,
      ]

      switch call.method {
      case "read":
        var readQuery = query
        readQuery[kSecReturnData as String] = true
        var item: CFTypeRef?
        let status = SecItemCopyMatching(readQuery as CFDictionary, &item)
        if status == errSecItemNotFound {
          result(nil)
        } else if status == errSecSuccess, let data = item as? Data {
          result(data.base64EncodedString())
        } else {
          result(FlutterError(code: "SECRET_STORE_ERROR", message: "falha ao ler Keychain", details: status))
        }
      case "write":
        guard let encoded = arguments["value"] as? String,
              let data = Data(base64Encoded: encoded),
              !data.isEmpty else {
          result(FlutterError(code: "EMPTY_SECRET", message: "segredo vazio", details: nil))
          return
        }
        let addQuery = query.merging([kSecValueData as String: data]) { _, new in new }
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status == errSecDuplicateItem {
          let updateStatus = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
          )
          result(updateStatus == errSecSuccess ? nil : FlutterError(
            code: "SECRET_STORE_ERROR",
            message: "falha ao atualizar Keychain",
            details: updateStatus
          ))
        } else {
          result(status == errSecSuccess ? nil : FlutterError(
            code: "SECRET_STORE_ERROR",
            message: "falha ao gravar Keychain",
            details: status
          ))
        }
      case "delete":
        let status = SecItemDelete(query as CFDictionary)
        result(status == errSecSuccess || status == errSecItemNotFound ? nil : FlutterError(
          code: "SECRET_STORE_ERROR",
          message: "falha ao remover Keychain",
          details: status
        ))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
