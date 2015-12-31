# Include add option cmake module
include(ctAddOption)

# Add Unit Test options
if(CMAKE_BUILD_TYPE MATCHES "Debug")
  set(UT_DEFAULT ON)
else()
  set(UT_DEFAULT OFF)
endif()
ct_add_option(UT_COMPILE
  BOOL
  "Compile unit test executables"
  ${UT_DEFAULT})
ct_add_option(UT_RUN_ON_COMPILE
  BOOL
  "Run unit test executables on compile"
  ${UT_DEFAULT})
ct_add_option(UT_FAIL_COMPILE
  BOOL
  "Fail compile on unit test failure"
  ${UT_DEFAULT})
ct_add_option(UT_COVERAGE
  BOOL
  "Provide unit test coverage report(s)"
  ${UT_DEFAULT})
ct_add_option(UT_OVERALL_COVERAGE
  BOOL
  "Provide unit test overall coverage report"
  OFF)
ct_add_option(UT_COVERAGE_DIR
    PATH
    "Unit test coverage directory"
    ${CMAKE_SOURCE_DIR}/coverage)

# Check for coverage programs on our path that will be used in creating the
# unit test coverage reports.
find_program(GCOV_COMMAND gcov)
find_program(LCOV_COMMAND lcov)
find_program(GENHTML_COMMAND genhtml)

# Check that either gcov or lcov and genhtml commands are available
if(GCOV_COMMAND-NOTFOUND OR LCOV_COMMAND-NOTFOUND AND GENHTML_COMMAND-NOTFOUND)
  message(WARNING "Test coverage reports disabled, missing gcov or lcov and genthml")
  set(UT_COVERAGE OFF)
endif()

# Check if compiler is not GCC but is Clang (version 3.0.0 and higher)
if(NOT CMAKE_COMPILER_IS_GNUCXX AND UT_COVERAGE)
  if(NOT "${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang")
    message(WARNING "Test coverage reports disabled, missing GNU gcc or clang compiler")
    set(UT_COVERAGE OFF)
  endif()
endif()

# Make sure the CMAKE_BUILD_TYPE is debug, otherwise show warning about misleading results
if(NOT CMAKE_BUILD_TYPE STREQUAL "Debug" AND UT_COVERAGE)
  message(WARNING "Test coverage results with an optimized (non-Debug) build may be misleading")
endif()

# Include CMakeParseArguments macro for use below
include(CMakeParseArguments)

# Create clean coverage and overall coverage report commands here
if(LCOV_COMMAND AND GENHTML_COMMAND)
  set(__CLEAN_COVERAGE_COMMAND
      COMMAND ${LCOV_COMMAND} -q -d ${PROJECT_BINARY_DIR} -z)
  set(__RUN_OVERALL_COVERAGE_COMMAND
      COMMAND ${LCOV_COMMAND} -q -d ${PROJECT_BINARY_DIR} -c -o overall.info.full
      COMMAND ${LCOV_COMMAND} -q -r overall.info.full
      '/usr/*'
      'third_party/*'
      -o overall.info
      COMMAND ${GENHTML_COMMAND}
      -o ${UT_COVERAGE_DIR}/overall overall.info
      COMMAND ${CMAKE_COMMAND}
      -E remove overall.info.full overall.info)
elseif(GCOV_COMMAND)
  # TODO: Add gcov report and clean commands here
  set(__CLEAN_COVERAGE_COMMAND)
  set(__RUN_OVERALL_COVERAGE_COMMAND)
else()
  message(FATAL_ERROR "Unknown coverage command")
endif()

# Only create coverage target once
if(NOT TARGET coverage)
  add_custom_target(coverage)
  # Add check-variables as dependency of coverage
  if(TARGET check-variables)
    add_dependencies(coverage check-variables)
  endif()
  # Add custom command to clean coverage reports
  add_custom_target(coverage-clean
      ${__CLEAN_COVERAGE_COMMAND})
  # Add coverage-clean as dependency for coverage target
  add_dependencies(coverage coverage-clean)
endif()

