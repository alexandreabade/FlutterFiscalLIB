import FlutterMacOS
import Foundation

final class XsdPlatformChannel {
  static func configure(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "flutter_fiscal_lib/xsd", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "validate":
        validate(call: call, result: result)
      case "validateBundle":
        validateBundle(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func validate(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any],
          let schema = arguments["schema"] as? String,
          let xml = arguments["xml"] as? String,
          !schema.isEmpty, !xml.isEmpty else {
      result(["exitCode": 1, "stdout": "", "stderr": "schema e XML são obrigatórios"])
      return
    }
    var error = [CChar](repeating: 0, count: 4096)
    let code = schema.utf8CString.withUnsafeBufferPointer { schemaBytes in
      xml.utf8CString.withUnsafeBufferPointer { xmlBytes in
        FFValidateXsd(schemaBytes.baseAddress, Int32(schema.utf8.count),
                      xmlBytes.baseAddress, Int32(xml.utf8.count),
                      &error, Int32(error.count))
      }
    }
    result(["exitCode": code, "stdout": code == 0 ? "valid" : "",
            "stderr": String(cString: error)])
  }

  private static func validateBundle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any],
          let schema = arguments["schema"] as? String,
          let xml = arguments["xml"] as? String,
          let resources = arguments["resources"] as? [String: String],
          !schema.isEmpty, !xml.isEmpty else {
      result(["exitCode": 1, "stdout": "", "stderr": "schema e XML são obrigatórios"])
      return
    }
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("flutter_fiscal_lib_xsd_\(UUID().uuidString)")
    let schemaURL = root.appendingPathComponent("schema.xsd")
    let xmlURL = root.appendingPathComponent("document.xml")
    defer { try? FileManager.default.removeItem(at: root) }
    do {
      try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
      try Data(schema.utf8).write(to: schemaURL, options: .atomic)
      try Data(xml.utf8).write(to: xmlURL, options: .atomic)
      for (name, content) in resources {
        guard !name.hasPrefix("/"), !name.split(separator: "/").contains("..") else {
          result(["exitCode": 1, "stdout": "", "stderr": "recurso XSD inseguro"])
          return
        }
        let resourceURL = name.split(separator: "/").reduce(root) {
          $0.appendingPathComponent(String($1))
        }
        try FileManager.default.createDirectory(
          at: resourceURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(content.utf8).write(to: resourceURL, options: .atomic)
      }
      var error = [CChar](repeating: 0, count: 4096)
      let code = schemaURL.path.withCString { schemaPath in
        xmlURL.path.withCString { xmlPath in
          FFValidateXsdBundle(schemaPath, xmlPath, &error, Int32(error.count))
        }
      }
      result(["exitCode": code, "stdout": code == 0 ? "valid" : "",
              "stderr": String(cString: error)])
    } catch {
      result(["exitCode": 1, "stdout": "", "stderr": error.localizedDescription])
    }
  }
}
