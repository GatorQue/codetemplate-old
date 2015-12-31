set(CMAKE_FIND_LIBRARY_PREFIXES @CMAKE_FIND_LIBRARY_PREFIXES@)
set(CMAKE_FIND_LIBRARY_SUFFIXES @CMAKE_FIND_LIBRARY_SUFFIXES@)

# Add cmake/modules directory if it exists
if(EXISTS @PROJECT_SOURCE_DIR@/cmake/Modules)
  set(CMAKE_MODULE_PATH @PROJECT_SOURCE_DIR@/cmake/Modules ${CMAKE_MODULE_PATH})
endif()

set(${_ct_ROOT_HINT_VAR} @_ct_INSTALL_DIR@)

find_package(@_FIND_PACKAGE_ARGS@)
if(NOT @_ct_FOUND_VAR@)
  message(FATAL_ERROR "@_ct_PACKAGE@ not found")
endif()
