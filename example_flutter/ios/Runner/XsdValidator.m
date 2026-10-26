#include <libxml/parser.h>
#include <libxml/xmlschemas.h>

#include <stdarg.h>
#include <pthread.h>
#include <stdio.h>
#include <string.h>

static pthread_mutex_t loader_mutex = PTHREAD_MUTEX_INITIALIZER;

static void append_error(void *context, const char *message, ...) {
  if (context == NULL || message == NULL) {
    return;
  }
  char *buffer = (char *)context;
  size_t current = strlen(buffer);
  const size_t capacity = 4096;
  if (current >= capacity - 1) {
    return;
  }
  va_list arguments;
  va_start(arguments, message);
  vsnprintf(buffer + current, capacity - current, message, arguments);
  va_end(arguments);
}

int FFValidateXsd(const char *schema_bytes,
                 int schema_length,
                 const char *xml_bytes,
                 int xml_length,
                 char *error_buffer,
                 int error_length) {
  if (schema_bytes == NULL || schema_length <= 0 || xml_bytes == NULL ||
      xml_length <= 0 || error_buffer == NULL || error_length <= 0) {
    return 1;
  }
  error_buffer[0] = '\0';

  // libxml2 keeps this loader process-global. Restrict the operation to the
  // non-network loader and restore the previous loader on every exit path.
  pthread_mutex_lock(&loader_mutex);
  xmlExternalEntityLoader previous_loader = xmlGetExternalEntityLoader();
  xmlSetExternalEntityLoader(xmlNoNetExternalEntityLoader);

  xmlSchemaParserCtxtPtr parser =
      xmlSchemaNewMemParserCtxt(schema_bytes, schema_length);
  if (parser == NULL) {
    snprintf(error_buffer, (size_t)error_length,
             "Não foi possível criar o contexto XSD.");
    xmlSetExternalEntityLoader(previous_loader);
    pthread_mutex_unlock(&loader_mutex);
    return 1;
  }
  xmlSchemaSetParserErrors(parser, append_error, append_error, error_buffer);
  xmlSchemaPtr schema = xmlSchemaParse(parser);
  xmlSchemaFreeParserCtxt(parser);
  if (schema == NULL) {
    if (error_buffer[0] == '\0') {
      snprintf(error_buffer, (size_t)error_length,
               "Não foi possível compilar o schema XSD.");
    }
    xmlSetExternalEntityLoader(previous_loader);
    pthread_mutex_unlock(&loader_mutex);
    return 1;
  }

  xmlDocPtr document = xmlReadMemory(
      xml_bytes, xml_length, NULL, NULL, XML_PARSE_NONET | XML_PARSE_NOERROR);
  if (document == NULL) {
    snprintf(error_buffer, (size_t)error_length,
             "O XML não pôde ser analisado com segurança.");
    xmlSchemaFree(schema);
    xmlSetExternalEntityLoader(previous_loader);
    pthread_mutex_unlock(&loader_mutex);
    return 1;
  }

  xmlSchemaValidCtxtPtr validator = xmlSchemaNewValidCtxt(schema);
  if (validator == NULL) {
    snprintf(error_buffer, (size_t)error_length,
             "Não foi possível criar o contexto de validação XSD.");
    xmlFreeDoc(document);
    xmlSchemaFree(schema);
    xmlSetExternalEntityLoader(previous_loader);
    pthread_mutex_unlock(&loader_mutex);
    return 1;
  }
  xmlSchemaSetValidErrors(validator, append_error, append_error, error_buffer);
  const int result = xmlSchemaValidateDoc(validator, document);
  xmlSchemaFreeValidCtxt(validator);
  xmlFreeDoc(document);
  xmlSchemaFree(schema);
  if (result != 0 && error_buffer[0] == '\0') {
    snprintf(error_buffer, (size_t)error_length,
             "O XML não passou no schema XSD.");
  }
  xmlSetExternalEntityLoader(previous_loader);
  pthread_mutex_unlock(&loader_mutex);
  return result == 0 ? 0 : 1;
}

int FFValidateXsdBundle(const char *schema_path,
                        const char *xml_path,
                        char *error_buffer,
                        int error_length) {
  if (schema_path == NULL || xml_path == NULL || error_buffer == NULL ||
      error_length <= 0) {
    return 1;
  }
  error_buffer[0] = '\0';
  pthread_mutex_lock(&loader_mutex);
  xmlExternalEntityLoader previous_loader = xmlGetExternalEntityLoader();
  xmlSetExternalEntityLoader(xmlNoNetExternalEntityLoader);

  xmlSchemaParserCtxtPtr parser = xmlSchemaNewParserCtxt(schema_path);
  if (parser == NULL) {
    snprintf(error_buffer, (size_t)error_length,
             "Não foi possível abrir o schema XSD.");
    xmlSetExternalEntityLoader(previous_loader);
    pthread_mutex_unlock(&loader_mutex);
    return 1;
  }
  xmlSchemaSetParserErrors(parser, append_error, append_error, error_buffer);
  xmlSchemaPtr schema = xmlSchemaParse(parser);
  xmlSchemaFreeParserCtxt(parser);
  if (schema == NULL) {
    if (error_buffer[0] == '\0') {
      snprintf(error_buffer, (size_t)error_length,
               "Não foi possível compilar o bundle XSD.");
    }
    xmlSetExternalEntityLoader(previous_loader);
    pthread_mutex_unlock(&loader_mutex);
    return 1;
  }
  xmlDocPtr document =
      xmlReadFile(xml_path, NULL, XML_PARSE_NONET | XML_PARSE_NOERROR);
  if (document == NULL) {
    snprintf(error_buffer, (size_t)error_length,
             "O XML não pôde ser analisado com segurança.");
    xmlSchemaFree(schema);
    xmlSetExternalEntityLoader(previous_loader);
    pthread_mutex_unlock(&loader_mutex);
    return 1;
  }
  xmlSchemaValidCtxtPtr validator = xmlSchemaNewValidCtxt(schema);
  if (validator == NULL) {
    snprintf(error_buffer, (size_t)error_length,
             "Não foi possível criar o contexto de validação XSD.");
    xmlFreeDoc(document);
    xmlSchemaFree(schema);
    xmlSetExternalEntityLoader(previous_loader);
    pthread_mutex_unlock(&loader_mutex);
    return 1;
  }
  xmlSchemaSetValidErrors(validator, append_error, append_error, error_buffer);
  const int result = xmlSchemaValidateDoc(validator, document);
  xmlSchemaFreeValidCtxt(validator);
  xmlFreeDoc(document);
  xmlSchemaFree(schema);
  if (result != 0 && error_buffer[0] == '\0') {
    snprintf(error_buffer, (size_t)error_length,
             "O XML não passou no bundle XSD.");
  }
  xmlSetExternalEntityLoader(previous_loader);
  pthread_mutex_unlock(&loader_mutex);
  return result == 0 ? 0 : 1;
}
