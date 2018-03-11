include (Translations)

configure_file(io.elementary.files.service.cmake ${CMAKE_CURRENT_BINARY_DIR}/io.elementary.files.service)
configure_file(io.elementary.files-filemanager1.service.cmake ${CMAKE_CURRENT_BINARY_DIR}/io.elementary.files.FileManager1.service)
configure_file(io.elementary.files-pkexec.cmake ${CMAKE_CURRENT_BINARY_DIR}/io.elementary.files-pkexec)
configure_file(io.elementary.files.policy.xml.in.in ${CMAKE_CURRENT_BINARY_DIR}/io.elementary.files.policy.xml.in)

configure_file_translation(io.elementary.files.desktop.in ${CMAKE_CURRENT_BINARY_DIR}/io.elementary.files.desktop ${CMAKE_SOURCE_DIR}/po/)
configure_file_translation(io.elementary.files.appdata.xml.in ${CMAKE_CURRENT_BINARY_DIR}/io.elementary.files.appdata.xml ${CMAKE_SOURCE_DIR}/po/)
configure_file_translation(${CMAKE_CURRENT_BINARY_DIR}/io.elementary.files.policy.xml.in ${CMAKE_CURRENT_BINARY_DIR}/io.elementary.files.policy ${CMAKE_SOURCE_DIR}/po/)

install (FILES ${CMAKE_CURRENT_BINARY_DIR}/io.elementary.files.appdata.xml DESTINATION share/appdata)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/io.elementary.files.desktop DESTINATION share/applications)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/io.elementary.files.service DESTINATION share/dbus-1/services/)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/io.elementary.files.FileManager1.service DESTINATION share/dbus-1/services/)
install (PROGRAMS ${CMAKE_CURRENT_BINARY_DIR}/io.elementary.files-pkexec DESTINATION bin)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/io.elementary.files.policy DESTINATION share/polkit-1/actions/)

add_subdirectory (icons)
add_subdirectory (schemas)