# ct_add_test will add a test executable target to be compiled to the project.
# Usage:
# ct_add_test(_target)
#   _target - Target name for the test executable being added
#   ENABLED [bool] - Flag enabling the building of the test executable (default UT_COMPILE)
#   INSTALL [bool] - Indicates the test executable should be installed on make install
#   RUN [bool]     - Flag enabling the running of test executable (default UT_RUN_ON_COMPILE)
#   RUN_DIR [dir]  - The base directory to run test executable from (defaults to cmake binary directory)
#   COVERAGE_DIRNAME [subdir] - Coverage directory name to use for coverage report (defaults to target)
#   TEST_DIR [dir] - The base directory to install test executable files to (defaults to test)
#   DEFINITIONS [.. ..] - One or more compiler definitions to use for test executable target
#   DEPENDS [.. ..] - One or more dependencies for test executable target
#   LIBS [.. ..] - One or more libraries to link test executable target against
#   SOURCES [.. ..] - One or more source files to compile into test executable target
function(ct_add_test _target)
  # Set options that have no arguments
  set(_options)
  # Set one value arguments
  set(_oneValueArgs ENABLED INSTALL TEST_DIR RUN RUN_DIR)
  # Set multi value arguments
  set(_multiValueArgs DEFINITIONS DEPENDS LIBS SOURCES)

  # Parse the arguments provided into categories
  cmake_parse_arguments(_ct "${_options}" "${_oneValueArgs}" "${_multiValueArgs}" ${ARGN})

  # Verify that at least SOURCES was provided
  if(NOT DEFINED _ct_SOURCES)
    message(FATAL_ERROR "ct_add_test requires SOURCES to be provided")
  endif()

  # If ENABLED was not defined then define it as ON
  if(NOT DEFINED _ct_ENABLED)
    set(_ct_ENABLED ${UT_COMPILE})
  endif()

  # If INSTALL was not defined then define it as ON
  if(NOT DEFINED _ct_INSTALL)
    set(_ct_INSTALL ON)
  endif()

  # If ENABLED was not defined then define it as ON
  if(NOT DEFINED _ct_RUN)
    set(_ct_RUN ${UT_RUN_ON_COMPILE})
  endif()

  # If RUN_DIR was not defined then define it as cmake binary directory
  if(NOT DEFINED _ct_RUN_DIR)
    set(_ct_BIN_DIR ${CMAKE_CURRENT_BINARY_DIR})
  endif()

  # If COVERAGE_DIRNAME was not defined then define it as target
  if(NOT DEFINED _ct_COVERAGE_DIRNAME)
    set(_ct_COVERAGE_DIRNAME ${_target})
  endif()

  # If TEST_DIR was not defined then define it as test
  if(NOT DEFINED _ct_TEST_DIR)
    set(_ct_TEST_DIR test/)
  endif()

  if(_ct_ENABLED)
    # Add the test executable target first
    add_executable(${_target} ${_ct_SOURCES})

    # Add unit test coverage compiler flags
    if(UT_COVERAGE)
      set(_ct_COVERAGE_DEFINITIONS "--coverage")
      set_target_properties(${_target} PROPERTIES
        LINK_FLAGS "--coverage")
    endif()

    # Add compiler definitions if defined
    if(_ct_DEFINITIONS OR UT_COVERAGE)
      set_target_properties(${_target} PROPERTIES
        COMPILE_FLAGS "${_ct_COVERAGE_DEFINITIONS} ${_ct_DEFINITIONS}")
    endif()

    # Add link libraries if provided
    if(_ct_LIBS)
      target_link_libraries(${_target} ${_ct_LIBS})
    endif()

    # Add check-variables as dependency of test target to allow for monitoring
    # for UT_xyz variable changes before building the test target.
    # This is particularly important for the overall coverage report to work
    # as expected (e.g. make UT_OVERALL_COVERAGE=ON coverage).
    if(TARGET check-variables)
      add_dependencies(${_target} check-variables)
    endif()

    # Add target dependencies if provided
    if(_ct_DEPENDS)
      add_dependencies(${_target} ${_ct_DEPENDS})
    endif()

    # Install the library built above?
    if(_ct_INSTALL)
      install(TARGETS ${_target} RUNTIME DESTINATION ${_ct_TEST_DIR})
    endif()

    # Run the test on every build?
    if(_ct_RUN)
      # Add this as a test with the same name as the executable (this is used
      # for the test target (e.g. the Unix Makefile 'make test' target)
      add_test(NAME ${_target} COMMAND ${_target})

      # Was unit tests re-enabled but executable already exists? then remove
      # it so it will get rebuild and run again as part of the post build
      if(EXISTS ${CMAKE_CURRENT_BINARY_DIR}/${_target} AND
         CMAKE_VARIABLES_CHANGED AND NOT UT_RUN_ON_COMPILE_PREVIOUS)
        file(REMOVE ${CMAKE_CURRENT_BINARY_DIR}/${_target})
      endif()

      if(UT_COVERAGE)
        # Add this target as a dependency of the coverage target
        add_dependencies(coverage ${_target})
      endif()

      # Overall Coverage enabled? then skip individual coverage clean, run,
      # and generate report steps
      if(NOT UT_OVERALL_COVERAGE)
        # Add custom command to clean coverage report if provided
        if(_ct_CLEAN_COVERAGE_COMMAND)
          add_custom_command(TARGET ${_target}
            PRE_BUILD
            ${__CLEAN_COVERAGE_COMMAND}
            COMMENT "Cleaning '${_target}' coverage report")
        endif()

        # Add custom command to run the unit test after building the test
        # executable using a special unit test CMake script which will cause the
        # executable to be deleted on unit test failure.
        add_custom_command(TARGET ${_target}
          POST_BUILD
          COMMAND ${CMAKE_COMMAND}
            -DTEST=${_target}
            -DTARGET=$<TARGET_FILE:${_target}>
            -DPROJECT_CMAKE_DIR=${PROJECT_CMAKE_DIR}
            -DPROJECT_BINARY_DIR=${PROJECT_BINARY_DIR}
            -DUT_FAIL_COMPILE=${UT_FAIL_COMPILE}
            -DUT_COVERAGE=${UT_COVERAGE}
            -DUT_COVERAGE_DIR=${UT_COVERAGE_DIR}/${_ct_COVERAGE_DIRNAME}
            -P ${PROJECT_CMAKE_DIR}/unittest-run.cmake
          COMMENT "Running '${_target}' unit test"
          VERBATIM)
      endif()
    endif()
  endif()
endfunction()

# ct_add_coverage should be called after adding all tests to add the overall
# coverage report generation step.
# Example:
# st_add_coverage()
function(ct_add_coverage)
  if(UT_OVERALL_COVERAGE)
    add_custom_command(TARGET coverage
        COMMAND ${CMAKE_CTEST_COMMAND} --output-on-failure
        COMMENT "Running all unit tests")

    # Add coverage report generation step if provided
    if(__RUN_OVERALL_COVERAGE_COMMAND)
      add_custom_command(TARGET coverage
          POST_BUILD
          ${__RUN_OVERALL_COVERAGE_COMMAND}
          COMMENT "Creating 'overall' coverage report")
    endif()
  endif()
endfunction()

# Enable test target (even if its empty)
enable_testing()

# EOF
