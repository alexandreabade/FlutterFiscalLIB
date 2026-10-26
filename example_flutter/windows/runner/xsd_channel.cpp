#include "xsd_channel.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <comdef.h>
#include <windows.h>

#import <msxml6.dll> named_guids

#include <filesystem>
#include <fstream>
#include <map>
#include <string>
#include <utility>

namespace {
using flutter::EncodableMap;
using flutter::EncodableValue;

std::wstring utf8_to_wide(const std::string& value) {
  if (value.empty()) return {};
  const int size = MultiByteToWideChar(CP_UTF8, 0, value.data(),
                                      static_cast<int>(value.size()), nullptr, 0);
  std::wstring result(size, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, value.data(), static_cast<int>(value.size()),
                      result.data(), size);
  return result;
}

std::string wide_to_utf8(const std::wstring& value) {
  if (value.empty()) return {};
  const int size = WideCharToMultiByte(CP_UTF8, 0, value.data(),
                                       static_cast<int>(value.size()), nullptr, 0,
                                       nullptr, nullptr);
  std::string result(size, '\0');
  WideCharToMultiByte(CP_UTF8, 0, value.data(), static_cast<int>(value.size()),
                      result.data(), size, nullptr, nullptr);
  return result;
}

std::string parse_error(MSXML2::IXMLDOMParseErrorPtr error) {
  if (error == nullptr) return "O XML não passou no schema XSD.";
  return wide_to_utf8(static_cast<const wchar_t*>(error->Getreason()));
}

int validate_file(const std::filesystem::path& schema_path,
                  const std::filesystem::path& xml_path,
                  std::string* error) {
  try {
    MSXML2::IXMLDOMDocument2Ptr document;
    document.CreateInstance(__uuidof(MSXML2::DOMDocument60));
    document->async = VARIANT_FALSE;
    document->validateOnParse = VARIANT_TRUE;
    document->resolveExternals = VARIANT_FALSE;
    document->setProperty(_bstr_t(L"ProhibitDTD"), _variant_t(VARIANT_TRUE));

    MSXML2::IXMLDOMSchemaCollection2Ptr schemas;
    schemas.CreateInstance(__uuidof(MSXML2::XMLSchemaCache60));
    const _variant_t schema_path_variant(schema_path.wstring().c_str());
    MSXML2::IXMLDOMDocument2Ptr schema_document;
    schema_document.CreateInstance(__uuidof(MSXML2::DOMDocument60));
    schema_document->async = VARIANT_FALSE;
    schema_document->resolveExternals = VARIANT_FALSE;
    schema_document->setProperty(_bstr_t(L"ProhibitDTD"),
                                 _variant_t(VARIANT_TRUE));
    VARIANT_BOOL schema_loaded = VARIANT_FALSE;
    schema_document->load(schema_path_variant, &schema_loaded);
    if (schema_loaded != VARIANT_TRUE) {
      *error = parse_error(schema_document->parseError);
      return 1;
    }
    std::wstring namespace_uri;
    MSXML2::IXMLDOMNodePtr node =
        schema_document->selectSingleNode(_bstr_t(L"/*/@targetNamespace"));
    if (node != nullptr) namespace_uri = static_cast<const wchar_t*>(node->text);
    schemas->add(_bstr_t(namespace_uri.c_str()), schema_path_variant);
    document->schemas = schemas.GetInterfacePtr();
    VARIANT_BOOL loaded = VARIANT_FALSE;
    document->load(_variant_t(xml_path.wstring().c_str()), &loaded);
    if (loaded != VARIANT_TRUE) {
      *error = parse_error(document->parseError);
      return 1;
    }
    return 0;
  } catch (const _com_error& exception) {
    *error = wide_to_utf8(exception.ErrorMessage());
    return 1;
  }
}

EncodableValue result(int code, const std::string& error) {
  EncodableMap map;
  map[EncodableValue("exitCode")] = EncodableValue(code);
  map[EncodableValue("stdout")] = EncodableValue(code == 0 ? "valid" : "");
  map[EncodableValue("stderr")] = EncodableValue(error);
  return EncodableValue(std::move(map));
}

std::filesystem::path make_temp_directory() {
  wchar_t temp_path[MAX_PATH];
  wchar_t temp_name[MAX_PATH];
  const DWORD path_length = GetTempPathW(MAX_PATH, temp_path);
  if (path_length == 0 || path_length >= MAX_PATH ||
      GetTempFileNameW(temp_path, L"ffx", 0, temp_name) == 0) {
    return {};
  }
  DeleteFileW(temp_name);
  if (!CreateDirectoryW(temp_name, nullptr)) return {};
  return std::filesystem::path(temp_name);
}

EncodableValue validate(const EncodableMap& args, const std::string& method) {
  const auto schema_it = args.find(EncodableValue("schema"));
  const auto xml_it = args.find(EncodableValue("xml"));
  if (schema_it == args.end() || xml_it == args.end() ||
      !std::holds_alternative<std::string>(schema_it->second) ||
      !std::holds_alternative<std::string>(xml_it->second)) {
    return result(1, "schema e XML são obrigatórios");
  }
  const std::string schema = std::get<std::string>(schema_it->second);
  const std::string xml = std::get<std::string>(xml_it->second);
  const auto root = make_temp_directory();
  if (root.empty()) return result(1, "não foi possível criar diretório temporário");
  std::error_code filesystem_error;
  const auto schema_path = root / "schema.xsd";
  const auto xml_path = root / "document.xml";
  {
    std::ofstream schema_file(schema_path, std::ios::binary);
    std::ofstream xml_file(xml_path, std::ios::binary);
    if (!schema_file || !xml_file) {
      std::filesystem::remove_all(root, filesystem_error);
      return result(1, "não foi possível gravar os arquivos XSD temporários");
    }
    schema_file << schema;
    xml_file << xml;
    if (!schema_file.good() || !xml_file.good()) {
      std::filesystem::remove_all(root, filesystem_error);
      return result(1, "falha ao gravar os arquivos XSD temporários");
    }
  }
  if (method == "validateBundle") {
    const auto resources_it = args.find(EncodableValue("resources"));
    if (resources_it == args.end() ||
        !std::holds_alternative<EncodableMap>(resources_it->second)) {
      return result(1, "schema, XML e resources são obrigatórios");
    }
    for (const auto& entry : std::get<EncodableMap>(resources_it->second)) {
      if (!std::holds_alternative<std::string>(entry.first) ||
          !std::holds_alternative<std::string>(entry.second)) continue;
      const auto name = std::get<std::string>(entry.first);
      if (name.empty() || name[0] == '/' || name[0] == '\\' ||
          name.find("..") != std::string::npos || name.find(':') != std::string::npos) {
        return result(1, "recurso XSD inseguro");
      }
      const auto path = root / utf8_to_wide(name);
      std::filesystem::create_directories(path.parent_path(), filesystem_error);
      if (filesystem_error) {
        std::filesystem::remove_all(root, filesystem_error);
        return result(1, "não foi possível criar diretório de recurso XSD");
      }
      std::ofstream resource_file(path, std::ios::binary);
      if (!resource_file) {
        std::filesystem::remove_all(root, filesystem_error);
        return result(1, "não foi possível gravar recurso XSD temporário");
      }
      resource_file << std::get<std::string>(entry.second);
      if (!resource_file.good()) {
        std::filesystem::remove_all(root, filesystem_error);
        return result(1, "falha ao gravar recurso XSD temporário");
      }
    }
  } else if (method != "validate") {
    std::filesystem::remove_all(root, filesystem_error);
    return result(1, "método XSD não implementado");
  }
  std::string error;
  const int code = validate_file(schema_path, xml_path, &error);
  std::filesystem::remove_all(root, filesystem_error);
  return result(code, error);
}
}  // namespace

void RegisterXsdChannel(flutter::FlutterEngine* engine) {
  flutter::MethodChannel<EncodableValue> channel(
      engine->messenger(), "flutter_fiscal_lib/xsd",
      &flutter::StandardMethodCodec::GetInstance());
  channel.SetMethodCallHandler(
      [](const flutter::MethodCall<EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<EncodableValue>> response) {
        const auto* arguments = call.arguments();
        if (arguments == nullptr ||
            !std::holds_alternative<EncodableMap>(*arguments)) {
          response->Success(result(1, "schema e XML são obrigatórios"));
          return;
        }
        response->Success(
            validate(std::get<EncodableMap>(*arguments), call.method_name()));
      });
}
