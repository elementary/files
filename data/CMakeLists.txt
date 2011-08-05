configure_file(marlin.desktop.in ${CMAKE_CURRENT_BINARY_DIR}/marlin.desktop)
configure_file(marlin.service.cmake ${CMAKE_CURRENT_BINARY_DIR}/marlin.service)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/marlin.desktop DESTINATION share/applications)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/marlin.service DESTINATION share/dbus-1/services/)
