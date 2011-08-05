configure_file(marlin.desktop.in ${CMAKE_CURRENT_BINARY_DIR}/marlin.desktop)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/marlin.desktop DESTINATION share/applications)
