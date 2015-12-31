# Capture the full path to ourselves for use later
if(NOT __ct_option_cmake_file)
  set(__ct_option_cmake_file ${CMAKE_CURRENT_LIST_FILE})
endif()

# If __ct_option_verify exists then include __ct_option_file provided
if(__ct_option_verify)
  include(${__ct_option_file})
endif()

# Only create parent check-variables target once
if(NOT TARGET check-variables AND NOT __ct_option_verify)
  add_custom_target(check-variables ALL)
endif()

# Include CMakeParseArguments macro for use below
include(CMakeParseArguments)

# ct_add_option simplifies adding options where the default value will be
# used if an environment variable using the option name doesn't exist to
# override the option. Options added this way can be overridden at make time.
# Usage:
# ct_add_option(_name _type _description _default)
#   _name        - The CMake name for option
#   _type        - The option type (String, Bool, Filepath, Path)
#   _description - The help description for option
#   _default     - The default value to use if
macro(ct_add_option _name _type _description _default)
  if(NOT __ct_option_verify)
    # Define the __ct_option_file variable
    set(__ct_option_file ${CMAKE_BINARY_DIR}/${_name}.cmake)
  endif()

  # Determine the value of the variable
  set(__ct_option_output "set(_name ${_name})")
  list(APPEND __ct_option_output "\nset(_type ${_type})")
  list(APPEND __ct_option_output "\nset(_description \"${_description}\")")
  if(DEFINED ENV{${_name}})
    set(${_name} $ENV{${_name}} CACHE ${_type} "${_description}" FORCE)
    list(APPEND __ct_option_output "\nset(${_name} $ENV{${_name}})")
  elseif(${_name})
    set(${_name} ${${_name}} CACHE ${_type} "${_description}" FORCE)
    list(APPEND __ct_option_output "\nset(${_name} ${${_name}})")
    set(ENV{${_name}} ${${_name}})
  else()
    set(${_name} ${_default} CACHE ${_type} "${_description}" FORCE)
    list(APPEND __ct_option_output "\nset(${_name} ${_default})")
  endif()
  # Import previous value from environment during CMake rebuild if available
  if(DEFINED ENV{${name}_PREVIOUS})
    list(APPEND __ct_option_output "\nset(${name}_PREVIOUS $ENV{${name}_PREVIOUS})")
    set(${name}_PREVIOUS $ENV{${name}_PREVIOUS})
  else()
    list(APPEND __ct_option_output "\nset(${name}_PREVIOUS ${${name}})")
  endif()

  # Generate the __ct_option_file output now (current or verify)
  execute_process(
    COMMAND ${CMAKE_COMMAND} -E echo ${__ct_option_output}
    OUTPUT_FILE ${__ct_option_file}${__ct_option_verify})

  # If __ct_option_verify doesn't exist create check-variables targets
  if(NOT __ct_option_verify)
    # Use this file as custom CMake execute process to verify variable
    add_custom_target(check-${_name}
      COMMAND ${CMAKE_COMMAND}
      -D__ct_option_verify:String=-verify
      -D__ct_option_file:Filepath=${__ct_option_file}
      -D__ct_option_sdir:Path=${CMAKE_SOURCE_DIR}
      -D__ct_option_bdir:Path=${CMAKE_BINARY_DIR}
      -P ${__ct_option_cmake_file}
      COMMENT "Checking variable '${_name}' for changes"
      VERBATIM)
    # Add custom target as dependency for parent check-variables target
    add_dependencies(check-variables check-${_name})
  else()
    # Use CMake to compare original file to this file for differences
    execute_process(
      COMMAND ${CMAKE_COMMAND} -E compare_files
      ${__ct_option_file} ${__ct_option_file}${__ct_option_verify}
      OUTPUT_VARIABLE COMPARE_OUTPUT
      ERROR_VARIABLE COMPARE_ERROR
      RESULT_VARIABLE COMPARE_RESULT)

    # Remove verify file
    file(REMOVE ${__ct_option_file}${__ct_option_verify})

    # If compare above failed, then call CMAKE to regenerate Makefiles
    if(NOT COMPARE_RESULT EQUAL 0)
      message(STATUS "Variable '${_name}' has changed")
      # Set master variable changed flag to ON
      set(ENV{CMAKE_VARIABLES_CHANGED} ON)
      # Keep track of previous value of variable
      set(ENV{${_name}_PREVIOUS} ${${_name}_PREVIOUS})
      execute_process(
        COMMAND ${CMAKE_COMMAND} -H${__ct_option_sdir} -B${__ct_option_bdir})
    endif()
  endif()
endmacro()

# If __ct_option_verify exists then use st_add_option to verify variable
if(__ct_option_verify)
  ct_add_option(${_name} ${_type} "${_description}" ${${_name}})
endif()

# EOF
