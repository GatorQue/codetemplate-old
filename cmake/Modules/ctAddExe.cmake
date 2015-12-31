# Include CMakeParseArguments macro for use below
include(CMakeParseArguments)

# ct_add_exe will add an executable target to be compiled to the project.
# Usage:
# ct_add_exe(_target)
#   _target - Target name for the executable being added
#   ENABLED [bool] - Flag enabling the adding of the executable (default on)
#   INSTALL [bool] - Indicates the executable should be installed on make install
#   BIN_DIR [dir] - The base directory to install executable files to (defaults to bin)
#   DEFINITIONS [.. ..] - One or more compiler definitions to use for executable target
#   DEPENDS [.. ..] - One or more dependencies for executable target
#   LIBS [.. ..] - One or more libraries to link executable target against
#   SOURCES [.. ..] - One or more source files to compile into executable target
function(ct_add_exe _target)
  # Set options that have no arguments
  set(_options)
  # Set one value arguments
  set(_oneValueArgs ENABLED INSTALL BIN_DIR)
  # Set multi value arguments
  set(_multiValueArgs DEFINITIONS DEPENDS LIBS SOURCES)

  # Parse the arguments provided into categories
  cmake_parse_arguments(_ct "${_options}" "${_oneValueArgs}" "${_multiValueArgs}" ${ARGN})

  # Verify that at least SOURCES was provided
  if(NOT DEFINED _ct_SOURCES)
    message(FATAL_ERROR "ct_add_exe requires SOURCES to be provided")
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

  if(_ct_ENABLED)
    # Add the executable target first
    add_executable(${_target} ${_ct_SOURCES})

    # Add compiler definitions if defined
    if(_ct_DEFINITIONS)
      set_target_properties(${_target} PROPERTIES
        COMPILE_FLAGS "${_ct_DEFINITIONS}")
    endif()

    # Add link libraries if provided
    if(_ct_LIBS)
      target_link_libraries(${_target} ${_ct_LIBS})
    endif()

    # Add target dependencies if provided
    if(_ct_DEPENDS)
      add_dependencies(${_target} ${_ct_DEPENDS})
    endif()

    # Install the library built above?
    if(_ct_INSTALL)
      install(TARGETS ${_target} RUNTIME DESTINATION ${_ct_BIN_DIR})
    endif()
  endif()
endfunction()

# EOF
