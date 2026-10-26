import Flutter
import Foundation
import UIKit
import Security

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    configureXsdChannel(with: engineBridge.applicationRegistrar.messenger())
    configureSecretChannel(with: engineBridge.applicationRegistrar.messenger())
  }

  private func configureSecretChannel(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "flutter_fiscal_lib/secret", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard let arguments = call.arguments as? [String: Any],
            let key = arguments["key"] as? String,
            !key.isEmpty,
            !key.contains("/"),
            !key.contains("\\") else {
        result(FlutterError(code: "INVALID_SECRET_KEY", message: "chave inválida", details: nil))
        return
      }
      let service = "flutter_fiscal_lib"
      let baseQuery: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: key,
      ]
      switch call.method {
      case "read":
        var query = baseQuery
        query[kSecReturnData as String] = true
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
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
        let status = SecItemAdd(
          (baseQuery.merging([kSecValueData as String: data]) { _, new in new }) as CFDictionary,
          nil
        )
        if status == errSecDuplicateItem {
          let updateStatus = SecItemUpdate(
            baseQuery as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
          )
          result(updateStatus == errSecSuccess ? nil : FlutterError(code: "SECRET_STORE_ERROR", message: "falha ao atualizar Keychain", details: updateStatus))
        } else {
          result(status == errSecSuccess ? nil : FlutterError(code: "SECRET_STORE_ERROR", message: "falha ao gravar Keychain", details: status))
        }
      case "delete":
        let status = SecItemDelete(baseQuery as CFDictionary)
        result(status == errSecSuccess || status == errSecItemNotFound ? nil : FlutterError(code: "SECRET_STORE_ERROR", message: "falha ao remover Keychain", details: status))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func configureXsdChannel(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "flutter_fiscal_lib/xsd", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "validate" else {
        if call.method == "validateBundle" {
          self.validateBundle(call: call, result: result)
          return
        }
        result(FlutterMethodNotImplemented)
        return
      }
      guard let arguments = call.arguments as? [String: Any],
            let schema = arguments["schema"] as? String,
            let xml = arguments["xml"] as? String,
            let schemaData = schema.data(using: .utf8),
            let xmlData = xml.data(using: .utf8),
            !schemaData.isEmpty,
            !xmlData.isEmpty else {
        result(["exitCode": 1, "stdout": "", "stderr": "schema e XML são obrigatórios"])
        return
      }
      var errorBuffer = [CChar](repeating: 0, count: 4096)
      let exitCode = schemaData.withUnsafeBytes { schemaBytes in
        xmlData.withUnsafeBytes { xmlBytes in
          FFValidateXsd(
            schemaBytes.bindMemory(to: CChar.self).baseAddress,
            Int32(schemaData.count),
            xmlBytes.bindMemory(to: CChar.self).baseAddress,
            Int32(xmlData.count),
            &errorBuffer,
            Int32(errorBuffer.count)
          )
        }
      }
      let message = String(cString: errorBuffer)
      result([
        "exitCode": exitCode,
        "stdout": exitCode == 0 ? "valid" : "",
        "stderr": message,
      ])
    }
  }

  private func validateBundle(
    call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard let arguments = call.arguments as? [String: Any],
          let schema = arguments["schema"] as? String,
          let xml = arguments["xml"] as? String,
          let rawResources = arguments["resources"] as? [String: String],
          !schema.isEmpty,
          !xml.isEmpty else {
      result(["exitCode": 1, "stdout": "", "stderr": "schema e XML são obrigatórios"])
      return
    }
    let fileManager = FileManager.default
    let root = fileManager.temporaryDirectory
      .appendingPathComponent("flutter_fiscal_lib_xsd_\(UUID().uuidString)")
    let schemaURL = root.appendingPathComponent("schema.xsd")
    let xmlURL = root.appendingPathComponent("document.xml")
    defer { try? fileManager.removeItem(at: root) }
    do {
      try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
      try Data(schema.utf8).write(to: schemaURL, options: .atomic)
      try Data(xml.utf8).write(to: xmlURL, options: .atomic)
      for (name, content) in rawResources {
        guard !name.hasPrefix("/"), !name.split(separator: "/").contains("..") else {
          result(["exitCode": 1, "stdout": "", "stderr": "recurso XSD inseguro"])
          return
        }
        let resourceURL = name.split(separator: "/").reduce(root) { url, component in
          url.appendingPathComponent(String(component))
        }
        try fileManager.createDirectory(
          at: resourceURL.deletingLastPathComponent(),
          withIntermediateDirectories: true
        )
        try Data(content.utf8).write(to: resourceURL, options: .atomic)
      }
      var errorBuffer = [CChar](repeating: 0, count: 4096)
      let exitCode = schemaURL.path.withCString { schemaPath in
        xmlURL.path.withCString { xmlPath in
          FFValidateXsdBundle(
            schemaPath,
            xmlPath,
            &errorBuffer,
            Int32(errorBuffer.count)
          )
        }
      }
      let message = String(cString: errorBuffer)
      result([
        "exitCode": exitCode,
        "stdout": exitCode == 0 ? "valid" : "",
        "stderr": message,
      ])
    } catch {
      result(["exitCode": 1, "stdout": "", "stderr": error.localizedDescription])
    }
  }
}
