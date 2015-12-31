# Include CMakeParseArguments macro for use below
include(CMakeParseArguments)

# ct_add_lib will add a library target to be compiled to the project.
# Usage:
# ct_add_lib(_target)
#   _target - Target name for the library being added
#   ENABLED [bool] - Flag enabling the adding of the library (default on)
#   INSTALL [bool] - Indicates the library should be installed on make install
#   BIN_DIR [dir] - The base directory to install shared library files to (defaults to bin)
#   HEADER_DIR [dir] - The base directory to install header files to (defaults to include/)
#   LIB_DIR [dir] - The base directory to install library files to (defaults to lib)
#   TYPE [STATIC/SHARED/BOTH] - The type of library to be installed (defaults to both)
#   VERSION [ver_string] - The full version of the library (defaults to none)
#   SOVERSION [so_ver] - The shared object version (defaults to none)
#   DEFINITIONS [.. ..] - One or more compiler definitions to use for library target
#   DEPENDS [.. ..] - One or more dependencies for library target
#   HEADERS [.. ..] - One or more header files to install with library
#   LIBS [.. ..] - One or more libraries to link library target against
#   SOURCES [.. ..] - One or more source files to compile into library target
function(ct_add_lib _target)
  # Set options that have no arguments
  set(_options)
  # Set one value arguments
  set(_oneValueArgs ENABLED INSTALL BIN_DIR HEADER_DIR LIB_DIR TYPE VERSION SOVERSION)
  # Set multi value arguments
  set(_multiValueArgs DEFINITIONS DEPENDS HEADERS LIBS SOURCES)

  # Parse the arguments provided into categories
  cmake_parse_arguments(_ct "${_options}" "${_oneValueArgs}" "${_multiValueArgs}" ${ARGN})

  # Verify that at least SOURCES was provided
  if(NOT DEFINED _ct_SOURCES)
    message(FATAL_ERROR "ct_add_lib requires SOURCES to be provided")
  endif()

  # If ENABLED was not defined then define it as ON
  if(NOT DEFINED _ct_ENABLED)
    set(_ct_ENABLED ON)
  endif()

  # If INSTALL was not defined then define it as ON
  if(NOT DEFINED _ct_INSTALL)
    set(_ct_INSTALL ON)
  endif()

  # If BIN_DIR was not defined then define it as bin
  if(NOT DEFINED _ct_BIN_DIR)
    set(_ct_BIN_DIR bin/)
  endif()

  # If HEADER_DIR was not defined then define it as include
  if(NOT DEFINED _ct_HEADER_DIR)
    set(_ct_HEADER_DIR include/)
  endif()

  # If LIB_DIR was not defined then define it as lib
  if(NOT DEFINED _ct_LIB_DIR)
    set(_ct_LIB_DIR lib)
  endif()

  # If TYPE was not defined then define it as both
  if(NOT DEFINED _ct_TYPE)
    set(_ct_TYPE BOTH)
  else()
    if(_ct_TYPE STREQUAL "SHARED")
      # OK
    elseif(_ct_TYPE STREQUAL "STATIC")
      # OK
    else()
      message(FATAL_ERROR "Bad TYPE '(${_ct_TYPE}'")
    endif()
  endif()

  if(_ct_ENABLED)
    if(_ct_TYPE STREQUAL "BOTH")
      # Add the object library target first
      add_library(${_target}-obj OBJECT ${_ct_HEADERS} ${_ct_SOURCES})

      # Add the shared library next
      add_library(${_target} SHARED $<TARGET_OBJECTS:${_target}-obj>)

      # Add the static library next (as lib${_target} on Windows 32)
      add_library(${_target}-static STATIC $<TARGET_OBJECTS:${_target}-obj>)
      set_target_properties(${_target}-static PROPERTIES OUTPUT_NAME ${_target})
      if(MSVC)
        set_target_properties(${_target}-static PROPERTIES PREFIX lib)
      endif()

      # Add unit test coverage compiler flags
      if(UNIT_TEST_COVERAGE)
        set(_ct_COVERAGE_DEFS "-fPIC --coverage")
        set_target_properties(${_target}-obj ${_target} ${_target}-static
          PROPERTIES LINK_FLAGS "--coverage")
      endif()

      # Add compiler definitions if defined
      if(_ct_DEFINITIONS OR UNIT_TEST_COVERAGE)
        set_target_properties(${_target}-obj ${_target} ${_target}-static
          PROPERTIES COMPILE_FLAGS "${_ct_COVERAGE_DEFS} ${_ct_DEFINITIONS}")
      endif()

      # Add link libraries if provided
      if(_ct_LIBS)
        target_link_libraries(${_target} ${_ct_LIBS})
      endif()

      # Add target dependencies if provided
      if(_ct_DEPENDS)
        add_dependencies(${_target} ${_ct_DEPENDS})
      endif()

      # Add target version and soversion properties
      if(_ct_VERSION AND _ct_SOVERSION)
        set_property(TARGET ${_target} PROPERTY VERSION "${_ct_VERSION}")
        set_property(TARGET ${_target} PROPERTY SOVERSION ${_ct_SOVERSION})
      endif()

      # Install the library built above?
      if(_ct_INSTALL)
        install(TARGETS ${_target} ${_target}-static
          RUNTIME DESTINATION ${_ct_BIN_DIR}
          LIBRARY DESTINATION ${_ct_LIB_DIR}
          ARCHIVE DESTINATION ${_ct_LIB_DIR})
      endif()
    else()
      # Add the static/shared library next
      add_library(${_target} ${_ct_TYPE} ${_ct_HEADERS} ${_ct_SOURCES})

      # Add compiler definitions if defined
      if(_ct_DEFINITIONS)
        set_target_properties(${_target} PROPERTIES COMPILE_FLAGS "${_ct_DEFINITIONS}")
      endif()

      # Add link libraries if provided
      if(_ct_LIBS)
        target_link_libraries(${_target} ${_ct_LIBS})
      endif()

      # Add target dependencies if provided
      if(_ct__DEPENDS)
        add_dependencies(${_target} ${_ct_DEPENDS})
      endif()

      # Add target version and soversion properties
      if(_ct_VERSION AND _ct_SOVERSION)
        set_property(TARGET ${_target} PROPERTY VERSION "${_ct_VERSION}")
        set_property(TARGET ${_target} PROPERTY SOVERSION ${_ct_SOVERSION})
      endif()

      # Install the library built above?
      if(_ct_INSTALL)
        install(TARGETS ${_target}
          RUNTIME DESTINATION ${_ct_BIN_DIR}
          LIBRARY DESTINATION ${_ct_LIB_DIR}
          ARCHIVE DESTINATION ${_ct_LIB_DIR})
      endif()
    endif()

    # Install public headers if provided (and INSTALL flag provided)
    if(_ct_INSTALL AND _ct_HEADERS)
      # Install each header file individually
      foreach(HEADER ${_ct_HEADERS})
        get_filename_component(_header_path ${HEADER} PATH)
        if(_header_path MATCHES "include[/\\](.*)[/\\]")
          # Results are in CMAKE_MATCH_1 used below
        elseif(_header_path MATCHES "include[/\\](.*)")
          # Results are in CMAKE_MATCH_1 used below
        elseif(_header_path MATCHES "inc[/\\](.*)[/\\]")
          # Results are in CMAKE_MATCH_1 used below
        elseif(_header_path MATCHES "inc[/\\](.*)")
          # Results are in CMAKE_MATCH_1 used below
        elseif(_header_path MATCHES "(.*)[/\\]")
          # Results are in CMAKE_MATCH_1 used below
        else()
          # Results are in CMAKE_MATCH_1 used below
        endif()
        # Add subdirectory found by MATCHES patterns above (if any)
        set(_subdir ${CMAKE_MATCH_1})
        # Install this header to the path provided (including subdir found)
        install(FILES ${HEADER}
          DESTINATION ${_ct_HEADER_DIR}${_subdir})
      endforeach()
    endif()
  endif()
endfunction()


# EOF
