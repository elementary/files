include (Translations)

configure_file(pantheon-files.service.cmake ${CMAKE_CURRENT_BINARY_DIR}/pantheon-files.service)
configure_file(pantheon-files-filemanager1.service.cmake ${CMAKE_CURRENT_BINARY_DIR}/io.elementary.pantheon-files.FileManager1.service)
configure_file(pantheon-files-pkexec.cmake ${CMAKE_CURRENT_BINARY_DIR}/pantheon-files-pkexec)
configure_file(net.launchpad.pantheon-files.policy.xml.in.in ${CMAKE_CURRENT_BINARY_DIR}/net.launchpad.pantheon-files.policy.xml.in)

configure_file_translation(pantheon-files.desktop.in ${CMAKE_CURRENT_BINARY_DIR}/org.pantheon.files.desktop ${CMAKE_SOURCE_DIR}/po/)
configure_file_translation(org.pantheon.files.appdata.xml.in ${CMAKE_CURRENT_BINARY_DIR}/org.pantheon.files.appdata.xml ${CMAKE_SOURCE_DIR}/po/)
configure_file_translation(${CMAKE_CURRENT_BINARY_DIR}/net.launchpad.pantheon-files.policy.xml.in ${CMAKE_CURRENT_BINARY_DIR}/net.launchpad.pantheon-files.policy ${CMAKE_SOURCE_DIR}/po/)

install (FILES ${CMAKE_CURRENT_BINARY_DIR}/org.pantheon.files.appdata.xml DESTINATION share/appdata)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/org.pantheon.files.desktop DESTINATION share/applications)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/pantheon-files.service DESTINATION share/dbus-1/services/)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/io.elementary.pantheon-files.FileManager1.service DESTINATION share/dbus-1/services/)
install (PROGRAMS ${CMAKE_CURRENT_BINARY_DIR}/pantheon-files-pkexec DESTINATION bin)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/net.launchpad.pantheon-files.policy DESTINATION share/polkit-1/actions/)

add_subdirectory (icons)
add_subdirectory (schemas)
