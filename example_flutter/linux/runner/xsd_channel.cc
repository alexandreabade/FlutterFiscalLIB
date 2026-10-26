#include "xsd_channel.h"

#include <libxml/parser.h>
#include <libxml/xmlschemas.h>

#include <glib.h>
#include <cstdarg>
#include <cstdio>
#include <cstring>
#include <mutex>
#include <string>

namespace {
std::mutex loader_mutex;

void collect_error(void* context, const char* message, ...) {
  if (context == nullptr || message == nullptr) return;
  auto* error = static_cast<std::string*>(context);
  va_list args;
  va_start(args, message);
  char buffer[1024];
  vsnprintf(buffer, sizeof(buffer), message, args);
  va_end(args);
  error->append(buffer);
}

int validate_document(xmlSchemaPtr schema, xmlDocPtr document,
                      std::string* error) {
  xmlSchemaValidCtxtPtr context = xmlSchemaNewValidCtxt(schema);
  if (context == nullptr) {
    error->append("Não foi possível criar o contexto de validação XSD.");
    return 1;
  }
  xmlSchemaSetValidErrors(context, collect_error, collect_error, error);
  const int result = xmlSchemaValidateDoc(context, document);
  xmlSchemaFreeValidCtxt(context);
  if (result != 0 && error->empty()) error->append("O XML não passou no schema XSD.");
  return result == 0 ? 0 : 1;
}

FlValue* response(int code, const std::string& error) {
  g_autoptr(FlValue) result = fl_value_new_map();
  fl_value_set_string_take(result, "exitCode", fl_value_new_int(code));
  fl_value_set_string_take(
      result, "stdout", fl_value_new_string(code == 0 ? "valid" : ""));
  fl_value_set_string_take(result, "stderr", fl_value_new_string(error.c_str()));
  return FL_VALUE(g_steal_pointer(&result));
}

int validate_memory(const gchar* schema_bytes, const gchar* xml_bytes,
                    std::string* error) {
  std::lock_guard<std::mutex> lock(loader_mutex);
  xmlExternalEntityLoader previous = xmlGetExternalEntityLoader();
  xmlSetExternalEntityLoader(xmlNoNetExternalEntityLoader);
  xmlSchemaParserCtxtPtr parser = xmlSchemaNewMemParserCtxt(
      schema_bytes, static_cast<int>(strlen(schema_bytes)));
  xmlSchemaPtr schema = parser == nullptr ? nullptr : xmlSchemaParse(parser);
  if (parser != nullptr) xmlSchemaFreeParserCtxt(parser);
  if (schema == nullptr) {
    error->append("Não foi possível compilar o schema XSD.");
    xmlSetExternalEntityLoader(previous);
    return 1;
  }
  xmlDocPtr document = xmlReadMemory(xml_bytes, static_cast<int>(strlen(xml_bytes)),
                                     nullptr, nullptr, XML_PARSE_NONET);
  const int result = document == nullptr
      ? 1
      : validate_document(schema, document, error);
  if (document == nullptr) error->append("O XML não pôde ser analisado com segurança.");
  else xmlFreeDoc(document);
  xmlSchemaFree(schema);
  xmlSetExternalEntityLoader(previous);
  return result;
}

int validate_bundle(const gchar* schema_path, const gchar* xml_path,
                    std::string* error) {
  std::lock_guard<std::mutex> lock(loader_mutex);
  xmlExternalEntityLoader previous = xmlGetExternalEntityLoader();
  xmlSetExternalEntityLoader(xmlNoNetExternalEntityLoader);
  xmlSchemaParserCtxtPtr parser = xmlSchemaNewParserCtxt(schema_path);
  xmlSchemaPtr schema = parser == nullptr ? nullptr : xmlSchemaParse(parser);
  if (parser != nullptr) xmlSchemaFreeParserCtxt(parser);
  if (schema == nullptr) {
    error->append("Não foi possível compilar o bundle XSD.");
    xmlSetExternalEntityLoader(previous);
    return 1;
  }
  xmlDocPtr document = xmlReadFile(xml_path, nullptr, XML_PARSE_NONET);
  const int result = document == nullptr
      ? 1
      : validate_document(schema, document, error);
  if (document == nullptr) error->append("O XML não pôde ser analisado com segurança.");
  else xmlFreeDoc(document);
  xmlSchemaFree(schema);
  xmlSetExternalEntityLoader(previous);
  return result;
}

void method_call_cb(FlMethodChannel*, FlMethodCall* call, gpointer) {
  const gchar* method = fl_method_call_get_name(call);
  FlValue* args = fl_method_call_get_args(call);
  FlValue* schema = fl_value_lookup_string(args, "schema");
  FlValue* xml = fl_value_lookup_string(args, "xml");
  std::string error;
  int code = 1;
  if (schema != nullptr && xml != nullptr &&
      fl_value_get_type(schema) == FL_VALUE_TYPE_STRING &&
      fl_value_get_type(xml) == FL_VALUE_TYPE_STRING) {
    if (g_strcmp0(method, "validate") == 0) {
      code = validate_memory(fl_value_get_string(schema), fl_value_get_string(xml), &error);
    } else if (g_strcmp0(method, "validateBundle") == 0) {
      FlValue* resources = fl_value_lookup_string(args, "resources");
      gchar* root = g_dir_make_tmp("flutter_fiscal_lib_xsd_XXXXXX", nullptr);
      if (root != nullptr && resources != nullptr &&
          fl_value_get_type(resources) == FL_VALUE_TYPE_MAP) {
        gchar* schema_path = g_build_filename(root, "schema.xsd", nullptr);
        gchar* xml_path = g_build_filename(root, "document.xml", nullptr);
        g_file_set_contents(schema_path, fl_value_get_string(schema), -1, nullptr);
        g_file_set_contents(xml_path, fl_value_get_string(xml), -1, nullptr);
        for (size_t i = 0; i < fl_value_get_length(resources); i++) {
          FlValue* key = fl_value_get_map_key(resources, i);
          FlValue* value = fl_value_get_map_value(resources, i);
          if (fl_value_get_type(key) != FL_VALUE_TYPE_STRING ||
              fl_value_get_type(value) != FL_VALUE_TYPE_STRING) continue;
          const gchar* name = fl_value_get_string(key);
          if (name[0] == '/' || strstr(name, "..") != nullptr) {
            error = "recurso XSD inseguro";
            code = 1;
            continue;
          }
          gchar* path = g_build_filename(root, name, nullptr);
          gchar* parent = g_path_get_dirname(path);
          g_mkdir_with_parents(parent, 0700);
          g_file_set_contents(path, fl_value_get_string(value), -1, nullptr);
          g_free(parent);
          g_free(path);
        }
        if (error.empty()) code = validate_bundle(schema_path, xml_path, &error);
        g_free(schema_path);
        g_free(xml_path);
      } else {
        error = "schema, XML e resources são obrigatórios";
      }
      if (root != nullptr) g_free(root);
    } else {
      g_autoptr(FlMethodResponse) response =
          FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
      fl_method_call_respond(call, response, nullptr);
      return;
    }
  } else {
    error = "schema e XML são obrigatórios";
  }
  g_autoptr(FlMethodResponse) result =
      FL_METHOD_RESPONSE(fl_method_success_response_new(response(code, error)));
  fl_method_call_respond(call, result, nullptr);
}
}  // namespace

void register_xsd_channel(FlView* view) {
  FlEngine* engine = fl_view_get_engine(view);
  FlBinaryMessenger* messenger = fl_engine_get_binary_messenger(engine);
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  FlMethodChannel* channel = fl_method_channel_new(
      messenger, "flutter_fiscal_lib/xsd", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb, nullptr, nullptr);
  // The runner owns this channel for the lifetime of the Flutter view.
}
