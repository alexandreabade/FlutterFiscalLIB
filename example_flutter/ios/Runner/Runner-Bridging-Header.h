#import "GeneratedPluginRegistrant.h"

int FFValidateXsd(const char *schema_bytes,
                  int schema_length,
                  const char *xml_bytes,
                  int xml_length,
                  char *error_buffer,
                  int error_length);

int FFValidateXsdBundle(const char *schema_path,
                        const char *xml_path,
                        char *error_buffer,
                        int error_length);
