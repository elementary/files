set(MARLIN_SCHEMAS "org.gnome.marlin.gschema.xml" "org.gnome.marlin.plugins.gschema.xml")
	
execute_process (COMMAND ${PKG_CONFIG_EXECUTABLE} glib-2.0 --variable prefix OUTPUT_VARIABLE _glib_prefix OUTPUT_STRIP_TRAILING_WHITESPACE)
set(GSETTINGS_DIR "${_glib_prefix}/share/glib-2.0/schemas/")
execute_process (COMMAND ${PKG_CONFIG_EXECUTABLE} gio-2.0 --variable glib_compile_schemas  OUTPUT_VARIABLE _glib_comple_schemas OUTPUT_STRIP_TRAILING_WHITESPACE)
execute_process (COMMAND ${_glib_comple_schemas} --dry-run --schema-file=${CMAKE_CURRENT_SOURCE_DIR}/${MARLIN_SCHEMAS} ERROR_VARIABLE _schemas_invalid OUTPUT_STRIP_TRAILING_WHITESPACE)
if (_schemas_invalid)
message (SEND_ERROR "Schema validation error: ${_schemas_invalid}")
endif (_schemas_invalid)
# Actually install and recomple schemas

message (STATUS "GSettings schemas will be installed into ${GSETTINGS_DIR}")
install (FILES ${MARLIN_SCHEMAS} DESTINATION ${GSETTINGS_DIR} OPTIONAL)
install (CODE "message (STATUS \"Compiling GSettings schemas\")
")
install (CODE "execute_process (COMMAND ${_glib_comple_schemas} ${GSETTINGS_DIR})
")
